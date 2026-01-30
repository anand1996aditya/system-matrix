#!/bin/bash

# Security Scanner for System Metrics Dashboard
# Scans all files for hardcoded secrets, credentials, and sensitive data
# Exit code 0 = SECURE, Exit code 1 = SECURITY ISSUES FOUND

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║        Security Scanner - System Metrics Dashboard     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

cd "$PROJECT_ROOT"

ISSUES_FOUND=0
WARNINGS_FOUND=0

# Function to report issues
report_issue() {
    local severity="$1"
    local file="$2"
    local line="$3"
    local issue="$4"
    local context="$5"

    if [ "$severity" = "CRITICAL" ]; then
        echo -e "${RED}[CRITICAL]${NC} $file:$line"
        echo -e "  Issue: $issue"
        echo -e "  Found: ${YELLOW}$context${NC}"
        echo ""
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    elif [ "$severity" = "WARNING" ]; then
        echo -e "${YELLOW}[WARNING]${NC} $file:$line"
        echo -e "  Issue: $issue"
        echo -e "  Found: $context"
        echo ""
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
}

echo -e "${BLUE}→ Scanning for security issues...${NC}\n"

# ============================================
# CHECK 1: Hardcoded Telegram Bot Tokens
# ============================================
echo -e "${BLUE}[1/10]${NC} Checking for Telegram bot tokens..."

# Pattern: Numbers followed by colon and base64-like string
TELEGRAM_PATTERN='[0-9]{9,10}:[A-Za-z0-9_-]{35}'

FILES=$(find . -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" -o -name "*.json" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/logs/*" \
    -not -path "*/.claude/*")

while IFS= read -r file; do
    if [ -f "$file" ]; then
        # Skip config.json and example files
        if [[ "$file" == *"config.json"* ]] || [[ "$file" == *"example"* ]]; then
            continue
        fi

        while IFS=: read -r line_num line_content; do
            # Skip if it's clearly a placeholder or variable
            if echo "$line_content" | grep -q -E "(YOUR_BOT_TOKEN|TOKEN_HERE|EXAMPLE|placeholder|\$|get_config|CONFIG_)"; then
                continue
            fi

            # Check for actual token pattern
            if echo "$line_content" | grep -E "$TELEGRAM_PATTERN" > /dev/null; then
                TOKEN=$(echo "$line_content" | grep -oE "$TELEGRAM_PATTERN" | head -1)
                report_issue "CRITICAL" "$file" "$line_num" "Hardcoded Telegram bot token detected" "$TOKEN"
            fi
        done < <(grep -n -E "$TELEGRAM_PATTERN" "$file" 2>/dev/null || true)
    fi
done <<< "$FILES"

# ============================================
# CHECK 2: Hardcoded API Keys and Passwords
# ============================================
echo -e "${BLUE}[2/10]${NC} Checking for API keys and passwords..."

API_KEY_PATTERNS=(
    'api[_-]?key["\s]*[:=]["\s]*[A-Za-z0-9_-]{20,}'
    'api[_-]?secret["\s]*[:=]["\s]*[A-Za-z0-9_-]{20,}'
    'password["\s]*[:=]["\s]*["\047][^"\047]{3,}["\047]'
    'passwd["\s]*[:=]["\s]*["\047][^"\047]{3,}["\047]'
    'secret[_-]?key["\s]*[:=]["\s]*["\047][A-Za-z0-9_-]{10,}'
    'client[_-]?secret["\s]*[:=]["\s]*["\047][A-Za-z0-9_-]{10,}'
)

for pattern in "${API_KEY_PATTERNS[@]}"; do
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Skip config files and obvious placeholders
            if [[ "$file" == *"config.json"* ]] || [[ "$file" == *"template"* ]]; then
                continue
            fi

            while IFS=: read -r line_num line_content; do
                # Skip if it's a comment or contains placeholder text
                if echo "$line_content" | grep -E "(^[[:space:]]*#|^[[:space:]]*//)|(YOUR_|_HERE|EXAMPLE|placeholder|xxx|PASSWORD_HASH)" > /dev/null; then
                    continue
                fi

                # Skip if it references a config variable
                if echo "$line_content" | grep -E "(\$CONFIG_|\$\{|get_config|config\.get)" > /dev/null; then
                    continue
                fi

                report_issue "CRITICAL" "$file" "$line_num" "Potential hardcoded credential" "$(echo "$line_content" | sed 's/^[[:space:]]*//')"
            done < <(grep -n -iE "$pattern" "$file" 2>/dev/null || true)
        fi
    done <<< "$FILES"
