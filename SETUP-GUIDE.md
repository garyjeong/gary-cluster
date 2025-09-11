# Gary Cluster 구축 가이드

> **EKS 최소비용 구축 + cert-manager TLS 자동 발급 완전 가이드**

## 📋 개요

이 문서는 AWS EKS 클러스터에서 cert-manager를 사용한 TLS 인증서 자동 발급까지의 전체 구축 과정을 기록합니다.

### 🎯 구축 목표

- AWS EKS 클러스터 (최소 비용)
- AWS Load Balancer Controller
- ExternalDNS (Route53 연동)
- cert-manager (Let's Encrypt TLS 자동 발급)
- 스모크 테스트 애플리케이션

### 💰 예상 비용

- **EKS Control Plane**: $72/월 ($0.10/시간)
- **Worker Node**: t3.small (~$30/월, 온디맨드)
- **Route53 Hosted Zone**: $0.50/월
- **총 예상 비용**: ~$104.50/월

## 🚀 1단계: 사전 준비

### 필수 도구 설치 (macOS)

```bash
# 필수 도구 설치
brew install awscli eksctl helm kubectl

# AWS 인증 설정
aws configure

# 권한 확인
aws sts get-caller-identity
```

### 환경 정보

- **리전**: ap-northeast-2 (Seoul)
- **도메인**: garyzone.pro
- **노드 타입**: t3.small (실제 구성)
- **Kubernetes 버전**: v1.32

## 🏗️ 2단계: EKS 클러스터 생성

### 클러스터 생성 (실제 적용된 방법)

```bash
# 1. EKS 클러스터 생성 (Control Plane + OIDC)
eksctl create cluster \
  --name gary-cluster \
  --region ap-northeast-2 \
  --version 1.32 \
  --with-oidc \
  --without-nodegroup

# 2. 노드 그룹 생성 (AWS CLI 직접 사용)
aws eks create-nodegroup \
  --cluster-name gary-cluster \
  --nodegroup-name gary-nodes \
  --subnets subnet-xxx subnet-yyy subnet-zzz \
  --node-role arn:aws:iam::ACCOUNT:role/EKS-NodeGroup-Role \
  --instance-types t3.small \
  --scaling-config minSize=0,maxSize=2,desiredSize=1

# 3. kubeconfig 업데이트
aws eks update-kubeconfig --region ap-northeast-2 --name gary-cluster

# 4. 클러스터 상태 확인
kubectl get nodes
kubectl get pods -A
```

## 🌐 3단계: AWS Load Balancer Controller 설치

### IRSA 생성 및 ALB Controller 설치

```bash
# 1. IRSA 생성 (eksctl 사용)
eksctl create iamserviceaccount \
  --cluster=gary-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name EKS-ALB-Controller-Role \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --approve

# 2. Helm 리포지토리 추가
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# 3. ALB Controller 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -f controllers/aws-load-balancer/values.yaml \
  -n kube-system

# 4. 설치 확인
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
```

## 🔗 4단계: ExternalDNS 설치

### Route53 Hosted Zone 생성 및 ExternalDNS 설정

```bash
# 1. Route53 Hosted Zone 생성
aws route53 create-hosted-zone \
  --name garyzone.pro \
  --caller-reference gary-cluster-$(date +%Y%m%d)

# 2. ExternalDNS용 IRSA 생성
eksctl create iamserviceaccount \
  --cluster=gary-cluster \
  --namespace=kube-system \
  --name=external-dns \
  --role-name EKS-ExternalDNS-Role \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonRoute53FullAccess \
  --approve

# 3. Helm 리포지토리 추가
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

# 4. ExternalDNS 설치
helm install external-dns external-dns/external-dns \
  -f controllers/external-dns/values.yaml \
  -n kube-system

# 5. 설치 확인
kubectl -n kube-system get pods -l app.kubernetes.io/name=external-dns
```

## 🔒 5단계: cert-manager 설치 및 설정

### cert-manager 설치

```bash
# 1. cert-manager 네임스페이스 생성
kubectl create namespace cert-manager

# 2. Helm 리포지토리 추가
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 3. cert-manager 설치
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --values controllers/cert-manager/values.yaml

# 4. 설치 확인
kubectl -n cert-manager get pods
```

### 🚨 주요 트러블슈팅 과정

#### 문제 1: ServiceAccount 누락

**현상**: cert-manager 컨트롤러 파드가 시작되지 않음

```bash
# 문제 확인
kubectl -n cert-manager get pods -l app=cert-manager
# No resources found

# 원인 확인
kubectl -n cert-manager get serviceaccount
# cert-manager ServiceAccount 없음
```

**해결**: values.yaml에서 ServiceAccount 생성 활성화

```yaml
# controllers/cert-manager/values.yaml
serviceAccount:
  create: true # false에서 true로 변경
  name: cert-manager
```

#### 문제 2: IRSA 권한 부족

**현상**: DNS Challenge에서 Route53 접근 실패

```bash
# 오류 확인
kubectl -n dev describe challenge [challenge-name]
# Error: no EC2 IMDS role found, operation error ec2imds
```

**해결**: cert-manager용 IRSA 생성

```bash
# IRSA 생성
eksctl create iamserviceaccount \
  --cluster=gary-cluster \
  --namespace=cert-manager \
  --name=cert-manager \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonRoute53FullAccess \
  --override-existing-serviceaccounts \
  --approve

# cert-manager 파드 재시작
kubectl -n cert-manager rollout restart deployment cert-manager
```

#### 문제 3: 메모리 부족

**현상**: 새 파드가 Pending 상태

```bash
# 노드 리소스 확인
kubectl describe node [node-name]
# memory: 1340Mi (94%) - 메모리 한계 도달
```

**해결**: metrics-server replica 축소

```bash
# metrics-server replica 축소
kubectl -n kube-system scale deployment metrics-server --replicas=1
```

### ClusterIssuer 설정

```bash
# 1. 이메일 주소 설정 (실제 이메일로 변경)
sed -i '' 's/YOUR_EMAIL@garyzone\.pro/jeonggaryaws@gmail.com/g' \
  controllers/cert-manager/cluster-issuer.yaml

# 2. ClusterIssuer 적용
kubectl apply -f controllers/cert-manager/cluster-issuer.yaml

# 3. 확인
kubectl get clusterissuer
```

## 📱 6단계: 네임스페이스 및 스모크 테스트

### 네임스페이스 생성

```bash
# 네임스페이스 생성
kubectl apply -f applications/namespaces/environments.yaml

# 확인
kubectl get namespaces dev prod gary-apps
```

### Hello World 애플리케이션 배포

```bash
# 스모크 테스트 애플리케이션 배포
kubectl apply -f applications/smoke-test/hello-world.yaml

# 배포 확인
kubectl -n dev get deployment,service,ingress
```

## 🔐 7단계: TLS 인증서 자동 발급

### 인증서 발급 과정 모니터링

```bash
# 1. Certificate 상태 확인
kubectl -n dev get certificate hello-world-tls

# 2. Order 및 Challenge 확인
kubectl -n dev get order,challenge

# 3. Challenge 상세 상태 확인
kubectl -n dev describe challenge [challenge-name]

# 4. Route53 DNS 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0394568WTSPBSC5SBHO \
  --query 'ResourceRecordSets[?contains(Name, `_acme-challenge`)]'

# 5. DNS 전파 확인
dig _acme-challenge.hello.dev.garyzone.pro TXT +short
nslookup -type=TXT _acme-challenge.hello.dev.garyzone.pro 8.8.8.8
```

### 인증서 발급 완료 확인

```bash
# Secret 생성 확인
kubectl -n dev get secret hello-world-tls

# 인증서 내용 확인
kubectl -n dev get secret hello-world-tls -o yaml

# 브라우저 테스트
# https://hello.dev.garyzone.pro
```

## 🔧 8단계: 운영 관리

### 비용 절약 스크립트

```bash
# 클러스터 시작 (노드 0→1)
./scripts/cluster-up.sh

# 클러스터 중지 (노드→0)
./scripts/cluster-down.sh

# 비용 리포트
./scripts/cost-report.sh
```

### 상태 모니터링

```bash
# 전체 상태 확인
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A

# cert-manager 상태 확인
kubectl -n cert-manager get pods
kubectl get clusterissuer

# 인증서 상태 확인
kubectl get certificates -A
```

## 📊 구축 결과

### ✅ 완료된 구성요소

- **EKS 클러스터**: gary-cluster (v1.32)
- **노드 그룹**: gary-nodes (t3.small, 1노드)
- **AWS Load Balancer Controller**: 정상 동작
- **ExternalDNS**: Route53 연동 완료
- **cert-manager**: TLS 자동 발급 설정 완료
- **Route53 DNS**: garyzone.pro 호스팅 존
- **네임스페이스**: dev, prod, gary-apps
- **스모크 테스트**: hello-world 애플리케이션 배포

### ⏳ 진행 중

- **TLS 인증서 발급**: DNS 전파 대기 중
- **GitOps 설정**: Argo CD 설치 예정

### 🔍 주요 해결된 문제들

1. **ServiceAccount 누락** → create: true로 설정
2. **IRSA 권한 부족** → Route53 권한 부여
3. **메모리 부족** → metrics-server replica 축소
4. **DNS 전파 지연** → 정상적인 과정 (5-10분 소요)

## 📝 설정 파일 요약

### controllers/cert-manager/values.yaml

```yaml
installCRDs: true
serviceAccount:
  create: true # 중요: true로 설정
  name: cert-manager
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

### controllers/cert-manager/cluster-issuer.yaml

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: jeonggaryaws@gmail.com # 실제 이메일
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - dns01:
          route53:
            region: ap-northeast-2
        selector:
          dnsZones:
            - "garyzone.pro"
```

### applications/smoke-test/hello-world.yaml (Ingress 부분)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
  namespace: dev
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    cert-manager.io/cluster-issuer: letsencrypt-prod # cert-manager 연동
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    external-dns.alpha.kubernetes.io/hostname: hello.dev.garyzone.pro
spec:
  rules:
    - host: hello.dev.garyzone.pro
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-world-service
                port:
                  number: 80
  tls:
    - hosts:
        - hello.dev.garyzone.pro
      secretName: hello-world-tls # cert-manager가 생성할 Secret
```

## 🎯 다음 단계

### GitOps (Argo CD) 설정

```bash
# 1. Argo CD 설치
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. GitHub 리포지토리 URL 수정
sed -i '' 's/USERNAME/your-github-username/g' \
  gitops/app-of-apps/root-app.yaml \
  gitops/applications/namespaces-app.yaml

# 3. App-of-Apps 적용
kubectl apply -f gitops/app-of-apps/root-app.yaml
```

## 💡 교훈 및 팁

### 1. 메모리 관리

- t3.small (2GB RAM)에서는 파드 개수 제한 주의
- metrics-server, coredns 등 시스템 파드가 많은 메모리 사용
- 불필요한 replica 축소 권장

### 2. cert-manager 설정

- ServiceAccount는 반드시 생성 필요
- IRSA 권한 설정이 핵심 (Route53 접근)
- DNS 전파는 시간이 걸리는 정상적인 과정

### 3. 비용 최적화

- 개발 시에만 노드 활성화
- 사용 후 즉시 노드 스케일 다운
- SPOT 인스턴스 사용으로 비용 절약

### 4. 트러블슈팅 접근법

- 파드 상태 → 이벤트 → 로그 순서로 확인
- RBAC, IRSA 권한 문제가 가장 빈번
- 리소스 부족 문제 항상 염두

---

**📅 작성일**: 2025년 9월 10일  
**👤 작성자**: Gary  
**🔄 최종 업데이트**: EKS 접근 권한 설정(Access Entry/`aws-auth` 스크립트) 가이드 추가

---

## 🔐 부록: kubectl 접근 권한 설정 가이드

### A. EKS Access Entry (권장)

콘솔 경로: EKS → 클러스터 → Access → Grant access

- Principal: 접근시킬 IAM User/Role ARN
- Access policy: Admin(Cluster) 또는 최소 권한
- Access scope: Cluster

### B. aws-auth ConfigMap (대안, 스크립트 제공)

스크립트: `scripts/update-aws-auth.sh` (자동 백업 + idempotent)

```bash
./scripts/update-aws-auth.sh \
  --cluster gary-cluster \
  --region ap-northeast-2 \
  --roles arn:aws:iam::014125597282:role/EKS-ClusterAdmin \
  --users arn:aws:iam::014125597282:user/gary-wemeet-macbook \
  --group system:masters
```

여러 위치에서 접근이 필요한 경우에는 공유 역할을 생성하여 신뢰 정책에 외부 계정/Organization을 허용한 뒤, 그 역할 ARN을 Access Entry 또는 aws-auth에 등록합니다.
