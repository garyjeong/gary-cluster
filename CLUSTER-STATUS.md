# 오늘 작업 요약 (2025-09-22)

- Argo CD 재설치 및 정상화: 모든 컴포넌트 Running
- EKS 노드 확장: 새 노드그룹 `gary-nodes-large`(t3.large) 추가, 기존 `t3.small` 노드그룹 제거
- 네트워크 수정: Private 서브넷 라우팅에 NAT 게이트웨이 경로(0.0.0.0/0 → NAT) 추가로 외부 통신 복구
- GitOps 복구: `root-app` 및 하위 앱(repoURL 오너 `garyjeong`로 정정), 동기화 정상화
- ArgoCD UI 노출: ALB Ingress 생성 및 도메인 연결
  - HTTP 임시 개방 → ACM 와일드카드(`*.garyzone.pro`, `garyzone.pro`) 발급 완료 후 HTTPS 활성화(80→443 리다이렉트)
  - 접근: https://argocd.garyzone.pro
- ExternalDNS 레코드 자동 생성 확인(가용)
- 서비스 상태 대시보드: `service-status` 앱 동기화 정상, Ingress/ALB 동작(HTTPS 연동 예정)
- 청소: 임시 파일 `.argo-cm.yaml` 제거

---

# Gary Cluster 현재 상태 리포트

> **2025년 9월 10일 기준 - EKS 클러스터 완전 구축 및 운영 상태**

## 📊 전체 클러스터 상태 요약

### ✅ **완전히 정상 가동 중**

- **EKS 클러스터**: gary-cluster (v1.32.8-eks-99d6cc0) - 완전 가동
- **노드 그룹**: gary-nodes (t3.small, 1노드, amd64) - Ready 상태
- **핵심 인프라**: 100% 가동 (로드밸런서, DNS, 인증서 관리)
- **시스템 파드**: 11개 모두 Running (t3.small 최대 제한 도달)

### ⚠️ **제한 상황**

- **파드 개수**: 11개 (t3.small 최대 제한) - **포화 상태**
- **애플리케이션 배포**: 새 파드 스케줄링 불가
- **Argo CD**: 일부 파드만 가동 (공간 부족)

## 🏗️ 인프라 구성 상세

### EKS 클러스터 정보

````text
클러스터명: gary-cluster
Kubernetes 버전: v1.32.8-eks-99d6cc0
리전: ap-northeast-2 (Seoul)
노드 그룹: gary-nodes
인스턴스 타입: t3.small (2 vCPU, 2GB RAM)
아키텍처: amd64
상태: Ready (2d23h)
```text

### 네트워킹 및 DNS

```bash
VPC: vpc-0e812b43bb30b0201 (3 AZ, 6 서브넷)
Route53 호스팅 존: garyzone.pro (Z0394568WTSPBSC5SBHO)
도메인 관리: ExternalDNS 연동 완료 (Route53)
ALB/Ingress 상태:
````

Ingress(dev/service-status-ingress): k8s-dev-services-b29f9e82ee-1928776017.ap-northeast-2.elb.amazonaws.com
Route53: A/AAAA Alias → 위 ALB 호스트명
권장: 등록기관(NS)을 Route53 NS로 위임하여 전 세계 조회 일치

```bash
로드밸런서: AWS Load Balancer Controller 가동
```

### 인증서 관리

```
cert-manager: 3개 파드 모두 Running
ClusterIssuer: letsencrypt-prod, letsencrypt-staging 생성
IRSA: Route53 권한 부여 완료
현재 상태: staging 환경에서 DNS 전파 대기 중
```

## 📋 현재 파드 배치 상황 (11/11)

### 🔧 시스템 파드 (6개)

```
NAMESPACE      NAME                                    STATUS      ROLE
kube-system    aws-node-gshhd                         Running     네트워킹 (2/2)
kube-system    coredns-844d8f59bb-z8629              Running     DNS
kube-system    kube-proxy-rzqwm                       Running     프록시
kube-system    metrics-server-67b599888d-wscwz        Running     메트릭
kube-system    aws-load-balancer-controller-*         Running     ALB
kube-system    external-dns-b96d8b65f-lfgc6           Running     Route53 연동
```

