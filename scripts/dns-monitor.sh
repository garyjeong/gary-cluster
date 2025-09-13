#!/bin/bash

# DNS 전파 및 서비스 접속 모니터링 스크립트 (HTTPS)
DOMAIN="service-status.garyzone.pro"
URL="https://${DOMAIN}"

echo "🔍 ${DOMAIN} DNS 전파 및 접속 모니터링 시작..."
echo "시간: $(date)"
echo "=================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

while true; do
    echo -e "\n⏰ $(date '+%H:%M:%S') 테스트 중..."
    
    # DNS 해석 테스트
    DNS_RESULT=$(dig +short $DOMAIN 2>/dev/null)
    if [ -n "$DNS_RESULT" ]; then
        echo -e "${GREEN}✅ DNS 해석 성공: $DNS_RESULT${NC}"
        
        # HTTPS 접속 테스트
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $URL 2>/dev/null)
        RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" $URL 2>/dev/null)
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}🎉 HTTPS 접속 성공! (${HTTP_CODE}) - 응답시간: ${RESPONSE_TIME}s${NC}"
            echo -e "${GREEN}🌐 브라우저에서 접속 가능: $URL${NC}"
            
            # 브라우저 자동 열기 (macOS)
            if command -v open >/dev/null 2>&1; then
                echo "🚀 브라우저를 자동으로 열고 있습니다..."
                open $URL
            fi
            break
        else
            echo -e "${YELLOW}⚠️  HTTPS 응답 코드: $HTTP_CODE${NC}"
        fi
    else
        echo -e "${RED}❌ DNS 해석 실패 - 아직 전파 중...${NC}"
    fi
    
    echo "30초 후 재시도..."
    sleep 30
done

echo -e "\n${GREEN}🎯 모니터링 완료! 서비스가 정상적으로 접속 가능합니다.${NC}"
