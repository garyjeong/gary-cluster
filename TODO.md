# EKS 최소비용 구축 + 도메인 연결 + ECR + GitOps - 체크리스트

## 📋 프로젝트 진행 상태

## ✅ **완료된 작업 요약** (2024년 12월 19일 기준)

### **클러스터 기본 구성**
- ✅ **EKS 클러스터**: `gary-cluster` (v1.32, Seoul 리전)
- ✅ **노드 그룹**: `gary-nodes-cli` (t3.small, 1노드, CREATING→ACTIVE 예정)
- ✅ **VPC**: `vpc-01b88f5ef0e77510c` (3개 AZ, 6개 서브넷)
- ✅ **IAM 역할**: `EKS-NodeGroup-Role` (필요 정책 모두 연결)
- ✅ **kubeconfig**: 로컬 설정 완료

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
- **총 예상 비용**: **~$104/월** (개발 환경)

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

### Phase 3: 네트워킹 및 Ingress 설정

- [ ] AWS Load Balancer Controller
  - [ ] IAM 정책 JSON 생성
  - [ ] IRSA (IAM Roles for Service Accounts) 설정
  - [ ] Helm으로 Controller 설치
  - [ ] 설치 확인 및 테스트
- [ ] Route53 및 ExternalDNS
  - [ ] Route53 Hosted Zone 확인/생성
  - [ ] ExternalDNS용 IRSA 설정
  - [ ] ExternalDNS Helm 설치 (domainFilters=garyzone.pro)
  - [ ] DNS 레코드 자동 생성 확인

### Phase 4: TLS 인증서 설정

- [ ] 방법 선택
  - [ ] (기본) ACM 와일드카드 인증서 발급
  - [ ] (대안) cert-manager + DNS-01(Route53) ClusterIssuer
- [ ] 인증서 발급 확인
- [ ] Ingress 어노테이션 TLS 설정

### Phase 5: ECR 리포지토리 생성

- [ ] ECR 리포지토리 7개 생성
  - [ ] hair-model-creator
  - [ ] household-ledger
  - [ ] gary-saju-service
  - [ ] spark-prompt
  - [ ] liview-backend
  - [ ] react-wedding-invitation-letter
  - [ ] liview-frontend
- [ ] ECR 접근 권한 설정
- [ ] 리포지토리 목록 검증 (`aws ecr describe-repositories`)

### Phase 6: 스모크 테스트

- [ ] Nginx 테스트 애플리케이션 배포
- [ ] Ingress 설정 (hello.dev.garyzone.pro)
- [ ] DNS 자동 레코드 생성 확인
- [ ] HTTPS 접근 확인 (브라우저 테스트)
- [ ] SSL 인증서 유효성 검증

### Phase 7: GitOps 준비 (Argo CD)

- [ ] Argo CD 설치
- [ ] App-of-Apps 패턴으로 부트스트랩 설정
- [ ] gary-cluster 저장소 연동
- [ ] Git 기반 배포 파이프라인 구성

## 🔧 운영 및 관리

- [ ] 비용 최적화 설정
  - [ ] 노드 스케일링 (0→1→0) 사용법 숙지
  - [ ] SPOT 인스턴스 설정
  - [ ] 사용하지 않는 리소스 정리
- [ ] 보안 검토
  - [ ] IRSA 최소 권한 원칙 적용
  - [ ] 네트워크 정책 설정
  - [ ] 시크릿 관리 방식 결정

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

_마지막 업데이트: 2024년 12월 19일_
