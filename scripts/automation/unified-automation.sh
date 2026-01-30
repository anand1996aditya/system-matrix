#!/bin/bash
# Unified Automation Script - Config-Aware Version
# Runs all maintenance tasks in parallel with centralized configuration

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utilities/config-loader.sh"

# Get paths from config
LOG_DIR="$CONFIG_LOGS_DIR"
DATE=$(date +%Y%m%d-%H%M%S)
MAIN_LOG="$LOG_DIR/unified-automation.log"
STATUS_FILE="$LOG_DIR/automation-status.json"
LOCK_FILE="$LOG_DIR/unified-automation.lock"
PID_FILE="$LOG_DIR/unified-automation.pid"

# Get backup configuration
GDRIVE_SCRIPT=$(get_config "backup.scripts.google_drive")
EVM_SCRIPT=$(get_config "backup.scripts.evm_drive")
MIN_DISK_SPACE=$(get_config_default "backup.settings.min_disk_space_gb" "10")

# Get automation settings
DOCKER_ENABLED=$(get_config_default "services.docker.enabled" "true")

# Ensure directories exist
mkdir -p "$LOG_DIR"

# ============================================
# EDGE CASE 1: Prevent simultaneous runs
# ============================================
if [ -f "$LOCK_FILE" ]; then
    # Check if the process is actually running
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Another instance is running (PID: $OLD_PID). Exiting." >> "$MAIN_LOG"
            exit 0
        else
            # Stale lock file, remove it
            rm -f "$LOCK_FILE" "$PID_FILE"
        fi
    else
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file and PID file
touch "$LOCK_FILE"
echo $$ > "$PID_FILE"

# Cleanup on exit
trap "rm -f $LOCK_FILE $PID_FILE" EXIT INT TERM

# Check if tasks are enabled from config
TASK_BACKUP=$(get_config_default "automation.unified_script.tasks.backup" "true")
TASK_DOCKER=$(get_config_default "automation.unified_script.tasks.docker_cleanup" "true")
TASK_LOGS=$(get_config_default "automation.unified_script.tasks.log_rotation" "true")
TASK_PIHOLE=$(get_config_default "automation.unified_script.tasks.pihole_update" "true")
TASK_HEALTH=$(get_config_default "automation.unified_script.tasks.health_check" "true")
TASK_PERF=$(get_config_default "automation.unified_script.tasks.performance_check" "true")
TASK_DRIVES=$(get_config_default "automation.unified_script.tasks.external_drives_check" "true")

# Get timeouts from config
TIMEOUT_DOCKER=$(get_config_default "automation.unified_script.timeouts.docker_cleanup" "60")
TIMEOUT_LOGS=$(get_config_default "automation.unified_script.timeouts.log_rotation" "30")
TIMEOUT_PIHOLE=$(get_config_default "automation.unified_script.timeouts.pihole_update" "120")
TIMEOUT_HEALTH=$(get_config_default "automation.unified_script.timeouts.health_check" "30")
TIMEOUT_PERF=$(get_config_default "automation.unified_script.timeouts.performance_check" "30")
TIMEOUT_DRIVES=$(get_config_default "automation.unified_script.timeouts.external_drives" "30")

# Initialize status file with progress tracking
STARTED_TIME=$(date '+%Y-%m-%d %H:%M:%S')
cat > "$STATUS_FILE" << EOF
{
  "running": true,
  "started": "$STARTED_TIME",
  "ended": null,
  "current_task": "Initializing automation...",
  "current_task_name": "Initialization",
  "progress": 0,
  "total_tasks": 8,
  "completed_tasks": 0,
  "tasks": {
    "Backup - Google Drive": {"status": "pending", "message": "Waiting...", "timestamp": ""},
    "Backup - EVM Drive": {"status": "pending", "message": "Waiting...", "timestamp": ""},
    "Docker Cleanup": {"status": "pending", "message": "Waiting...", "timestamp": ""},
    "Log Rotation": {"status": "pending", "message": "Waiting...", "timestamp": ""},
    "Pi-hole Update": {"status": "pending", "message": "Waiting...", "timestamp": ""},
    "Health Check": {"status": "pending", "message": "Waiting...", "timestamp": ""},
    "Performance Check": {"status": "pending", "message": "Waiting...", "timestamp": ""},
    "External Drives": {"status": "pending", "message": "Waiting...", "timestamp": ""}
  }
}
EOF

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAIN_LOG"
}

