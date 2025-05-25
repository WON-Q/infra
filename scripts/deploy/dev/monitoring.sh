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

print_step "Prometheus 및 Grafana 배포 스크립트 시작..."

# --- 1. Helm Repository 추가 및 업데이트 ---
print_status "Helm Repository 추가 및 업데이트 중..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# --- 2. 네임스페이스 생성 및 prometheus + grafana 배포 ---
print_status "Monitoring 네임스페이스 생성 및 Prometheus, Grafana 배포 중..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
print_status "네임스페이스 'monitoring' 생성 또는 확인 완료."

# Prometheus 및 Grafana 배포 확인
if kubectl get deployment prometheus-grafana -n monitoring &>/dev/null; then
  print_warning "Prometheus 및 Grafana가 이미 설치되어 있습니다. 배포 단계를 건너뜁니다."
else
  print_status "kube-prometheus-stack (Prometheus, Grafana 포함) 배포 중..."
  # `helm show values prometheus-community/kube-prometheus-stack` 명령어로 기본값을 조회했을 때 `prometheus.prometheusSpec.maximumStartupDurationSeconds` 값이 0으로 설정되어 있어,
  # Helm 설치 시 이 값을 600초로 설정하여 Prometheus가 충분한 시간 동안 시작될 수 있도록 합니다.
  # 또한 Grafana 서비스를 애초에 LoadBalancer로 설정하여 후에 Prometheus 업그레이드 시에도 유지되도록 합니다.
  helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring \
    --set prometheus.prometheusSpec.maximumStartupDurationSeconds=600 \
    --set grafana.service.type=LoadBalancer
  print_status "kube-prometheus-stack 배포 완료."
fi

# --- 3. Grafana 관리자 비밀번호 조회 ---
print_status "Grafana 관리자 비밀번호 조회 중..."
GRAFANA_PASSWORD=$(kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)
print_status "Grafana 비밀번호: $GRAFANA_PASSWORD"

# --- 4. Grafana 서비스를 LoadBalancer로 변경 ---
print_status "Grafana 서비스 타입 확인 중..."
GRAFANA_SVC_TYPE=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.spec.type}' 2>/dev/null)
if [[ "$GRAFANA_SVC_TYPE" == "LoadBalancer" ]]; then
  print_status "Grafana 서비스가 이미 LoadBalancer 타입입니다."
else
  print_status "Grafana 서비스를 LoadBalancer로 변경 중..."
  kubectl patch svc prometheus-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
fi

# --- 5. Grafana 외부 IP 확인 ---
print_status "Grafana External IP 확인 중 (최대 5분 대기)..."
GRAFANA_IP=""
for i in {1..60}; do # 5초 * 60 = 300초 (5분) 대기
  GRAFANA_IP=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [[ -n "$GRAFANA_IP" ]]; then
    break
  fi
  echo "Grafana External IP 할당 대기 중... ($i/60)"
  sleep 5
done

# --- 6. Monitoring 네임스페이스의 서비스 조회 ---
print_status "Monitoring 네임스페이스의 서비스 목록:"
kubectl get svc -n monitoring

# --- 7. 정보 출력 ---
print_step "배포 완료 정보"
echo "----------------------------------------"
print_status "Grafana 배포 완료! 접근 정보:"
echo "  URL: http://$GRAFANA_IP/login"
echo "  사용자 이름: admin"
echo "  비밀번호: $GRAFANA_PASSWORD"
echo ""
echo "----------------------------------------"