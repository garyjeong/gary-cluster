# EKS 최소비용 구축 + 도메인 연결 + ECR + GitOps - 체크리스트

## 📋 프로젝트 진행 상태

## ✅ **완료된 작업 요약** (2025년 9월 11일 기준)

### **클러스터 기본 구성**

- ✅ **EKS 클러스터**: `gary-cluster` (v1.32, Seoul 리전) - 재생성 완료
- ✅ **노드 그룹**: `gary-nodes` (t3.small, 1노드, ACTIVE)
- ✅ **VPC**: `vpc-0e812b43bb30b0201` (3개 AZ, 6개 서브넷) - 새 VPC
- ✅ **IAM 역할**: `EKS-NodeGroup-Role` (필요 정책 모두 연결)
- ✅ **kubeconfig**: 로컬 설정 완료
- ✅ **RBAC 권한**: 문제 해결 완료
- ✅ **시스템 애드온**: vpc-cni, coredns, kube-proxy, metrics-server 모두 실행

### **컨트롤러 설치**

- ✅ **AWS Load Balancer Controller**: 완전 설치 및 실행 (2/2 파드 Ready)
- ✅ **IRSA 설정**: ALB Controller용 ServiceAccount 및 IAM Role 생성

### **ECR 리포지토리**

- ⚠️ **ECR 접근**: 정상 (AmazonEC2ContainerRegistryPowerUser 권한)
- ⚠️ **ECR 리포지토리**: 실제 1개만 존재 (문서와 불일치)
  - ✅ service-status (2025-09-10 생성, 이미지 업로드 완료)
  - ❌ hair-model-creator (누락)
  - ❌ household-ledger (누락)
  - ❌ gary-saju-service (누락)
  - ❌ spark-prompt (누락)
  - ❌ liview-backend (누락)
  - ❌ react-wedding-invitation-letter (누락)
  - ❌ liview-frontend (누락)

### **도구 및 환경**

- ✅ **AWS CLI**: v2.x, 인증 완료
- ✅ **eksctl**: v0.214.0-dev
- ✅ **helm**: v3.18.6
- ✅ **kubectl**: v1.32.2
- ✅ **리전**: ap-northeast-2 (Seoul)

### **예상 월 비용**

- **EKS Control Plane**: $72/월 ($0.10/시간)
- **t3.small 노드**: ~$30/월 (온디맨드 기준)
- **EBS 스토리지**: ~$2/월 (20GB)
- **Route53 Hosted Zone**: ~$0.50/월 (garyzone.pro)
- **총 예상 비용**: **~$104.50/월** (개발 환경)

### Phase 1: 사전 준비 및 환경 점검 ✅

- [x] AWS CLI, eksctl, helm, kubectl 버전 확인
- [x] AWS 계정 연결 및 권한 확인 (`aws sts get-caller-identity`)
- [x] 리전 설정 확인 (ap-northeast-2)
- [ ] 도메인 소유권 확인 (garyzone.pro)

### Phase 2: EKS 클러스터 생성 (최소 비용) ✅

- [x] EKS 클러스터 구성 파일 생성
- [x] 클러스터 생성 (Control Plane)
  - [x] 옵션 선택: 기본 설정으로 클러스터 생성 (`gary-cluster`)
  - [x] 노드 그룹 생성: AWS CLI로 직접 생성 (`gary-nodes-cli`)
- [x] kubeconfig 연결 및 접근 확인
- [x] IAM 역할 생성 (EKS-NodeGroup-Role)

### Phase 3: 네트워킹 및 Ingress 설정 ✅

- [x] AWS Load Balancer Controller
  - [x] IAM 정책 JSON 생성
  - [x] IRSA (IAM Roles for Service Accounts) 설정
  - [x] Helm으로 Controller 설치
  - [x] 설치 확인 및 테스트 (2/2 파드 Ready)
- [x] Route53 및 ExternalDNS
  - [x] Route53 Hosted Zone 생성 (Z0394568WTSPBSC5SBHO)
  - [x] ExternalDNS용 IRSA 설정 (EKS-ExternalDNS-Role)
  - [x] ExternalDNS Helm 설치 (domainFilters=garyzone.pro)
  - [x] DNS 레코드 자동 생성 확인

### Phase 4: TLS 인증서 설정 🔄

- [x] 방법 선택
  - [ ] ~~(기본) ACM 와일드카드 인증서 발급~~
  - [x] **(선택됨)** cert-manager + DNS-01(Route53) ClusterIssuer
- [x] cert-manager Helm 설치 (부분 완료 - 트러블슈팅 중)
- [x] ClusterIssuer 생성 (letsencrypt-prod, letsencrypt-staging)
- [ ] 인증서 자동 발급 확인
- [x] Ingress 어노테이션 TLS 설정 (cert-manager 방식으로 변경)

### Phase 5: ECR 리포지토리 생성 ⚠️

- [x] ECR 접근 권한 설정 (AmazonEC2ContainerRegistryPowerUser)
- [x] ECR 로그인 테스트 (성공)
- ⚠️ ECR 리포지토리 생성 (실제 1개/계획 7개)
  - [x] service-status (기존 존재)
  - [ ] hair-model-creator (생성 필요)
  - [ ] household-ledger (생성 필요)
  - [ ] gary-saju-service (생성 필요)
  - [ ] spark-prompt (생성 필요)
  - [ ] liview-backend (생성 필요)
  - [ ] react-wedding-invitation-letter (생성 필요)
  - [ ] liview-frontend (생성 필요)