### 🔒 cert-manager (3개)

```
NAMESPACE      NAME                                    STATUS      ROLE
cert-manager   cert-manager-75f6c48f97-mn4c5          Running     컨트롤러
cert-manager   cert-manager-cainjector-*              Running     CA 주입기
cert-manager   cert-manager-webhook-*                 Running     웹훅
```

### 🚀 GitOps (2개 가동 중)

```
NAMESPACE      NAME                                    STATUS      ROLE
argocd         argocd-applicationset-controller-*     Running     앱셋 컨트롤러
argocd         argocd-dex-server-*                    Running     인증 서버
```

### ❌ Pending 파드들 (공간 부족)

```
dev            hello-world-*                          Pending     테스트 앱
argocd         argocd-application-controller-0        Pending     앱 컨트롤러
argocd         argocd-redis-*                         Pending     Redis
argocd         argocd-repo-server-*                   Pending     Git 서버
argocd         argocd-server-*                        Pending     UI 서버
```

## 🔧 주요 해결된 문제들

### 1. **ServiceAccount 누락 문제**

**현상**: cert-manager 컨트롤러 파드가 시작되지 않음

```yaml
# 해결: controllers/cert-manager/values.yaml
serviceAccount:
  create: true # false에서 true로 변경
  name: cert-manager
```

### 2. **IRSA 권한 부족 문제**

**현상**: DNS Challenge에서 Route53 접근 실패

```bash
# 해결: cert-manager용 IRSA 생성
eksctl create iamserviceaccount \
  --cluster=gary-cluster \
  --namespace=cert-manager \
  --name=cert-manager \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonRoute53FullAccess \
  --override-existing-serviceaccounts \
  --approve
```

### 3. **메모리 부족 문제**

**현상**: 새 파드가 Pending 상태

```bash
# 해결: metrics-server replica 축소
kubectl -n kube-system scale deployment metrics-server --replicas=1
```

### 4. **파드 개수 제한 문제**

**현상**: `Too many pods` 오류 (t3.small 최대 11개)

```bash
# 해결: 불필요한 replica 축소
kubectl -n kube-system scale deployment aws-load-balancer-controller --replicas=1
# hello-world replica 2→1로 축소
```

### 5. **아키텍처 불일치 문제**

**현상**: arm64 nodeSelector vs amd64 노드

```yaml
# 해결: nodeSelector 제거
# nodeSelector:
#   kubernetes.io/arch: arm64  # 제거됨
```

## 💰 현재 비용 구조

### 월 예상 비용

- **EKS Control Plane**: $72/월 ($0.10/시간)
- **t3.small 노드**: ~$30/월 (온디맨드)
- **Route53 Hosted Zone**: $0.50/월
- **총 예상 비용**: **~$104.50/월**

### 비용 절약 방법

```bash
# 노드 중지 (Control Plane만 유지)
./scripts/cluster-down.sh  # → $72/월

# 노드 시작 (개발 시)
./scripts/cluster-up.sh

# 비용 리포트
./scripts/cost-report.sh
```

## 🎯 현재 제약사항 및 해결방안

### 주요 제약사항

1. **파드 개수 제한**: t3.small 최대 11개
2. **메모리 제한**: 2GB RAM
3. **애플리케이션 배포 불가**: 새 파드 스케줄링 공간 없음

### 해결방안

#### 즉시 적용 가능

```bash
# 1. 불필요한 Argo CD 파드 비활성화
kubectl -n argocd scale deployment argocd-notifications-controller --replicas=0

# 2. 기존 Pending 파드 정리
kubectl -n dev delete deployment hello-world
kubectl -n argocd delete statefulset argocd-application-controller
```

#### 확장 옵션 (비용 증가)

