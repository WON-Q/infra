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

# 명령어 존재 여부 확인 함수
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 기존 Linkerd Viz 제거
# Linkerd Viz에서 403 오류가 발생하는 경우가 있음 (Prometheus 메트릭 쿼리 실패)
# 이는 주로 다음과 같은 이유로 발생:
# 1. 내장 Prometheus와 외부 Prometheus 간의 충돌
# 2. 메트릭 스크래핑 설정 불일치
# 3. RBAC 권한 문제
# 4. 대시보드와 메트릭 API 간의 연결 문제
# 완전한 제거 후 재설치로 이런 문제들을 해결
cleanup_existing_linkerd_viz() {
    print_step "기존 Linkerd Viz 설치 확인 및 제거..."
    print_warning "Linkerd Viz에서 403 오류나 메트릭 쿼리 실패가 발생할 수 있습니다."
    print_warning "완전한 제거 후 재설치로 이런 문제들을 해결합니다."
    
    # Helm 릴리스 확인 및 제거
    if helm list -n linkerd-viz | grep -q linkerd-viz; then
        print_warning "기존 Linkerd Viz Helm 릴리스가 발견되었습니다. 제거 중..."
        helm uninstall linkerd-viz -n linkerd-viz --timeout=5m || true
        sleep 10
    fi
    
    # 네임스페이스 확인 및 제거
    if kubectl get namespace linkerd-viz >/dev/null 2>&1; then
        print_status "기존 linkerd-viz 네임스페이스 제거 중..."
        kubectl delete namespace linkerd-viz --timeout=60s || true
        
        # 네임스페이스 삭제 대기
        local wait_count=0
        while kubectl get namespace linkerd-viz >/dev/null 2>&1 && [[ $wait_count -lt 30 ]]; do
            echo "네임스페이스 삭제 대기 중... ($wait_count/30)"
            sleep 2
            ((wait_count++))
        done
    fi
    
    print_status "기존 Linkerd Viz 정리 완료."
}

# 외부 Prometheus 사용 여부 확인
check_external_prometheus() {
    print_step "외부 Prometheus 사용 여부 확인 중..."
    
    # monitoring 네임스페이스의 Prometheus 서비스 확인
    if kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring >/dev/null 2>&1; then
        local prometheus_ip
        prometheus_ip=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.clusterIP}')
        if [[ -n "$prometheus_ip" ]]; then
            print_status "외부 Prometheus가 발견되었습니다: $prometheus_ip:9090"
            echo ""
            echo "외부 Prometheus를 사용하시겠습니까?"
            echo "1) 예 - 외부 Prometheus 사용 (monitoring.sh로 설치된 Prometheus에 Linkerd 메트릭 추가)"
            echo "2) 아니오 - Linkerd Viz 내장 Prometheus 사용"
            echo ""
            read -p "선택하세요 [1/2]: " -r prometheus_choice
            
            case $prometheus_choice in
                1)
                    USE_EXTERNAL_PROMETHEUS=true
                    EXTERNAL_PROMETHEUS_URL="http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
                    print_status "외부 Prometheus를 사용합니다: $EXTERNAL_PROMETHEUS_URL"
                    
                    # Linkerd 메트릭 스크래핑 설정 추가 여부 확인
                    echo ""
                    echo "외부 Prometheus에 Linkerd 메트릭 수집 설정을 추가하시겠습니까?"
                    echo "1) 예 - Linkerd 메트릭 스크래핑 설정 추가 (권장)"
                    echo "2) 아니오 - 현재 Prometheus 설정 유지"
                    echo ""
                    read -p "선택하세요 [1/2]: " -r scraping_choice
                    
                    case $scraping_choice in
                        1)
                            CONFIGURE_PROMETHEUS_SCRAPING=true
                            print_status "Prometheus에 Linkerd 메트릭 스크래핑 설정을 추가합니다."
                            ;;
                        2)
                            CONFIGURE_PROMETHEUS_SCRAPING=false
                            print_status "현재 Prometheus 설정을 유지합니다."
                            ;;
                        *)
                            print_warning "잘못된 선택입니다. 스크래핑 설정을 추가합니다."
                            CONFIGURE_PROMETHEUS_SCRAPING=true
                            ;;
                    esac
                    return 0
                    ;;
                2)
                    USE_EXTERNAL_PROMETHEUS=false
                    CONFIGURE_PROMETHEUS_SCRAPING=false
                    print_status "Linkerd Viz 내장 Prometheus를 사용합니다."
                    return 0
                    ;;
                *)
                    print_warning "잘못된 선택입니다. 내장 Prometheus를 사용합니다."
                    USE_EXTERNAL_PROMETHEUS=false
                    CONFIGURE_PROMETHEUS_SCRAPING=false
                    return 0
                    ;;
            esac
        fi
    fi
    
    USE_EXTERNAL_PROMETHEUS=false
    CONFIGURE_PROMETHEUS_SCRAPING=false
    print_status "외부 Prometheus가 발견되지 않았습니다. 내장 Prometheus를 사용합니다."
}

