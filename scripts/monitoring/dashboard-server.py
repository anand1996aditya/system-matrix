#!/usr/bin/env python3

"""
Simple dashboard web server - Config-Aware Version
Serves the dashboard HTML and provides metrics API
"""

import http.server
import socketserver
import subprocess
import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import urlparse, parse_qs, unquote
import mimetypes
from datetime import datetime
import base64
import hashlib
import secrets
import threading

# Load configuration
script_dir = Path(__file__).parent.resolve()
sys.path.insert(0, str(script_dir / "../utilities"))
from config_loader import get_config

# Get configuration instance
config = get_config()

# Load configuration values
PORT = config.get('services.dashboard.port', 8888)
DASHBOARD_DIR = config.get('paths.dashboard_dir')
METRICS_SCRIPT = str(Path(config.get('paths.scripts_dir')) / 'monitoring' / 'collect-metrics.sh')
AUTH_CONFIG_FILE = str(Path(config.get('paths.config_dir')) / '.dashboard_auth')

# File browser drives configuration - auto-detect or use config
def get_drives():
    """Auto-detect mounted drives or use config"""
    drives = []

    # Check if auto-detect is enabled
    drives_config = config.get('drives', {})
    auto_detect = drives_config.get('auto_detect', True) if isinstance(drives_config, dict) else True

    if auto_detect:
        # Auto-detect mounted volumes
        volumes_path = Path('/Volumes')
        if volumes_path.exists():
            exclude_list = drives_config.get('exclude', ['Macintosh HD']) if isinstance(drives_config, dict) else ['Macintosh HD']

            for volume in volumes_path.iterdir():
                if volume.is_dir() and volume.name not in exclude_list:
                    drives.append({
                        'name': volume.name,
                        'path': str(volume)
                    })

        # Add home directory
        drives.insert(0, {
            'name': 'Home',
            'path': str(Path.home())
        })

        # Add custom drives from config if any
        custom_drives = drives_config.get('custom_drives', []) if isinstance(drives_config, dict) else []
        for drive in custom_drives:
            if drive.get('enabled', False) and Path(drive.get('path', '')).exists():
                drives.append({
                    'name': drive.get('name', 'Custom'),
                    'path': drive.get('path', '')
                })
    else:
        # Use legacy config format (list)
        if isinstance(drives_config, list):
            for drive in drives_config:
                if drive.get('enabled', True) and Path(drive.get('path', '')).exists():
                    drives.append({
                        'name': drive.get('name', 'Unknown'),
                        'path': drive.get('path', '')
                    })

    return drives

DRIVES = get_drives()

# Cache for last successful metrics
METRICS_CACHE = {
    'data': None,
    'timestamp': 0,
    'ttl': config.get('monitoring.metrics_cache_ttl_seconds', 10)
}

# Lock to prevent multiple simultaneous metrics collection
METRICS_LOCK = threading.Lock()
METRICS_IN_PROGRESS = False

# Server start time for uptime tracking
START_TIME = None

# Authentication configuration
def load_auth_config():
    """Load authentication credentials from config or fallback file"""
    # Try loading from main config first
    username_from_config = config.get('dashboard_auth.username')
    password_hash_from_config = config.get('dashboard_auth.password_hash')

    if username_from_config and password_hash_from_config and password_hash_from_config != "WILL_BE_SET_BY_SETUP_SCRIPT":
        return username_from_config, password_hash_from_config

    # Fallback to legacy auth file
    if os.path.exists(AUTH_CONFIG_FILE):
        try:
            with open(AUTH_CONFIG_FILE, 'r') as f:
                auth_config = json.load(f)
                return auth_config.get('username'), auth_config.get('password_hash')
        except:
            pass

    # Default credentials if no config exists
    print(f"\n⚠️  SECURITY NOTICE ⚠️")
    print(f"No authentication configured!")
    print(f"Please run setup.sh to configure dashboard authentication")
    print(f"Using default credentials (INSECURE - change immediately!)\n")

    default_username = "admin"
    default_password = "matrix2026"
    password_hash = hashlib.sha256(default_password.encode()).hexdigest()

    return default_username, password_hash

