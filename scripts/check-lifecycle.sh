#!/usr/bin/env bash
# Checks Keel's install, activation, and removal lifecycle against a real Claude Code CLI.
# Uses a throwaway CLAUDE_CONFIG_DIR, so the caller's own configuration is untouched.
# Makes a few short model calls with the caller's existing Claude Code authentication.
#
# Usage: scripts/check-lifecycle.sh [marketplace-source]   (default: this checkout)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:-$REPO}"
CORE_MARK="Keel: engineering partner"
HOST_MARK="Keel host notes: Claude Code"

# Run as an independent session, not as a child of any session that launched this script.
unset CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_CHILD_SESSION

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/config"
mkdir -p "$CLAUDE_CONFIG_DIR" "$WORK/project"
cd "$WORK/project" && git init -q

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected $3, got $2)"; fi; }

transcript() { find "$CLAUDE_CONFIG_DIR/projects" -name "$1.jsonl" | head -n 1; }
count() { local n; n="$(grep -c "$1" "$(transcript "$2")" 2>/dev/null)"; echo "${n:-0}"; }
newest_session() { basename "$(ls -t "$CLAUDE_CONFIG_DIR"/projects/*/*.jsonl | head -n 1)" .jsonl; }
run() { claude -p "$@" --output-format json 2>/dev/null; }
session_of() { python3 -I -c 'import json,sys; print(json.load(sys.stdin)["session_id"])'; }

echo "Claude Code $(claude --version 2>/dev/null)"
echo "Core: $(wc -c < "$REPO/plugin/core.md") chars; Claude Code notes: $(wc -c < "$REPO/plugin/hosts/claude-code.md") chars (hook output cap: 10000 each)"

# Install
if claude plugin install keel --marketplace "$SOURCE" -y >/dev/null 2>&1; then pass "install from $SOURCE"; else fail "install from $SOURCE"; exit 1; fi

# Fresh session: core and host notes injected exactly once
SID="$(run "Reply with exactly: OK" | session_of)"
check "startup injects core once" "$(count "$CORE_MARK" "$SID")" 1
check "startup injects Claude Code notes once" "$(count "$HOST_MARK" "$SID")" 1

# The model can see it
reply="$(claude -p "If your context contains a section titled 'Keel: engineering partner', reply exactly YES. Otherwise reply exactly NO." 2>/dev/null)"
case "$reply" in *YES*) pass "model sees the core";; *) fail "model sees the core (replied: $reply)";; esac

# Resume: no duplicate injection
run --resume "$SID" "Reply with exactly: OK" >/dev/null
check "resume does not re-inject" "$(count "$CORE_MARK" "$SID")" 1

# Compaction: re-injected after the summary
claude -p --resume "$SID" "/compact" >/dev/null 2>&1
check "compaction re-injects" "$(count "$CORE_MARK" "$SID")" 2

# /clear: the new conversation gets the core
claude -p --resume "$SID" "/clear" >/dev/null 2>&1
CLEARED="$(newest_session)"
check "/clear injects core in new conversation" "$(count "$CORE_MARK" "$CLEARED")" 1

# Disable: fresh sessions are clean; a resumed old session keeps its transcript text
claude plugin disable keel@keel >/dev/null 2>&1 || fail "disable command"
OFF="$(run "Reply with exactly: OK" | session_of)"
check "disabled: fresh session has no core" "$(count "$CORE_MARK" "$OFF")" 0
run --resume "$SID" "Reply with exactly: OK" >/dev/null
check "disabled: resumed session keeps earlier core text, adds none" "$(count "$CORE_MARK" "$SID")" 2
claude plugin enable keel@keel >/dev/null 2>&1 || fail "re-enable command"

# Uninstall: no longer installed, data directory removed. Claude Code keeps the old cached
# version marked orphaned and deletes it later by design, so sessions already using it keep working.
claude plugin uninstall keel@keel >/dev/null 2>&1 || fail "uninstall command"
check "uninstall removes install record" "$(grep -c '"keel@keel"' "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json")" 0
data="$(find "$CLAUDE_CONFIG_DIR/plugins/data" -maxdepth 1 -name '*keel*' 2>/dev/null | head -n 1)"
check "uninstall leaves no plugin data" "${data:-none}" none
marked="$(find "$CLAUDE_CONFIG_DIR/plugins/cache" -path '*keel*' -name .orphaned_at 2>/dev/null | head -n 1)"
if [ -n "$marked" ]; then pass "uninstall marks cached copy for cleanup"; else fail "uninstall marks cached copy for cleanup"; fi
GONE="$(run "Reply with exactly: OK" | session_of)"
check "uninstalled: fresh session has no core" "$(count "$CORE_MARK" "$GONE")" 0

# Hook failure: a broken copy must not break the session
BROKEN="$WORK/broken"
cp -R "$REPO/plugin" "$BROKEN" && rm "$BROKEN/core.md"
if out="$(claude -p --plugin-dir "$BROKEN" "Reply with exactly: OK" 2>/dev/null)" && [[ "$out" == *OK* ]]; then
  pass "missing core file: session still works"
else
  fail "missing core file: session still works"
fi

echo
if [ "$failures" -eq 0 ]; then echo "All lifecycle checks passed."; else echo "$failures lifecycle check(s) failed."; fi
exit "$failures"
