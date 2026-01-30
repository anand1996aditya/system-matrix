# Local vs Public Files - Clear Guide

This document explains **exactly** which files are personal (stay on your machine) and which are public (pushed to GitHub).

---

## 🔴 PERSONAL FILES (Git-Ignored - NEVER Pushed to GitHub)

These files contain YOUR personal data, credentials, and settings. They are explicitly listed in `.gitignore`.

### Configuration Files
```
config/config.json                    ← Your actual bot token, settings
config/.dashboard_auth                ← Your dashboard username/password hash
```

**What's in them:**
- `config.json`: Your real Telegram bot token, chat ID, personal paths
- `.dashboard_auth`: Your actual dashboard login credentials

**How they're created:**
- By `setup.sh` wizard (asks for your credentials)
- By `change-dashboard-password.sh` (updates your password)

---

### Logs & Runtime Data
```
logs/*.log                            ← All log files
logs/cache/                           ← Cached metrics
logs/alert-state/                     ← Alert cooldown tracking
logs/metrics-state/                   ← Metrics history
logs/automation-status.json           ← Automation run status
logs/*.lock                           ← Lock files
logs/*.pid                            ← Process IDs
```

**What's in them:**
- Real system metrics from your Mac
- Actual alerts sent to your Telegram
- Timestamps, IP addresses, service statuses

---

### Backup & Temporary Files
```
*.bak                                 ← Backup files
*.backup                              ← Backup files
*~                                    ← Temporary editor files
.cleanup-backup-*                     ← Cleanup backups
*.tmp                                 ← Temporary files
.cache/                               ← Cache directory
tmp/                                  ← Temp directory
```

---

### Development Files
```
.vscode/                              ← VS Code settings
.idea/                                ← IntelliJ settings
*.swp, *.swo                          ← Vim swap files
notes.md                              ← Your personal notes
TODO.md                               ← Your personal todo
.personal/                            ← Your personal folder
```

---

## 🟢 PUBLIC FILES (In Git - Pushed to GitHub)

These files are safe to share publicly. They contain NO credentials, only templates and code.

### Configuration Templates
```
config/config.template.json           ← Template with placeholders
config/templates/                     ← Other template files
config/launchagents/                  ← LaunchAgent templates
```

**What's in them:**
- Placeholder values like `"YOUR_BOT_TOKEN_HERE"`
- Default settings (can be changed in personal config.json)
- Structure showing what users need to configure

**Example from config.template.json:**
```json
{
  "notifications": {
    "telegram": {
      "bot_token": "YOUR_BOT_TOKEN_HERE",    ← Placeholder, not real
      "chat_id": "YOUR_CHAT_ID_HERE"         ← Placeholder, not real
    }
  },
  "dashboard_auth": {
    "username": "admin",                     ← Default suggestion
    "password_hash": "..."                   ← Hash of "matrix2026"
  }
}
```

---

### Scripts (All Public)
```
scripts/automation/                   ← Automation scripts
scripts/monitoring/                   ← Monitoring scripts
scripts/notifications/                ← Notification scripts
scripts/utilities/                    ← Utility scripts
setup.sh                              ← Setup wizard
```

