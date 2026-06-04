## \[K8S\] Phần 21 - Xây dựng luồng Gitops với Jenkins và ArgoCD

> Lời đầu tiên xin chúc tất cả bạn đọc và gia đình năm mới mạnh khỏe, an khang thịnh vượng 🤩

> Chúc các bạn đạt được nhiều mục tiêu đề ra và dành được nhiều thành công trong năm mới 2023 này.

## Giới thiệu

Hello mọi người. Lâu rồi mình mới có thời gian quay lại với series Kubernetes này. Trong phần 17 của series này, mình đã chia sẻ một mô hình CICD đơn giản sử dụng Jenkins. Các bạn có thể tham khảo nội dung [***bài viết đó ở đây.***](https://viblo.asia/p/k8s-phan-17-xay-dung-luong-cicd-voi-gitlab-va-jenkins-RnB5pJAGZPG)

**Ý tương triển khai Mô hình CICD đó như sau:** ![image.png](https://images.viblo.asia/full/5df67387-c99a-42e3-9f92-19db91cfb1a3.png)

Mô hình này đã giúp giải quyết được bài toán tự động hóa luồng cập nhật thay đổi từ source code tới môi trường triển khai (dev/prod..).

**Tuy nhiên nó vẫn còn một số hạn chế như sau:**

- Rủi ro về bảo mật khi CI và CD không được tách biệt. Trong trường hợp nó bị tấn công thì kẻ tấn công cũng có thể truy cập vào hệ thống đang chạy
- Không phát hiện được sự sai khác giữa cấu hình triển khai ta định nghĩa ban đầu và cấu hình triển khai thực tế
- Khó quản lý tính đồng nhất về cấu hình triển khai ứng dụng trong quá trình vận hành
- Luồng CICD này chủ yếu tập trung vào việc đưa các cập nhật của source code lên các môi trường triển khai. Phần cấu hình triển khai thường ít có thay đổi (helmchart/manifest) trừ thông tin image của source code mới build.

Có thể lấy một ví dụ đơn giản là bạn deploy một ứng dụng A sử dụng luồng CICD như bên trên. Ban đầu bạn đặt cấu hình resource với cpu limit là 300m. Nhưng trong quá trình vận hành bạn thấy Pod thường bị restart khi vượt ngưỡng CPU. Do đó để hot fix bạn vào trực tiếp hệ thống để edit deployment tăng giá trị CPU Limit lên thành 600m.

Tuy nhiên khi bạn chạy lại luồng CICD (khi có update về source code và cần deploy lên hệ thống) thì lúc này các giá trị cấu hình của ứng dụng sẽ lại được set về như ban đầu (giá trị CPU limit sẽ được set lại thành 300m). Bạn đã thấy vấn đề bắt đầu xuất hiện ở đây chưa?

***Vì đây chính là lúc Gitops xuất hiện để giải quyết bài toán trên cho các bạn.***

## Gitops là gì, gitops mang lại lợi ích gì

## Gitops là gì

Ý tưởng chính của GitOps là sử dụng Git để lưu trữ cấu hình toàn bộ cơ sở hạ tầng triển khai hoàn chỉnh cho một ứng dụng. Một tập hợp các file, sử dụng IAC, được sử dụng để phân bổ các tài nguyên cơ sở hạ tầng cần thiết, để cấu hình việc triển khai ứng dụng.

Điều này làm cho thông tin được lưu trữ trên Git trở thành nguồn cơ sở của toán bộ hạ tầng (source of truth) mà các ứng dụng phải tiếp cận và thực hiện xoay quanh nó.

Một ví dụ điển hình là Terraform của Hashicorp. Với Terraform, bạn có thể định nghĩa toàn bộ cơ sở hạ tầng của mình dưới dạng mã code và lưu trữ trên git. Hạ tầng của bạn sẽ luôn được đảm bảo tính nhất quán với các cấu hình bạn đã định nghĩa.

**Một flow về Gitops cho infra::**

## Lợi ích khi sử dụng gitops

Lợi ích cốt lõi của GitOps có thể được hiểu ngắn gọn là đảm bảo các thay đổi được cập nhật ở cả tầng hệ thống và tầng ứng dụng, tự động các quy trình sau đó và đảm bảo ứng dụng trong thực tế phản ánh chính xác ứng dụng được miêu tả trong các tệp chứa cấu hình triển khai ứng dụng/hệ thống.

GitOps có thể giúp bạn nâng cấp luồng CICD lên một level cao hơn, nâng cao tính bảo mật, độ tin cậy tối ưu được nguồn lực cho vận hành hệ thống.

## Mô hình Gitops cơ bản với Jenkins và ArgoCD

Các bạn có thể tham khảo một mô hình Gitops cơ bản dùng Jenkins (CI) và ArgoCD (CD) như sau:

## Ý tưởng của nó như sau:

- Source code của dự án được lưu ở một repo riêng, gọi là `source repo`
- Phần cấu hình triển khai ứng dụng (helmchart hay k8s manifest files..) được lưu ở một repo riêng, gọi là `config repo`
- Luồng CICD hoạt động theo trình tự:
	- Dev commit source code
		- Jenkins build source code
		- Jenkins Build Images
		- Jenkins push image lên image registry
		- Jenkins cập nhật thông tin phiên bản ứng dụng vào các file cấu hình triển khai ứng dụng lưu trên config repo
		- ArgoCD phát hiện thay đổi trên config repo thì cập nhật thay đổi về
		- ArgoCD so sánh thông tin cấu hình mới với cấu hình hiện tại trên hệ thống, nếu phát hiện sai khác sẽ cảnh báo và đồng bộ lại theo cấu hình được khai báo và lưu trên config repo

Ví dụ bạn deploy ứng dụng bằng helmchart và nó sẽ tạo ra 1 deployment + 1 service + 1 configmap chẳng hạn. Thì ArgoCD sẽ tìm trên K8S có các resource như mô tả của helmchart + helm-value hay chưa (dựa vào namespace và resource-name).

**Như vậy so với luồng CICD mà mình đã giới thiệu trước đó (ở bài 17) thì chúng ta sẽ có một số việc mới cần giải quyết:**

- Lưu trữ helmchart của ứng dụng lên một `config repo` trên git
- Cập nhật thông tin phiên bản ứng dụng (image:tag) vào file helmchart-value trên `config repo`
- Cài đặt và cấu hình ArgoCD để đồng bộ từ config repo với ứng dụng triển khai thực tế trên k8s

## Triển khai

## Các bước chúng ta cần thực hiện gồm:

- Dựng cụm k8s (đương nhiên) và các thành phần liên quan như Ingress Controller..
- Tạo `source repo` trên Git (sử dụng Github cho tiện cho bài demo này)
- Tạo `config repo` trên Git (sử dụng Github cho tiện cho bài demo này)
- Tạo repository trên DockerHub để lưu image của ứng dụng
- Cài đặt và cấu hình Jenkins (tích hợp với git chứa `source repo` và `config repo`)
- Cài đặt và cấu hình ArgoCD trên K8S (tích hợp với Github và Dockerhub)
- Tạo job trên Jenkin thực hiện các tác vụ: Pull source code + Build source + Build Image + Push Image + Update Image:tag vào `config repo`
- Tạo ứng dụng trên ArgoCD sử dụng các file manifest trên `config repo` để đồng bộ với ứng dụng triển khai thực tế trên k8s
- Test luồng cập nhật `source repo` và luồng cập nhật `config repo`

## Mô hình triển khai

Mô hình triển khai Lab này như sau:

- K8S được cài trên 3 VM gồm 1 control-plane và 2 worker node
- Jenkins được cài trên VM
- ArgoCD được cài đặt trên K8S ở namespace `argocd`
- Ứng dụng demo được cài ở namespace `demo2`

## Dựng cụm k8s

Mình đã dựng sẵn một cụm k8s gồm 1 master và 2 worker như sau:

```
NAME               STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION    CONTAINER-RUNTIME
ip-172-31-21-254   Ready    control-plane   28d   v1.26.0   172.31.21.254   <none>        Ubuntu 20.04.5 LTS   5.15.0-1028-aws   containerd://1.6.15
ip-172-31-29-187   Ready    <none>          28d   v1.26.0   172.31.29.187   <none>        Ubuntu 20.04.5 LTS   5.15.0-1028-aws   containerd://1.6.15
ip-172-31-30-194   Ready    <none>          28d   v1.26.0   172.31.30.194   <none>        Ubuntu 20.04.5 LTS   5.15.0-1028-aws   containerd://1.6.15
```

Môi trường Lab này mình cài k8s phiên bản `v1.26.0` và sử dụng CRI là containerd `1.6.15`.

## Tạo source repo để lưu trữ source code

### Tạo source repo

Mình sử dụng lại bản source code giống như đã triển khai ở bài hướng dẫn dựng CICD, các bạn có thể download source code ở [link github này](https://github.com/rockman88v/demo-app.git)

Mô tả sơ bộ thì đây là một App viết bằng NodeJs hiển thị một số thông tin về deployment của nó trên k8s như namespace, node, Pod..

### Tạo access key để truy cập github

Trong mô hình sử dụng gitops này, Jenkin vẫn đóng vai trò CI và nó cần pull được từ `source repo` và `config repo`. Do đó ta cần tạo một `access token` trên github và cấu hình cho Jenkins sử dụng token đó khi pull từ github.

**Các bạn tạo `access token` theo bước sau:**

Vào thông tin user ở góc trên bên phải chọn Setting ⇒ Developer settings (Hoặc truy cập thẳng vào link: [https://github.com/settings/tokens](https://github.com/settings/tokens))

Chọn **Generate new token** ⇒ **Generate new token (classic)** ⇒ Đặt tên token và tick chọn vào mục **repo** ⇒ **Generate token** ⇒ Lưu lại token vừa sinh ra để sử dụng.

## Tạo config repo để lưu trữ helmchart và file helm-value cho ứng dụng

### Tạo config repo

Phần helmchart để triển khai cho ứng này mình sẽ lưu trên một repo riêng, các bạn có thể [***download ở đây***](https://github.com/rockman88v/app-helmchart.git). Trong thư mục helmchart mình sẽ lưu trữ một file `values.yaml` chứa các cấu hình mặc định cho ứng dụng. Các giá trị cần tùy biến sẽ lưu ở file `app-demo-value.yaml`. Một số tham số quan trọng như:

- image.repository => Khai báo thông tin image của ứng dụng
- image.tag => Phiên bản đóng gói của ứng dụng
- replicaCount => Số Pod chạy ứng dụng
- service.type => Mình để là `NodePort` để khỏi phải tạo ingress..

### Tạo access key để truy cập github

Nếu `config repo` và `source repo` cùng dùng chung github thì bạn chỉ cần tạo 1 lần `access token` để dùng chung. Còn nếu là 2 hệ thống khác nhau thì tạo 2 `access token` riêng biệt nhé!

**Ở đây mình dùng chung một account nên chỉ tạo 1 `access token` là đủ.**

## Tạo repository trên Dockerhub để lưu Images

### Tạo repository

Bước này khá đơn giản nên mình không mô tả gì thêm nhiều. Các bạn tạo một repo mới để sau khi build docker image thì sẽ push image đó lên dockerhub repo. Mình đã tạo sẵn repo trên dockerhub là `rockman88v/demo-app` như sau:

### Tạo access token để kết nối tới dockerhub

Khi login vào dockerhub bạn chọn vào tên account → Setting → Secutiry → Access Tokens → New Access Token:

![Untitled (1).png](https://images.viblo.asia/full/a2f91afa-592f-457b-a268-07774e4f8a5f.png)

Untitled (1).png

Chọn tên cho token, quyền là Read & Write và chọn Generate. Bạn cần lưu lại token mới sinh ra để sử dụng ở các bước sau:

```
dckr_pat_m_ygVxxxxxxxxxxxxxx
```

***Token này sẽ được sử dụng làm credential cho Jenkins khi cần push docker image lên dockerhub.***

## Cài đặt và cấu hình jenkins

### Cài đặt và cấu hình Jenkins

Bước này mình không giới thiệu kỹ vì cài đặt khá đơn giản các bạn gg và làm theo. Phần cài đặt các plugin thì bạn cần cài Git, Docker Pipeline.

### Tạo credentials kết nối github và dockerhub

Trong ví dụ này mình sử dụng github và dockerhub. Trong trường hợp các bạn sử dụng công cụ khác thì cũng làm tương tự là tạo token hoặc user/pass trên các hệ thống SMC và registry tương ứng để tạo credentials cho jenkins.

Để tạo credentials bạn thực hiện trên jenkins web như sau: Vào Manage Jenkins => Manage Credentials => chọn Domain `global` => chọn `Add Credentials` => chọn kind là `Username with password`.

**Ví dụ để tạo credentials cho Jenkins két nối github mình sẽ điền:**

- Username: Là user của bạn trên github
- Password: Là `access token` tạo ở bước trên
- ID: Điền là `github`. ID này sẽ được dùng trong pipeline khi cần pull/commit tới github, bạn đặt tên gì gợi nhớ là dc.

**Tương tự bạn tạo credential cho Jenkins kết nối tới dockerhub:**

- Username: Là user của bạn trên dockerhub
- Password: Là `access token` tạo ở bước trên
- ID: Điền là `dockerhub`. ID này sẽ được dùng trong pipeline khi cần push image lên dockerhub

**Kết quả như sau:**

## Cài đặt và cấu hình ArgoCD

**Các bạn cài đặt ArgoCD lên K8S bằng lệnh sau:**

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Cấu hình service thành loại NodePort:
kubectl patch svc -n argocd argocd-server --patch '{"spec": {"type": "NodePort"}}'
```

**Kết quả sinh ra các resource ở namespace `argocd` như sau:**

```
ubuntu@base-node:~$ k -n argocd get all
NAME                                                    READY   STATUS    RESTARTS      AGE
pod/argocd-application-controller-0                     1/1     Running   4 (13h ago)   29d
pod/argocd-applicationset-controller-6f8bd46d57-6zlrs   1/1     Running   5 (13h ago)   29d
pod/argocd-dex-server-7b64b5456b-rw858                  1/1     Running   4 (13h ago)   29d
pod/argocd-notifications-controller-6d8d47c47b-7kczx    1/1     Running   4 (13h ago)   29d
pod/argocd-redis-847d5bc57c-sm4g8                       1/1     Running   4 (13h ago)   29d
pod/argocd-repo-server-685bbbf85c-68rjf                 1/1     Running   4 (13h ago)   29d
pod/argocd-server-66fcf976bf-5jt88                      1/1     Running   4 (13h ago)   28d

NAME                                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/argocd-applicationset-controller          ClusterIP   10.106.171.153   <none>        7000/TCP,8080/TCP            29d
service/argocd-dex-server                         ClusterIP   10.106.88.129    <none>        5556/TCP,5557/TCP,5558/TCP   29d
service/argocd-metrics                            ClusterIP   10.97.2.20       <none>        8082/TCP                     29d
service/argocd-notifications-controller-metrics   ClusterIP   10.98.211.133    <none>        9001/TCP                     29d
service/argocd-redis                              ClusterIP   10.106.47.164    <none>        6379/TCP                     29d
service/argocd-repo-server                        ClusterIP   10.109.251.135   <none>        8081/TCP,8084/TCP            29d
service/argocd-server                             NodePort    10.99.253.77     <none>        80:32656/TCP,443:30671/TCP   29d
service/argocd-server-metrics                     ClusterIP   10.107.240.56    <none>        8083/TCP                     29d

NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/argocd-applicationset-controller   1/1     1            1           29d
deployment.apps/argocd-dex-server                  1/1     1            1           29d
deployment.apps/argocd-notifications-controller    1/1     1            1           29d
deployment.apps/argocd-redis                       1/1     1            1           29d
deployment.apps/argocd-repo-server                 1/1     1            1           29d
deployment.apps/argocd-server                      1/1     1            1           29d

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/argocd-applicationset-controller-6f8bd46d57   1         1         1       29d
replicaset.apps/argocd-dex-server-7b64b5456b                  1         1         1       29d
replicaset.apps/argocd-notifications-controller-6d8d47c47b    1         1         1       29d
replicaset.apps/argocd-redis-847d5bc57c                       1         1         1       29d
replicaset.apps/argocd-repo-server-685bbbf85c                 1         1         1       29d
replicaset.apps/argocd-server-66fcf976bf                      1         1         1       29d

NAME                                             READY   AGE
statefulset.apps/argocd-application-controller   1/1     29d
```

**Để truy cập vào web của ArgoCD bạn cần 2 thứ:**

- Lấy thông tin NodePort được gán cho service `argocd-server`, như bên dưới ta có NodePort https là `30671`:

```
ubuntu@base-node:~$ k -n argocd get svc argocd-server
NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
argocd-server   NodePort   10.99.253.77   <none>        80:32656/TCP,443:30671/TCP   29d
```

- Lấy thông tin password đăng nhập mặc định sau khi cài (kết quả cho ra `EvmRUhW99524rAfE`):

```
ubuntu@base-node:~$ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
EvmRUhW99524rAfE
```

***Lúc này ta có thể truy cập vào Web của ArgoCD thông qua workerIP:NodePort dùng user mặc định là `admin` với password trên.***

`NOTE: Ở bước này mình chưa cài certificate cho Argo nên khi đăng nhập sẽ báo invalid certificate thì các bạn vẫn chọn tiếp tục để bỏ qua lỗi cert nhé!`

## Tạo job CI trên Jenkins

**Tới bước này mình cần định nghĩa Job cho jenkins thực hiện các công việc sau:**

- Pull `source code` từ github
- Build source code
- Build docker image
- Push docker image lên container registry (dockerhub)
- Cập nhật thông tin phiên bản ứng dụng (image.tag) vào file helm-value lưu trong `config repo`

Các bước trên đều không có gì mới so với luồng CICD trước đây mình đã đề cập ở [bài 17 Xây dựng luồng CICD với Gitlab và Jenkins](https://viblo.asia/p/k8s-phan-17-xay-dung-luong-cicd-voi-gitlab-va-jenkins-RnB5pJAGZPG) trừ bước cập nhật thông tin phiên bản ứng dụng.

Ý tưởng của bước này là ở mỗi lần build source code thành docker image, ta sẽ sử dụng tham số BUILD\_NUMBER (tăng lần sau mỗi lần build) là thông tin tag của image. Do đó ta cũng cần cập nhật tham số này cho file helm-value để triển khai ứng dụng lên k8s, file này nằm ở `config repo`.

**Để thực hiện được bước này có nhiều phương án, ở đây mình dùng ý tưởng đơn giản như sau:**

- Pull `config repo` về
- Cập nhật giá trị image.tag theo đúng tag mới build
- Commit thay đổi vào repo `config repo`

**Các bạn tham khảo cấu hình job thực hiện các bước nêu trên như sau:**

```java
//pull config repo ok
// update tag in config repo ok
// not yet commit and push
def appSourceRepo = 'https://github.com/rockman88v/demo-app.git'
def appSourceBranch = 'master'

def appConfigRepo = 'https://github.com/rockman88v/app-helmchart.git'
def appConfigBranch = 'master'
def helmRepo = "app-helmchart"
def helmChart = "app-demo"
def helmValueFile = "app-demo/app-demo-value.yaml"

def dockerhubAccount = 'dockerhub'
def githubAccount = 'github'

dockerBuildCommand = './'
def version = "v1.${BUILD_NUMBER}"

pipeline {
    agent any    
   
    environment {
        DOCKER_REGISTRY = 'https://registry-1.docker.io'
        DOCKER_IMAGE_NAME = "rockman88v/demo-app"
        DOCKER_IMAGE = "registry-1.docker.io/${DOCKER_IMAGE_NAME}"
    }

    stages {        
        stage('Checkout project') {
          steps {
            git branch: appSourceBranch,
                credentialsId: githubAccount,
                url: appSourceRepo
          }
        }
        stage('Build And Push Docker Image') {
            steps {
                script {
                    sh "git reset --hard"
                    sh "git clean -f"                    
                    app = docker.build(DOCKER_IMAGE_NAME, dockerBuildCommand)
                    docker.withRegistry( DOCKER_REGISTRY, dockerhubAccount ) {
                       app.push(version)
                    }

                    sh "docker rmi ${DOCKER_IMAGE_NAME} -f"
                    sh "docker rmi ${DOCKER_IMAGE}:${version} -f"
                }
            }
        }

        stage('Update value in helm-chart') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                sh """#!/bin/bash
                       [[ -d ${helmRepo} ]] && rm -r ${helmRepo}
                       git clone ${appConfigRepo} --branch ${appConfigBranch}
                       cd ${helmRepo}
                       sed -i 's|  tag: .*|  tag: "${version}"|' ${helmValueFile}
                       git add . ; git commit -m "Update to version ${version}";git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/rockman88v/app-helmchart.git
                       cd ..
                       [[ -d ${helmRepo} ]] && rm -r ${helmRepo}
                       """        
                }                
            }
        }
    }
}
```

Lúc này mỗi khi bạn có thay đổi về source code và build job trên Jenkins thì phiên bản của Docker Image sẽ được cập nhật vào file helm-value (`app-demo-value.yaml`)

**Kết quả build Jenkins:**

**Kết quả update lên `config repo`:**

***Như vậy là Jenkins đã hoàn thành nhiệm vụ của nó rồi. Phần còn lại là cấu hình tiếp phía ArgoCD để thực hiện luồng CD***

## Tạo Application (ứng dụng) trên ArgoCD

### Khai báo repository chứa config repo vào argocd

Từ web của argocd vào Settings → Repositories → Connect repo → via HTTPS và cấu hình các tham số như sau:

- Choose your connection method: => `VIA HTTPS`
- Type => `Git`
- Project => `default`
- Repository URL: Điền thông tin repo đã tạo ở bên trên `https://github.com/rockman88v/app-helmchart.git`
- Username/Password: Điền thông tin account, password là token tạo bên trên.

**Kết quả khi tạo repository thành công:**

### Khai báo ứng dụng trên ArgoCD

> Khái niệm "Application" (ứng dụng) trên ArgoCD chính là ta khai báo việc theo dõi một tập các resource trên K8S dựa vào một tập file cấu hình định nghĩa các resource đó. Trong trường hợp này ta sẽ định nghĩa ứng dụng demo của chúng ta từ bộ helm-chart và helm-value được lưu trên `config repo`.

**Khai báo application:** Từ web của argocd vào Applications → New App và điền các tham số như sau:

**GENERAL:**

- Application Name: Điền tên của Application, ví dụ `DEMO-APP3`
- Project Name: `Default`
- SYNC POLICY: `Manual`. Ở đây có 2 option là `Manual` hoặc `Auto-sync`.
	- `Auto-sync`: Khi phát hiện sự bất đồng bộ giữa cấu hình thực tế (trên K8S) so với định nghĩa (trên `config repo` thì Argo thực hiện tự động việc cập nhật cấu hình các resource trên K8S theo đúng cấu hình đã định nghĩa
		- `Manual` Khi phát hiện bất động bộ thì ArgoCD sẽ chỉ cảnh báo lên các resource bị mất đồng bộ (out of sync) và bạn muốn đồng bộ lại thì cần phải chọn vào nút `sync` để đồng bộ lại.

**SOURCE:**

- Repository URL: [`https://github.com/rockman88v/app-helmchart.git`](https://github.com/rockman88v/app-helmchart.git)
- Path: `app-demo` -> Đây là thư mục chứa helmchart của chúng ta

**DESTINATION:**

- Cluster URL: [`https://kubernetes.default.svc`](https://kubernetes.default.svc/)
- Namespace: `demo3`

**Helm:**

- VALUES FILES: Chọn 2 file value theo đúng thứ tự là `values.yaml` và `app-demo-value.yaml`

**Sau đó chọn CREATE để tạo application. Kết quả:**

Ở đây khi mới tạo thì ứng dụng của bạn sẽ ở trạng thái " **Missing, OutOfSync** ", đơn giản là vì bạn chưa tạo resource trên K8S. Trong hình trên thì app `demo-app2` là mình đã sync từ trước rồi, còn app `app-demo3` là mình vừa tạo xong tương tự như app-demo2 nhưng ở namespace khác.

> Một lưu ý là bạn cần tạo namespace trước khi khai báo ứng dụng trên ArgoCD nhé!

Khi ấn vào xem chi tiết ứng dụng sẽ thấy ứng dụng này quản lý trạng thái của 3 resource là `service`, `service account` và `deployment`, cả 3 resource này đều chưa được tạo trên namespace `demo3`:

Chúng ta có thể ấn `SYNC` để đồng bộ trạng thái trên k8s với trên git, nghĩa là sẽ tạo ra các resource trên k8s:

Kết quả sau khi sync thành công, ứng dụng ở trạng thái "Synced":

## Test luồng cập nhật source code

Thông thường thì phần cấu hình cho ứng dụng sẽ ít khi có thay đổi, trừ khi bạn muốn bổ sung thêm template hay thay đổi scale hoặc các tham số liên quan tới resource limit/request..

Mỗi khi có update về source code thì bạn sẽ cần chạy luồng CICD để deploy lên môi trường thực tế. Khi đó phần duy nhất thay đổi ở phần `config repo` là giá trị image.tag. Ví dụ ứng dụng hiện tại của mình đang ở phiên bản ứng dụng là `1.33 20230116` như các bạn thấy khi vào web:

Bây giờ mình sẽ cập nhật giá trị này ở trong source code, file `documents/index.html` thành "This is version 1.40 20230209" và chạy lại luồng CICD này.

Sau khi Jenkin build xong sẽ cập nhật thông tin image và ArgoCD sẽ update các resoure tương ứng trên k8s, cụ thể chỉ có deployment cần update (do image.tag thay đổi) còn các resource khác khong ảnh hưởng gì:

**Vào lại web của ứng dụng và verify thông tin cập nhật (hiển thị phiên bản mới `1.41 20230209`):**

## Test luồng cập nhật trực tiếp helmchart trên config repo

Trong quá trình vận hành ứng dụng, đôi khi chúng ta phải thay đổi các tham số cấu hình cho ứng dụng ví dụ như:

- Thay đổi số lượng Pod (tăng/giảm)
- Thay đổi cấu hình resource (tăng/giảm request/limit cho RAM/CPU)
- Thêm template mới (ví dụ thêm cấu hình Affinity, hay service monitor..)

Những thay đổi này độc lập với thay đổi của source code ứng dụng (tức là về logic nghiệp vụ không đổi, phiên bản đóng gói ứng dụng không đổi).

Lúc này những thay đổi sẽ được thực hiện commit lên `config repo` và đây là nguồn đảm bảo thông tin cấu hình luôn được đồng bộ với mọi thành viên trong team.

**Mình sẽ demo 2 trường hợp điển hình:**

- Cập nhật cấu hình ở `config repo` => Argo đồng bộ các thay đổi đó lên các resource tương ứng trên k8s
- Thay đổi cấu hình resource trên k8s => Argo phát hiện thay đổi và sẽ chiếu theo cấu hình từ trên git để apply ngược lại k8s

### Trường hợp cấu hình ứng dụng trên git

Hiện trạng ứng dụng của mình lúc này đang quản lý 3 tài nguyên là service, service account và deployment với 3 replicas.

> Lưu ý bước này mình sẽ tắt tính năng autosync của Application trên ArgoCD để dễ quan sát sự thay đổi và khác biệt giữa cấu hình thực tế và cấu hình định nghĩa trên git.

**Mình sẽ update cấu hình ứng dụng này ở file helm-value `app-demo-value.yaml` như sau:**

- Tăng số replicas lên thành 4 Pod
- Enable ingress => Sẽ tạo ra một resource mới là ingress

**Thông tin cập nhật:**

```
replicaCount: 4
```

```
ingress:
  enabled: true
  className: "local"
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  hosts:
    - host: demo-helm.prod.viettq.com
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
```

**Sau đó commit thay đổi lên `config repo` và chờ xem kết quả ở ArgoCD**.

**Argo đã báo cho chúng ta 3 vấn đề:**

- resource ingress `demo-app2-app-demo` có khai báo trên Git nhưng chưa tồn tại trên k8s
- resource deployment `demo-app2-app-demo` đang bị mất đồng bộ.

**Chúng ta có thể kiểm tra chi tiết sự mất đồng bộ ở đây là những tham số nào bằng cách chọn vào resource đó chọn diff:**

**Ta có thể ấn `SYNC` ở application để cập nhật thay đổi của tất cả resource của hệ thống:**

Lúc này 1 Pod mới sẽ được tạo ra để đảm bảo đúng số lượng Pod là 4 (như khai báo trên git) và 1 ingress mới được tạo ra:

### Trường hợp thay đổi resource trên k8s

Tiếp tục bjo nếu ta thay đổi cấu hình các resource trên k8s thì ArgoCD sẽ phát hiện và cảnh báo.

**Mình sẽ thực hiện như sau:**

- Scale số Pod về 1

```
k -n demo2 scale deployment demo-app2-app-demo --replicas 1
```

- Đổi cấu hình service về ClusterIP

```
kubectl -n demo2 patch svc demo-app2-app-demo --type='json' -p '[{"op":"replace","path":"/spec/type","value":"ClusterIP"},{"op":"replace","path":"/spec/ports/0/nodePort","value":null}]'
```

**Kiểm tra trên ArgoCD sẽ phát hiện ra ngay 2 resource bị mất đồng bộ là service và deployment:**

**Chi tiết thay đổi của service:**

**Chi tiết thay đổi của deployment:**

**Và ta chỉ việc đơn giản SYNC lại ứng dụng để đưa hệ thóng về lại đúng trạng thái mà ta mong muốn (là trạng thái theo cấu hình lưu trên Git):**

## Tổng kết

Bài viết này khá dài nhưng hy vọng mọi người sẽ có cái nhìn rõ hơn về Gitops cũng như các ý tưởng xử lý trong luồng này. Bởi nó sẽ không bị bó buộc bởi một công cụ cụ thể nào cả, các bạn có thể linh động sử dụng các công cụ khác mà bản thân thấy quen dùng hơn.

**Qua nội dung bài này có thể gợi mở cho các bạn tìm hiểu thêm nhiều chủ đề khác nữa như:**

- Công cụ Gitops tương tự ArgoCD (FluxCD
- Các công cụ CI khác ngoài Jenkins (gitlab..)
- Phân quyền trên ArgoCD
- Quản lý phiên bản, rollback bằng ArgoCD..
- Sử dụng file deployment manifest thay vì dùng helmchart..

***Cảm ơn mọi người đã dành thời gian đọc tới đây. Nếu thấy bài viết hữu ích thì cho mình xin 1 upvote cho bài viết để tiếp tục ra nhiều nội dung mới nhé!***
