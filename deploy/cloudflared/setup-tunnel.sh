#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-vucongtuanduong.dpdns.org}"
TUNNEL_NAME="${2:-dev1-web-grading}"

echo "=== Creating cloudflared tunnel: ${TUNNEL_NAME} ==="
cloudflared tunnel create "${TUNNEL_NAME}"

echo ""
echo "=== Routing DNS for dev1-*.${DOMAIN} ==="
cloudflared tunnel route dns "${TUNNEL_NAME}" "dev1-*.${DOMAIN}"

TUNNEL_ID=$(cloudflared tunnel info "${TUNNEL_NAME}" | grep -oP 'ID\s+\K[a-f0-9-]+' | head -1)
echo ""
echo "=== Tunnel ID: ${TUNNEL_ID} ==="

echo ""
echo "=== Config file created at: ~/.cloudflared/${TUNNEL_ID}.json ==="
echo ""
echo "=== Next: run cloudflared with docker-compose ==="
echo "  cd deploy/cloudflared"
echo "  docker compose up -d"
echo ""
echo "=== DNS records to add in Cloudflare Dashboard: ==="
echo "  CNAME dev1-api    → ${TUNNEL_ID}.cfargotunnel.com"
echo "  CNAME dev1-executor → ${TUNNEL_ID}.cfargotunnel.com"
echo "  CNAME dev1-jenkins  → ${TUNNEL_ID}.cfargotunnel.com"
echo "  CNAME dev1-argocd   → ${TUNNEL_ID}.cfargotunnel.com"
echo ""
echo "Or use: cloudflared tunnel route dns already handles CNAME automatically"