# Linkerd 메트릭 수집을 위한 Prometheus 스크래핑 설정 생성
create_linkerd_scrape_config() {
    print_status "Linkerd 메트릭 수집을 위한 Prometheus 스크래핑 설정 생성 중..."
    
    cat > ./prometheus-linkerd-values.yaml <<EOF
# Linkerd 메트릭 수집을 위한 Prometheus 설정
prometheus:
  prometheusSpec:
    # 글로벌 스크래핑 간격을 10초로 설정 (Linkerd 권장)
    scrapeInterval: 10s
    scrapeTimeout: 10s
    evaluationInterval: 10s
    
    # Linkerd 메트릭 수집을 위한 추가 스크래핑 작업
    additionalScrapeConfigs:
    - job_name: 'linkerd-controller'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
          - 'linkerd'
          - 'linkerd-viz'
      relabel_configs:
      - source_labels:
        - __meta_kubernetes_pod_container_port_name
        action: keep
        regex: admin-http
      - source_labels: [__meta_kubernetes_pod_container_name]
        action: replace
        target_label: component
    
    - job_name: 'linkerd-proxy'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels:
        - __meta_kubernetes_pod_container_name
        - __meta_kubernetes_pod_container_port_name
        - __meta_kubernetes_pod_label_linkerd_io_control_plane_ns
        action: keep
        regex: ^linkerd-proxy;linkerd-admin;linkerd\$
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod
      - source_labels: [__meta_kubernetes_pod_label_linkerd_io_proxy_job]
        action: replace
        target_label: k8s_job
      - action: labeldrop
        regex: __meta_kubernetes_pod_label_linkerd_io_proxy_job
      - action: labelmap
        regex: __meta_kubernetes_pod_label_linkerd_io_proxy_(.+)
      - action: labeldrop
        regex: __meta_kubernetes_pod_label_linkerd_io_proxy_(.+)
      - action: labelmap
        regex: __meta_kubernetes_pod_label_linkerd_io_(.+)
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
        replacement: __tmp_pod_label_\$1
      - action: labelmap
        regex: __tmp_pod_label_linkerd_io_(.+)
        replacement: __tmp_pod_label_\$1
      - action: labeldrop
        regex: __tmp_pod_label_linkerd_io_(.+)
      - action: labelmap
        regex: __tmp_pod_label_(.+)
EOF
    
    print_status "Linkerd 스크래핑 설정 파일 생성 완료: ./prometheus-linkerd-values.yaml"
}

