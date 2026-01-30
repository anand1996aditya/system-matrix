#!/bin/bash

# Configuration Loader for System Metrics Dashboard
# This script provides functions to load and parse configuration
# Usage: source this script in other scripts to access config values

# Determine script location and config path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/../../config" && pwd)"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_TEMPLATE="$CONFIG_DIR/config.template.json"

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found at: $CONFIG_FILE" >&2
    echo "Please run the setup script first: ./setup.sh" >&2
    echo "Or copy config.template.json to config.json and fill in your values" >&2
    exit 1
fi

# Function to expand environment variables in config values
expand_vars() {
    local value="$1"
    # Replace ${HOME} with actual home directory
    value="${value//\$\{HOME\}/$HOME}"
    # Replace ${USER} with actual username
    value="${value//\$\{USER\}/$USER}"
    echo "$value"
}

# Function to get config value using jq
# Usage: get_config "path.to.key"
get_config() {
    local key="$1"
    local value

    value=$(python3 -c "
import json
import sys

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)

    # Navigate to nested key
    keys = '$key'.split('.')
    result = config
    for k in keys:
        if isinstance(result, dict):
            result = result.get(k)
        elif isinstance(result, list) and k.isdigit():
            result = result[int(k)]
        else:
            print('', end='')
            sys.exit(0)

    if result is None:
        print('', end='')
    elif isinstance(result, bool):
        print('true' if result else 'false', end='')
    elif isinstance(result, (int, float)):
        print(result, end='')
    elif isinstance(result, str):
        print(result, end='')
    else:
        print(json.dumps(result), end='')
except Exception as e:
    print('', end='')
    sys.exit(1)
" 2>/dev/null)

    # Expand environment variables
    expand_vars "$value"
}

# Function to get config value with default
# Usage: get_config_default "path.to.key" "default_value"
get_config_default() {
    local key="$1"
    local default="$2"
    local value

    value=$(get_config "$key")
    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Preload commonly used config values for performance
CONFIG_BASE_DIR=$(get_config "paths.base_dir")
CONFIG_LOGS_DIR=$(get_config "paths.logs_dir")
CONFIG_CACHE_DIR=$(get_config "paths.cache_dir")
CONFIG_ALERT_STATE_DIR=$(get_config "paths.alert_state_dir")
CONFIG_METRICS_STATE_DIR=$(get_config "paths.metrics_state_dir")
CONFIG_DASHBOARD_DIR=$(get_config "paths.dashboard_dir")
CONFIG_SCRIPTS_DIR=$(get_config "paths.scripts_dir")

# Telegram config
CONFIG_TELEGRAM_ENABLED=$(get_config "notifications.telegram.enabled")
CONFIG_TELEGRAM_BOT_TOKEN=$(get_config "notifications.telegram.bot_token")
CONFIG_TELEGRAM_CHAT_ID=$(get_config "notifications.telegram.chat_id")

# Export commonly used variables
export CONFIG_BASE_DIR
export CONFIG_LOGS_DIR
export CONFIG_CACHE_DIR
export CONFIG_ALERT_STATE_DIR
export CONFIG_METRICS_STATE_DIR
export CONFIG_DASHBOARD_DIR
export CONFIG_SCRIPTS_DIR
export CONFIG_TELEGRAM_ENABLED
export CONFIG_TELEGRAM_BOT_TOKEN
export CONFIG_TELEGRAM_CHAT_ID

# Validation function
validate_config() {
    local errors=0

    # Check critical paths exist
    if [ ! -d "$CONFIG_BASE_DIR" ]; then
        echo "ERROR: Base directory does not exist: $CONFIG_BASE_DIR" >&2
        errors=$((errors + 1))
    fi

    # Check Telegram config if enabled
    if [ "$CONFIG_TELEGRAM_ENABLED" = "true" ]; then
        if [ -z "$CONFIG_TELEGRAM_BOT_TOKEN" ] || [ "$CONFIG_TELEGRAM_BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ]; then
            echo "ERROR: Telegram bot token not configured" >&2
            errors=$((errors + 1))
        fi

        if [ -z "$CONFIG_TELEGRAM_CHAT_ID" ] || [ "$CONFIG_TELEGRAM_CHAT_ID" = "YOUR_CHAT_ID_HERE" ]; then
            echo "ERROR: Telegram chat ID not configured" >&2
            errors=$((errors + 1))
        fi
    fi

    return $errors
}

# Auto-validate on load (can be disabled by setting SKIP_CONFIG_VALIDATION=1)
if [ "${SKIP_CONFIG_VALIDATION:-0}" != "1" ]; then
    if ! validate_config; then
        echo "Configuration validation failed. Please check your config.json file." >&2
        exit 1
    fi
fi
