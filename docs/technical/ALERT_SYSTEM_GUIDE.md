# 🚨 System Matrix Alert System - Complete Guide
**Last Updated:** January 29, 2026

---

## 📊 CURRENT ALERTS OVERVIEW

Your System Matrix Dashboard now monitors **8 critical areas** and provides real-time alerts.

---

## ✅ ACTIVE ALERTS

### 1. 🧠 **High Memory Usage**
**Threshold:** > 90%
**Severity:** Warning ⚠️
**Service:** System
**Triggers when:** System RAM usage exceeds 90%
**Message:** "High memory usage: XX%"
**Action:** Close unnecessary applications, check for memory leaks

---

### 2. 💾 **Disk Space Usage**
**Threshold:** > 75%
**Severity:** Warning ⚠️
**Service:** Storage
**Triggers when:** Disk usage exceeds 75%
**Message:** "Disk space usage at XX% - Consider cleanup"
**Action:** Run cleanup, delete old files, check large folders

---

### 3. 🔐 **SSH Brute Force Detection** ⭐ NEW
**Threshold:** > 5 failed attempts in 1 hour
**Severity:** Critical 🔴
**Service:** Security
**Triggers when:** Multiple SSH login failures detected
**Message:** "SSH brute force detected: XX failed attempts in last hour"
**Action:**
- Check `/var/log/system.log` for source IPs
- Consider blocking IPs via firewall
- Review SSH configuration
- Enable fail2ban if not active

---

### 4. 🔒 **Dashboard Failed Login** ⭐ NEW
**Threshold:** > 3 failures in 10 minutes
**Severity:** Critical 🔴
**Service:** Security
**Triggers when:** Multiple dashboard login failures
**Message:** "Dashboard login attempts: XX failures detected"
**Action:**
- Check `~/Claude-Code/Logs/dashboard-server.log`
- Identify source IP addresses
- Consider IP whitelist or rate limiting
- Change dashboard password if compromised

---

### 5. ⚙️ **Critical Service Failures** ⭐ NEW
**Monitors:** Pi-hole, Caddy
**Severity:** Warning ⚠️
**Service:** Infrastructure
**Triggers when:** Essential services are stopped
**Message:** "Critical services down: Pi-hole, Caddy"
**Action:**
- Restart failed services
- Check Docker/Colima status
- Review service logs
- Verify system resources

---

### 6. 🌡️ **High CPU Temperature** ⭐ NEW
**Threshold:** > 80°C
**Severity:** Warning ⚠️
**Service:** Thermal
**Triggers when:** CPU temperature exceeds 80°C
**Message:** "High CPU temperature: XX°C"
**Action:**
- Check CPU usage (`top` or Activity Monitor)
- Ensure proper ventilation
- Clean dust from vents
- Consider reducing workload
- Check fan operation

---

### 7. 🌐 **Tailscale VPN Offline** ⭐ NEW
**Severity:** Warning ⚠️
**Service:** Network
**Triggers when:** Tailscale is not running
**Message:** "Tailscale VPN is offline - Remote access unavailable"
**Action:**
- Start Tailscale app
- Check Tailscale service status
- Verify network connectivity
- Review Tailscale logs

---

### 8. 🐳 **Unhealthy Docker Containers** ⭐ NEW
**Severity:** Warning ⚠️
**Service:** Docker
**Triggers when:** Docker health checks fail
**Message:** "XX unhealthy container(s) detected"
**Action:**
- Run `docker ps` to identify containers
- Check container logs: `docker logs <container>`
- Restart unhealthy containers
- Verify container configuration

---

## 🎯 ALERT SEVERITY LEVELS

| Severity | Color | Icon | Meaning | Response Time |
|----------|-------|------|---------|---------------|
| **Critical** 🔴 | Red | 🚨 | Security breach or system failure | Immediate |
| **Warning** ⚠️ | Orange | ⚠️ | Attention needed, not urgent | Within hours |
| **Info** ℹ️ | Blue | ℹ️ | Informational, no action needed | Informational |

---

