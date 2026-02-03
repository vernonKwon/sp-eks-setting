#!/bin/bash
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 스크립트 위치 기준으로 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/env"
NAMESPACE="pitin-service"

# 사용법 출력
usage() {
    echo "Usage: $0 <service> [options]"
    echo ""
    echo "Services:"
    echo "  bsms        Deploy BSMS (production)"
    echo "  bsms-dev    Deploy BSMS-dev (development)"
    echo "  all         Deploy all services"
    echo ""
    echo "Options:"
    echo "  --dry-run   Show rendered manifests without applying"
    echo ""
    echo "Examples:"
    echo "  $0 bsms"
    echo "  $0 bsms-dev --dry-run"
    echo "  $0 all"
    exit 1
}

# 환경 변수 로드
load_env() {
    if [ -f "$ENV_DIR/common.env" ]; then
        echo -e "${YELLOW}Loading common.env...${NC}"
        set -a
        source "$ENV_DIR/common.env"
        set +a
    else
        echo -e "${RED}Error: common.env not found${NC}"
        exit 1
    fi
}

# 네임스페이스 생성
deploy_namespace() {
    local dry_run=$1

    echo -e "${YELLOW}Applying namespace...${NC}"
    if [ "$dry_run" = true ]; then
        cat "$SCRIPT_DIR/namespace.yaml"
        echo "---"
    else
        kubectl apply -f "$SCRIPT_DIR/namespace.yaml"
    fi
}

# 서비스 배포 함수
deploy_service() {
    local service_dir=$1
    local dry_run=$2

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deploying: $service_dir${NC}"
    echo -e "${GREEN}========================================${NC}"

    for file in deployment.yaml service.yaml hpa.yaml; do
        if [ -f "$SCRIPT_DIR/$service_dir/$file" ]; then
            echo -e "${YELLOW}Applying $file...${NC}"
            if [ "$dry_run" = true ]; then
                cat "$SCRIPT_DIR/$service_dir/$file"
                echo "---"
            else
                kubectl apply -f "$SCRIPT_DIR/$service_dir/$file"
            fi
        fi
    done

    echo ""
}

# Ingress 적용 함수
deploy_ingress() {
    local dry_run=$1

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deploying Ingress${NC}"
    echo -e "${GREEN}========================================${NC}"

    echo -e "${YELLOW}Applying ingress.yaml (with envsubst)...${NC}"
    if [ "$dry_run" = true ]; then
        cat "$SCRIPT_DIR/ingress.yaml" | envsubst
    else
        cat "$SCRIPT_DIR/ingress.yaml" | envsubst | kubectl apply -f -
    fi

    echo ""
}

# 메인 로직
main() {
    if [ $# -lt 1 ]; then
        usage
    fi

    local service=$1
    local dry_run=false

    # 옵션 파싱
    if [ "$2" = "--dry-run" ]; then
        dry_run=true
        echo -e "${YELLOW}=== DRY RUN MODE ===${NC}"
        echo ""
    fi

    # 환경 변수 로드
    load_env

    # CERTIFICATE_ARN 확인
    if [ -z "$CERTIFICATE_ARN" ]; then
        echo -e "${RED}Error: CERTIFICATE_ARN is not set in common.env${NC}"
        exit 1
    fi
    echo -e "${GREEN}CERTIFICATE_ARN loaded successfully${NC}"
    echo ""

    # 네임스페이스 먼저 생성
    deploy_namespace $dry_run

    case $service in
        bsms)
            deploy_service "BSMS" $dry_run
            deploy_ingress $dry_run
            ;;
        bsms-dev)
            deploy_service "BSMS-dev" $dry_run
            deploy_ingress $dry_run
            ;;
        all)
            deploy_service "BSMS" $dry_run
            deploy_service "BSMS-dev" $dry_run
            deploy_ingress $dry_run
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            usage
            ;;
    esac

    if [ "$dry_run" = false ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Deployment completed!${NC}"
        echo -e "${GREEN}========================================${NC}"
    fi
}

main "$@"
