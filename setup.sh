#!/bin/bash

# System Metrics Dashboard - Interactive Setup Script
# This script will guide you through the initial configuration

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_TEMPLATE="$CONFIG_DIR/config.template.json"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║   System Metrics Dashboard - Interactive Setup        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  Configuration file already exists: $CONFIG_FILE${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled. Existing configuration preserved."
        exit 0
    fi
fi

# Check dependencies
echo -e "${BLUE}→ Checking dependencies...${NC}"

MISSING_DEPS=()

if ! command -v python3 &> /dev/null; then
    MISSING_DEPS+=("python3")
fi

if ! command -v brew &> /dev/null; then
    MISSING_DEPS+=("homebrew")
fi

# Check for optional but recommended dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}  ⚠️  jq not found (optional, but recommended for config validation)${NC}"
fi

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}  ⚠️  Docker not found (optional, for Pi-hole, Plex, etc.)${NC}"
fi

# If missing required dependencies, offer to install them
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}  ✗ Missing required dependencies: ${MISSING_DEPS[*]}${NC}"
    echo ""

    # Check if installer exists
    if [ -f "$SCRIPT_DIR/scripts/install/install-dependencies.sh" ]; then
        echo "Would you like to automatically install missing dependencies?"
        echo ""
        read -p "Run automatic installer? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            "$SCRIPT_DIR/scripts/install/install-dependencies.sh"

            # Check if installation succeeded
            if [ $? -ne 0 ]; then
                echo -e "${RED}Dependency installation failed. Please install manually.${NC}"
                exit 1
            fi

            echo ""
            echo -e "${GREEN}✓ Dependencies installed! Continuing with setup...${NC}"
            echo ""
        else
            echo -e "${RED}Please install dependencies manually and run setup again:${NC}"
            echo "  • Homebrew: https://brew.sh"
            echo "  • Python 3: brew install python3"
            echo ""
            echo "Or run: ./scripts/install/install-dependencies.sh"
            exit 1
        fi
    else
        echo -e "${RED}Please install these dependencies:${NC}"
        echo "  • Homebrew: https://brew.sh"
        echo "  • Python 3: brew install python3"
        echo ""
        echo "Or run: ./scripts/install/install-dependencies.sh"
        exit 1
    fi
fi

echo -e "${GREEN}✓ All required dependencies found${NC}\n"

# Check for port conflicts
echo -e "${BLUE}→ Checking for port conflicts...${NC}"

check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}  ⚠️  Port $port is already in use (needed for $service)${NC}"
        return 1
    else
        echo -e "${GREEN}  ✓ Port $port available${NC}"
        return 0
    fi
}

PORT_CONFLICTS=()

check_port 8888 "Dashboard" || PORT_CONFLICTS+=("8888 (Dashboard)")
check_port 8080 "Pi-hole Web UI" || PORT_CONFLICTS+=("8080 (Pi-hole)")
check_port 32400 "Plex Media Server" || PORT_CONFLICTS+=("32400 (Plex)")
check_port 5353 "Pi-hole DNS" || PORT_CONFLICTS+=("5353 (DNS)")