## 📍 WHERE TO SEE ALERTS

**System Matrix Dashboard:**
- **Local:** http://localhost:8888
- **Tailscale:** http://100.118.129.106:8888

**Alert Section Location:**
- Top of dashboard (Alerts card)
- Updates every 10 seconds
- Shows most recent/active alerts
- Color-coded by severity

---

## 🔔 ALERT BEHAVIOR

### Update Frequency:
- Dashboard refreshes: Every 10 seconds
- Metrics collection: Real-time
- Alert evaluation: Every refresh cycle

### Persistence:
- Alerts remain until condition resolves
- Multiple alerts can display simultaneously
- "All systems operational" shows when no alerts

### Priority Display:
1. Critical alerts (security) shown first
2. Warning alerts (system/infrastructure)
3. Info messages last

---

## 🛡️ SECURITY ALERTS - DETAILED RESPONSE

### SSH Brute Force Detection:

**Investigation Steps:**
```bash
# Check recent SSH attempts
log show --predicate 'eventMessage contains "sshd"' --last 1h

# View failed SSH attempts with IPs
tail -100 /var/log/system.log | grep "sshd.*Failed"

# Check current SSH connections
lsof -i :22
```

**Prevention Measures:**
1. Use SSH keys instead of passwords
2. Change default SSH port
3. Enable fail2ban
4. Use Tailscale for SSH access only
5. Disable root login

---

### Dashboard Login Failures:

**Investigation Steps:**
```bash
# Check dashboard logs
tail -100 ~/Claude-Code/Logs/dashboard-server.log | grep "401"

# View recent access attempts
tail -100 ~/Claude-Code/Logs/dashboard-server.log | grep "Authorization"

# Check for patterns (repeated IPs)
grep "401" ~/Claude-Code/Logs/dashboard-server.log | awk '{print $1}' | sort | uniq -c
```

**Security Measures:**
1. Change dashboard password:
   ```bash
   ~/Claude-Code/Scripts/change-dashboard-password.sh
   ```
2. Enable IP whitelist
3. Add rate limiting
4. Use Tailscale access only
5. Enable 2FA (future enhancement)

---

## 💡 ADDITIONAL ALERT IDEAS

### Recommended Future Additions:

#### 1. **Network Bandwidth Spike**
- Monitor unusual network traffic
- Alert on bandwidth > 90% of capacity
- Detect potential DDoS or data exfiltration

#### 2. **Repeated Failed API Calls**
- Monitor Pi-hole API failures
- Track Plex API errors
- Detect service degradation

#### 3. **Backup Failure Detection**
- Alert if Google Drive backup fails
- Monitor backup timestamps
- Track backup size anomalies

#### 4. **Port Scan Detection**
- Monitor for port scanning attempts
- Alert on suspicious port activity
- Track connection attempts from unknown IPs

#### 5. **Certificate Expiration**
- Monitor SSL certificate expiry
- Alert 30 days before expiration
- Track Tailscale cert renewals

#### 6. **Suspicious Process Detection**
- Monitor for unknown processes
- Alert on high CPU processes
- Detect crypto miners

#### 7. **File System Changes**
- Monitor critical system directories
- Alert on unauthorized modifications
- Track permission changes

#### 8. **Pi-hole Blocking Failure**
- Alert if Pi-hole stops blocking
- Monitor query response times
- Track DNS resolution failures

#### 9. **Plex Transcoding Overload**
- Monitor Plex transcoding queue
- Alert on excessive streams
- Track server performance

#### 10. **Time Drift Detection**
- Monitor system clock accuracy
- Alert on significant time drift
- Important for logs and security

---

## 🧪 TESTING ALERTS

### Test Each Alert Type:

```bash
# Test overall alert system
~/Claude-Code/Scripts/collect-metrics.sh | grep -A 50 "alerts"

# Check memory alert threshold
vm_stat | grep "Pages active"

# Check disk usage
df -h /System/Volumes/Data

# View SSH logs
log show --predicate 'eventMessage contains "sshd"' --last 1h

# Check dashboard logs
tail -50 ~/Claude-Code/Logs/dashboard-server.log

# Check service status
docker ps -a

# Monitor CPU temperature
sudo powermetrics --samplers smc -i1 -n1 | grep "CPU die"

# Check Tailscale
tailscale status
```

