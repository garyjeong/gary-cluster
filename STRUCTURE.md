# Gary Cluster 프로젝트 구조

이 문서는 gary-cluster 프로젝트의 디렉토리 구조와 각 파일의 역할을 설명합니다.

## 📁 전체 디렉토리 구조

```
gary-cluster/
├── README.md                           # 프로젝트 개요 및 가이드
├── TODO.md                             # 단계별 체크리스트
├── STRUCTURE.md                        # 프로젝트 구조 설명 (현재 파일)
│
├── clusters/                           # EKS 클러스터 설정
│   ├── cluster-config.yaml             # eksctl 클러스터 생성 설정 (복합)
│   └── cluster-simple.yaml             # 간소화된 클러스터 설정 (실제 사용)
│
├── controllers/                        # 쿠버네티스 컨트롤러 설정
│   ├── aws-load-balancer/              # AWS Load Balancer Controller
│   │   └── values.yaml                 # Helm values 설정
│   ├── external-dns/                   # ExternalDNS 컨트롤러
│   │   └── values.yaml                 # Helm values 설정
│   └── cert-manager/                   # cert-manager (TLS 인증서)
│       ├── values.yaml                 # Helm values 설정
│       └── cluster-issuer.yaml         # Let's Encrypt ClusterIssuer
│
├── applications/                       # 애플리케이션 매니페스트
│   ├── namespaces/                     # 네임스페이스 정의
│   │   └── environments.yaml           # dev, prod, gary-apps 네임스페이스
│   ├── ingress/                        # Ingress 리소스 (추후 추가)
│   └── smoke-test/                     # 테스트 애플리케이션
│       └── hello-world.yaml            # 스모크 테스트용 Hello World
│
├── environments/                       # 환경별 설정 (Kustomize)
│   ├── dev/                            # 개발 환경
│   │   └── kustomization.yaml          # 개발 환경 Kustomize 설정
│   └── prod/                           # 프로덕션 환경
│       └── kustomization.yaml          # 프로덕션 환경 Kustomize 설정
│
├── ecr/                                # ECR 리포지토리 설정
│   └── repositories.yaml               # ECR 리포지토리 목록 및 정책
│
├── gitops/                             # GitOps 설정 (Argo CD)
│   ├── argocd/                         # Argo CD 설치 설정 (추후 추가)
│   ├── applications/                   # Application 정의
│   │   └── namespaces-app.yaml         # 네임스페이스, 스모크테스트 등 앱
│   └── app-of-apps/                    # App-of-Apps 패턴
│       └── root-app.yaml               # 루트 애플리케이션
│
└── scripts/                            # 유틸리티 스크립트
    ├── cluster-up.sh                   # 클러스터 시작 (노드 스케일 업)
    ├── cluster-down.sh                 # 클러스터 중지 (노드 스케일 다운)
    ├── cost-report.sh                  # 비용 리포트 생성
    └── update-aws-auth.sh              # aws-auth ConfigMap 매핑(eksctl 기반)
```

## 🔍 주요 파일 설명

### 클러스터 설정

- **`clusters/cluster-config.yaml`**: EKS 클러스터 생성을 위한 eksctl 설정 (복합)
  - t4g.small SPOT 인스턴스 (ARM64)
  - IRSA 설정 (ALB Controller, ExternalDNS, cert-manager)
  - CloudWatch 로깅 등 고급 설정 포함
- **`clusters/cluster-simple.yaml`**: 간소화된 클러스터 설정 (실제 사용)
  - 기본적인 설정만 포함
  - 호환성 문제 해결을 위해 단순화

### 실제 적용된 방법 (2025.09.08)

**클러스터 생성**:

```bash
# EKS 클러스터 생성 (Control Plane + OIDC)
eksctl create cluster \
  --name gary-cluster \
  --region ap-northeast-2 \
  --version 1.32 \
  --with-oidc \
  --without-nodegroup
```

**노드 그룹 생성**:

```bash
# AWS CLI로 노드 그룹 직접 생성
aws eks create-nodegroup \
  --cluster-name gary-cluster \
  --nodegroup-name gary-nodes \
  --subnets subnet-xxx subnet-yyy subnet-zzz \
  --node-role arn:aws:iam::ACCOUNT:role/EKS-NodeGroup-Role \
  --instance-types t3.small \
  --scaling-config minSize=0,maxSize=2,desiredSize=1
```

### 컨트롤러 설정