done

# ============================================
# CHECK 3: Hardcoded Email Addresses
# ============================================
echo -e "${BLUE}[3/10]${NC} Checking for hardcoded email addresses..."

EMAIL_PATTERN='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

while IFS= read -r file; do
    if [ -f "$file" ]; then
        # Skip documentation, example files, and config template
        if [[ "$file" == *".md"* ]] || [[ "$file" == *"README"* ]] || [[ "$file" == *"example"* ]] || [[ "$file" == *"template"* ]]; then
            continue
        fi

        while IFS=: read -r line_num line_content; do
            # Skip if it's a comment or example
            if echo "$line_content" | grep -E "(^[[:space:]]*#|^[[:space:]]*//)|(example|noreply|placeholder)" > /dev/null; then
                continue
            fi

            EMAIL=$(echo "$line_content" | grep -oE "$EMAIL_PATTERN" | head -1)
            if [ -n "$EMAIL" ] && [[ ! "$EMAIL" =~ (example|test|noreply|placeholder) ]]; then
                report_issue "WARNING" "$file" "$line_num" "Hardcoded email address" "$EMAIL"
            fi
        done < <(grep -n -E "$EMAIL_PATTERN" "$file" 2>/dev/null || true)
    fi
done <<< "$FILES"

# ============================================
# CHECK 4: Hardcoded Private IP Addresses
# ============================================
echo -e "${BLUE}[4/10]${NC} Checking for hardcoded private IP addresses..."

# Skip localhost/common IPs
PRIVATE_IP_PATTERN='(192\.168\.[0-9]{1,3}\.[0-9]{1,3}|10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]{1,3}\.[0-9]{1,3})'

while IFS= read -r file; do
    if [ -f "$file" ]; then
        # Skip markdown and docs
        if [[ "$file" == *".md"* ]]; then
            continue
        fi

        while IFS=: read -r line_num line_content; do
            # Skip comments
            if echo "$line_content" | grep -E "(^[[:space:]]*#|^[[:space:]]*//)|(example|sample)" > /dev/null; then
                continue
            fi

            IP=$(echo "$line_content" | grep -oE "$PRIVATE_IP_PATTERN" | head -1)
            if [ -n "$IP" ]; then
                report_issue "WARNING" "$file" "$line_num" "Hardcoded private IP address" "$IP"
            fi
        done < <(grep -n -E "$PRIVATE_IP_PATTERN" "$file" 2>/dev/null || true)
    fi
done <<< "$FILES"

# ============================================
# CHECK 5: Hardcoded User-Specific Paths
# ============================================
echo -e "${BLUE}[5/10]${NC} Checking for hardcoded user-specific paths..."

# Pattern for /Users/username or /home/username (but not placeholders)
USER_PATH_PATTERN='/Users/[a-z][a-z0-9_-]+|/home/[a-z][a-z0-9_-]+'

while IFS= read -r file; do
    if [ -f "$file" ]; then
        # Skip docs and templates
        if [[ "$file" == *".md"* ]] || [[ "$file" == *"template"* ]]; then
            continue
        fi

        while IFS=: read -r line_num line_content; do
            # Skip comments and variable references
            if echo "$line_content" | grep -E "(^[[:space:]]*#|^[[:space:]]*//)|\$|expanduser|~" > /dev/null; then
                continue
            fi

            USERPATH=$(echo "$line_content" | grep -oE "$USER_PATH_PATTERN" | head -1)
            if [ -n "$USERPATH" ] && [[ ! "$line_content" =~ (example|sample|username|USER) ]]; then
                report_issue "CRITICAL" "$file" "$line_num" "Hardcoded user-specific path" "$USERPATH"
            fi
        done < <(grep -n -E "$USER_PATH_PATTERN" "$file" 2>/dev/null || true)
    fi
done <<< "$FILES"

# ============================================
# CHECK 6: AWS/Cloud Keys
# ============================================
echo -e "${BLUE}[6/10]${NC} Checking for AWS/cloud credentials..."

AWS_PATTERNS=(
    'AKIA[0-9A-Z]{16}'  # AWS Access Key
    'aws_access_key_id'
    'aws_secret_access_key'
)

for pattern in "${AWS_PATTERNS[@]}"; do
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Skip the security scanner itself (it contains patterns to check for)
            if [[ "$file" == *"security-scan.sh"* ]]; then
                continue
            fi

            while IFS=: read -r line_num line_content; do
                if echo "$line_content" | grep -E "(example|sample|placeholder)" > /dev/null; then
                    continue
                fi
                report_issue "CRITICAL" "$file" "$line_num" "Potential AWS credential" "***REDACTED***"
            done < <(grep -n -i "$pattern" "$file" 2>/dev/null || true)
        fi
    done <<< "$FILES"
