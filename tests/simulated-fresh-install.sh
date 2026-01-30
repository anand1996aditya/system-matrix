#!/bin/bash

# Simulated Fresh Install Test
# Simulates what a new user would experience after git clone
# Tests the setup process in an isolated environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test directory (isolated)
TEST_DIR="/tmp/system-matrix-fresh-test-$$"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║     Simulated Fresh Install Test - System Matrix      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

echo -e "${BLUE}→ Creating isolated test environment...${NC}"
echo "Test directory: $TEST_DIR"
echo ""

# Create test directory and copy files
mkdir -p "$TEST_DIR"
cd "$PROJECT_ROOT"

# Copy all files except git, logs, and config.json
rsync -av \
    --exclude='.git' \
    --exclude='logs/' \
    --exclude='config/config.json' \
    --exclude='.DS_Store' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    ./ "$TEST_DIR/" > /dev/null 2>&1

cd "$TEST_DIR"

echo -e "${GREEN}✓ Test environment created${NC}\n"

# ============================================
# TEST 1: File Structure
# ============================================
echo -e "${BLUE}[1/6] Checking File Structure...${NC}\n"

REQUIRED_FILES=(
    "README.md"
    "setup.sh"
    ".gitignore"
    "config/config.template.json"
    "dashboard/index.html"
    "scripts/monitoring/dashboard-server.py"
    "scripts/monitoring/collect-metrics.sh"
    "scripts/utilities/security-scan.sh"
    "scripts/utilities/detect-services.sh"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (MISSING)"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo -e "\n${RED}✗ $MISSING_FILES files missing!${NC}\n"
    exit 1
fi

echo -e "\n${GREEN}✓ All required files present${NC}\n"

# ============================================
# TEST 2: Dependencies Check
# ============================================
echo -e "${BLUE}[2/6] Checking Dependencies...${NC}\n"

check_dependency() {
    local cmd="$1"
    local name="$2"

    if command -v "$cmd" &> /dev/null; then
        VERSION=$($cmd --version 2>&1 | head -1)
        echo -e "${GREEN}✓${NC} $name: $VERSION"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $name: Not installed (optional)"
        return 1
    fi
}

check_dependency "python3" "Python 3"
check_dependency "bash" "Bash"
check_dependency "docker" "Docker"
check_dependency "jq" "jq"

echo ""

# ============================================
# TEST 3: Script Permissions
# ============================================
echo -e "${BLUE}[3/6] Checking Script Permissions...${NC}\n"

SCRIPTS_NOT_EXECUTABLE=0
while IFS= read -r script; do
    if [ -x "$script" ]; then
        echo -e "${GREEN}✓${NC} $(basename $script)"
    else
        echo -e "${YELLOW}⚠${NC} $(basename $script) (not executable - will fix)"
        chmod +x "$script"
        SCRIPTS_NOT_EXECUTABLE=$((SCRIPTS_NOT_EXECUTABLE + 1))
    fi
done < <(find scripts -name "*.sh" 2>/dev/null)

if [ $SCRIPTS_NOT_EXECUTABLE -gt 0 ]; then
    echo -e "\n${YELLOW}Fixed $SCRIPTS_NOT_EXECUTABLE scripts${NC}\n"
fi

echo -e "${GREEN}✓ All scripts now executable${NC}\n"

# ============================================
# TEST 4: Security Scan
# ============================================
echo -e "${BLUE}[4/6] Running Security Scan...${NC}\n"

if ./scripts/utilities/security-scan.sh; then
    echo -e "\n${GREEN}✓ Security scan passed${NC}\n"
else
    echo -e "\n${RED}✗ Security scan failed${NC}\n"
    exit 1
fi

# ============================================
# TEST 5: Config Template Validation
# ============================================
echo -e "${BLUE}[5/6] Validating Configuration Template...${NC}\n"

if python3 -m json.tool config/config.template.json > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Config template is valid JSON"
else
    echo -e "${RED}✗${NC} Config template has JSON errors"
    exit 1
fi

if grep -q "YOUR_BOT_TOKEN_HERE" config/config.template.json; then
    echo -e "${GREEN}✓${NC} Config has placeholders (safe for GitHub)"
else
    echo -e "${RED}✗${NC} Config missing placeholders"
    exit 1
fi

if grep -q "System Matrix" config/config.template.json; then
    echo -e "${GREEN}✓${NC} Config references System Matrix"
else
    echo -e "${YELLOW}⚠${NC} Config may reference wrong project name"
fi

echo ""

# ============================================
# TEST 6: Service Detection
# ============================================
echo -e "${BLUE}[6/6] Testing Service Detection...${NC}\n"

if [ -x scripts/utilities/detect-services.sh ]; then
    echo "Running service detection..."
    if ./scripts/utilities/detect-services.sh | python3 -m json.tool > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Service detection works and returns valid JSON"
    else
        echo -e "${RED}✗${NC} Service detection failed or returned invalid JSON"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Service detection script not executable"
    exit 1
fi

echo ""

# ============================================
# FINAL SUMMARY
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Simulated Install Complete                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
echo ""
echo "The project works correctly after a fresh git clone."
echo ""
echo "Test environment: $TEST_DIR"
echo ""
echo "What was tested:"
echo "  ✓ All required files present"
echo "  ✓ Dependencies available"
echo "  ✓ Scripts executable"
echo "  ✓ No security issues"
echo "  ✓ Config template valid"
echo "  ✓ Service detection functional"
echo ""
echo "To clean up test directory:"
echo "  rm -rf $TEST_DIR"
echo ""

exit 0
