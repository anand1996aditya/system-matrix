#!/bin/bash
#
# Master Startup Script - Ensures ALL Services Start on Boot (FIXED VERSION)
# This script starts all home server services in the correct order with proper health checks
#

LOG_FILE="$HOME/.startup-services.log"
LOCK_FILE="$HOME/.startup-services.lock"

# Prevent overlapping runs and detect throttling
if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ $LOCK_AGE -lt 60 ]; then
        # Script ran less than 60 seconds ago - possible throttling or overlap
        echo "$(date): Skipping run - script ran $LOCK_AGE seconds ago (possible throttling)" >> "$LOG_FILE"
        exit 0
    fi
fi

# Create lock file
touch "$LOCK_FILE"

# Remove lock file on exit
trap "rm -f $LOCK_FILE" EXIT

exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================================================"
echo "🚀 MASTER STARTUP - $(date)"
echo "========================================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SUCCESS=0
FAILED=0

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
        ((SUCCESS++))
    else
        echo -e "${RED}❌ $2${NC}"
        ((FAILED++))
    fi
}

# Wait for network to be available
echo "Waiting for network..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        log_status 0 "Network is ready"
        break
    fi
    sleep 2
done

echo ""
echo "========================================================================"
echo "STEP 1: Tailscale VPN"
echo "========================================================================"

if pgrep -x "tailscaled" > /dev/null; then
    log_status 0 "Tailscale daemon is running"

    # Wait for Tailscale to be ready
    for i in {1..10}; do
        if tailscale status > /dev/null 2>&1; then
            log_status 0 "Tailscale is connected"
            break
        fi
        sleep 2
    done
else
    log_status 1 "Tailscale daemon is NOT running"
fi

echo ""
echo "========================================================================"
echo "STEP 2: Colima (Docker Runtime)"
echo "========================================================================"

if colima status > /dev/null 2>&1; then
    log_status 0 "Colima is already running"
else
    echo "Starting Colima..."
    # NOT backgrounded - wait for completion
    colima start > /dev/null 2>&1

    # Verify it started
    if colima status > /dev/null 2>&1; then
        log_status 0 "Colima started successfully"
    else
        log_status 1 "Colima failed to start"
    fi
fi

# Wait for Docker socket to be ready (increased timeout to 60s)
echo "Waiting for Docker socket..."
for i in {1..60}; do
    if docker info > /dev/null 2>&1; then
        log_status 0 "Docker socket is ready"
        break
    fi
    sleep 1
done

if ! docker info > /dev/null 2>&1; then
    log_status 1 "Docker socket not ready after 60 seconds"
fi

# NEW: Verify Docker networking is ready
echo "Verifying Docker networking..."
if docker network ls > /dev/null 2>&1; then
    log_status 0 "Docker networking ready"
else
    log_status 1 "Docker networking not ready"
fi

echo ""
echo "========================================================================"
echo "STEP 3: Docker Services"
echo "========================================================================"

# Helper function to wait for container health
wait_for_healthy() {
    local compose_dir=$1
    local service_name=$2
    local timeout=$3
    local elapsed=0

    echo "Waiting for $service_name containers to become healthy (timeout: ${timeout}s)..."

    cd "$compose_dir"
    while [ $elapsed -lt $timeout ]; do
        # Check if all containers are healthy or at least running
        local status=$(docker-compose ps 2>/dev/null)
        if echo "$status" | grep -q "healthy"; then
            return 0
        fi

        # Also accept if containers are running (no healthcheck defined)
        if echo "$status" | grep -q "Up" && ! echo "$status" | grep -q "starting"; then
            return 0
        fi

        sleep 5
        elapsed=$((elapsed + 5))
    done
    return 1
}

# Start Sentinel Platform services
if [ -d "$HOME/sentinel-platform" ]; then
    echo "Starting Sentinel Platform (PostgreSQL + Redis)..."
    cd "$HOME/sentinel-platform"
    docker-compose up -d > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_status 0 "Sentinel Platform containers created"

        # NEW: Wait for services to be healthy
        if wait_for_healthy "$HOME/sentinel-platform" "Sentinel Platform" 120; then
            log_status 0 "Sentinel Platform services are HEALTHY"

            # NEW: Explicit health checks for critical services
            echo "Verifying PostgreSQL..."
            for i in {1..30}; do
                if docker exec postgres pg_isready -U sentinel > /dev/null 2>&1; then
                    log_status 0 "PostgreSQL is healthy and accepting connections"
                    break
                fi
                sleep 2
            done

            echo "Verifying Redis..."
            for i in {1..15}; do
                if docker exec redis redis-cli ping > /dev/null 2>&1; then
                    log_status 0 "Redis is healthy and responding"
                    break
                fi
                sleep 2
            done
        else
            log_status 1 "Sentinel Platform services started but not healthy within timeout"
        fi
    else
        log_status 1 "Failed to start Sentinel Platform"
    fi
else
    echo "⚠️  Sentinel Platform directory not found"
fi

# Start Home Services (Plex + Pi-hole)
if [ -d "$HOME/home-services" ]; then
    echo "Starting Home Services (Plex + Pi-hole)..."
    cd "$HOME/home-services"
    docker-compose up -d > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_status 0 "Home services containers created"

        # NEW: Wait for services to be healthy
        if wait_for_healthy "$HOME/home-services" "Home Services" 120; then
            log_status 0 "Home services (Plex + Pi-hole) are HEALTHY"
        else
            log_status 1 "Home services started but not healthy within timeout"
        fi
    else
        log_status 1 "Failed to start Home services"
    fi
else
    echo "⚠️  Home Services directory not found"
fi

echo ""
echo "========================================================================"
echo "STEP 4: Clawdbot Services"
echo "========================================================================"

# Check Clawdbot Gateway
if launchctl list | grep -q "com.clawdbot.gateway"; then
    if curl -s http://localhost:18789/health > /dev/null 2>&1; then
        log_status 0 "Clawdbot Gateway is running and healthy"
    else
        log_status 1 "Clawdbot Gateway is loaded but not responding"
    fi
else
    log_status 1 "Clawdbot Gateway is NOT loaded"
fi

# Check Caddy
if launchctl list | grep -q "com.clawdbot.caddy"; then
    log_status 0 "Caddy reverse proxy is running"
else
    log_status 1 "Caddy is NOT loaded"
fi

echo ""
echo "========================================================================"
echo "STARTUP SUMMARY"
echo "========================================================================"
echo -e "Successful: ${GREEN}$SUCCESS${NC}"
echo -e "Failed:     ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL SERVICES STARTED SUCCESSFULLY${NC}"
else
    echo -e "${YELLOW}⚠️  SOME SERVICES FAILED TO START${NC}"
    echo "Check logs at: $LOG_FILE"
fi

echo ""
echo "========================================================================"
echo "SERVICE ACCESS URLS"
echo "========================================================================"
echo "• Clawdbot:          http://localhost:18789"
echo "• Plex:              http://localhost:32400/web"
echo "• Pi-hole:           http://localhost:8080/admin"
echo "• Sentinel Dashboard: http://localhost:5000 (run: cd ~/sentinel-platform && ./run_dashboard.sh)"
echo ""
echo "Via Tailscale:"
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")
echo "• Clawdbot:    http://$TAILSCALE_IP:18789"
echo "• Plex:        http://$TAILSCALE_IP:32400/web"
echo "• Pi-hole:     http://$TAILSCALE_IP:8080/admin"
echo ""
echo "Completed: $(date)"
echo "========================================================================"

# Always exit 0 to prevent LaunchAgent throttling
# Even if some services failed, the script ran successfully
exit 0
