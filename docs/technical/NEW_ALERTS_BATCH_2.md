# ✅ New Alerts Added - Batch 2
**Date:** January 29, 2026

---

## 🎉 SIX NEW ALERTS ADDED

### **Alert 3: Backup Size Anomalies** ⚠️
- **Purpose**: Detect data loss or corruption
- **Trigger**: Backup size changes >50% from previous backup
- **Monitors**: Google Drive and EVM backup sizes
- **Telegram**: ✅ Enabled
- **State Tracking**: Stores previous backup size in metrics-state/

**Example Alert:**
```
"Google Drive backup size changed by 75% - Possible data loss or corruption"
```

---

### **Alert 4: Network Bandwidth Spikes** ⚠️
- **Purpose**: Detect unusual network activity, data exfiltration, or attacks
- **Trigger**: Total bandwidth >50 Mbps sustained
- **Monitors**: Combined download + upload traffic
- **Telegram**: ✅ Enabled

**Example Alert:**
```
"Bandwidth spike detected: 85 Mbps - Unusual network activity"
```

---

### **Alert 5: Disk I/O Wait Time** ⚠️
- **Purpose**: Early warning of disk bottlenecks or failing drives
- **Trigger**: I/O wait time >20%
- **Monitors**: System-wide disk I/O using iostat
- **Telegram**: Dashboard only

**Example Alert:**
```
"High I/O wait time: 25% - Disk bottleneck detected"
```

---

### **Alert 6: Failed Scheduled Jobs** ⚠️
- **Purpose**: Ensure automation works reliably
- **Trigger**: Any System Matrix LaunchAgent fails
- **Monitors**: LaunchAgents with com.systemmatrix.* prefix
- **Telegram**: ✅ Enabled

**Example Alert:**
```
"System Matrix job(s) failed: com.systemmatrix.startup"
```

**Note**: Filtered to only check System Matrix jobs, not Apple system services

---

### **Alert 7: Log File Growth** ⚠️
- **Purpose**: Prevent disk space issues from runaway logs
- **Trigger**: Any log file >1GB
- **Monitors**:
  - ~/Claude-Code/Logs
  - ~/.backup_logs
  - /var/log
- **Telegram**: Dashboard only

**Example Alert:**
```
"Large log files detected (>1GB): dashboard-server.log, backup.log"
```

---

### **Alert 8: Application-Specific Checks** ⚠️

#### 8a. Pi-hole Error Detection
- **Trigger**: >10 errors in last 100 log lines
- **Monitors**: Docker logs for Pi-hole container
- **Detects**: Critical Pi-hole failures

#### 8b. Tailscale Connection Quality
- **Trigger**: Any warnings/errors in Tailscale status
- **Monitors**: Tailscale daemon status output
- **Detects**: VPN connection issues

#### 8c. Plex Transcoding Failures
- **Trigger**: Transcode errors in last 24 hours
- **Monitors**: Plex Media Server logs
- **Detects**: Media playback issues

---

## 📊 UPDATED ALERT SYSTEM

**Total Alerts: 18 comprehensive monitors**

### 🚨 Critical Security (4 alerts):
1. SSH Brute Force
2. Dashboard Login Failures
3. Port Exposure
4. Internet Connectivity Loss

### ⚠️ Warning - System (3 alerts):
5. High Memory Usage
6. Disk Space
7. CPU Temperature

### ⚠️ Warning - Infrastructure (5 alerts):
8. Critical Service Failures
9. Tailscale VPN Offline
10. Unhealthy Docker Containers
11. Backup Failure
12. Pi-hole Query Spike

### ⚠️ Warning - Advanced Monitoring (6 NEW alerts): ✨
13. **Backup Size Anomalies** (±50% change)
14. **Network Bandwidth Spikes** (>50 Mbps)
15. **Disk I/O Wait Time** (>20%)
16. **Failed Scheduled Jobs** (LaunchAgent failures)
17. **Log File Growth** (>1GB files)
18. **Application-Specific** (Pi-hole, Tailscale, Plex)

---

## 🔔 TELEGRAM NOTIFICATIONS

**Alerts with Telegram (9 total):**
- SSH Brute Force 🚨
- Dashboard Login Failures 🚨
- Internet Loss 🚨
- Service Failures ⚠️
- Backup Failures ⚠️
- Pi-hole Query Spike ⚠️
- **Backup Size Anomalies ⚠️** (NEW)
- **Bandwidth Spikes ⚠️** (NEW)
- **Failed Scheduled Jobs ⚠️** (NEW)

**Dashboard Only (9 total):**
- Memory/Disk/CPU warnings
- Docker health
- Tailscale status
- **I/O Wait Time** (NEW)
- **Log File Growth** (NEW)
- **Application Errors** (NEW)
- All systems operational

---

## 🎯 ALERT THRESHOLDS

| Alert | Threshold | Adjustable? | Line |
|-------|-----------|-------------|------|
| Backup Size Change | ±50% | Yes | ~825 |
| Bandwidth Spike | 50 Mbps | Yes | ~844 |
| I/O Wait Time | 20% | Yes | ~850 |
| Log File Size | 1GB | Yes | ~868 |
| Pi-hole Errors | 10 errors | Yes | ~899 |

---

## 🧪 TESTING NEW ALERTS

### Test Backup Size Anomaly:
```bash
# This will trigger on next backup if size changes significantly
du -sh ~/Documents
```

### Test Bandwidth Spike:
```bash
# Start a large download to trigger >50 Mbps
curl -O https://speed.hetzner.de/1GB.bin &
```

### Test I/O Wait:
```bash
# Check current I/O wait
iostat -c 2 -w 1
```

### Test Log Growth:
```bash
# Check large logs
find ~/Claude-Code/Logs -type f -size +1G
```

---

## 💡 STATE TRACKING

New state directory created: `~/Claude-Code/Logs/metrics-state/`

**Tracks:**
- Previous backup sizes (backup_gd_size.last)
- Alert cooldown timestamps
- Historical metrics for comparison

---

## 📈 ALERT COVERAGE

**Now monitoring:**
✅ Security threats (SSH, ports, login attempts)
✅ System performance (CPU, memory, disk, I/O)
✅ Service health (Pi-hole, Caddy, Tailscale, Docker)
✅ Data protection (backups, backup integrity)
✅ DNS security (query spikes)
✅ Network anomalies (bandwidth spikes)
✅ Automation reliability (LaunchAgents)
✅ Storage health (log growth, I/O wait)
✅ Application health (Plex, Pi-hole, Tailscale)

---

## 🚀 NEXT STEPS

**Completed:**
- ✅ 6 new advanced alerts implemented
- ✅ Telegram integration for critical alerts
- ✅ State tracking for backup anomalies
- ✅ Cooldown mechanism (10 min critical, 1 hour warnings)

**Ready for:**
- UI improvements (data visualization, graphs, interactivity)
- Additional application monitoring
- Custom alert rules
- Historical trend analysis

---

**Report Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Total Alerts:** 18 active
**New Alerts:** 6 (Backup Anomalies, Bandwidth, I/O, Jobs, Logs, Apps)
**Status:** ✅ FULLY OPERATIONAL