# Load authentication credentials
AUTH_USERNAME, AUTH_PASSWORD_HASH = load_auth_config()

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    # Class-level dictionary to track failed login attempts
    # Structure: {ip_address: {'count': int, 'first_attempt': timestamp, 'locked_until': timestamp}}
    failed_attempts = {}

    # Rate limiting configuration from config
    MAX_FAILED_ATTEMPTS = config.get('dashboard_auth.max_failed_attempts', 3)
    LOCKOUT_DURATION = config.get('dashboard_auth.lockout_duration_seconds', 180)
    ATTEMPT_WINDOW = 300     # 5 minutes window to track attempts

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DASHBOARD_DIR, **kwargs)

    def get_client_ip(self):
        """Get the client's IP address"""
        # Handle both direct connections and proxy headers
        forwarded_for = self.headers.get('X-Forwarded-For')
        if forwarded_for:
            return forwarded_for.split(',')[0].strip()
        return self.client_address[0]

    def is_locked_out(self, ip):
        """Check if an IP address is currently locked out"""
        if ip not in self.failed_attempts:
            return False

        attempt_info = self.failed_attempts[ip]
        current_time = time.time()

        # Check if lockout period has expired
        if 'locked_until' in attempt_info and current_time < attempt_info['locked_until']:
            remaining = int(attempt_info['locked_until'] - current_time)
            print(f"[AUTH] IP {ip} is locked out. {remaining}s remaining.", flush=True)
            return True

        # Lockout expired, clean up
        if 'locked_until' in attempt_info and current_time >= attempt_info['locked_until']:
            del self.failed_attempts[ip]
            print(f"[AUTH] Lockout expired for IP {ip}", flush=True)
            return False

        return False

    def record_failed_attempt(self, ip):
        """Record a failed authentication attempt"""
        current_time = time.time()

        if ip not in self.failed_attempts:
            self.failed_attempts[ip] = {
                'count': 1,
                'first_attempt': current_time
            }
            print(f"[AUTH] Failed attempt 1/{self.MAX_FAILED_ATTEMPTS} from {ip}", flush=True)
        else:
            attempt_info = self.failed_attempts[ip]

            # Reset count if outside the attempt window
            if current_time - attempt_info['first_attempt'] > self.ATTEMPT_WINDOW:
                self.failed_attempts[ip] = {
                    'count': 1,
                    'first_attempt': current_time
                }
                print(f"[AUTH] Failed attempt 1/{self.MAX_FAILED_ATTEMPTS} from {ip} (window reset)", flush=True)
            else:
                attempt_info['count'] += 1
                print(f"[AUTH] Failed attempt {attempt_info['count']}/{self.MAX_FAILED_ATTEMPTS} from {ip}", flush=True)

                # Lock out if threshold reached
                if attempt_info['count'] >= self.MAX_FAILED_ATTEMPTS:
                    attempt_info['locked_until'] = current_time + self.LOCKOUT_DURATION
                    print(f"[AUTH] ⚠️  IP {ip} LOCKED OUT for {self.LOCKOUT_DURATION}s after {self.MAX_FAILED_ATTEMPTS} failed attempts", flush=True)

    def clear_failed_attempts(self, ip):
        """Clear failed attempts for an IP after successful login"""
        if ip in self.failed_attempts:
            del self.failed_attempts[ip]
            print(f"[AUTH] ✓ Successful login from {ip}, clearing failed attempts", flush=True)

    def check_auth(self):
        """Check HTTP Basic Authentication with rate limiting"""
        client_ip = self.get_client_ip()

        # Check if IP is locked out
        if self.is_locked_out(client_ip):
            return False

        auth_header = self.headers.get('Authorization')

        if auth_header is None:
            return False

        try:
            # Parse "Basic base64string"
            auth_type, auth_string = auth_header.split(' ', 1)

            if auth_type.lower() != 'basic':
                return False

            # Decode base64
            decoded = base64.b64decode(auth_string).decode('utf-8')
            username, password = decoded.split(':', 1)

            # Hash the provided password
            password_hash = hashlib.sha256(password.encode()).hexdigest()

            # Check credentials
            if username == AUTH_USERNAME and password_hash == AUTH_PASSWORD_HASH:
                # Successful authentication
                self.clear_failed_attempts(client_ip)
                return True
            else:
                # Failed authentication
                self.record_failed_attempt(client_ip)
                print(f"[AUTH] Invalid credentials from {client_ip}: username='{username}'", flush=True)
                return False

        except Exception as e:
            print(f"[AUTH] Auth error from {client_ip}: {e}", flush=True)
            self.record_failed_attempt(client_ip)
            return False

    def send_auth_required(self):
        """Send 401 Unauthorized response or 429 if locked out"""
        client_ip = self.get_client_ip()

        # Check if IP is locked out
        if self.is_locked_out(client_ip):
            # Send 429 Too Many Requests for locked out IPs
            attempt_info = self.failed_attempts.get(client_ip, {})
            remaining_time = 0
            if 'locked_until' in attempt_info:
                remaining_time = int(attempt_info['locked_until'] - time.time())

            self.send_response(429)
            self.send_header('Content-type', 'text/html')
            self.send_header('Retry-After', str(remaining_time))
            self.end_headers()

            html = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Account Locked</title>
                <style>
                    body {{
                        font-family: 'Courier New', monospace;
                        background: #0A0A0A;
                        color: #FF4444;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        height: 100vh;
                        margin: 0;
                    }}
                    .auth-box {{
                        border: 3px solid #FF4444;
                        padding: 40px;
                        text-align: center;
                        box-shadow: 0 0 20px rgba(255, 68, 68, 0.3);
                    }}
                    h1 {{ color: #FF0000; text-shadow: 0 0 10px #FF0000; }}
                    .timer {{
                        font-size: 2em;
                        color: #FFFF00;
                        margin: 20px 0;
                        text-shadow: 0 0 10px #FFFF00;
                    }}
                    .info {{ color: #AAAAAA; font-size: 0.9em; margin-top: 20px; }}
                </style>
                <script>
                    let remainingSeconds = {remaining_time};
                    function updateTimer() {{
                        if (remainingSeconds <= 0) {{
                            document.getElementById('timer').textContent = 'UNLOCKED';
                            document.getElementById('message').textContent = 'You may now refresh the page to try again.';
                            return;
                        }}
                        const minutes = Math.floor(remainingSeconds / 60);
                        const seconds = remainingSeconds % 60;
                        document.getElementById('timer').textContent =
                            minutes + ':' + (seconds < 10 ? '0' : '') + seconds;
                        remainingSeconds--;
                        setTimeout(updateTimer, 1000);
                    }}
                    window.onload = updateTimer;
                </script>
            </head>
            <body>
                <div class="auth-box">
                    <h1>⚠️ ACCOUNT LOCKED</h1>
                    <p>Too many failed authentication attempts from your IP address.</p>
                    <p class="timer" id="timer">{remaining_time // 60}:{remaining_time % 60:02d}</p>
                    <p id="message">Please wait for the lockout period to expire.</p>
                    <p class="info">Your IP: {client_ip}<br>
                    Failed attempts: {attempt_info.get('count', 0)}/{self.MAX_FAILED_ATTEMPTS}</p>
                </div>
            </body>
            </html>
            """
            self.wfile.write(html.encode())
        else:
            # Normal 401 response
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'Basic realm="System Matrix Dashboard"')
            self.send_header('Content-type', 'text/html')
            self.end_headers()

            html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Authentication Required</title>
                <style>
                    body {
                        font-family: 'Courier New', monospace;
                        background: #0A0A0A;
                        color: #00FF41;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        height: 100vh;
                        margin: 0;
                    }
                    .auth-box {
                        border: 3px solid #00FF41;
                        padding: 40px;
                        text-align: center;
                        box-shadow: 0 0 20px rgba(0, 255, 65, 0.3);
                    }
                    h1 { color: #00FFFF; text-shadow: 0 0 10px #00FFFF; }
                </style>
            </head>
            <body>
                <div class="auth-box">
                    <h1>🔒 AUTHENTICATION REQUIRED</h1>
                    <p>Access to System Matrix Dashboard requires authentication.</p>
                    <p style="color: #00AA33; font-size: 0.9em;">Your browser should prompt you for credentials.</p>
                </div>
            </body>
            </html>
            """
            self.wfile.write(html.encode())

    def do_POST(self):
        # Check authentication first
        if not self.check_auth():
            self.send_auth_required()
            return

        parsed_path = urlparse(self.path)

        # Trigger Google Drive backup
        if parsed_path.path == '/api/backup/gdrive':
            try:
                result = {'success': False, 'message': ''}

                # Run Google Drive backup script in background
                backup_script = os.path.expanduser("~/backup_documents_to_gdrive.sh")

                if not os.path.exists(backup_script):
                    result = {'success': False, 'message': f'Backup script not found at {backup_script}'}
                else:
                    # Check if backup is already running
                    check_running = subprocess.run(['pgrep', '-f', 'backup_documents_to_gdrive.sh'],
                                                  capture_output=True)
                    if check_running.returncode == 0:
                        result = {'success': False, 'message': 'Google Drive backup is already running. Please wait for it to complete.'}
                    else:
                        # Check execute permission
                        if not os.access(backup_script, os.X_OK):
                            result = {'success': False, 'message': f'Backup script is not executable. Run: chmod +x {backup_script}'}
                        else:
                            # Run in background
                            subprocess.Popen([backup_script],
                                           stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE)
                            result = {'success': True, 'message': 'Google Drive backup started. Check logs at ~/.backup_logs/'}

                # Send JSON response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode())

        # Trigger EVM backup
        elif parsed_path.path == '/api/backup/evm':
            try:
                result = {'success': False, 'message': ''}

                # Check if EVM is mounted first
                evm_mount = "/Volumes/EVM"
                if not os.path.exists(evm_mount):
                    result = {'success': False, 'message': 'EVM drive not mounted. Please connect the drive first.'}
                else:
                    # Run EVM backup script in background
                    backup_script = os.path.expanduser("~/backup_documents_to_evm.sh")

                    if not os.path.exists(backup_script):
                        result = {'success': False, 'message': f'Backup script not found at {backup_script}'}
                    else:
                        # Check if backup is already running
                        check_running = subprocess.run(['pgrep', '-f', 'backup_documents_to_evm.sh'],
                                                      capture_output=True)
                        if check_running.returncode == 0:
                            result = {'success': False, 'message': 'EVM backup is already running. Please wait for it to complete.'}
                        else:
                            # Check execute permission
                            if not os.access(backup_script, os.X_OK):
                                result = {'success': False, 'message': f'Backup script is not executable. Run: chmod +x {backup_script}'}
                            else:
                                # Run in background
                                subprocess.Popen([backup_script],
                                               stdout=subprocess.PIPE,
                                               stderr=subprocess.PIPE)
                                result = {'success': True, 'message': 'EVM backup started. Check logs at ~/.backup_logs/'}

                # Send JSON response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode())

        # Trigger automation endpoint
        elif parsed_path.path == '/api/trigger/automation':
            try:
                result = {'success': False, 'message': ''}

                # Run unified automation script in background
                automation_script = os.path.expanduser("~/Claude-Code/Scripts/unified-automation.sh")

                if os.path.exists(automation_script):
                    # Run in background
                    subprocess.Popen([automation_script],
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE)
                    result = {'success': True, 'message': 'Automation script started in background. Check logs at ~/Claude-Code/Logs/unified-automation.log'}
                else:
                    result = {'success': False, 'message': f'Automation script not found at {automation_script}'}

                # Send JSON response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode())

        # Restart service endpoints
        elif parsed_path.path.startswith('/api/restart/'):
            service = parsed_path.path.split('/')[-1]

            try:
                result = {'success': False, 'message': ''}

                if service == 'pihole':
                    cmd_result = subprocess.run(['docker', 'restart', 'pihole'],
                                              capture_output=True, text=True, timeout=30)
                    if cmd_result.returncode == 0:
                        result = {'success': True, 'message': 'Pi-hole restarted successfully'}
                    else:
                        result = {'success': False, 'message': f'Failed to restart Pi-hole: {cmd_result.stderr}'}

                elif service == 'plex':
                    # Restart Plex Docker container
                    cmd_result = subprocess.run(['docker', 'restart', 'plex'],
                                              capture_output=True, text=True, timeout=30)
                    if cmd_result.returncode == 0:
                        result = {'success': True, 'message': 'Plex restarted successfully'}
                    else:
                        result = {'success': False, 'message': f'Failed to restart Plex: {cmd_result.stderr}'}

                elif service == 'colima':
                    # Restart Colima
                    cmd_result = subprocess.run(['colima', 'restart'],
                                              capture_output=True, text=True, timeout=60)
                    if cmd_result.returncode == 0:
                        result = {'success': True, 'message': 'Colima restarting...'}
                    else:
                        result = {'success': False, 'message': f'Failed to restart Colima: {cmd_result.stderr}'}

                elif service == 'caddy':
                    # Restart Caddy via launchctl
                    cmd_result = subprocess.run(['launchctl', 'kickstart', '-k', 'gui/501/com.clawdbot.caddy'],
                                              capture_output=True, text=True, timeout=15)
                    if cmd_result.returncode == 0:
                        result = {'success': True, 'message': 'Caddy restarted successfully'}
                    else:
                        result = {'success': False, 'message': f'Failed to restart Caddy: {cmd_result.stderr}'}

                elif service == 'tailscale':
                    result = {'success': False, 'message': 'Tailscale restart not recommended - use Tailscale app'}

                elif service == 'clawdbot':
                    # Restart ClawdBot
                    subprocess.run(['pkill', '-f', 'clawdbot-gateway'], capture_output=True)
                    subprocess.run(['pkill', '-f', 'clawdbot'], capture_output=True)
                    time.sleep(2)
                    # ClawdBot will auto-restart via its own mechanisms or needs manual start
                    result = {'success': True, 'message': 'ClawdBot processes stopped - will auto-restart if configured'}

                else:
                    result = {'success': False, 'message': f'Unknown service: {service}'}

                # Send JSON response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode())

        # Fan control endpoint
        elif parsed_path.path == '/api/fan/set':
            try:
                # Read request body
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode('utf-8'))

                rpm = data.get('rpm', 0)

                # Check if Macs Fan Control is installed
                app_path = "/Applications/Macs Fan Control.app"

                if not os.path.exists(app_path):
                    result = {'success': False, 'message': 'Macs Fan Control not installed. Install it from https://crystalidea.com/macs-fan-control'}
                else:
                    # Open Macs Fan Control app
                    subprocess.run(['open', '-a', 'Macs Fan Control'], capture_output=True)

                    if rpm == 0:
                        result = {'success': True, 'message': f'Macs Fan Control opened. Please set fan to AUTO mode in the app.'}
                    else:
                        result = {'success': True, 'message': f'Macs Fan Control opened. Please set fan to {rpm} RPM in the app.'}

                # Send JSON response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode())

        # Automation status endpoint
        elif parsed_path.path == '/api/automation/status':
            try:
                status_file = os.path.expanduser("~/Claude-Code/Logs/automation-status.json")

                if os.path.exists(status_file):
                    with open(status_file, 'r') as f:
                        status_data = json.load(f)
                else:
                    status_data = {'running': False, 'tasks': {}}

                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(json.dumps(status_data).encode())

            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())

        else:
            self.send_error(404, "Not found")

    def do_GET(self):
        parsed_path = urlparse(self.path)

        # Health check endpoint (no authentication required for monitoring)
        if parsed_path.path == '/health':
            try:
                current_time = time.time()
                uptime_seconds = current_time - START_TIME if START_TIME else 0

                # Perform health checks
                health_checks = {
                    'metrics_script_exists': os.path.exists(METRICS_SCRIPT),
                    'auth_config_exists': os.path.exists(AUTH_CONFIG_FILE),
                    'dashboard_dir_exists': os.path.exists(DASHBOARD_DIR),
                    'drives_available': sum(1 for d in DRIVES if os.path.exists(d['path'])),
                    'total_drives': len(DRIVES)
                }

                # Overall health status
                all_critical_checks_pass = (
                    health_checks['metrics_script_exists'] and
                    health_checks['auth_config_exists'] and
                    health_checks['dashboard_dir_exists']
                )

                health_data = {
                    'status': 'healthy' if all_critical_checks_pass else 'degraded',
                    'timestamp': current_time,
                    'uptime_seconds': uptime_seconds,
                    'uptime_human': f"{int(uptime_seconds // 3600)}h {int((uptime_seconds % 3600) // 60)}m {int(uptime_seconds % 60)}s",
                    'version': '1.0.0',
                    'checks': health_checks
                }

                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(json.dumps(health_data, indent=2).encode())
                return
            except Exception as e:
                self.send_error(500, f'Health check failed: {str(e)}')
                return

        # Check authentication for all other endpoints
        if not self.check_auth():
            self.send_auth_required()
            return

        # API endpoint for file browser - list drives
        if parsed_path.path == '/api/files/drives':
            try:
                drives_info = []
                for drive in DRIVES:
                    exists = os.path.exists(drive['path'])
                    drive_info = {
                        'name': drive['name'],
                        'path': drive['path'],
                        'available': exists
                    }
                    drives_info.append(drive_info)

                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps({'drives': drives_info}).encode())
                return
            except Exception as e:
                self.send_error(500, str(e))
                return

        # API endpoint for file browser - list directory contents (OPTIMIZED)
        elif parsed_path.path == '/api/files/list':
            try:
                query_params = parse_qs(parsed_path.query)
                requested_path = query_params.get('path', ['/'])[0]
                requested_path = unquote(requested_path)

                # Security check
                is_allowed = any(requested_path.startswith(drive['path']) for drive in DRIVES)
                if not is_allowed:
                    self.send_error(403, 'Access denied')
                    return

                # Path validation
                if not os.path.exists(requested_path):
                    self.send_error(404, 'Path not found')
                    return

                if not os.path.isdir(requested_path):
                    self.send_error(400, 'Not a directory')
                    return

                # Optimized directory listing
                items = []
                try:
                    print(f"[TEST] Attempting scandir on: {requested_path}", flush=True)
                    entries = os.scandir(requested_path)  # More efficient than listdir
                    print(f"[TEST] scandir SUCCESS!", flush=True)
                    for entry in entries:
                        # Skip hidden files
                        if entry.name.startswith('.'):
                            continue

                        try:
                            stat_info = entry.stat(follow_symlinks=False)
                            items.append({
                                'name': entry.name,
                                'path': entry.path,
                                'is_directory': entry.is_dir(follow_symlinks=False),
                                'size': stat_info.st_size if entry.is_file() else 0,
                                'modified': datetime.fromtimestamp(stat_info.st_mtime).isoformat()
                            })
                        except (OSError, PermissionError):
                            # Skip files we can't access
                            continue
                except PermissionError as e:
                    print(f"[TEST] PermissionError: {e}", flush=True)
                    import traceback
                    print(f"[TEST] Traceback:\n{traceback.format_exc()}", flush=True)
                    self.send_error(403, 'Permission denied - macOS Full Disk Access required')
                    return

                # Sort efficiently
                items.sort(key=lambda x: (not x['is_directory'], x['name'].lower()))

                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'path': requested_path,
                    'items': items
                }).encode())
                return
            except Exception as e:
                self.send_error(500, str(e))
                return

        # API endpoint for file download (OPTIMIZED - streaming)
        elif parsed_path.path == '/api/files/download':
            try:
                query_params = parse_qs(parsed_path.query)
                requested_path = query_params.get('path', [''])[0]
                requested_path = unquote(requested_path)

                # Security check
                is_allowed = any(requested_path.startswith(drive['path']) for drive in DRIVES)
                if not is_allowed:
                    self.send_error(403, 'Access denied')
                    return

                if not os.path.exists(requested_path):
                    self.send_error(404, 'File not found')
                    return

                if os.path.isdir(requested_path):
                    self.send_error(400, 'Cannot download directory')
                    return

                # Get file info
                file_size = os.path.getsize(requested_path)
                mime_type, _ = mimetypes.guess_type(requested_path)
                mime_type = mime_type or 'application/octet-stream'

                # Send headers
                self.send_response(200)
                self.send_header('Content-type', mime_type)
                self.send_header('Content-Disposition', f'attachment; filename="{os.path.basename(requested_path)}"')
                self.send_header('Content-Length', str(file_size))
                self.end_headers()

                # Stream file in chunks (more efficient for large files)
                chunk_size = 1024 * 1024  # 1MB chunks
                with open(requested_path, 'rb') as f:
                    while True:
                        chunk = f.read(chunk_size)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                return
            except Exception as e:
                self.send_error(500, str(e))
                return

        # API endpoint for backup status
        elif parsed_path.path == '/api/backup/status':
            try:
                import glob

                # Get latest backup logs
                backup_logs_dir = os.path.expanduser("~/.backup_logs")

                # Check if backup logs directory exists
                if not os.path.exists(backup_logs_dir):
                    os.makedirs(backup_logs_dir, exist_ok=True)

                gdrive_logs = glob.glob(f"{backup_logs_dir}/backup_*.log")
                evm_logs = glob.glob(f"{backup_logs_dir}/backup_evm_*.log")

                # Sort by modification time
                gdrive_logs.sort(key=os.path.getmtime, reverse=True)
                evm_logs.sort(key=os.path.getmtime, reverse=True)

                result = {
                    'gdrive': {'status': 'idle', 'progress': '', 'percent': 0, 'message': '', 'last_log': None},
                    'evm': {'status': 'idle', 'progress': '', 'percent': 0, 'message': '', 'last_log': None}
                }

                # Check Google Drive backup status
                if gdrive_logs:
                    latest_gdrive = gdrive_logs[0]

                    # Skip if file is empty (crashed backup)
                    if os.path.getsize(latest_gdrive) == 0:
                        result['gdrive']['status'] = 'error'
                        result['gdrive']['message'] = 'Backup crashed (empty log)'
                    else:
                        mod_time = os.path.getmtime(latest_gdrive)
                        age_seconds = time.time() - mod_time

                        # If modified in last 2 minutes, backup might be running
                        if age_seconds < 120:
                            result['gdrive']['status'] = 'running'
                            # Read only last 50 lines to avoid reading huge files
                            with open(latest_gdrive, 'rb') as f:
                                try:
                                    # Seek to end and read last ~10KB (should contain last 50+ lines)
                                    f.seek(0, 2)  # Seek to end
                                    file_size = f.tell()
                                    read_size = min(10240, file_size)  # Read last 10KB or entire file
                                    f.seek(max(0, file_size - read_size))
                                    lines = f.read().decode('utf-8', errors='ignore').splitlines()
                                except:
                                    lines = []

                                result['gdrive']['progress'] = '\n'.join(lines[-10:])

                                # Parse for latest PROGRESS line
                                for line in reversed(lines):
                                    if 'PROGRESS:' in line:
                                        try:
                                            parts = line.split('PROGRESS:')[1].split(':', 1)
                                            result['gdrive']['percent'] = int(parts[0])
                                            result['gdrive']['message'] = parts[1].strip() if len(parts) > 1 else ""
                                            break
                                        except:
                                            pass
                        else:
                            # Check if successful - read only last 5KB to check status
                            with open(latest_gdrive, 'rb') as f:
                                try:
                                    f.seek(0, 2)
                                    file_size = f.tell()
                                    read_size = min(5120, file_size)  # Read last 5KB
                                    f.seek(max(0, file_size - read_size))
                                    content = f.read().decode('utf-8', errors='ignore')
                                except:
                                    content = ""

                                if 'Backup Completed' in content:
                                    result['gdrive']['status'] = 'completed'
                                    result['gdrive']['percent'] = 100
                                    result['gdrive']['message'] = 'Backup complete!'
                                else:
                                    result['gdrive']['status'] = 'error'
                                    result['gdrive']['message'] = 'Backup failed'

                        result['gdrive']['last_log'] = os.path.basename(latest_gdrive)

                # Check EVM backup status
                if evm_logs:
                    latest_evm = evm_logs[0]

                    # Skip if file is empty (crashed backup)
                    if os.path.getsize(latest_evm) == 0:
                        result['evm']['status'] = 'error'
                        result['evm']['message'] = 'Backup crashed (empty log)'
                    else:
                        mod_time = os.path.getmtime(latest_evm)
                        age_seconds = time.time() - mod_time

                        if age_seconds < 120:
                            result['evm']['status'] = 'running'
                            # Read only last 50 lines to avoid reading huge files
                            with open(latest_evm, 'rb') as f:
                                try:
                                    # Seek to end and read last ~10KB (should contain last 50+ lines)
                                    f.seek(0, 2)  # Seek to end
                                    file_size = f.tell()
                                    read_size = min(10240, file_size)  # Read last 10KB or entire file
                                    f.seek(max(0, file_size - read_size))
                                    lines = f.read().decode('utf-8', errors='ignore').splitlines()
                                except:
                                    lines = []

                                result['evm']['progress'] = '\n'.join(lines[-10:])

                                # Parse for latest PROGRESS line
                                for line in reversed(lines):
                                    if 'PROGRESS:' in line:
                                        try:
                                            parts = line.split('PROGRESS:')[1].split(':', 1)
                                            result['evm']['percent'] = int(parts[0])
                                            result['evm']['message'] = parts[1].strip() if len(parts) > 1 else ""
                                            break
                                        except:
                                            pass
                        else:
                            # Check if successful - read only last 5KB to check status
                            with open(latest_evm, 'rb') as f:
                                try:
                                    f.seek(0, 2)
                                    file_size = f.tell()
                                    read_size = min(5120, file_size)  # Read last 5KB
                                    f.seek(max(0, file_size - read_size))
                                    content = f.read().decode('utf-8', errors='ignore')
                                except:
                                    content = ""

                                if 'completed successfully' in content:
                                    result['evm']['status'] = 'completed'
                                    result['evm']['percent'] = 100
                                    result['evm']['message'] = 'Backup complete!'
                                else:
                                    result['evm']['status'] = 'error'
                                    result['evm']['message'] = 'Backup failed'

                        result['evm']['last_log'] = os.path.basename(latest_evm)

                # Send JSON response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'success': False, 'message': str(e)}).encode())

        # API endpoint for metrics
        elif parsed_path.path == '/api/metrics':
            global METRICS_IN_PROGRESS
            try:
                current_time = time.time()

                # Check if cache is still valid
                if (METRICS_CACHE['data'] is not None and
                    (current_time - METRICS_CACHE['timestamp']) < METRICS_CACHE['ttl']):
                    # Return cached data
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.send_header('Cache-Control', 'no-cache')
                    self.end_headers()
                    self.wfile.write(METRICS_CACHE['data'].encode())
                    return

                # Check if metrics collection is already in progress
                if not METRICS_LOCK.acquire(blocking=False):
                    # Another request is collecting metrics, return cached data
                    if METRICS_CACHE['data']:
                        self.send_response(200)
                        self.send_header('Content-type', 'application/json')
                        self.send_header('Access-Control-Allow-Origin', '*')
                        self.send_header('Cache-Control', 'no-cache')
                        self.send_header('X-Rate-Limited', 'true')
                        self.end_headers()
                        self.wfile.write(METRICS_CACHE['data'].encode())
                    else:
                        self.send_error(429, "Metrics collection in progress, try again soon")
                    return

                try:
                    METRICS_IN_PROGRESS = True

                    # Run the metrics collection script
                    result = subprocess.run(
                        [METRICS_SCRIPT],
                        capture_output=True,
                        text=True,
                        timeout=30
                    )

                    if result.returncode == 0 and result.stdout:
                        # Validate JSON
                        try:
                            json.loads(result.stdout)  # Validate it's proper JSON

                            # Update cache
                            METRICS_CACHE['data'] = result.stdout
                            METRICS_CACHE['timestamp'] = current_time

                            # Send JSON response
                            self.send_response(200)
                            self.send_header('Content-type', 'application/json')
                            self.send_header('Access-Control-Allow-Origin', '*')
                            self.send_header('Cache-Control', 'no-cache')
                            self.end_headers()
                            self.wfile.write(result.stdout.encode())
                        except json.JSONDecodeError:
                            # Invalid JSON, return cached data if available
                            if METRICS_CACHE['data']:
                                self.send_response(200)
                                self.send_header('Content-type', 'application/json')
                                self.send_header('Access-Control-Allow-Origin', '*')
                                self.end_headers()
                                self.wfile.write(METRICS_CACHE['data'].encode())
                            else:
                                self.send_error(500, "Invalid JSON from metrics script")
                    else:
                        # Script failed, return cached data if available
                        if METRICS_CACHE['data']:
                            self.send_response(200)
                            self.send_header('Content-type', 'application/json')
                            self.send_header('Access-Control-Allow-Origin', '*')
                            self.end_headers()
                            self.wfile.write(METRICS_CACHE['data'].encode())
                        else:
                            self.send_error(500, "Metrics collection failed")

                finally:
                    METRICS_IN_PROGRESS = False
                    METRICS_LOCK.release()

            except subprocess.TimeoutExpired:
                METRICS_IN_PROGRESS = False
                if METRICS_LOCK.locked():
                    METRICS_LOCK.release()
                # Return cached data on timeout
                if METRICS_CACHE['data']:
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(METRICS_CACHE['data'].encode())
                else:
                    self.send_error(504, "Metrics collection timeout")
            except Exception as e:
                METRICS_IN_PROGRESS = False
                if METRICS_LOCK.locked():
                    METRICS_LOCK.release()
                # Return cached data on error
                if METRICS_CACHE['data']:
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(METRICS_CACHE['data'].encode())
                else:
                    self.send_error(500, f"Error: {str(e)}")

        # Serve dashboard HTML
        else:
            super().do_GET()

    def end_headers(self):
        # Add no-cache headers for all responses
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")

        # Add security headers
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-XSS-Protection", "1; mode=block")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:")
        self.send_header("Referrer-Policy", "no-referrer")

        super().end_headers()

    def log_message(self, format, *args):
        # Log to file instead of console
        log_dir = os.path.expanduser("~/Claude-Code/Logs")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "dashboard-server.log")

        with open(log_file, 'a') as f:
            f.write(f"{self.log_date_time_string()} - {format % args}\n")

if __name__ == "__main__":
    # Record server start time for health checks
    START_TIME = time.time()

    # Bind to all interfaces so it's accessible via Tailscale
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), DashboardHandler) as httpd:
        print(f"Dashboard server running on port {PORT}")
        print(f"Access via: http://localhost:{PORT}")
        print(f"Or via Tailscale: http://100.118.129.106:{PORT}")
        print(f"Health check: http://localhost:{PORT}/health")
        httpd.serve_forever()
