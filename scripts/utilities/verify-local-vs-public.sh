#!/bin/bash

# Verify Local vs Public Files
# Shows what's personal (git-ignored) and what's public (in git)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$PROJECT_ROOT"

echo -e "${BLUE}=== Local vs Public Files Verification ===${NC}\n"

# Check personal files exist and are ignored
echo -e "${BLUE}[1/4] Checking Personal Files (Should be git-ignored)${NC}"
echo ""

check_ignored() {
    local file="$1"
    if [ -f "$file" ]; then
        if git check-ignore -q "$file" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $file ${GREEN}(git-ignored)${NC}"
        else
            echo -e "  ${RED}✗${NC} $file ${RED}(NOT IGNORED - DANGER!)${NC}"
        fi
    else
        echo -e "  ${YELLOW}○${NC} $file ${YELLOW}(not created yet)${NC}"
    fi
}

check_ignored "config/config.json"
check_ignored "config/.dashboard_auth"
check_ignored "logs/telegram-alerts.log"
check_ignored "logs/cache"

echo ""
echo -e "${BLUE}[2/4] Checking Public Template Files (Should be in git)${NC}"
echo ""

check_tracked() {
    local file="$1"
    if [ -f "$file" ]; then
        if git ls-files --error-unmatch "$file" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $file ${GREEN}(tracked in git)${NC}"
        else
            echo -e "  ${RED}✗${NC} $file ${RED}(NOT TRACKED - Should be in git!)${NC}"
        fi
    else
        echo -e "  ${RED}✗${NC} $file ${RED}(missing!)${NC}"
    fi
}

check_tracked "config/config.template.json"
check_tracked "setup.sh"
check_tracked "README.md"
check_tracked "LICENSE"

echo ""
echo -e "${BLUE}[3/4] Checking for Secrets in Tracked Files${NC}"
echo ""

# Run security scan quietly
if ./scripts/utilities/security-scan.sh >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Security scan passed - no secrets in git"
else
    echo -e "  ${RED}✗${NC} Security scan FAILED - run './scripts/utilities/security-scan.sh' for details"
fi

echo ""
echo -e "${BLUE}[4/4] Your Personal Configuration Status${NC}"
echo ""

# Check if personal config exists
if [ -f "config/config.json" ]; then
    echo -e "  ${GREEN}✓${NC} Personal config exists: ${GREEN}config/config.json${NC}"
    
    # Check if it has real credentials or still has placeholders
    if grep -q "YOUR_BOT_TOKEN_HERE" config/config.json 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC}  Still has placeholders - run ${YELLOW}./setup.sh${NC} to configure"
    else
        echo -e "  ${GREEN}✓${NC} Configured with real credentials"
    fi
else
    echo -e "  ${YELLOW}⚠${NC}  No personal config - run ${YELLOW}./setup.sh${NC} to create"
fi

# Check dashboard auth
if [ -f "config/.dashboard_auth" ]; then
    USERNAME=$(jq -r '.username' config/.dashboard_auth 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Dashboard credentials set for user: ${GREEN}$USERNAME${NC}"
else
    echo -e "  ${YELLOW}⚠${NC}  No dashboard credentials - run ${YELLOW}./scripts/utilities/change-dashboard-password.sh${NC}"
fi

echo ""
echo -e "${BLUE}=== Summary ===${NC}\n"

# Count personal vs public files
PERSONAL_COUNT=$(git status --ignored --short | grep -c "^!!" || echo "0")
TRACKED_COUNT=$(git ls-files | wc -l | tr -d ' ')

echo "  Personal files (git-ignored): $PERSONAL_COUNT"
echo "  Public files (in git): $TRACKED_COUNT"

echo ""
echo -e "${GREEN}TIP:${NC} Read LOCAL_VS_PUBLIC.md for detailed explanation"
echo -e "${GREEN}TIP:${NC} Run 'git status --ignored' to see all ignored files"
echo ""
