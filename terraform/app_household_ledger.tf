data "aws_caller_identity" "current" {}

resource "kubernetes_namespace" "gary_app" {
  metadata {
    name = "gary-app"
    labels = {
      name        = "gary-app"
      purpose     = "applications"
      managed-by  = "terraform"
    }
  }
}

module "eso_household_ledger_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.40.0"

  role_name = "eso-household-ledger"

  oidc_providers = {
    default = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["gary-app:household-ledger-sa"]
    }
  }

  role_policy_arns = {
    secrets_read = "arn:aws:iam::aws:policy/SecretsManagerReadOnly"
  }

  tags = local.default_tags
}

resource "kubernetes_service_account" "household_ledger" {
  metadata {
    name      = "household-ledger-sa"
    namespace = kubernetes_namespace.gary_app.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.eso_household_ledger_irsa.iam_role_arn
    }
  }
  automount_service_account_token = true

  depends_on = [kubernetes_namespace.gary_app]
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secretsmanager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = kubernetes_service_account.household_ledger.metadata[0].name
                namespace = kubernetes_service_account.household_ledger.metadata[0].namespace
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_manifest" "external_secret_household_ledger" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "household-ledger-secrets"
      namespace = kubernetes_namespace.gary_app.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = kubernetes_manifest.cluster_secret_store.manifest["metadata"]["name"]
        kind = "ClusterSecretStore"
      }
      target = {
        name          = "household-ledger-secrets"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          mergePolicy   = "Merge"
          data = {
            "database-url" = "{{ printf \"mysql://%s:%s@%s:%v/%s\" (urlquery .username) (urlquery .password) .host .port .database }}"
          }
        }
      }
      dataFrom = [
        {
          extract = {
            key = "rds/household-ledger/app"
          }
        }
      ]
      data = [
        {
          secretKey = "nextauth-secret"
          remoteRef = {
            key      = "household-ledger/app"
            property = "nextauth-secret"
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.cluster_secret_store]
}