- **`controllers/aws-load-balancer/values.yaml`**: ALB Controller Helm 설정 ✅ **설치 완료**
- **`controllers/external-dns/values.yaml`**: ExternalDNS 설정 (garyzone.pro) ✅ **설치 완료**
- **`controllers/cert-manager/`**: TLS 인증서 자동 관리 🔄 **설치 진행 중**
  - `values.yaml`: cert-manager Helm 설정 (nodeSelector 제거됨)
  - `cluster-issuer.yaml`: Let's Encrypt ClusterIssuer (생성 완료)

### 애플리케이션

- **`applications/namespaces/environments.yaml`**: 환경별 네임스페이스 ✅ **생성 완료** (dev, prod, gary-apps)
- **`applications/smoke-test/hello-world.yaml`**: 테스트용 애플리케이션 ✅ **배포 완료**
  - hello.dev.garyzone.pro 도메인으로 접근 설정
  - cert-manager를 통한 자동 TLS 인증서 발급 설정

### GitOps 설정

- **`gitops/app-of-apps/root-app.yaml`**: Argo CD 루트 애플리케이션
- **`gitops/applications/`**: 개별 애플리케이션 정의

### 환경별 설정

- **`environments/dev/`**: 개발 환경 Kustomize 설정
- **`environments/prod/`**: 프로덕션 환경 Kustomize 설정

### 유틸리티 스크립트

- **`scripts/cluster-up.sh`**: 노드 스케일 업 (0→1)
- **`scripts/cluster-down.sh`**: 노드 스케일 다운 (→0), 비용 절약
- **`scripts/cost-report.sh`**: 실시간 비용 리포트

## 🚀 사용 워크플로

### 1. 초기 설정 (실제 적용된 순서)

```bash
# 1. 클러스터 생성
eksctl create cluster --name gary-cluster --region ap-northeast-2 --version 1.32 --with-oidc --without-nodegroup

# 2. Route53 Hosted Zone 생성
aws route53 create-hosted-zone --name garyzone.pro --caller-reference gary-cluster-20250908

# 3. AWS Load Balancer Controller 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -f controllers/aws-load-balancer/values.yaml -n kube-system

# 4. ExternalDNS 설치 (IRSA 설정 포함)
helm install external-dns external-dns/external-dns \
  -f controllers/external-dns/values.yaml -n kube-system

# 5. cert-manager 설치
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --values controllers/cert-manager/values.yaml
kubectl apply -f controllers/cert-manager/cluster-issuer.yaml
```

### 2. 일상 운영

```bash
# 개발 시작
./scripts/cluster-up.sh

# 작업 완료 후 비용 절약
./scripts/cluster-down.sh

# 비용 확인
./scripts/cost-report.sh
```

### 3. GitOps 배포

```bash
# Argo CD 설치 후
kubectl apply -f gitops/app-of-apps/root-app.yaml
```

## 📦 ECR 리포지토리

프로젝트에서 관리하는 7개의 ECR 리포지토리:

1. **hair-model-creator** - AI 헤어 모델링 서비스
2. **household-ledger** - 가계부 관리 애플리케이션
3. **gary-saju-service** - 사주 분석 서비스
4. **spark-prompt** - AI 프롬프트 최적화 도구
5. **liview-backend** - LiView 백엔드 API
6. **react-wedding-invitation-letter** - 모바일 청첩장 서비스
7. **liview-frontend** - LiView 프론트엔드

## 🔒 보안 고려사항

- **IRSA**: IAM 역할을 ServiceAccount에 연결하여 최소 권한 원칙 적용
- **TLS**: 모든 외부 트래픽은 HTTPS로 암호화
- **Network Policy**: 파드 간 통신 제어 (추후 구현)
- **Secret 관리**: 민감 정보는 Kubernetes Secret으로 관리

## 💰 비용 최적화

- **온디맨드 인스턴스**: t3.small 사용 (현재 구성)
- **노드 스케일링**: 미사용 시 0대로 스케일 다운 (`kubectl scale` 또는 `eksctl scale`)
- **리소스 제한**: 모든 파드에 적절한 리소스 제한 설정
- **파드 개수 최적화**: CoreDNS 등 시스템 컴포넌트 replicas 최소화 (1개)
- **Life cycle 정책**: ECR 이미지 자동 정리

## 🔧 해결된 주요 이슈

- **파드 스케줄링 오류**: `nodeSelector: kubernetes.io/arch=arm64` 제거 (x86 노드와 불일치)
- **파드 용량 한계**: t3.small 최대 11개 파드 제한, CoreDNS replica 축소로 해결
- **cert-manager 설치 이슈**: Helm values.yaml 스키마 불일치 해결

---

이 구조는 GitOps 방식으로 쿠버네티스를 관리하며, 비용 효율성과 보안을 동시에 고려하여 설계되었습니다.
