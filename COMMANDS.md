# COMMANDS — Terraform 운영 명령 모음 (gary-cluster)

> 이 프로젝트의 모든 인프라는 `terraform/` 디렉터리에서 Terraform 1.6.x로 관리됩니다. 아래 명령은 macOS/zsh 기준입니다.

## 0) 환경 준비

```bash
# (권장) tfenv로 Terraform 1.6.x 사용
brew install tfenv || true
brew unlink terraform 2>/dev/null || true
brew link --overwrite tfenv
tfenv install 1.6.6
tfenv use 1.6.6

# AWS 자격 증명 확인
aws sts get-caller-identity
```

## 1) 기본 워크플로우

```bash
# 디렉터리 지정 방법 고정
TFDIR=terraform

# 초기화/플러그인 업그레이드
terraform -chdir=$TFDIR init -upgrade -input=false

# 정적 유효성 검사
terraform -chdir=$TFDIR validate

# 전체 계획 생성
terraform -chdir=$TFDIR plan -out tfplan

# 적용
terraform -chdir=$TFDIR apply tfplan

# 출력 조회(중요 엔드포인트/ARN 등)
terraform -chdir=$TFDIR output
terraform -chdir=$TFDIR output -raw cluster_name
terraform -chdir=$TFDIR output -raw cluster_endpoint
```

## 2) 단계적 Plan/Apply (선택)

EKS를 먼저 생성한 다음 Helm/Kubernetes 리소스를 적용하는 2단계 접근이 안전합니다.

```bash
# 1단계: EKS만 Plan/Apply
terraform -chdir=$TFDIR plan -target=module.eks -out tfplan.eks
terraform -chdir=$TFDIR apply tfplan.eks

# 2단계: 나머지 전체 Plan/Apply
terraform -chdir=$TFDIR plan -out tfplan
terraform -chdir=$TFDIR apply tfplan
```

## 3) 리소스별 타겟팅 예시

> 주의: -target 사용은 비정상 상태 복구 등 예외 상황에만 추천됩니다.

### 3.1 EKS/VPC 모듈

```bash
# VPC(옵션 생성)만 계획
terraform -chdir=$TFDIR plan -target=module.vpc

# EKS만 계획/적용
terraform -chdir=$TFDIR plan -target=module.eks -out tfplan.eks
terraform -chdir=$TFDIR apply tfplan.eks
```

### 3.2 IRSA (IAM Roles for Service Accounts)

```bash
# 각 IRSA 모듈만 재적용
terraform -chdir=$TFDIR plan -target=module.alb_irsa
terraform -chdir=$TFDIR plan -target=module.external_dns_irsa
terraform -chdir=$TFDIR plan -target=module.cert_manager_irsa
terraform -chdir=$TFDIR plan -target=module.eso_household_ledger_irsa
```

### 3.3 Helm 릴리즈

```bash
# AWS Load Balancer Controller
terraform -chdir=$TFDIR plan -target=helm_release.aws_load_balancer_controller

# ExternalDNS
terraform -chdir=$TFDIR plan -target=helm_release.external_dns

# cert-manager
terraform -chdir=$TFDIR plan -target=helm_release.cert_manager

# External Secrets
terraform -chdir=$TFDIR plan -target=helm_release.external_secrets

# Argo CD (설치 유지 시)
terraform -chdir=$TFDIR plan -target=helm_release.argocd
```

### 3.4 Kubernetes 매니페스트

```bash
# cert-manager ClusterIssuer
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.cert_manager_cluster_issuer

# Argo CD Ingress
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.argocd_ingress

# household-ledger
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.household_ledger_deployment
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.household_ledger_service
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.household_ledger_ingress
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.cluster_secret_store
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.external_secret_household_ledger

# service-status
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.service_status
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.service_status_svc
terraform -chdir=$TFDIR plan -target=kubernetes_manifest.service_status_ingress
```

### 3.5 ECR (리포지토리/정책)

```bash
# 특정 ECR 리포지토리만 타겟팅 예시
# 키는 variables.tf의 ecr_repositories.name 값을 사용
terraform -chdir=$TFDIR state list | grep aws_ecr_repository

# 예: household-ledger만 재생성 강제(주의: 데이터 손실 영향 검토)
terraform -chdir=$TFDIR taint 'aws_ecr_repository.this["household-ledger"]'
terraform -chdir=$TFDIR plan -target='aws_ecr_repository.this["household-ledger"]'
```

## 4) 변수/환경 설정

```bash
# variables.tf 값 일시 오버라이드(예: 다른 도메인/ARN)
terraform -chdir=$TFDIR plan \
  -var='domain_argocd=argocd.example.com' \
  -var='acm_certificate_arn=arn:aws:acm:ap-northeast-2:ACCOUNT:certificate/XXXX'

# tfvars 파일 사용 예시
terraform -chdir=$TFDIR plan -var-file=prod.tfvars
```

## 5) 점검/검증 보조 명령

```bash
# EKS 상태
aws eks describe-cluster --name $(terraform -chdir=$TFDIR output -raw cluster_name) \
  --region ap-northeast-2 --query cluster.status --output text

# kubectl 접속(사전 Access Entry 필요할 수 있음)
aws eks update-kubeconfig --region ap-northeast-2 --name $(terraform -chdir=$TFDIR output -raw cluster_name)
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A

# ExternalDNS 로그
kubectl -n kube-system logs deploy/external-dns --tail=200

# ALB 주소 확인
kubectl get ing -A -o wide
```

## 6) 상태/잠금/캐시 이슈 대응

```bash
# 잠금 대기 적용(권장)
terraform -chdir=$TFDIR apply -auto-approve -lock-timeout=45m

# 로컬 모듈/플러그인 캐시 꼬임 시(무해)
mv $TFDIR/.terraform $TFDIR/.terraform.bak-$(date +%Y%m%d-%H%M%S) || true
terraform -chdir=$TFDIR init -upgrade -input=false
```

## 7) 파괴(Destroy) 주의

```bash
# 매우 위험: 전체 인프라 삭제
terraform -chdir=$TFDIR destroy

# 부분 파괴 예시(예외 상황 한정)
terraform -chdir=$TFDIR destroy -target=module.eks
```

## 8) 자동화 스크립트

```bash
# state lock 대기 + 전체 적용 + 간단 점검
./scripts/auto-terraform-apply.sh all

# EKS만 먼저 적용
./scripts/auto-terraform-apply.sh eks-only
```

## 9) 유용한 Terraform 상태 명령

```bash
terraform -chdir=$TFDIR state list
terraform -chdir=$TFDIR state show <ADDRESS>
# (주의) 상태 수동 편집은 지양. 불가피할 때만 사용
terraform -chdir=$TFDIR state rm <ADDRESS>
```

---

- 모든 리소스 주소(ADDRESS)는 `terraform -chdir=$TFDIR state list`로 조회 가능합니다.
- Git에 `.terraform/` 산출물이 커밋되지 않도록 `.gitignore`가 구성되어 있습니다.
