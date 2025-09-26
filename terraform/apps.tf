resource "kubernetes_manifest" "argocd_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-server-ingress"
      namespace = "argocd"
      annotations = {
        "kubernetes.io/ingress.class"                    = "alb"
        "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"         = "ip"
        "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\":\"redirect\",\"RedirectConfig\":{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}}"
        "alb.ingress.kubernetes.io/certificate-arn"     = var.acm_certificate_arn
        "external-dns.alpha.kubernetes.io/hostname"     = var.domain_argocd
      }
    }
    spec = {
      rules = [
        {
          host = var.domain_argocd
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "argocd-server"
                    port = { number = 80 }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns, helm_release.argocd]
}

resource "kubernetes_manifest" "household_ledger_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "household-ledger-service"
      namespace = "gary-app"
    }
    spec = {
      selector = { app = "household-ledger" }
      ports = [{ protocol = "TCP", port = 80, targetPort = 3000 }]
      type  = "ClusterIP"
    }
  }

  depends_on = [kubernetes_namespace.gary_app]
}

resource "kubernetes_manifest" "household_ledger_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "household-ledger-ingress"
      namespace = "gary-app"
      annotations = {
        "kubernetes.io/ingress.class"                    = "alb"
        "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"         = "ip"
        "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
        "alb.ingress.kubernetes.io/certificate-arn"     = var.acm_certificate_arn
        "external-dns.alpha.kubernetes.io/hostname"     = var.domain_household_ledger
      }
    }
    spec = {
      rules = [
        {
          host = var.domain_household_ledger
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "household-ledger-service"
                    port = { number = 80 }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns, kubernetes_manifest.household_ledger_service]
}

resource "kubernetes_manifest" "household_ledger_deployment" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "name"      = "household-ledger"
      "namespace" = "gary-app"
      "labels" = { "app" = "household-ledger" }
    }
    "spec" = {
      "replicas" = 1
      "revisionHistoryLimit" = 2
      "strategy" = {
        "type" = "RollingUpdate"
        "rollingUpdate" = { "maxUnavailable" = 0, "maxSurge" = 1 }
      }
      "selector" = { "matchLabels" = { "app" = "household-ledger" } }
      "template" = {
        "metadata" = {
          "labels" = { "app" = "household-ledger" }
          "annotations" = {
            "deploy.garyzone.pro/image-tag" = var.household_ledger_image_tag
          }
        }
        "spec" = {
          "serviceAccountName" = "household-ledger-sa"
          "containers" = [
            {
              "name"  = "household-ledger"
              "image" = "${var.household_ledger_image_repo}:${var.household_ledger_image_tag}"
              "imagePullPolicy" = "Always"
              "ports" = [{ "containerPort" = 3000 }]
              "livenessProbe"  = { "httpGet" = { "path" = "/api/health", "port" = 3000 }, "initialDelaySeconds" = 20, "periodSeconds" = 15, "timeoutSeconds" = 5, "failureThreshold" = 3 }
              "readinessProbe" = { "httpGet" = { "path" = "/api/health", "port" = 3000 }, "initialDelaySeconds" = 10, "periodSeconds" = 10, "timeoutSeconds" = 3, "failureThreshold" = 3 }
              "startupProbe"   = { "httpGet" = { "path" = "/api/health", "port" = 3000 }, "periodSeconds" = 5, "failureThreshold" = 30 }
              "resources" = {
                "requests" = { "cpu" = "100m", "memory" = "256Mi" }
                "limits"   = { "cpu" = "200m", "memory" = "512Mi" }
              }
              "env" = [
                { "name" = "DATABASE_URL",    "valueFrom" = { "secretKeyRef" = { "name" = "household-ledger-secrets", "key" = "database-url" } } },
                { "name" = "NEXTAUTH_SECRET", "valueFrom" = { "secretKeyRef" = { "name" = "household-ledger-secrets", "key" = "nextauth-secret" } } },
                { "name" = "NEXTAUTH_URL",    "value" = "https://household-ledger.garyzone.pro" }
              ]
            }
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.household_ledger,
    kubernetes_manifest.external_secret_household_ledger
  ]
}

resource "kubernetes_manifest" "service_status" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = { name = "service-status", namespace = "gary-app", labels = { app = "service-status" } }
    spec = {
      replicas = 1
      revisionHistoryLimit = 2
      strategy = { type = "RollingUpdate", rollingUpdate = { maxUnavailable = 0, maxSurge = 1 } }
      selector = { matchLabels = { app = "service-status" } }
      template = {
        metadata = { labels = { app = "service-status" } }
        spec = {
          containers = [
            {
              name  = "service-status"
              image = "014125597282.dkr.ecr.ap-northeast-2.amazonaws.com/service-status:latest"
              ports = [{ containerPort = 80 }]
              livenessProbe  = { httpGet = { path = "/", port = 80 }, initialDelaySeconds = 10, periodSeconds = 15, timeoutSeconds = 5, failureThreshold = 3 }
              readinessProbe = { httpGet = { path = "/", port = 80 }, initialDelaySeconds = 5,  periodSeconds = 10, timeoutSeconds = 3, failureThreshold = 3 }
              startupProbe   = { httpGet = { path = "/", port = 80 }, periodSeconds = 5, failureThreshold = 30 }
              resources = { limits = { cpu = "100m", memory = "128Mi" }, requests = { cpu = "50m", memory = "64Mi" } }
            }
          ]
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.gary_app]
}

resource "kubernetes_manifest" "service_status_svc" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = { name = "service-status-service", namespace = "gary-app", labels = { app = "service-status" } }
    spec = {
      selector = { app = "service-status" }
      ports    = [{ port = 80, targetPort = 80, protocol = "TCP" }]
      type     = "ClusterIP"
    }
  }
}

resource "kubernetes_manifest" "service_status_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "service-status-ingress"
      namespace = "gary-app"
      labels    = { app = "service-status" }
      annotations = {
        "kubernetes.io/ingress.class"                    = "alb"
        "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"         = "ip"
        "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
        "alb.ingress.kubernetes.io/certificate-arn"     = var.acm_certificate_arn
        "external-dns.alpha.kubernetes.io/hostname"     = var.domain_service_status
      }
    }
    spec = {
      rules = [
        {
          host = var.domain_service_status
          http = { paths = [{ path = "/", pathType = "Prefix", backend = { service = { name = "service-status-service", port = { number = 80 } } } }] }
        }
      ]
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns, kubernetes_manifest.service_status_svc]
}


