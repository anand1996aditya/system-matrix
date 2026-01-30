#!/bin/bash

# Service Detection Utility
# Detects which optional services are installed on the system
# Returns JSON with installed services and their availability

# Output JSON
echo "{"

# Docker
if command -v docker &> /dev/null; then
    echo "  \"docker\": {"
    echo "    \"installed\": true,"
    if docker ps &> /dev/null; then
        echo "    \"running\": true,"
        # Get list of running containers
        CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        echo "    \"containers\": [$(echo "$CONTAINERS" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')]"
    else
        echo "    \"running\": false,"
        echo "    \"containers\": []"
    fi
    echo "  },"
else
    echo "  \"docker\": { \"installed\": false, \"running\": false, \"containers\": [] },"
fi

# Tailscale
if command -v tailscale &> /dev/null || pgrep -x "Tailscale" > /dev/null; then
    echo "  \"tailscale\": {"
    echo "    \"installed\": true,"
    if pgrep -x "Tailscale" > /dev/null || pgrep -x "tailscaled" > /dev/null; then
        echo "    \"running\": true"
    else
        echo "    \"running\": false"
    fi
    echo "  },"
else
    echo "  \"tailscale\": { \"installed\": false, \"running\": false },"
fi

# Colima
if command -v colima &> /dev/null; then
    echo "  \"colima\": {"
    echo "    \"installed\": true,"
    if colima status &> /dev/null; then
        echo "    \"running\": true"
    else
        echo "    \"running\": false"
    fi
    echo "  },"
else
    echo "  \"colima\": { \"installed\": false, \"running\": false },"
fi

# Plex (check both app and docker)
PLEX_INSTALLED=false
PLEX_RUNNING=false
if [ -d "/Applications/Plex Media Server.app" ] || docker ps --format '{{.Names}}' 2>/dev/null | grep -q "plex"; then
    PLEX_INSTALLED=true
    if pgrep -f "Plex Media Server" > /dev/null || docker ps --format '{{.Names}}' 2>/dev/null | grep -q "plex"; then
        PLEX_RUNNING=true
    fi
fi
echo "  \"plex\": { \"installed\": $PLEX_INSTALLED, \"running\": $PLEX_RUNNING },"

# Pi-hole (docker only)
PIHOLE_INSTALLED=false
PIHOLE_RUNNING=false
if docker images --format '{{.Repository}}' 2>/dev/null | grep -q "pihole"; then
    PIHOLE_INSTALLED=true
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pihole"; then
        PIHOLE_RUNNING=true
    fi
fi
echo "  \"pihole\": { \"installed\": $PIHOLE_INSTALLED, \"running\": $PIHOLE_RUNNING },"

# Caddy
if command -v caddy &> /dev/null || pgrep -x "caddy" > /dev/null; then
    echo "  \"caddy\": {"
    echo "    \"installed\": true,"
    if pgrep -x "caddy" > /dev/null; then
        echo "    \"running\": true"
    else
        echo "    \"running\": false"
    fi
    echo "  },"
else
    echo "  \"caddy\": { \"installed\": false, \"running\": false },"
fi

# ClawdBot
if pgrep -f "clawdbot" > /dev/null || [ -d "$HOME/.clawdbot" ]; then
    echo "  \"clawdbot\": {"
    echo "    \"installed\": true,"
    if pgrep -f "clawdbot-gateway" > /dev/null; then
        echo "    \"running\": true"
    else
        echo "    \"running\": false"
    fi
    echo "  },"
else
    echo "  \"clawdbot\": { \"installed\": false, \"running\": false },"
fi

# External Drives (detect mounted volumes)
echo "  \"drives\": ["
FIRST=true
for vol in /Volumes/*; do
    if [ -d "$vol" ] && [ "$(basename "$vol")" != "Macintosh HD" ]; then
        if [ "$FIRST" = false ]; then echo ","; fi
        FIRST=false
        NAME=$(basename "$vol")
        SIZE=$(df -h "$vol" 2>/dev/null | tail -1 | awk '{print $2}')
        echo "    { \"name\": \"$NAME\", \"path\": \"$vol\", \"size\": \"$SIZE\" }"
    fi
done
echo "  ]"

echo "}"