# Function to update status file for dashboard
update_status() {
    local task="$1"
    local status="$2"  # pending, running, success, warning, error, skipped
    local message="$3"

    python3 -c "
import json
import sys

try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)

    data['current_task_name'] = '$task'
    data['current_task'] = '$task: $message'
    data['tasks']['$task'] = {
        'status': '$status',
        'message': '$message',
        'timestamp': '$(date '+%Y-%m-%d %H:%M:%S')'
    }

    # Update progress
    if '$status' == 'success':
        data['completed_tasks'] = data.get('completed_tasks', 0) + 1
        total = data.get('total_tasks', 15)
        data['progress'] = int((data['completed_tasks'] / total) * 100)

    with open('$STATUS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
except:
    pass
" 2>/dev/null
}

log "=========================================="
log "Starting Unified Automation (Config-Aware)"
log "=========================================="

# ============================================
# WAIT FOR DOCKER SERVICES TO BE READY
# ============================================
wait_for_services() {
    log "Checking if Docker services are ready..."

    # If Docker is not running, skip waiting
    if ! docker info > /dev/null 2>&1; then
        log "⚠️  Docker not running, skipping service wait"
        return 1
    fi

    # Wait up to 5 minutes for services to be healthy
    for i in {1..60}; do
        # Check if containers are running and healthy
        if docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null | grep -q "healthy"; then
            log "✅ Docker services are healthy, proceeding..."
            return 0
        fi

        # Also check if containers are at least running (may not have healthcheck)
        if docker ps 2>/dev/null | grep -qE "pihole|plex|postgres|redis"; then
            log "✅ Docker services are running, proceeding..."
            return 0
        fi

        sleep 5
    done

    log "⚠️  Warning: Docker services not fully ready after 5 minutes, proceeding anyway..."
    return 1
}

# Wait for services before starting tasks
if [ "$DOCKER_ENABLED" = "true" ]; then
    wait_for_services
fi

# ============================================
# TASK 1: BACKUP - Trigger existing backup scripts (NON-BLOCKING)
# ============================================
backup_task() {
    local LOG_FILE="$LOG_DIR/backup.log"
    local MAX_WAIT=300  # Wait max 5 minutes for backup to start properly

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] Initiating backups..." | tee -a "$LOG_FILE"

    # EDGE CASE: Check if backup is already running
    if ps aux | grep -E "backup_documents_to_gdrive|backup_documents_to_evm" | grep -v grep > /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ⚠️  Backup already in progress, skipping..." | tee -a "$LOG_FILE"
        return 0
    fi

    # EDGE CASE: Check available disk space before backup
    DOCUMENTS_DIR=$(get_config "backup.paths.documents")
    AVAILABLE_GB=$(df -g "$DOCUMENTS_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo 100)
    if [ "$AVAILABLE_GB" -lt "$MIN_DISK_SPACE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ⚠️  Low disk space (${AVAILABLE_GB}GB), skipping backup" | tee -a "$LOG_FILE"
        return 1
    fi

    # Start Google Drive backup in background (fire and forget)
    if [ -f "$GDRIVE_SCRIPT" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] Starting Google Drive backup (background)..." | tee -a "$LOG_FILE"
        update_status "Backup - Google Drive" "running" "Uploading to cloud..."
        nohup "$GDRIVE_SCRIPT" >> "$LOG_FILE" 2>&1 &
        GDRIVE_PID=$!
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ✓ Google Drive backup started (PID: $GDRIVE_PID)" | tee -a "$LOG_FILE"
        update_status "Backup - Google Drive" "success" "Running in background (PID: $GDRIVE_PID)"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ⚠️  Google Drive backup script not found at $GDRIVE_SCRIPT" | tee -a "$LOG_FILE"
        update_status "Backup - Google Drive" "skipped" "Script not found"
        GDRIVE_PID=""
    fi

    # Start EVM drive backup in background (fire and forget)
    EVM_MOUNT=$(get_config "backup.paths.evm_mount")
    if [ -f "$EVM_SCRIPT" ]; then
        if [ -d "$EVM_MOUNT" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] Starting EVM drive backup (background)..." | tee -a "$LOG_FILE"
            update_status "Backup - EVM Drive" "running" "Backing up to EVM..."
            nohup "$EVM_SCRIPT" >> "$LOG_FILE" 2>&1 &
            EVM_PID=$!
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ✓ EVM drive backup started (PID: $EVM_PID)" | tee -a "$LOG_FILE"
            update_status "Backup - EVM Drive" "success" "Running in background (PID: $EVM_PID)"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ⚠️  EVM drive not mounted at $EVM_MOUNT, skipping" | tee -a "$LOG_FILE"
            update_status "Backup - EVM Drive" "skipped" "EVM drive not mounted"
            EVM_PID=""
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ⚠️  EVM backup script not found at $EVM_SCRIPT" | tee -a "$LOG_FILE"
        update_status "Backup - EVM Drive" "skipped" "Script not found"
        EVM_PID=""
    fi

    # DON'T WAIT - let backups run in background
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] ✅ Backup tasks initiated (running independently)" | tee -a "$LOG_FILE"
    BACKUP_LOGS=$(get_config "paths.backup_logs_dir")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] Check backup status: tail -f $BACKUP_LOGS/backup_*.log" | tee -a "$LOG_FILE"
}

