#!/usr/bin/env bash
set -euo pipefail

# Auto-apply Terraform with lock waiting and optional staged flow.
# Usage:
#   ./scripts/auto-terraform-apply.sh [eks-only|all]  (default: all)

MODE="${1:-all}"
TFDIR="$(cd "$(dirname "$0")/.." && pwd)/terraform"

echo "[auto-tf] Mode: ${MODE} | Terraform dir: ${TFDIR}"

# Ensure init
terraform -chdir="${TFDIR}" init -upgrade -input=false >/dev/null
terraform -chdir="${TFDIR}" validate >/dev/null

if [[ "${MODE}" == "eks-only" ]]; then
  echo "[auto-tf] Applying EKS module only (waiting for lock if needed)..."
  terraform -chdir="${TFDIR}" apply -target=module.eks -auto-approve -lock-timeout=45m
else
  echo "[auto-tf] Applying all Terraform (waiting for lock if needed)..."
  terraform -chdir="${TFDIR}" apply -auto-approve -lock-timeout=45m
fi

echo "[auto-tf] Apply completed. Verifying cluster status..."

# Optional: basic post checks (best-effort)
if command -v aws >/dev/null 2>&1; then
  CLUSTER="$(terraform -chdir="${TFDIR}" output -raw cluster_name 2>/dev/null || echo gary-cluster)"
  REGION="${AWS_REGION:-ap-northeast-2}"
  STATUS=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query cluster.status --output text 2>/dev/null || echo "UNKNOWN")
  echo "[auto-tf] EKS status: ${STATUS}"
fi

if command -v kubectl >/dev/null 2>&1; then
  echo "[auto-tf] kubectl version (client):"; kubectl version --client --short || true
  echo "[auto-tf] kube-system pods:"; kubectl get pods -n kube-system || true
  echo "[auto-tf] cert-manager pods:"; kubectl get pods -n cert-manager || true
  echo "[auto-tf] argocd pods:"; kubectl get pods -n argocd || true
  echo "[auto-tf] ingresses:"; kubectl get ingress -A || true
fi

echo "[auto-tf] Done."


