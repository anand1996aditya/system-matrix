#!/bin/bash

# Path Validation Utility
# Validates that required paths exist before scripts run
# Usage: source validate-paths.sh && validate_required_paths

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validate a single path
validate_path() {
    local path="$1"
    local description="${2:-Path}"
    local required="${3:-true}"

    if [ -e "$path" ]; then
        return 0
    elif [ "$required" = "false" ]; then
        echo -e "${YELLOW}⚠️  Optional $description not found: $path${NC}" >&2
        return 0
    else
        echo -e "${RED}✗ Required $description not found: $path${NC}" >&2
        return 1
    fi
}

# Validate directory exists
validate_directory() {
    local dir="$1"
    local description="${2:-Directory}"

    if [ -d "$dir" ]; then
        return 0
    else
        echo -e "${RED}✗ $description not found: $dir${NC}" >&2
        return 1
    fi
}

# Validate file exists
validate_file() {
    local file="$1"
    local description="${2:-File}"

    if [ -f "$file" ]; then
        return 0
    else
        echo -e "${RED}✗ $description not found: $file${NC}" >&2
        return 1
    fi
}

# Validate file is executable
validate_executable() {
    local file="$1"
    local description="${2:-File}"

    if [ -f "$file" ]; then
        if [ -x "$file" ]; then
            return 0
        else
            echo -e "${RED}✗ $description is not executable: $file${NC}" >&2
            echo -e "${YELLOW}  Run: chmod +x $file${NC}" >&2
            return 1
        fi
    else
        echo -e "${RED}✗ $description not found: $file${NC}" >&2
        return 1
    fi
}

# Validate required paths for System Matrix
validate_required_paths() {
    local SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local errors=0

    # Validate critical directories
    validate_directory "$SCRIPT_DIR/scripts" "Scripts directory" || ((errors++))
    validate_directory "$SCRIPT_DIR/dashboard" "Dashboard directory" || ((errors++))
    validate_directory "$SCRIPT_DIR/config" "Config directory" || ((errors++))
    validate_directory "$SCRIPT_DIR/logs" "Logs directory" || ((errors++))

    # Validate critical files
    validate_file "$SCRIPT_DIR/config/config.json" "Configuration file" || {
        echo -e "${YELLOW}  Run setup.sh to create configuration${NC}" >&2
        ((errors++))
    }

    # Validate utilities
    validate_file "$SCRIPT_DIR/scripts/utilities/config-loader.sh" "Config loader" || ((errors++))

    if [ $errors -gt 0 ]; then
        echo -e "${RED}✗ $errors validation error(s) found${NC}" >&2
        return 1
    else
        return 0
    fi
}

# Validate a port is available
validate_port_available() {
    local port=$1
    local service="${2:-Service}"

    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port $port is already in use (needed for $service)${NC}" >&2
        return 1
    else
        return 0
    fi
}

# Validate Python is available
validate_python() {
    if command -v python3 &> /dev/null; then
        return 0
    else
        echo -e "${RED}✗ Python 3 not found${NC}" >&2
        return 1
    fi
}

# Validate required command exists
validate_command() {
    local cmd="$1"
    local description="${2:-$cmd}"

    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        echo -e "${RED}✗ Required command not found: $description${NC}" >&2
        return 1
    fi
}

# Export functions for use in other scripts
export -f validate_path
export -f validate_directory
export -f validate_file
export -f validate_executable
export -f validate_required_paths
export -f validate_port_available
export -f validate_python
export -f validate_command
