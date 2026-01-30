# Quick Start Guide

## For You (First Time Setup)

```bash
cd /Users/aditya/Claude-Code/System-Metrics
./setup.sh
# Answer the questions
# Test: python3 scripts/monitoring/dashboard-server.py
# Visit: http://localhost:8888
```

## Push to GitHub

```bash
cd /Users/aditya/Claude-Code/System-Metrics
git init
git add .
git commit -m "Initial commit: System Metrics Dashboard v1.0.0"
git remote add origin https://github.com/YOUR_USERNAME/system-metrics-dashboard.git
git branch -M main
git push -u origin main
```

## For Other Users (After Cloning)

```bash
git clone https://github.com/YOUR_USERNAME/system-metrics-dashboard.git
cd system-metrics-dashboard
./setup.sh
# Answer the questions
# Done!
```

## Key Commands

```bash
# Start dashboard manually
python3 scripts/monitoring/dashboard-server.py

# Run automation manually
./scripts/automation/unified-automation.sh

# Collect metrics
./scripts/monitoring/collect-metrics.sh | jq

# Send test alert
./scripts/notifications/send-telegram-alert.sh info test "Hello!"

# Check config
python3 scripts/utilities/config_loader.py
```

## What's Git-Ignored (Safe)

- `config/config.json` - Your secrets
- `logs/` - Runtime logs
- `.dashboard_auth` - Password hashes

## What's Committed (Safe)

- `config/config.template.json` - Placeholders
- All scripts - No secrets
- Documentation
- `.gitignore`

## Verification Checklist

Before pushing to GitHub:

- [ ] Run `./setup.sh` successfully
- [ ] Test dashboard works
- [ ] Test Telegram alerts work
- [ ] Verify `git status` shows config.json as untracked
- [ ] Check no secrets in `git diff --cached`
- [ ] Push to GitHub
- [ ] Clone to new directory and test `./setup.sh` works

## Support

- **README:** Complete documentation
- **MIGRATION_GUIDE:** Detailed changes
- **REFACTORING_COMPLETE:** What was done

---

**You're ready to go!** 🚀
