#!/bin/bash

# Verification script for file browser fix

echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║      FILE BROWSER VERIFICATION SCRIPT                   ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "📋 Checking configuration..."
echo ""

# Check 1: Verify credentials mode in HTML
echo "1️⃣  Checking credentials mode in HTML..."
if grep -q "credentials: 'include'" ~/Claude-Code/Dashboard/index.html; then
    echo "   ✅ PASS: credentials set to 'include'"
else
    echo "   ❌ FAIL: credentials NOT set to 'include'"
    echo "   Run: grep \"credentials:\" ~/Claude-Code/Dashboard/index.html"
fi
echo ""

# Check 2: Verify server is running
echo "2️⃣  Checking if dashboard server is running..."
if lsof -ti:8888 > /dev/null 2>&1; then
    PID=$(lsof -ti:8888)
    echo "   ✅ PASS: Server running (PID: $PID)"
else
    echo "   ❌ FAIL: Server NOT running"
    echo "   Start with: cd ~/Claude-Code/Scripts && python3 dashboard-server.py &"
fi
echo ""

# Check 3: Verify drives exist
echo "3️⃣  Checking if external drives are mounted..."
DRIVES=("Data" "EVM" "Extreme SSD")
for drive in "${DRIVES[@]}"; do
    if [ -d "/Volumes/$drive" ]; then
        echo "   ✅ /Volumes/$drive - MOUNTED"
    else
        echo "   ⚠️  /Volumes/$drive - NOT MOUNTED"
    fi
done
echo ""

# Check 4: Check auth configuration
echo "4️⃣  Checking authentication configuration..."
if [ -f ~/Claude-Code/Scripts/.dashboard_auth ]; then
    USERNAME=$(cat ~/Claude-Code/Scripts/.dashboard_auth | grep username | cut -d'"' -f4)
    echo "   ✅ Auth configured for user: $USERNAME"
else
    echo "   ❌ FAIL: No auth configuration found"
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🧪 MANUAL TEST STEPS:"
echo ""
echo "1. Close all browser tabs with localhost:8888"
echo "2. Open: http://localhost:8888"
echo "3. Login with your credentials"
echo "4. Hard refresh: Cmd+Shift+R"
echo "5. Wait 2 seconds"
echo "6. Check FILE BROWSER section"
echo ""
echo "Expected: All mounted drives should appear with BROWSE buttons"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📖 For detailed troubleshooting, read:"
echo "   ~/Claude-Code/Scripts/FILE_BROWSER_FIX_EXPLAINED.md"
echo ""
