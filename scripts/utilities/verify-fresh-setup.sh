#!/bin/bash

# Fresh Setup Verification Script
# Simulates what a new user would experience after git clone
# Checks for hardcoded values, missing files, and setup issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

ISSUES_FOUND=0
WARNINGS_FOUND=0
CHECKS_PASSED=0

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║       Fresh Clone Verification - Pre-flight Check     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Function to report results
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    echo -e "   ${YELLOW}$2${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    echo -e "   $2"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
}

# ============================================
# SECTION 1: Required Files Structure
# ============================================
echo -e "${BLUE}[1/7] Checking Required Files...${NC}\n"

# Core directories
required_dirs=(
    "dashboard"
    "scripts/automation"
    "scripts/monitoring"
    "scripts/notifications"
    "scripts/utilities"
    "config"
    "config/launchagents"
    "docs/setup"
    ".github/workflows"
    ".git-hooks"
    "tests"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        check_pass "Directory exists: $dir/"
    else
        check_fail "Missing directory: $dir/" "Create this directory"
    fi
done

# Essential files
required_files=(
    "setup.sh"
    "README.md"
    ".gitignore"
    "config/config.template.json"
    "scripts/utilities/config-loader.sh"
    "scripts/utilities/config_loader.py"
    "scripts/utilities/security-scan.sh"
    "scripts/utilities/install-git-hooks.sh"
    "scripts/automation/unified-automation.sh"
    "scripts/monitoring/collect-metrics.sh"
    "scripts/monitoring/dashboard-server.py"
    "scripts/notifications/send-telegram-alert.sh"
    ".git-hooks/pre-commit"
    ".github/workflows/security-scan.yml"
    "tests/test-security.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        check_pass "File exists: $file"
    else
        check_fail "Missing file: $file" "This file is required for the system to work"
    fi
done

# ============================================
# SECTION 2: Executable Permissions
# ============================================
echo -e "\n${BLUE}[2/7] Checking Executable Permissions...${NC}\n"

executable_files=(
    "setup.sh"
    "scripts/utilities/config-loader.sh"
    "scripts/utilities/config_loader.py"
    "scripts/utilities/security-scan.sh"
    "scripts/utilities/install-git-hooks.sh"
    "scripts/automation/unified-automation.sh"
    "scripts/monitoring/collect-metrics.sh"
    "scripts/monitoring/dashboard-server.py"
    "scripts/notifications/send-telegram-alert.sh"
    ".git-hooks/pre-commit"
    "tests/test-security.sh"
)

for file in "${executable_files[@]}"; do
    if [ -f "$file" ]; then
        if [ -x "$file" ]; then
            check_pass "Executable: $file"
        else
            check_warn "Not executable: $file" "Run: chmod +x $file"
        fi
    fi
done

# ============================================
# SECTION 3: Hardcoded Values Check
# ============================================
echo -e "\n${BLUE}[3/7] Checking for Hardcoded Values...${NC}\n"

# Check for hardcoded Telegram tokens
if grep -r '[0-9]\{9,10\}:[A-Za-z0-9_-]\{35\}' scripts/ \
   --include='*.sh' --include='*.py' \
   --exclude='security-scan.sh' \
   --exclude='*test*' 2>/dev/null; then
    check_fail "Found hardcoded Telegram token" "Move to config.json"
else
    check_pass "No hardcoded Telegram tokens"
fi

# Check for hardcoded user paths (excluding verify/test scripts that check for them)
if grep -r '/Users/aditya' scripts/ dashboard/ \
   --include='*.sh' --include='*.py' --include='*.html' \
   --exclude='*.md' --exclude='*verify*' --exclude='*test*' --exclude='security-scan.sh' 2>/dev/null \
   | grep -v "grep -r.*Users"; then
    check_fail "Found hardcoded user path /Users/aditya" "Use \$HOME or config variables"
else
    check_pass "No hardcoded user paths"
fi

# Check for hardcoded port numbers (except in config template)
if grep -r 'PORT\s*=\s*[0-9]\{4\}' scripts/ \
   --include='*.sh' --include='*.py' \
   | grep -v 'config' 2>/dev/null; then
    check_warn "Found potential hardcoded port" "Verify it uses config"
else
    check_pass "No hardcoded ports outside config"
fi

# ============================================
# SECTION 4: Configuration System
# ============================================
echo -e "\n${BLUE}[4/7] Checking Configuration System...${NC}\n"

# Config template exists
if [ -f "config/config.template.json" ]; then
    check_pass "Config template exists"

    # Validate JSON
    if python3 -m json.tool config/config.template.json > /dev/null 2>&1; then
        check_pass "Config template is valid JSON"
    else
        check_fail "Config template has invalid JSON" "Fix JSON syntax errors"
    fi

    # Check for placeholders
    if grep -q "YOUR_BOT_TOKEN_HERE" config/config.template.json; then
        check_pass "Config template has bot token placeholder"
    else
        check_fail "Config template missing bot token placeholder" "Add YOUR_BOT_TOKEN_HERE"
    fi

    if grep -q "YOUR_CHAT_ID_HERE" config/config.template.json; then
        check_pass "Config template has chat ID placeholder"
    else
        check_fail "Config template missing chat ID placeholder" "Add YOUR_CHAT_ID_HERE"
    fi
else
    check_fail "Config template not found" "Create config/config.template.json"
fi

# Config loaders exist
if [ -f "scripts/utilities/config-loader.sh" ]; then
    check_pass "Bash config loader exists"

    # Check it has the necessary functions
    if grep -q "get_config" scripts/utilities/config-loader.sh; then
        check_pass "Config loader has get_config function"
    else
        check_warn "Config loader missing get_config function" "May not work properly"
    fi
else
    check_fail "Bash config loader missing" "Required for scripts"
fi

if [ -f "scripts/utilities/config_loader.py" ]; then
    check_pass "Python config loader exists"

    # Check it has ConfigLoader class
    if grep -q "class ConfigLoader" scripts/utilities/config_loader.py; then
        check_pass "Config loader has ConfigLoader class"
    else
        check_warn "Config loader missing ConfigLoader class" "May not work properly"
    fi
else
    check_fail "Python config loader missing" "Required for dashboard"
fi

# ============================================
# SECTION 5: .gitignore Configuration
# ============================================
echo -e "\n${BLUE}[5/7] Checking .gitignore...${NC}\n"

if [ -f ".gitignore" ]; then
    check_pass ".gitignore exists"

    # Check critical exclusions
    critical_exclusions=(
        "config/config.json"
        ".dashboard_auth"
        "logs/"
    )

    for exclusion in "${critical_exclusions[@]}"; do
        if grep -q "$exclusion" .gitignore; then
            check_pass ".gitignore excludes: $exclusion"
        else
            check_fail ".gitignore missing: $exclusion" "Add to .gitignore immediately!"
        fi
    done
else
    check_fail ".gitignore not found" "Create .gitignore to protect secrets"
fi

# Check if sensitive files are tracked
if [ -d ".git" ]; then
    if git ls-files | grep -q "config/config.json"; then
        check_fail "config.json is tracked by git!" "Run: git rm --cached config/config.json"
    else
        check_pass "config.json not tracked by git"
    fi

    if git ls-files | grep -q ".dashboard_auth"; then
        check_fail ".dashboard_auth is tracked by git!" "Run: git rm --cached .dashboard_auth"
    else
        check_pass ".dashboard_auth not tracked by git"
    fi
fi

# ============================================
# SECTION 6: Dependencies & Requirements
# ============================================
echo -e "\n${BLUE}[6/7] Checking Dependencies...${NC}\n"

# Check for required commands
commands=(
    "python3:Python 3"
    "bash:Bash shell"
    "git:Git version control"
)

for cmd_info in "${commands[@]}"; do
    cmd="${cmd_info%%:*}"
    name="${cmd_info#*:}"

    if command -v "$cmd" &> /dev/null; then
        version=$($cmd --version 2>&1 | head -1)
        check_pass "$name available: $version"
    else
        check_fail "$name not found" "Install $name"
    fi
done

# Optional but recommended
optional_commands=(
    "docker:Docker (for containers)"
    "jq:JSON processor (for testing)"
)

for cmd_info in "${optional_commands[@]}"; do
    cmd="${cmd_info%%:*}"
    name="${cmd_info#*:}"

    if command -v "$cmd" &> /dev/null; then
        check_pass "$name available (optional)"
    else
        check_warn "$name not found (optional)" "Install if using containers/testing"
    fi
done

# ============================================
# SECTION 7: Setup Script Validation
# ============================================
echo -e "\n${BLUE}[7/7] Checking Setup Script...${NC}\n"

if [ -f "setup.sh" ]; then
    check_pass "setup.sh exists"

    if [ -x "setup.sh" ]; then
        check_pass "setup.sh is executable"
    else
        check_warn "setup.sh not executable" "Run: chmod +x setup.sh"
    fi

    # Check setup script has key sections
    if grep -q "update_json" setup.sh; then
        check_pass "Setup script has config update function"
    else
        check_warn "Setup script may be incomplete" "Verify functionality"
    fi

    if grep -q "Telegram" setup.sh; then
        check_pass "Setup script configures Telegram"
    else
        check_warn "Setup script may not configure Telegram" "Check implementation"
    fi
else
    check_fail "setup.sh not found" "Required for initial configuration"
fi

# ============================================
# FINAL SUMMARY
# ============================================
echo -e "\n${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Verification Complete                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

TOTAL_CHECKS=$((CHECKS_PASSED + ISSUES_FOUND + WARNINGS_FOUND))

echo "Total Checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS_FOUND${NC}"
echo -e "Failed: ${RED}$ISSUES_FOUND${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ READY FOR GITHUB!${NC}"
    echo ""
    echo "All checks passed. This project will work correctly when cloned."
    echo ""
    echo "Next steps:"
    echo "  1. git init"
    echo "  2. git add ."
    echo "  3. git commit -m 'Initial commit'"
    echo "  4. git push to GitHub"
    echo ""
    exit 0
elif [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS FOUND${NC}"
    echo ""
    echo "No critical issues, but please review warnings above."
    echo "The project should work, but some features may need attention."
    echo ""
    exit 0
else
    echo -e "${RED}❌ ISSUES FOUND - NOT READY FOR GITHUB${NC}"
    echo ""
    echo "Please fix the issues above before pushing to GitHub."
    echo ""
    echo "Common fixes:"
    echo "  • Move secrets to config.json"
    echo "  • Replace hardcoded paths with variables"
    echo "  • Add missing files"
    echo "  • Update .gitignore"
    echo ""
    echo "Run this script again after fixes:"
    echo "  ./scripts/utilities/verify-fresh-setup.sh"
    echo ""
    exit 1
fi
