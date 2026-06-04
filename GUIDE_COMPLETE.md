# Hướng dẫn GitOps với Jenkins + ArgoCD + k3s + Cloudflare Tunnel

## Kiến trúc tổng thể

```
[GitHub Source Repo] ──push──▶ [Jenkins] ──build──▶ [Docker Hub]
                             │                          │
                             └── update image tag ──────┘
                                    │
                                    ▼
                         [GitHub Config Repo]
                                    │
                         ArgoCD detect change
                                    ▼
                         [ArgoCD] ──sync──▶ [k3s Cluster]
                                    │
                                    ├── API service (port 8080)
                                    └── Executor service (port 8081)

Internet ──▶ [Cloudflare DNS] ──tunnel──▶ [cloudflared local] ──▶ [Traefik] ──▶ Services
```

## Yêu cầu hệ thống

- RAM: tối thiểu 8GB (thực tế máy em 15GB)
- OS: Linux (đã cài sẵn k3s, Docker, cloudflared)
- GitHub account + access token
- Docker Hub account + access token
- Domain (dùng dpdns.org hoặc Cloudflare)

## Các repo

| Repo | URL | Mục đích |
|------|-----|----------|
| Source | `https://github.com/Duong-Vu-practice-workspace/web-programming-grading-test1.git` | Code + Dockerfile + Jenkinsfile |
| Config | `https://github.com/Duong-Vu-practice-workspace/web-programming-grading-config-test1.git` | Helm chart |

## Cấu trúc file project

```
test-ci-cd/
├── start.sh                                    # Script start all services
├── Jenkinsfile                                 # Pipeline CI
├── backend/web_programming_grading/
│   ├── Dockerfile.api                          # Build API image
│   ├── Dockerfile.executor                     # Build Executor image
│   ├── pom.xml                                 # Parent Maven
│   ├── mvnw                                    # Maven wrapper
│   ├── web_programming_grading_core/           # Library module
│   ├── web_programming_grading_api/            # API service (port 8080)
│   └── web_programming_grading_executor/       # Executor service (port 8081)
└── deploy/
    ├── Dockerfile.jenkins                      # Jenkins custom image
    ├── install-jenkins.sh                      # Cài Jenkins
    ├── install-argocd.sh                       # Cài ArgoCD lên k3s
    ├── setup-namespace.sh                      # Tạo namespace + secret + ArgoCD app
    ├── argocd-application.yaml                 # ArgoCD Application manifest
    ├── argocd-ingress.yaml                     # Ingress cho ArgoCD
    ├── setup-all.sh                            # Script tổng hợp
    ├── cloudflared/
    │   ├── config.yml                          # Config route tunnel
    │   ├── docker-compose.yml                  # Chạy cloudflared
    │   └── setup-tunnel.sh                     # Tạo tunnel + route DNS
    └── helm/web-grading/                       # Helm chart (config repo)
        ├── Chart.yaml
        ├── values.yaml
        ├── values-stg.yaml                     # File được Jenkins update tag
        └── templates/
            ├── _helpers.tpl
            ├── deployments.yaml
            ├── services.yaml
            └── ingress.yaml
```

## Các bước cài đặt chi tiết

### Bước 1: Chuẩn bị

**1.1.** Tạo 2 GitHub repos:
- `Duong-Vu-practice-workspace/web-programming-grading-test1` (source)
- `Duong-Vu-practice-workspace/web-programming-grading-config-test1` (config)

**1.2.** Tạo GitHub access token (classic): Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token → chọn `repo`

**1.3.** Tạo Docker Hub access token: Docker Hub → Account Settings → Security → Access Tokens → New Access Token → quyền Read & Write

### Bước 2: Push code lên GitHub

```bash
# Source repo
cd /home/duongvct/Documents/workspace/PTIT/test-ci-cd
git remote add origin https://github.com/Duong-Vu-practice-workspace/web-programming-grading-test1.git
git push -u origin main

# Config repo (Helm chart)
cd /tmp/web-programming-grading-config
git remote add origin https://github.com/Duong-Vu-practice-workspace/web-programming-grading-config-test1.git
git push -u origin main
```