---

## ⚙️ CUSTOMIZING ALERTS

### Modify Thresholds:

**Edit:** `~/Claude-Code/Scripts/collect-metrics.sh`

**Common Adjustments:**
```bash
# Memory alert (currently 90%)
if [ "$MEM_PERCENT" -gt 90 ]; then

# Disk alert (currently 75%)
if [ "$DISK_PERCENT" -gt 75 ]; then

# SSH attempts (currently 5 in 1 hour)
if [ "$SSH_FAILED" -gt 5 ]; then

# Dashboard failures (currently 3 in 10 min)
if [ "$DASHBOARD_FAILED" -gt 3 ]; then

# CPU temperature (currently 80°C)
if [ "$CPU_TEMP" -gt 80 ]; then
```

---

## 📋 ALERT RESPONSE CHECKLIST

### When You See an Alert:

1. **Identify Severity**
   - Critical = immediate action
   - Warning = investigate soon
   - Info = awareness only

2. **Check Details**
   - Read full alert message
   - Note affected service
   - Check timestamp

3. **Investigate**
   - Use commands in this guide
   - Check relevant logs
   - Identify root cause

4. **Take Action**
   - Follow recommended steps
   - Document what you did
   - Monitor for recurrence

5. **Verify Resolution**
   - Wait for alert to clear
   - Confirm service health
   - Test affected functionality

---

## 📊 ALERT STATISTICS

Track your alerts over time:

```bash
# Count alerts by type in last 24h
grep "severity" ~/Claude-Code/Logs/dashboard-server.log | \
  grep "$(date '+%Y-%m-%d')" | \
  grep -o '"service":"[^"]*"' | \
  sort | uniq -c

# Most common alerts
grep "message" ~/Claude-Code/Logs/dashboard-server.log | \
  sort | uniq -c | sort -nr | head -5
```

---

## 🔧 TROUBLESHOOTING

### Alert Not Showing:

1. Check script syntax:
   ```bash
   bash -n ~/Claude-Code/Scripts/collect-metrics.sh
   ```

2. Run metrics manually:
   ```bash
   ~/Claude-Code/Scripts/collect-metrics.sh
   ```

3. Check dashboard server:
   ```bash
   ps aux | grep dashboard-server
   ```

4. Verify dashboard logs:
   ```bash
   tail -50 ~/Claude-Code/Logs/dashboard-server.log
   ```

### False Positives:

- Adjust thresholds in collect-metrics.sh
- Add exclusions for known patterns
- Increase alert timeframes

### Missing Alerts:

- Ensure all services are monitored
- Check log file permissions
- Verify metric collection frequency

---

## 📖 RELATED DOCUMENTATION

- **Disk Alerts:** `~/Claude-Code/Scripts/DISK_ALERT_INFO.md`
- **Dashboard Auth:** `~/Claude-Code/Scripts/DASHBOARD_AUTH_README.md`
- **Service Management:** `~/Claude-Code/Scripts/startup-all-services.sh`
- **Cleanup Guide:** `~/SPACE_OPTIMIZATION_OPTIONS.md`

---

## 🎯 SUMMARY

### Currently Active: 8 Alert Types
- ✅ Memory usage
- ✅ Disk space
- ✅ SSH brute force (NEW)
- ✅ Dashboard login failures (NEW)
- ✅ Service failures (NEW)
- ✅ CPU temperature (NEW)
- ✅ Tailscale connectivity (NEW)
- ✅ Docker health (NEW)

### Alert Locations:
- System Matrix Dashboard (primary)
- Log files (historical)
- Real-time metrics API

### Response Protocol:
1. Identify severity
2. Investigate cause
3. Take corrective action
4. Monitor resolution
5. Document incident

---

**Your system is now comprehensively monitored with proactive security and performance alerts!** 🚀

