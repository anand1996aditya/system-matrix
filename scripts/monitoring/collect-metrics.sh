#!/bin/bash

# Optimized Metrics Collection Script - Config-Aware Version
# Performance improvements:
# - Parallel execution of independent operations
# - Cached Pi-hole stats (5s TTL)
# - Faster bandwidth sampling (optional)
# - Parallel ping operations
# - Reduced timeout values

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utilities/config-loader.sh"

# Get paths from config
CACHE_DIR="$CONFIG_CACHE_DIR"
mkdir -p "$CACHE_DIR"

# Get monitoring settings from config
METRICS_CACHE_TTL=$(get_config_default "monitoring.metrics_cache_ttl_seconds" "10")
PIHOLE_CACHE_TTL=$(get_config_default "monitoring.pihole_cache_ttl_seconds" "5")
BANDWIDTH_SAMPLE_INTERVAL=$(get_config_default "monitoring.bandwidth_sample_interval_seconds" "1")
PING_TIMEOUT=$(get_config_default "monitoring.ping_timeout_ms" "200")

# Get alert thresholds from config
MEM_THRESHOLD=$(get_config_default "alerts.memory_threshold_percent" "90")
DISK_THRESHOLD=$(get_config_default "alerts.disk_threshold_percent" "75")
CPU_TEMP_WARNING=$(get_config_default "alerts.cpu_temp_warning_celsius" "70")
CPU_TEMP_CRITICAL=$(get_config_default "alerts.cpu_temp_critical_celsius" "85")

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EPOCH=$(date +%s)

# Start JSON output
echo "{"
echo "  \"timestamp\": \"$TIMESTAMP\","
echo "  \"epoch\": $EPOCH,"

#=== PARALLEL OPERATION FUNCTIONS ===

