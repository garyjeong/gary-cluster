#!/bin/bash
# EKS 클러스터 중지 스크립트 (비용 절약)

set -e

CLUSTER_NAME="gary-cluster"
REGION="ap-northeast-2"
NODEGROUP_NAME="gary-nodes"

echo "🛑 Gary Cluster 중지 중..."

# 1. 현재 노드 수 확인
echo "📊 현재 노드 상태 확인..."
CURRENT_NODES=$(kubectl get nodes --no-headers | wc -l | xargs)
echo "현재 노드 수: $CURRENT_NODES"

if [ "$CURRENT_NODES" -eq 0 ]; then
    echo "ℹ️  노드가 이미 0개입니다."
    exit 0
fi

# 2. 중요한 애플리케이션 상태 백업 (선택사항)
echo "💾 중요 상태 정보 백업..."
kubectl get pods -A -o wide > /tmp/gary-cluster-pods-backup.txt
kubectl get pvc -A > /tmp/gary-cluster-pvc-backup.txt 2>/dev/null || true
kubectl get configmaps -A > /tmp/gary-cluster-configmaps-backup.txt

echo "📁 백업 파일 생성됨:"
echo "- /tmp/gary-cluster-pods-backup.txt"
echo "- /tmp/gary-cluster-pvc-backup.txt" 
echo "- /tmp/gary-cluster-configmaps-backup.txt"

# 3. 확인 메시지
read -p "⚠️  노드를 0개로 스케일 다운하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 작업이 취소되었습니다."
    exit 0
fi

# 4. 노드 그룹 스케일 다운
echo "📉 노드 그룹 스케일 다운 (→ 0)"
eksctl scale nodegroup --cluster=$CLUSTER_NAME --name=$NODEGROUP_NAME --nodes=0 --region=$REGION

# 5. 스케일 다운 완료 대기
echo "⏳ 노드 종료 대기 중..."
sleep 30

# 6. 최종 상태 확인
FINAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | xargs || echo "0")
echo "최종 노드 수: $FINAL_NODES"

echo "✅ Gary Cluster 중지 완료!"
echo ""
echo "💰 비용 절약 효과:"
echo "- Worker Node 비용: $0/hour"
echo "- Control Plane 비용: $0.10/hour (계속 실행)"
echo ""
echo "🚀 재시작하려면: 'scripts/cluster-up.sh'를 실행하세요."
echo ""
echo "🗑️  완전히 삭제하려면:"
echo "eksctl delete cluster --name=$CLUSTER_NAME --region=$REGION"
