# Terraform 일원화 체크리스트 (EKS + ALB + ExternalDNS + cert-manager + ECR + Apps)

## 진행 개요

- 인프라와 애플리케이션 경계 리소스를 전부 Terraform으로 관리하도록 전환 완료
- 제거: `controllers/`, `clusters/`, `ecr/`, `gitops/` 및 중복 YAML/values 파일
- 유지: `terraform/`, `scripts/`, 문서(README/STRUCTURE/SETUP-GUIDE/CLUSTER-STATUS)

## 완료 항목

- Terraform 1.6.x 환경 구성(tfenv 포함)
- VPC(옵션 생성), EKS, 노드그룹(SPOT), IRSA 3종(ALB, ExternalDNS, cert-manager)
- Helm 배포: aws-load-balancer-controller, external-dns, cert-manager
- ClusterIssuer(ACME/Route53)
- ECR 7개 리포지토리 생성 + 라이프사이클 정책
- 네임스페이스/SA(IRSA)/ClusterSecretStore/ExternalSecret/Deployment/Service/Ingress
  - 대상: `household-ledger`, `service-status`, `argocd-server` Ingress
- 중복 GitOps/App-of-Apps 제거, 잔여 매니페스트 정리

## 실행 방법(드라이런 포함)

```bash
terraform -chdir=terraform init -upgrade
terraform -chdir=terraform validate
# 1단계(EKS만):
terraform -chdir=terraform plan -target=module.eks -out tfplan.eks
# 전체 계획:
terraform -chdir=terraform plan -out tfplan
# 적용:
terraform -chdir=terraform apply tfplan
```

## 운영 스크립트

- 자동 적용: `scripts/auto-terraform-apply.sh all`
  - state lock 대기 + 적용 + 간단 점검

## 다음 할 일(권장)

- [ ] EKS Access Entry 생성으로 kubectl 접근 활성화(콘솔 → Access)
- [ ] 도메인 NS 위임/검증(`garyzone.pro`)
- [ ] 각 Ingress 도메인 접근 및 TLS 유효성 확인
- [ ] 불필요 운영 스크립트(eksctl 기반) 보관/삭제 결정
- [ ] 비용 점검(`scripts/cost-report.sh`) 및 SPOT 설정 검증

## 참고

- 주요 변수: `terraform/variables.tf` (도메인, ACM ARN, 리전 등)
- Git에 Terraform 산출물 포함 금지: `.gitignore` 반영 완료

**마지막 업데이트:** 2025-09-25 (Terraform 전면 전환 반영)
