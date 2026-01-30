# System Matrix 🖥️

> **A powerful, yet friendly macOS monitoring dashboard that keeps your system healthy, secure, and running smoothly.**

Hey there! 👋 Welcome to System Matrix - your Mac's new best friend. Think of it as a control center that watches over your system 24/7, sends you alerts when something needs attention, and even handles routine maintenance while you sleep.

[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/anand1996aditya/system-matrix)

---

## 🎥 See It In Action

<div align="center">
  <img src="docs/screenshots/demo.gif" alt="System Matrix Demo" width="100%">
  <p><i>System Matrix in action - real-time monitoring, alerts, and automation</i></p>
</div>

### 📸 Screenshots

<table>
  <tr>
    <td width="50%">
      <img src="docs/screenshots/dashboard-overview.png" alt="System Matrix Dashboard">
      <p align="center"><i>Real-time monitoring dashboard with Matrix theme</i></p>
    </td>
    <td width="50%">
      <img src="docs/screenshots/telegram-alert.jpg" alt="Telegram Alerts">
      <p align="center"><i>Smart notifications delivered to your phone</i></p>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/screenshots/file-browser.png" alt="File Browser">
      <p align="center"><i>Built-in file browser for managing files across all drives</i></p>
    </td>
    <td width="50%">
    </td>
  </tr>
</table>

---

## 🎯 What is System Matrix?

You know that feeling when your Mac starts acting up, but you're not sure why? Or when you forget to run backups for weeks? System Matrix solves these problems.

It's a **monitoring and automation dashboard** that:
- 📊 Shows you **real-time metrics** (CPU, memory, disk, network) in a sleek web interface
- 🚨 Sends **Telegram alerts** when something goes wrong (disk full, service crashed, security threat)
- 🤖 **Automates maintenance** tasks (backups, cleanup, updates) on a schedule
- 🔍 **Detects issues** before they become problems (high memory, failing drives, suspicious activity)
- 🎨 Looks **gorgeous** with a Matrix-themed UI (because why not?)

**Best part?** Once you set it up, it just works. No babysitting required.

---

## ✨ Features That'll Make You Smile

### 📊 Real-Time Dashboard

Open your browser to `http://localhost:8888` and see:

- **System Health**: CPU usage, memory pressure, disk space, network activity
- **Service Status**: Docker containers (Pi-hole, Plex, etc.), Tailscale VPN, and more
- **Internet Quality**: Latency to Google, Cloudflare, your router
- **Temperature**: Keep an eye on that M1/M2 chip temperature
- **Top Processes**: See what's eating your RAM and CPU

All auto-refreshing every 10 seconds, with gradient progress bars that look *chef's kiss*.

### 🔔 Smart Alerts (via Telegram)

Get instant notifications for:

