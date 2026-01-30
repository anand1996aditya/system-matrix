#!/bin/bash

# Script to change System Matrix Dashboard password

AUTH_FILE="$HOME/Claude-Code/Scripts/.dashboard_auth"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║         SYSTEM MATRIX DASHBOARD - PASSWORD CHANGE        ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if auth file exists
if [ ! -f "$AUTH_FILE" ]; then
    echo "⚠️  Authentication config file not found: $AUTH_FILE"
    echo "The dashboard will create default credentials on first start."
    exit 1
fi

# Read current username
CURRENT_USER=$(cat "$AUTH_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('username', 'admin'))")

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

# Generate password hash using Python
PASSWORD_HASH=$(echo -n "$NEW_PASSWORD" | python3 -c "import sys, hashlib; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())")

# Create new auth config
cat > "$AUTH_FILE" << EOF
{
  "username": "$NEW_USER",
  "password_hash": "$PASSWORD_HASH"
}
EOF

# Secure the file
chmod 600 "$AUTH_FILE"

echo "✅ Dashboard credentials updated successfully!"
echo ""
echo "New credentials:"
echo "  Username: $NEW_USER"
echo "  Password: (hidden)"
echo ""
echo "🔄 Restart the dashboard server for changes to take effect:"
echo "   pkill -f dashboard-server.py"
echo "   cd ~/Claude-Code/Scripts && python3 dashboard-server.py &"
echo ""
