# Optimized multi-stage build using Alpine Linux for minimal size
FROM alpine:3.22 AS base

# Version pinning for reproducible builds
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION="v1.33.3"
# renovate: datasource=github-releases depName=kubevirt/kubevirt  
ARG VIRTCTL_VERSION="v1.5.0"
# renovate: datasource=github-releases depName=nats-io/natscli
ARG NATSCLI_VERSION="0.2.4"
# renovate: datasource=github-releases depName=nats-io/nsc
ARG NSC_VERSION="2.11.0"
# renovate: datasource=github-releases depName=rclone/rclone
ARG RCLONE_VERSION="v1.70.3"

# Build info
ARG BUILD_DATE
ARG BUILD_VERSION
LABEL build_date=$BUILD_DATE
LABEL version=$BUILD_VERSION

# Stage 1: Install all dependencies in one layer
FROM base AS builder

# Install all packages and tools in a single RUN command for better caching
RUN --mount=type=cache,target=/var/cache/apk \
    set -ex \
    && apk add --no-cache \
        # Basic tools
        curl \
        wget \
        ca-certificates \
        # Build tools  
        unzip \
        tar \
        jq \
        # Network tools
        openssh-client \
        netcat-openbsd \
        # System tools
        vim \
        bash \
        # Node.js and npm
        nodejs \
        npm \
        # PostgreSQL client
        postgresql17-client \
        # Git for npm packages
        git \
    && ARCH=$(uname -m) \
    && case "${ARCH}" in \
        x86_64) TOOL_ARCH=amd64 ;; \
        aarch64) TOOL_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac \
    && mkdir -p /opt/binaries \
    # Download all binaries
    && echo "Downloading kubectl..." \
    && curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TOOL_ARCH}/kubectl" -o /opt/binaries/kubectl \
    && chmod +x /opt/binaries/kubectl \
    && echo "Downloading virtctl..." \
    && curl -L "https://github.com/kubevirt/kubevirt/releases/download/${VIRTCTL_VERSION}/virtctl-${VIRTCTL_VERSION}-linux-${TOOL_ARCH}" -o /opt/binaries/virtctl \
    && chmod +x /opt/binaries/virtctl \
    && echo "Downloading mc..." \
    && curl -L "https://dl.min.io/client/mc/release/linux-${TOOL_ARCH}/mc" -o /opt/binaries/mc \
    && chmod +x /opt/binaries/mc \
    && echo "Downloading rclone..." \
    && curl -L "https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-${TOOL_ARCH}.zip" -o /tmp/rclone.zip \
    && unzip -q /tmp/rclone.zip -d /tmp \
    && mv /tmp/rclone-*-linux-${TOOL_ARCH}/rclone /opt/binaries/ \
    && chmod +x /opt/binaries/rclone \
    && echo "Downloading nats..." \
    && curl -L "https://github.com/nats-io/natscli/releases/download/v${NATSCLI_VERSION}/nats-${NATSCLI_VERSION}-linux-${TOOL_ARCH}.zip" -o /tmp/nats.zip \
    && unzip -q /tmp/nats.zip -d /tmp \
    && mv /tmp/nats-*/nats /opt/binaries/ \
    && chmod +x /opt/binaries/nats \
    && echo "Downloading nsc..." \
    && curl -L "https://github.com/nats-io/nsc/releases/download/v${NSC_VERSION}/nsc-linux-${TOOL_ARCH}.zip" -o /tmp/nsc.zip \
    && unzip -q /tmp/nsc.zip -d /tmp \
    && mv /tmp/nsc /opt/binaries/ \
    && chmod +x /opt/binaries/nsc \
    # Install Claude CLI globally
    && npm install -g @anthropic-ai/claude-code \
    # Clean up
    && rm -rf /tmp/* /root/.npm

# Stage 2: Final minimal runtime image
FROM alpine:3.22 AS runtime

# Install only runtime dependencies
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        netcat-openbsd \
        nodejs \
        openssh-client \
        postgresql17-client \
        vim \
        wget

# Copy binaries from builder
COPY --from=builder /opt/binaries/* /usr/local/bin/
COPY --from=builder /usr/local/lib/node_modules/@anthropic-ai/claude-code /usr/local/lib/node_modules/@anthropic-ai/claude-code

# Create proper Claude CLI wrapper script
RUN printf '#!/bin/sh\nexec node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js "$@"\n' > /usr/local/bin/claude \
    && chmod +x /usr/local/bin/claude

# Create non-root user for OpenShift compatibility  
RUN adduser -D -u 1001 -g 0 claude-user \
    && chmod g=u /etc/passwd \
    && chgrp -R 0 /home/claude-user \
    && chmod -R g=u /home/claude-user

# Set up environment
ENV HOME=/home/claude-user
WORKDIR ${HOME}

# Add entrypoint script for dynamic user creation in OpenShift
RUN printf '#!/bin/sh\n\
if ! whoami >/dev/null 2>&1; then\n\
  if [ -w /etc/passwd ]; then\n\
    echo "${USER_NAME:-claude-user}:x:$(id -u):0:${USER_NAME:-claude-user} user:${HOME}:/bin/sh" >> /etc/passwd\n\
  fi\n\
fi\n\
exec "$@"\n' > /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Verify all tools are installed
RUN set -ex \
    && echo "=== Verifying installed tools ===" \
    && for tool in kubectl mc rclone nats nsc virtctl claude; do \
        which "$tool" && echo "✓ $tool found" || (echo "✗ $tool missing" && exit 1); \
    done \
    && echo "All tools verified successfully!"

# Switch to non-root user
USER 1001

# Set entrypoint and default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]