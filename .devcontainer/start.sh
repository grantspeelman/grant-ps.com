#!/usr/bin/env bash
# Opens an interactive bash shell in the sandbox (run `claude` yourself).
# For the long-lived Claude session, use bin/sandbox instead.
# If no ssh-agent is running, starts one for this session, loads your default
# key (ssh-add may ask for its passphrase) and stops the agent on exit.
set -euo pipefail

SANDBOX="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/sandbox"

if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)" >/dev/null
  trap 'ssh-agent -k >/dev/null' EXIT
  ssh-add || echo "Warning: no key loaded; git over SSH won't work in this shell." >&2
fi

"$SANDBOX" shell