# ============================================
# TASK 2: DOCKER CLEANUP (runs in background)
# ============================================
docker_cleanup_task() {
    local LOG_FILE="$LOG_DIR/docker-cleanup.log"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] Starting cleanup..." | tee -a "$LOG_FILE"
    update_status "Docker Cleanup" "running" "Removing unused containers..."

    # EDGE CASE: Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] ⚠️  Docker not running, skipping cleanup" | tee -a "$LOG_FILE"
        update_status "Docker Cleanup" "skipped" "Docker not running"
        return 1
    fi

    # EDGE CASE: Check if cleanup is safe (not during critical operations)
    RUNNING_CONTAINERS=$(docker ps -q | wc -l | tr -d ' ')
    if [ "$RUNNING_CONTAINERS" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] No containers running, safe to cleanup" | tee -a "$LOG_FILE"
    fi

    docker container prune -f >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] Container prune failed" | tee -a "$LOG_FILE"
    docker image prune -a -f >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] Image prune failed" | tee -a "$LOG_FILE"
    docker volume prune -f >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] Volume prune failed" | tee -a "$LOG_FILE"
    docker builder prune -f >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] Builder prune failed" | tee -a "$LOG_FILE"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKER] ✅ Cleanup complete" | tee -a "$LOG_FILE"
    update_status "Docker Cleanup" "success" "Cleanup completed"
}