- [x] 리포지토리 목록 검증 (`aws ecr describe-repositories`)

### Phase 6: 스모크 테스트 ✅

- [x] 네임스페이스 생성 (dev, prod, gary-apps)
- [x] Hello World 테스트 애플리케이션 배포 (삭제됨)
- [x] Ingress 설정 (hello.dev.garyzone.pro) - cert-manager 연동
- [ ] DNS 자동 레코드 생성 확인
- [ ] HTTPS 접근 확인 (브라우저 테스트)
- [ ] SSL 인증서 유효성 검증 (Let's Encrypt)

### Phase 7: GitOps 준비 (Argo CD) ✅

- [x] Argo CD 설치
- [x] App-of-Apps 패턴으로 부트스트랩 설정
- [x] gary-cluster 저장소 연동
- [ ] Git 기반 배포 파이프라인 구성

### Phase 8: EKS 접근 권한 설정 ⚠️

- [x] AWS CLI 자격 증명 재설정 (gary-wemeet-macbook)
- [x] kubeconfig 갱신 권한 부여 (eks:DescribeCluster, eks:ListClusters)
- [x] kubeconfig 업데이트 성공
- ⚠️ kubectl 접근 권한 (RBAC/Access Entry 필요)
  - [ ] EKS Access Entry 생성 (권장) 또는
  - [ ] aws-auth ConfigMap 매핑 (scripts/update-aws-auth.sh 사용)
- [x] 다중 위치 접근용 스크립트 작성 (update-aws-auth.sh)

## 🔧 운영 및 관리

- [ ] 비용 최적화 설정
  - [ ] 노드 스케일링 (0→1→0) 사용법 숙지
  - [ ] SPOT 인스턴스 설정
  - [ ] 사용하지 않는 리소스 정리
- [ ] 보안 검토
  - [ ] IRSA 최소 권한 원칙 적용
  - [ ] 네트워크 정책 설정
  - [ ] 시크릿 관리 방식 결정

## 🚨 **즉시 확인 필요한 사항들** (2025-09-11)

### 우선순위 1: kubectl 접근 권한

- [ ] EKS Access Entry에서 Principal에 Admin(Cluster) 권한 부여
  - Principal: arn:aws:iam::014125597282:user/gary-wemeet-macbook
  - 콘솔: EKS → gary-cluster → Access → Grant access
- [ ] kubectl 접근 확인: `kubectl get pods -A`
- [ ] dev 네임스페이스 hello-world 리소스 상태 점검

### 우선순위 2: ECR 리포지토리 정리

- [ ] 누락된 ECR 리포지토리 생성 여부 결정
- [ ] 필요 시 ecr/repositories.yaml 기반으로 일괄 생성
- [ ] 문서의 ECR 섹션을 실제 상태에 맞게 수정

### 우선순위 3: 클러스터 상태 점검

- [ ] 전체 파드 상태 확인 (현재 t3.small 11개 파드 제한)
- [ ] cert-manager TLS 인증서 발급 진행 상황
- [ ] hello-world 애플리케이션 삭제 반영 여부
- [ ] 파드 공간 부족 문제 해결 (노드 추가 or 불필요 파드 정리)

## 📝 참고사항

- **타겟 리전**: ap-northeast-2 (Seoul)
- **도메인**: garyzone.pro
- **비용 목표**: 월 $30 이하 (개발 환경 기준)
- **노드 사양**: t4g.small (Graviton, arm64) + SPOT 인스턴스
- **스토리지**: 20GB GP3 볼륨

## 🚨 주의사항

- 각 단계 완료 후 반드시 검증 명령어 실행
- 비용 발생 구간에서는 사용 후 즉시 리소스 정리
- 루트 키 사용 금지, IRSA로 권한 최소화
- 프로덕션 적용 전 충분한 테스트 수행

---

---

## 📊 **현재 상태 요약**

### ✅ **정상 작동**

- AWS CLI 인증 및 권한 (계정: 014125597282)
- EKS 클러스터 gary-cluster (v1.32, 1노드 t3.small)
- ECR 접근 및 로그인 (service-status 리포지토리 존재)
- AWS Load Balancer Controller, ExternalDNS 설치 완료
- kubeconfig 갱신 가능

### ⚠️ **해결 필요**

- kubectl 클러스터 접근 불가 (RBAC 미매핑)
- ECR 리포지토리 7개 중 6개 누락
- hello-world 애플리케이션 삭제 상태 미확인
- t3.small 파드 개수 제한 (11개 포화)

### 🎯 **다음 액션**

1. EKS Access Entry 생성으로 kubectl 접근 활성화
2. 클러스터 전체 상태 점검 (파드, 서비스, 인그레스)
3. ECR 리포지토리 생성 계획 수립
4. cert-manager TLS 인증서 발급 상태 확인

_마지막 업데이트: 2025년 9월 11일 (AWS 자격 증명 재설정 및 ECR 상태 점검 완료)_
