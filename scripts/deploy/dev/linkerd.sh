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

# 기존 Linkerd 제거
# Linkerd는 서비스 메시 및 mTLS 인증서 체계가 복잡하여 기존 설치가 남아있으면 새로운 설치와 충돌할 가능성이 높음
# 특히 다음과 같은 이유로 완전한 제거 후 재설치를 권장:
# 1. mTLS 인증서 체계가 변경되었을 경우 기존 인증서와 충돌
# 2. Linkerd Control Plane의 설정이 변경되었을 경우 불일치 문제
# 3. CRD 버전 업그레이드 시 호환성 문제
# 4. 네임스페이스에 남은 리소스들이 새 설치를 방해할 수 있음
# 5. 서비스 메시의 특성상 일부만 업데이트하면 네트워크 정책이 꼬일 수 있음
cleanup_existing_linkerd() {
    print_step "기존 Linkerd 설치 확인 및 제거..."
    print_warning "Linkerd는 서비스 메시 특성상 기존 설치가 남아있으면 충돌 가능성이 높습니다."
    print_warning "mTLS 인증서 체계와 네트워크 정책의 일관성을 위해 완전 제거 후 재설치합니다."
    
    # Helm 릴리스 확인 및 제거
    if helm list -A | grep -q linkerd; then
        print_warning "기존 Linkerd Helm 릴리스가 발견되었습니다. 제거 중..."
        helm list -A | grep linkerd | awk '{print $1, $2}' | while read -r release namespace; do
            print_status "릴리스 제거 중: $release (네임스페이스: $namespace)"
            helm uninstall "$release" -n "$namespace" --timeout=5m || true
        done
        sleep 10
    fi
    
    # 네임스페이스 확인 및 제거
    if kubectl get namespace linkerd >/dev/null 2>&1; then
        print_status "기존 linkerd 네임스페이스 제거 중..."
        kubectl delete namespace linkerd --timeout=60s || true
        
        # 네임스페이스 삭제 대기
        local wait_count=0
        while kubectl get namespace linkerd >/dev/null 2>&1 && [[ $wait_count -lt 30 ]]; do
            echo "네임스페이스 삭제 대기 중... ($wait_count/30)"
            sleep 2
            ((wait_count++))
        done
    fi
    
    print_status "기존 Linkerd 정리 완료."
}

# step을 사용하여 루트 인증서 생성
generate_root_certificate() {
    print_step "step을 사용하여 루트 인증서 생성 중..."
    
    # 인증서 디렉토리 생성
    mkdir -p ./certs
    cd ./certs
    
    # 기존 인증서 파일이 있으면 백업
    if [[ -f "ca.crt" ]]; then
        print_warning "기존 루트 인증서가 발견되었습니다. 백업 중..."
        mv ca.crt ca.crt.backup.$(date +%Y%m%d-%H%M%S) || true
        mv ca.key ca.key.backup.$(date +%Y%m%d-%H%M%S) || true
    fi
    
    # step을 사용하여 루트 인증서 생성
    # step을 사용한 이유는 Linkerd에서 Step으로 가이드를 제공하고 있기 때문
    print_status "step 명령으로 루트 인증서 생성 중..."
    step certificate create root.linkerd.cluster.local ca.crt ca.key \
        --profile root-ca --no-password --insecure
    
    # 생성된 인증서 확인
    if [[ -f "ca.crt" && -f "ca.key" ]]; then
        print_status "루트 인증서 생성 완료:"
        print_status "  인증서: $(pwd)/ca.crt"
        print_status "  개인키: $(pwd)/ca.key"
        
        # 인증서 정보 표시
        print_status "인증서 정보:"
        step certificate inspect ca.crt --short
    else
        print_error "루트 인증서 생성에 실패했습니다."
        exit 1
    fi
    
    cd - >/dev/null
}

