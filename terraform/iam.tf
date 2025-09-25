module "alb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.40.0"

  role_name                          = "${var.project_name}-alb-controller"
  attach_aws_managed_policy_arns     = ["arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"]
  attach_load_balancer_controller_policy = true
  policy_statements = {
    Additional = {
      effect    = "Allow"
      actions   = ["iam:CreateServiceLinkedRole"]
      resources = ["*"]
      condition = {
        StringEquals = {
          "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
        }
      }
    }
  }

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
  attach_aws_managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonRoute53FullAccess"]

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
  attach_aws_managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonRoute53FullAccess"]

  inline_policy_statements = {
    allow_route53_changes = {
      effect = "Allow"
      actions = [
        "route53:GetChange",
        "route53:ChangeResourceRecordSets"
      ]
      resources = ["*"]
    }
  }

  oidc_providers = {
    gary = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  tags = local.default_tags
}

