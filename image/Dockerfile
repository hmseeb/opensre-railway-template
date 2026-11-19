# OpenSRE gateway for Railway.
#
# Upstream's Dockerfile (Tracer-Cloud/opensre, main) ships the toolchain plus a
# supervisor that downloads the rolling main-channel binary on every start.
# That download is not on a volume, so each Railway restart re-fetches it and
# the deployed version drifts with upstream main. This image keeps upstream's
# toolchain verbatim and bakes ONE pinned release binary at build time instead:
# reproducible, no runtime dependency on install.opensre.com, fast boot.

FROM python:3.12-slim

WORKDIR /workspace

# Same tool list as upstream: coding agents and tool calls shell out to these.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash build-essential ca-certificates curl git jq less openssh-client \
        procps ripgrep unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI + Node + Codex CLI, pinned and checksum-verified, as upstream.
ARG GH_VERSION=2.103.3
ARG NODE_VERSION=22.23.4
ARG CODEX_VERSION=0.156.1
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) exit 1 ;; esac; \
    cd /tmp; \
    gh_deb="gh_${GH_VERSION}_linux_${arch}.deb"; \
    curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${gh_deb}"; \
    curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt"; \
    grep " ${gh_deb}$" "gh_${GH_VERSION}_checksums.txt" | sha256sum -c -; \
    dpkg -i "${gh_deb}"; \
    node_tar="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${node_tar}"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"; \
    grep " ${node_tar}$" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "${node_tar}" -C /usr/local --strip-components=1 --no-same-owner; \
    npm install -g "@openai/codex@${CODEX_VERSION}"; \
    rm -rf /tmp/* /root/.npm

RUN groupadd --gid 1000 opensre \
    && useradd --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin opensre \
    && mkdir -p /workspace/scratch /home/opensre/.local/bin \
    && chown -R opensre:opensre /workspace /home/opensre

# The pinned release. Bump this (and the workflow tag) to upgrade.
ARG OPENSRE_VERSION=0.1.2026.11.19
RUN su opensre -s /bin/bash -c "OPENSRE_AUTO_LAUNCH=0 OPENSRE_SKIP_GH_INSTALL=1 \
      curl -fsSL https://install.opensre.com | bash -s -- --version ${OPENSRE_VERSION} --install-dir /home/opensre/.local/bin" \
    && /home/opensre/.local/bin/opensre --version | grep -F "${OPENSRE_VERSION}"

COPY entrypoint.sh /usr/local/bin/opensre-railway-entrypoint
RUN chmod 0755 /usr/local/bin/opensre-railway-entrypoint

ENV PORT=8000 \
    HOME=/home/opensre \
    PATH=/home/opensre/.local/bin:$PATH \
    CODING_AGENT_SANDBOX=host \
    OPENSRE_AUTO_LAUNCH=0 \
    OPENSRE_SKIP_GH_INSTALL=1 \
    OPENSRE_DEPLOYMENT_METHOD=railway \
    OPENSRE_HOME=/data/opensre

EXPOSE 8000

# Starts as root only to hand the Railway volume (root-owned) to uid 1000,
# then drops privileges. See entrypoint.sh.
CMD ["/usr/local/bin/opensre-railway-entrypoint"]
