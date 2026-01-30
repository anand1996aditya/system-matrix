# 🎯 Additional Alert Recommendations
**Priority-Ordered List**

---

## 🔴 **CRITICAL SECURITY ALERTS**

### 1. **Unusual Network Connections** ⭐ HIGH PRIORITY
**Why:** Detect malware, data exfiltration, or compromised services
**Check:** Monitor outbound connections to suspicious IPs/ports
**Trigger:** Connection to known malicious IPs or unusual ports
```bash
# Check current connections
lsof -i -n -P | grep ESTABLISHED
netstat -an | grep ESTABLISHED
```

### 2. **Port Exposure Detection** ⭐ HIGH PRIORITY
**Why:** Prevent unauthorized access to services
**Check:** Detect ports accidentally exposed to internet
**Trigger:** Services listening on 0.0.0.0 instead of localhost
```bash
# Check exposed ports
lsof -i -P | grep LISTEN | grep -v "127.0.0.1"
```

### 3. **Rapid File System Changes** ⭐ CRITICAL
**Why:** Early ransomware/malware detection
**Check:** Monitor critical directories for mass file modifications
**Trigger:** >100 files changed in critical dirs in 5 minutes
```bash
# Monitor file changes
fswatch -1 ~/Documents ~/Desktop ~/Projects
```

### 4. **Pi-hole Query Spike** ⭐ HIGH PRIORITY
**Why:** Detect malware beaconing, DNS tunneling, or DDoS
**Check:** Unusual increase in DNS queries
**Trigger:** >5000 queries/minute or 10x normal rate
```bash
# Check Pi-hole query rate
curl -s http://localhost:8080/admin/api.php?summaryRaw
```

---

## ⚠️ **OPERATIONAL ALERTS**

### 5. **Internet Connectivity Loss**
**Why:** Know when you're offline vs service issues
**Check:** Ping external servers (8.8.8.8, 1.1.1.1)
**Trigger:** Cannot reach any external DNS servers
```bash
ping -c 1 8.8.8.8 || ping -c 1 1.1.1.1
```

### 6. **Backup Failure Detection**
**Why:** Ensure data protection is working
**Check:** Monitor backup job completion and timestamps
**Trigger:** Backup not run in 24 hours or failure detected
```bash
# Check last backup time
find ~/Documents -name "*.backup" -mtime -1
```

### 7. **SSL Certificate Expiration**
**Why:** Prevent service disruptions
**Check:** Monitor certificate expiry dates
**Trigger:** Certificate expires in <30 days
```bash
# Check cert expiry
echo | openssl s_client -connect localhost:8443 2>/dev/null | \
  openssl x509 -noout -dates
```

### 8. **Repeated Service Restarts**
**Why:** Detect crash loops or instability
**Check:** Monitor service restart frequency
**Trigger:** Same service restarted >3 times in 10 minutes
```bash
# Check container restarts
docker ps --format "table {{.Names}}\t{{.Status}}" | grep "Restarting"
```

### 9. **System Update Available**
**Why:** Security patch awareness
**Check:** Check for macOS and security updates
**Trigger:** Critical security update available
```bash
# Check for updates
softwareupdate --list
```

### 10. **API Rate Limit Warnings**
**Why:** Prevent service degradation
**Check:** Monitor API response times and error rates
**Trigger:** >10% error rate or slow responses
```bash
# Check API health
time curl -s http://localhost:8080/admin/api.php > /dev/null
```

---

## 💡 **NICE-TO-HAVE ALERTS**

### 11. **Fan Speed Anomaly**
**Why:** Early hardware failure detection
**Check:** Monitor fan RPM changes
**Trigger:** Fan speed sudden increase (thermal issue)

### 12. **Power Supply Status**
**Why:** Know about power issues
**Check:** Battery health, charging status
**Trigger:** Battery health < 80% or not charging

### 13. **Bandwidth Spike**
**Why:** Detect unusual usage patterns
**Check:** Monitor network traffic volume
**Trigger:** Bandwidth usage >2x normal

### 14. **Time Drift Detection**
**Why:** Important for logs and security
**Check:** Compare system time to NTP servers
**Trigger:** Time difference > 5 seconds

### 15. **Zombie Process Detection**
**Why:** System health indicator
**Check:** Count zombie processes
**Trigger:** >5 zombie processes

---

## 🎯 RECOMMENDED IMPLEMENTATION ORDER

### Phase 1 (Implement Now):
1. Port Exposure Detection
2. Internet Connectivity Loss
3. Backup Failure Detection
4. Pi-hole Query Spike

### Phase 2 (Next Week):
5. Unusual Network Connections
6. SSL Certificate Expiration
7. Repeated Service Restarts
8. System Update Available

### Phase 3 (Future):
9. Rapid File System Changes
10. API Rate Limit Warnings
11. Bandwidth Spike
12. Time Drift Detection

---

## 📊 ALERT PRIORITY MATRIX

| Alert | Security Impact | Operational Impact | Implementation Difficulty |
|-------|----------------|-------------------|--------------------------|
| Port Exposure | 🔴 Critical | ⚠️ Medium | ✅ Easy |
| Network Connections | 🔴 Critical | ⚠️ Medium | ⚠️ Medium |
| Rapid File Changes | 🔴 Critical | ⚠️ Low | 🔴 Hard |
| Pi-hole Spike | ⚠️ High | ⚠️ High | ✅ Easy |
| Internet Loss | ⚠️ Low | 🔴 Critical | ✅ Easy |
| Backup Failure | ⚠️ Medium | 🔴 Critical | ✅ Easy |
| SSL Expiration | ⚠️ Medium | ⚠️ High | ✅ Easy |
| Service Restarts | ⚠️ Low | ⚠️ High | ✅ Easy |
| System Updates | ⚠️ Medium | ⚠️ Medium | ✅ Easy |
| API Rate Limits | ⚠️ Low | ⚠️ Medium | ⚠️ Medium |

