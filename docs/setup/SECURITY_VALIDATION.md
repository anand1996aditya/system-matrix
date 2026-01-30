# Security Validation Pipeline

Complete guide to the automated security validation system for System Metrics Dashboard.

---

## Overview

This project includes multiple layers of security validation to ensure **no secrets, credentials, or sensitive data** are accidentally committed to GitHub.

### Security Layers

1. **Manual Security Scan** - Run on-demand
2. **Pre-commit Hook** - Automatic before every commit
3. **GitHub Actions CI/CD** - Automatic on push/PR
4. **Test Suite** - Validates configuration system

---

## 🔒 Security Scanner

### What It Checks

The security scanner (`scripts/utilities/security-scan.sh`) performs 10 comprehensive checks:

1. **Telegram Bot Tokens** - Pattern: `[0-9]{9,10}:[A-Za-z0-9_-]{35}`
2. **API Keys & Passwords** - Common patterns for credentials
3. **Email Addresses** - Hardcoded emails (excluding examples)
4. **Private IP Addresses** - Internal network IPs
5. **User-Specific Paths** - `/Users/username` or `/home/username`
6. **AWS/Cloud Keys** - AWS access keys and secrets
7. **Private Keys** - SSH/TLS private keys
8. **Database Connections** - Connection strings with credentials
9. **.gitignore Configuration** - Ensures sensitive files excluded
10. **Config Template** - Validates placeholders exist

### How to Run

```bash
# Run security scan manually
./scripts/utilities/security-scan.sh
```

### Exit Codes

- **0** = SECURE (safe to commit)
- **1** = ISSUES FOUND (do not commit!)

### Output Example

```
╔════════════════════════════════════════════════════════╗
║        Security Scanner - System Metrics Dashboard     ║
╚════════════════════════════════════════════════════════╝

→ Scanning for security issues...

[1/10] Checking for Telegram bot tokens...
[2/10] Checking for API keys and passwords...
[3/10] Checking for hardcoded email addresses...
[4/10] Checking for hardcoded private IP addresses...
[5/10] Checking for hardcoded user-specific paths...
[6/10] Checking for AWS/cloud credentials...
[7/10] Checking for private keys...
[8/10] Checking for database connection strings...
[9/10] Checking .gitignore configuration...
✓ Config template has placeholders
[10/10] Checking config template...

╔════════════════════════════════════════════════════════╗
║                    Scan Complete                       ║
╚════════════════════════════════════════════════════════╝

✅ SECURE: No security issues found!

Your code is safe to commit to GitHub.
```

---

## 🪝 Pre-commit Hook

### Installation

```bash
# Install git hooks (one-time setup)
./scripts/utilities/install-git-hooks.sh
```

This copies `.git-hooks/pre-commit` to `.git/hooks/pre-commit` and makes it executable.

### How It Works

Every time you run `git commit`, the pre-commit hook:

1. Automatically runs `security-scan.sh`
2. If scan passes → commit proceeds
3. If scan fails → commit is **blocked**

### Example Output

```bash
$ git commit -m "Update config"

🔒 Running security scan before commit...

[Running security checks...]

❌ Commit blocked due to security issues!

Fix the issues above and try again.

To bypass this check (NOT RECOMMENDED):
  git commit --no-verify
```

### Bypassing (NOT RECOMMENDED)

```bash
# Skip pre-commit hook (dangerous!)
git commit --no-verify -m "Message"
```

**⚠️ WARNING:** Only bypass if you're absolutely certain no secrets are present.

---

## 🤖 GitHub Actions CI/CD

### Workflow File

`.github/workflows/security-scan.yml`

### Triggers

- **Push** to main or develop branch
- **Pull requests** to main or develop
- **Manual** trigger via GitHub UI

### What It Does

1. **Runs Security Scanner**
   - All 10 checks from security-scan.sh

2. **Checks Git History**
   - Scans commit history for leaked secrets
   - Detects if secrets were committed in the past

3. **Verifies .gitignore**
   - Confirms `config.json` not tracked
   - Confirms `.dashboard_auth` not tracked
   - Confirms logs not tracked

4. **Validates Config Template**
   - Checks template exists
   - Verifies placeholders present
   - Validates JSON syntax

5. **Checks for Hardcoded Paths**
   - Ensures no `/Users/username` paths in code

### Viewing Results

1. Go to your GitHub repository
2. Click "Actions" tab
3. View workflow runs and results

### Example Badge

Add to README.md:

```markdown
![Security Scan](https://github.com/YOUR_USERNAME/system-metrics-dashboard/actions/workflows/security-scan.yml/badge.svg)
```

---

## 🧪 Test Suite

### Running Tests

```bash
# Run all security tests
./tests/test-security.sh
```

### What It Tests

**Configuration System (7 tests):**
- Config template exists
- Placeholders present
- Valid JSON syntax
- Config loaders exist
- Config loaders executable

**Security Tools (6 tests):**
- Security scanner exists
- Scanner executable
- Git hooks exist
- Pre-commit hook exists
- GitHub Actions workflow exists

**Gitignore (6 tests):**
- .gitignore exists
- Excludes config.json
- Excludes .dashboard_auth
- Excludes logs/
- Excludes alert-state/
- Excludes cache/

