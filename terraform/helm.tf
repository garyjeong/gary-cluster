resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.0"

  create_namespace = false

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.aws_region
      serviceAccount = {
        create = false
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.alb_irsa.iam_role_arn
        }
      }
      resources = {
        limits = {
          cpu    = "200m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }
      replicaCount = 1
      logLevel     = "info"
      defaultTags  = local.default_tags
    })
  ]

  depends_on = [module.alb_irsa, module.eks]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.15.0"

  values = [
    yamlencode({
      provider = "aws"
      domainFilters = [
        "garyzone.pro",
        "garyzone.ai"
      ]
      sources = ["ingress", "service"]
      registry = "txt"
      txtOwnerId = var.cluster_name
      serviceAccount = {
        create = false
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.external_dns_irsa.iam_role_arn
        }
      }
      aws = {
        region              = var.aws_region
        zoneType            = "public"
        evaluateTargetHealth = true
      }
      resources = {
        limits = {
          cpu    = "50m"
          memory = "50Mi"
        }
        requests = {
          cpu    = "25m"
          memory = "25Mi"
        }
      }
      interval        = "1m"
      policy          = "sync"
      annotationFilter = "external-dns.alpha.kubernetes.io/hostname"
      metrics = {
        enabled = true
        port    = 7979
      }
    })
  ]

  depends_on = [module.external_dns_irsa, module.eks]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.15.1"

  create_namespace = true

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        create = false
        name   = "cert-manager"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.cert_manager_irsa.iam_role_arn
        }
      }
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
    })
  ]

  depends_on = [module.cert_manager_irsa, module.eks]
}

