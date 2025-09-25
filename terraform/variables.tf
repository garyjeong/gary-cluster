variable "project_name" {
  description = "프로젝트 식별자"
  type        = string
  default     = "gary-cluster"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "eks_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.30"
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
  default     = "gary-cluster"
}

variable "node_group_name" {
  description = "노드 그룹 이름"
  type        = string
  default     = "gary-nodes"
}

variable "node_instance_type" {
  description = "노드 그룹 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

variable "node_desired_size" {
  description = "노드 그룹 기본 desired 개수"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "노드 그룹 최소 개수"
  type        = number
  default     = 0
}

variable "node_max_size" {
  description = "노드 그룹 최대 개수"
  type        = number
  default     = 3
}

variable "additional_tags" {
  description = "공통 태그에 병합할 추가 태그"
  type        = map(string)
  default     = {}
}

variable "cert_manager_email" {
  description = "cert-manager에서 사용할 연락 이메일"
  type        = string
  default     = "jeonggaryaws@gmail.com"
}

variable "acm_certificate_arn" {
  description = "ALB Ingress에서 사용할 ACM 인증서 ARN"
  type        = string
  default     = "arn:aws:acm:ap-northeast-2:014125597282:certificate/1249ba8a-b4bc-4254-bfda-f48d1c936d9e"
}

variable "domain_argocd" {
  description = "Argo CD Ingress 도메인"
  type        = string
  default     = "argocd.garyzone.pro"
}

variable "domain_household_ledger" {
  description = "household-ledger Ingress 도메인"
  type        = string
  default     = "household-ledger.garyzone.pro"
}

variable "domain_service_status" {
  description = "service-status Ingress 도메인"
  type        = string
  default     = "service-status.garyzone.pro"
}

variable "vpc_id" {
  description = "사용할 기존 VPC ID (생략 시 새 VPC 생성)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "EKS 워커 노드용 서브넷 ID 목록"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "퍼블릭 리소스용 서브넷 ID 목록"
  type        = list(string)
  default     = []
}