> **Lưu ý:** `deploy/helm/web-grading/` là nội dung của config repo. Khi push config repo, chỉ push thư mục Helm chart đó.

### Bước 3: Cài Jenkins

```bash
cd /home/duongvct/Documents/workspace/PTIT/test-ci-cd
bash deploy/install-jenkins.sh
```

Jenkins chạy ở `http://localhost:9999`. Lấy initial password:
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

> **Nếu báo lỗi `No such file or directory`:** Jenkins chưa khởi tạo xong, đợi 30s rồi chạy lại.
>
> **Nếu Jenkins đã cài trước đó:** Dùng user/pass đã tạo, không có initial password nữa.

**Kiến trúc Jenkins container:**
- Docker socket mounted: `/var/run/docker.sock` (cho phép build Docker image)
- Docker CLI được cài sẵn trong image
- Jenkins user được thêm vào docker group (GID host) để có quyền truy cập socket

#### Fix lỗi Docker permission denied

Nếu Jenkins build báo `permission denied while trying to connect to the Docker daemon socket`:

**Nguyên nhân:** Jenkins user trong container không có quyền đọc Docker socket host.

**Fix trong Dockerfile.jenkins:**
```dockerfile
ARG DOCKER_GID=999
USER root
RUN apt-get update && apt-get install -y docker.io
RUN groupadd -g ${DOCKER_GID} docker_host || true
RUN usermod -aG docker_host jenkins
USER jenkins
```

**Fix trong install-jenkins.sh:**
```bash
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
docker build --build-arg DOCKER_GID="${DOCKER_GID}" ...
```

**Rebuild:**
```bash
docker stop jenkins && docker rm jenkins
bash deploy/install-jenkins.sh
```

> 📌 **Mount volume:** Dùng `-v jenkins_home:/var/jenkins_home` (named volume) để plugin, job, credentials không bị mất khi rebuild container.

### Bước 4: Cấu hình Jenkins

Vào `http://localhost:9999`:

**4.1.** Cài plugin: Manage Jenkins → Plugins → Available plugins → cài:
- Git
- Docker Pipeline
- Pipeline

**4.2.** Tạo credentials: Manage Jenkins → Credentials → System → Global → Add Credentials

| ID | Kind | Username | Password |
|----|------|----------|----------|
| `github` | Username with password | `vucongtuanduong` | GitHub access token |
| `dockerhub` | Username with password | `vucongtuanduong` | Docker Hub access token |

> **Fix lỗi `unauthorized: incorrect username or password` khi push Docker:** Username trong credential `dockerhub` phải là `vucongtuanduong` (không phải `dockerhub`). Password là access token Docker Hub.

**4.3.** Tạo Pipeline job: New Item → `web-grading-pipeline` → Pipeline → OK
- Definition: `Pipeline script from SCM`
- SCM: `Git`
- Repository URL: `https://github.com/Duong-Vu-practice-workspace/web-programming-grading-test1.git`
- Script Path: `Jenkinsfile`

#### Fix lỗi `Author identity unknown` khi commit

**Nguyên nhân:** Jenkins container chưa có git config.

**Fix trong Jenkinsfile:**
```groovy
sh """
    git config user.email "jenkins@web-grading.com"
    git config user.name "Jenkins CI"
    git add .
    git commit -m "Update images to version ${version}"
"""
```

### Bước 5: Cài ArgoCD lên k3s

```bash
bash deploy/install-argocd.sh
```

#### Fix lỗi `ErrImagePull` - k3s không pull được image từ quay.io

**Nguyên nhân:** containerd (k3s) không resolve được DNS `quay.io` (lỗi `lookup quay.io: Try again`).