done

# ============================================
# CHECK 7: Private Keys
# ============================================
echo -e "${BLUE}[7/10]${NC} Checking for private keys..."

KEY_PATTERNS=(
    '-----BEGIN [A-Z]+ PRIVATE KEY-----'
    '-----BEGIN RSA PRIVATE KEY-----'
    '-----BEGIN EC PRIVATE KEY-----'
    '-----BEGIN OPENSSH PRIVATE KEY-----'
)

for pattern in "${KEY_PATTERNS[@]}"; do
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if grep -q "$pattern" "$file" 2>/dev/null; then
                report_issue "CRITICAL" "$file" "?" "Private key detected" "***KEY FOUND***"
            fi
        fi
    done <<< "$FILES"
done

# ============================================
# CHECK 8: Database Connection Strings
# ============================================
echo -e "${BLUE}[8/10]${NC} Checking for database connection strings..."

DB_PATTERN='(mysql|postgresql|mongodb)://[^@]+:[^@]+@'

while IFS= read -r file; do
    if [ -f "$file" ]; then
        while IFS=: read -r line_num line_content; do
            if echo "$line_content" | grep -E "(example|sample)" > /dev/null; then
                continue
            fi
            DB_CONN=$(echo "$line_content" | grep -oE "$DB_PATTERN" | head -1)
            if [ -n "$DB_CONN" ]; then
                report_issue "CRITICAL" "$file" "$line_num" "Database connection string with credentials" "***REDACTED***"
            fi
        done < <(grep -n -E "$DB_PATTERN" "$file" 2>/dev/null || true)
    fi
done <<< "$FILES"

# ============================================
# CHECK 9: Verify config.json is gitignored
# ============================================
echo -e "${BLUE}[9/10]${NC} Checking .gitignore configuration..."

if [ -f ".gitignore" ]; then
    if ! grep -q "config/config.json" .gitignore; then
        report_issue "CRITICAL" ".gitignore" "?" "config/config.json not in .gitignore" "Missing exclusion"
    fi

    if ! grep -q "logs/" .gitignore; then
        report_issue "WARNING" ".gitignore" "?" "logs/ directory not in .gitignore" "Missing exclusion"
    fi

    if ! grep -q ".dashboard_auth" .gitignore; then
        report_issue "CRITICAL" ".gitignore" "?" ".dashboard_auth not in .gitignore" "Missing exclusion"
    fi
else
    report_issue "CRITICAL" "." "?" ".gitignore file not found" "Create .gitignore"
fi

# ============================================
# CHECK 10: Verify config.template.json has placeholders
# ============================================
echo -e "${BLUE}[10/10]${NC} Checking config template..."

if [ -f "config/config.template.json" ]; then
    # Check that it has placeholders, not real values
    if grep -q "YOUR_BOT_TOKEN_HERE" config/config.template.json && \
       grep -q "YOUR_CHAT_ID_HERE" config/config.template.json; then
        echo -e "${GREEN}✓ Config template has placeholders${NC}"
    else
        report_issue "CRITICAL" "config/config.template.json" "?" "Config template missing placeholders" "Check YOUR_BOT_TOKEN_HERE"
    fi
else
    report_issue "WARNING" "config/" "?" "config.template.json not found" "Should exist for users"
fi

# ============================================
# SUMMARY
# ============================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Scan Complete                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ SECURE: No security issues found!${NC}"
    echo ""
    echo "Your code is safe to commit to GitHub."
    exit 0
elif [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS: Found $WARNINGS_FOUND warning(s)${NC}"
    echo ""
    echo "Review warnings above. Code is generally safe but check carefully."
    exit 0
else
    echo -e "${RED}❌ SECURITY ISSUES: Found $ISSUES_FOUND critical issue(s) and $WARNINGS_FOUND warning(s)${NC}"
    echo ""
    echo "⚠️  DO NOT COMMIT TO GITHUB UNTIL ISSUES ARE RESOLVED!"
    echo ""
    echo "Actions to take:"
    echo "  1. Review all CRITICAL issues above"
    echo "  2. Move secrets to config.json"
    echo "  3. Replace hardcoded paths with config variables"
    echo "  4. Run this scan again before committing"
    echo ""
    exit 1
fi