# Function: Check services status (only installed services)
get_services() {
    echo "  \"services\": {"

    SERVICES_OUTPUT=""

    # Check if service auto-detection is enabled
    SHOW_ONLY_INSTALLED=$(get_config_default "services.show_only_installed" "true")

    # Pi-hole (only show if Docker image exists or container is running)
    if docker images --format '{{.Repository}}' 2>/dev/null | grep -q "pihole" || \
       docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "pihole"; then
        PIHOLE_STATUS="stopped"
        PIHOLE_HEALTH="stopped"
        PIHOLE_PORT=""
        PIHOLE_UPTIME="0"

        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pihole"; then
            PIHOLE_STATUS="running"
            PIHOLE_HEALTH=$(docker inspect pihole --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
            PIHOLE_PORT="5353 (DNS), 8080 (Web)"
            PIHOLE_UPTIME=$(docker ps --format '{{.Status}}' --filter "name=pihole" 2>/dev/null | sed 's/Up //' || echo "0")
        fi

        SERVICES_OUTPUT="${SERVICES_OUTPUT}    \"pihole\": {
      \"status\": \"$PIHOLE_STATUS\",
      \"health\": \"$PIHOLE_HEALTH\",
      \"port\": \"$PIHOLE_PORT\",
      \"uptime\": \"$PIHOLE_UPTIME\"
    },"
    fi

    # Tailscale (only show if installed)
    if command -v tailscale &> /dev/null || pgrep -x "Tailscale" > /dev/null || [ -d "/Applications/Tailscale.app" ]; then
        TAILSCALE_STATUS="stopped"
        TAILSCALE_IP=""
        TAILSCALE_EXIT="disabled"

        if pgrep -x "Tailscale" > /dev/null || pgrep -x "tailscaled" > /dev/null; then
            TAILSCALE_STATUS="running"
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -1)
            TAILSCALE_EXIT=$(tailscale status 2>/dev/null | grep "offers exit node" | wc -l | tr -d ' ')
            if [ "$TAILSCALE_EXIT" -gt 0 ]; then
                TAILSCALE_EXIT="enabled"
            else
                TAILSCALE_EXIT="disabled"
            fi
        fi

        SERVICES_OUTPUT="${SERVICES_OUTPUT}
    \"tailscale\": {
      \"status\": \"$TAILSCALE_STATUS\",
      \"ip\": \"$TAILSCALE_IP\",
      \"exit_node\": \"$TAILSCALE_EXIT\"
    },"
    fi

    # Colima (only show if installed)
    if command -v colima &> /dev/null; then
        COLIMA_STATUS="stopped"
        COLIMA_CONTAINERS=0

        if colima status > /dev/null 2>&1; then
            COLIMA_STATUS="running"
            COLIMA_CONTAINERS=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
        fi

        SERVICES_OUTPUT="${SERVICES_OUTPUT}
    \"colima\": {
      \"status\": \"$COLIMA_STATUS\",
      \"containers\": $COLIMA_CONTAINERS
    },"
    fi

    # Plex (only show if installed - check both app and docker)
    if [ -d "/Applications/Plex Media Server.app" ] || \
       docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "plex" || \
       docker images --format '{{.Repository}}' 2>/dev/null | grep -q "plex"; then
        PLEX_STATUS="stopped"
        PLEX_HEALTH="stopped"
        PLEX_PORT="32400"

        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "plex" || pgrep -f "Plex Media Server" > /dev/null; then
            PLEX_STATUS="running"
            if lsof -i :32400 > /dev/null 2>&1; then
                PLEX_HEALTH="healthy"
            else
                PLEX_HEALTH="starting"
            fi
        fi

        SERVICES_OUTPUT="${SERVICES_OUTPUT}
    \"plex\": {
      \"status\": \"$PLEX_STATUS\",
      \"health\": \"$PLEX_HEALTH\",
      \"port\": \"$PLEX_PORT\"
    },"
    fi

    # Caddy (only show if installed)
    if command -v caddy &> /dev/null || pgrep -x "caddy" > /dev/null; then
        CADDY_STATUS="stopped"
        CADDY_HEALTH="stopped"
        CADDY_PORT="8443"

        if pgrep -x "caddy" > /dev/null; then
            CADDY_STATUS="running"
            if lsof -i :8443 > /dev/null 2>&1; then
                CADDY_HEALTH="healthy"
            else
                CADDY_HEALTH="starting"
            fi
        fi

        SERVICES_OUTPUT="${SERVICES_OUTPUT}
    \"caddy\": {
      \"status\": \"$CADDY_STATUS\",
      \"health\": \"$CADDY_HEALTH\",
      \"port\": \"$CADDY_PORT\"
    },"
    fi

    # ClawdBot (only show if installed)
    if pgrep -f "clawdbot" > /dev/null || [ -d "$HOME/.clawdbot" ] || command -v clawdbot &> /dev/null; then
        CLAWDBOT_STATUS="stopped"
        CLAWDBOT_HEALTH="stopped"
        CLAWDBOT_PORT="18789"

        if pgrep -f "clawdbot-gateway" > /dev/null; then
            CLAWDBOT_STATUS="running"
            if lsof -i :18789 > /dev/null 2>&1; then
                CLAWDBOT_HEALTH="healthy"
            else
                CLAWDBOT_HEALTH="starting"
            fi
        fi

        SERVICES_OUTPUT="${SERVICES_OUTPUT}
    \"clawdbot\": {
      \"status\": \"$CLAWDBOT_STATUS\",
      \"health\": \"$CLAWDBOT_HEALTH\",
      \"port\": \"$CLAWDBOT_PORT\"
    },"
    fi

    # Remove trailing comma from LAST line only and output
    if [ -n "$SERVICES_OUTPUT" ]; then
        echo "$SERVICES_OUTPUT" | sed '$s/,$//'
    fi

    echo "  },"
}

