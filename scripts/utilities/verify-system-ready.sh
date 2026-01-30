#!/bin/bash

# System Ready Verification Script
# Checks that all components are properly configured for out-of-box deployment

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

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SYSTEM MATRIX - DEPLOYMENT VERIFICATION          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    if [ -n "$2" ]; then
        echo -e "    ${YELLOW}Fix: $2${NC}"
    fi
    FAILED=$((FAILED + 1))
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

# ============================================
# 1. FILE LOCATIONS & PATHS
# ============================================
echo -e "${BLUE}[1/6] Checking File Locations & Paths${NC}"
echo ""

# Check no hardcoded user paths in scripts (exclude test and verification scripts that check for them)
if grep -r "/Users/aditya" scripts/ dashboard/ \
   --include="*.sh" --include="*.py" --include="*.html" \
   --exclude="*.md" --exclude="*verify*" --exclude="*test*" --exclude="security-scan.sh" 2>/dev/null \
   | grep -v "grep -r"; then
    check_fail "Hardcoded user paths found in scripts" "Replace with \${HOME} or config-based paths"
else
    check_pass "No hardcoded user paths in scripts"
fi

# Check config files exist
if [ -f "config/config.template.json" ]; then
    check_pass "Config template exists"
else
    check_fail "Config template missing" "Create config/config.template.json"
fi

# Check dashboard files exist
if [ -f "dashboard/index.html" ] && [ -f "dashboard/file-browser.html" ]; then
    check_pass "Dashboard files exist"
else
    check_fail "Dashboard files missing" "Check dashboard/ directory"
fi

# Check main scripts exist
CRITICAL_SCRIPTS=(
    "scripts/monitoring/dashboard-server.py"
    "scripts/monitoring/collect-metrics.sh"
    "scripts/automation/unified-automation.sh"
    "scripts/utilities/config-loader.sh"
    "scripts/utilities/detect-services.sh"
    "setup.sh"
)

for script in "${CRITICAL_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        check_pass "Script exists: $script"
    else
        check_fail "Script missing: $script" "Restore from git"
    fi
done

echo ""

# ============================================
# 2. SERVICE DETECTION
# ============================================
echo -e "${BLUE}[2/6] Checking Service Detection${NC}"
echo ""

# Run service detection
if [ -x "scripts/utilities/detect-services.sh" ]; then
    SERVICES_JSON=$(./scripts/utilities/detect-services.sh 2>/dev/null)
    check_pass "Service detection script works"
    
    # Check specific services
    if echo "$SERVICES_JSON" | jq -e '.docker.installed' >/dev/null 2>&1; then
        if [ "$(echo "$SERVICES_JSON" | jq -r '.docker.installed')" = "true" ]; then
            check_pass "Docker detected"
        else
            check_warn "Docker not installed (optional)"
        fi
    fi
    
    if echo "$SERVICES_JSON" | jq -e '.plex.installed' >/dev/null 2>&1; then
        if [ "$(echo "$SERVICES_JSON" | jq -r '.plex.installed')" = "true" ]; then
            check_pass "Plex detected"
        else
            check_warn "Plex not installed (optional)"
        fi
    fi
    
    if echo "$SERVICES_JSON" | jq -e '.caddy.installed' >/dev/null 2>&1; then
        if [ "$(echo "$SERVICES_JSON" | jq -r '.caddy.installed')" = "true" ]; then
            check_pass "Caddy detected"
        else
            check_warn "Caddy not installed (optional)"
        fi
    fi
    
    if echo "$SERVICES_JSON" | jq -e '.clawdbot.installed' >/dev/null 2>&1; then
        if [ "$(echo "$SERVICES_JSON" | jq -r '.clawdbot.installed')" = "true" ]; then
            check_pass "ClawdBot detected"
        else
            check_warn "ClawdBot not installed (optional)"
        fi
    fi
    
    # Check drives
    DRIVE_COUNT=$(echo "$SERVICES_JSON" | jq '.drives | length' 2>/dev/null || echo 0)
    if [ "$DRIVE_COUNT" -gt 0 ]; then
        check_pass "External drives detected: $DRIVE_COUNT"
    else
        check_warn "No external drives detected (optional)"
    fi
else
    check_fail "Service detection script not executable" "chmod +x scripts/utilities/detect-services.sh"
fi

echo ""

# ============================================
# 3. UNIFIED AUTOMATION SCRIPT
# ============================================
echo -e "${BLUE}[3/6] Checking Unified Automation${NC}"
echo ""

