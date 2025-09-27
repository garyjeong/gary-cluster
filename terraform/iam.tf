module "alb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.40.0"

  role_name                          = "${var.project_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    gary = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.default_tags
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.40.0"

  role_name                      = "${var.project_name}-external-dns"
  attach_external_dns_policy     = true

  oidc_providers = {
    gary = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = local.default_tags
}

module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.40.0"

  role_name                      = "${var.project_name}-cert-manager"
  role_policy_arns = {
    route53 = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
  }

  oidc_providers = {
    gary = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  tags = local.default_tags
}