# Function: Get system resources (CPU, Memory, Disk) - keeping existing logic
get_resources() {
    echo "  \"resources\": {"

    # CPU (single top call)
    TOP_OUTPUT=$(top -l 1)
    CPU_LINE=$(echo "$TOP_OUTPUT" | grep "CPU usage")
    CPU_USER=$(echo "$CPU_LINE" | awk '{print $3}' | sed 's/%//')
    CPU_SYS=$(echo "$CPU_LINE" | awk '{print $5}' | sed 's/%//')
    CPU_IDLE=$(echo "$CPU_LINE" | awk '{print $7}' | sed 's/%//')

    LOAD_AVG=$(sysctl -n vm.loadavg)
    LOAD_1=$(echo "$LOAD_AVG" | awk '{print $2}')
    LOAD_5=$(echo "$LOAD_AVG" | awk '{print $3}')
    LOAD_15=$(echo "$LOAD_AVG" | awk '{print $4}')

    echo "    \"cpu\": {"
    echo "      \"user\": \"$CPU_USER\","
    echo "      \"system\": \"$CPU_SYS\","
    echo "      \"idle\": \"$CPU_IDLE\","
    echo "      \"load_1min\": \"$LOAD_1\","
    echo "      \"load_5min\": \"$LOAD_5\","
    echo "      \"load_15min\": \"$LOAD_15\""
    echo "    },"

    # Memory
    MEM_TOTAL_BYTES=$(sysctl -n hw.memsize)
    MEM_TOTAL=$((MEM_TOTAL_BYTES / 1024 / 1024))
    MEM_INFO=$(echo "$TOP_OUTPUT" | grep PhysMem)
    MEM_USED=$(echo "$MEM_INFO" | awk '{print $2}' | sed 's/M//')
    MEM_AVAILABLE=$((MEM_TOTAL - MEM_USED))
    MEM_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($MEM_USED/$MEM_TOTAL)*100}")

    echo "    \"memory\": {"
    echo "      \"used_mb\": \"$MEM_USED\","
    echo "      \"available_mb\": \"$MEM_AVAILABLE\","
    echo "      \"total_mb\": \"$MEM_TOTAL\","
    echo "      \"percent\": \"$MEM_PERCENT\""
    echo "    },"

    # Disk
    if [ -d "/System/Volumes/Data" ]; then
        DISK_INFO=$(df -H /System/Volumes/Data | tail -1)
    else
        DISK_INFO=$(df -H / | tail -1)
    fi
    DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
    DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
    DISK_AVAIL=$(echo "$DISK_INFO" | awk '{print $4}')
    DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}' | sed 's/%//')

    echo "    \"disk\": {"
    echo "      \"total_gb\": \"$DISK_TOTAL\","
    echo "      \"used_gb\": \"$DISK_USED\","
    echo "      \"available_gb\": \"$DISK_AVAIL\","
    echo "      \"percent\": \"$DISK_PERCENT\""
    echo "    },"

    # Network totals
    NET_INFO=$(netstat -ib | /usr/bin/grep -E "^en[0-9]+" | awk '$7 > 0' | sort -k7 -rn | head -1)
    if [ -n "$NET_INFO" ]; then
        NET_IN=$(echo "$NET_INFO" | awk '{print $7}')
        NET_OUT=$(echo "$NET_INFO" | awk '{print $10}')
        NET_IN_GB=$(awk "BEGIN {printf \"%.2f\", $NET_IN/1024/1024/1024}")
        NET_OUT_GB=$(awk "BEGIN {printf \"%.2f\", $NET_OUT/1024/1024/1024}")
    else
        NET_IN_GB="0"
        NET_OUT_GB="0"
    fi

    echo "    \"network\": {"
    echo "      \"received_gb\": \"$NET_IN_GB\","
    echo "      \"sent_gb\": \"$NET_OUT_GB\""
    echo "    },"

    # Temperature (keeping existing logic)
    BATT_TEMP_C=$(python3 -c "
import subprocess
try:
    result = subprocess.run(['ioreg', '-rn', 'AppleSmartBattery', '-w0'],
                           capture_output=True, text=True, timeout=1)
    for line in result.stdout.split('\n'):
        if '\"Temperature\"' in line and '=' in line:
            temp_raw = line.split('=')[1].strip()
            temp_c = float(temp_raw) / 100.0
            print(f'{temp_c:.1f}')
            break
except:
    print('N/A')
" 2>/dev/null || echo "N/A")

    if [ "$BATT_TEMP_C" != "N/A" ] && [ -n "$BATT_TEMP_C" ]; then
        CPU_LOAD=$(awk "BEGIN {printf \"%.2f\", $CPU_USER + $CPU_SYS}")
        LOAD_FACTOR=$(awk "BEGIN {printf \"%.2f\", $CPU_LOAD / 100}")
        CPU_TEMP_OFFSET=$(awk "BEGIN {printf \"%.1f\", 15 + ($LOAD_FACTOR * 10)}")
        TEMP_C=$(awk "BEGIN {printf \"%.1f\", $BATT_TEMP_C + $CPU_TEMP_OFFSET}")
        TEMP_F=$(awk "BEGIN {printf \"%.1f\", ($TEMP_C * 9/5) + 32}")

        if [ $(awk "BEGIN {print ($TEMP_C > $CPU_TEMP_CRITICAL) ? 1 : 0}") -eq 1 ]; then
            TEMP_STATUS="critical"
        elif [ $(awk "BEGIN {print ($TEMP_C > $CPU_TEMP_WARNING) ? 1 : 0}") -eq 1 ]; then
            TEMP_STATUS="warning"
        else
            TEMP_STATUS="normal"
        fi
    else
        TEMP_C="N/A"
        TEMP_F="N/A"
        TEMP_STATUS="unknown"
    fi

    echo "    \"temperature\": {"
    echo "      \"cpu_celsius\": \"$TEMP_C\","
    echo "      \"cpu_fahrenheit\": \"$TEMP_F\","
    echo "      \"battery_celsius\": \"$BATT_TEMP_C\","
    echo "      \"status\": \"$TEMP_STATUS\","
    echo "      \"note\": \"CPU temp estimated (M1 requires sudo for direct access)\""
    echo "    },"

    # Fan (unavailable - fast)
    echo "    \"fan\": {"
    echo "      \"speed_rpm\": \"N/A\","
    echo "      \"status\": \"unavailable\","
    echo "      \"note\": \"Install Macs Fan Control for manual fan control\""
    echo "    },"

    # Bandwidth - Skip 1-second sleep, use cached value or estimate
    BANDWIDTH_CACHE="$CACHE_DIR/bandwidth.cache"
    if [ -f "$BANDWIDTH_CACHE" ] && [ $((EPOCH - $(stat -f %m "$BANDWIDTH_CACHE"))) -lt $METRICS_CACHE_TTL ]; then
        # Use cached bandwidth
        cat "$BANDWIDTH_CACHE"
    else
        # Quick estimate or zero
        echo "    \"bandwidth\": {"
        echo "      \"download_mbps\": \"0.00\","
        echo "      \"upload_mbps\": \"0.00\""
        echo "    },"

        # Update cache in background
        (
            NET_SAMPLE_1=$(netstat -ib 2>/dev/null | /usr/bin/grep -E "^en[0-9]+" | awk '$7 > 0' | sort -k7 -rn | head -1 | awk '{print $7, $10}')
            RX_1=$(echo "$NET_SAMPLE_1" | awk '{print $1}')
            TX_1=$(echo "$NET_SAMPLE_1" | awk '{print $2}')
            sleep $BANDWIDTH_SAMPLE_INTERVAL
            NET_SAMPLE_2=$(netstat -ib 2>/dev/null | /usr/bin/grep -E "^en[0-9]+" | awk '$7 > 0' | sort -k7 -rn | head -1 | awk '{print $7, $10}')
            RX_2=$(echo "$NET_SAMPLE_2" | awk '{print $1}')
            TX_2=$(echo "$NET_SAMPLE_2" | awk '{print $2}')

            if [ -n "$RX_1" ] && [ -n "$RX_2" ] && [ -n "$TX_1" ] && [ -n "$TX_2" ]; then
                RX_BPS=$((RX_2 - RX_1))
                TX_BPS=$((TX_2 - TX_1))
                RX_MBPS=$(awk "BEGIN {printf \"%.2f\", $RX_BPS / 1024 / 1024 * 8}")
                TX_MBPS=$(awk "BEGIN {printf \"%.2f\", $TX_BPS / 1024 / 1024 * 8}")
            else
                RX_MBPS="0.00"
                TX_MBPS="0.00"
            fi

            cat > "$BANDWIDTH_CACHE" << EOF
    "bandwidth": {
      "download_mbps": "$RX_MBPS",
      "upload_mbps": "$TX_MBPS"
    },
EOF
        ) &
    fi

    # Top processes (already available from top output)
    echo "    \"top_cpu\": ["
    ps aux -r | head -6 | tail -5 | awk '{
        name = $11
        gsub(/\\/, "\\\\", name)
        gsub(/"/, "\\\"", name)
        printf "      {\"pid\": \"%s\", \"cpu\": \"%.1f\", \"mem\": \"%.1f\", \"name\": \"%s\"}", $2, $3, $4, name
        if (NR < 5) printf ","
        printf "\n"
    }'
    echo "    ],"

    echo "    \"top_memory\": ["
    ps aux -m | head -6 | tail -5 | awk '{
        name = $11
        gsub(/\\/, "\\\\", name)
        gsub(/"/, "\\\"", name)
        printf "      {\"pid\": \"%s\", \"cpu\": \"%.1f\", \"mem\": \"%.1f\", \"name\": \"%s\"}", $2, $3, $4, name
        if (NR < 5) printf ","
        printf "\n"
    }'
    echo "    ],"

    # Port status (optimized - single lsof call)
    echo "    \"ports\": {"
    PORTS_TO_CHECK="5353 8080 32400 18789 8443 $(get_config_default 'services.dashboard.port' '8888')"
    PORT_DATA=$(/usr/sbin/lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null)
    FIRST_PORT=true
    for PORT_NUM in $PORTS_TO_CHECK; do
        [ "$FIRST_PORT" = false ] && echo ","
        FIRST_PORT=false
        PORT_INFO=$(echo "$PORT_DATA" | /usr/bin/grep ":$PORT_NUM " | head -1)
        if [ -n "$PORT_INFO" ]; then
            PORT_PROCESS=$(echo "$PORT_INFO" | awk '{print $1}' | sed 's/\\x[0-9a-fA-F][0-9a-fA-F]/ /g')
            PORT_PROCESS=$(echo "$PORT_PROCESS" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr -d '\n\r')
            PORT_STATUS="listening"
        else
            PORT_PROCESS="none"
            PORT_STATUS="closed"
        fi
        echo -n "      \"$PORT_NUM\": {\"status\": \"$PORT_STATUS\", \"process\": \"$PORT_PROCESS\"}"
    done
    echo ""
    echo "    },"

    # Internet connectivity (parallel pings with configurable timeout)
    PING_HOSTS=$(get_config "monitoring.internet_check_hosts")
    HOST1=$(echo "$PING_HOSTS" | python3 -c "import sys, json; hosts=json.load(sys.stdin); print(hosts[0])" 2>/dev/null || echo "8.8.8.8")
    HOST2=$(echo "$PING_HOSTS" | python3 -c "import sys, json; hosts=json.load(sys.stdin); print(hosts[1])" 2>/dev/null || echo "1.1.1.1")

    (ping -c 1 -W $PING_TIMEOUT $HOST1 2>/dev/null | tail -1 | awk -F'/' '{print $5}' > "$CACHE_DIR/ping_host1.tmp" &)
    (ping -c 1 -W $PING_TIMEOUT $HOST2 2>/dev/null | tail -1 | awk -F'/' '{print $5}' > "$CACHE_DIR/ping_host2.tmp" &)
    wait

    PING_HOST1=$(cat "$CACHE_DIR/ping_host1.tmp" 2>/dev/null || echo "timeout")
    PING_HOST2=$(cat "$CACHE_DIR/ping_host2.tmp" 2>/dev/null || echo "timeout")
    [ -z "$PING_HOST1" ] && PING_HOST1="timeout"
    [ -z "$PING_HOST2" ] && PING_HOST2="timeout"

    if [ "$PING_HOST1" = "timeout" ]; then
        INTERNET_STATUS="degraded"
    else
        INTERNET_STATUS="online"
    fi

    echo "    \"internet\": {"
    echo "      \"status\": \"$INTERNET_STATUS\","
    echo "      \"ping_google\": \"$PING_HOST1\","
    echo "      \"ping_cloudflare\": \"$PING_HOST2\""
    echo "    },"

    # System uptime
    UPTIME_DAYS=$(uptime | awk '{print $3}' | sed 's/,//')
    if echo "$UPTIME_DAYS" | /usr/bin/grep -q ":"; then
        UPTIME_DAYS="0"
    fi

    echo "    \"uptime\": {"
    echo "      \"days\": \"$UPTIME_DAYS\","
    echo "      \"full\": \"$(uptime | sed 's/^.*up //' | sed 's/,.*user.*$//')\""
    echo "    }"

    echo "  },"
}

