#!/bin/bash
# EKS 클러스터 비용 리포트 스크립트

set -e

CLUSTER_NAME="gary-cluster"
REGION="ap-northeast-2"

echo "💰 Gary Cluster 비용 리포트"
echo "=============================="

# 1. 클러스터 기본 정보
echo ""
echo "📊 클러스터 정보:"
if eksctl get cluster --name=$CLUSTER_NAME --region=$REGION > /dev/null 2>&1; then
    echo "✅ 클러스터: $CLUSTER_NAME (활성)"
    CLUSTER_STATUS="활성"
else
    echo "❌ 클러스터: $CLUSTER_NAME (비활성)"
    CLUSTER_STATUS="비활성"
fi

# 2. 노드 상태 및 비용
echo ""
echo "🖥️  노드 상태 및 예상 비용:"
if [ "$CLUSTER_STATUS" = "활성" ]; then
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | xargs || echo "0")
    echo "- 노드 수: $NODE_COUNT"
    
    if [ "$NODE_COUNT" -gt 0 ]; then
        echo "- 노드 타입: t4g.small (ARM64, 2vCPU, 2GB RAM)"
        echo "- SPOT 인스턴스 할인 적용"
        
        # SPOT 인스턴스 가격 (대략적)
        SPOT_HOURLY_COST=0.0232  # t4g.small SPOT 시간당 약 $0.0232
        DAILY_NODE_COST=$(echo "$SPOT_HOURLY_COST * 24 * $NODE_COUNT" | bc -l)
        MONTHLY_NODE_COST=$(echo "$DAILY_NODE_COST * 30" | bc -l)
        
        printf "- 노드 비용: \$%.4f/시간, \$%.2f/일, \$%.2f/월\n" \
               $(echo "$SPOT_HOURLY_COST * $NODE_COUNT" | bc -l) \
               $DAILY_NODE_COST \
               $MONTHLY_NODE_COST
    else
        echo "- 노드 비용: \$0/시간 (노드 0개)"
    fi
else
    echo "- 노드 확인 불가 (클러스터 비활성)"
fi

# 3. Control Plane 비용
echo ""
echo "🎛️  Control Plane 비용:"
if [ "$CLUSTER_STATUS" = "활성" ]; then
    echo "- EKS Control Plane: \$0.10/시간"
    echo "- Control Plane 일간 비용: \$2.40"
    echo "- Control Plane 월간 비용: \$72.00"
else
    echo "- EKS Control Plane: \$0/시간 (클러스터 삭제됨)"
fi

# 4. 스토리지 비용
echo ""
echo "💾 스토리지 비용:"
if [ "$CLUSTER_STATUS" = "활성" ] && [ "$NODE_COUNT" -gt 0 ]; then
    echo "- EBS GP3 볼륨: 20GB × $NODE_COUNT = $(echo "20 * $NODE_COUNT" | bc)GB"
    STORAGE_MONTHLY_COST=$(echo "20 * $NODE_COUNT * 0.08" | bc -l)  # GP3는 GB당 월 $0.08
    printf "- 스토리지 월간 비용: \$%.2f\n" $STORAGE_MONTHLY_COST
else
    echo "- 스토리지 비용: \$0 (노드 없음)"
fi

# 5. 총 예상 비용
echo ""
echo "💸 총 예상 비용 (월간):"
if [ "$CLUSTER_STATUS" = "활성" ]; then
    if [ "$NODE_COUNT" -gt 0 ]; then
        TOTAL_MONTHLY=$(echo "$MONTHLY_NODE_COST + 72.00 + $STORAGE_MONTHLY_COST" | bc -l)
        printf "- 활성 상태 (노드 %d개): \$%.2f/월\n" $NODE_COUNT $TOTAL_MONTHLY
    else
        echo "- 노드 0개 상태: \$72.00/월 (Control Plane만)"
    fi
    echo "- 노드 중지 상태: \$72.00/월"
    echo "- 완전 삭제 상태: \$0/월"
else
    echo "- 클러스터 삭제됨: \$0/월"
fi

# 6. 비용 최적화 권장사항
echo ""
echo "💡 비용 최적화 권장사항:"
echo "- 개발 시에만 노드 활성화 (scripts/cluster-up.sh)"
echo "- 작업 완료 후 노드 중지 (scripts/cluster-down.sh)" 
echo "- 장기간 미사용 시 클러스터 완전 삭제"
echo "- SPOT 인스턴스로 최대 90% 할인 적용됨"

# 7. 추가 서비스 비용 (참고)
echo ""
echo "📋 추가 서비스 비용 (참고):"
echo "- ALB (Application Load Balancer): \$16.43/월 + 트래픽 비용"
echo "- Route53 Hosted Zone: \$0.50/월"
echo "- CloudWatch Logs: 로그량에 따라 변동"
echo "- Data Transfer: 트래픽량에 따라 변동"

echo ""
echo "🕐 리포트 생성 시간: $(date)"
echo "=============================="