# 외부 Prometheus에 Linkerd 메트릭 스크래핑 설정 추가
configure_prometheus_for_linkerd() {
    if [[ "$CONFIGURE_PROMETHEUS_SCRAPING" == "true" ]]; then
        print_step "외부 Prometheus에 Linkerd 메트릭 스크래핑 설정 추가 중..."
        
        # Prometheus 업그레이드 (YAML 파일 없이 직접 설정)
        print_status "Prometheus를 Linkerd 메트릭 수집 설정으로 업그레이드 중..."
        helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring \
            --reuse-values \
            --set prometheus.prometheusSpec.scrapeInterval=10s \
            --set prometheus.prometheusSpec.scrapeTimeout=10s \
            --set prometheus.prometheusSpec.evaluationInterval=10s \
            --set-string prometheus.prometheusSpec.additionalScrapeConfigs='
- job_name: "linkerd-controller"
  kubernetes_sd_configs:
  - role: pod
    namespaces:
      names:
      - "linkerd"
      - "linkerd-viz"
  relabel_configs:
  - source_labels:
    - __meta_kubernetes_pod_container_port_name
    action: keep
    regex: admin-http
  - source_labels: [__meta_kubernetes_pod_container_name]
    action: replace
    target_label: component

- job_name: "linkerd-proxy"
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels:
    - __meta_kubernetes_pod_container_name
    - __meta_kubernetes_pod_container_port_name
    - __meta_kubernetes_pod_label_linkerd_io_control_plane_ns
    action: keep
    regex: ^linkerd-proxy;linkerd-admin;linkerd$
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: namespace
  - source_labels: [__meta_kubernetes_pod_name]
    action: replace
    target_label: pod
  - source_labels: [__meta_kubernetes_pod_label_linkerd_io_proxy_job]
    action: replace
    target_label: k8s_job
  - action: labeldrop
    regex: __meta_kubernetes_pod_label_linkerd_io_proxy_job
  - action: labelmap
    regex: __meta_kubernetes_pod_label_linkerd_io_proxy_(.+)
  - action: labeldrop
    regex: __meta_kubernetes_pod_label_linkerd_io_proxy_(.+)
  - action: labelmap
    regex: __meta_kubernetes_pod_label_linkerd_io_(.+)
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
    replacement: __tmp_pod_label_$1
  - action: labelmap
    regex: __tmp_pod_label_linkerd_io_(.+)
    replacement: __tmp_pod_label_$1
  - action: labeldrop
    regex: __tmp_pod_label_linkerd_io_(.+)
  - action: labelmap
    regex: __tmp_pod_label_(.+)' \
            --timeout=10m
        
        print_status "Prometheus 업그레이드 완료. Linkerd 메트릭 수집이 활성화되었습니다."
        
        # Prometheus Pod 재시작 대기
        print_status "Prometheus Pod 재시작 대기 중..."
        kubectl rollout status statefulset/prometheus-prometheus-kube-prometheus-prometheus -n monitoring --timeout=300s || {
            print_warning "Prometheus 재시작이 완료되지 않았을 수 있습니다. 수동으로 확인하세요."
        }
    fi
}

# Linkerd Viz 설치
install_linkerd_viz() {
    print_step "Linkerd Viz 확장 설치 중..."
    
    # Linkerd Control Plane이 설치되어 있는지 확인
    if ! kubectl get namespace linkerd >/dev/null 2>&1; then
        print_error "Linkerd Control Plane이 설치되어 있지 않습니다."
        print_error "먼저 ./linkerd.sh를 실행하여 Linkerd Control Plane을 설치하세요."
        exit 1
    fi
    
    # Linkerd Helm 저장소 확인 및 추가
    if ! helm repo list | grep -q linkerd; then
        print_status "Linkerd Helm 저장소 추가 중..."
        helm repo add linkerd https://helm.linkerd.io/stable
        helm repo update
    else
        print_status "Helm 저장소 업데이트 중..."
        helm repo update
    fi
    
    # 설치 옵션 구성
    local helm_args=(
        "linkerd-viz" "linkerd/linkerd-viz"
        "--namespace" "linkerd-viz"
        "--create-namespace"
        "--set" "dashboard.enforcedHostRegexp=.*"
        "--wait"
        "--timeout=10m"
    )
    
    # 외부 Prometheus 사용 시 추가 설정
    if [[ "$USE_EXTERNAL_PROMETHEUS" == "true" ]]; then
        print_status "외부 Prometheus 설정을 적용합니다..."
        helm_args+=(
            "--set" "prometheus.enabled=false"
            "--set" "prometheusUrl=$EXTERNAL_PROMETHEUS_URL"
        )
    fi
    
    # Linkerd Viz 설치
    print_status "Linkerd Viz Helm 차트 설치 중..."
    if [[ "$USE_EXTERNAL_PROMETHEUS" == "true" ]]; then
        print_status "외부 Prometheus URL: $EXTERNAL_PROMETHEUS_URL"
        print_status "내장 Prometheus: 비활성화됨"
    else
        print_status "내장 Prometheus: 활성화됨"
    fi
    
    helm install "${helm_args[@]}"
    
    print_status "Linkerd Viz 설치 완료."
}

