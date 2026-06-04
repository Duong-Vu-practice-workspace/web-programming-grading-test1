#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building Jenkins image with Docker CLI ==="
docker build -t my-jenkins:lts -f "$SCRIPT_DIR/Dockerfile.jenkins" "$SCRIPT_DIR"

echo "=== Starting Jenkins container ==="
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 9999:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd):/workspace" \
  my-jenkins:lts

echo "Waiting for Jenkins to start..."
sleep 20

echo ""
echo "=== Initial admin password ==="
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

echo ""
echo "=== Access Jenkins at: http://localhost:9999 ==="
echo "=== First-time setup ==="
echo "  1. Paste the initial admin password above"
echo "  2. Install suggested plugins"
echo "  3. Create admin user (or continue as admin)"
echo ""
echo "=== Post-setup: Install plugins ==="
echo "  Manage Jenkins > Plugins > Available plugins:"
echo "  - Git"
echo "  - Docker Pipeline"
echo "  - Pipeline"
echo ""
echo "=== Credentials to create (Manage Jenkins > Credentials): ==="
echo "  ID 'github':"
echo "    Kind: Username with password"
echo "    Username: vucongtuanduong"
echo "    Password: <your GitHub access token>"
echo ""
echo "  ID 'dockerhub':"
echo "    Kind: Username with password"
echo "    Username: vucongtuanduong"
echo "    Password: <your Docker Hub access token>"
echo ""
echo "=== Then create Pipeline job: ==="
echo "  New Item > Pipeline > OK"
echo "  Pipeline > Definition: Pipeline script from SCM"
echo "  SCM: Git, Repo: https://github.com/Duong-Vu-practice-workspace/web-programming-grading-test1.git"
echo "  Script Path: Jenkinsfile"
