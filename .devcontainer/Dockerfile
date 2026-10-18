# Spec + design notes for this image live in .devcontainer/container-structure-test.yaml.
# Ubuntu LTS, matching the host OS. Most tools come from its archive; gh and
# gitleaks, whose archive versions are too old, are fetched as pinned binaries below,
# and Ruby, which the archive doesn't carry at the version Gemfile.lock wants, is
# built from its pinned source tarball.
FROM ubuntu:26.04

# pipefail so `curl | tar` and friends fail loudly on a broken download.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
# ubuntu sets no locale, so Ruby would read files as US-ASCII and commonmarker
# and nokogiri reject the posts. The old ruby base image set this for us.
ENV LANG=C.UTF-8

ARG USER_UID=1000
ARG USER_GID=1000

# From the Ubuntu archive:
#   • nodejs/npm (Node 22): for Claude Code and bin/check-pages (Playwright, axe-core).
#   • python3: for the ad-hoc scripts Claude writes and runs.
#   • gosu: the entrypoint runs as root (for dockerd) and drops to vscode with it.
#   • docker.io & co.: for `start.sh --docker` only. dockerd is started by
#     /entrypoint.sh when ENABLE_DOCKER=1, which compose.docker.yml sets alongside
#     privileged mode; otherwise the binaries sit unused.
#   • No sudo, on purpose: root inside the container could undo the read-only
#     mounts and anything else meant to hold Claude in. Tools a project needs
#     go in here, at build time.
#   • build-essential and the -dev libraries: to build Ruby below, and for gems
#     with C extensions.
#   • bubblewrap/socat: what Claude Code's Linux sandbox (/sandbox) runs on.
#     They won't run on hosts that restrict unprivileged user namespaces (Ubuntu's
#     kernel.apparmor_restrict_unprivileged_userns=1), not even with --docker. The
#     container is the sandbox here; they're installed for hosts where that's lifted.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bubblewrap \
    build-essential \
    ca-certificates \
    curl \
    docker-buildx \
    docker-compose-v2 \
    docker.io \
    git \
    gosu \
    iptables \
    jq \
    less \
    libffi-dev \
    libssl-dev \
    libyaml-dev \
    nodejs \
    npm \
    openssh-client \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    socat \
    unzip \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI: authenticates from GH_TOKEN in the host's ~/.config/grantspeelman/grant-ps.com/gh.env.
ARG GH_VERSION=2.102.0
ENV GH_SHA256_AMD64=bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386
ENV GH_SHA256_ARM64=7862c86c72f43df3a2d93ddde6f473285b4e2af61b494849846827e513ef6484
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    case "${ARCH}" in \
      amd64) SHA256="${GH_SHA256_AMD64}" ;; \
      arm64) SHA256="${GH_SHA256_ARM64}" ;; \
      *) echo "Unsupported arch: ${ARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors \
      "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.tar.gz" \
      -o /tmp/gh.tar.gz; \
    echo "${SHA256}  /tmp/gh.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/gh.tar.gz -C /tmp "gh_${GH_VERSION}_linux_${ARCH}/bin/gh"; \
    install -m755 "/tmp/gh_${GH_VERSION}_linux_${ARCH}/bin/gh" /usr/local/bin/gh; \
    rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_${ARCH}"; \
    gh --version

# gitleaks: run by .githooks/pre-commit so secrets never reach a commit.
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

# Ruby: Gemfile.lock wants 4.0.7, which the Ubuntu archive doesn't carry. Built
# from the official source tarball into /usr/local, so vscode can run it. The
# checksum is the one published in https://cache.ruby-lang.org/pub/ruby/index.txt.
ARG RUBY_VERSION=4.0.7
ENV RUBY_SHA256=911ace20f90d068ca0e4dda6d0e4f0f81e52e52f2dd4f4004c721e253412e82d
RUN set -eux; \
    curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors \
      "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz" \
      -o /tmp/ruby.tar.gz; \
    echo "${RUBY_SHA256}  /tmp/ruby.tar.gz" | sha256sum -c -; \
    mkdir /tmp/ruby; \
    tar -xzf /tmp/ruby.tar.gz -C /tmp/ruby --strip-components=1; \
    cd /tmp/ruby; \
    ./configure --prefix=/usr/local --enable-shared --disable-install-doc; \
    make -j"$(nproc)"; \
    make install; \
    cd /; \
    rm -rf /tmp/ruby /tmp/ruby.tar.gz; \
    ruby --version

