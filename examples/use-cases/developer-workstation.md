# Developer Workstation - Use Case

**Scenario:** You're a developer who runs Docker containers, needs reliable backups, and wants to catch issues before they become problems.

## Overview

Monitor your development Mac to prevent "it worked on my machine" disasters. Get alerts before your disk fills up or Docker eats all your RAM.

## What You Need

- **Docker**: For development containers
- **Backups**: Protect your code and projects
- **Alerts**: Know when something's wrong
- **No Automation**: You control when tasks run

## Recommended Configuration

Use: `examples/configs/telegram-only.json` (modified)

### Key Settings

```json
{
  "notifications": {
    "telegram": {
      "enabled": true,
      "cooldown": {
        "critical": 300,   // Quick alerts for dev issues
        "warning": 1800,
        "info": 3600
      }
    }
  },

  "alerts": {
    "memory_threshold_percent": 90,   // Docker can be RAM-hungry
    "disk_threshold_percent": 80,     // Disk fills up fast with images
    "cpu_temp_warning_celsius": 70,   // Keep Mac cool
    "backup_age_warning_hours": 48    // Remind to backup every 2 days
  },

  "automation": {
    "unified_script": {
      "enabled": false  // Manual control
    }
  }
}
```

## Setup Steps

### 1. Quick Install

```bash
git clone https://github.com/anand1996aditya/system-matrix.git
cd system-matrix
./scripts/install/install-dependencies.sh
./setup.sh
```

Choose "telegram-only" when asked, or customize.

### 2. Configure Alerts

Set up Telegram bot for notifications:
- @BotFather for bot token
- @userinfobot for chat ID

### 3. Dashboard Auto-Start

```bash
# Only dashboard, no automation
cp examples/launchagents/basic-dashboard.plist ~/Library/LaunchAgents/
sed -i '' "s|INSTALL_PATH_HERE|$(pwd)|g" ~/Library/LaunchAgents/basic-dashboard.plist
launchctl load ~/Library/LaunchAgents/basic-dashboard.plist
```

## What You'll Monitor

### Critical Alerts
- **Disk > 80%** - Docker images filling disk
- **Memory > 90%** - Containers using too much RAM
- **Docker daemon down** - Your containers stopped

### Warning Alerts
- **Backup > 48h old** - Time to commit/push!
- **CPU temp > 70°C** - Laptop getting hot
- **High IO wait** - Disk bottleneck

### Info Alerts
- **SSH activity** - Someone accessing your Mac
- **New external drive** - USB drive connected

## Developer Workflow Integration

### Morning Routine

```bash
# Check dashboard before starting work
open http://localhost:8888

# Quick health check
curl localhost:8888/api/metrics | jq '.resources, .services'
```

### Before Commits

```bash
# Run manual cleanup
~/system-matrix/scripts/automation/unified-automation.sh

# Cleans:
# - Old Docker images
# - Stopped containers
# - Dangling volumes
# - Old logs
```

### End of Day

```bash
# Check if you need to backup
# (Dashboard shows last backup time)

# Run your backup script
~/backup_code.sh
```

## Docker Management

### Monitor Container Resources

Dashboard shows:
- Number of running containers
- Memory usage per container
- Container health status

### Manual Cleanup

```bash
# Clean everything Docker-related
docker system prune -a --volumes -f

# Or use System Matrix's script
~/system-matrix/scripts/automation/unified-automation.sh
```

### Set Resource Limits

In your docker-compose.yml:
```yaml
services:
  my-service:
    mem_limit: 512m  # Prevent RAM hogging
    cpus: 2.0        # Limit CPU usage
```

## Backup Strategy for Developers

### What to Backup
- ✅ ~/Code or ~/Projects
- ✅ ~/Documents
- ✅ ~/.ssh keys
- ✅ ~/.gitconfig
- ✅ IDE settings

### What NOT to Backup
- ❌ node_modules/
- ❌ .venv/
- ❌ __pycache__/
- ❌ build/
- ❌ dist/

### Automated Reminders

System Matrix reminds you to backup every 48 hours.