# Function: Get backup status - using config paths
get_backups() {
    echo "  \"backups\": {"

    BACKUP_LOGS_DIR=$(get_config "paths.backup_logs_dir")

    # Google Drive backup - sort by filename (timestamp) instead of modification time
    LATEST_GD_LOG=$(ls -1 "$BACKUP_LOGS_DIR"/backup_*.log 2>/dev/null | grep -v "evm" | sort -r | head -1)
    DOCUMENTS_DIR=$(get_config "backup.paths.documents")

    if [ -n "$LATEST_GD_LOG" ]; then
        if [ -d "$DOCUMENTS_DIR" ]; then
            GD_SIZE=$(du -sh "$DOCUMENTS_DIR" 2>/dev/null | awk '{print $1}')
        else
            GD_SIZE="N/A"
        fi

        GD_START=$(grep "Started:" "$LATEST_GD_LOG" 2>/dev/null | awk '{print $NF}' | head -1)
        GD_END=$(grep "Completed:" "$LATEST_GD_LOG" 2>/dev/null | awk '{print $NF}' | head -1)

        if [ -n "$GD_END" ]; then
            GD_SUCCESS="true"
            GD_STATUS="completed"
            GD_IN_PROGRESS="false"
        elif [ -n "$GD_START" ]; then
            GD_SUCCESS="false"
            GD_STATUS="in progress"
            GD_IN_PROGRESS="true"
        else
            GD_SUCCESS="false"
            GD_STATUS="unknown"
            GD_IN_PROGRESS="false"
        fi

        [ -z "$GD_START" ] && GD_START="N/A"
        [ -z "$GD_END" ] && GD_END="N/A"
    else
        GD_SIZE="N/A"
        GD_START="never"
        GD_END="never"
        GD_SUCCESS="false"
        GD_STATUS="never"
        GD_IN_PROGRESS="false"
    fi

    echo "    \"google_drive\": {"
    echo "      \"size\": \"$GD_SIZE\","
    echo "      \"started\": \"$GD_START\","
    echo "      \"ended\": \"$GD_END\","
    echo "      \"status\": \"$GD_STATUS\","
    echo "      \"in_progress\": $GD_IN_PROGRESS,"
    echo "      \"success\": $GD_SUCCESS"
    echo "    },"

    # EVM backup - sort by filename (timestamp) instead of modification time
    LATEST_EVM_LOG=$(ls -1 "$BACKUP_LOGS_DIR"/backup_evm_*.log 2>/dev/null | sort -r | head -1)
    EVM_BACKUP_DIR=$(get_config "backup.paths.evm_backup_dir")

    if [ -n "$LATEST_EVM_LOG" ]; then
        if [ -d "$EVM_BACKUP_DIR" ]; then
            EVM_SIZE=$(du -sh "$EVM_BACKUP_DIR" 2>/dev/null | awk '{print $1}')
            EVM_MOUNTED="true"
        else
            EVM_SIZE="N/A"
            EVM_MOUNTED="false"
        fi

        EVM_START=$(grep "Started:" "$LATEST_EVM_LOG" 2>/dev/null | awk '{print $NF}' | head -1)
        EVM_END=$(grep "Completed:" "$LATEST_EVM_LOG" 2>/dev/null | awk '{print $NF}' | head -1)

        if grep -q "completed successfully" "$LATEST_EVM_LOG" 2>/dev/null; then
            EVM_SUCCESS="true"
            EVM_STATUS="completed"
            EVM_IN_PROGRESS="false"
        elif grep -q "completed with warnings" "$LATEST_EVM_LOG" 2>/dev/null; then
            EVM_SUCCESS="false"
            EVM_STATUS="warnings"
            EVM_IN_PROGRESS="false"
        elif [ -n "$EVM_START" ] && [ -z "$EVM_END" ]; then
            EVM_SUCCESS="false"
            EVM_STATUS="in progress"
            EVM_IN_PROGRESS="true"
        else
            EVM_SUCCESS="false"
            EVM_STATUS="unknown"
            EVM_IN_PROGRESS="false"
        fi

        [ -z "$EVM_START" ] && EVM_START="N/A"
        [ -z "$EVM_END" ] && EVM_END="N/A"
    else
        EVM_SIZE="N/A"
        EVM_START="never"
        EVM_END="never"
        EVM_SUCCESS="false"
        EVM_STATUS="never"
        EVM_IN_PROGRESS="false"
        EVM_MOUNTED="false"
    fi

    EVM_MOUNT=$(get_config "backup.paths.evm_mount")
    if [ ! -d "$EVM_MOUNT" ]; then
        EVM_MOUNTED="false"
    fi

    echo "    \"evm_drive\": {"
    echo "      \"size\": \"$EVM_SIZE\","
    echo "      \"started\": \"$EVM_START\","
    echo "      \"ended\": \"$EVM_END\","
    echo "      \"status\": \"$EVM_STATUS\","
    echo "      \"in_progress\": $EVM_IN_PROGRESS,"
    echo "      \"success\": $EVM_SUCCESS,"
    echo "      \"mounted\": $EVM_MOUNTED"
    echo "    }"

    echo "  },"
}

