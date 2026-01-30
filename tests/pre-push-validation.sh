#!/bin/bash

# Pre-Push Validation Script
# Comprehensive checks before pushing to GitHub
# Run this to ensure everything is ready for public release

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
WARNINGS=0

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║       Pre-Push Validation - System Matrix             ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Testing: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_warning() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Checking: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# ============================================
# SECTION 1: File Structure
# ============================================
echo -e "${BLUE}[1/8] Validating File Structure...${NC}\n"

run_test "README.md exists" "test -f README.md"
run_test "setup.sh exists" "test -f setup.sh"
run_test "setup.sh is executable" "test -x setup.sh"
run_test ".gitignore exists" "test -f .gitignore"
run_test "config template exists" "test -f config/config.template.json"
run_test "dashboard files exist" "test -f dashboard/index.html"
run_test "security scanner exists" "test -f scripts/utilities/security-scan.sh"
run_test "service detector exists" "test -f scripts/utilities/detect-services.sh"

# ============================================
# SECTION 2: Script Syntax Validation
# ============================================
echo -e "\n${BLUE}[2/8] Validating Script Syntax...${NC}\n"

for script in scripts/**/*.sh scripts/**/**/*.sh; do
    if [ -f "$script" ]; then
        run_test "$(basename $script) syntax" "bash -n $script"
    fi
done

# ============================================
# SECTION 3: Python Scripts
# ============================================
echo -e "\n${BLUE}[3/8] Validating Python Scripts...${NC}\n"

run_test "dashboard-server.py syntax" "python3 -m py_compile scripts/monitoring/dashboard-server.py"
run_test "config_loader.py syntax" "python3 -m py_compile scripts/utilities/config_loader.py"

# ============================================
# SECTION 4: JSON Validation
# ============================================
echo -e "\n${BLUE}[4/8] Validating JSON Files...${NC}\n"

run_test "config.template.json is valid JSON" "python3 -m json.tool config/config.template.json > /dev/null"

# ============================================
# SECTION 5: Security Scan
# ============================================
echo -e "\n${BLUE}[5/8] Running Security Scan...${NC}\n"

if ./scripts/utilities/security-scan.sh > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Security scan passed${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Security scan failed - CRITICAL!${NC}"
    echo "Run: ./scripts/utilities/security-scan.sh for details"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================
# SECTION 6: Documentation
# ============================================
echo -e "\n${BLUE}[6/8] Checking Documentation...${NC}\n"

run_test "README.md not empty" "test -s README.md"
run_warning "QUICK_START.md exists" "test -f QUICK_START.md"
run_warning "Fresh clone verification exists" "test -f FRESH_CLONE_VERIFICATION.md"

# ============================================
# SECTION 7: No Hardcoded Values
# ============================================
echo -e "\n${BLUE}[7/8] Checking for Hardcoded Values...${NC}\n"

run_test "No /Users/aditya paths" "! grep -r '/Users/aditya' scripts/ --include='*.sh' --include='*.py' --exclude='*security-scan*' --exclude='*verify-fresh*'"
run_test "No hardcoded tokens" "! grep -r '[0-9]\{9,10\}:[A-Za-z0-9_-]\{35\}' scripts/ --include='*.sh' --exclude='*security-scan*'"
run_test "Config has placeholders" "grep -q 'YOUR_BOT_TOKEN_HERE' config/config.template.json"

# ============================================
# SECTION 8: Naming Consistency
# ============================================
echo -e "\n${BLUE}[8/8] Checking Naming Consistency...${NC}\n"

run_test "Project is 'System Matrix'" "grep -q 'System Matrix' README.md"
run_test "Folder is 'System-Matrix'" "basename $(pwd) | grep -q 'System-Matrix'"
run_test "Config references System Matrix" "grep -q 'System Matrix Dashboard' config/config.template.json"

# ============================================
# FINAL SUMMARY
# ============================================
echo -e "\n${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Validation Complete                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ READY FOR GITHUB!${NC}"
    echo ""
    echo "All critical tests passed. Your code is ready to push."
    echo ""
    echo "Next steps:"
    echo "  1. git init"
    echo "  2. git add ."
    echo "  3. git commit -m 'Initial commit'"
    echo "  4. git remote add origin https://github.com/YOUR_USERNAME/REPO.git"
    echo "  5. git push -u origin main"
    echo ""
    exit 0
else
    echo -e "${RED}❌ NOT READY - Fix issues above${NC}"
    echo ""
    echo "Please resolve the failed tests before pushing to GitHub."
    echo ""
    exit 1
fi
