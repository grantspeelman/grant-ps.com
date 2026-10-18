#!/usr/bin/env bash
# Runs as vscode on every container start, from both VS Code and start.sh.
# Everything here is idempotent: the Claude config dir is a volume that
# outlives containers, so this script meets its own earlier output.
set -euo pipefail

config_dir="${CLAUDE_CONFIG_DIR:?CLAUDE_CONFIG_DIR is set in the Dockerfile}"

# Permission prompts off by default. This is the container's own Claude config,
# so the host's settings are untouched. Only the one key is set, leaving any
# other settings you have added in the volume alone.
settings="${config_dir}/settings.json"
[ -s "${settings}" ] || echo '{}' > "${settings}"
jq '.permissions.defaultMode = "bypassPermissions"' "${settings}" > "${settings}.tmp"
mv "${settings}.tmp" "${settings}"

# Project dependencies, skipped when nothing changed since the last install: the
# hash covers the lockfile and the runtime version. Gems live in the bundle
# volume and node_modules in the checkout, so each stamp sits beside what it
# describes and goes away with it.
cd /workspace
install_if_changed() { # <stamp> <lockfile> <runtime> <command...>
  local stamp="$1" lock="$2" runtime="$3" hash
  shift 3
  hash="$({ cat "${lock}"; "${runtime}" --version; } | sha256sum | cut -d ' ' -f 1)"
  if [ "$(cat "${stamp}" 2>/dev/null)" != "${hash}" ]; then
    "$@"
    echo "${hash}" > "${stamp}"
  fi
}
install_if_changed "${BUNDLE_PATH}/.installed.sha256" Gemfile.lock ruby \
  bundle install --quiet
install_if_changed node_modules/.installed.sha256 package-lock.json node \
  npm ci --no-fund --no-audit --loglevel=error

# Status, so a missing credential shows up now rather than mid-task.
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
  echo "No SSH agent forwarded: git push over SSH will not work."
else
  agent_status=0
  ssh-add -l >/dev/null 2>&1 || agent_status=$?
  case "${agent_status}" in
    0) ;;
    1) echo "SSH agent reachable but holds no keys: run 'ssh-add' on the host." ;;
    *) echo "SSH agent socket is dead (host agent restarted?): run .devcontainer/start.sh --rebuild." ;;
  esac
fi

if [ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
  echo "Neither GH_TOKEN nor GITHUB_TOKEN is set: gh (PRs, issues) is unauthenticated. Put GH_TOKEN=... in ~/.config/grantspeelman/grant-ps.com/gh.env on the host and rerun start.sh."
fi

if [ ! -s "${config_dir}/.credentials.json" ]; then
  echo "Claude is not logged in yet: run 'claude' and log in once; the login persists across rebuilds."
fi