```bash
# 1. 노드 추가 (비용 2배)
aws eks update-nodegroup-config \
  --cluster-name gary-cluster \
  --nodegroup-name gary-nodes \
  --scaling-config minSize=0,maxSize=3,desiredSize=2

# 2. 인스턴스 타입 업그레이드
# t3.small → t3.medium (더 많은 파드 지원)
```

## 🔍 모니터링 및 상태 확인

### 일상적인 상태 확인

```bash
# 클러스터 전체 상태
kubectl get nodes
kubectl get pods -A

# 파드 개수 확인
kubectl get pods -A --no-headers | wc -l

# 리소스 사용량
kubectl describe node | grep -A 15 "Allocated resources"

# cert-manager 상태
kubectl -n cert-manager get pods
kubectl get clusterissuer
kubectl -n dev get certificate,order,challenge
```

### TLS 인증서 발급 상태

```bash
# 현재 진행 상황
kubectl -n dev describe challenge [challenge-name]

# Route53 DNS 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0394568WTSPBSC5SBHO \
  --query 'ResourceRecordSets[?contains(Name, `_acme-challenge`)]'

# DNS 전파 확인
dig _acme-challenge.hello.dev.garyzone.pro TXT +short
```

## 🚀 다음 단계 권장사항

### 우선순위 1: TLS 인증서 완료

1. DNS 전파 완료 대기 (백그라운드 진행 중)
2. 인증서 발급 확인 후 브라우저 테스트
3. staging → production 환경 전환

### 우선순위 2: 파드 공간 확보

1. 불필요한 서비스 정리
2. hello-world 애플리케이션 배포 완료
3. 기본 스모크 테스트 성공

### 우선순위 3: 확장 고려

1. 노드 추가 또는 인스턴스 업그레이드
2. Argo CD 완전 활성화
3. 추가 애플리케이션 배포

## 💡 운영 팁

### 파드 제한 환경에서의 최적화

1. **단일 replica 원칙**: 개발 환경에서는 모든 서비스 1개씩
2. **선택적 서비스**: 필수가 아닌 서비스는 비활성화
3. **리소스 제한**: 모든 파드에 적절한 limits/requests 설정

### 트러블슈팅 순서

1. **파드 상태 확인**: `kubectl get pods -A`
2. **이벤트 확인**: `kubectl describe pod [pod-name]`
3. **로그 확인**: `kubectl logs [pod-name]`
4. **리소스 확인**: `kubectl describe node`

### 비용 최적화

1. **일일 운영**: 사용 시에만 노드 활성화
2. **주말/야간**: 노드 완전 중지
3. **모니터링**: 정기적인 비용 리포트 확인

---

**📅 리포트 날짜**: 2025년 9월 10일  
**⏰ 마지막 업데이트**: 20:50 KST  
**📊 클러스터 상태**: 핵심 인프라 100% 가동, 파드 제한으로 확장 제약  
**🎯 다음 목표**: TLS 인증서 발급 완료 및 스모크 테스트 성공

## 🔐 접근 권한 업데이트 (2025-09-11)

- AWS CLI 자격 증명 재설정 후, `eks:DescribeCluster` 권한 부재로 kubeconfig 갱신 실패 → 인라인 정책으로 `eks:DescribeCluster`, `eks:ListClusters` 허용하여 해결
- kubectl 인증 문제는 클러스터 RBAC 미매핑이 원인 → 다음 중 하나로 해결 가능:
  - 권장: EKS Access Entry에서 Principal(사용자/역할)에 Admin(Cluster) 부여
  - 대안: `aws-auth` ConfigMap에 사용자/역할 매핑. 제공 스크립트 사용:
    ```bash
    ./scripts/update-aws-auth.sh \
      --cluster gary-cluster \
      --region ap-northeast-2 \
      --roles arn:aws:iam::014125597282:role/EKS-ClusterAdmin \
      --users arn:aws:iam::014125597282:user/gary-wemeet-macbook \
      --group system:masters
    ```
  - 여러 위치에서 접근 필요 시: 공유 역할을 생성하고 신뢰 정책에 외부 계정/Organization을 허용한 뒤, 그 역할 ARN을 Access Entry 또는 aws-auth에 등록
