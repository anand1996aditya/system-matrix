# 📱 Alert Notification Setup Guide
**Email, Telegram & WhatsApp Integration**

---

## 📧 OPTION 1: EMAIL NOTIFICATIONS

### ✅ **PROS:**
- ✓ Universal - everyone has email
- ✓ Free (using Gmail, iCloud, etc.)
- ✓ Easy to set up
- ✓ Built-in to macOS
- ✓ Can include detailed reports
- ✓ Reliable delivery
- ✓ No special apps required

### ❌ **CONS:**
- ✗ Can be delayed (1-5 minutes)
- ✗ May go to spam folder
- ✗ Not as instant as messaging apps
- ✗ Requires SMTP configuration
- ✗ Rate limits on free accounts

### 📝 **SETUP STEPS:**

#### Method 1: Using macOS `mail` Command (Simplest)

**Step 1: Enable Internet Accounts**
```bash
# No special setup needed if using iCloud mail
# macOS mail command uses your system mail account
```

**Step 2: Test Email**
```bash
echo "Test alert from System Matrix" | mail -s "Test Alert" your.email@example.com
```

**Step 3: Create Alert Script**
```bash
cat > ~/Claude-Code/Scripts/send-email-alert.sh << 'EOF'
#!/bin/bash
# Send email alert

SUBJECT="$1"
MESSAGE="$2"
TO_EMAIL="your.email@example.com"

echo "$MESSAGE" | mail -s "🚨 System Matrix: $SUBJECT" "$TO_EMAIL"
EOF

chmod +x ~/Claude-Code/Scripts/send-email-alert.sh
```

#### Method 2: Using Gmail SMTP (More Reliable)

**Step 1: Create App Password**
1. Go to https://myaccount.google.com/security
2. Enable 2-Step Verification
3. Go to "App passwords"
4. Generate password for "Mail"
5. Save the 16-character password

**Step 2: Install `msmtp`**
```bash
brew install msmtp
```

**Step 3: Configure `msmtp`**
```bash
cat > ~/.msmtprc << 'EOF'
# Gmail SMTP Configuration
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/cert.pem
logfile        ~/Claude-Code/Logs/msmtp.log

# Gmail account
account        gmail
host           smtp.gmail.com
port           587
from           your.email@gmail.com
user           your.email@gmail.com
password       YOUR_APP_PASSWORD_HERE

# Set default account
account default : gmail
EOF

chmod 600 ~/.msmtprc
```

**Step 4: Test Gmail**
```bash
echo -e "Subject: Test Alert\n\nThis is a test from System Matrix" | \
  msmtp your.email@gmail.com
```

**Step 5: Create Alert Function**
```bash
cat > ~/Claude-Code/Scripts/send-email-alert.sh << 'EOF'
#!/bin/bash

SUBJECT="$1"
MESSAGE="$2"
TO_EMAIL="your.email@gmail.com"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Create email body
EMAIL_BODY="Subject: 🚨 System Matrix Alert: $SUBJECT
From: System Matrix <your.email@gmail.com>
To: $TO_EMAIL

Alert Time: $TIMESTAMP
Severity: $3
Service: $4

$MESSAGE

---
Sent from System Matrix Dashboard
http://localhost:8888
"

echo "$EMAIL_BODY" | msmtp "$TO_EMAIL"
EOF

chmod +x ~/Claude-Code/Scripts/send-email-alert.sh
```

**Step 6: Integrate with Alerts**
Add to `collect-metrics.sh` in alert sections:
```bash
# After each critical alert
~/Claude-Code/Scripts/send-email-alert.sh "SSH Brute Force" "5+ failed attempts detected" "critical" "security"
```

---

## 💬 OPTION 2: TELEGRAM NOTIFICATIONS

### ✅ **PROS:**
- ✓ Instant notifications (< 1 second)
- ✓ Free unlimited messages
- ✓ Easy API integration
- ✓ Can include buttons/links
- ✓ Group chat support
- ✓ Message formatting (Markdown)
- ✓ File/image attachments
- ✓ Most reliable for automation

### ❌ **CONS:**
- ✗ Requires Telegram app
- ✗ Need to create bot
- ✗ Requires API token setup
- ✗ Less universal than email

### 📝 **SETUP STEPS:**

