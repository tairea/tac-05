# ADW System Debugging & Testing Guide

> **Context Priming Document**: Read this first when debugging ADW issues to understand the system architecture, common issues, and debugging strategies.

## Quick Reference

- **Main Documentation**: [README.md](/opt/adw/README.md)
- **ADW Detailed Docs**: [adws/README.md](/opt/adw/adws/README.md)
- **Working Directory**: `/opt/adw`
- **Agent Logs**: `/opt/adw/agents/<adw_id>/`
- **System Logs**: `/opt/adw/logs/`

## System Architecture Overview

### Key Components

1. **Trigger Systems**
   - `adw_triggers/trigger_webhook.py` - FastAPI webhook server (port 8001)
   - `adw_triggers/trigger_cron.py` - Polling monitor (20s interval)

2. **Workflow Scripts**
   - `adw_plan.py` - Planning phase (issue classification, branch creation, plan generation)
   - `adw_build.py` - Implementation phase (executes the plan)
   - `adw_test.py` - Testing phase (runs test suite)
   - `adw_plan_build.py` - Combined plan + build
   - `adw_plan_build_test.py` - Full pipeline (plan + build + test)

3. **Core Modules** (`adw_modules/`)
   - `agent.py` - Claude Code CLI integration
   - `github.py` - GitHub API operations
   - `git_ops.py` - Git operations (commits, branches, PRs)
   - `workflow_ops.py` - Core workflow logic
   - `state.py` - State management (adw_state.json)
   - `data_types.py` - Pydantic models

### Workflow Execution Flow

```
GitHub Issue Created
    ↓
Webhook/Cron Trigger Detects
    ↓
Launches adw_plan_build_test.py <issue_number> <adw_id>
    ↓
├─ adw_plan.py
│  ├─ Classify issue (/feature, /bug, /chore)
│  ├─ Generate branch name
│  ├─ Create implementation plan
│  └─ Commit plan + create PR
│
├─ adw_build.py
│  ├─ Read plan from state
│  ├─ Execute implementation
│  ├─ Make code changes
│  └─ Commit + push
│
└─ adw_test.py
   ├─ Run test suite
   ├─ Report results
   └─ Commit + push
```

## Directory Structure

```
/opt/adw/
├── agents/                     # Agent execution logs (indexed by ADW ID)
│   └── <adw_id>/
│       ├── adw_state.json     # Workflow state
│       ├── webhook_trigger/
│       │   └── execution.log
│       ├── issue_classifier/
│       │   ├── prompts/
│       │   ├── raw_output.jsonl
│       │   └── raw_output.json
│       ├── branch_generator/
│       ├── sdlc_planner/
│       ├── sdlc_implementor/
│       ├── adw_plan/
│       │   └── execution.log
│       ├── adw_build/
│       │   └── execution.log
│       ├── adw_test/
│       │   └── execution.log
│       └── adw_plan_build_test/
│           ├── stdout.log     # Workflow stdout
│           └── stderr.log     # Workflow stderr
│
├── adws/                      # ADW scripts and modules
│   ├── adw_modules/           # Core Python modules
│   ├── adw_triggers/          # Webhook and cron triggers
│   └── adw_tests/             # Health checks and tests
│
├── .local/bin/                # User binaries
│   ├── claude                 # Claude Code CLI
│   └── uv                     # Python package manager
│
└── logs/                      # System logs
```

## Common Issues & Solutions

### 1. Webhook Posts Comment But Nothing Happens

**Symptoms:**
- GitHub comment posted: `[ADW-BOT] 🤖 ADW Webhook: Detected adw_plan_build_test workflow request`
- No subsequent activity
- Log directory created but empty or with errors

**Debugging Steps:**

```bash
# 1. Find the ADW ID from the GitHub comment (e.g., d669f5bd)
ADW_ID="d669f5bd"

# 2. Check if workflow logs exist
ls -la /opt/adw/agents/$ADW_ID/

# 3. Check stdout/stderr from the workflow launch
cat /opt/adw/agents/$ADW_ID/adw_plan_build_test/stdout.log
cat /opt/adw/agents/$ADW_ID/adw_plan_build_test/stderr.log

# 4. Check webhook execution log
cat /opt/adw/agents/$ADW_ID/webhook_trigger/execution.log
```

