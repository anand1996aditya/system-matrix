#!/bin/bash

# Security Test Suite
# Validates that the configuration system is working correctly
# and no secrets are hardcoded

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Testing: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Security Test Suite                       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# ============================================
# CONFIGURATION TESTS
# ============================================
echo -e "${BLUE}[1/3] Configuration System Tests${NC}\n"

run_test "Config template exists" \
    "[ -f config/config.template.json ]"

run_test "Config template has bot token placeholder" \
    "grep -q 'YOUR_BOT_TOKEN_HERE' config/config.template.json"

run_test "Config template has chat ID placeholder" \
    "grep -q 'YOUR_CHAT_ID_HERE' config/config.template.json"

run_test "Config template is valid JSON" \
    "python3 -m json.tool config/config.template.json"

run_test "Bash config loader exists" \
    "[ -f scripts/utilities/config-loader.sh ]"

run_test "Python config loader exists" \
    "[ -f scripts/utilities/config_loader.py ]"

run_test "Python config loader is executable" \
    "[ -x scripts/utilities/config_loader.py ]"

# ============================================
# SECURITY SCANNER TESTS
# ============================================
echo -e "\n${BLUE}[2/3] Security Scanner Tests${NC}\n"

run_test "Security scanner exists" \
    "[ -f scripts/utilities/security-scan.sh ]"

run_test "Security scanner is executable" \
    "[ -x scripts/utilities/security-scan.sh ]"

run_test "Git hooks directory exists" \
    "[ -d .git-hooks ]"

run_test "Pre-commit hook exists" \
    "[ -f .git-hooks/pre-commit ]"

run_test "Hook installer exists" \
    "[ -f scripts/utilities/install-git-hooks.sh ]"

run_test "GitHub Actions workflow exists" \
    "[ -f .github/workflows/security-scan.yml ]"

# ============================================
# GITIGNORE TESTS
# ============================================
echo -e "\n${BLUE}[3/3] .gitignore Tests${NC}\n"

run_test ".gitignore exists" \
    "[ -f .gitignore ]"

run_test ".gitignore excludes config.json" \
    "grep -q 'config/config.json' .gitignore"

run_test ".gitignore excludes .dashboard_auth" \
    "grep -q '.dashboard_auth' .gitignore"

run_test ".gitignore excludes logs" \
    "grep -q 'logs/' .gitignore"

run_test ".gitignore excludes alert state" \
    "grep -q 'alert-state' .gitignore"

run_test ".gitignore excludes cache" \
    "grep -q 'cache' .gitignore"

# ============================================
# SCRIPT VALIDATION TESTS
# ============================================
echo -e "\n${BLUE}[Bonus] Script Validation${NC}\n"

run_test "Telegram alert script uses config" \
    "grep -q 'config-loader.sh' scripts/notifications/send-telegram-alert.sh"

run_test "Unified automation uses config" \
    "grep -q 'config-loader.sh' scripts/automation/unified-automation.sh"

run_test "Collect metrics uses config" \
    "grep -q 'config-loader.sh' scripts/monitoring/collect-metrics.sh"

run_test "Dashboard server uses config" \
    "grep -q 'config_loader' scripts/monitoring/dashboard-server.py"

run_test "No hardcoded Telegram tokens in scripts" \
    "! grep -r '[0-9]\{9,10\}:[A-Za-z0-9_-]\{35\}' scripts/ --include='*.sh' --include='*.py' --exclude='*test*'"

run_test "No /Users/aditya in scripts" \
    "! grep -r '/Users/aditya' scripts/ --include='*.sh' --include='*.py'"

# ============================================
# SUMMARY
# ============================================
echo -e "\n${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test Results                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Some tests failed. Please review and fix.${NC}"
    exit 1
else
    echo -e "Failed: ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}✅ All tests passed! Security configuration is correct.${NC}"
    exit 0
fi
