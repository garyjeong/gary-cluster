output "cluster_name" {
  value       = module.eks.cluster_name
  description = "생성된 EKS 클러스터 이름"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS 클러스터 엔드포인트"
}

output "cluster_security_group_id" {
  value       = module.eks.cluster_security_group_id
  description = "클러스터 보안 그룹 ID"
}

output "node_group_role_arn" {
  value       = module.eks.eks_managed_node_groups["default"].iam_role_arn
  description = "관리형 노드 그룹 IAM 역할 ARN"
}

output "alb_controller_role_arn" {
  value       = module.alb_irsa.iam_role_arn
  description = "AWS Load Balancer Controller용 IAM 역할 ARN"
}

output "external_dns_role_arn" {
  value       = module.external_dns_irsa.iam_role_arn
  description = "ExternalDNS IAM 역할 ARN"
}

output "cert_manager_role_arn" {
  value       = module.cert_manager_irsa.iam_role_arn
  description = "cert-manager IAM 역할 ARN"
}