**Common Root Causes:**

a) **PATH Issues** - `uv` or `claude` not in PATH
```bash
# Check webhook process environment
ps aux | grep trigger_webhook | grep -v grep
# Note the PID, then:
cat /proc/<PID>/environ | tr '\0' '\n' | grep PATH

# Fix: Use full paths in scripts
uv_path = os.path.join(repo_root, ".local", "bin", "uv")
```

b) **Permission Issues** - Running as wrong user
```bash
# Check process owner
ps aux | grep trigger_webhook

# Check file permissions
ls -la /opt/adw/.local/bin/uv
ls -la /opt/adw/.local/bin/claude
```

c) **Claude Code Permission Error**
```
Error: --dangerously-skip-permissions cannot be used with root/sudo privileges
```
- This means Claude Code is being run as root
- Ensure webhook spawns processes as `adw-user`

### 2. Workflow Starts But Fails During Execution

**Debugging Steps:**

```bash
# Find recent ADW executions
ls -ltr /opt/adw/agents/ | tail -10

# Check the most recent one
ADW_ID="<latest_id>"
tail -50 /opt/adw/agents/$ADW_ID/adw_plan_build_test/stdout.log
tail -50 /opt/adw/agents/$ADW_ID/adw_plan_build_test/stderr.log

# Check individual phase logs
cat /opt/adw/agents/$ADW_ID/adw_plan/execution.log
cat /opt/adw/agents/$ADW_ID/adw_build/execution.log
cat /opt/adw/agents/$ADW_ID/adw_test/execution.log

# Check agent outputs
cat /opt/adw/agents/$ADW_ID/issue_classifier/raw_output.jsonl | tail -1 | jq .
cat /opt/adw/agents/$ADW_ID/sdlc_planner/raw_output.jsonl | tail -1 | jq .
cat /opt/adw/agents/$ADW_ID/sdlc_implementor/raw_output.jsonl | tail -1 | jq .
```

### 3. Webhook Server Not Running

**Check Status:**
```bash
# Check if webhook is running
ps aux | grep trigger_webhook | grep -v grep

# Check port binding
lsof -i :8001

# Test health endpoint
curl http://localhost:8001/health
```

**Restart Webhook:**
```bash
# Find and kill existing processes
pkill -f trigger_webhook

# Start webhook server
cd /opt/adw/adws/adw_triggers
nohup /opt/adw/.local/bin/uv run trigger_webhook.py > /opt/adw/logs/webhook.log 2>&1 &

# Verify it started
sleep 2
ps aux | grep trigger_webhook | grep -v grep
```

### 4. GitHub API Issues

**Common Errors:**
```bash
# "GraphQL: Could not resolve to an issue or pull request"
# - Issue number doesn't exist
# - Wrong repository

# Check GitHub authentication
gh auth status

# Test GitHub API access
gh issue list --repo tairea/tac-05 --limit 5

# Check environment variables
echo $GITHUB_REPO_URL
echo $GITHUB_PAT
```

## Testing & Debugging Strategies

### Manual Workflow Testing

```bash
# Test the full pipeline manually
cd /opt/adw
/opt/adw/.local/bin/uv run /opt/adw/adws/adw_plan_build_test.py 7 test123

# Test individual phases
/opt/adw/.local/bin/uv run /opt/adw/adws/adw_plan.py 7 test456
/opt/adw/.local/bin/uv run /opt/adw/adws/adw_build.py 7 test456
/opt/adw/.local/bin/uv run /opt/adw/adws/adw_test.py 7 test456
```

### Simulating Webhook Events

