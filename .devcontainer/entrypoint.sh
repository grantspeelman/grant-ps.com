#!/bin/bash
set -euo pipefail

USER_UID="${SANDBOX_UID:-1000}"
USER_GID="${SANDBOX_GID:-1000}"

groupmod -o -g "$USER_GID" sandbox
usermod -o -u "$USER_UID" sandbox

for dir in /home/sandbox/.claude /home/sandbox/.cache; do
  mkdir -p "$dir"
  chown -R sandbox:sandbox "$dir"
done

exec gosu sandbox "$@"