**What's in them:**
- Code that reads from config.json (but doesn't contain actual values)
- Variables like `$CONFIG_TELEGRAM_BOT_TOKEN` (loaded at runtime)
- NO hardcoded credentials

**Example from send-telegram-alert.sh:**
```bash
# This is SAFE - it loads from your personal config.json
BOT_TOKEN="$CONFIG_TELEGRAM_BOT_TOKEN"

# This would be UNSAFE (we removed these):
# BOT_TOKEN="8329891117:AAEYZmDxmbn..."  ← NEVER DO THIS
```

---

### Dashboard Files
```
dashboard/index.html                  ← Dashboard UI
dashboard/file-browser.html           ← File browser UI
```

**What's in them:**
- HTML, CSS, JavaScript for the web interface
- NO credentials (auth is checked by Python backend)

---

### Documentation
```
README.md                             ← Main documentation
CONTRIBUTING.md                       ← Contribution guide
LICENSE                               ← MIT License
docs/                                 ← All documentation
.github/                              ← GitHub templates
```

**What's in them:**
- Instructions, examples, screenshots
- NO real credentials (only example placeholders)

---

## 🔍 How to Verify What Will Be Committed

### Check Git Status
```bash
cd /Users/aditya/Claude-Code/System-Matrix

# See what would be committed
git status

# See what's ignored
git status --ignored
```

### Test Before Committing
```bash
# See exactly what would be committed
git diff

# Check for any secrets (runs security scan)
./scripts/utilities/security-scan.sh

# Run all tests
./tests/run-all-tests.sh
```

### View .gitignore
```bash
# See the complete list of ignored files
cat .gitignore
```

---

## 🔐 Your Dashboard Credentials - How It Works

### Default (Public Template)
**File:** `config/config.template.json`
```json
"dashboard_auth": {
  "username": "admin",
  "password_hash": "dff2b288a595a78976cdf31c85beef3291130288b15828dfe66ddeebf496d797"
}
```
- Username: `admin` (example)
- Password hash: SHA-256 of `matrix2026` (example)
- This is just a SUGGESTION in the template

### Your Personal Setup
**File:** `config/.dashboard_auth` (git-ignored)
```json
{
  "username": "aditha.talvo.anand",
  "password_hash": "YOUR_ACTUAL_PASSWORD_HASH_HERE"
}
```

**How to set your credentials:**
```bash
# Run this script to set YOUR password
./scripts/utilities/change-dashboard-password.sh

# Enter when prompted:
# Username: aditha.talvo.anand
# Password: [your personal password]
```

**What happens:**
1. Script creates/updates `config/.dashboard_auth`
2. Your password is hashed with SHA-256
3. File is git-ignored, never committed
4. Dashboard server reads from this file

**Also updates:** `config/config.json` (also git-ignored)
```json
"dashboard_auth": {
  "username": "aditha.talvo.anand",
  "password_hash": "your_actual_hash..."
}
```

---

## 📋 Quick Reference Table

| File/Folder | Personal? | In Git? | Purpose |
|-------------|-----------|---------|---------|
| `config/config.json` | ✅ Yes | ❌ No | Your real credentials |
| `config/config.template.json` | ❌ No | ✅ Yes | Public template |
| `config/.dashboard_auth` | ✅ Yes | ❌ No | Your dashboard login |
| `logs/*.log` | ✅ Yes | ❌ No | Your system logs |
| `scripts/*.sh` | ❌ No | ✅ Yes | Shared code |
| `dashboard/*.html` | ❌ No | ✅ Yes | Shared UI |
| `README.md` | ❌ No | ✅ Yes | Public docs |
| `setup.sh` | ❌ No | ✅ Yes | Setup wizard |

---

## ✅ Safe Workflow

### Making Personal Changes
```bash
# Edit your personal config
nano config/config.json

# Change your dashboard password
./scripts/utilities/change-dashboard-password.sh

# These files are git-ignored, safe to edit
```

### Making Public Changes
```bash
# Edit a script or documentation
nano scripts/monitoring/collect-metrics.sh

# Check what you're committing
git diff

# Run security scan
./scripts/utilities/security-scan.sh

# If all clear, commit
git add scripts/monitoring/collect-metrics.sh
git commit -m "Update metrics collection"
git push origin main
```

---

## 🚨 Red Flags - NEVER Commit These

❌ Real bot tokens
❌ Real passwords (even hashed ones from your personal setup)
❌ Real chat IDs (yours is personal)
❌ Real email addresses (except in LICENSE/docs as contact)
❌ Log files with real data
❌ Your actual system metrics

---

## 💡 Summary

**Simple Rule:**
- Files in `.gitignore` = **Personal** (your machine only)
- Files NOT in `.gitignore` = **Public** (goes to GitHub)

**Your Dashboard Credentials:**
- Template suggests: `admin` / `matrix2026` (just an example)
- You use: `aditha.talvo.anand` / `[your password]`
- Your credentials stored in: `config/.dashboard_auth` (git-ignored)
- Template keeps defaults for other users

**When in doubt:**
```bash
# Always run before committing
./scripts/utilities/security-scan.sh
```

This will catch any accidental credential leaks!
