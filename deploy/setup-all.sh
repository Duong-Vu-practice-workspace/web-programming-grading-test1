#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  Web Grading - Full GitOps Setup"
echo "============================================"
echo ""

echo "=== Step 1: Create k3s namespace + DB secret ==="
bash "$SCRIPT_DIR/setup-namespace.sh"
echo ""

echo "=== Step 2: Install ArgoCD ==="
bash "$SCRIPT_DIR/install-argocd.sh"
echo ""

echo "=== Step 3: Install Jenkins ==="
bash "$SCRIPT_DIR/install-jenkins.sh"
echo ""

echo "=== Step 4: Setup Cloudflare Tunnel ==="
echo "Run this AFTER setting up GitHub + Docker Hub:"
echo ""
echo "  bash deploy/cloudflared/setup-tunnel.sh"
echo ""
echo "  docker compose -f deploy/cloudflared/docker-compose.yml up -d"
echo ""

echo "=== Step 5: Push Helm chart to config repo ==="
echo "  cd deploy/helm/web-grading"
echo "  git init && git add . && git commit -m 'init'"
echo "  git remote add origin git@github.com:Duong-Vu-practice-workspace/web-programming-grading-config-test1.git"
echo "  git push -u origin main"
echo ""

echo "=== Step 6: Create ArgoCD Application ==="
echo "  kubectl apply -f deploy/argocd-application.yaml"
echo ""

echo "=== Summary ==="
echo "  dev1-api.vucongtuanduong.dpdns.org      → API service (port 8080)"
echo "  dev1-executor.vucongtuanduong.dpdns.org → Executor service (port 8081)"
echo "  dev1-jenkins.vucongtuanduong.dpdns.org   → Jenkins (port 9999)"
echo "  dev1-argocd.vucongtuanduong.dpdns.org    → ArgoCD"
echo ""
echo "  For new services:"
echo "    1. Add to deploy/helm/web-grading/values.yaml under services:"
echo "    2. Add route to deploy/cloudflared/config.yml"
echo "    3. Push to config repo"
