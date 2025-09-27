resource "kubernetes_manifest" "cert_manager_cluster_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-prod"
    }
    "spec" = {
      "acme" = {
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "email"  = var.cert_manager_email
        "privateKeySecretRef" = {
          "name" = "letsencrypt-prod"
        }
        "solvers" = [
          {
            "dns01" = {
              "route53" = {
                "region" = var.aws_region
              }
            }
            "selector" = {
              "dnsZones" = ["garyzone.pro"]
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