# cert-manager 설치
install_cert_manager() {
    print_step "cert-manager 설치 중..."
    
    # cert-manager가 이미 설치되어 있는지 확인
    if kubectl get namespace cert-manager >/dev/null 2>&1; then
        print_warning "cert-manager가 이미 설치되어 있습니다. 건너뜁니다."
        return 0
    fi
    
    # Jetstack Helm 저장소 추가
    print_status "Jetstack Helm 저장소 추가 중..."
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # cert-manager 설치
    # 현재 기준으로 v1.17.2 버전이 가장 최신 버전
    # https://artifacthub.io/packages/helm/cert-manager/cert-manager 참고
    print_status "cert-manager 설치 중..."
    helm install cert-manager --namespace cert-manager --create-namespace \
        --version v1.17.2 \
        --set crds.enabled=true \
        jetstack/cert-manager
    
    # 설치 확인
    print_status "cert-manager 설치 확인 중..."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    
    print_status "cert-manager 설치 완료."
    kubectl get all -n cert-manager
}

# Linkerd 네임스페이스 생성 및 루트 인증서 Secret 생성
setup_linkerd_namespace() {
    print_step "Linkerd 네임스페이스 및 루트 인증서 Secret 생성 중..."
    
    # Linkerd 네임스페이스 생성
    kubectl create namespace linkerd || true
    
    # 루트 인증서로 TLS Secret 생성
    print_status "루트 인증서를 사용하여 TLS Secret 생성 중..."
    kubectl create secret tls linkerd-trust-anchor \
        --cert=./certs/ca.crt \
        --key=./certs/ca.key \
        --namespace=linkerd \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Secret 확인
    kubectl get secrets -n linkerd linkerd-trust-anchor
    print_status "루트 인증서 Secret 생성 완료."
}

# cert-manager Issuer 및 중간 인증서 생성
# https://wlsdn3004.tistory.com/3 참고함
setup_certificate_issuer() {
    print_step "cert-manager Issuer 및 중간 인증서 생성 중..."
    
    # Issuer 생성
    print_status "루트 인증서를 참조하는 Issuer 생성 중..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: linkerd-trust-anchor
  namespace: linkerd
spec:
  ca:
    secretName: linkerd-trust-anchor
EOF
    
    # Certificate (중간 인증서) 생성
    print_status "Linkerd Identity용 중간 인증서 생성 중..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: linkerd-identity-issuer
  namespace: linkerd
spec:
  secretName: linkerd-identity-issuer
  duration: 48h
  renewBefore: 25h
  issuerRef:
    name: linkerd-trust-anchor
    kind: Issuer
  commonName: identity.linkerd.cluster.local
  dnsNames:
  - identity.linkerd.cluster.local
  isCA: true
  privateKey:
    algorithm: ECDSA
  usages:
  - cert sign
  - crl sign
  - server auth
  - client auth
EOF
    
    # Certificate가 생성될 때까지 대기
    print_status "중간 인증서 생성 대기 중..."
    kubectl wait --for=condition=Ready certificate/linkerd-identity-issuer -n linkerd --timeout=300s
    
    # 생성된 중간 인증서 Secret 확인
    print_status "생성된 중간 인증서 Secret 확인:"
    kubectl describe secrets -n linkerd linkerd-identity-issuer | grep -A4 Data
    
    print_status "cert-manager를 통한 인증서 설정 완료."
}

# Linkerd Helm 저장소 설정
setup_linkerd_helm_repo() {
    print_step "Linkerd Helm 저장소 설정 중..."
    
    # Linkerd Helm 저장소 추가 (stable 버전 사용)
    helm repo add linkerd https://helm.linkerd.io/stable
    helm repo update
    
    # 사용 가능한 차트 확인
    print_status "사용 가능한 Linkerd 차트 확인:"
    helm search repo linkerd/linkerd-crds --versions | head -3
    helm search repo linkerd/linkerd-control-plane --versions | head -3
    
    print_status "Linkerd Helm 저장소 설정 완료."
}

# Linkerd CRDs 설치
install_linkerd_crds() {
    print_step "Linkerd CRDs 설치 중..."
    
    # linkerd-crds 설치 (기본값 사용, Gateway API 충돌 방지)
    print_status "Linkerd CRDs Helm 차트 설치 중..."
    helm install linkerd-crds linkerd/linkerd-crds \
        --namespace linkerd \
        --create-namespace \
        --set installGatewayAPI=false \
        --wait \
        --timeout=10m
    
    # CRDs 설치 확인
    print_status "설치된 Linkerd CRDs 확인:"
    kubectl get crd | grep -i linkerd
    
    print_status "Linkerd CRDs 설치 완료."
}