if [ ${#PORT_CONFLICTS[@]} -gt 0 ]; then
    echo -e "${YELLOW}"
    echo "⚠️  Warning: Some ports are in use:"
    for conflict in "${PORT_CONFLICTS[@]}"; do
        echo "   - $conflict"
    done
    echo -e "${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled. Free the ports and try again."
        exit 1
    fi
fi

echo -e "${GREEN}✓ Port check complete${NC}\n"

# Create directories
echo -e "${BLUE}→ Creating directory structure...${NC}"

mkdir -p "$SCRIPT_DIR/logs"/{cache,alert-state,metrics-state}
mkdir -p "$SCRIPT_DIR/dashboard"
mkdir -p "$SCRIPT_DIR/scripts"/{automation,monitoring,notifications,utilities}
mkdir -p "$SCRIPT_DIR/config/launchagents"
mkdir -p "$SCRIPT_DIR/docs"/{setup,guides,technical,alerts}
mkdir -p "$SCRIPT_DIR/tests"

echo -e "${GREEN}✓ Directories created${NC}\n"

# Detect and offer optional service installation
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Optional Services Detection                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}→ Detecting installed services...${NC}\n"

# Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker not installed${NC}"
    echo "   Docker is required for Pi-hole, Plex, and other containerized services."
    echo ""
    read -p "   Would you like installation instructions for Docker? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}   Docker Installation Options:${NC}"
        echo "   1. Docker Desktop: https://www.docker.com/products/docker-desktop"
        echo "   2. Colima (lightweight): brew install colima && colima start"
        echo ""
    fi
else
    echo -e "${GREEN}✓ Docker installed${NC}"
fi

# Tailscale
if ! command -v tailscale &> /dev/null && ! pgrep -x "Tailscale" > /dev/null; then
    echo -e "${YELLOW}⚠️  Tailscale not installed${NC}"
    echo "   Tailscale provides secure remote access to your dashboard."
    echo ""
    read -p "   Would you like to install Tailscale? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v brew &> /dev/null; then
            echo "   Installing Tailscale via Homebrew..."
            brew install --cask tailscale
            echo -e "${GREEN}   ✓ Tailscale installed. Open Tailscale.app to configure.${NC}"
        else
            echo -e "${BLUE}   Manual installation:${NC}"
            echo "   Download from: https://tailscale.com/download/mac"
        fi
    fi
else
    echo -e "${GREEN}✓ Tailscale installed${NC}"
fi

# Colima (if Docker not installed)
if ! command -v docker &> /dev/null && ! command -v colima &> /dev/null; then
    echo -e "${YELLOW}⚠️  Colima not installed${NC}"
    echo "   Colima is a lightweight Docker alternative for macOS."
    echo ""
    read -p "   Would you like to install Colima? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v brew &> /dev/null; then
            echo "   Installing Colima..."
            brew install colima docker
            echo -e "${GREEN}   ✓ Colima installed. Run 'colima start' to begin.${NC}"
        else
            echo "   Please install Homebrew first: https://brew.sh"
        fi
    fi
fi

# Pi-hole
if ! docker images --format '{{.Repository}}' 2>/dev/null | grep -q "pihole"; then
    echo -e "${YELLOW}⚠️  Pi-hole not installed${NC}"
    echo "   Pi-hole provides network-wide ad blocking and DNS filtering."
    echo ""
    read -p "   Would you like installation instructions for Pi-hole? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}   Pi-hole Docker Installation:${NC}"
        echo "   docker run -d --name pihole \\"
        echo "     -p 53:53/tcp -p 53:53/udp \\"
        echo "     -p 8080:80/tcp \\"
        echo "     -e TZ=America/Los_Angeles \\"
        echo "     -e WEBPASSWORD=yourpassword \\"
        echo "     --restart=unless-stopped \\"
        echo "     pihole/pihole:latest"
        echo ""
        echo "   Or use docker-compose. See: https://github.com/pi-hole/docker-pi-hole"
        echo ""
    fi
else
    echo -e "${GREEN}✓ Pi-hole installed${NC}"
fi

# Plex
if ! docker images --format '{{.Repository}}' 2>/dev/null | grep -q "plex" && ! [ -d "/Applications/Plex Media Server.app" ]; then
    echo -e "${YELLOW}⚠️  Plex Media Server not installed${NC}"
    echo "   Plex organizes and streams your media library."
    echo ""
    read -p "   Would you like installation instructions for Plex? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}   Plex Installation Options:${NC}"
        echo "   1. Desktop App: https://www.plex.tv/media-server-downloads/"
        echo "   2. Docker: docker run -d --name plex -p 32400:32400 plexinc/pms-docker"
        echo ""
    fi
else
    echo -e "${GREEN}✓ Plex installed${NC}"
fi

echo ""

# Copy template to config
echo -e "${BLUE}→ Creating configuration file...${NC}"
cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"

# Validation functions
validate_telegram_token() {
    local token="$1"
    # Telegram bot tokens format: 123456789:ABCdefGHIjklMNOpqrSTUvwxYZ
    if [[ "$token" =~ ^[0-9]{8,10}:[A-Za-z0-9_-]{35}$ ]]; then
        return 0
    else
        echo -e "${RED}Invalid Telegram token format${NC}"
        echo "Expected format: 1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ"
        return 1
    fi
}

validate_telegram_chat_id() {
    local chat_id="$1"
    # Chat ID should be numeric (can be negative for groups)
    if [[ "$chat_id" =~ ^-?[0-9]+$ ]]; then
        return 0
    else
        echo -e "${RED}Invalid chat ID format${NC}"
        echo "Chat ID should be a number (e.g., 123456789 or -987654321)"
        return 1
    fi
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        echo -e "${RED}Invalid port number${NC}"
        echo "Port must be between 1024 and 65535"
        return 1
    fi
}

validate_path() {
    local path="$1"
    local allow_missing="${2:-false}"

    # Expand ~ to home directory
    path="${path/#\~/$HOME}"

    if [ -e "$path" ]; then
        return 0
    elif [ "$allow_missing" = "true" ]; then
        return 0
    else
        echo -e "${YELLOW}Warning: Path does not exist: $path${NC}"
        return 1
    fi
}

# Function to update JSON value
update_json() {
    local file="$1"
    local key="$2"
    local value="$3"
    local type="${4:-string}"  # string, number, boolean

    python3 -c "
import json
import sys

with open('$file', 'r') as f:
    config = json.load(f)

keys = '$key'.split('.')
obj = config
for k in keys[:-1]:
    obj = obj[k]

if '$type' == 'number':
    obj[keys[-1]] = $value
elif '$type' == 'boolean':
    obj[keys[-1]] = $value
else:
    obj[keys[-1]] = '$value'

with open('$file', 'w') as f:
    json.dump(config, f, indent=2)
"
}

# Get user input
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Configuration Questions                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

# Telegram configuration
echo -e "${YELLOW}═══ Telegram Notifications ═══${NC}"
read -p "Enable Telegram notifications? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    update_json "$CONFIG_FILE" "notifications.telegram.enabled" "True" "boolean"

    echo -e "\n${BLUE}To get your Telegram bot token:${NC}"
    echo "  1. Open Telegram and search for @BotFather"
    echo "  2. Send /newbot and follow instructions"
    echo "  3. Copy the bot token\n"

    while true; do
        read -p "Enter Telegram Bot Token: " TELEGRAM_TOKEN
        if validate_telegram_token "$TELEGRAM_TOKEN"; then
            update_json "$CONFIG_FILE" "notifications.telegram.bot_token" "$TELEGRAM_TOKEN"
            break
        fi
        echo "Please try again."
    done

    echo -e "\n${BLUE}To get your Chat ID:${NC}"
    echo "  1. Search for @userinfobot in Telegram"
    echo "  2. Send /start"
    echo "  3. Copy your ID\n"

    while true; do
        read -p "Enter Telegram Chat ID: " TELEGRAM_CHAT_ID
        if validate_telegram_chat_id "$TELEGRAM_CHAT_ID"; then
            update_json "$CONFIG_FILE" "notifications.telegram.chat_id" "$TELEGRAM_CHAT_ID"
            break
        fi
        echo "Please try again."
    done
else
    update_json "$CONFIG_FILE" "notifications.telegram.enabled" "False" "boolean"
fi

# Dashboard authentication
echo -e "\n${YELLOW}═══ Dashboard Authentication ═══${NC}"
read -p "Enter dashboard username (default: admin): " DASHBOARD_USER
DASHBOARD_USER=${DASHBOARD_USER:-admin}
update_json "$CONFIG_FILE" "dashboard_auth.username" "$DASHBOARD_USER"

while true; do
    echo -n "Enter dashboard password (min 8 characters): "
    read -s DASHBOARD_PASS
    echo

    if [ -z "$DASHBOARD_PASS" ]; then
        DASHBOARD_PASS="matrix2026"
        echo -e "${YELLOW}Using default password: matrix2026 (PLEASE CHANGE THIS!)${NC}"
        break
    elif [ ${#DASHBOARD_PASS} -lt 8 ]; then
        echo -e "${RED}Password too short. Must be at least 8 characters.${NC}"
        continue
    else
        # Confirm password
        echo -n "Confirm dashboard password: "
        read -s DASHBOARD_PASS_CONFIRM
        echo

        if [ "$DASHBOARD_PASS" != "$DASHBOARD_PASS_CONFIRM" ]; then
            echo -e "${RED}Passwords do not match. Please try again.${NC}"
            continue
        fi
        break
    fi
done

# Hash the password
PASSWORD_HASH=$(echo -n "$DASHBOARD_PASS" | shasum -a 256 | awk '{print $1}')
update_json "$CONFIG_FILE" "dashboard_auth.password_hash" "$PASSWORD_HASH"

# Backup scripts
echo -e "\n${YELLOW}═══ Backup Configuration ═══${NC}"
echo "Enter paths to your backup scripts (or press Enter to skip):"

while true; do
    read -p "Google Drive backup script path [$HOME/backup_documents_to_gdrive.sh]: " GD_SCRIPT
    GD_SCRIPT=${GD_SCRIPT:-$HOME/backup_documents_to_gdrive.sh}

    # Expand ~ to home directory
    GD_SCRIPT="${GD_SCRIPT/#\~/$HOME}"

    if [ -z "$GD_SCRIPT" ] || validate_path "$GD_SCRIPT" true; then
        update_json "$CONFIG_FILE" "backup.scripts.google_drive" "$GD_SCRIPT"
        break
    fi

    read -p "Path not found. Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_json "$CONFIG_FILE" "backup.scripts.google_drive" "$GD_SCRIPT"
        break
    fi
done

while true; do
    read -p "EVM backup script path [$HOME/backup_documents_to_evm.sh]: " EVM_SCRIPT
    EVM_SCRIPT=${EVM_SCRIPT:-$HOME/backup_documents_to_evm.sh}

    # Expand ~ to home directory
    EVM_SCRIPT="${EVM_SCRIPT/#\~/$HOME}"

    if [ -z "$EVM_SCRIPT" ] || validate_path "$EVM_SCRIPT" true; then
        update_json "$CONFIG_FILE" "backup.scripts.evm_drive" "$EVM_SCRIPT"
        break
    fi

    read -p "Path not found. Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_json "$CONFIG_FILE" "backup.scripts.evm_drive" "$EVM_SCRIPT"
        break
    fi
done

# Dashboard port
echo -e "\n${YELLOW}═══ Dashboard Settings ═══${NC}"
while true; do
    read -p "Dashboard port (default: 8888): " DASHBOARD_PORT
    DASHBOARD_PORT=${DASHBOARD_PORT:-8888}

    if validate_port "$DASHBOARD_PORT"; then
        # Check if port is available
        if lsof -Pi :$DASHBOARD_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo -e "${YELLOW}Warning: Port $DASHBOARD_PORT is currently in use${NC}"
            read -p "Use it anyway? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                update_json "$CONFIG_FILE" "services.dashboard.port" "$DASHBOARD_PORT" "number"
                break
            fi
        else
            update_json "$CONFIG_FILE" "services.dashboard.port" "$DASHBOARD_PORT" "number"
            break
        fi
    fi
done

# Expand environment variables in paths
echo -e "\n${BLUE}→ Expanding environment variables in config...${NC}"
sed -i.bak "s|\${HOME}|$HOME|g" "$CONFIG_FILE"
sed -i.bak "s|\${USER}|$USER|g" "$CONFIG_FILE"

# Replace template install path with actual detected path
DETECTED_INSTALL_PATH="$SCRIPT_DIR"
sed -i.bak "s|\${HOME}/Claude-Code/System-Matrix|$DETECTED_INSTALL_PATH|g" "$CONFIG_FILE"

rm -f "$CONFIG_FILE.bak"

echo -e "${GREEN}✓ Configuration file created: $CONFIG_FILE${NC}\n"

# Create LaunchAgents
echo -e "${BLUE}→ Creating LaunchAgent files...${NC}"

# Detect Python path (for M1 Mac compatibility)
PYTHON_PATH=$(command -v python3)
if [ -z "$PYTHON_PATH" ]; then
    PYTHON_PATH="/usr/bin/python3"
    echo -e "${YELLOW}  ⚠️  Python3 not found in PATH, using default /usr/bin/python3${NC}"
else
    echo -e "${GREEN}  ✓ Using Python at: $PYTHON_PATH${NC}"
fi

# Unified automation LaunchAgent
cat > "$CONFIG_DIR/launchagents/com.securitylab.unified.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.securitylab.unified</string>

    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/scripts/automation/unified-automation.sh</string>
    </array>

    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key>
            <integer>3</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>

    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/logs/unified-automation-launchagent.log</string>

    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/logs/unified-automation-error.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin</string>
    </dict>
</dict>
</plist>
EOF

# Dashboard LaunchAgent
cat > "$CONFIG_DIR/launchagents/com.securitylab.dashboard.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.securitylab.dashboard</string>

    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON_PATH</string>
        <string>$SCRIPT_DIR/scripts/monitoring/dashboard-server.py</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/logs/dashboard-server-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/logs/dashboard-server-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin</string>
    </dict>
</dict>
</plist>
EOF

echo -e "${GREEN}✓ LaunchAgent files created${NC}\n"

# Offer to install LaunchAgents
echo -e "${YELLOW}═══ LaunchAgent Installation ═══${NC}"
read -p "Install LaunchAgents now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cp "$CONFIG_DIR/launchagents/com.securitylab.unified.plist" "$HOME/Library/LaunchAgents/"
    cp "$CONFIG_DIR/launchagents/com.securitylab.dashboard.plist" "$HOME/Library/LaunchAgents/"

    launchctl load "$HOME/Library/LaunchAgents/com.securitylab.dashboard.plist" 2>/dev/null || true
    launchctl load "$HOME/Library/LaunchAgents/com.securitylab.unified.plist" 2>/dev/null || true

    echo -e "${GREEN}✓ LaunchAgents installed and loaded${NC}"
else
    echo -e "${YELLOW}  → LaunchAgent files are in: $CONFIG_DIR/launchagents/${NC}"
    echo -e "${YELLOW}  → Copy them to ~/Library/LaunchAgents/ manually${NC}"
fi

# Create .gitignore
echo -e "\n${BLUE}→ Creating .gitignore...${NC}"
cat > "$SCRIPT_DIR/.gitignore" << 'EOF'
# Configuration files with secrets
config/config.json
config/.dashboard_auth

# Runtime logs
logs/*.log
logs/**/*.log
logs/cache/
logs/alert-state/
logs/metrics-state/
logs/automation-status.json
logs/*.lock
logs/*.pid

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python

# Backup files
*.bak
*.backup
*~
.cleanup-backup-*

# OS files
.DS_Store
.AppleDouble
.LSOverride
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Temporary files
*.tmp
.cache/

# Environment variables
.env
.env.local
EOF

echo -e "${GREEN}✓ .gitignore created${NC}\n"

# Summary
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Setup Complete! ✓                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Next Steps:${NC}\n"
echo "1. Review your configuration:"
echo "   ${YELLOW}cat $CONFIG_FILE${NC}\n"

echo "2. Start the dashboard server:"
echo "   ${YELLOW}launchctl start com.securitylab.dashboard${NC}"
echo "   Or run manually: ${YELLOW}python3 $SCRIPT_DIR/scripts/monitoring/dashboard-server.py${NC}\n"

echo "3. Access the dashboard:"
echo "   ${YELLOW}http://localhost:${DASHBOARD_PORT}${NC}"
echo "   Username: ${YELLOW}${DASHBOARD_USER}${NC}"
echo "   Password: ${YELLOW}[your password]${NC}\n"

echo "4. Test automation manually:"
echo "   ${YELLOW}$SCRIPT_DIR/scripts/automation/unified-automation.sh${NC}\n"

echo "5. Test Telegram notifications (if enabled):"
echo "   ${YELLOW}$SCRIPT_DIR/scripts/notifications/send-telegram-alert.sh info test 'Setup complete!'${NC}\n"

echo -e "${GREEN}Documentation:${NC}"
echo "  • README: $SCRIPT_DIR/README.md"
echo "  • Configuration Guide: $SCRIPT_DIR/docs/setup/CONFIGURATION.md"
echo "  • Alert System: $SCRIPT_DIR/docs/guides/ALERT_SYSTEM_GUIDE.md\n"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