**Fix: Pull bằng Docker rồi import vào containerd:**
```bash
docker pull quay.io/argoproj/argocd:v3.4.3
docker save quay.io/argoproj/argocd:v3.4.3 -o /tmp/argocd.tar
sudo k3s ctr images import /tmp/argocd.tar
k3s kubectl delete pods -n argocd --all
```

Kiểm tra pod đã chạy:
```bash
k3s kubectl get pods -n argocd
# Kỳ vọng: tất cả 1/1 Running
```

Sau đó config ArgoCD insecure mode (cho Traefik proxy) + Ingress:
```bash
k3s kubectl patch deployment argocd-server -n argocd --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--insecure"}]'
k3s kubectl apply -f deploy/argocd-ingress.yaml
```

Lấy password ArgoCD:
```bash
k3s kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Bước 6: Setup Cloudflare Tunnel

```bash
bash deploy/cloudflared/setup-tunnel.sh
```

#### Fix lỗi `tunnel with name already exists`

Script đã tự động check và skip nếu tunnel đã tồn tại.

#### Fix lỗi `Authentication error` khi route DNS

**Nguyên nhân:** Domain `vucongtuanduong.dpdns.org` không nằm trên Cloudflare DNS.

**Cách 1:** Thêm CNAME records tại DNS provider (dpdns.org):
| Type | Name | Target |
|------|------|--------|
| CNAME | dev1-api | `b6a0d739-...cfargotunnel.com` |
| CNAME | dev1-executor | `b6a0d739-...cfargotunnel.com` |
| CNAME | dev1-jenkins | `b6a0d739-...cfargotunnel.com` |
| CNAME | dev1-argocd | `b6a0d739-...cfargotunnel.com` |

> `b6a0d739-...` là tunnel ID lấy từ output của `cloudflared tunnel info dev1-web-grading`

**Cách 2:** Dùng Cloudflare DNS nameserver (nếu domain mua từ Cloudflare).

#### Fix lỗi `permission denied` khi chạy cloudflared container

**Nguyên nhân:** Container chạy với user 65532, thư mục `~/.cloudflared/` có permission 700 (chỉ owner đọc được).

**Fix:**
```bash
chmod 755 ~/.cloudflared
docker compose -f deploy/cloudflared/docker-compose.yml down
docker compose -f deploy/cloudflared/docker-compose.yml up -d
```

Script `setup-tunnel.sh` đã tự động fix điều này.

Chạy cloudflared:
```bash
docker compose -f deploy/cloudflared/docker-compose.yml up -d
```

Cấu hình route (config.yml):
```yaml
tunnel: b6a0d739-...  # Tunnel ID thực tế
credentials-file: /etc/cloudflared/b6a0d739-....json
ingress:
  - hostname: dev1-jenkins.vucongtuanduong.dpdns.org
    service: http://localhost:9999
  - hostname: dev1-api.vucongtuanduong.dpdns.org
    service: http://localhost:31242  # Traefik NodePort
  - hostname: dev1-executor.vucongtuanduong.dpdns.org
    service: http://localhost:31242
  - hostname: dev1-argocd.vucongtuanduong.dpdns.org
    service: http://localhost:31242
```

> 📌 **Tại sao dùng NodePort (31242) thay vì LoadBalancer IP?** NodePort ổn định hơn, không phụ thuộc vào mạng (khi đổi WiFi IP host vẫn dùng được `localhost:31242`).

### Bước 7: Tạo namespace + secret + ArgoCD Application

```bash
bash deploy/setup-namespace.sh
```

#### Fix lỗi `unbound variable` khi parse .env

**Nguyên nhân:** File `.env` có dấu `&` trong URL (`channel_binding=require`) khiến `source` command hiểu sai.

**Fix:** Dùng `grep + cut` thay vì `source`:
```bash
DB_URL=$(grep -m1 '^DB_URL=' "$ENV_FILE" | cut -d= -f2-)
```

### Bước 8: Kết nối ArgoCD với config repo

Vào `https://dev1-argocd.vucongtuanduong.dpdns.org` (user: `admin`):

