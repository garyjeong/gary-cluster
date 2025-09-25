## gary-cluster — EKS 최소비용 + Terraform 일원화 (2025-09-25)

- 인프라 전면 Terraform 관리: VPC(옵션), EKS/노드그룹, IRSA, Helm(ALB/ExternalDNS/cert-manager/ExternalSecrets), Kubernetes 매니페스트(ClusterIssuer/Ingress/Service/Deployment), ECR
- 실행 디렉터리: `terraform/` | 자동 적용 스크립트: `scripts/auto-terraform-apply.sh`
- 운영 명령 모음은 `COMMANDS.md` 참고(초기화/계획/적용/타겟팅/잠금 이슈 대응)

### 현재 상태 요약

- EKS `gary-cluster` 가동(개발 목적 최소 비용 구성)
- 컨트롤러: AWS Load Balancer Controller, ExternalDNS, cert-manager(Helm)
- 경계 리소스: `argocd` Ingress, `service-status`/`household-ledger`(Manifest)
- 소형 노드 권장: 모든 워크로드 1 replica, 엄격한 limits/requests

### 아키텍처 개요

````text
Internet → Route53(garyzone.pro) → ACM(와일드카드) → ALB(ingress) → EKS → Pods
 - ExternalDNS: Route53 레코드 자동화
 - cert-manager: Let's Encrypt DNS-01(Route53)
```text

### 빠른 시작
1) 환경 준비(요약)
```bash
brew install awscli kubectl helm tfenv || true
aws sts get-caller-identity
```
2) Terraform 실행
```bash
terraform -chdir=terraform init -upgrade
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out tfplan
terraform -chdir=terraform apply tfplan
```
3) 주요 변수 수정: `terraform/variables.tf`
- `aws_region`, `cluster_name`, `acm_certificate_arn`, `domain_*`

### 도메인/네임서버
- Hosted Zone: `garyzone.pro`(Route53). 등록기관 NS를 Route53 NS로 위임 권장
- Ingress 생성 시 ALB 할당 → ExternalDNS가 A/AAAA Alias 생성
- ACM: 와일드카드 인증서 또는 cert-manager DNS-01 기반 발급

### 보안/접근
- IRSA 최소 권한: ALB/ExternalDNS/cert-manager/ExternalSecrets 전용 역할
- kubectl 접근: EKS Access Entry(권장) 또는 `scripts/update-aws-auth.sh`로 매핑
- TLS/HTTPS 기본, Security Group 최소 개방

### 비용 가이드(개발 환경)
- Control Plane: ~$72/월, t3.small 노드: ~$30/월, Hosted Zone: ~$0.5/월
- 절약 팁: 사용 후 노드 0으로 축소
```bash
aws eks update-nodegroup-config \
  --cluster-name gary-cluster \
  --nodegroup-name gary-nodes \
  --scaling-config minSize=0,maxSize=2,desiredSize=0
```

### 점검(핵심 명령)
```bash
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
kubectl -n kube-system logs deploy/external-dns --tail=200
kubectl get ing -A -o wide  # ALB 호스트 확인
```

### ECR 리포지토리(목록)
- hair-model-creator, household-ledger, gary-saju-service, spark-prompt,
  liview-backend, react-wedding-invitation-letter, liview-frontend

### 프로젝트 구조(최신)
```
./
├── README.md
├── TODO.md
├── COMMANDS.md
├── scripts/
│   ├── auto-terraform-apply.sh
│   ├── cluster-up.sh
│   ├── cluster-down.sh
│   ├── cost-report.sh
│   └── update-aws-auth.sh
└── terraform/
    ├── main.tf            # providers, locals
    ├── network.tf         # VPC(옵션 생성)
    ├── eks.tf             # EKS/NodeGroup(SPOT)
    ├── iam.tf             # IRSA(ALB/ExternalDNS/cert-manager/eso)
    ├── helm.tf            # aws-lb, external-dns, cert-manager, external-secrets
    ├── kubernetes.tf      # ClusterIssuer(ACME/Route53)
    ├── apps.tf            # argocd/service-status/household-ledger 매니페스트
    ├── ecr.tf             # ECR 7개 리포지토리 + 수명주기
    ├── variables.tf
    └── outputs.tf
```

### 부록(참고 내용 통합)
- 상태 리포트: 소형 노드(t3.small) 환경은 파드 수(≈11)와 메모리(2GB) 제약이 큼 → 시스템 파드 축소/단일 replica 권장
- 트러블슈팅 순서: 파드 상태 → 이벤트 → 로그 → 노드 리소스(Allocated resources)
- cert-manager 주의: IRSA/ServiceAccount 필수, DNS 전파 대기 정상(5~10분)

—
관리자: Gary (garyzone.pro) · 마지막 업데이트: 2025-09-25
````
