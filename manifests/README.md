# Kubernetes Manifests

이 폴더는 WON-Q 프로젝트의 모든 Kubernetes 매니페스트 파일들을 포함합니다.

## 구조

```
manifests/
├── app-card/
│   ├── namespace.yml
│   └── server/
│       ├── deployment.yml
│       └── service.yml
├── bank/
│   ├── namespace.yml
│   └── server/
│       ├── deployment.yml
│       └── service.yml
├── card/
│   ├── namespace.yml
│   └── server/
│       ├── deployment.yml
│       └── service.yml
├── pg/
│   ├── namespace.yml
│   ├── client/
│   │   ├── deployment.yml
│   │   └── service.yml
│   └── server/
│       ├── deployment.yml
│       └── service.yml
└── wonq-order/
    ├── namespace.yml
    ├── client/
    │   ├── merchant/
    │   │   ├── deployment.yml
    │   │   └── service.yml
    │   └── user/
    │       ├── deployment.yml
    │       └── service.yml
    └── server/
        ├── deployment.yml
        └── service.yml
```

## 서비스 목록

### WONQ Order 시스템

- **wonq-order-user-client**: 사용자 클라이언트 (포트: 443 → 3000)
- **wonq-order-merchant-client**: 가맹점 클라이언트 (포트: 443 → 3000)
- **wonq-order-server**: 주문 서버 (포트: 443 → 8080)

### 카드 시스템

- **card-server**: 카드 서버 (포트: 8080)

### 앱 카드 시스템

- **app-card-server**: 앱 카드 서버 (포트: 8080)

### 은행 시스템

- **bank-server**: 은행 서버 (포트: 9090)

### PG (Payment Gateway) 시스템

- **pg-client**: PG 클라이언트 (포트: 443 → 3000)
- **pg-server**: PG 서버 (포트: 443 → 8080)

## 특징

- **Service Mesh**: 모든 네임스페이스에 Linkerd 주입 활성화
- **Load Balancer**: 모든 서비스가 LoadBalancer 타입으로 설정
- **Container Registry**: Google Cloud Artifact Registry 사용
- **High Availability**: 모든 서비스 3개 레플리카로 구성

## 배포 방법

### 직접 배포

```bash
# 네임스페이스 생성
kubectl apply -f manifests/wonq-order/namespace.yml
kubectl apply -f manifests/app-card/namespace.yml
kubectl apply -f manifests/card/namespace.yml
kubectl apply -f manifests/bank/namespace.yml
kubectl apply -f manifests/pg/namespace.yml

# 각 서비스 배포
kubectl apply -f manifests/wonq-order/client/user/
kubectl apply -f manifests/wonq-order/client/merchant/
kubectl apply -f manifests/wonq-order/server/
kubectl apply -f manifests/app-card/server/
kubectl apply -f manifests/card/server/
kubectl apply -f manifests/bank/server/
kubectl apply -f manifests/pg/client/
kubectl apply -f manifests/pg/server/
```
