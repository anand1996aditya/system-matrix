#!/bin/bash

# Master Test Runner
# Runs all tests and generates comprehensive report

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║     SYSTEM MATRIX - COMPREHENSIVE TEST SUITE         ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

echo -e "${BLUE}This will run all validation tests before GitHub push.${NC}"
echo -e "${BLUE}Tests will verify code quality, security, and functionality.${NC}"
echo ""

read -p "Press Enter to continue..." -r
echo ""

# Track overall status
OVERALL_STATUS=0

# ============================================
# TEST SUITE 1: Pre-Push Validation
# ============================================
echo -e "${CYAN}"
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  TEST SUITE 1: Pre-Push Validation                    ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo -e "${NC}\n"

if "$SCRIPT_DIR/pre-push-validation.sh"; then
    echo -e "\n${GREEN}✅ Pre-Push Validation: PASSED${NC}\n"
else
    echo -e "\n${RED}❌ Pre-Push Validation: FAILED${NC}\n"
    OVERALL_STATUS=1
fi

read -p "Press Enter to continue to next test..." -r
echo ""

# ============================================
# TEST SUITE 2: Simulated Fresh Install
# ============================================
echo -e "${CYAN}"
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  TEST SUITE 2: Simulated Fresh Install                ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo -e "${NC}\n"

if "$SCRIPT_DIR/simulated-fresh-install.sh"; then
    echo -e "\n${GREEN}✅ Simulated Fresh Install: PASSED${NC}\n"
else
    echo -e "\n${RED}❌ Simulated Fresh Install: FAILED${NC}\n"
    OVERALL_STATUS=1
fi

# ============================================
# FINAL REPORT
# ============================================
echo ""
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║                  FINAL TEST REPORT                     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

if [ $OVERALL_STATUS -eq 0 ]; then
    echo -e "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${GREEN}┃                                                        ┃${NC}"
    echo -e "${GREEN}┃              ✅ ALL TESTS PASSED! ✅                   ┃${NC}"
    echo -e "${GREEN}┃                                                        ┃${NC}"
    echo -e "${GREEN}┃        System Matrix is ready for GitHub! 🚀          ┃${NC}"
    echo -e "${GREEN}┃                                                        ┃${NC}"
    echo -e "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
    echo "Test Results:"
    echo "  ✓ Pre-Push Validation: PASSED"
    echo "  ✓ Simulated Fresh Install: PASSED"
    echo ""
    echo "You can now safely push to GitHub!"
    echo ""
    echo "Next steps:"
    echo "  1. Provide GitHub credentials"
    echo "  2. Initialize git repository"
    echo "  3. Commit and push to GitHub"
    echo ""
else
    echo -e "${RED}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${RED}┃                                                        ┃${NC}"
    echo -e "${RED}┃                ❌ TESTS FAILED ❌                      ┃${NC}"
    echo -e "${RED}┃                                                        ┃${NC}"
    echo -e "${RED}┃         Please review errors above                     ┃${NC}"
    echo -e "${RED}┃                                                        ┃${NC}"
    echo -e "${RED}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
    echo "Some tests failed. Please fix the issues and run again."
    echo ""
fi

exit $OVERALL_STATUS
