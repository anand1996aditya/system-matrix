#!/bin/bash

# Script to change System Matrix Dashboard password

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../config/config.json"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║         SYSTEM MATRIX DASHBOARD - PASSWORD CHANGE        ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  Configuration file not found: $CONFIG_FILE"
    echo "Please run setup.sh first."
    exit 1
fi

# Read current username
CURRENT_USER=$(cat "$CONFIG_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('dashboard_auth', {}).get('username', 'admin'))")

echo "Current username: $CURRENT_USER"
echo ""

# Prompt for new username
read -p "Enter new username (or press Enter to keep '$CURRENT_USER'): " NEW_USER
if [ -z "$NEW_USER" ]; then
    NEW_USER="$CURRENT_USER"
fi

echo ""
echo "🔐 Setting new password for user: $NEW_USER"
echo ""

# Prompt for new password (hidden input)
read -s -p "Enter new password: " NEW_PASSWORD
echo ""
read -s -p "Confirm new password: " CONFIRM_PASSWORD
echo ""
echo ""

# Check if passwords match
if [ "$NEW_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
    echo "❌ Passwords do not match!"
    exit 1
fi

# Check password length
if [ ${#NEW_PASSWORD} -lt 8 ]; then
    echo "❌ Password must be at least 8 characters long!"
    exit 1
fi

# Generate a salted PBKDF2-HMAC-SHA256 hash using the shared helper
PASSWORD_HASH=$(printf '%s' "$NEW_PASSWORD" | python3 "$SCRIPT_DIR/dashboard_auth.py" hash)
if [ -z "$PASSWORD_HASH" ]; then
    echo "❌ Failed to hash the new password. Configuration was not changed."
    exit 1
fi

# Update config.json with new credentials using Python.
# Values travel in environment variables, not in the script body.
NEW_USER="$NEW_USER" PASSWORD_HASH="$PASSWORD_HASH" CONFIG_FILE="$CONFIG_FILE" python3 << 'EOF'
import json
import os

config_file = os.environ['CONFIG_FILE']
with open(config_file, 'r') as f:
    config = json.load(f)
config.setdefault('dashboard_auth', {})
config['dashboard_auth']['username'] = os.environ['NEW_USER']
config['dashboard_auth']['password_hash'] = os.environ['PASSWORD_HASH']
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
EOF

# Secure the file
chmod 600 "$CONFIG_FILE"

echo "✅ Dashboard credentials updated successfully!"
echo ""
echo "New credentials:"
echo "  Username: $NEW_USER"
echo "  Password: (hidden)"
echo ""
echo "🔄 Restart the dashboard server for changes to take effect:"
echo "   launchctl kickstart -k gui/\$(id -u)/com.securitylab.dashboard"
echo ""
