#!/bin/bash
# EKS 클러스터 시작 스크립트

set -e

CLUSTER_NAME="gary-cluster"
REGION="ap-northeast-2"
NODEGROUP_NAME="gary-nodes"

echo "🚀 Gary Cluster 시작 중..."

# 1. 클러스터 상태 확인
echo "📊 클러스터 상태 확인 중..."
if ! eksctl get cluster --name=$CLUSTER_NAME --region=$REGION > /dev/null 2>&1; then
    echo "❌ 클러스터가 존재하지 않습니다. 먼저 클러스터를 생성하세요:"
    echo "eksctl create cluster -f clusters/cluster-config.yaml"
    exit 1
fi

# 2. 노드 그룹 스케일 업
echo "⚡ 노드 그룹 스케일 업 (0 → 1)"
eksctl scale nodegroup --cluster=$CLUSTER_NAME --name=$NODEGROUP_NAME --nodes=1 --region=$REGION

# 3. 노드 준비 대기
echo "⏳ 노드 준비 대기 중..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# 4. 파드 상태 확인
echo "🔍 시스템 파드 상태 확인..."
kubectl get pods -A | grep -E "(kube-system|aws-load-balancer|external-dns|cert-manager)"

# 5. Ingress 상태 확인
echo "🌐 Ingress 상태 확인..."
kubectl get ingress -A

echo "✅ Gary Cluster 시작 완료!"
echo ""
echo "🔗 유용한 명령어:"
echo "kubectl get nodes"
echo "kubectl get pods -A"
echo "kubectl get ingress -A"
echo ""
echo "💰 비용 절약을 위해 사용 후 'scripts/cluster-down.sh'를 실행하세요."