**8.1.** Settings → Repositories → Connect Repo → Via HTTPS
- URL: `https://github.com/Duong-Vu-practice-workspace/web-programming-grading-config-test1.git`
- Username: `vucongtuanduong`
- Password: *(GitHub access token)*

**8.2.** Applications → chọn `web-grading` → `SYNC`

### Bước 9: Chạy CI/CD lần đầu

Vào Jenkins → `web-grading-pipeline` → `Build Now`

Luồng chạy:
1. Checkout source từ GitHub
2. Build Docker image cho API service → push lên Docker Hub
3. Build Docker image cho Executor service → push lên Docker Hub
4. Clone config repo, update `values-stg.yaml` với tag mới → commit & push
5. ArgoCD detect change → sync deployment trên k3s

## Các lệnh hữu ích

### Khởi động lại toàn bộ sau khi boot máy

```bash
# Trong project test-ci-cd/
bash start.sh
```

Hoặc thủ công:
```bash
sudo systemctl start k3s
docker start jenkins 2>/dev/null
docker start cloudflared-dev1 2>/dev/null
```

### Kiểm tra trạng thái

```bash
# k3s cluster
k3s kubectl get nodes
k3s kubectl get pods -A

# ArgoCD
k3s kubectl get pods -n argocd

# Services
k3s kubectl get all -n web-grading

# Jenkins
docker ps | grep jenkins

# Cloudflared
docker ps | grep cloudflared
docker logs cloudflared-dev1
```

### Dọn dẹp dung lượng

```bash
# Xóa Docker build cache
docker system prune -a -f

# Xóa Maven cache trong container
docker exec jenkins rm -rf /root/.m2/repository
```

## Debug Jenkins build

1. Vào Jenkins → chọn build → **Console Output**
2. Đọc log từ dưới lên, lỗi thường ở cuối
3. Các lỗi thường gặp:
   - `permission denied` → Docker socket issue (fix: rebuild Jenkins image)
   - `unauthorized` → Sai credential Docker Hub (fix: update username/password)
   - `Author identity unknown` → Thiếu git config (fix: thêm vào Jenkinsfile)
   - `port already allocated` → Container cũ chưa xóa (fix: `docker rm -f jenkins`)

## Subdomains

| Subdomain | Service | Port | Loại |
|-----------|---------|------|------|
| dev1-jenkins.vucongtuanduong.dpdns.org | Jenkins | 9999 | Docker container |
| dev1-api.vucongtuanduong.dpdns.org | API service | 8080 | k3s (Traefik) |
| dev1-executor.vucongtuanduong.dpdns.org | Executor service | 8081 | k3s (Traefik) |
| dev1-argocd.vucongtuanduong.dpdns.org | ArgoCD | 80 | k3s (Traefik) |

## Thêm service mới

**1.** Tạo module mới trong source repo + Dockerfile

**2.** Thêm stage build trong `Jenkinsfile`:
```groovy
stage('Build and Push New Service') {
    steps {
        script {
            dir('backend/web_programming_grading') {
                def img = docker.build(
                    "${DOCKERHUB_NAMESPACE}/web-grading-new",
                    "-f Dockerfile.new ."
                )
                docker.withRegistry(DOCKER_REGISTRY, dockerhubAccount) {
                    img.push(version)
                    img.push('latest')
                }
            }
        }
    }
}
```

**3.** Thêm vào `values.yaml` và `values-stg.yaml`:
```yaml
services:
  - name: new-service
    replicaCount: 1
    image:
      repository: vucongtuanduong/web-grading-new
    service:
      type: ClusterIP
      port: 8082
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi
```

**4.** Thêm route trong `cloudflared/config.yml`:
```yaml
- hostname: dev1-new-service.vucongtuanduong.dpdns.org
  service: http://localhost:31242
```

**5.** Push lên GitHub → Jenkins tự build → ArgoCD auto-sync
