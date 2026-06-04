#!/usr/bin/env bash
set -euo pipefail

echo "=== Start k3s ==="
sudo systemctl start k3s
sleep 5
k3s kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "=== Start Jenkins ==="
docker start jenkins 2>/dev/null || \
  echo "Jenkins chưa có, chạy: bash deploy/install-jenkins.sh"

echo "=== Start Cloudflare Tunnel ==="
docker start cloudflared-dev1 2>/dev/null || \
  echo "cloudflared chưa có, chạy: docker compose -f deploy/cloudflared/docker-compose.yml up -d"

echo ""
echo "=== Services ==="
echo "  dev1-jenkins.vucongtuanduong.dpdns.org   → localhost:9999"
echo "  dev1-api.vucongtuanduong.dpdns.org        → localhost:31242 (Traefik) → api:8080"
echo "  dev1-executor.vucongtuanduong.dpdns.org   → localhost:31242 (Traefik) → executor:8081"
echo "  dev1-argocd.vucongtuanduong.dpdns.org     → localhost:31242 (Traefik) → argocd:80"