# Linkerd Control Plane 설치
install_linkerd_control_plane() {
    print_step "Linkerd Control Plane 설치 중..."
    
    # Control Plane 설치
    print_status "Linkerd Control Plane Helm 차트 설치 중..."
    helm install linkerd-control-plane linkerd/linkerd-control-plane \
        --namespace linkerd \
        --set-file identityTrustAnchorsPEM=./certs/ca.crt \
        --set identity.issuer.scheme=kubernetes.io/tls \
        --wait \
        --timeout=15m
    
    # 설치 확인
    print_status "Linkerd Control Plane 설치 확인:"
    helm list -n linkerd
    
    print_status "Linkerd Control Plane 설치 완료."
}

# Linkerd 설치 검증
verify_linkerd_installation() {
    print_step "Linkerd 설치 검증 중..."
    
    # Pod 상태 확인
    print_status "Linkerd Pod 상태 확인 중..."
    kubectl get pods -n linkerd -o wide
    
    # Pod 준비 상태 대기
    print_status "모든 Linkerd Pod가 Ready 상태가 될 때까지 대기 중..."
    kubectl wait --for=condition=Ready pod --all -n linkerd --timeout=300s
    
    # 서비스 확인
    print_status "Linkerd 서비스 확인:"
    kubectl get svc -n linkerd
    
    # 핵심 서비스 상태 확인
    local core_services=("linkerd-identity" "linkerd-dst" "linkerd-proxy-injector")
    for svc in "${core_services[@]}"; do
        if kubectl get svc "$svc" -n linkerd >/dev/null 2>&1; then
            print_status "✅ 서비스 $svc: 정상"
        else
            print_error "❌ 서비스 $svc: 누락"
        fi
    done
    
    # Certificate 상태 확인
    print_status "cert-manager Certificate 상태 확인:"
    kubectl get certificate -n linkerd
    
    print_status "Linkerd 설치 검증 완료."
}

# 설치 완료 정보 출력
print_installation_summary() {
    print_step "Linkerd 설치 완료!"
    echo "----------------------------------------"
    echo "설치 요약:"
    echo ""
    echo "✅ 네임스페이스: linkerd"
    echo "✅ 루트 인증서: step으로 생성됨"
    echo "✅ 중간 인증서: cert-manager로 자동 관리됨"
    echo "✅ Linkerd CRDs: 설치됨"
    echo "✅ Linkerd Control Plane: 설치됨"
    echo ""
    echo "설치된 Helm 릴리스:"
    helm list -n linkerd
    echo ""
    echo "Linkerd Pod 상태:"
    kubectl get pods -n linkerd
    echo ""
    echo "Linkerd 서비스:"
    kubectl get svc -n linkerd
    echo ""
    echo "인증서 상태:"
    kubectl get certificate -n linkerd
    echo "----------------------------------------"
    echo ""
    echo "다음 단계 권장사항:"
    echo "1. Linkerd Viz 확장 설치 (모니터링 대시보드):"
    echo "   ./linkerd-viz.sh"
    echo ""
    echo "2. 애플리케이션에 Linkerd 주입:"
    echo "   kubectl get deploy -n <your-namespace> -o yaml | linkerd inject - | kubectl apply -f -"
    echo ""
    print_status "Linkerd가 성공적으로 배포되었습니다!"
}

# 메인 함수
main() {
    echo "Linkerd 배포 스크립트 시작..."
    echo "이 스크립트는 step과 cert-manager를 사용하여 Linkerd를 설치합니다."
    echo ""
    
    # 사용자 확인
    read -p "계속하시겠습니까? [y/n]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "설치를 취소합니다."
        exit 0
    fi
    
    # 설치 단계 실행
    cleanup_existing_linkerd
    generate_root_certificate
    install_cert_manager
    setup_linkerd_namespace
    setup_certificate_issuer
    setup_linkerd_helm_repo
    install_linkerd_crds
    install_linkerd_control_plane
    verify_linkerd_installation
    print_installation_summary
}

# 스크립트 실행
main "$@"