# ============================================
# TASK 3: LOG ROTATION (runs in background)
# ============================================
log_rotation_task() {
    local MAX_SIZE=10485760  # 10MB
    local ROTATED_COUNT=0
    local DELETED_COUNT=0

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [LOGS] Starting log rotation..."
    update_status "Log Rotation" "running" "Checking log files..."

    # Check and rotate large logs
    for logfile in "$LOG_DIR"/*.log; do
        if [ -f "$logfile" ]; then
            local size=$(stat -f%z "$logfile" 2>/dev/null || echo 0)
            local size_mb=$((size / 1048576))

            if [ "$size" -gt "$MAX_SIZE" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [LOGS] Rotating $(basename $logfile) (${size_mb}MB)"

                if mv "$logfile" "${logfile}.1" 2>/dev/null && touch "$logfile" && gzip "${logfile}.1" 2>/dev/null; then
                    ROTATED_COUNT=$((ROTATED_COUNT + 1))
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [LOGS] ✓ Rotated: $(basename $logfile)"
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [LOGS] ⚠️  Failed to rotate: $(basename $logfile)"
                fi
            fi
        fi
    done

    # Cleanup old rotated logs (>30 days)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [LOGS] Cleaning up old rotated logs..."
    DELETED_COUNT=$(find "$LOG_DIR" -name "*.log.*.gz" -mtime +30 -type f 2>/dev/null | wc -l | tr -d ' ')
    find "$LOG_DIR" -name "*.log.*.gz" -mtime +30 -delete 2>/dev/null

    # Build status message
    if [ "$ROTATED_COUNT" -gt 0 ] || [ "$DELETED_COUNT" -gt 0 ]; then
        local message="Rotated: ${ROTATED_COUNT} files, Deleted: ${DELETED_COUNT} old files"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [LOGS] ✅ $message"
        update_status "Log Rotation" "success" "$message"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [LOGS] ✅ All logs within size limits"
        update_status "Log Rotation" "success" "No rotation needed (all logs < 10MB)"
    fi
}

# ============================================
# TASK 4: PI-HOLE UPDATE (runs in background)
# ============================================
pihole_update_task() {
    local LOG_FILE="$LOG_DIR/pihole-updates.log"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] Starting update..." | tee -a "$LOG_FILE"
    update_status "Pi-hole Update" "running" "Checking Pi-hole container..."

    if docker ps | grep -q pihole; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] Container found, updating blocklists..." | tee -a "$LOG_FILE"
        update_status "Pi-hole Update" "running" "Updating blocklists..."

        # Update blocklists
        if docker exec pihole pihole -g >> "$LOG_FILE" 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] Blocklists updated" | tee -a "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] ⚠️  Blocklist update had issues" | tee -a "$LOG_FILE"
        fi

        # Update gravity
        update_status "Pi-hole Update" "running" "Updating gravity database..."
        if docker exec pihole pihole updateGravity >> "$LOG_FILE" 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] Gravity updated" | tee -a "$LOG_FILE"
        fi

        # Get blocked domain count
        DOMAINS=$(docker exec pihole pihole -g 2>&1 | grep "domains being blocked" | awk '{print $1}' | head -1)
        if [ -n "$DOMAINS" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] ✅ Update complete - $DOMAINS domains blocked" | tee -a "$LOG_FILE"
            update_status "Pi-hole Update" "success" "Updated - $DOMAINS domains blocked"
            osascript -e "display notification \"$DOMAINS domains blocked\" with title \"Pi-hole Updated\"" 2>/dev/null || true
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] ✅ Update complete" | tee -a "$LOG_FILE"
            update_status "Pi-hole Update" "success" "Blocklists and gravity updated"
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIHOLE] Container not running, skipping" | tee -a "$LOG_FILE"
        update_status "Pi-hole Update" "skipped" "Container not running"
    fi
}

# ============================================
# TASK 5: HEALTH CHECK (runs in background)
# ============================================
health_check_task() {
    local LOG_FILE="$LOG_DIR/health-check.log"
    local ISSUES=0

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] Checking services..." | tee -a "$LOG_FILE"
    update_status "Health Check" "checking" "Checking all services..."

    # Get enabled services from config
    DOCKER_CONTAINERS=$(get_config "services.docker.containers")

    # Check Docker
    update_status "Docker" "checking" "Checking Docker daemon..."
    if ! docker info &> /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] ❌ Docker not running" | tee -a "$LOG_FILE"
        update_status "Docker" "error" "Not running"
        ISSUES=$((ISSUES + 1))
    else
        update_status "Docker" "success" "Running"
    fi

    # Check containers
    for container in pihole plex sentinel-postgres sentinel-redis; do
        # Capitalize first letter (macOS bash 3.2 compatible)
        container_name="$(echo "$container" | sed 's/^./\U&/')"
        update_status "$container_name" "checking" "Checking container..."
        if ! docker ps | grep -q "$container"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] ❌ $container not running" | tee -a "$LOG_FILE"
            docker start "$container" >> "$LOG_FILE" 2>&1
            update_status "$container_name" "warning" "Restarted"
            ISSUES=$((ISSUES + 1))
        else
            update_status "$container_name" "success" "Running"
        fi
    done

    # Check dashboard
    DASHBOARD_PORT=$(get_config "services.dashboard.port")
    update_status "Dashboard" "checking" "Checking dashboard..."
    if ! lsof -i:"$DASHBOARD_PORT" > /dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] ❌ Dashboard server not running on port $DASHBOARD_PORT" | tee -a "$LOG_FILE"
        update_status "Dashboard" "error" "Not running"
        ISSUES=$((ISSUES + 1))
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] ✅ Dashboard server running" | tee -a "$LOG_FILE"
        update_status "Dashboard" "success" "Running"
    fi

    if [ "$ISSUES" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] ✅ All services healthy" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HEALTH] ⚠️  $ISSUES issue(s) detected" | tee -a "$LOG_FILE"
        osascript -e "display notification \"$ISSUES service issues detected\" with title \"Health Check\"" 2>/dev/null
    fi
}

# ============================================
# TASK 6: PERFORMANCE CHECK (runs in background)
# ============================================
performance_check_task() {
    local LOG_FILE="$LOG_DIR/performance.log"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PERF] Performance check..." | tee -a "$LOG_FILE"

    # Load average
    LOAD=$(uptime | awk -F'load averages:' '{print $2}')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PERF] Load:$LOAD" | tee -a "$LOG_FILE"

    # CPU usage
    CPU_INFO=$(top -l 1 | grep "CPU usage")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PERF] $CPU_INFO" | tee -a "$LOG_FILE"

    # Memory
    MEMORY=$(top -l 1 | grep PhysMem)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PERF] $MEMORY" | tee -a "$LOG_FILE"

    # Disk
    DISK=$(df -h / | tail -1 | awk '{print "Used: "$3" Free: "$4" ("$5")"}')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PERF] Disk: $DISK" | tee -a "$LOG_FILE"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PERF] ✅ Check complete" | tee -a "$LOG_FILE"
}

# ============================================
# TASK 7: EXTERNAL DRIVES CHECK (runs in background)
# ============================================
external_drives_check() {
    local LOG_FILE="$LOG_DIR/external-drives.log"
    local ISSUES=0
    local MOUNTED_COUNT=0
    local TOTAL_COUNT=0

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] Checking external drives..." | tee -a "$LOG_FILE"
    update_status "External Drives" "running" "Scanning for external drives..."

    # Check /Volumes for mounted drives (macOS)
    VOLUMES_COUNT=$(ls -1 /Volumes 2>/dev/null | grep -v "Macintosh HD" | wc -l | tr -d ' ')

    if [ "$VOLUMES_COUNT" -gt 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] Found $VOLUMES_COUNT external volume(s)" | tee -a "$LOG_FILE"

        for drive in /Volumes/*; do
            if [ -d "$drive" ] && [ "$(basename "$drive")" != "Macintosh HD" ]; then
                DRIVE_NAME=$(basename "$drive")
                TOTAL_COUNT=$((TOTAL_COUNT + 1))

                if [ -r "$drive" ]; then
                    SPACE=$(df -h "$drive" 2>/dev/null | tail -1 | awk '{print $4}')
                    PERCENT=$(df -h "$drive" 2>/dev/null | tail -1 | awk '{print $5}')
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] ✅ $DRIVE_NAME: $SPACE free ($PERCENT used)" | tee -a "$LOG_FILE"
                    MOUNTED_COUNT=$((MOUNTED_COUNT + 1))
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] ⚠️  $DRIVE_NAME: Not accessible" | tee -a "$LOG_FILE"
                    ISSUES=$((ISSUES + 1))
                fi
            fi
        done
    fi

    # Also check drives from config if specified
    DRIVE_COUNT=$(get_config "drives.custom_drives" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(len([x for x in d if x.get('enabled', False)]))" 2>/dev/null || echo 0)

    if [ "$DRIVE_COUNT" -gt 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] Checking $DRIVE_COUNT configured drive(s)..." | tee -a "$LOG_FILE"

        for i in $(seq 0 $((DRIVE_COUNT - 1))); do
            DRIVE_NAME=$(get_config "drives.custom_drives.$i.name" 2>/dev/null)
            DRIVE_PATH=$(get_config "drives.custom_drives.$i.path" 2>/dev/null)
            DRIVE_ENABLED=$(get_config "drives.custom_drives.$i.enabled" 2>/dev/null)

            if [ "$DRIVE_ENABLED" = "true" ] && [ -d "$DRIVE_PATH" ]; then
                SPACE=$(df -h "$DRIVE_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
                PERCENT=$(df -h "$DRIVE_PATH" 2>/dev/null | tail -1 | awk '{print $5}')
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] ✅ $DRIVE_NAME: $SPACE free ($PERCENT used)" | tee -a "$LOG_FILE"
                TOTAL_COUNT=$((TOTAL_COUNT + 1))
                MOUNTED_COUNT=$((MOUNTED_COUNT + 1))
            elif [ "$DRIVE_ENABLED" = "true" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] ⚠️  $DRIVE_NAME not mounted at $DRIVE_PATH" | tee -a "$LOG_FILE"
                TOTAL_COUNT=$((TOTAL_COUNT + 1))
                ISSUES=$((ISSUES + 1))
            fi
        done
    fi

    # Update final status
    if [ "$TOTAL_COUNT" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] ℹ️  No external drives found" | tee -a "$LOG_FILE"
        update_status "External Drives" "info" "No external drives detected"
    elif [ "$ISSUES" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] ✅ All drives accessible ($MOUNTED_COUNT/$TOTAL_COUNT)" | tee -a "$LOG_FILE"
        update_status "External Drives" "success" "$MOUNTED_COUNT/$TOTAL_COUNT drives accessible"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DRIVES] ⚠️  $ISSUES drive(s) unavailable ($MOUNTED_COUNT/$TOTAL_COUNT accessible)" | tee -a "$LOG_FILE"
        update_status "External Drives" "warning" "$ISSUES drives unavailable ($MOUNTED_COUNT/$TOTAL_COUNT accessible)"
    fi
}

# ============================================
# RUN TASKS (backup first, then others in parallel)
# ============================================

log "Starting backup task first..."
echo ""

# Update status for backup start
python3 -c "
import json
try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
    data['current_task_name'] = 'Backups'
    data['current_task'] = 'Running backup tasks...'
    data['progress'] = 5
    with open('$STATUS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
except: pass
" 2>/dev/null

# Run backup task first (to avoid interference from docker cleanup)
if [ "$TASK_BACKUP" = "true" ]; then
    backup_task
    log "✅ Backup complete"
else
    log "⊘ Backup task disabled in config"
fi

log "Running remaining tasks in parallel..."
echo ""

# Start remaining tasks in background
if [ "$TASK_DOCKER" = "true" ]; then
    docker_cleanup_task &
    PID_DOCKER=$!
fi

if [ "$TASK_LOGS" = "true" ]; then
    log_rotation_task &
    PID_LOGS=$!
fi

if [ "$TASK_PIHOLE" = "true" ]; then
    pihole_update_task &
    PID_PIHOLE=$!
fi

if [ "$TASK_HEALTH" = "true" ]; then
    health_check_task &
    PID_HEALTH=$!
fi

if [ "$TASK_PERF" = "true" ]; then
    performance_check_task &
    PID_PERF=$!
fi

if [ "$TASK_DRIVES" = "true" ]; then
    external_drives_check &
    PID_DRIVES=$!
fi

# Wait for all parallel tasks to complete (with timeout protection)
log "Waiting for remaining tasks to complete (timeouts configured)..."

# EDGE CASE: Use simple wait for background processes
# macOS doesn't have GNU timeout by default, so we use simple wait
if [ -n "$PID_DOCKER" ]; then
    wait $PID_DOCKER 2>/dev/null && log "✅ Docker cleanup complete" || log "⚠️  Docker cleanup failed"
fi

if [ -n "$PID_LOGS" ]; then
    wait $PID_LOGS 2>/dev/null && log "✅ Log rotation complete" || log "⚠️  Log rotation failed"
fi

if [ -n "$PID_PIHOLE" ]; then
    wait $PID_PIHOLE 2>/dev/null && log "✅ Pi-hole update complete" || log "⚠️  Pi-hole update failed"
fi

if [ -n "$PID_HEALTH" ]; then
    wait $PID_HEALTH 2>/dev/null && log "✅ Health check complete" || log "⚠️  Health check failed"
fi

if [ -n "$PID_PERF" ]; then
    wait $PID_PERF 2>/dev/null && log "✅ Performance check complete" || log "⚠️  Performance check failed"
fi

if [ -n "$PID_DRIVES" ]; then
    wait $PID_DRIVES 2>/dev/null && log "✅ External drives check complete" || log "⚠️  External drives check failed"
fi

log ""
log "=========================================="
log "All tasks completed successfully!"
log "=========================================="

# EDGE CASE: Ensure completion is logged even if Python/JSON fails
# Mark automation as complete
ENDED_TIME=$(date '+%Y-%m-%d %H:%M:%S')
python3 -c "
import json
try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
    data['running'] = False
    data['ended'] = '$ENDED_TIME'
    data['completed'] = '$ENDED_TIME'
    data['current_task'] = 'Completed'
    data['current_task_name'] = 'Complete'
    data['progress'] = 100
    with open('$STATUS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    # If JSON update fails, at least log the error
    with open('$LOG_DIR/automation-error.log', 'a') as f:
        f.write('[$(date '+%Y-%m-%d %H:%M:%S')] Status update failed: {}\n'.format(str(e)))
" 2>/dev/null

# Send completion notification (suppress errors)
osascript -e 'display notification "All automation tasks completed" with title "Unified Automation" sound name "Glass"' 2>/dev/null || true

# EDGE CASE: Clean up lock files on normal exit
rm -f "$LOCK_FILE" "$PID_FILE" 2>/dev/null

exit 0
