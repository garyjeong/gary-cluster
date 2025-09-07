# gary-cluster: EKS 최소비용 구축 + GitOps

최소 비용으로 AWS EKS 클러스터를 구축하고, 도메인 연결, ECR 통합, GitOps 파이프라인을 구현하는 프로젝트입니다.

## 🎯 프로젝트 목표

- **최소 비용 EKS 클러스터** (월 $104 실제 구성)
- **자동 도메인 관리** (\*.garyzone.pro)
- **컨테이너 레지스트리 통합** (ECR 7개 리포지토리)
- **GitOps 기반 배포** (Argo CD App-of-Apps)

## 📊 **현재 구축 상태** (2024.12.19)

### ✅ **완료된 구성요소**
- **EKS 클러스터**: `gary-cluster` (v1.32) 
- **노드 그룹**: `gary-nodes-cli` (t3.small, 1노드)
- **VPC**: `vpc-01b88f5ef0e77510c` (3 AZ, 6 서브넷)
- **IAM 역할**: `EKS-NodeGroup-Role` (완전 구성됨)
- **kubeconfig**: 로컬 설정 완료

### 🔄 **다음 단계**
- AWS Load Balancer Controller 설치
- ExternalDNS 설치 (garyzone.pro 연동)  
- TLS 인증서 설정
- ECR 리포지토리 7개 생성
- 스모크 테스트 및 GitOps 설정

## 🏗️ 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet                                  │
│                       │                                     │
│                ┌──────▼──────┐                              │
│                │   Route53   │ (garyzone.pro)               │
│                │    DNS      │                              │
│                └──────┬──────┘                              │
│                       │                                     │
│                ┌──────▼──────┐                              │
│                │     ACM     │ (*.garyzone.pro)             │
│                │ Certificate │                              │
│                └──────┬──────┘                              │
│                       │                                     │
│ ┌─────────────────────▼────────────────────────────────────┐ │
│ │                   AWS EKS                                │ │
│ │  ┌──────────────┐  ┌─────────────────┐  ┌─────────────┐ │ │
│ │  │     ALB      │  │  ExternalDNS    │  │    ECR      │ │ │
│ │  │ (Ingress)    │  │   Controller    │  │ Registry    │ │ │
│ │  └──────┬───────┘  └─────────────────┘  └─────────────┘ │ │
│ │         │                                               │ │
│ │  ┌──────▼───────────────────────────────────────────┐   │ │
│ │  │              Kubernetes Pods                     │   │ │
│ │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ │   │ │
│ │  │  │ App1    │ │ App2    │ │ App3    │ │ ArgoCD  │ │   │ │
│ │  │  │         │ │         │ │         │ │         │ │   │ │
│ │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ │   │ │
│ │  └─────────────────────────────────────────────────┘   │ │
│ │                                                         │ │
│ │  Node: t4g.small (Graviton/ARM64) + SPOT               │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 📋 환경 정보

### 필수 요구사항

- **OS**: macOS (Apple Silicon M1/M2)
- **Shell**: zsh
- **AWS CLI**: v2.x
- **도구**: eksctl, helm, kubectl
- **AWS 리전**: ap-northeast-2 (Seoul)
- **도메인**: garyzone.pro

### 리소스 사양 (실제 구성 기준)

- **EKS Control Plane**: $0.10/hour ($72/월)
- **Worker Node**: t3.small (2 vCPU, 2GB RAM) 온디맨드
- **스토리지**: 기본 EBS 볼륨
- **실제 월 비용**: ~$104/월 (개발 환경)
  
### 비용 절약 방법
```bash
# 노드를 0대로 스케일 다운 (Control Plane만 유지)
aws eks update-nodegroup-config --cluster-name gary-cluster --nodegroup-name gary-nodes-cli --scaling-config minSize=0,maxSize=2,desiredSize=0

# 필요할 때 노드를 1대로 확장
aws eks update-nodegroup-config --cluster-name gary-cluster --nodegroup-name gary-nodes-cli --scaling-config minSize=0,maxSize=2,desiredSize=1
```

## 🚀 빠른 시작

### 1. 사전 준비

```bash
# 도구 설치 (macOS)
brew install awscli eksctl helm kubectl

# AWS 인증 설정
aws configure

# 권한 확인
aws sts get-caller-identity
```

### 2. 클러스터 생성

#### **실제 적용된 방법 (2024.12.19)**

```bash
# 1. EKS 클러스터 생성 (Control Plane)
eksctl create cluster \
  --name gary-cluster \
  --region ap-northeast-2 \
  --nodes 1 \
  --with-oidc

# 2. IAM 역할 생성 (노드 그룹용)
aws iam create-role --role-name EKS-NodeGroup-Role --assume-role-policy-document file://nodegroup-trust-policy.json
aws iam attach-role-policy --role-name EKS-NodeGroup-Role --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

# 3. 노드 그룹 생성 (AWS CLI 직접 사용)
aws eks create-nodegroup \
  --cluster-name gary-cluster \
  --nodegroup-name gary-nodes-cli \
  --subnets subnet-xxx subnet-yyy subnet-zzz \
  --node-role arn:aws:iam::ACCOUNT:role/EKS-NodeGroup-Role \
  --instance-types t3.small \
  --scaling-config minSize=0,maxSize=2,desiredSize=1
```

