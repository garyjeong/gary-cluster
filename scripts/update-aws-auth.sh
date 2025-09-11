#!/usr/bin/env bash

set -euo pipefail

#
# update-aws-auth.sh
#
# Safely add IAM role/user mappings to the aws-auth ConfigMap for an EKS cluster.
# Preferred path: use eksctl to update mappings idempotently. Falls back to guidance
# if eksctl is not installed.
#
# Usage examples:
#   ./scripts/update-aws-auth.sh \
#     --cluster gary-cluster \
#     --region ap-northeast-2 \
#     --roles arn:aws:iam::014125597282:role/EKS-ClusterAdmin \
#     --users arn:aws:iam::014125597282:user/gary-wemeet-macbook \
#     --group system:masters
#
# Multiple ARNs can be provided as comma-separated lists to --roles / --users.
# Default kubernetes group is system:masters.

print_usage() {
  cat <<'USAGE'
Usage: update-aws-auth.sh --cluster <name> --region <region> [--roles <role_arns>] [--users <user_arns>] [--group <k8s_group>] [--username-prefix <prefix>]

Options:
  --cluster            EKS cluster name (required)
  --region             AWS region of the cluster (required)
  --roles              Comma-separated IAM Role ARNs to map (optional)
  --users              Comma-separated IAM User ARNs to map (optional)
  --group              Kubernetes group to grant (default: system:masters)
  --username-prefix    Prefix for generated usernames (default: iam:)

Notes:
  - This script prefers 'eksctl create iamidentitymapping' which updates the aws-auth ConfigMap safely.
  - A timestamped backup of the current aws-auth ConfigMap will be written under ./backups/.
USAGE
}

CLUSTER_NAME=""
REGION=""
ROLE_ARNS=""
USER_ARNS=""
K8S_GROUP="system:masters"
USERNAME_PREFIX="iam:"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      CLUSTER_NAME="$2"; shift 2 ;;
    --region)
      REGION="$2"; shift 2 ;;
    --roles)
      ROLE_ARNS="$2"; shift 2 ;;
    --users)
      USER_ARNS="$2"; shift 2 ;;
    --group)
      K8S_GROUP="$2"; shift 2 ;;
    --username-prefix)
      USERNAME_PREFIX="$2"; shift 2 ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      print_usage
      exit 1 ;;
  esac
done

if [[ -z "$CLUSTER_NAME" || -z "$REGION" ]]; then
  echo "[ERROR] --cluster and --region are required." >&2
  print_usage
  exit 1
fi

if [[ -z "${ROLE_ARNS}" && -z "${USER_ARNS}" ]]; then
  echo "[WARN] No --roles or --users provided. Nothing to add. Exiting." >&2
  exit 0
fi

# Verify AWS identity
aws sts get-caller-identity >/dev/null

# Ensure kubeconfig context exists (non-fatal if already present)
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1 || true

# Backup current aws-auth ConfigMap
mkdir -p ./backups
if kubectl -n kube-system get configmap aws-auth >/dev/null 2>&1; then
  ts="$(date +%Y%m%d-%H%M%S)"
  kubectl -n kube-system get configmap aws-auth -o yaml > "./backups/aws-auth-${CLUSTER_NAME}-${ts}.yaml"
  echo "[INFO] Backed up aws-auth to ./backups/aws-auth-${CLUSTER_NAME}-${ts}.yaml"
else
  echo "[INFO] aws-auth ConfigMap not found yet; it will be created by EKS/eksctl when mappings are added."
fi

if ! command -v eksctl >/dev/null 2>&1; then
  echo "[ERROR] eksctl is required for safe/idempotent updates. Please install: brew install eksctl" >&2
  exit 1
fi

add_mapping() {
  local arn="$1"
  local group="$2"
  local username_prefix="$3"

  # Derive a friendly username from the ARN tail
  local tail
  tail="${arn##*/}"
  local username
  username="${username_prefix}${tail}"

  echo "[INFO] Adding mapping for ${arn} -> group=${group}, username=${username}"
  if ! eksctl create iamidentitymapping \
      --cluster "$CLUSTER_NAME" \
      --region "$REGION" \
      --arn "$arn" \
      --group "$group" \
      --username "$username" 2>/tmp/eksctl-iamidentitymapping.err; then
    if grep -qi "already exists" /tmp/eksctl-iamidentitymapping.err; then
      echo "[INFO] Mapping already exists for ${arn}; skipping."
    else
      echo "[ERROR] Failed to add mapping for ${arn}" >&2
      cat /tmp/eksctl-iamidentitymapping.err >&2 || true
      exit 1
    fi
  fi
}

# Process roles
IFS=',' read -r -a ROLE_ARR <<< "${ROLE_ARNS}"
for arn in "${ROLE_ARR[@]}"; do
  [[ -z "$arn" ]] && continue
  add_mapping "$arn" "$K8S_GROUP" "$USERNAME_PREFIX"
done

# Process users
IFS=',' read -r -a USER_ARR <<< "${USER_ARNS}"
for arn in "${USER_ARR[@]}"; do
  [[ -z "$arn" ]] && continue
  add_mapping "$arn" "$K8S_GROUP" "$USERNAME_PREFIX"
done

echo "[INFO] Verifying cluster access..."
kubectl get nodes >/dev/null 2>&1 || true
kubectl -n kube-system get configmap aws-auth -o yaml | sed -n '1,200p' || true

echo "[DONE] aws-auth updated. You can verify with: kubectl get configmap -n kube-system aws-auth -o yaml"


