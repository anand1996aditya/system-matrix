#!/bin/bash

# Telegram Alert Script for System Matrix with Cooldown
# Now using centralized configuration system

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utilities/config-loader.sh"

# Parse arguments
SEVERITY="$1"
SERVICE="$2"
MESSAGE="$3"

# Validate arguments
if [ -z "$SEVERITY" ] || [ -z "$SERVICE" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <severity> <service> <message>" >&2
    echo "Example: $0 critical security 'SSH brute force detected'" >&2
    exit 1
fi

# Check if Telegram is enabled
if [ "$CONFIG_TELEGRAM_ENABLED" != "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Telegram notifications disabled, skipping" >&2
    exit 0
fi

# Get Telegram credentials from config
BOT_TOKEN="$CONFIG_TELEGRAM_BOT_TOKEN"
CHAT_ID="$CONFIG_TELEGRAM_CHAT_ID"

# Validate credentials
if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Telegram bot token not configured" >&2
    exit 1
fi

if [ -z "$CHAT_ID" ] || [ "$CHAT_ID" = "YOUR_CHAT_ID_HERE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Telegram chat ID not configured" >&2
    exit 1
fi

# Alert state directory (from config)
STATE_DIR="$CONFIG_ALERT_STATE_DIR"
mkdir -p "$STATE_DIR"

# Create unique alert key (based on severity and service)
ALERT_KEY="${SEVERITY}_${SERVICE}"
STATE_FILE="$STATE_DIR/${ALERT_KEY}.last"

# Get cooldown period from config (in seconds)
case "$SEVERITY" in
    "critical")
        COOLDOWN=$(get_config "notifications.telegram.cooldown.critical")
        [ -z "$COOLDOWN" ] && COOLDOWN=600  # Default 10 minutes
        ;;
    "warning")
        COOLDOWN=$(get_config "notifications.telegram.cooldown.warning")
        [ -z "$COOLDOWN" ] && COOLDOWN=3600  # Default 1 hour
        ;;
    "info")
        COOLDOWN=$(get_config "notifications.telegram.cooldown.info")
        [ -z "$COOLDOWN" ] && COOLDOWN=7200  # Default 2 hours
        ;;
    *)
        COOLDOWN=3600  # Default 1 hour
        ;;
esac

# Check if we're in cooldown period
CURRENT_TIME=$(date +%s)
SHOULD_SEND=true

if [ -f "$STATE_FILE" ]; then
    LAST_SENT=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    TIME_DIFF=$((CURRENT_TIME - LAST_SENT))

    if [ "$TIME_DIFF" -lt "$COOLDOWN" ]; then
        SHOULD_SEND=false
        REMAINING=$((COOLDOWN - TIME_DIFF))
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Alert suppressed (cooldown): ${SEVERITY} - ${SERVICE} - ${REMAINING}s remaining" >> "$CONFIG_LOGS_DIR/telegram-alerts.log"
    fi
fi

# Only send if not in cooldown
if [ "$SHOULD_SEND" = true ]; then
    # Set emoji based on severity
    case "$SEVERITY" in
        "critical") EMOJI="🚨" ;;
        "warning")  EMOJI="⚠️" ;;
        "info")     EMOJI="ℹ️" ;;
        *)          EMOJI="📊" ;;
    esac

    # Convert severity to uppercase
    SEVERITY_UPPER=$(echo "$SEVERITY" | tr '[:lower:]' '[:upper:]')

    # Get dashboard port from config
    DASHBOARD_PORT=$(get_config_default "services.dashboard.port" "8888")

    # Format message with Markdown
    TELEGRAM_MESSAGE="${EMOJI} *System Matrix Alert*

*Severity:* ${SEVERITY_UPPER}
*Service:* ${SERVICE}
*Time:* $(date '+%Y-%m-%d %H:%M:%S')

${MESSAGE}

[Open Dashboard](http://localhost:${DASHBOARD_PORT})"

    # Send to Telegram
    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d chat_id="${CHAT_ID}" \
      -d text="${TELEGRAM_MESSAGE}" \
      -d parse_mode="Markdown" \
      -d disable_web_page_preview=true 2>&1)

    # Check if send was successful
    if echo "$RESPONSE" | grep -q '"ok":true'; then
        # Update state file with current timestamp
        echo "$CURRENT_TIME" > "$STATE_FILE"

        # Log the alert
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Alert sent: ${SEVERITY} - ${SERVICE} - ${MESSAGE}" >> "$CONFIG_LOGS_DIR/telegram-alerts.log"
    else
        # Log error
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR sending alert: ${RESPONSE}" >> "$CONFIG_LOGS_DIR/telegram-alerts.log"
        exit 1
    fi
fi
