#!/bin/bash
set -e

# 출력 색상 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 색상 없음

# 색상 출력 함수들
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 스크립트 존재 여부 확인 함수
check_script_exists() {
    local script_path="$1"
    if [[ ! -f "$script_path" ]]; then
        print_error "스크립트 파일을 찾을 수 없습니다: $script_path"
        return 1
    fi
    if [[ ! -x "$script_path" ]]; then
        print_status "스크립트에 실행 권한을 부여합니다: $script_path"
        chmod +x "$script_path"
    fi
    return 0
}

# 배포 단계 실행 함수
execute_deployment_step() {
    local step_name="$1"
    local script_path="$2"
    local description="$3"
    
    print_step "$step_name 배포 시작..."
    echo "설명: $description"
    echo "스크립트: $script_path"
    echo ""
    
    if ! check_script_exists "$script_path"; then
        print_error "$step_name 배포 실패: 스크립트 파일을 찾을 수 없습니다."
        return 1
    fi
    
    # 스크립트 실행
    if bash "$script_path"; then
        print_status "✅ $step_name 배포 완료!"
        echo ""
        return 0
    else
        print_error "❌ $step_name 배포 실패!"
        return 1
    fi
}

# 전체 상태 확인
check_overall_status() {
    print_step "전체 배포 상태 확인 중..."
    
    echo "=========================================="
    echo "네임스페이스 목록:"
    kubectl get namespaces | grep -E "(monitoring|argocd|linkerd|cert-manager)" || true
    echo ""
    
    echo "모든 Pod 상태:"
    kubectl get pods --all-namespaces | grep -E "(monitoring|argocd|linkerd|cert-manager)" || true
    echo ""
    
    echo "LoadBalancer 서비스:"
    kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer || true
    echo ""
    
    echo "Helm 릴리스:"
    helm list --all-namespaces || true
    echo "=========================================="
}

# 접속 정보 수집 및 출력
collect_access_information() {
    print_step "서비스 접속 정보 수집 중..."
    
    # ArgoCD 정보
    local argocd_ip argocd_password
    argocd_ip=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    
    # Grafana 정보
    local grafana_ip grafana_password
    grafana_ip=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    grafana_password=$(kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    
    # Linkerd Viz 정보
    local linkerd_viz_ip
    linkerd_viz_ip=$(kubectl get svc web -n linkerd-viz -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    # 접속 정보 출력
    echo ""
    echo "===== 인프라 구성 완료! ====="
    echo "=========================================="
    print_status "서비스 접근 정보:"
    echo ""
    
    # Monitoring (Grafana) 접속 정보
    echo "Grafana (모니터링 대시보드):"
    echo "  URL: http://$grafana_ip"
    echo "  사용자 이름: admin"
    echo "  비밀번호: $grafana_password"
    echo ""
    
    # ArgoCD 접속 정보
    echo "ArgoCD (GitOps 플랫폼):"
    echo "  URL: https://$argocd_ip"
    echo "  사용자 이름: admin"
    echo "  초기 비밀번호: $argocd_password"
    echo ""
    
    # Linkerd Viz Dashboard 접속 정보
    echo "Linkerd Viz (서비스 메시 대시보드):"
    echo "  URL: http://$linkerd_viz_ip:8084"
    echo "  CLI 대시보드: linkerd viz dashboard"
    echo ""
    
    echo "추가 유용한 명령어:"
    echo "  • 전체 상태 확인: kubectl get pods --all-namespaces"
    echo "  • ArgoCD 앱 생성: kubectl apply -f your-application.yaml"
    echo "  • Linkerd 주입: kubectl get deploy -n <namespace> -o yaml | linkerd inject - | kubectl apply -f -"
    echo "  • Linkerd 상태: linkerd check"
    echo "  • Linkerd Viz 상태: linkerd viz check"
    echo ""
    echo "생성된 설정 파일들:"
    echo "  • 루트 인증서: $(pwd)/certs/ca.crt"
    echo "  • Linkerd Values: $(pwd)/linkerd-values.yaml"
    echo "  • Linkerd Viz Values: $(pwd)/linkerd-viz-values.yaml"
    echo "=========================================="
}

# 메인 함수
main() {
    echo ""
    echo "===== 통합 인프라 배포 스크립트 ====="
    echo "이 스크립트는 다음 컴포넌트들을 순차적으로 배포합니다:"
    echo ""
    echo "1. Monitoring (Prometheus + Grafana)"
    echo "2. ArgoCD (GitOps 플랫폼)"
    echo "3. Linkerd (서비스 메시)"
    echo "4. Linkerd Viz (서비스 메시 대시보드)"
    echo ""
    echo "예상 소요 시간: 10-15분"
    echo "=========================================="
    echo ""
    
    # 사용자 확인
    read -p "계속하시겠습니까? [y/n]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "배포를 취소합니다."
        exit 0
    fi
    
    echo ""
    print_step "배포 프로세스 시작..."
    
    # 배포 시작 시간 기록
    local start_time
    start_time=$(date +%s)
    
    # 1. Monitoring 배포 (Prometheus + Grafana)
    if ! execute_deployment_step "Monitoring" "./monitoring.sh" "Prometheus와 Grafana를 배포하여 클러스터 모니터링 환경을 구성합니다."; then
        print_error "Monitoring 배포 실패. 배포를 중단합니다."
        exit 1
    fi
    
    # 2. ArgoCD 배포
    if ! execute_deployment_step "ArgoCD" "./argocd.sh" "GitOps 플랫폼인 ArgoCD를 배포하여 지속적 배포 환경을 구성합니다."; then
        print_error "ArgoCD 배포 실패. 배포를 중단합니다."
        exit 1
    fi
    
    # 3. Linkerd 배포
    if ! execute_deployment_step "Linkerd" "./linkerd.sh" "서비스 메시인 Linkerd를 배포하여 마이크로서비스 간 통신을 관리합니다."; then
        print_error "Linkerd 배포 실패. 배포를 중단합니다."
        exit 1
    fi
    
    # 4. Linkerd Viz 배포
    if ! execute_deployment_step "Linkerd Viz" "./linkerd-viz.sh" "Linkerd 모니터링 대시보드를 배포하여 서비스 메시 상태를 시각화합니다."; then
        print_warning "Linkerd Viz 배포 실패. 다른 컴포넌트들은 정상 작동합니다."
        print_warning "나중에 'bash ./linkerd-viz.sh'로 재시도할 수 있습니다."
    fi
    
    # 배포 완료 시간 계산
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    print_step "총 배포 시간: ${duration}초"
    echo ""
    
    # 전체 상태 확인
    check_overall_status
    echo ""
    
    # 접속 정보 수집 및 출력
    collect_access_information
    
    print_status "인프라 구성이 성공적으로 완료되었습니다!"
    echo ""
}

# 스크립트 실행
main "$@"