**Script Validation (6 tests):**
- Scripts use config system
- No hardcoded tokens
- No hardcoded paths

### Example Output

```
╔════════════════════════════════════════════════════════╗
║              Security Test Suite                       ║
╚════════════════════════════════════════════════════════╝

[1/3] Configuration System Tests

Testing: Config template exists... ✓ PASS
Testing: Config template has bot token placeholder... ✓ PASS
Testing: Config template has chat ID placeholder... ✓ PASS
Testing: Config template is valid JSON... ✓ PASS
Testing: Bash config loader exists... ✓ PASS
Testing: Python config loader exists... ✓ PASS
Testing: Python config loader is executable... ✓ PASS

[2/3] Security Scanner Tests

Testing: Security scanner exists... ✓ PASS
Testing: Security scanner is executable... ✓ PASS
...

╔════════════════════════════════════════════════════════╗
║                    Test Results                        ║
╚════════════════════════════════════════════════════════╝

Total Tests: 25
Passed: 25
Failed: 0

✅ All tests passed! Security configuration is correct.
```

---

## 📋 Security Checklist

### Before First Commit

- [ ] Run `./setup.sh` to create config.json
- [ ] Install git hooks: `./scripts/utilities/install-git-hooks.sh`
- [ ] Run security scan: `./scripts/utilities/security-scan.sh`
- [ ] Run tests: `./tests/test-security.sh`
- [ ] Verify config.json is in .gitignore: `git status`

### Before Every Commit

- [ ] Pre-commit hook runs automatically (no action needed)
- [ ] If hook fails, fix issues before committing
- [ ] Never use `--no-verify` unless absolutely necessary

### After Pushing to GitHub

- [ ] Check GitHub Actions passed
- [ ] Review any warnings in Actions log
- [ ] Ensure no secrets in commit history

---

## 🚨 What If Secrets Were Already Committed?

If you accidentally committed secrets to git history:

### Option 1: BFG Repo-Cleaner (Recommended)

```bash
# Install BFG
brew install bfg  # macOS

# Clone a fresh copy
git clone --mirror https://github.com/YOUR_USERNAME/repo.git

# Remove secrets
bfg --replace-text passwords.txt repo.git

# Cleanup
cd repo.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (⚠️ Warning: rewrites history)
git push --force
```

### Option 2: Git Filter-Branch

```bash
# Remove file from all history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/secret/file" \
  --prune-empty --tag-name-filter cat -- --all

# Force push
git push origin --force --all
```

### Option 3: Delete and Recreate Repo

If the repo is new and you don't mind losing history:

1. Delete repository on GitHub
2. Remove .git folder locally: `rm -rf .git`
3. Fix the secrets in files
4. Run security scan
5. Initialize fresh repo: `git init`
6. Create new repo on GitHub and push

---

## 🛡️ Best Practices

### Do's ✅

- **Always run security scan** before pushing
- **Use config.json** for all secrets
- **Review .gitignore** regularly
- **Install pre-commit hooks** immediately
- **Test on a separate branch** first
- **Use environment variables** for CI/CD secrets

### Don'ts ❌

- **Never commit config.json** to GitHub
- **Never hardcode tokens** in scripts
- **Never use `--no-verify`** unless emergency
- **Never share config.json** via chat/email
- **Never commit .dashboard_auth** file
- **Never expose logs** directory

---

## 🔍 Common Issues

### "Commit blocked due to security issues"

**Cause:** Security scanner found hardcoded secrets

**Solution:**
1. Read the scanner output carefully
2. Move secrets to `config.json`
3. Replace hardcoded values with config variables
4. Run scan again: `./scripts/utilities/security-scan.sh`

### "config.json is tracked by git"

**Cause:** config.json was added before .gitignore

**Solution:**
```bash
# Remove from git (keeps local file)
git rm --cached config/config.json

# Verify it's in .gitignore
grep config.json .gitignore

# Commit the removal
git commit -m "Remove config.json from tracking"
```

### "Pre-commit hook not running"

**Cause:** Hooks not installed

**Solution:**
```bash
./scripts/utilities/install-git-hooks.sh
```

---

## 📊 Security Metrics

### Coverage

- **10** security check types
- **25+** automated tests
- **3** validation layers (manual, pre-commit, CI/CD)
- **100%** of scripts use config system

### Performance

- **Security Scan:** ~2-5 seconds
- **Pre-commit Hook:** ~3-7 seconds
- **GitHub Actions:** ~30-60 seconds

---

## 🆘 Support

If you encounter security issues:

1. **Run verbose scan:** Add `set -x` to security-scan.sh
2. **Check test output:** `./tests/test-security.sh`
3. **Review this guide:** Complete troubleshooting steps
4. **Check GitHub Actions logs:** View detailed CI/CD output

---

## 🎓 Additional Resources

- **Git Hooks Documentation:** https://git-scm.com/docs/githooks
- **GitHub Actions Security:** https://docs.github.com/en/actions/security-guides
- **BFG Repo-Cleaner:** https://rtyley.github.io/bfg-repo-cleaner/
- **git-secrets tool:** https://github.com/awslabs/git-secrets

---

**Remember:** Security is a continuous process, not a one-time check. Always review your code before committing!

---

**Last Updated:** January 30, 2026
**Version:** 1.0.0
