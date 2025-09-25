resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.6"

  values = [
    yamlencode({
      global = {
        image = {
          tag = null
        }
      }
      configs = {
        params = {
          "server\.insecure" = false
        }
      }
      controller = { replicas = 1 }
      repoServer = { replicas = 1 }
      server     = { replicas = 1 }
      redis      = { enabled  = true }
    })
  ]

  depends_on = [module.eks]
}