# Function: Get automation status
get_automation() {
    echo "  \"automation\": {"

    UNIFIED_LOG="$CONFIG_LOGS_DIR/unified-automation.log"
    if [ -f "$UNIFIED_LOG" ]; then
        UNIFIED_LAST=$(grep "All tasks completed" "$UNIFIED_LOG" | tail -1 | awk -F'[][]' '{print $2}')
        [ -z "$UNIFIED_LAST" ] && UNIFIED_LAST="unknown"
    else
        UNIFIED_LAST="never"
    fi

    STATUS_FILE="$CONFIG_LOGS_DIR/automation-status.json"
    if [ -f "$STATUS_FILE" ]; then
        STATUS_JSON=$(python3 -c "
import json
try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
    print(json.dumps(data))
except:
    print('{}')
" 2>/dev/null)
    else
        STATUS_JSON='{}'
    fi

    STARTUP_PID=$(launchctl list | grep com.securitylab.unified | awk '{print $1}')
    if [ -n "$STARTUP_PID" ] && [ "$STARTUP_PID" != "-" ]; then
        if [ "$STARTUP_PID" = "-" ]; then
            STARTUP_STATUS="loaded"
        else
            STARTUP_STATUS="running"
        fi
    else
        STARTUP_STATUS="not loaded"
    fi

    SCHEDULE=$(get_config_default "automation.unified_script.schedule" "Daily at 3:00 AM")

    echo "    \"unified_script\": {"
    echo "      \"last_run\": \"$UNIFIED_LAST\","
    echo "      \"schedule\": \"$SCHEDULE\","
    echo "      \"status\": $STATUS_JSON"
    echo "    },"

    echo "    \"startup_service\": {"
    echo "      \"status\": \"$STARTUP_STATUS\","
    echo "      \"schedule\": \"Boot + every 5 minutes\""
    echo "    }"

    echo "  },"
}

# Function: Get Pi-hole stats (cached)
get_pihole_stats() {
    PIHOLE_CACHE="$CACHE_DIR/pihole.cache"
    CACHE_AGE=999

    if [ -f "$PIHOLE_CACHE" ]; then
        CACHE_AGE=$((EPOCH - $(stat -f %m "$PIHOLE_CACHE")))
    fi

    if [ $CACHE_AGE -lt $PIHOLE_CACHE_TTL ]; then
        # Use cached data
        cat "$PIHOLE_CACHE"
    else
        # Fetch new data in background, return cached or default
        if [ -f "$PIHOLE_CACHE" ]; then
            cat "$PIHOLE_CACHE"
        else
            # Return default values on first run
            echo "  \"pihole_stats\": {"
            echo "    \"domains_blocked\": \"0\","
            echo "    \"queries_today\": \"0\","
            echo "    \"ads_blocked_today\": \"0\","
            echo "    \"percent_blocked\": \"0\","
            echo "    \"queries_total\": \"0\","
            echo "    \"ads_blocked_total\": \"0\","
            echo "    \"unique_domains\": \"0\","
            echo "    \"queries_forwarded\": \"0\","
            echo "    \"queries_cached\": \"0\""
            echo "  },"
        fi

        # Update cache in background
        (
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pihole"; then
                PIHOLE_DATA=$(docker exec pihole pihole api "stats/summary" 2>/dev/null)

                if [ -n "$PIHOLE_DATA" ]; then
                    DOMAINS_BLOCKED=$(echo "$PIHOLE_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)['gravity']['domains_being_blocked'])" 2>/dev/null || echo "0")
                    DNS_QUERIES_TOTAL=$(echo "$PIHOLE_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)['queries']['total'])" 2>/dev/null || echo "0")
                    ADS_BLOCKED_TOTAL=$(echo "$PIHOLE_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)['queries']['blocked'])" 2>/dev/null || echo "0")
                    PERCENT_BLOCKED=$(echo "$PIHOLE_DATA" | python3 -c "import sys, json; print(round(json.load(sys.stdin)['queries']['percent_blocked'], 1))" 2>/dev/null || echo "0")
                    UNIQUE_DOMAINS=$(echo "$PIHOLE_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)['queries']['unique_domains'])" 2>/dev/null || echo "0")
                    QUERIES_FORWARDED=$(echo "$PIHOLE_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)['queries']['forwarded'])" 2>/dev/null || echo "0")
                    QUERIES_CACHED=$(echo "$PIHOLE_DATA" | python3 -c "import sys, json; print(json.load(sys.stdin)['queries']['cached'])" 2>/dev/null || echo "0")

                    DNS_QUERIES="$DNS_QUERIES_TOTAL"
                    ADS_BLOCKED="$ADS_BLOCKED_TOTAL"
                else
                    DOMAINS_BLOCKED="0"
                    DNS_QUERIES="0"
                    ADS_BLOCKED="0"
                    PERCENT_BLOCKED="0"
                    DNS_QUERIES_TOTAL="0"
                    ADS_BLOCKED_TOTAL="0"
                    UNIQUE_DOMAINS="0"
                    QUERIES_FORWARDED="0"
                    QUERIES_CACHED="0"
                fi
            else
                DOMAINS_BLOCKED="0"
                DNS_QUERIES="0"
                ADS_BLOCKED="0"
                PERCENT_BLOCKED="0"
                DNS_QUERIES_TOTAL="0"
                ADS_BLOCKED_TOTAL="0"
                UNIQUE_DOMAINS="0"
                QUERIES_FORWARDED="0"
                QUERIES_CACHED="0"
            fi

            cat > "$PIHOLE_CACHE" << EOF
  "pihole_stats": {
    "domains_blocked": "$DOMAINS_BLOCKED",
    "queries_today": "$DNS_QUERIES",
    "ads_blocked_today": "$ADS_BLOCKED",
    "percent_blocked": "$PERCENT_BLOCKED",
    "queries_total": "$DNS_QUERIES_TOTAL",
    "ads_blocked_total": "$ADS_BLOCKED_TOTAL",
    "unique_domains": "$UNIQUE_DOMAINS",
    "queries_forwarded": "$QUERIES_FORWARDED",
    "queries_cached": "$QUERIES_CACHED"
  },
EOF
        ) &
    fi
}

# Function: Get alerts (using config thresholds)
get_alerts() {
    echo "  \"alerts\": ["

    ALERT_COUNT=0

    # Re-calculate memory and disk percentages for alert checks
    # (Since get_resources runs in parallel, variables aren't accessible)
    MEM_TOTAL_BYTES=$(sysctl -n hw.memsize)
    MEM_TOTAL=$((MEM_TOTAL_BYTES / 1024 / 1024))
    MEM_USED=$(top -l 1 | grep PhysMem | awk '{print $2}' | sed 's/M//')
    LOCAL_MEM_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($MEM_USED/$MEM_TOTAL)*100}")

    if [ -d "/System/Volumes/Data" ]; then
        LOCAL_DISK_PERCENT=$(df -H /System/Volumes/Data | tail -1 | awk '{print $5}' | sed 's/%//')
    else
        LOCAL_DISK_PERCENT=$(df -H / | tail -1 | awk '{print $5}' | sed 's/%//')
    fi

    # Check memory usage (using config threshold)
    if [ $(awk "BEGIN {print ($LOCAL_MEM_PERCENT > $MEM_THRESHOLD) ? 1 : 0}") -eq 1 ]; then
        [ $ALERT_COUNT -gt 0 ] && echo ","
        echo "    {"
        echo "      \"severity\": \"warning\","
        echo "      \"service\": \"system\","
        echo "      \"message\": \"High memory usage: ${LOCAL_MEM_PERCENT}%\""
        echo "    }"
        ALERT_COUNT=$((ALERT_COUNT + 1))
    fi

    # Check disk usage (using config threshold)
    if [ "$LOCAL_DISK_PERCENT" -gt "$DISK_THRESHOLD" ]; then
        [ $ALERT_COUNT -gt 0 ] && echo ","
        echo "    {"
        echo "      \"severity\": \"warning\","
        echo "      \"service\": \"storage\","
        echo "      \"message\": \"Disk space usage at ${LOCAL_DISK_PERCENT}% - Consider cleanup\""
        echo "    }"
        ALERT_COUNT=$((ALERT_COUNT + 1))
    fi

    # If no alerts
    if [ $ALERT_COUNT -eq 0 ]; then
        echo "    {"
        echo "      \"severity\": \"info\","
        echo "      \"service\": \"system\","
        echo "      \"message\": \"All systems operational\""
        echo "    }"
    fi

    echo "  ]"
}

#=== EXECUTE ALL FUNCTIONS IN PARALLEL ===

# Create temp files for parallel output
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Run functions in parallel
get_services > "$TEMP_DIR/services.json" &
PID_SERVICES=$!

get_resources > "$TEMP_DIR/resources.json" &
PID_RESOURCES=$!

get_backups > "$TEMP_DIR/backups.json" &
PID_BACKUPS=$!

get_automation > "$TEMP_DIR/automation.json" &
PID_AUTOMATION=$!

get_pihole_stats > "$TEMP_DIR/pihole.json" &
PID_PIHOLE=$!

# Wait for all critical sections to complete
wait $PID_SERVICES
wait $PID_RESOURCES
wait $PID_BACKUPS
wait $PID_AUTOMATION
wait $PID_PIHOLE

# Assemble JSON output
cat "$TEMP_DIR/services.json"
cat "$TEMP_DIR/resources.json"
cat "$TEMP_DIR/backups.json"
cat "$TEMP_DIR/automation.json"
cat "$TEMP_DIR/pihole.json"

# Generate alerts last (needs resource data)
get_alerts

# Close JSON
echo "}"
