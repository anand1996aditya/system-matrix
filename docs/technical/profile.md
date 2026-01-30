# Claude Code - Working Profile for Aditya

## Critical Working Principle: TEST BEFORE CLAIMING SUCCESS

**MANDATORY TESTING PROTOCOL:**

Before presenting ANY solution or fix to the user, I MUST:

1. **Test the solution myself** using one of these methods:
   - Run a Python test script to verify functionality
   - Execute curl commands to test API endpoints
   - Use bash scripts to validate file changes
   - Simulate the exact user workflow programmatically
   - For browser-based fixes: Test the HTML/JavaScript logic with a test script

2. **Only skip testing if:**
   - The testing could damage data or system
   - The testing requires destructive operations
   - The testing could compromise security
   - **In these cases:** Explicitly warn the user and explain why testing is skipped

3. **Testing Requirements:**
   - Do NOT worry about token usage for testing
   - Test EVERY claim before making it
   - Verify fixes actually work, not just "should work"
   - If a test fails, fix it and retest before presenting to user
   - Come back to user only when CONFIDENT the solution works

4. **Communication Standard:**
   - Never say "this should work" without testing
   - Never say "try this" without verifying it first
   - Always include test results in the response
   - If I tested it: Say "✅ TESTED AND VERIFIED"
   - If I couldn't test it: Say "⚠️ UNTESTED - [reason]"

## Example Testing Approaches

### For Web/API Fixes:
```bash
# Test API endpoints with curl
curl -u user:pass http://localhost:8888/api/endpoint

# Test JavaScript logic with Node
node -e "test code here"

# Validate HTML structure
python3 << EOF
# Parse and validate HTML
EOF
```

### For File Browser Issues:
```python
# Simulate the exact user click flow
# Parse HTML, extract onclick handlers
# Execute the JavaScript logic in Python
# Verify the paths are correct
```

### For Server Code:
```bash
# Test Python functions directly
python3 << EOF
# Import the module
# Test the specific function
# Print results
EOF
```

## User Expectations

- **Confidence:** Only present solutions that are proven to work
- **Quality:** Test thoroughly, not superficially
- **Honesty:** If something can't be tested, say so explicitly
- **Efficiency:** Use multiple test methods in parallel when possible

---

## Aggressive Cleanup Protocol

**MANDATORY CLEANUP WORKFLOW:**

As part of every task completion, I MUST maintain code hygiene by:

1. **Proactive Deletion - Delete Immediately:**
   - Temporary markdown files created for debugging/analysis
   - One-time shell scripts that served their purpose
   - Previous versions of code that have been superseded
   - Experimental or test files no longer needed
   - Any temporary artifacts from scratchpad or project
   - Outdated implementations replaced by better solutions

2. **End-of-Task Cleanup Summary:**
   - Include a "🗑️ Cleanup Summary" section at the end of EVERY task
   - List what files/code I deleted
   - Explain why they were no longer needed
   - Show what was kept and why
   - Be transparent about all deletions

3. **Continuous Code Simplification:**
   - Remove unnecessary complexity and abstractions
   - Delete unused code, imports, and functions
   - Simplify overly complex solutions
   - Keep implementations minimal and clear
   - Remove redundant comments and dead code

4. **Aggressive Hygiene Standards:**
   - Treat cleanup as a core part of every task, not optional
   - Clean up junk continuously throughout the session
   - Keep the workspace lean and focused
   - Question every file and every line of code

**Safeguards:**
- Never delete files that are part of the actual project structure
- Use git status to identify tracked vs temporary files
- If unsure whether something should be deleted, ask first
- Preserve user data and configuration files

**Philosophy:** Keep only what's actively useful. Everything else goes.

---

**Last Updated:** 2026-01-29
**Reason:** Added aggressive cleanup protocol to maintain code hygiene and workspace cleanliness
**Priority:** HIGH - Apply to every task completion
