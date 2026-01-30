# Security Pipeline - Quick Reference

## 🔒 4 Commands You Need

### 1. Run Security Scan
```bash
./scripts/utilities/security-scan.sh
```
**Use before:** First commit, after changes, before GitHub push

### 2. Install Git Hooks (One-time)
```bash
./scripts/utilities/install-git-hooks.sh
```
**Use once:** After cloning or setting up repository

### 3. Run Tests
```bash
./tests/test-security.sh
```
**Use to:** Validate entire security system

### 4. Check Status
```bash
git status
# Verify config.json shows as "untracked" (not staged)
```

---

## ✅ Pre-commit Checklist

Before `git commit`:
- [ ] Security scan passes
- [ ] No secrets in changes
- [ ] config.json not staged
- [ ] Logs not staged

---

## 🚨 If Commit Blocked

```bash
# 1. Read the error message
# 2. Fix the issue (move secret to config.json)
# 3. Run scan again
./scripts/utilities/security-scan.sh

# 4. Commit again
git commit -m "Your message"
```

**Never use** `git commit --no-verify` unless emergency!

---

## 📊 What Gets Blocked

- ❌ Telegram bot tokens
- ❌ API keys & passwords
- ❌ AWS credentials
- ❌ Private keys
- ❌ User-specific paths (`/Users/aditya`)
- ❌ Database connection strings
- ❌ config.json file
- ❌ Log files
- ❌ Auth files

---

## ✅ What's Safe

- ✓ config.template.json (placeholders)
- ✓ Scripts using $CONFIG_ variables
- ✓ Documentation files
- ✓ README files
- ✓ .gitignore
- ✓ Test files

---

## 🆘 Quick Fixes

### "Token detected"
```bash
# Move to config.json
# Update script to use: $CONFIG_TELEGRAM_BOT_TOKEN
```

### "User path detected"
```bash
# Replace: /Users/aditya/path
# With: $HOME/path or ${CONFIG_BASE_DIR}/path
```

### "config.json tracked"
```bash
git rm --cached config/config.json
git commit -m "Remove config.json from tracking"
```

---

## 📈 Success Indicators

✅ Security scan passes (exit code 0)
✅ Pre-commit hook installed
✅ All 25 tests pass
✅ GitHub Actions badge green
✅ config.json not in git

---

## 🎯 One-time Setup

```bash
cd /Users/aditya/Claude-Code/System-Metrics

# 1. Create config
./setup.sh

# 2. Install hooks
./scripts/utilities/install-git-hooks.sh

# 3. Verify security
./scripts/utilities/security-scan.sh
./tests/test-security.sh

# 4. Commit
git init
git add .
git commit -m "Initial commit"
git push
```

**Done!** All future commits automatically protected.

---

## 📞 Help

- **Full docs:** `docs/setup/SECURITY_VALIDATION.md`
- **Summary:** `SECURITY_PIPELINE_COMPLETE.md`
- **Scanner:** `./scripts/utilities/security-scan.sh`
- **Tests:** `./tests/test-security.sh`

---

**Keep this card handy!** 📌
