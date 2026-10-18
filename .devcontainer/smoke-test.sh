#!/bin/bash
# End-to-end check of the dev container through the same compose files start.sh
# uses: builds for the calling user's UID, forwards a throwaway ssh-agent, runs
# the post-start setup, then exercises nested Docker and dropping back out of it.
# Runs in CI (.github/workflows/devcontainer-ci.yml) and locally alike. It uses
# its own compose project, a throwaway Claude config volume (never your real
# login's) and a temporary key in a fresh agent, and removes them all on exit.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT="grant-ps-com-smoke-$$"
BASE=(docker compose -p "$PROJECT"
    -f "$SCRIPT_DIR/docker-compose.yml"
    -f "$SCRIPT_DIR/compose.ssh.yml"
    -f "$SCRIPT_DIR/smoke-test.compose.yml")
DOCKER=("${BASE[@]}" -f "$SCRIPT_DIR/compose.docker.yml")
in_container() { "${DOCKER[@]}" exec -T --user vscode app bash -c "$1"; }

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok - $*"; }

tmp="$(mktemp -d)"
cleanup() {
    "${DOCKER[@]}" down --volumes --remove-orphans >/dev/null 2>&1 || true
    [ -n "${SSH_AGENT_PID:-}" ] && kill "$SSH_AGENT_PID" 2>/dev/null || true
    rm -rf "$tmp"
}
trap cleanup EXIT

# A fresh agent holding a throwaway key: never the caller's own agent or keys.
eval "$(ssh-agent -a "$tmp/agent.sock")" >/dev/null
ssh-keygen -q -t ed25519 -N '' -f "$tmp/key"
ssh-add -q "$tmp/key"
export HOST_SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
export USER_UID="$(id -u)" USER_GID="$(id -g)"
export SMOKE_CLAUDE_VOLUME="$PROJECT-claude-config"

echo "# privileged, with nested Docker"
"${DOCKER[@]}" up --detach --build --quiet-pull
timeout=90
until "${DOCKER[@]}" exec -T app docker info >/dev/null 2>&1; do
    timeout=$((timeout - 1))
    [ "$timeout" -gt 0 ] || { "${DOCKER[@]}" logs --tail 40 app >&2; fail "dockerd did not start"; }
    sleep 1
done
pass "dockerd started"

in_container '.devcontainer/postStartCommand.sh' >/dev/null
pass "postStartCommand.sh ran"

[ "$(in_container 'id -u')" = "$USER_UID" ] || fail "vscode UID does not match host UID $USER_UID"
pass "vscode runs as host UID $USER_UID"

[ "$(in_container 'ssh-add -l | wc -l')" = 1 ] || fail "forwarded agent does not hold the test key"
pass "ssh-agent forwarded"

[ "$(in_container 'jq -r .permissions.defaultMode "$CLAUDE_CONFIG_DIR/settings.json"')" = bypassPermissions ] \
    || fail "bypassPermissions not set"
pass "Claude defaults to bypassPermissions"

# The repo's own checks, on the gems and node_modules postStartCommand.sh installed.
in_container 'bundle exec rake test && bin/guard --all && bin/meta --check' >/dev/null \
    || fail "rake test, bin/guard --all or bin/meta --check failed"
pass "rake test, bin/guard --all, bin/meta --check"

in_container 'node -e "require(\"playwright\").chromium.launch().then(b => b.close())"' \
    || fail "Playwright can't launch the image's Chromium (bin/check-pages)"
pass "Playwright launches Chromium"

# .githooks from .git/config (bin/setup) or, in a fresh clone, from /etc/gitconfig.
case "$(in_container 'git -C /workspace config core.hooksPath')" in
    .githooks|/workspace/.githooks) ;;
    *) fail "git does not use .githooks/" ;;
esac
pass "git uses .githooks/"

# A scratch repo picks up the image's core.hooksPath. gitleaks runs first and must
# be what stops the commit, before .githooks/pre-commit reaches bin/precommit.
in_container '
    set -e; git init -q /tmp/t; cd /tmp/t
    git config user.email smoke@example.com; git config user.name smoke
    printf "token = \"ghp_%s\"\n" "$(head -c 300 /dev/urandom | tr -dc A-Za-z0-9 | head -c 36)" > leak.txt
    git add leak.txt; ! out=$(git commit -qm leak 2>&1); echo "$out" | grep -q "leaks found"' \
    || fail "gitleaks hook let a token through"
pass "gitleaks hook blocks a token"

in_container 'docker run --rm --quiet hello-world' | grep -q 'Hello from Docker!' || fail "nested docker run failed"
pass "nested docker run works"

echo "# back to unprivileged"
"${BASE[@]}" up --detach
[ "$(docker inspect "$("${BASE[@]}" ps -q app)" --format '{{.HostConfig.Privileged}}')" = false ] \
    || fail "container still privileged without compose.docker.yml"
pass "container recreated unprivileged"
"${BASE[@]}" exec -T --user vscode app bash -c '! docker info >/dev/null 2>&1' || fail "dockerd running while unprivileged"
pass "no dockerd while unprivileged"

echo "# read-only paths, unprivileged"
in_unprivileged() { "${BASE[@]}" exec -T --user "$1" app bash -c "$2"; }
in_unprivileged vscode '! command -v sudo' >/dev/null || fail "sudo is installed"
pass "no sudo"
for path in .git/config .git/hooks/smoke-plant .githooks/pre-commit .githooks/smoke-plant; do
    in_unprivileged vscode "! touch /workspace/$path 2>/dev/null" || fail "/workspace/$path is writable"
done
pass "host-executed paths are read-only"
in_unprivileged vscode '! git -C /workspace config core.fsmonitor "touch /tmp/pwned" 2>/dev/null' \
    || fail "git config could be changed"
pass "git config can't be changed"
in_unprivileged root 'command -v mount' >/dev/null || fail "no mount binary to test remounting with"
for path in .git/hooks .git/config .githooks; do
    in_unprivileged root "! mount -o remount,rw,bind /workspace/$path 2>/dev/null" \
        || fail "root could remount /workspace/$path read-write"
done
pass "even root can't remount them read-write"

echo "all smoke tests passed"