**Step 1: Create Telegram Bot**
1. Open Telegram and search for `@BotFather`
2. Send `/newbot`
3. Choose a name: "System Matrix Alerts"
4. Choose username: "YourSystemMatrixBot"
5. Save the **Bot Token** (looks like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

**Step 2: Get Your Chat ID**
1. Search for your bot in Telegram and start a chat
2. Send any message to your bot
3. Get your chat ID:
```bash
# Replace with your bot token
TOKEN="YOUR_BOT_TOKEN"
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2
```

**Step 3: Create Telegram Alert Script**
```bash
cat > ~/Claude-Code/Scripts/send-telegram-alert.sh << 'EOF'
#!/bin/bash

# Configuration
BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
CHAT_ID="YOUR_CHAT_ID_HERE"

# Parse arguments
SEVERITY="$1"
SERVICE="$2"
MESSAGE="$3"

# Set emoji based on severity
case "$SEVERITY" in
    "critical") EMOJI="🚨" ;;
    "warning")  EMOJI="⚠️" ;;
    "info")     EMOJI="ℹ️" ;;
    *)          EMOJI="📊" ;;
esac

# Format message
TELEGRAM_MESSAGE="${EMOJI} *System Matrix Alert*

*Severity:* ${SEVERITY}
*Service:* ${SERVICE}
*Time:* $(date '+%Y-%m-%d %H:%M:%S')

${MESSAGE}

[Open Dashboard](http://localhost:8888)"

# Send to Telegram
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="${TELEGRAM_MESSAGE}" \
  -d parse_mode="Markdown" \
  -d disable_web_page_preview=true \
  > /dev/null
EOF

chmod +x ~/Claude-Code/Scripts/send-telegram-alert.sh
```

**Step 4: Test Telegram**
```bash
~/Claude-Code/Scripts/send-telegram-alert.sh "critical" "security" "SSH brute force detected: 5 failed attempts"
```

**Step 5: Integrate with Alerts**
Add to `collect-metrics.sh`:
```bash
# For critical alerts only
if [ "$SSH_FAILED" -gt 5 ]; then
    # Show in dashboard
    [existing alert code...]

    # Send Telegram notification
    ~/Claude-Code/Scripts/send-telegram-alert.sh "critical" "security" "SSH brute force: ${SSH_FAILED} attempts" &
fi
```

---

## 📱 OPTION 3: WHATSAPP NOTIFICATIONS

### ✅ **PROS:**
- ✓ Most popular messaging app
- ✓ Instant notifications
- ✓ Familiar to everyone
- ✓ End-to-end encrypted

### ❌ **CONS:**
- ✗ No official API for personal use
- ✗ Requires third-party services (paid)
- ✗ Against WhatsApp ToS (unofficial methods)
- ✗ Can get account banned
- ✗ Complex setup
- ✗ Less reliable than Telegram
- ✗ Risk of account suspension

### 📝 **SETUP OPTIONS:**

#### Option A: Twilio WhatsApp Business API (Recommended)

**Pros:** Official, reliable, business-grade
**Cons:** Paid ($0.005 per message), requires business verification

**Step 1: Create Twilio Account**
1. Sign up at https://www.twilio.com/
2. Get free trial credits ($15)
3. Verify your phone number

**Step 2: Enable WhatsApp**
1. Go to Twilio Console
2. Navigate to WhatsApp Beta
3. Connect your WhatsApp number
4. Get Account SID and Auth Token

**Step 3: Create Script**
```bash
cat > ~/Claude-Code/Scripts/send-whatsapp-alert.sh << 'EOF'
#!/bin/bash

# Twilio Configuration
ACCOUNT_SID="YOUR_ACCOUNT_SID"
AUTH_TOKEN="YOUR_AUTH_TOKEN"
FROM_WHATSAPP="whatsapp:+14155238886"  # Twilio sandbox
TO_WHATSAPP="whatsapp:+1234567890"     # Your number

# Parse arguments
SEVERITY="$1"
SERVICE="$2"
MESSAGE="$3"

# Format message
WHATSAPP_MESSAGE="🚨 *System Matrix Alert*

Severity: ${SEVERITY}
Service: ${SERVICE}
Time: $(date '+%H:%M:%S')

${MESSAGE}"

# Send via Twilio
curl -X POST "https://api.twilio.com/2010-04-01/Accounts/${ACCOUNT_SID}/Messages.json" \
  --data-urlencode "From=${FROM_WHATSAPP}" \
  --data-urlencode "To=${TO_WHATSAPP}" \
  --data-urlencode "Body=${WHATSAPP_MESSAGE}" \
  -u "${ACCOUNT_SID}:${AUTH_TOKEN}"
EOF

chmod +x ~/Claude-Code/Scripts/send-whatsapp-alert.sh
```

#### Option B: CallMeBot (Free, but less reliable)

**Pros:** Free, simple
**Cons:** Unreliable, rate limits, privacy concerns

**Setup:**
1. Add CallMeBot to WhatsApp: +34 644 28 34 89
2. Send message: "I allow callmebot to send me messages"
3. Get your API key from reply

**Script:**
```bash
#!/bin/bash
API_KEY="YOUR_API_KEY"
PHONE="1234567890"
MESSAGE="$1"

curl -s "https://api.callmebot.com/whatsapp.php?phone=${PHONE}&text=${MESSAGE}&apikey=${API_KEY}"
```

#### Option C: WhatsApp Web (Unofficial - NOT RECOMMENDED)

**Warning:** Against WhatsApp ToS, can result in ban

---

## 🎯 **COMPARISON TABLE**

| Feature | Email | Telegram | WhatsApp (Twilio) | WhatsApp (Unofficial) |
|---------|-------|----------|-------------------|----------------------|
| **Speed** | 1-5 min | < 1 sec | < 1 sec | 1-5 sec |
| **Cost** | Free | Free | $0.005/msg | Free/Risk |
| **Reliability** | High | Very High | High | Low |
| **Setup Difficulty** | Easy | Easy | Medium | Hard |
| **Privacy** | Medium | High | High | Low |
| **Account Risk** | None | None | None | High (ban) |
| **Rate Limits** | Yes | No | Yes | Yes |
| **Rich Formatting** | Limited | Yes | Limited | Limited |
| **Attachments** | Yes | Yes | Yes | Limited |
| **API Quality** | Good | Excellent | Good | Poor |

---

## 🏆 **RECOMMENDED APPROACH**

### Primary: **Telegram** (Best for automation)
- Instant notifications
- Free unlimited messages
- Easy setup
- Reliable API

### Backup: **Email** (Universal fallback)
- Works everywhere
- No app required
- Good for detailed reports

### Optional: **WhatsApp (Twilio)** (If needed)
- Only if team uses WhatsApp exclusively
- Paid but reliable
- Business use case

### Avoid: **Unofficial WhatsApp** (Not worth the risk)
- Risk of account ban
- Unreliable
- Against ToS

---

## 🚀 **IMPLEMENTATION PLAN**

### Phase 1: Setup Telegram (15 minutes)
```bash
1. Create bot with @BotFather
2. Get chat ID
3. Create send-telegram-alert.sh
4. Test with: ~/Claude-Code/Scripts/send-telegram-alert.sh "test" "system" "Testing"
```

### Phase 2: Setup Email Backup (10 minutes)
```bash
1. Configure msmtp with Gmail
2. Create send-email-alert.sh
3. Test email delivery
```

### Phase 3: Integrate with Alerts (20 minutes)
```bash
1. Edit collect-metrics.sh
2. Add notification calls for critical alerts
3. Test each alert type
4. Verify notifications arrive
```

---

## 📝 **ALERT NOTIFICATION LOGIC**

### Suggested Rules:

**Critical Alerts → Telegram + Email**
- SSH brute force
- Dashboard login failures
- Rapid file changes

**Warnings → Telegram Only**
- High memory/disk/CPU
- Service failures
- Network issues

**Info → Dashboard Only**
- All systems operational
- Routine status updates

---

## 🔧 **INTEGRATION EXAMPLE**

Here's how to modify `collect-metrics.sh`:

```bash
# Check for SSH brute force attempts
if [ "$SSH_FAILED" -gt 5 ]; then
    [ $ALERT_COUNT -gt 0 ] && echo ","
    echo "    {"
    echo "      \"severity\": \"critical\","
    echo "      \"service\": \"security\","
    echo "      \"message\": \"SSH brute force detected: ${SSH_FAILED} attempts\""
    echo "    }"
    ALERT_COUNT=$((ALERT_COUNT + 1))

    # Send notifications (run in background to not block metrics)
    (
        ~/Claude-Code/Scripts/send-telegram-alert.sh "critical" "security" "SSH brute force: ${SSH_FAILED} failed attempts in last hour"
        ~/Claude-Code/Scripts/send-email-alert.sh "SSH Brute Force" "Detected ${SSH_FAILED} failed SSH login attempts" "critical" "security"
    ) &
fi
```

---

## ⚡ **QUICK START (Recommended)**

Run this to set up Telegram in 2 minutes:

```bash
# 1. Get bot token from @BotFather in Telegram
# 2. Start chat with your bot
# 3. Run this:

echo "Enter your Bot Token:"
read BOT_TOKEN

echo "Sending test message to get your Chat ID..."
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates"

echo ""
echo "Copy your Chat ID from above (the 'id' number) and paste:"
read CHAT_ID

# Create the alert script
cat > ~/Claude-Code/Scripts/send-telegram-alert.sh << EOF
#!/bin/bash
BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"
SEVERITY="\$1"
SERVICE="\$2"
MESSAGE="\$3"
case "\$SEVERITY" in
    "critical") EMOJI="🚨" ;;
    "warning")  EMOJI="⚠️" ;;
    *)          EMOJI="ℹ️" ;;
esac
TELEGRAM_MESSAGE="\${EMOJI} *System Matrix Alert*

*Severity:* \${SEVERITY}
*Service:* \${SERVICE}
*Time:* \$(date '+%Y-%m-%d %H:%M:%S')

\${MESSAGE}"
curl -s -X POST "https://api.telegram.org/bot\${BOT_TOKEN}/sendMessage" \
  -d chat_id="\${CHAT_ID}" \
  -d text="\${TELEGRAM_MESSAGE}" \
  -d parse_mode="Markdown" > /dev/null
EOF

chmod +x ~/Claude-Code/Scripts/send-telegram-alert.sh

echo "✅ Setup complete! Testing..."
~/Claude-Code/Scripts/send-telegram-alert.sh "info" "system" "Telegram notifications are now active!"

echo ""
echo "Check your Telegram for the test message!"
```

---

## 📊 **MONITORING NOTIFICATIONS**

Track notification delivery:

```bash
# Check Telegram notification log
tail -50 ~/Claude-Code/Logs/telegram-alerts.log

# Check email delivery
tail -50 ~/Claude-Code/Logs/msmtp.log

# Test all notification methods
~/Claude-Code/Scripts/test-all-notifications.sh
```

---

**Would you like me to set up any of these notification methods for you right now?**

