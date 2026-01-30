#!/bin/bash

# Service Management Script with Enhanced Status Tracking
# Matches unified automation format with progress and detailed status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load config
CONFIG_FILE="$BASE_DIR/config/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Get paths from config and expand environment variables
LOGS_DIR=$(jq -r '.paths.logs_dir // "'"$BASE_DIR/logs"'"' "$CONFIG_FILE")
LOGS_DIR=$(eval echo "$LOGS_DIR")
STATUS_FILE="$LOGS_DIR/startup-status.json"

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Initialize status file with all services as pending
initialize_status() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    cat > "$STATUS_FILE" <<EOF
{
  "running": true,
  "started": "$timestamp",
  "ended": null,
  "current_task": "Initializing...",
  "current_task_name": "Initialize",
  "progress": 0,
  "total_tasks": 6,
  "completed_tasks": 0,
  "tasks": {
    "Dashboard Server": {
      "status": "pending",
      "message": "Waiting...",
      "timestamp": ""
    },
    "Unified Automation": {
      "status": "pending",
      "message": "Waiting...",
      "timestamp": ""
    },
    "Docker": {
      "status": "pending",
      "message": "Waiting...",
      "timestamp": ""
    },
    "Tailscale": {
      "status": "pending",
      "message": "Waiting...",
      "timestamp": ""
    },
    "Colima": {
      "status": "pending",
      "message": "Waiting...",
      "timestamp": ""
    },
    "Pi-hole": {
      "status": "pending",
      "message": "Waiting...",
      "timestamp": ""
    }
  }
}
EOF
}

# Function to update status file
update_status() {
    local service="$1"
    local status="$2"
    local message="$3"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    jq --arg service "$service" \
       --arg status "$status" \
       --arg message "$message" \
       --arg timestamp "$timestamp" \
       '.tasks[$service] = {
         "status": $status,
         "message": $message,
         "timestamp": $timestamp
       }' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Update current task and progress
update_progress() {
    local current_task="$1"
    local current_task_name="$2"
    local progress="$3"
    local completed="$4"

    jq --arg current_task "$current_task" \
       --arg current_task_name "$current_task_name" \
       --argjson progress "$progress" \
       --argjson completed "$completed" \
       '.current_task = $current_task |
        .current_task_name = $current_task_name |
        .progress = $progress |
        .completed_tasks = $completed' \
       "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Function to mark as completed
mark_completed() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    jq --arg timestamp "$timestamp" \
       '.running = false |
        .ended = $timestamp |
        .completed = $timestamp |
        .current_task = "Completed" |
        .current_task_name = "Complete" |
        .progress = 100' \
       "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Function to check if LaunchAgent is loaded
is_loaded() {
    local label="$1"
    launchctl list | grep -q "$label"
    return $?
}

# Function to get LaunchAgent status
get_service_status() {
    local label="$1"
    local plist="$HOME/Library/LaunchAgents/${label}.plist"

    if [ ! -f "$plist" ]; then
        echo "not_installed"
        return 1
    fi

    if is_loaded "$label"; then
        local status_line=$(launchctl list | grep "$label")
        local pid=$(echo "$status_line" | awk '{print $1}')

        if [ "$pid" = "-" ]; then
            echo "loaded"
        else
            echo "running"
        fi
    else
        echo "stopped"
    fi
}

# Function to check and manage a service
manage_service() {
    local label="$1"
    local name="$2"
    local plist="$HOME/Library/LaunchAgents/${label}.plist"

    # Mark as checking
    update_status "$name" "checking" "Checking service status..."
    sleep 0.5  # Brief pause for UI

    if [ ! -f "$plist" ]; then
        update_status "$name" "error" "LaunchAgent not installed"
        return 1
    fi

    local status=$(get_service_status "$label")

    case $status in
        "running")
            update_status "$name" "success" "Running"
            ;;
        "loaded")
            update_status "$name" "success" "Loaded (scheduled)"
            ;;
        "stopped")
            update_status "$name" "warning" "Stopped - attempting to start..."
            if launchctl load "$plist" 2>/dev/null; then
                update_status "$name" "success" "Started successfully"
            else
                launchctl unload "$plist" 2>/dev/null
                if launchctl load "$plist" 2>/dev/null; then
                    update_status "$name" "success" "Restarted successfully"
                else
                    update_status "$name" "error" "Failed to start"
                fi
            fi
            ;;
        "not_installed")
            update_status "$name" "error" "Not installed"
            ;;
    esac
}

# Check external service (non-LaunchAgent)
check_external_service() {
    local name="$1"
    local check_command="$2"
    local check_type="$3"  # "command" or "running"

    update_status "$name" "checking" "Checking service status..."
    sleep 0.5

    if [ "$check_type" = "command" ]; then
        # Check if command exists
        if command -v $check_command &> /dev/null; then
            update_status "$name" "success" "Installed"
        else
            update_status "$name" "info" "Not installed (optional)"
        fi
    elif [ "$check_type" = "running" ]; then
        # Check if service is running
        if $check_command &> /dev/null; then
            update_status "$name" "success" "Running"
        else
            update_status "$name" "warning" "Not running"
        fi
    fi
}

# Main execution
echo "=========================================="
echo "System Matrix - Service Management"
echo "=========================================="
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Initialize status file
initialize_status

# Total tasks
TOTAL=6
COMPLETED=0

# Check LaunchAgent services
echo "[$(date '+%H:%M:%S')] Checking LaunchAgent services..."

update_progress "Dashboard Server: Checking..." "Dashboard Server" 10 $COMPLETED
manage_service "com.securitylab.dashboard" "Dashboard Server"
COMPLETED=$((COMPLETED + 1))

update_progress "Unified Automation: Checking..." "Unified Automation" 25 $COMPLETED
manage_service "com.securitylab.unified" "Unified Automation"
COMPLETED=$((COMPLETED + 1))

# Check Docker/Colima
echo ""
echo "[$(date '+%H:%M:%S')] Checking container services..."

update_progress "Docker: Checking..." "Docker" 40 $COMPLETED
check_external_service "Docker" "docker ps" "running"
COMPLETED=$((COMPLETED + 1))

update_progress "Colima: Checking..." "Colima" 55 $COMPLETED
check_external_service "Colima" "colima" "command"
COMPLETED=$((COMPLETED + 1))

# Check Tailscale
echo ""
echo "[$(date '+%H:%M:%S')] Checking network services..."

update_progress "Tailscale: Checking..." "Tailscale" 70 $COMPLETED
if command -v tailscale &> /dev/null; then
    update_status "Tailscale" "checking" "Verifying connection..."
    sleep 0.5
    if tailscale status &> /dev/null 2>&1; then
        update_status "Tailscale" "success" "Running"
    else
        update_status "Tailscale" "warning" "Not running"
    fi
else
    update_status "Tailscale" "info" "Not installed (optional)"
fi
COMPLETED=$((COMPLETED + 1))

# Check Pi-hole
update_progress "Pi-hole: Checking..." "Pi-hole" 85 $COMPLETED
if docker ps 2>/dev/null | grep -q "pihole"; then
    update_status "Pi-hole" "success" "Running (Docker)"
else
    update_status "Pi-hole" "info" "Not running (optional)"
fi
COMPLETED=$((COMPLETED + 1))

# Mark as completed
update_progress "All services checked" "Complete" 100 $COMPLETED
mark_completed

echo ""
echo "=========================================="
echo "Service check completed!"
echo "=========================================="

exit 0