**Security Issues:**
- SSH brute force attempts (someone's trying to break in!)
- Unexpected open ports (did something start listening?)
- Failed login attempts (sus activity detected)

**System Health:**
- Memory running low (90%+ usage)
- Disk space critical (75%+ full)
- CPU overheating (85°C+)

**Service Problems:**
- Docker containers crashed
- Pi-hole stopped blocking ads
- Tailscale VPN disconnected
- Critical services down

**Backup & Maintenance:**
- Backup failed to run
- Backup size anomaly (way too big or small)
- External drives missing

And it's **smart about notifications** - won't spam you with the same alert every minute. Configurable cooldown periods keep your sanity intact.

### 🤖 Automation That Actually Works

Set it and forget it. Every night at 3 AM (or whenever you choose):

✅ **Backs up your files** to Google Drive and external drives
✅ **Cleans Docker** (removes unused containers, images, volumes)
✅ **Rotates logs** (keeps things tidy)
✅ **Updates Pi-hole** (fresh blocklists)
✅ **Checks system health** (and auto-fixes what it can)
✅ **Monitors performance** (catches slowdowns early)

All logged, all tracked, all automatic.

### 🎨 Beautiful Interface

Forget boring terminal outputs. System Matrix gives you:

- **Matrix-themed UI** with green gradients and that hacker aesthetic
- **File Browser** - manage files across all your drives (including external)
- **Responsive design** - works on your Mac, iPad, even your phone
- **Password protected** - secure by default
- **Dark mode** - because your eyes deserve better

### 🔐 Security by Design

- **Auto-detects services** - only shows what you have installed (no hardcoded assumptions)
- **Git hooks** - blocks accidental commits of secrets/credentials
- **Config separation** - all sensitive data in git-ignored config files
- **Rate limiting** - brute force protection on the dashboard
- **Comprehensive scanner** - validates no secrets before every commit

---

## 🚀 Quick Start (Seriously, It's Easy)

### What You Need

**Required:**
- **macOS** (tested on Monterey and newer, works on M1/M2/Intel)
- **Python 3.7+** (already on your Mac, auto-detected during setup)
- **5 minutes** (for real)

**Optional but recommended:**
- **Telegram account** (for mobile alerts - highly recommended!)
- **Docker** (for Pi-hole, Plex, containers)
- **External drives** (for backups)

**Security Note:** You'll set up a dashboard password during installation. If you skip it, default credentials (`admin`/`matrix2026`) are used - **change them immediately!** See [Dashboard Credentials](#-dashboard-credentials--security).

### Installation

**1. Clone this repo:**
```bash
git clone https://github.com/anand1996aditya/system-matrix.git
cd system-matrix
```

**2. Run the setup wizard:**
```bash
./setup.sh
```

The wizard will:
- ✅ Check your system has everything needed
- ✅ Detect available ports (prevents conflicts)
- ✅ Ask for your Telegram credentials (optional, with validation)
- ✅ Set up a dashboard password (min 8 chars, confirmed)
- ✅ Validate all inputs (tokens, chat IDs, ports, paths)
- ✅ Configure paths and settings automatically
- ✅ Detect what services you have installed
- ✅ Offer to install missing services (Docker, Tailscale, etc.)
- ✅ Generate secure config files with proper permissions

> **💡 Pro Tip:** The setup wizard validates everything as you go. Invalid Telegram tokens, occupied ports, or bad paths will be caught immediately with helpful error messages.

**3. Start the dashboard:**
```bash
python3 scripts/monitoring/dashboard-server.py
```

**4. Open your browser:**
```
http://localhost:8888
```

Login with the credentials you set up. 🎉

**That's it!** You're monitoring.

---

## 🔐 Dashboard Credentials & Security

### Default Credentials

If you skipped setting a password during setup, the system uses these **default credentials**:

```
Username: admin
Password: matrix2026
```

**⚠️ CRITICAL SECURITY NOTICE:**

These default credentials are **publicly documented** in `config/config.template.json`. You **MUST** change them immediately after your first login!

### How to Change Your Password

#### Method 1: Using the Script (Recommended)

Run the password change utility:

```bash
./scripts/utilities/change-dashboard-password.sh
```

The script will:
- Show your current username
- Prompt for a new username (optional)
- Ask for a new password (min 8 characters)
- Confirm the password
- Update your configuration automatically
- Restart the dashboard service

#### Method 2: Manual Configuration

Edit `config/config.json` and update the `dashboard_auth` section:

```bash
# 1. Generate a SHA-256 hash of your new password
echo -n "YourNewPassword" | shasum -a 256

# 2. Edit config.json
nano config/config.json

# 3. Update these fields:
{
  "dashboard_auth": {
    "username": "your_new_username",
    "password_hash": "your_generated_hash_here"
  }
}

# 4. Restart the dashboard
pkill -f dashboard-server.py
python3 scripts/monitoring/dashboard-server.py
```

**Security Best Practices:**

✅ Use a **strong password** (12+ characters, mix of letters, numbers, symbols)
✅ Change credentials **immediately** after first setup
✅ Never share your `config/config.json` file (it's git-ignored for security)
✅ Consider using a **password manager** to generate and store credentials

**What's Protected:**

The password protects access to:
- Dashboard UI (system metrics)
- File browser (view/download files)
- Service controls
- Alert history
- System information

---

## 📱 Getting Telegram Alerts

Want notifications on your phone? Here's how:

**1. Create a Telegram bot:**
- Open Telegram and search for `@BotFather`
- Send `/newbot` and follow the prompts
- Copy the bot token (looks like `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

**2. Get your chat ID:**
- Search for `@userinfobot` in Telegram
- Send `/start`
- Copy your ID

**3. Paste into setup:**
When you run `./setup.sh`, it'll ask for these. Done!

Now you'll get alerts like:
> 🚨 **System Matrix Alert**
> **Severity:** CRITICAL
> **Service:** disk
> **Time:** 2026-01-30 14:23:45
>
> Disk usage critical: 89% used (234 GB free)

---

## 🎮 Usage

### Daily Use

**Dashboard:**
```bash
# Start dashboard server
python3 scripts/monitoring/dashboard-server.py

# Visit in browser
open http://localhost:8888
```

**Manual Tasks:**
```bash
# Check current metrics
./scripts/monitoring/collect-metrics.sh

# Send a test alert
./scripts/notifications/send-telegram-alert.sh info test "Hello from System Matrix!"

# Run maintenance manually
./scripts/automation/unified-automation.sh

# Detect installed services
./scripts/utilities/detect-services.sh
```

### Auto-Start on Boot

Want the dashboard to start automatically when your Mac boots?

```bash
# Install LaunchAgent (created by setup.sh)
cp config/launchagents/com.securitylab.dashboard.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.securitylab.dashboard.plist
```

Now it starts on login! 🎊

---

## 🛠️ Configuration

Everything's configured in `config/config.json` (created by setup wizard).

### Configuration File Location

```
config/config.json          # Your personal config (git-ignored, contains secrets)
config/config.template.json # Safe template (in git, has placeholders)
```

**⚠️ NEVER commit `config.json`** - it contains your credentials and is automatically git-ignored.

### Common Configuration Tweaks

```json
{
  "dashboard_auth": {
    "username": "admin",                       // Dashboard username
    "password_hash": "sha256_hash_here",       // Password (hashed)
    "session_timeout_minutes": 60,            // Auto-logout after 1 hour
    "max_failed_attempts": 3,                 // Lockout after 3 failed logins
    "lockout_duration_seconds": 180           // 3 min lockout
  },

  "alerts": {
    "memory_threshold_percent": 90,           // Alert when memory > 90%
    "disk_threshold_percent": 75,             // Alert when disk > 75%
    "cpu_temp_critical_celsius": 85,          // Alert when CPU > 85°C
    "backup_age_warning_hours": 24,           // Alert if backup > 24h old
    "ssh_brute_force_threshold": 100          // Alert after 100 SSH attempts
  },

  "notifications": {
    "telegram": {
      "enabled": true,                        // Enable Telegram alerts
      "bot_token": "YOUR_BOT_TOKEN_HERE",     // From @BotFather
      "chat_id": "YOUR_CHAT_ID_HERE",         // From @userinfobot
      "cooldown": {
        "critical": 600,                      // 10 min cooldown for critical
        "warning": 3600,                      // 1 hour for warnings
        "info": 7200                          // 2 hours for info
      }
    }
  },

  "services": {
    "dashboard": {
      "port": 8888,                           // Dashboard port
      "host": "0.0.0.0",                      // Listen on all interfaces
      "auth_required": true                   // Require login (recommended)
    }
  }
}
```

**Pro tips:**
- 🔐 **Change default credentials** - see [Dashboard Credentials section](#-dashboard-credentials--security)
- 🎯 Services and drives are **auto-detected** - no hardcoding needed!
- 📝 Default config is documented in `config/config.template.json`
- 🔒 Your `config.json` is **never tracked by git** - safe to put secrets there

---

## 🧪 Testing & Validation

Want to make sure everything works? We've got comprehensive tests:

```bash
# Run all validation tests
./tests/run-all-tests.sh

# Or run individual tests
./tests/pre-push-validation.sh        # 33 validation checks
./tests/test-security.sh               # Security configuration tests
./tests/simulated-fresh-install.sh    # Fresh clone simulation
./scripts/utilities/security-scan.sh  # 10 security scans
./scripts/utilities/verify-system-ready.sh  # Deployment readiness (30 checks)
```

**What's Tested:**

✅ File structure (all required files exist)
✅ Script syntax (bash/python validation)
✅ JSON validation (config template)
✅ Security (no hardcoded paths, tokens, secrets)
✅ Documentation (README, guides)
✅ Naming consistency
✅ Git hooks (pre-commit validation)
✅ GitHub Actions (CI/CD workflows)
✅ Configuration system (loaders, templates)
✅ .gitignore (secrets properly excluded)

**Expected Results:**
```
Total Tests: 33
Passed: 33
Failed: 0
Warnings: 0-1

✅ READY FOR GITHUB!
```

All tests should pass before pushing changes. If you see failures, the test output will tell you exactly what to fix.

---

## 🎨 Customization

### Change Dashboard Theme

Edit `dashboard/index.html` - all styles are inline CSS. Change colors, fonts, whatever you like!

### Add New Alerts

Edit `scripts/monitoring/collect-metrics.sh` and add your check:

```bash
# Example: Alert if Downloads folder > 10GB
DOWNLOADS_SIZE=$(du -sh ~/Downloads | awk '{print $1}')
if [ $DOWNLOADS_SIZE -gt 10 ]; then
    ./scripts/notifications/send-telegram-alert.sh \
        warning \
        storage \
        "Downloads folder is ${DOWNLOADS_SIZE}GB"
fi
```

### Add Custom Services

Services are auto-detected! Just install the service (Docker, Plex, whatever) and System Matrix will find it automatically.

---

## 🐛 Troubleshooting

**Can't login to dashboard?**
```bash
# Check if you're using default credentials
Username: admin
Password: matrix2026

# Reset your password
./scripts/utilities/change-dashboard-password.sh

# Check config file exists
ls -la config/config.json

# View current username (password is hashed)
grep -A 2 "dashboard_auth" config/config.json
```

**Dashboard won't start?**
```bash
# Check if port 8888 is already in use
lsof -i :8888

# Kill existing process
pkill -f dashboard-server.py

# Try a different port
# Edit config.json: "dashboard": { "port": 8889 }

# Check for errors
python3 scripts/monitoring/dashboard-server.py
```

**No Telegram alerts?**
```bash
# Test your credentials
./scripts/notifications/send-telegram-alert.sh info test "Test message"

# Verify credentials in config
grep -A 3 "telegram" config/config.json

# Check logs
tail -f logs/telegram-alerts.log

# Common issues:
# - Invalid bot token format (should be: 123456789:ABCdef...)
# - Wrong chat ID (should be numeric)
# - Telegram disabled in config: "enabled": false
```

**Services not detected?**
```bash
# Run detection manually
./scripts/utilities/detect-services.sh

# Check if service is actually running
docker ps        # For Docker containers
pgrep tailscale  # For Tailscale
lsof -i :32400   # For Plex

# Common issues:
# - Service installed but not running
# - Service running on non-standard port
```

**Setup fails?**
```bash
# Check dependencies
python3 --version  # Should be 3.7+
which jq          # Should be installed (optional but recommended)

# Install missing deps
brew install jq

# Check Python path (for M1 Macs)
which python3     # Should show /opt/homebrew/bin/python3 or /usr/bin/python3

# Verify config template exists
cat config/config.template.json

# Check port availability
lsof -i :8888     # Should be empty
```

**Permission denied errors?**
```bash
# Make scripts executable
chmod +x setup.sh
chmod +x scripts/**/*.sh

# Fix config permissions
chmod 600 config/config.json

# Check file ownership
ls -la config/config.json  # Should be owned by you
```

---

## 🆕 Recent Updates & Improvements

### Version 1.0.0 (January 2026)

**Portability & Auto-Detection:**
- ✅ **No hardcoded paths** - works from any installation directory
- ✅ **Auto-detects Python** - compatible with M1 Macs (Homebrew vs system Python)
- ✅ **Port conflict detection** - checks availability before setup
- ✅ **Path validation** - validates all file paths during setup
- ✅ **Input validation** - Telegram tokens, chat IDs, ports, passwords all validated

**Security Enhancements:**
- ✅ **Multi-layer validation** - pre-commit hooks, GitHub Actions, test suites
- ✅ **No false positives** - security scans exclude test/verification scripts
- ✅ **Comprehensive scanning** - 33 validation tests before every push
- ✅ **Git hooks** - prevent accidental commit of secrets

**Cleanup & Optimization:**
- ✅ **23% smaller** - removed development documentation (15 files, 3,698 lines)
- ✅ **Production-ready** - only essential files remain
- ✅ **Clean structure** - organized docs, scripts, tests
- ✅ **Fast setup** - streamlined wizard with better error messages

**Alert System:**
- ✅ **8 security alerts** - SSH brute force, port exposure, failed logins, etc.
- ✅ **6 system health alerts** - memory, disk, CPU temp, network, IO wait, swap
- ✅ **4 service alerts** - Docker, Pi-hole, Tailscale, critical services
- ✅ **3 backup alerts** - failures, size anomalies, missing drives
- ✅ **Smart cooldowns** - won't spam you with duplicate alerts

**Documentation:**
- ✅ **Comprehensive README** - you're reading it!
- ✅ **Quick Start Guide** - get running in 5 minutes
- ✅ **Alert System Guide** - all alerts documented
- ✅ **Security Validation** - security best practices
- ✅ **Contributing Guide** - help make it better

---

## 🤝 Contributing

Found a bug? Have a cool feature idea? Contributions are **super welcome**!

**Quick guide:**

1. Fork the repo
2. Create a branch (`git checkout -b feature/awesome-thing`)
3. Make your changes
4. Run tests (`./tests/run-all-tests.sh`)
5. Commit (`git commit -m "Add awesome thing"`)
6. Push (`git push origin feature/awesome-thing`)
7. Open a Pull Request

**Before submitting:**
- ✅ Tests pass
- ✅ Security scan passes
- ✅ Code follows existing style
- ✅ Added documentation for new features

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📋 Project Structure

```
system-matrix/                    # 58 files (cleaned up, production-ready)
│
├── 📂 dashboard/                 # Web UI (3 files)
│   ├── index.html               # Main dashboard
│   ├── file-browser.html        # File browser
│   └── file-browser.js          # Browser logic
│
├── 📂 scripts/                   # Core functionality (15 files)
│   ├── automation/              # Scheduled maintenance
│   │   └── unified-automation.sh
│   ├── monitoring/              # Metrics & server
│   │   ├── collect-metrics.sh
│   │   └── dashboard-server.py
│   ├── notifications/           # Alert system
│   │   └── send-telegram-alert.sh
│   └── utilities/               # Helper tools (11 files)
│       ├── config-loader.sh     # Bash config loader
│       ├── config_loader.py     # Python config loader
│       ├── detect-services.sh   # Service auto-detection
│       ├── security-scan.sh     # Security validator
│       ├── validate-paths.sh    # Path validation
│       ├── change-dashboard-password.sh  # Password changer
│       └── verify-*.sh          # Verification scripts
│
├── 📂 config/                    # Configuration (2 files)
│   ├── config.template.json     # ✅ Safe template (in git)
│   ├── config.json              # 🔒 Your config (git-ignored, secrets here)
│   └── launchagents/            # Auto-start configs (created by setup)
│
├── 📂 tests/                     # Test suite (4 files)
│   ├── pre-push-validation.sh   # 33 validation checks
│   ├── test-security.sh         # Security tests
│   ├── run-all-tests.sh         # Test runner
│   └── simulated-fresh-install.sh
│
├── 📂 docs/                      # Documentation
│   ├── setup/                   # Setup guides
│   ├── technical/               # Technical docs (2 guides)
│   └── screenshots/             # Visual demos (4 images)
│
├── 📂 .github/                   # CI/CD & community (5 files)
│   ├── workflows/               # GitHub Actions
│   │   └── security-scan.yml    # Automated security validation
│   └── ISSUE_TEMPLATE/          # Bug reports & feature requests
│
├── 📂 .git-hooks/                # Pre-commit security hooks
│
├── 📄 setup.sh                   # ⭐ Interactive setup wizard (start here!)
├── 📄 README.md                  # You are here
├── 📄 QUICK_START.md             # Quick reference guide
├── 📄 CONTRIBUTING.md            # Contribution guidelines
├── 📄 LICENSE                    # MIT License
└── 📄 .gitignore                 # Protects your secrets

📊 Total: 41 tracked files + 17 runtime files (logs, cache, your config)
```

**Color Key:**
- ✅ = Tracked by git (safe, no secrets)
- 🔒 = Git-ignored (your personal data, never committed)
- ⭐ = Start here!

---

## 🔒 Security

**We take security seriously.** Here's what's built-in:

### Credential Protection
- 🔐 **No hardcoded secrets** - all credentials in git-ignored config files
- 🚫 **Impossible to commit secrets** - pre-commit hooks block accidental commits
- 🔑 **Password hashing** - SHA-256 for dashboard authentication
- ⚠️ **Default credential warnings** - documented and must be changed (see [Dashboard Credentials](#-dashboard-credentials--security))
- 🛡️ **Config separation** - template (public) vs actual config (private)

### Validation & Scanning
- ✅ **Multi-layer validation** - pre-commit hooks, GitHub Actions, test suites
- 🔍 **33 automated checks** - run before every push
- 🚨 **Security scanner** - detects hardcoded paths, tokens, credentials
- 📝 **Input validation** - Telegram tokens, chat IDs, ports, passwords validated during setup
- 🎯 **Path validation** - ensures all file paths exist and are accessible

### Runtime Security
- 🔒 **Password protected dashboard** - authentication required by default
- ⏱️ **Session timeouts** - auto-logout after inactivity
- 🚷 **Rate limiting** - brute force protection (3 attempts, 3 min lockout)
- 🎭 **Auto-detection only** - no assumed services or hardcoded paths
- 📊 **Alert monitoring** - SSH brute force, port exposure, failed logins

### Best Practices
- ✅ Change default credentials immediately (username: `admin`, password: `matrix2026`)
- ✅ Use strong passwords (12+ characters, mixed case, numbers, symbols)
- ✅ Never share `config/config.json` (contains your secrets)
- ✅ Run security tests before pushing: `./tests/pre-push-validation.sh`
- ✅ Keep your Telegram bot token private

**Found a vulnerability?** Please email aditya12anand@protonmail.com instead of opening a public issue. Responsible disclosure is appreciated!

---

## 📜 License

**MIT License** - Use it, modify it, share it, sell it. We only ask that you keep the license notice.

See [LICENSE](LICENSE) for full details.

---

## 🙏 Credits

**Created by:** [Aditya Anand](https://github.com/anand1996aditya)

**Built with:**
- Python 3 (dashboard backend)
- Bash (automation scripts)
- Vanilla JavaScript (no frameworks, keepin' it simple)
- Love ❤️ (and lots of coffee ☕)

**Special thanks to:**
- The open-source community
- Everyone who contributes
- You, for checking this out! 🎉

---

## 💬 Support & Community

**Questions? Issues? Just want to chat?**

- 🐛 [Open an issue](https://github.com/anand1996aditya/system-matrix/issues)
- 💡 [Start a discussion](https://github.com/anand1996aditya/system-matrix/discussions)
- ⭐ Star the repo if you find it useful!

---

<div align="center">

**Made with ❤️ for the macOS community**

If System Matrix helps you, consider starring ⭐ the repo!

[Report Bug](https://github.com/anand1996aditya/system-matrix/issues) · [Request Feature](https://github.com/anand1996aditya/system-matrix/issues) · [Documentation](docs/)

</div>