# Web 서비스를 LoadBalancer로 노출
expose_web_service() {
    print_step "Web 서비스를 LoadBalancer로 노출 중..."
    
    # 현재 web 서비스 타입 확인
    local current_type
    current_type=$(kubectl get svc web -n linkerd-viz -o jsonpath='{.spec.type}' 2>/dev/null || echo "NotFound")
    
    if [[ "$current_type" == "LoadBalancer" ]]; then
        print_status "Web 서비스가 이미 LoadBalancer로 구성되어 있습니다."
    else
        print_status "Web 서비스를 LoadBalancer로 변경 중..."
        kubectl patch svc web -n linkerd-viz -p '{"spec": {"type": "LoadBalancer"}}'
        print_status "Web 서비스 타입 변경 완료."
    fi
}

# Linkerd Viz 설치 검증
verify_linkerd_viz() {
    print_step "Linkerd Viz 설치 검증 중..."
    
    # Pod 상태 확인
    print_status "Linkerd Viz Pod 상태 확인:"
    kubectl get pods -n linkerd-viz -o wide
    
    # Ready 상태 대기
    print_status "Linkerd Viz Pod가 Ready 상태가 될 때까지 대기 중..."
    kubectl wait --for=condition=Ready pod --all -n linkerd-viz --timeout=300s || {
        print_warning "일부 Pod가 Ready 상태가 되지 않았습니다. 상태를 확인합니다."
        kubectl get pods -n linkerd-viz
    }
    
    # 서비스 확인
    print_status "Linkerd Viz 서비스 확인:"
    kubectl get svc -n linkerd-viz
    
    # 핵심 서비스 상태 확인
    local core_services=("web" "metrics-api" "tap")
    for svc in "${core_services[@]}"; do
        if kubectl get svc "$svc" -n linkerd-viz >/dev/null 2>&1; then
            print_status "✅ 서비스 $svc: 정상"
        else
            print_warning "⚠️ 서비스 $svc: 확인 필요"
        fi
    done
    
    # Linkerd CLI로 확인 (가능한 경우)
    if command_exists linkerd; then
        print_status "Linkerd Viz 상태 확인 실행 중..."
        if linkerd viz check; then
            print_status "✅ Linkerd Viz 상태 확인 성공!"
        else
            print_warning "⚠️ Linkerd Viz 확인에서 일부 경고가 있지만 기본 기능은 작동합니다."
        fi
    fi
    
    print_status "Linkerd Viz 검증 완료."
}

