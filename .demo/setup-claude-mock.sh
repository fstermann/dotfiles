#!/usr/bin/env bash
# Idempotent setup for the demo: makes sure `claude` is installed and
# starts the local Anthropic-API stub used by the demo recording.
#
# After this:
#   - claude       is on PATH
#   - mock server  is serving on http://127.0.0.1:${MOCK_PORT}
#   - demo.tape    will export ANTHROPIC_BASE_URL pointing here
set -euo pipefail

MOCK_PORT="${MOCK_PORT:-8787}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_HOME="${DEMO_HOME:-/tmp/dotfiles-claude-demo-home}"

log() { printf '\e[36m▸\e[0m %s\n' "$*" >&2; }

# ─── claude code ───────────────────────────────────────────────────────
if ! command -v claude >/dev/null 2>&1; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "error: npm not on PATH (needed to install @anthropic-ai/claude-code)" >&2
    exit 1
  fi
  log "Installing @anthropic-ai/claude-code"
  npm install -g @anthropic-ai/claude-code
fi

# ─── mock server ───────────────────────────────────────────────────────
if curl -sf "http://127.0.0.1:${MOCK_PORT}/" >/dev/null 2>&1; then
  log "Mock anthropic already running on :${MOCK_PORT}"
else
  log "Starting mock anthropic on :${MOCK_PORT}"
  nohup python3 "$SCRIPT_DIR/mock-anthropic.py" "$MOCK_PORT" \
      >/tmp/mock-anthropic.log 2>&1 &
  for _ in $(seq 1 20); do
    sleep 0.2
    curl -sf "http://127.0.0.1:${MOCK_PORT}/" >/dev/null 2>&1 && break
  done
  curl -sf "http://127.0.0.1:${MOCK_PORT}/" >/dev/null 2>&1 \
      || { echo "mock server failed to start (see /tmp/mock-anthropic.log)" >&2; exit 1; }
fi

# ─── isolated $HOME for claude (pre-onboarded, pre-approved API key, ──
#     workspace already trusted) ────────────────────────────────────────
mkdir -p "$DEMO_HOME"

# Trust every plausible repo path so the workspace prompt never shows up,
# regardless of where the demo recording is launched from (local checkout,
# stowed `~/.dotfiles`, GitHub Actions runner workspace, custom dir).
trust_paths=("$HOME/.dotfiles" "$PWD")
[[ -n "${DOTFILES_DIR:-}" ]]      && trust_paths+=("$DOTFILES_DIR")
[[ -n "${GITHUB_WORKSPACE:-}" ]]  && trust_paths+=("$GITHUB_WORKSPACE")

projects_json=$(printf '%s\n' "${trust_paths[@]}" | sort -u | jq -R . | jq -s '
  map({(.): {
    hasTrustDialogAccepted: true,
    projectOnboardingSeenCount: 5,
    hasClaudeMdExternalIncludesApproved: true,
    hasClaudeMdExternalIncludesWarningShown: true,
    allowedTools: [],
    mcpContextUris: [],
    mcpServers: {},
    enabledMcpjsonServers: [],
    disabledMcpjsonServers: []
  }}) | add
')

jq -n --argjson projects "$projects_json" '{
  hasCompletedOnboarding: true,
  hasIdeOnboardingBeenShown: true,
  customApiKeyResponses: { approved: ["demo"], rejected: [] },
  firstStartTime: "2024-01-01T00:00:00.000Z",
  userID: "demo-user",
  oauthAccount: {
    accountUuid: "demo",
    emailAddress: "demo@example.com",
    organizationUuid: "demo-org",
    organizationRole: "user"
  },
  autoUpdates: false,
  btwUseCount: 999,
  projects: $projects
}' > "$DEMO_HOME/.claude.json"

# Wire up the user's oh-my-posh config (so palette edits flow through) and
# write a thin statusline wrapper that overlays "as if I'd been working all
# day" usage data onto the real JSON before piping to oh-my-posh.
mkdir -p "$DEMO_HOME/.claude" "$DEMO_HOME/.config/zsh"
ln -sfn "$HOME/.config/zsh/oh-my-posh" "$DEMO_HOME/.config/zsh/oh-my-posh"

# Defensive: a previous version of this script created the statusline path
# as a symlink to the user's real script. `cat >` follows symlinks and would
# clobber the original. Always remove first so we write a fresh regular file.
rm -f "$DEMO_HOME/.claude/statusline-command.sh" "$DEMO_HOME/.claude/settings.json"

cat > "$DEMO_HOME/.claude/statusline-command.sh" <<'SH'
#!/bin/zsh
# Demo wrapper — overlays sample cost / line / context values on top of the
# JSON Claude Code sends, so the rate-limit and session pills look populated
# in the recording even though we're running against a stub API.
input=$(cat)
now=$(date +%s)
input=$(echo "$input" | jq --argjson now "$now" '
  .cost.total_cost_usd            = 8.99      |
  .cost.total_lines_added         = 1001      |
  .cost.total_lines_removed       = 180       |
  .cost.total_duration_ms         = 1842000   |
  .context_window.used_percentage = 18        |
  .rate_limits = {
    five_hour: { used_percentage: 64, resets_at: ($now + 14400)  },
    seven_day: { used_percentage: 26, resets_at: ($now + 172800) }
  }
')
export CLAUDE_EFFORT=medium
echo "$input" | oh-my-posh claude --config "$HOME/.config/zsh/oh-my-posh/pure.claude.toml"
SH
chmod +x "$DEMO_HOME/.claude/statusline-command.sh"

cat > "$DEMO_HOME/.claude/settings.json" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "zsh $DEMO_HOME/.claude/statusline-command.sh",
    "padding": 0
  }
}
EOF

# Shell snippet sourced by demo.tape so the typed `claude` invocation uses
# the demo HOME without VHS having to type a multi-statement function.
cat > /tmp/dotfiles-demo-shellrc.zsh <<EOF
claude() { HOME='${DEMO_HOME}' command claude "\$@" }
EOF

log "Ready — HOME=${DEMO_HOME} ANTHROPIC_BASE_URL=http://127.0.0.1:${MOCK_PORT} ANTHROPIC_API_KEY=demo claude"
