#!/bin/bash

# System Matrix - Automatic Dependency Installer
# Installs all required and optional dependencies automatically

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     System Matrix - Dependency Installer             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}✗ This script only works on macOS${NC}"
    echo "System Matrix is designed for macOS systems."
    exit 1
fi

echo "This script will automatically install missing dependencies."
echo "You'll be prompted before each installation."
echo ""

DEPS_INSTALLED=0
DEPS_SKIPPED=0
DEPS_FAILED=0

# ============================================
# 1. CHECK HOMEBREW
# ============================================
echo -e "${BLUE}[1/5] Checking Homebrew...${NC}"

if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}⚠️  Homebrew not found${NC}"
    echo ""
    echo "Homebrew is the package manager for macOS. It's required to install"
    echo "other dependencies like Python, jq, Docker, etc."
    echo ""
    echo "Install from: https://brew.sh"
    echo ""
    read -p "Install Homebrew now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo ""
            echo "Detected Apple Silicon Mac. Adding Homebrew to PATH..."

            # Add to zsh profile if it exists
            if [ -f "$HOME/.zprofile" ]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            fi

            # Add to bash profile if it exists
            if [ -f "$HOME/.bash_profile" ]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
            fi

            # Apply to current session
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        # Verify installation
        if command -v brew &> /dev/null; then
            echo -e "${GREEN}✓ Homebrew installed successfully${NC}"
            DEPS_INSTALLED=$((DEPS_INSTALLED + 1))
        else
            echo -e "${RED}✗ Homebrew installation failed${NC}"
            echo "Please install manually from: https://brew.sh"
            exit 1
        fi
    else
        echo -e "${RED}✗ Homebrew is required to continue${NC}"
        echo "Install manually from: https://brew.sh"
        echo "Then run this script again."
        exit 1
    fi
else
    BREW_VERSION=$(brew --version | head -1)
    echo -e "${GREEN}✓ Homebrew already installed ($BREW_VERSION)${NC}"
fi

echo ""

