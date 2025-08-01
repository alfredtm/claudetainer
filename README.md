# Claudetainer

A containerized Claude Code CLI with common DevOps tools for Kubernetes and OpenShift deployment.

## Overview

This container packages Anthropic's Claude Code CLI alongside essential tools like kubectl, rclone, and PostgreSQL client in an Alpine Linux environment. It's designed for secure, non-root deployment in Kubernetes clusters.

## Quick Start

```bash
# Deploy to your cluster
kubectl apply -f k8s/claude.yaml

# Access Claude AI
kubectl exec -it deployment/claude -n claude-system -- claude

# Or get an interactive shell
kubectl exec -it deployment/claude -n claude-system -- /bin/bash
```

## Included Tools

| Tool | Purpose | Version |
|------|---------|---------|
| Claude CLI | AI Assistant | v1.0.65 |
| kubectl | Kubernetes CLI | v1.33.3 |
| mc | MinIO Client | Latest |
| rclone | Cloud Sync | v1.70.3 |
| nats/nsc | Messaging Tools | v0.2.4/v2.11.0 |
| psql | PostgreSQL Client | v17.5 |
| virtctl | KubeVirt CLI | v1.5.0 |
| jq | JSON Processor | v1.8.0 |

## Security

- Non-root execution (runs as UID 1001)
- Read-only cluster access (no secrets access)
- OpenShift compatible with random UID support
- All capabilities dropped
- Alpine Linux base for minimal attack surface

## Technical Details

- **Base**: Alpine Linux 3.22
- **Platforms**: AMD64, ARM64
- **Runtime**: Node.js 20 LTS
- **Writable paths**: `/tmp`, `/app/cache`, `/home/claude-user`

## Usage

```bash
# Pull the image
docker pull ghcr.io/alfredtm/claudetainer/claude-cli:latest

# Deploy to Kubernetes
kubectl apply -f k8s/claude.yaml
```

## Resource Requirements

- **Memory**: 1-2GB recommended
- **CPU**: 0.5-1 core recommended

## Authentication

Claude CLI requires interactive authentication on first use:

```bash
kubectl exec -it deployment/claude -n claude-system -- claude
# Follow the browser-based authentication flow
```

## License

MIT License - see [LICENSE](LICENSE) file for details.