if [ -f "scripts/automation/unified-automation.sh" ]; then
    # Check it uses config loader
    if grep -q "config-loader.sh" scripts/automation/unified-automation.sh; then
        check_pass "Uses config loader"
    else
        check_fail "Doesn't use config loader" "Add config-loader.sh sourcing"
    fi
    
    # Check for hardcoded paths
    if grep -q "/Users/" scripts/automation/unified-automation.sh; then
        check_warn "May contain user-specific paths"
    else
        check_pass "No hardcoded user paths"
    fi
    
    # Check if executable
    if [ -x "scripts/automation/unified-automation.sh" ]; then
        check_pass "Script is executable"
    else
        check_fail "Script not executable" "chmod +x scripts/automation/unified-automation.sh"
    fi
else
    check_fail "Unified automation script missing"
fi

echo ""

# ============================================
# 4. FILE BROWSER
# ============================================
echo -e "${BLUE}[4/6] Checking File Browser${NC}"
echo ""

if [ -f "dashboard/file-browser.html" ]; then
    check_pass "File browser HTML exists"
    
    # Check dashboard server has file browser support
    if grep -q "file-browser\|get_drives" scripts/monitoring/dashboard-server.py; then
        check_pass "Dashboard server has file browser support"
    else
        check_fail "Dashboard server missing file browser" "Add file browser routes"
    fi
    
    # Check auto-detection
    if grep -q "auto_detect.*drives\|get_drives" scripts/monitoring/dashboard-server.py; then
        check_pass "Drives are auto-detected"
    else
        check_warn "Drives may not be auto-detected"
    fi
else
    check_fail "File browser HTML missing"
fi

echo ""

# ============================================
# 5. CONFIGURATION SECURITY
# ============================================
echo -e "${BLUE}[5/6] Checking Configuration Security${NC}"
echo ""

# Check .gitignore
if grep -q "config/config.json" .gitignore; then
    check_pass "config.json is git-ignored"
else
    check_fail "config.json not in .gitignore" "Add to .gitignore"
fi

if grep -q "config/.dashboard_auth" .gitignore; then
    check_pass ".dashboard_auth is git-ignored"
else
    check_fail ".dashboard_auth not in .gitignore" "Add to .gitignore"
fi

# Check template has placeholders
if grep -q "YOUR_BOT_TOKEN_HERE" config/config.template.json; then
    check_pass "Template has bot token placeholder"
else
    check_fail "Template missing bot token placeholder" "Add YOUR_BOT_TOKEN_HERE"
fi

# Run security scan
if [ -x "scripts/utilities/security-scan.sh" ]; then
    if ./scripts/utilities/security-scan.sh >/dev/null 2>&1; then
        check_pass "Security scan passes"
    else
        check_fail "Security scan failed" "Run ./scripts/utilities/security-scan.sh for details"
    fi
else
    check_warn "Security scan script not found"
fi

echo ""

# ============================================
# 6. OUT-OF-BOX READINESS
# ============================================
echo -e "${BLUE}[6/6] Out-of-Box Deployment Check${NC}"
echo ""

# Check README exists and is comprehensive
if [ -f "README.md" ]; then
    README_LINES=$(wc -l < README.md)
    if [ "$README_LINES" -gt 100 ]; then
        check_pass "README is comprehensive ($README_LINES lines)"
    else
        check_warn "README may be incomplete"
    fi
fi

# Check LICENSE exists
if [ -f "LICENSE" ]; then
    check_pass "LICENSE file exists"
else
    check_warn "LICENSE file missing"
fi

# Check setup.sh exists
if [ -f "setup.sh" ] && [ -x "setup.sh" ]; then
    check_pass "Setup script exists and is executable"
else
    check_fail "Setup script missing or not executable" "chmod +x setup.sh"
fi

# Check GitHub templates
if [ -f ".github/ISSUE_TEMPLATE/bug_report.md" ]; then
    check_pass "GitHub issue templates exist"
else
    check_warn "GitHub issue templates missing"
fi

# Check contributing guide
if [ -f "CONTRIBUTING.md" ]; then
    check_pass "Contributing guide exists"
else
    check_warn "CONTRIBUTING.md missing"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    SUMMARY                           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✅ SYSTEM READY FOR DEPLOYMENT${NC}"
    echo ""
    echo "Your System Matrix is ready to be pushed to GitHub!"
    echo "Anyone who clones it will be able to:"
    echo "  1. Run ./setup.sh"
    echo "  2. Configure their credentials"
    echo "  3. Start monitoring immediately"
    exit 0
else
    echo -e "${RED}❌ FIXES REQUIRED BEFORE DEPLOYMENT${NC}"
    echo ""
    echo "Please fix the failed checks above before pushing."
    exit 1
fi
