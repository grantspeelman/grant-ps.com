#!/usr/bin/env bash
# Builds the sandbox image and checks it can do this repo's job: remap to the
# host UID, run the unit tests, and block a committed secret. Needs only Docker.
# Usage: .devcontainer/smoke-test.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="grant-ps-blog-smoke:$$"
pass() { echo "ok: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
trap 'docker rmi -f "$IMAGE" >/dev/null 2>&1 || true' EXIT

docker build --quiet --network=host -t "$IMAGE" "$REPO_ROOT/.devcontainer" >/dev/null
pass "image builds"

# Same shape as bin/sandbox, minus the long-lived session. The checkout is
# mounted read-write; tests only write under tmp/.
in_container() {
  docker run --rm --network host \
    -e SANDBOX_UID="$(id -u)" -e SANDBOX_GID="$(id -g)" \
    -e BUNDLE_PATH=/home/sandbox/.cache/bundle \
    -v "$REPO_ROOT:/workspace" -w /workspace \
    "$IMAGE" bash -c "$1"
}

[ "$(in_container 'id -u' | tail -n1)" = "$(id -u)" ] || fail "sandbox UID does not match host UID"
pass "sandbox runs as host UID"

# One container, because gems install under the container's own ~/.cache.
in_container 'bundle install --quiet && bundle exec rake test && bin/guard --all && bin/meta --check' >/dev/null \
  || fail "bundle install, rake test, bin/guard --all or bin/meta --check failed"
pass "bundle install, rake test, bin/guard --all, bin/meta --check"

in_container '
  set -e; git init -q /tmp/t; cd /tmp/t
  git config user.email smoke@example.com; git config user.name smoke
  git config core.hooksPath /workspace/.githooks
  printf "token = \"ghp_%s\"\n" "$(head -c 300 /dev/urandom | tr -dc A-Za-z0-9 | head -c 36)" > leak.txt
  git add leak.txt; ! out=$(git commit -qm leak 2>&1); echo "$out" | grep -q "leaks found"' || fail "pre-commit hook let a token through"
pass "pre-commit hook blocks a token"

echo "all smoke tests passed"