# ============================================
# 2. CHECK PYTHON 3
# ============================================
echo -e "${BLUE}[2/5] Checking Python 3...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}⚠️  Python 3 not found${NC}"
    echo ""
    echo "Python 3 is required to run the dashboard server and metrics collection."
    echo ""
    read -p "Install Python 3 via Homebrew? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Installing Python 3..."
        brew install python3

        if command -v python3 &> /dev/null; then
            PYTHON_VERSION=$(python3 --version)
            echo -e "${GREEN}✓ Python 3 installed successfully ($PYTHON_VERSION)${NC}"
            DEPS_INSTALLED=$((DEPS_INSTALLED + 1))
        else
            echo -e "${RED}✗ Python 3 installation failed${NC}"
            DEPS_FAILED=$((DEPS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗ Python 3 is required${NC}"
        echo "Install manually: brew install python3"
        exit 1
    fi
else
    PYTHON_VERSION=$(python3 --version)
    PYTHON_PATH=$(which python3)
    echo -e "${GREEN}✓ Python 3 already installed${NC}"
    echo "  Version: $PYTHON_VERSION"
    echo "  Path: $PYTHON_PATH"
fi

echo ""

# ============================================
# 3. CHECK JQ (JSON PROCESSOR)
# ============================================
echo -e "${BLUE}[3/5] Checking jq (JSON processor)...${NC}"

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq not found (optional but recommended)${NC}"
    echo ""
    echo "jq is a command-line JSON processor. It's used for config validation"
    echo "and testing. Not required, but highly recommended."
    echo ""
    read -p "Install jq? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        echo "Installing jq..."
        brew install jq

        if command -v jq &> /dev/null; then
            JQ_VERSION=$(jq --version)
            echo -e "${GREEN}✓ jq installed successfully ($JQ_VERSION)${NC}"
            DEPS_INSTALLED=$((DEPS_INSTALLED + 1))
        else
            echo -e "${RED}✗ jq installation failed${NC}"
            DEPS_FAILED=$((DEPS_FAILED + 1))
        fi
    else
        echo -e "${YELLOW}⚠️  Skipping jq (some features may not work optimally)${NC}"
        DEPS_SKIPPED=$((DEPS_SKIPPED + 1))
    fi
else
    JQ_VERSION=$(jq --version)
    echo -e "${GREEN}✓ jq already installed ($JQ_VERSION)${NC}"
fi

echo ""

# ============================================
# 4. OPTIONAL SERVICES
# ============================================
echo -e "${BLUE}[4/5] Checking Optional Services...${NC}"
echo ""
echo "The following services are optional but enhance System Matrix functionality:"
echo ""

# Docker
echo -e "${YELLOW}→ Docker${NC}"
if ! command -v docker &> /dev/null; then
    echo "  Status: Not installed"
    echo "  Purpose: Run containerized services (Pi-hole, Plex, etc.)"
    echo ""
    read -p "  Install Docker Desktop? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Installing Docker Desktop..."
        brew install --cask docker

        if command -v docker &> /dev/null; then
            echo -e "${GREEN}  ✓ Docker Desktop installed${NC}"
            echo -e "${YELLOW}  → Please open Docker.app to complete setup${NC}"
            DEPS_INSTALLED=$((DEPS_INSTALLED + 1))
        else
            echo -e "${RED}  ✗ Docker Desktop installation failed${NC}"
            echo "  Install manually from: https://www.docker.com/products/docker-desktop"
            DEPS_FAILED=$((DEPS_FAILED + 1))
        fi
    else
        echo -e "${YELLOW}  ⊘ Skipping Docker${NC}"
        DEPS_SKIPPED=$((DEPS_SKIPPED + 1))
    fi
else
    DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}  ✓ Docker already installed ($DOCKER_VERSION)${NC}"
fi

echo ""

# Tailscale
echo -e "${YELLOW}→ Tailscale${NC}"
if ! command -v tailscale &> /dev/null && ! pgrep -x "Tailscale" > /dev/null; then
    echo "  Status: Not installed"
    echo "  Purpose: Secure remote access to your dashboard from anywhere"
    echo ""
    read -p "  Install Tailscale? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Installing Tailscale..."
        brew install --cask tailscale

        if command -v tailscale &> /dev/null || [ -d "/Applications/Tailscale.app" ]; then
            echo -e "${GREEN}  ✓ Tailscale installed${NC}"
            echo -e "${YELLOW}  → Please open Tailscale.app to complete setup${NC}"
            DEPS_INSTALLED=$((DEPS_INSTALLED + 1))
        else
            echo -e "${RED}  ✗ Tailscale installation failed${NC}"
            echo "  Install manually from: https://tailscale.com/download/mac"
            DEPS_FAILED=$((DEPS_FAILED + 1))
        fi
    else
        echo -e "${YELLOW}  ⊘ Skipping Tailscale${NC}"
        DEPS_SKIPPED=$((DEPS_SKIPPED + 1))
    fi
else
    if command -v tailscale &> /dev/null; then
        TAILSCALE_VERSION=$(tailscale version | head -1)
        echo -e "${GREEN}  ✓ Tailscale already installed ($TAILSCALE_VERSION)${NC}"
    else
        echo -e "${GREEN}  ✓ Tailscale already installed (GUI)${NC}"
    fi
fi

echo ""

# ============================================
# 5. VERIFY INSTALLATION
# ============================================
echo -e "${BLUE}[5/5] Verifying Installation...${NC}"
echo ""

REQUIRED_MISSING=()
OPTIONAL_MISSING=()

# Check required dependencies
if ! command -v brew &> /dev/null; then
    REQUIRED_MISSING+=("Homebrew")
fi

if ! command -v python3 &> /dev/null; then
    REQUIRED_MISSING+=("Python 3")
fi

# Check optional dependencies
if ! command -v jq &> /dev/null; then
    OPTIONAL_MISSING+=("jq")
fi

if ! command -v docker &> /dev/null; then
    OPTIONAL_MISSING+=("Docker")
fi

if ! command -v tailscale &> /dev/null && ! pgrep -x "Tailscale" > /dev/null; then
    OPTIONAL_MISSING+=("Tailscale")
fi

# Report results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ${#REQUIRED_MISSING[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All required dependencies installed!${NC}"
else
    echo -e "${RED}✗ Missing required dependencies: ${REQUIRED_MISSING[*]}${NC}"
fi

if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Optional dependencies not installed: ${OPTIONAL_MISSING[*]}${NC}"
    echo "  (You can install these later if needed)"
fi

echo ""
echo "Installation Summary:"
echo "  Installed: $DEPS_INSTALLED"
echo "  Skipped: $DEPS_SKIPPED"
echo "  Failed: $DEPS_FAILED"
echo ""

if [ ${#REQUIRED_MISSING[@]} -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Installation Complete!                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "🎉 System Matrix is ready to set up!"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./setup.sh"
    echo "  2. Follow the setup wizard"
    echo "  3. Start monitoring!"
    echo ""

    if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
        echo "Optional: Install skipped dependencies later by running:"
        echo "  ./scripts/install/install-dependencies.sh"
        echo ""
    fi

    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║         Installation Incomplete                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Please install the missing required dependencies and run this script again."
    echo ""
    exit 1
fi
