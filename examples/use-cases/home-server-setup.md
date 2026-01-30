# Home Server Setup - Use Case

**Scenario:** You run a home server with Pi-hole, Plex, and Docker containers.

## Overview

This setup monitors your home server's health, keeps services running, and alerts you when something needs attention.

## What You're Running

- **Pi-hole**: Network-wide ad blocking
- **Plex Media Server**: Streaming media
- **Docker**: Container services
- **Tailscale**: Remote access VPN
- **Backups**: Regular backups to external drives

## Recommended Configuration

Use: `examples/configs/full-featured.json`

### Key Settings

```json
{
  "notifications": {
    "telegram": {
      "enabled": true,
      "cooldown": {
        "critical": 300,   // 5 min - faster alerts for server issues
        "warning": 1800,   // 30 min
        "info": 3600       // 1 hour
      }
    }
  },

  "alerts": {
    "memory_threshold_percent": 85,
    "disk_threshold_percent": 70,
    "cpu_temp_warning_celsius": 65,
    "backup_age_warning_hours": 24
  },

  "automation": {
    "unified_script": {
      "enabled": true,
      "tasks": {
        "docker_cleanup": true,      // Clean unused containers
        "log_rotation": true,         // Prevent log bloat
        "pihole_update": true,        // Update blocklists
        "health_check": true,         // Check all services
        "external_drives_check": true // Monitor backup drives
      }
    }
  }
}
```

## Setup Steps

### 1. Install System Matrix

```bash
git clone https://github.com/anand1996aditya/system-matrix.git
cd system-matrix
./scripts/install/install-dependencies.sh
./setup.sh
```

### 2. Configure Telegram

Get bot token from @BotFather, chat ID from @userinfobot.

### 3. Set Up Auto-Start

```bash
# Copy LaunchAgents
cp examples/launchagents/*.plist ~/Library/LaunchAgents/

# Update paths in plists
sed -i '' "s|INSTALL_PATH_HERE|$(pwd)|g" ~/Library/LaunchAgents/com.systemmatrix.*.plist

# Load them
launchctl load ~/Library/LaunchAgents/com.systemmatrix.dashboard.plist
launchctl load ~/Library/LaunchAgents/com.systemmatrix.automation.plist
```

### 4. Configure Services

System Matrix auto-detects:
- ✅ Docker (if running)
- ✅ Pi-hole (if container is named "pihole")
- ✅ Plex (checks port 32400)
- ✅ Tailscale (if installed)

No manual configuration needed!

## Expected Alerts

You'll receive Telegram notifications for:

### Critical (5 min cooldown)
- **Pi-hole down** - DNS/ad-blocking stopped
- **Plex unreachable** - Media streaming down
- **Disk > 90%** - Running out of space
- **Memory > 85%** - System under pressure

### Warning (30 min cooldown)
- **Backup didn't run** - Last backup > 24h old
- **Docker cleanup needed** - Unused containers piling up
- **External drive missing** - Backup drive not mounted
- **CPU temp high** - Thermal throttling risk

### Info (1 hour cooldown)
- **Automation completed** - Daily maintenance done
- **Services restarted** - Automatic recovery happened

## Dashboard Access

### Local Network
```
http://your-mac-ip:8888
```

### Remote Access (via Tailscale)
```
http://your-mac-tailscale-ip:8888
```

### From Phone
Add to home screen for quick access!

## Automation Schedule

**Every night at 3:00 AM:**

1. **Docker Cleanup** (5 min)
   - Remove stopped containers
   - Clean dangling images
   - Remove unused volumes

2. **Log Rotation** (2 min)
   - Compress old logs
   - Delete logs > 30 days
   - Keep logs under 100MB total

3. **Pi-hole Update** (10 min)
   - Update gravity database
   - Refresh blocklists
   - Restart if needed

4. **Health Check** (3 min)
   - Test all services
   - Verify network connectivity
   - Check disk space

5. **External Drives** (2 min)
   - Verify backup drives mounted
   - Check backup timestamps
   - Alert if backups stale

**Total time:** ~20 minutes while you sleep!

## Monitoring What Matters

### Always Monitor
- ✅ Pi-hole status (no ads = happy browsing)
- ✅ Plex uptime (family needs their shows!)
- ✅ Disk space (media libraries grow fast)
- ✅ Docker health (containers can crash)
- ✅ Backup freshness (data protection)

### Don't Obsess Over
- CPU usage (it's a server, it should work!)
- Network spikes (streaming uses bandwidth)
- Memory at 70% (that's normal for servers)

## Troubleshooting

### Pi-hole Shows Down But It's Running

Check if container name matches:
```bash
docker ps | grep pihole
# Should show container named "pihole"

# If different name, update config or rename container
docker rename old_name pihole
```

### Plex Not Detected

Verify port 32400 is accessible:
```bash
curl http://localhost:32400/web
# Should return HTML

# If different port, update in config.json
```

### Too Many Alerts

Adjust thresholds in config.json:
```json
{
  "alerts": {
    "memory_threshold_percent": 95,  // Less sensitive
    "disk_threshold_percent": 85
  },
  "notifications": {
    "telegram": {
      "cooldown": {
        "warning": 7200  // Only alert every 2 hours
      }
    }
  }
}
```

## Pro Tips

### Tip 1: Quick Service Check
```bash
# From phone via SSH
ssh your-mac "curl localhost:8888/api/metrics | jq .services"
```

### Tip 2: Force Automation Now
```bash
# Don't wait for 3 AM
~/system-matrix/scripts/automation/unified-automation.sh
```

### Tip 3: Monitor Multiple Macs
Set up System Matrix on each Mac with different Telegram bots.
Or use same bot but different chat IDs.

### Tip 4: Remote Dashboard Access
Use Tailscale for secure remote access.
No port forwarding, no exposed services.

## Cost

**Total:** $0/month

- System Matrix: Free & open source
- Telegram: Free
- Tailscale: Free tier (100 devices)

## Next Steps

1. ✅ Set up System Matrix
2. ✅ Configure Telegram alerts
3. ✅ Enable automation
4. ✅ Install LaunchAgents
5. Monitor for a week
6. Adjust thresholds based on your usage
7. Share dashboard with family (optional)

## See Also

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Plex Media Server Setup](https://www.plex.tv/media-server-downloads/)
- [Tailscale Getting Started](https://tailscale.com/kb/1017/install/)
- [System Matrix Alert Guide](../../docs/technical/ALERT_SYSTEM_GUIDE.md)
