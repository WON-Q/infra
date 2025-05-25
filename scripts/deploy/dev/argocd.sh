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

print_step "ArgoCD 배포 스크립트 시작..."

# --- 1. 네임스페이스 생성 ---
print_status "ArgoCD 네임스페이스 생성 중..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
print_status "네임스페이스 'argocd' 생성 또는 확인 완료."

# --- 2. ArgoCD 배포 ---
print_status "ArgoCD 배포 확인 중..."
if kubectl get deployment argocd-server -n argocd &>/dev/null; then
  print_warning "ArgoCD가 이미 설치되어 있습니다. 배포 단계를 건너뜁니다."
else
  print_status "ArgoCD 배포 시작..."
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  print_status "ArgoCD 배포 매니페스트 적용 완료."

  # ArgoCD 서버가 준비될 때까지 대기
  print_status "ArgoCD 서버가 준비될 때까지 대기 중 (최대 5분)..."
  kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
  print_status "ArgoCD 서버 준비 완료."
fi

# --- 3. 서비스 타입 확인 및 변경 ---
print_status "ArgoCD 서비스 타입 확인 중..."
ARGOCD_SVC_TYPE=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}' 2>/dev/null)
if [[ "$ARGOCD_SVC_TYPE" == "LoadBalancer" ]]; then
  print_status "ArgoCD 서비스가 이미 LoadBalancer 타입입니다."
else
  print_status "ArgoCD 서비스를 LoadBalancer로 변경 중..."
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
  print_status "ArgoCD 서비스 LoadBalancer 타입으로 패치 완료."
fi

# --- 4. ArgoCD 초기 관리자 비밀번호 검색 ---
print_status "ArgoCD 초기 관리자 비밀번호 검색 중..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
print_status "ArgoCD 초기 비밀번호 검색 완료."

# --- 5. ArgoCD LoadBalancer IP 확인 ---
print_status "ArgoCD LoadBalancer IP 확인 중 (최대 5분 대기)..."
ARGOCD_IP=""
for i in {1..60}; do # 5초 * 60 = 300초 (5분) 대기
  ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [[ -n "$ARGOCD_IP" ]]; then
    break
  fi
  echo "ArgoCD LoadBalancer IP 할당 대기 중... ($i/60)"
  sleep 5
done

# --- 6. ArgoCD 네임스페이스의 서비스 조회 ---
print_status "ArgoCD 네임스페이스의 서비스 목록:"
kubectl get svc -n argocd

# --- 7. 정보 출력 ---
print_step "배포 완료 정보"
echo "----------------------------------------"
print_status "ArgoCD 배포 완료! 접근 정보:"
echo "  URL: https://$ARGOCD_IP"
echo "  사용자 이름: admin"
echo "  초기 비밀번호: $ARGOCD_PASSWORD"
echo ""
echo "----------------------------------------"