### 3. 핵심 컴포넌트 설치

상세한 단계별 가이드는 [TODO.md](./TODO.md)를 참조하세요.

### 4. 주요 설정 변경사항

사용 전 다음 설정들을 실제 값으로 변경해주세요:

- **GitHub 리포지토리**: `gitops/` 폴더의 `USERNAME`을 실제 GitHub 사용자명으로 변경
- **이메일 주소**: `controllers/cert-manager/cluster-issuer.yaml`의 `YOUR_EMAIL`을 실제 이메일로 변경
- **ACM 인증서**: `applications/smoke-test/hello-world.yaml`의 `YOUR_ACCOUNT_ID`, `YOUR_CERT_ID`를 실제 값으로 변경

## 📁 프로젝트 구조

```
gary-cluster/
├── README.md                   # 프로젝트 개요 (현재 파일)
├── TODO.md                     # 단계별 체크리스트
├── clusters/                   # EKS 클러스터 설정
│   └── cluster-config.yaml     # eksctl 클러스터 정의
├── controllers/                # 쿠버네티스 컨트롤러
│   ├── aws-load-balancer/      # ALB Controller 설정
│   ├── external-dns/           # ExternalDNS 설정
│   └── cert-manager/           # TLS 인증서 관리
├── applications/               # 애플리케이션 매니페스트
│   ├── namespaces/            # 네임스페이스 정의
│   ├── ingress/               # Ingress 리소스
│   └── smoke-test/            # 테스트 애플리케이션
├── ecr/                       # ECR 리포지토리 설정
│   └── repositories.yaml      # ECR 리포지토리 목록
├── gitops/                    # GitOps 설정
│   ├── argocd/               # Argo CD 설치
│   ├── applications/         # Application 정의
│   └── app-of-apps/          # App-of-Apps 패턴
└── scripts/                   # 유틸리티 스크립트
    ├── cluster-up.sh         # 클러스터 시작
    ├── cluster-down.sh       # 클러스터 중지
    └── cost-report.sh        # 비용 리포트
```

## 🔧 운영 가이드

### 비용 절약 팁

```bash
# 노드를 0대로 스케일 다운 (비용 절약)
eksctl scale nodegroup --cluster=gary-cluster --name=gary-nodes --nodes=0

# 필요할 때 노드를 1대로 확장
eksctl scale nodegroup --cluster=gary-cluster --name=gary-nodes --nodes=1

# 클러스터 완전 삭제
eksctl delete cluster --name=gary-cluster
```

### 상태 확인

```bash
# 클러스터 상태
kubectl get nodes
kubectl get pods -A

# Ingress 및 서비스 상태
kubectl get ingress -A
kubectl get svc -A

# 비용 관련 리소스 확인
aws eks describe-cluster --name gary-cluster
aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=gary-cluster"
```

## 📦 ECR 리포지토리 목록

프로젝트에서 사용하는 7개의 ECR 리포지토리:

1. **hair-model-creator** - AI 헤어 모델링 서비스
2. **household-ledger** - 가계부 관리 애플리케이션
3. **gary-saju-service** - 사주 분석 서비스
4. **spark-prompt** - AI 프롬프트 최적화 도구
5. **liview-backend** - LiView 백엔드 API
6. **react-wedding-invitation-letter** - 모바일 청첩장 서비스
7. **liview-frontend** - LiView 프론트엔드

### ECR 접근

```bash
# ECR 로그인 (ACCOUNT_ID를 실제 AWS Account ID로 변경)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드 및 푸시 예시
docker build -t hair-model-creator .
docker tag hair-model-creator:latest $ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com/hair-model-creator:latest
docker push $ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com/hair-model-creator:latest
```

## 🔒 보안 및 권한

### IRSA (IAM Roles for Service Accounts)

- AWS Load Balancer Controller용 역할
- ExternalDNS용 Route53 접근 역할
- cert-manager용 Route53 DNS-01 역할

### 네트워크 보안

- Security Group: 필요한 포트만 개방
- Network Policy: 파드 간 통신 제어
- TLS/HTTPS: 모든 외부 트래픽 암호화

## 🚨 주의사항

1. **비용 모니터링**: AWS Cost Explorer로 일일 비용 확인
2. **리소스 정리**: 사용 후 반드시 노드 스케일 다운
3. **보안 업데이트**: 정기적인 EKS, 컨트롤러 버전 업데이트
4. **백업**: 중요한 설정은 별도 백업 유지

## 📞 지원 및 기여

- **이슈 리포팅**: GitHub Issues 활용
- **기여 가이드**: CONTRIBUTING.md 참조 (예정)
- **라이센스**: MIT License

---

**🎯 목표**: 개발자 친화적이고 비용 효율적인 EKS 환경 구축  
**📅 마지막 업데이트**: 2024년 12월  
**👤 관리자**: Gary (garyzone.pro)
