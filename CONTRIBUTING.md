# Contributing to System Matrix 🤝

First off, **thank you!** 🎉 The fact that you're reading this means you're considering contributing, and that's awesome.

System Matrix is built by people who care about making macOS monitoring easier and more accessible. Whether you're fixing a typo, adding a feature, or reporting a bug, your contribution matters.

---

## 🎯 Ways to Contribute

### 1. Report Bugs 🐛

Found something broken? Let us know!

**Before submitting:**
- Check if someone already reported it in [Issues](https://github.com/anand1996aditya/system-matrix/issues)
- Make sure you're running the latest version
- Try to reproduce it consistently

**When reporting:**
- **What happened?** (the bug)
- **What should have happened?** (expected behavior)
- **How can we reproduce it?** (steps)
- **Your environment** (macOS version, Python version, etc.)
- **Logs** (if applicable)

### 2. Suggest Features 💡

Have an idea? We're all ears!

Open an issue with:
- **What problem does it solve?**
- **How would it work?** (mockups/examples welcome)
- **Who would benefit?**

### 3. Improve Documentation 📚

Docs can always be clearer! Feel free to:
- Fix typos
- Add examples
- Clarify confusing sections
- Add screenshots/GIFs
- Translate to other languages

### 4. Write Code 💻

Ready to dive in? Awesome!

---

## 🚀 Getting Started

### Fork & Clone

```bash
# Fork the repo on GitHub, then:
git clone https://github.com/YOUR_USERNAME/system-matrix.git
cd system-matrix

# Add upstream remote
git remote add upstream https://github.com/anand1996aditya/system-matrix.git
```

### Set Up Development Environment

```bash
# Run setup to create config
./setup.sh

# Install git hooks (runs tests before commits)
./scripts/utilities/install-git-hooks.sh

# Make sure tests pass
./tests/run-all-tests.sh
```

### Create a Branch

```bash
# Create a descriptive branch name
git checkout -b feature/add-slack-notifications
# or
git checkout -b fix/dashboard-crash-on-startup
# or
git checkout -b docs/improve-installation-guide
```

**Branch naming:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation
- `refactor/` - Code improvements
- `test/` - Test additions/fixes

---

## 💻 Development Guidelines

### Code Style

**Bash Scripts:**
```bash
#!/bin/bash

# Use set -e to exit on errors
set -e

# Clear comments explaining what code does
# Use descriptive variable names (not single letters)
BOT_TOKEN="$CONFIG_TELEGRAM_BOT_TOKEN"

# Functions in lowercase with underscores
send_alert() {
    local severity="$1"
    local message="$2"
    # ...
}
```

**Python:**
```python
#!/usr/bin/env python3

"""
Module docstring explaining what this does.
"""

# Standard library imports first
import os
import sys

# Third-party imports second
import json

# Local imports last
from config_loader import get_config

# Constants in UPPERCASE
MAX_RETRIES = 3

# Functions in snake_case
def collect_metrics():
    """Function docstring."""
    pass
```

### Testing

**Before committing:**

```bash
# Run all tests
./tests/run-all-tests.sh

# If you added new scripts, test them:
bash -n your-new-script.sh  # Syntax check
./your-new-script.sh        # Actually run it

# Security scan MUST pass
./scripts/utilities/security-scan.sh
```

**Write tests** for new features (add to `tests/` directory).

### Commit Messages

Good commit messages help everyone understand changes:

```bash
# Good ✅
git commit -m "Add Slack notification support

- Created send-slack-alert.sh script
- Updated config template with Slack webhook
- Added Slack section to README
- Tests pass"

# Bad ❌
git commit -m "fixed stuff"
git commit -m "Update"
```

**Format:**
```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain WHAT and WHY, not HOW (code shows how).

- Bullet points are fine
- Reference issues: Fixes #123
```

---

## 📝 Pull Request Process

### Before Submitting

- [ ] Tests pass (`./tests/run-all-tests.sh`)
- [ ] Security scan passes (`./scripts/utilities/security-scan.sh`)
- [ ] Code follows existing style
- [ ] Documented new features in README
- [ ] Added/updated tests for changes
- [ ] Branch is up to date with `main`

### Submitting

1. **Push your branch:**
   ```bash
   git push origin feature/your-feature
   ```

2. **Open Pull Request** on GitHub

3. **Fill in PR template** (will appear automatically)

4. **Link related issues** (e.g., "Fixes #42")

### PR Title Format

```
feat: Add Slack notification support
fix: Dashboard crash on empty metrics
docs: Improve Telegram setup guide
refactor: Simplify config loader
test: Add tests for alert cooldown
```

### What Happens Next

- **Automated tests** will run (make sure they pass!)
- **Code review** - We'll review and provide feedback
- **Discussions** - We might ask questions or suggest changes
- **Merge** - Once approved, we'll merge it!

---

## 🎨 Feature Guidelines

### Adding New Service Support

Want to add monitoring for a new service? Awesome!

**Example: Adding Slack monitoring**

1. **Detection** (in `scripts/utilities/detect-services.sh`):
   ```bash
   if command -v slack &> /dev/null; then
       echo "  \"slack\": { \"installed\": true, \"running\": true },"
   fi
   ```

2. **Metrics** (in `scripts/monitoring/collect-metrics.sh`):
   ```bash
   if pgrep -x "Slack" > /dev/null; then
       SLACK_STATUS="running"
   else
       SLACK_STATUS="stopped"
   fi
   ```

3. **Config** (update `config/config.template.json` if needed)

4. **Documentation** (update README.md)

5. **Tests** (add tests to verify it works)

### Adding New Alert Types

1. **Create the check** in `collect-metrics.sh`
2. **Send alert** using `send-telegram-alert.sh`
3. **Test it** thoroughly
4. **Document it** in README

---

## 🐛 Bug Fix Guidelines

1. **Reproduce the bug** locally
2. **Write a test** that fails because of the bug
3. **Fix the bug**
4. **Verify test now passes**
5. **Make sure no other tests broke**

---

## 📚 Documentation Guidelines

### README Updates

- Keep the friendly, conversational tone
- Use examples and code snippets
- Add screenshots/GIFs when helpful
- Test all commands actually work

### Code Comments

```bash
# Good ✅
# Check if disk usage is above threshold and send alert
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then

# Bad ❌
# Check disk
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
```

---

## 🔒 Security Guidelines

**NEVER commit:**
- Real API tokens/passwords
- Personal information
- Private keys
- Actual email addresses (use `example@example.com`)

**Always:**
- Use config template with placeholders
- Run security scan before committing
- Use git-ignored config files for real credentials
- Report security issues privately to aditya12anand@protonmail.com

---

## ❓ Questions?

**Not sure about something?**

- 💬 [Open a discussion](https://github.com/anand1996aditya/system-matrix/discussions)
- 📧 Email aditya12anand@protonmail.com
- 🐛 Open an issue (we're friendly!)

**Want to contribute but don't know where to start?**

Look for issues labeled:
- `good first issue` - Perfect for beginners
- `help wanted` - We'd love help with these
- `documentation` - Improve docs

---

## 🎉 Recognition

Contributors are recognized in:
- README.md credits section
- Release notes
- Our eternal gratitude ❤️

---

## 📜 Code of Conduct

### Our Pledge

We're committed to making participation in System Matrix a harassment-free experience for everyone, regardless of:
- Age, body size, disability
- Ethnicity, gender identity/expression
- Level of experience
- Nationality, personal appearance
- Race, religion, sexual identity/orientation

### Our Standards

**Positive behavior:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what's best for the community
- Showing empathy towards others

**Unacceptable behavior:**
- Trolling, insulting/derogatory comments, personal attacks
- Public or private harassment
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported to aditya12anand@protonmail.com. All complaints will be reviewed and investigated.

---

## 🙏 Thank You!

Every contribution, no matter how small, makes System Matrix better. Whether you fixed a typo, added a feature, or just starred the repo - **thank you for being part of this project!**

We can't wait to see what you build! 🚀

---

<div align="center">

**Happy Contributing!** ⭐

Made with ❤️ by the System Matrix community

</div>