# Bundler at the version Gemfile.lock was bundled with. Installed as root here,
# because vscode can't write to /usr/local and Bundler would otherwise try to
# fetch it there on first `bundle install`.
ARG BUNDLER_VERSION=4.0.20
RUN gem install bundler -v "${BUNDLER_VERSION}" --no-document && bundle --version

# Chromium for bin/check-pages, at the Playwright version package-lock.json pins
# (bump both together). Root-owned and outside the checkout, so `npm ci` can't
# replace it; bin/setup skips its own browser download when this one is present.
ARG PLAYWRIGHT_VERSION=1.63.0
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN npx --yes "playwright@${PLAYWRIGHT_VERSION}" install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/* \
    && npm cache clean --force

# Claude Code floats to latest on purpose: a rebuild should give you the CLI
# Anthropic currently ships, not one frozen when the image was first built.
# Auto-update is off because the global npm prefix is root-owned; rebuild to upgrade.
# Ubuntu's npm 9 predates the package.json `libc` filter, so it also installs the
# musl (Alpine) build of the CLI alongside the glibc one; drop that dead weight.
# hadolint ignore=DL3016
RUN npm install -g @anthropic-ai/claude-code \
    && rm -rf /usr/local/lib/node_modules/@anthropic-ai/claude-code/node_modules/@anthropic-ai/claude-code-linux-*-musl \
    && npm cache clean --force
ENV DISABLE_AUTOUPDATER=1

# Git hooks come from the checkout's .githooks/ (gitleaks, then bin/precommit),
# which docker-compose.yml mounts read-only along with .git/hooks, so nothing in
# the container can change what host git later runs. Set system-wide as well as
# in .git/config (bin/setup), so commits are checked even in a fresh clone.
RUN git config --system core.hooksPath /workspace/.githooks && \
    # .git/config is read-only too, so `git push -u` can't record an upstream;
    # pushing to the same-named branch makes a plain `git push` work without one.
    git config --system push.default current

# Pin GitHub's SSH host keys (from https://api.github.com/meta) so the first
# `git push` neither prompts nor trusts whatever answers on port 22.
COPY .devcontainer/ssh_known_hosts /etc/ssh/ssh_known_hosts

# Create the `vscode` user with the host's UID/GID so bind-mounted files and the
# forwarded ssh-agent socket are owned by the same user on both sides. The
# ubuntu base image ships an `ubuntu` user at 1000:1000, which is renamed rather than duplicated.
RUN set -eux; \
    if [ "${USER_UID}" -eq 0 ] || [ "${USER_GID}" -eq 0 ]; then \
        echo "ERROR: USER_UID and USER_GID must not be 0 (got UID=${USER_UID} GID=${USER_GID})" >&2; \
        exit 1; \
    fi; \
    if getent group "${USER_GID}" > /dev/null; then \
        groupmod -n vscode "$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
        groupadd -g "${USER_GID}" vscode; \
    fi; \
    if getent passwd "${USER_UID}" > /dev/null; then \
        existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
        [ "${existing_user}" = vscode ] || usermod -l vscode "${existing_user}"; \
        usermod -d /home/vscode -m -s /bin/bash -g "${USER_GID}" vscode; \
    else \
        useradd -l -m -d /home/vscode -s /bin/bash -g "${USER_GID}" -u "${USER_UID}" vscode; \
    fi; \
    # docker group: only matters with start.sh --docker, where dockerd runs. Access
    # to it is root-equivalent, which is why that mode is not a boundary. -G, not
    # -aG: it also drops the groups the renamed `ubuntu` user had (sudo, adm, ...).
    usermod -G docker vscode

# Claude's config dir is a named volume (see docker-compose.yml) so the login
# survives rebuilds. Creating it here, vscode-owned, means Docker seeds a fresh
# volume with that ownership instead of root's.
ENV CLAUDE_CONFIG_DIR=/home/vscode/.claude
# Gems go in a named volume too (see docker-compose.yml), so a rebuild doesn't
# reinstall them; same vscode-owned seeding.
ENV BUNDLE_PATH=/home/vscode/.bundle
RUN mkdir -p /workspace "${CLAUDE_CONFIG_DIR}" "${BUNDLE_PATH}" && \
    chown vscode:vscode /workspace "${CLAUDE_CONFIG_DIR}" "${BUNDLE_PATH}"
WORKDIR /workspace

COPY .devcontainer/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
# The entrypoint starts as root (for optional dockerd) and gosu-drops to vscode itself.
# hadolint ignore=DL3002
USER root
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
