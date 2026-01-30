#!/bin/bash

echo "═══════════════════════════════════════════════════════════════════"
echo "Testing File Browser API (You'll need to enter your password)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

USERNAME="aditya12anand"

echo "Username: $USERNAME"
echo -n "Password: "
read -s PASSWORD
echo ""
echo ""

echo "Test 1: /api/files/drives"
echo "─────────────────────────────────────────────────────────────────"
RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" http://localhost:8888/api/files/drives)
echo "$RESPONSE" | python3 -m json.tool 2>&1 | head -20

echo ""
echo "Test 2: /api/files/list?path=/Volumes/EVM"
echo "─────────────────────────────────────────────────────────────────"
RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" "http://localhost:8888/api/files/list?path=%2FVolumes%2FEVM")
STATUS=$?

if echo "$RESPONSE" | python3 -m json.tool > /dev/null 2>&1; then
    echo "✅ Success! Got valid JSON:"
    echo "$RESPONSE" | python3 -m json.tool | head -30
else
    echo "❌ Error! Response:"
    echo "$RESPONSE"
fi

echo ""
echo "Test 3: /api/files/list?path=/Volumes/Extreme SSD"
echo "─────────────────────────────────────────────────────────────────"
RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" "http://localhost:8888/api/files/list?path=%2FVolumes%2FExtreme%20SSD")

if echo "$RESPONSE" | python3 -m json.tool > /dev/null 2>&1; then
    echo "✅ Success! Got valid JSON:"
    echo "$RESPONSE" | python3 -m json.tool | head -30
else
    echo "❌ Error! Response:"
    echo "$RESPONSE"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "If you see ✅ above, the API is working!"
echo "If you see ❌, there's still an issue."
echo "═══════════════════════════════════════════════════════════════════"
