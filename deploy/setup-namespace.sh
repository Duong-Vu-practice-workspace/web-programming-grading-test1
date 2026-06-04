#!/usr/bin/env bash
set -euo pipefail

echo "=== Creating web-grading namespace ==="
k3s kubectl create namespace web-grading --dry-run=client -o yaml | k3s kubectl apply -f -

echo "=== Creating secrets from .env ==="
if [ -f backend/web_programming_grading/.env ]; then
  source backend/web_programming_grading/.env
  k3s kubectl create secret generic db-secret \
    --namespace web-grading \
    --from-literal=DB_URL="${DB_URL}" \
    --from-literal=DB_USERNAME="${DB_USERNAME}" \
    --from-literal=DB_PASSWORD="${DB_PASSWORD}" \
    --dry-run=client -o yaml | k3s kubectl apply -f -
else
  echo "WARNING: .env file not found, create db-secret manually"
fi

echo ""
echo "=== Apply ArgoCD Application ==="
k3s kubectl apply -f deploy/argocd-application.yaml
