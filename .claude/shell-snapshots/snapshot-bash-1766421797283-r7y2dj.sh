# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
shopt -s expand_aliases
# Check for rg availability
if ! command -v rg >/dev/null 2>&1; then
  alias rg='/opt/adw/.local/share/claude/versions/2.0.75 --ripgrep'
fi
export PATH=/opt/adw/.cache/uv/environments-v2/adw-build-17173fc5a51f2413/bin\:/opt/adw/.cache/uv/environments-v2/adw-plan-build-test-3de362a7d524175c/bin\:/opt/adw/.cache/uv/environments-v2/trigger-webhook-092622c3f6c6e7c3/bin\:/root/.cargo/bin\:/root/.local/bin\:/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin
