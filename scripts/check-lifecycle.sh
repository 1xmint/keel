#!/usr/bin/env bash
# Checks Keel's install, activation, and removal lifecycle against a real Claude Code CLI.
# Uses a throwaway CLAUDE_CONFIG_DIR, so the caller's own configuration is untouched.
# Makes a few short model calls with the caller's existing Claude Code authentication.
# Every step must observably succeed; a missing session, transcript, or failed command is a FAIL.
#
# Usage: scripts/check-lifecycle.sh [marketplace-source]   (default: this checkout)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:-$REPO}"
CORE_MARK="Keel: engineering partner"
HOST_MARK="Keel host notes: Claude Code"

for tool in claude python3 git; do
  command -v "$tool" >/dev/null || { echo "FAIL  required command not found: $tool"; exit 1; }
done

# Run as an independent session, not as a child of any session that launched this script.
unset CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_CHILD_SESSION

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/config"
mkdir -p "$CLAUDE_CONFIG_DIR" "$WORK/project"
cd "$WORK/project" && git init -q

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2" | head -n 5; failures=$((failures + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected $3, got $2)"; fi; }

# Run a command; on failure record it with its output. Usage: step "label" cmd args...
step() {
  local label="$1" out; shift
  if out="$("$@" 2>&1)"; then return 0; fi
  fail "$label" "$out"; return 1
}

# Start or resume a headless session and print its session id. It runs inside command
# substitution, so its diagnostics go to stderr; the empty id then fails every check that uses it.
run_session() {
  local label="$1" out sid; shift
  if ! out="$(claude -p "$@" --output-format json 2>&1)"; then fail "$label: claude exited non-zero" "$out" >&2; return 1; fi
  sid="$(printf '%s' "$out" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
if d.get("is_error") or not d.get("session_id"):
    sys.exit(1)
print(d["session_id"])' 2>/dev/null)" || { fail "$label: no successful session result" "$out" >&2; return 1; }
  printf '%s' "$sid"
}

transcripts() { find "$CLAUDE_CONFIG_DIR/projects" -name '*.jsonl' 2>/dev/null | sort; }

# Occurrences of a marker in one session's transcript, or "missing" if the transcript is absent or ambiguous.
count() {
  local files n
  [ -n "$2" ] || { echo missing; return; }
  files="$(find "$CLAUDE_CONFIG_DIR/projects" -name "$2.jsonl" 2>/dev/null)"
  [ "$(printf '%s' "$files" | grep -c .)" = 1 ] || { echo missing; return; }
  n="$(grep -c -- "$1" "$files")"
  echo "${n:-0}"
}

echo "Claude Code $(claude --version 2>/dev/null)"
echo "Core: $(wc -c < "$REPO/plugin/core.md") chars; Claude Code notes: $(wc -c < "$REPO/plugin/hosts/claude-code.md") chars (hook output cap: 10000 each)"

# Install
if step "install from $SOURCE" claude plugin install keel --marketplace "$SOURCE" -y; then
  pass "install from $SOURCE"
else
  echo "Cannot continue without an installed plugin."; exit 1
fi

# Fresh session: core and host notes injected exactly once
SID="$(run_session "startup session" "Reply with exactly: OK")"
check "startup injects core once" "$(count "$CORE_MARK" "$SID")" 1
check "startup injects Claude Code notes once" "$(count "$HOST_MARK" "$SID")" 1

# The model can see it
if reply="$(claude -p "If your context contains a section titled 'Keel: engineering partner', reply exactly YES. Otherwise reply exactly NO." 2>&1)"; then
  case "$reply" in *YES*) pass "model sees the core";; *) fail "model sees the core" "$reply";; esac
else
  fail "model sees the core: claude exited non-zero" "$reply"
fi

# Resume: no duplicate injection
run_session "resume session" --resume "$SID" "Reply with exactly: OK" >/dev/null
check "resume does not re-inject" "$(count "$CORE_MARK" "$SID")" 1

# Compaction: re-injected after the summary
step "/compact command" claude -p --resume "$SID" "/compact" && pass "/compact command"
check "compaction re-injects" "$(count "$CORE_MARK" "$SID")" 2

# /clear: exactly one new conversation, which gets the core
before="$(transcripts)"
step "/clear command" claude -p --resume "$SID" "/clear" && pass "/clear command"
new="$(comm -13 <(printf '%s\n' "$before") <(transcripts) | grep .)"
if [ "$(printf '%s' "$new" | grep -c .)" = 1 ]; then
  check "/clear injects core in new conversation" "$(count "$CORE_MARK" "$(basename "$new" .jsonl)")" 1
else
  fail "/clear creates exactly one new conversation" "new transcripts: ${new:-none}"
fi

# Disable: fresh sessions are clean; a resumed old session keeps its transcript text
step "disable command" claude plugin disable keel@keel && pass "disable command"
OFF="$(run_session "disabled fresh session" "Reply with exactly: OK")"
check "disabled: fresh session has no core" "$(count "$CORE_MARK" "$OFF")" 0
run_session "disabled resumed session" --resume "$SID" "Reply with exactly: OK" >/dev/null
check "disabled: resumed session keeps earlier core text, adds none" "$(count "$CORE_MARK" "$SID")" 2
step "re-enable command" claude plugin enable keel@keel && pass "re-enable command"

# Uninstall: no longer installed, data directory removed. Claude Code keeps the old cached
# version marked orphaned and deletes it later by design, so sessions already using it keep working.
step "uninstall command" claude plugin uninstall keel@keel && pass "uninstall command"
record="$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
if [ -f "$record" ]; then
  check "uninstall removes install record" "$(grep -c '"keel@keel"' "$record")" 0
else
  fail "uninstall removes install record" "$record not found"
fi
data="$(find "$CLAUDE_CONFIG_DIR/plugins/data" -maxdepth 1 -name '*keel*' 2>/dev/null | head -n 1)"
check "uninstall leaves no plugin data" "${data:-none}" none
marked="$(find "$CLAUDE_CONFIG_DIR/plugins/cache" -path '*keel*' -name .orphaned_at 2>/dev/null | head -n 1)"
if [ -n "$marked" ]; then pass "uninstall marks cached copy for cleanup"; else fail "uninstall marks cached copy for cleanup"; fi
GONE="$(run_session "uninstalled fresh session" "Reply with exactly: OK")"
check "uninstalled: fresh session has no core" "$(count "$CORE_MARK" "$GONE")" 0

# Hook failure: a missing core file is reported as a hook error, the host notes still load,
# and the session still answers.
BROKEN="$WORK/broken"
cp -R "$REPO/plugin" "$BROKEN" && rm "$BROKEN/core.md"
if events="$(claude -p --plugin-dir "$BROKEN" "Reply with exactly: OK" --output-format stream-json --verbose 2>&1)"; then
  verdict="$(printf '%s\n' "$events" | python3 -I -c '
import json, sys
core_error = notes_ok = answered = False
for line in sys.stdin:
    try:
        d = json.loads(line)
    except ValueError:
        continue
    if d.get("subtype") == "hook_response" and d.get("hook_event") == "SessionStart":
        if d.get("outcome") == "error" and d.get("exit_code") not in (0, None) and "core.md" in d.get("stderr", ""):
            core_error = True
        if d.get("outcome") == "success" and "Keel host notes" in d.get("stdout", ""):
            notes_ok = True
    if d.get("type") == "result" and not d.get("is_error") and "OK" in (d.get("result") or ""):
        answered = True
print(f"{core_error} {notes_ok} {answered}")')"
  read -r core_error notes_ok answered <<<"$verdict"
  check "missing core file: reported as SessionStart hook error" "$core_error" True
  check "missing core file: Claude Code notes still load" "$notes_ok" True
  check "missing core file: session still answers" "$answered" True
else
  fail "missing core file: claude exited non-zero" "$events"
fi

echo
if [ "$failures" -eq 0 ]; then echo "All lifecycle checks passed."; else echo "$failures lifecycle check(s) failed."; fi
[ "$failures" -eq 0 ]
