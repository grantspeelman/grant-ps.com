FROM ruby:4.0.7-slim-bookworm

ARG NODE_MAJOR=22

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      openssh-client \
      curl \
      ca-certificates \
      gnupg \
      build-essential \
      gosu \
      bubblewrap \
      socat \
    && install -d -m 0755 /usr/share/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get update && apt-get install -y --no-install-recommends gh nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code playwright

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
ENV NODE_PATH=/usr/lib/node_modules
RUN npx playwright install --with-deps chromium

# gitleaks: run by .githooks/pre-commit so secrets never reach a commit, and by CI over full history.
ARG GITLEAKS_VERSION=8.30.1
ENV GITLEAKS_SHA256_AMD64=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
ENV GITLEAKS_SHA256_ARM64=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) GITLEAKS_ARCH=x64;   SHA256="${GITLEAKS_SHA256_AMD64}" ;; \
      arm64) GITLEAKS_ARCH=arm64; SHA256="${GITLEAKS_SHA256_ARM64}" ;; \
      *) echo "Unsupported arch: $(dpkg --print-architecture)"; exit 1 ;; \
    esac; \
    curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors \
      "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz" \
      -o /tmp/gitleaks.tar.gz; \
    echo "${SHA256}  /tmp/gitleaks.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks; \
    rm /tmp/gitleaks.tar.gz; \
    gitleaks version

# Pin GitHub's SSH host keys (from https://api.github.com/meta) so the first
# `git push` neither prompts nor trusts whatever answers on port 22.
COPY ssh_known_hosts /etc/ssh/ssh_known_hosts

RUN useradd --create-home --home-dir /home/sandbox --shell /bin/bash sandbox

ENV HOME=/home/sandbox
WORKDIR /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions", "--remote-control"]