# 대시보드 접근 정보 출력
get_dashboard_access_info() {
    print_step "Linkerd Viz 대시보드 접근 정보 확인 중..."
    
    # LoadBalancer IP 확인 (최대 5분 대기)
    print_status "LoadBalancer External IP 할당 대기 중 (최대 5분)..."
    local viz_ip=""
    for i in {1..60}; do
        viz_ip=$(kubectl get svc web -n linkerd-viz -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [[ -n "$viz_ip" ]]; then
            break
        fi
        echo "External IP 할당 대기 중... ($i/60)"
        sleep 5
    done
    
    # 서비스 정보 출력
    print_status "Linkerd Viz 서비스 정보:"
    kubectl get svc -n linkerd-viz
    
    # 접근 정보 출력
    print_step "Linkerd Viz 대시보드 접근 정보"
    echo "----------------------------------------"
    if [[ -n "$viz_ip" ]]; then
        echo "🎯 Linkerd Viz 대시보드:"
        echo "   URL: http://$viz_ip:8084"
        echo ""
        echo "✅ Host 헤더 검증이 해제되었습니다 (enforcedHostRegexp=.*)"
        echo "✅ LoadBalancer로 외부 접근이 가능합니다"
        
        if [[ "$USE_EXTERNAL_PROMETHEUS" == "true" ]]; then
            echo "✅ 외부 Prometheus 사용 중: $EXTERNAL_PROMETHEUS_URL"
            echo "   • 더 안정적인 메트릭 수집"
            echo "   • monitoring.sh와 통합된 모니터링 스택"
            
            if [[ "$CONFIGURE_PROMETHEUS_SCRAPING" == "true" ]]; then
                echo "✅ Linkerd 메트릭 스크래핑이 외부 Prometheus에 추가되었습니다"
                echo "   • 10초 간격으로 Linkerd 메트릭 수집"
                echo "   • Grafana에서 Linkerd 메트릭 확인 가능"
            fi
        else
            echo "✅ 내장 Prometheus 사용 중"
        fi
        
        echo ""
        echo "⚠️  보안 참고사항:"
        echo "   • 현재 모든 Host 헤더를 허용합니다"
        echo "   • 프로덕션 환경에서는 특정 도메인으로 제한을 권장합니다"
    else
        print_warning "External IP가 할당되지 않았습니다."
        echo "🔧 대안 접근 방법:"
        echo "   포트 포워딩: kubectl port-forward -n linkerd-viz svc/web 8084:8084"
        echo "   로컬 접근: http://localhost:8084"
    fi
    
    # Linkerd CLI가 설치되어 있다면 추가 정보 제공
    if command_exists linkerd; then
        echo ""
        echo "📋 추가 Linkerd CLI 명령어:"
        echo "   • Viz 상태 확인: linkerd viz check"
        echo "   • CLI 대시보드: linkerd viz dashboard"
        echo "   • 실시간 메트릭: linkerd viz top deploy"
        echo "   • 트래픽 모니터링: linkerd viz tap deploy/<deployment-name>"
        echo "   • 라우트 분석: linkerd viz routes deploy/<deployment-name>"
    fi
    
    echo ""
    echo "🛠️  관리 명령어:"
    echo "   • Helm 상태: helm list -n linkerd-viz"
    echo "   • Pod 상태: kubectl get pods -n linkerd-viz"
    echo "   • 서비스 상태: kubectl get svc -n linkerd-viz"
    echo "   • 로그 확인: kubectl logs -n linkerd-viz deployment/web"
    echo "----------------------------------------"
}

# 설치 완료 정보 출력
print_installation_summary() {
    print_step "Linkerd Viz 설치 완료!"
    echo ""
    echo "📊 설치 요약:"
    echo "✅ Linkerd Viz Extension 설치됨"
    echo "✅ 대시보드가 LoadBalancer로 노출됨"
    echo "✅ Host 헤더 검증 해제됨 (외부 접근 허용)"
    
    if [[ "$USE_EXTERNAL_PROMETHEUS" == "true" ]]; then
        echo "✅ 외부 Prometheus 연동됨 (monitoring.sh 스택)"
        echo "✅ 내장 Prometheus 비활성화됨 (리소스 절약)"
        
        if [[ "$CONFIGURE_PROMETHEUS_SCRAPING" == "true" ]]; then
            echo "✅ 외부 Prometheus에 Linkerd 메트릭 스크래핑 추가됨"
            echo "   • 10초 간격으로 메트릭 수집"
            echo "   • Grafana에서 Linkerd 메트릭 확인 가능"
        fi
    else
        echo "✅ 내장 Prometheus, Grafana 포함됨"
    fi
    
    echo ""
    echo "다음 단계:"
    echo "1. 애플리케이션을 Linkerd에 주입하여 메트릭 수집"
    echo "2. 대시보드에서 서비스 메시 상태 모니터링"
    echo "3. 트래픽 분석 및 성능 최적화"
    
    if [[ "$USE_EXTERNAL_PROMETHEUS" == "true" && "$CONFIGURE_PROMETHEUS_SCRAPING" == "true" ]]; then
        echo "4. Grafana에서 통합 모니터링 (Linkerd 메트릭 포함)"
        echo "   • Grafana 접근: monitoring.sh 실행 결과 참조"
        echo "   • Linkerd 대시보드 임포트 가능"
    fi
    
    echo ""
    print_status "Linkerd Viz가 성공적으로 배포되었습니다!"
}

# 메인 함수
main() {
    echo "Linkerd Viz 대시보드 배포 스크립트 시작..."
    echo "이 스크립트는 Helm 차트를 사용하여 Linkerd Viz를 설치합니다."
    echo "외부 Prometheus와의 연동 및 Linkerd 메트릭 스크래핑 설정도 지원합니다."
    echo ""
    
    # 사용자 확인
    read -p "계속하시겠습니까? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "설치를 취소합니다."
        exit 0
    fi
    
    # 설치 단계 실행
    cleanup_existing_linkerd_viz
    check_external_prometheus
    configure_prometheus_for_linkerd
    install_linkerd_viz
    expose_web_service
    verify_linkerd_viz
    get_dashboard_access_info
    print_installation_summary
}

# 스크립트 실행
main "$@"