```bash
# Create test payload
cat > /tmp/test_webhook.json << 'EOF'
{
  "action": "opened",
  "issue": {
    "number": 7,
    "body": "adw_plan_build_test\n\n/feature\n\nTest description"
  }
}
EOF

# Send to webhook
curl -X POST http://localhost:8001/gh-webhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: issues" \
  -d @/tmp/test_webhook.json

# Check response and logs
sleep 3
find /opt/adw/agents -name "*.log" -mmin -1 -exec ls -lh {} \;
```

### Environment Verification

```bash
# Check all required binaries
which uv || echo "uv not in PATH"
which claude || echo "claude not in PATH"
which gh || echo "gh not in PATH"

# Use full paths
/opt/adw/.local/bin/uv --version
/opt/adw/.local/bin/claude --version
gh --version

# Check environment variables
env | grep -E "(GITHUB|ANTHROPIC|CLAUDE)" | sort

# Verify GitHub repo access
gh repo view tairea/tac-05
```

### Process Environment Debugging

```bash
# Find webhook process
PID=$(ps aux | grep trigger_webhook | grep -v grep | awk '{print $2}' | head -1)

# Check environment
cat /proc/$PID/environ | tr '\0' '\n' | grep -E "PATH|USER|HOME|CLAUDE|ANTHROPIC"

# Check open file descriptors
lsof -p $PID | grep -E "(log|txt|out)"

# Check current working directory
readlink -f /proc/$PID/cwd
```

### State Management Debugging

```bash
# Find state files
find /opt/adw/agents -name "adw_state.json" -mmin -60

# View state
ADW_ID="<id>"
cat /opt/adw/agents/$ADW_ID/adw_state.json | jq .

# Common state fields:
# - adw_id: Workflow ID
# - issue_number: GitHub issue number
# - branch_name: Git branch name
# - plan_file: Path to implementation plan
# - issue_class: Classification (/feature, /bug, /chore)
```

### Git Branch Debugging

```bash
# Check if branch exists locally
cd /opt/adw
git branch -a | grep -i "e211dda3"

# Check remote branches
git ls-remote --heads origin | grep -i "feature"

# Check current branch
git branch --show-current

# Check for uncommitted changes
git status
```

## Quick Diagnostic Script

```bash
#!/bin/bash
# Save as /opt/adw/scripts/diagnose_adw.sh

echo "=== ADW System Diagnostics ==="
echo

echo "1. Webhook Status:"
ps aux | grep trigger_webhook | grep -v grep || echo "  ❌ Not running"
echo

echo "2. Recent Workflows (last 5):"
ls -ltr /opt/adw/agents/ | tail -6
echo

echo "3. Environment Variables:"
env | grep -E "(GITHUB_REPO_URL|CLAUDE_CODE_PATH)" | sed 's/=.*$/=***/'
echo

echo "4. Binary Paths:"
echo "  uv: $(/opt/adw/.local/bin/uv --version 2>&1 | head -1)"
echo "  claude: $(/opt/adw/.local/bin/claude --version 2>&1 | head -1)"
echo "  gh: $(gh --version 2>&1 | head -1)"
echo

echo "5. Webhook Health:"
curl -s http://localhost:8001/health | jq -r '.status // "ERROR"' 2>/dev/null || echo "  ❌ Cannot reach webhook"
echo

echo "6. Recent Errors (last 10 lines):"
find /opt/adw/agents -name "stderr.log" -mmin -60 -exec tail -1 {} \; 2>/dev/null | grep -v "^$" | tail -10
echo

echo "7. Git Status:"
cd /opt/adw && git status --short | head -10
```

## Best Practices for Debugging

1. **Always Check Logs in Order:**
   - Webhook execution log (webhook_trigger/execution.log)
   - Workflow stdout/stderr (adw_plan_build_test/stdout.log, stderr.log)
   - Phase-specific logs (adw_plan/execution.log, etc.)
   - Agent outputs (raw_output.jsonl)

2. **Use Full Paths:**
   - Never rely on PATH in subprocess calls
   - Always use `/opt/adw/.local/bin/uv` instead of `uv`
   - Always use `/opt/adw/.local/bin/claude` instead of `claude`

