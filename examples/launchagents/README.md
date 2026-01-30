# LaunchAgent Examples

LaunchAgents allow System Matrix to start automatically when you log in to your Mac.

## Available Examples

### 1. basic-dashboard.plist
**Purpose:** Auto-start dashboard only (no automation)

**What it does:**
- Starts dashboard server on login
- Keeps dashboard running (auto-restarts if crashed)
- Runs on boot after user login

**Use when:**
- You want the dashboard always available
- You run automation tasks manually
- Monitoring-only setup

---

### 2. full-automation.plist
**Purpose:** Run automated maintenance daily at 3 AM

**What it does:**
- Runs unified-automation.sh daily at 3:00 AM
- Performs backups, cleanup, updates
- Logs all activity

**Use when:**
- You want automated maintenance
- Set-it-and-forget-it operation
- Combined with basic-dashboard.plist

---

## Installation

### Step 1: Update Paths

Replace `INSTALL_PATH_HERE` with your actual installation path:

```bash
# Example: If installed at /Users/yourname/system-matrix
sed -i '' 's|INSTALL_PATH_HERE|/Users/yourname/system-matrix|g' basic-dashboard.plist
```

Or use the setup wizard which does this automatically.

### Step 2: Copy to LaunchAgents Directory

```bash
# Copy dashboard LaunchAgent
cp basic-dashboard.plist ~/Library/LaunchAgents/com.systemmatrix.dashboard.plist

# Optional: Copy automation LaunchAgent
cp full-automation.plist ~/Library/LaunchAgents/com.systemmatrix.automation.plist
```

### Step 3: Load LaunchAgents

```bash
# Load dashboard (starts immediately)
launchctl load ~/Library/LaunchAgents/com.systemmatrix.dashboard.plist

# Optional: Load automation (will run at scheduled time)
launchctl load ~/Library/LaunchAgents/com.systemmatrix.automation.plist
```

---

## Management Commands

### Check Status

```bash
# Check if dashboard is running
launchctl list | grep systemmatrix

# View logs
tail -f ~/system-matrix/logs/dashboard-server-stdout.log
```

### Restart Services

```bash
# Restart dashboard
launchctl kickstart -k gui/$(id -u)/com.systemmatrix.dashboard

# Restart automation (runs immediately)
launchctl kickstart -k gui/$(id -u)/com.systemmatrix.automation
```

### Stop Services

```bash
# Stop dashboard
launchctl stop com.systemmatrix.dashboard

# Stop automation
launchctl stop com.systemmatrix.automation
```

### Unload (Disable Auto-Start)

```bash
# Unload dashboard
launchctl unload ~/Library/LaunchAgents/com.systemmatrix.dashboard.plist

# Unload automation
launchctl unload ~/Library/LaunchAgents/com.systemmatrix.automation.plist
```

### Remove Completely

```bash
# Unload first
launchctl unload ~/Library/LaunchAgents/com.systemmatrix.*.plist

# Delete files
rm ~/Library/LaunchAgents/com.systemmatrix.*.plist
```

---

## Customization

### Change Automation Schedule

Edit `full-automation.plist` and change the schedule:

```xml
<!-- Run at 2:00 AM instead of 3:00 AM -->
<key>Hour</key>
<integer>2</integer>
<key>Minute</key>
<integer>0</integer>
```

### Run Multiple Times Per Day

```xml
<key>StartCalendarInterval</key>
<array>
    <!-- Run at 3:00 AM -->
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <!-- Run at 3:00 PM -->
    <dict>
        <key>Hour</key>
        <integer>15</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</array>
```

### Change Log Locations

```xml
<key>StandardOutPath</key>
<string>/Users/yourname/Desktop/dashboard-logs.log</string>
```

---

## Troubleshooting

### LaunchAgent Not Starting

```bash
# Check for errors
launchctl list | grep systemmatrix

# View system log
log show --predicate 'subsystem contains "com.systemmatrix"' --last 1h
```

### Dashboard Won't Start

```bash
# Check if Python path is correct
which python3

# Update ProgramArguments in plist:
<string>/opt/homebrew/bin/python3</string>  <!-- M1/M2 Mac -->
<!-- OR -->
<string>/usr/bin/python3</string>           <!-- Intel Mac -->
```

### Automation Not Running

```bash
# Check automation logs
tail -f ~/system-matrix/logs/unified-automation-launchagent.log

# Manually run to test
~/system-matrix/scripts/automation/unified-automation.sh
```

---

## Security Notes

- LaunchAgents run as your user (not root)
- Have access to your files and credentials
- Logs may contain sensitive information
- Make sure log files are protected (chmod 600)

---

## Advanced: System-Wide Installation

To run for all users (requires sudo):

```bash
# Copy to system LaunchDaemons (NOT RECOMMENDED)
sudo cp basic-dashboard.plist /Library/LaunchDaemons/

# This is NOT recommended because:
# - Runs as root (security risk)
# - May not have access to user files
# - Harder to manage

# Stick with ~/Library/LaunchAgents/ instead
```

---

## See Also

- [macOS LaunchAgent Documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [LaunchControl App](https://www.soma-zone.com/LaunchControl/) - GUI for managing LaunchAgents
- [System Matrix Setup Guide](../../README.md)