Configure in `config.json`:
```json
{
  "alerts": {
    "backup_age_warning_hours": 48  // 2 days
  }
}
```

## Dashboard Shortcuts

### Quick Status from Terminal

```bash
# Add to ~/.zshrc or ~/.bashrc
alias status='curl -s localhost:8888/api/metrics | jq "{memory: .resources.memory_percent, disk: .resources.disk_percent, containers: .services.docker.running_containers}"'

# Usage:
$ status
{
  "memory": "67.2",
  "disk": "72.5",
  "containers": 5
}
```

### VSCode Integration

Create a VSCode task (`.vscode/tasks.json`):
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Check System Status",
      "type": "shell",
      "command": "open http://localhost:8888",
      "problemMatcher": []
    }
  ]
}
```

## Performance Optimization

### Keep Mac Fast

System Matrix helps by:
- ✅ Alerting when memory is high (close some apps!)
- ✅ Warning about disk space (clean up Docker!)
- ✅ Monitoring CPU temp (close Chrome with 100 tabs!)

### Docker Performance

Best practices:
```bash
# Use BuildKit for faster builds
export DOCKER_BUILDKIT=1

# Clean up regularly
docker system prune -a --volumes -f

# Limit log sizes in docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## Troubleshooting

### Dashboard Slow to Load

```bash
# Check if metrics collection is stuck
ps aux | grep collect-metrics

# Kill if needed
pkill -f collect-metrics

# Restart dashboard
launchctl kickstart -k gui/$(id -u)/basic-dashboard
```

### Too Many Docker Alerts

Adjust threshold in config.json:
```json
{
  "alerts": {
    "memory_threshold_percent": 95  // Only alert when very high
  }
}
```

### Backup Alerts Too Frequent

Change reminder interval:
```json
{
  "alerts": {
    "backup_age_warning_hours": 168  // Once per week
  }
}
```

## Pro Tips for Developers

### Tip 1: Pre-Commit Hook
Add System Matrix check to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Check if disk space is low before commit
DISK=$(curl -s localhost:8888/api/metrics | jq -r '.resources.disk_percent')
if (( $(echo "$DISK > 90" | bc -l) )); then
    echo "⚠️  Disk space low ($DISK%). Clean up before committing!"
    exit 1
fi
```

### Tip 2: CI/CD Integration
Use dashboard API in CI scripts:
```bash
# Check if dev machine is healthy before deploying
MEMORY=$(curl -s your-mac:8888/api/metrics | jq -r '.resources.memory_percent')
if (( $(echo "$MEMORY > 95" | bc -l) )); then
    echo "Dev machine overloaded. Wait before deploying."
    exit 1
fi
```

### Tip 3: Team Dashboard
Share dashboard with team (read-only):
```bash
# Via Tailscale
http://your-mac-tailscale-ip:8888

# Everyone sees if dev server is healthy
```

### Tip 4: Mobile Quick Check
Add to iPhone home screen:
- Open Safari: http://your-mac-tailscale-ip:8888
- Share → Add to Home Screen
- Check server health from anywhere!

## When NOT to Use Automation

Developers should usually **disable automation** because:

❌ You want control over when Docker cleanup runs
❌ You might be testing with specific containers
❌ Log rotation could delete important debug logs
❌ Automated tasks could interrupt your work

Instead:
✅ Run tasks manually when convenient
✅ Use alerts to remind you
✅ Keep full control over your environment

## Cost & Resources

**Overhead:**
- RAM: ~50MB (dashboard + metrics)
- CPU: <1% (only when collecting metrics)
- Disk: ~10MB (code + logs)

**Impact:**
- No noticeable performance impact
- Metrics collected every 10 seconds
- Dashboard updates every 10 seconds

## Next Steps

1. Install System Matrix
2. Set up Telegram alerts
3. Disable automation (manual control)
4. Monitor for a week
5. Adjust thresholds for your workload
6. Add to your development workflow

## See Also

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [System Matrix Alert Guide](../../docs/technical/ALERT_SYSTEM_GUIDE.md)
- [Tailscale for Developers](https://tailscale.com/kb/1017/install/)