3. **Check Process Environment:**
   - Verify the user running the process
   - Check PATH, HOME, and other environment variables
   - Ensure proper permissions on binaries

4. **Test Components Individually:**
   - Test webhook endpoint separately
   - Run workflow scripts manually
   - Verify GitHub API access
   - Test Claude Code CLI directly

5. **Monitor in Real-Time:**
   ```bash
   # Watch workflow logs as they're written
   tail -f /opt/adw/agents/<adw_id>/adw_plan_build_test/stdout.log

   # Watch for new agent executions
   watch -n 2 'ls -ltr /opt/adw/agents/ | tail -10'
   ```

## Environment Setup Checklist

When setting up a new environment or debugging environment issues:

- [ ] `/opt/adw/.local/bin/uv` exists and is executable
- [ ] `/opt/adw/.local/bin/claude` exists and is executable
- [ ] `gh` is installed and authenticated (`gh auth status`)
- [ ] `GITHUB_REPO_URL` is set in environment
- [ ] `ANTHROPIC_API_KEY` is set in environment
- [ ] Webhook server is running (`ps aux | grep trigger_webhook`)
- [ ] Port 8001 is accessible (`curl http://localhost:8001/health`)
- [ ] Git repository is initialized (`cd /opt/adw && git status`)
- [ ] User has write access to `/opt/adw/agents/`
- [ ] Claude Code CLI can run without permission errors

## Troubleshooting Checklist

When a workflow fails:

1. [ ] Check stderr.log for error messages
2. [ ] Verify ADW ID in GitHub comment matches log directory
3. [ ] Confirm webhook server is running
4. [ ] Check if binary paths are correct
5. [ ] Verify GitHub issue exists and is accessible
6. [ ] Check git branch was created
7. [ ] Review agent output JSONLs for failures
8. [ ] Verify environment variables are set
9. [ ] Check for permission issues
10. [ ] Test individual components manually

## Quick Command Reference

```bash
# Find latest workflow
ls -ltr /opt/adw/agents/ | tail -1

# Check specific workflow
ADW_ID="<id>"
ls -la /opt/adw/agents/$ADW_ID/

# View all logs for a workflow
find /opt/adw/agents/$ADW_ID -name "*.log" -exec echo "=== {} ===" \; -exec cat {} \;

# Restart webhook
pkill -f trigger_webhook && cd /opt/adw/adws/adw_triggers && nohup /opt/adw/.local/bin/uv run trigger_webhook.py &

# Test webhook
curl -X POST http://localhost:8001/gh-webhook -H "Content-Type: application/json" -H "X-GitHub-Event: issues" -d '{"action":"opened","issue":{"number":7,"body":"adw_plan_build_test"}}'

# View recent GitHub activity
gh issue list --repo tairea/tac-05 --limit 5

# Check git branches
cd /opt/adw && git branch -a | grep feature | tail -10
```

## Key Learnings from Debugging Sessions

### Session: Webhook Trigger Not Working (2024-12-22)

**Problem:** Webhook posted GitHub comment but workflow never started

**Root Cause:**
- Webhook process PATH didn't include `/opt/adw/.local/bin/`
- Subprocess calls to `uv run` failed silently with FileNotFoundError
- No error logging for subprocess launch failures

**Solution:**
- Use full path to uv: `uv_path = os.path.join(repo_root, ".local", "bin", "uv")`
- Added error logging around subprocess.Popen
- Updated all workflow scripts (adw_plan_build.py, adw_plan_build_test.py)

**Prevention:**
- Always use full paths in subprocess calls
- Add comprehensive error logging
- Test subprocess launches manually before deployment

## Additional Resources

- **Claude Code CLI Docs**: https://docs.anthropic.com/en/docs/claude-code
- **GitHub CLI Docs**: https://cli.github.com/manual/
- **uv Documentation**: https://docs.astral.sh/uv/
- **FastAPI Docs**: https://fastapi.tiangolo.com/

---

**Last Updated**: 2024-12-22
**Maintainer**: ADW Development Team
