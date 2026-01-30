# Example Configurations

This directory contains example configuration files for different use cases.

## Available Examples

### 1. minimal-config.json
**Use Case:** Lightweight monitoring, no automation

**Features:**
- ✅ Dashboard monitoring
- ✅ Basic metrics collection
- ❌ No Telegram alerts
- ❌ No automation
- ❌ No backups

**Perfect for:**
- Testing System Matrix
- Minimal resource usage
- Dashboard-only monitoring
- Learning the system

**Alert Thresholds:**
- Memory: 95% (very high to avoid alerts)
- Disk: 90%
- CPU Temp: 80°C / 95°C

---

### 2. full-featured.json
**Use Case:** Maximum monitoring and automation

**Features:**
- ✅ Dashboard monitoring
- ✅ Telegram alerts (aggressive thresholds)
- ✅ Full automation (backups, cleanup, updates)
- ✅ Backup monitoring
- ✅ All services detected
- ✅ External drive monitoring

**Perfect for:**
- Power users
- Production environments
- Home servers (Pi-hole, Plex, Docker)
- Complete system management

**Alert Thresholds:**
- Memory: 85% (aggressive)
- Disk: 70% (early warning)
- CPU Temp: 65°C / 80°C (conservative)
- SSH brute force: 50 attempts
- Bandwidth spike: 100 Mbps

---

### 3. telegram-only.json
**Use Case:** Mobile alerts without automation

**Features:**
- ✅ Dashboard monitoring
- ✅ Telegram alerts (standard thresholds)
- ❌ No automation tasks
- ❌ No backups

**Perfect for:**
- Users who want notifications but manage tasks manually
- Monitoring remote Macs
- Keeping automation control separate
- Testing alert system

**Alert Thresholds:**
- Memory: 90%
- Disk: 75%
- CPU Temp: 70°C / 85°C (standard)
- More frequent cooldowns (5min critical, 30min warning)

---

## How to Use

### Method 1: During Setup

When running `./setup.sh`, you can base your config on one of these examples:

```bash
# After setup creates config.json, you can replace sections:
cat examples/configs/minimal-config.json > config/config.json

# Then customize your credentials
nano config/config.json
```

### Method 2: Manual Copy

```bash
# Copy example as starting point
cp examples/configs/full-featured.json config/config.json

# Customize with your values
nano config/config.json

# Update these fields:
# - notifications.telegram.bot_token
# - notifications.telegram.chat_id
# - dashboard_auth.password_hash (or use change-dashboard-password.sh)
# - backup.scripts.* (your backup script paths)
```

### Method 3: Mix and Match

Take sections from different examples:

```bash
# Start with minimal
cp examples/configs/minimal-config.json config/config.json

# Add Telegram from telegram-only
# Copy the "notifications.telegram" section

# Add automation from full-featured
# Copy the "automation" section
```

---

## Customization Tips

### Change Dashboard Port

```json
"services": {
  "dashboard": {
    "port": 8889,  // Change from 8888
    "host": "0.0.0.0",
    "auth_required": true
  }
}
```

### Adjust Alert Thresholds

```json
"alerts": {
  "memory_threshold_percent": 85,    // Alert at 85% memory
  "disk_threshold_percent": 80,      // Alert at 80% disk
  "cpu_temp_warning_celsius": 70,    // Warning at 70°C
  "cpu_temp_critical_celsius": 85    // Critical at 85°C
}
```

### Change Alert Cooldowns

```json
"notifications": {
  "telegram": {
    "cooldown": {
      "critical": 300,   // 5 minutes (more frequent)
      "warning": 1800,   // 30 minutes
      "info": 3600       // 1 hour
    }
  }
}
```

### Session Timeout

```json
"dashboard_auth": {
  "session_timeout_minutes": 120,  // 2 hours instead of 1 hour
  "max_failed_attempts": 5,        // 5 attempts instead of 3
  "lockout_duration_seconds": 600  // 10 min lockout instead of 3 min
}
```

---

## Security Notes

⚠️ **IMPORTANT:** All examples use default credentials:

```
Username: admin
Password: matrix2026
```

**You MUST change these immediately!**

Run:
```bash
./scripts/utilities/change-dashboard-password.sh
```

Or manually update `dashboard_auth.password_hash` in `config/config.json`.

---

## Path Placeholders

All examples use these placeholders:

- `${HOME}` - Your home directory (auto-expanded by setup.sh)
- `${USER}` - Your username (auto-expanded by setup.sh)

The setup wizard automatically replaces these with actual paths.

---

## Need Help?

- **Can't decide which config to use?** Start with `telegram-only.json` - get alerts without automation
- **Want everything?** Use `full-featured.json` - all features enabled
- **Just testing?** Use `minimal-config.json` - basic monitoring only

Check the [main README](../../README.md) for more documentation.
