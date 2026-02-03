# Pitin EKS

Pitin 서비스들을 AWS EKS에 배포하기 위한 Kubernetes 매니페스트 저장소입니다.

## 아키텍처

- **단일 ALB**: 모든 서비스가 하나의 ALB 공유
- **단일 네임스페이스**: 모든 서비스가 `pitin-service` 네임스페이스에 배포
- **경로 기반 라우팅**: URL 경로로 서비스 분기 (`/bsms`, `/bsms-dev` 등)
- **HTTPS**: ACM 인증서를 통한 TLS 종료

## 디렉토리 구조

```
pitin-eks/
├── deploy.sh              # 배포 스크립트
├── namespace.yaml         # pitin-service 네임스페이스 (공용)
├── ingressclass.yaml      # ALB IngressClass (클러스터당 1회 적용)
├── ingress.yaml           # 통합 Ingress (경로 기반 라우팅)
├── env/
│   ├── common.env         # 공통 환경 변수 (CERTIFICATE_ARN 등)
│   ├── bsms.env           # BSMS 라이브 환경 변수
│   └── bsms.dev.env       # BSMS 개발 환경 변수
├── BSMS/                  # BSMS 라이브 서버
│   ├── deployment.yaml
│   ├── service.yaml
│   └── hpa.yaml
└── BSMS-dev/              # BSMS 개발 서버
    ├── deployment.yaml
    └── service.yaml
```

## 서비스 목록

| 서비스 | 경로 | 환경 |
|--------|------|------|
| BSMS | service.pitin-ev.com/bsms | Live |
| BSMS-dev | service.pitin-ev.com/bsms-dev | Dev |

## 사전 요구사항

- AWS EKS 클러스터 (AWS Load Balancer Controller 설치됨)
- kubectl 클러스터 연결 설정
- ALB 생성을 위한 IAM 권한
- ACM 인증서 (`*.pitin-ev.com` 또는 `service.pitin-ev.com`)
- `envsubst` 설치 (macOS: 기본 포함, Linux: `gettext` 패키지)

## 환경 변수 설정

### env/common.env

ingress에서 사용하는 공통 환경 변수입니다. `deploy.sh` 실행 시 `envsubst`를 통해 치환됩니다.

```bash
CERTIFICATE_ARN=arn:aws:acm:ap-northeast-2:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### env/bsms.env / env/bsms.dev.env

애플리케이션에서 사용하는 환경 변수들을 설정합니다 (DB 접속 정보, API 키 등).

## 배포 방법

### 1. IngressClass 적용 (클러스터당 1회)

> 이미 적용되어 있다면 이 단계는 건너뛰세요.

```bash
kubectl get ingressclass alb
kubectl apply -f ingressclass.yaml
```

### 2. Secret 생성 (최초 1회)

```bash
# 네임스페이스 생성
kubectl create namespace pitin-service

# BSMS 라이브용 Secret
kubectl create secret generic bsms-backend-secret --from-env-file=env/bsms.env -n pitin-service

# BSMS 개발용 Secret
kubectl create secret generic bsms-dev-backend-secret --from-env-file=env/bsms.dev.env -n pitin-service
```

### 3. 서비스 배포

```bash
# BSMS 라이브 배포
./deploy.sh bsms

# BSMS 개발 배포
./deploy.sh bsms-dev

# 전체 배포
./deploy.sh all
```

### 4. 배포 전 확인 (Dry-run)

```bash
./deploy.sh bsms --dry-run
./deploy.sh bsms-dev --dry-run
```

### 5. DNS 설정

배포 후 ALB DNS 주소를 확인합니다.

```bash
kubectl get ingress -n pitin-service -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

도메인 관리 툴에서 CNAME 레코드를 추가합니다:

| 호스트 | 타입 | 값 |
|--------|------|-----|
| service | CNAME | `k8s-pitinser-xxxxxx.ap-northeast-2.elb.amazonaws.com` |

## 배포 확인

```bash
# 전체 리소스 확인
kubectl get all -n pitin-service

# Ingress 상태 확인
kubectl get ingress -n pitin-service
```

## 로그 확인

```bash
# BSMS 라이브 로그 (실시간)
kubectl logs -f deployment/bsms-backend -n pitin-service

# BSMS 개발 로그 (실시간)
kubectl logs -f deployment/bsms-dev-backend -n pitin-service
```

## 환경변수 확인

```bash
# BSMS 라이브 환경변수 확인
kubectl get secret bsms-backend-secret -n pitin-service -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'

# BSMS 개발 환경변수 확인
kubectl get secret bsms-dev-backend-secret -n pitin-service -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
```

## API 문서 (Swagger)

| 서비스 | Swagger URL |
|--------|-------------|
| BSMS | https://service.pitin-ev.com/bsms/swagger-ui/index.html |
| BSMS-dev | https://service.pitin-ev.com/bsms-dev/swagger-ui/index.html |

## Secret 업데이트

```bash
# BSMS 라이브 Secret 업데이트
kubectl delete secret bsms-backend-secret -n pitin-service
kubectl create secret generic bsms-backend-secret --from-env-file=env/bsms.env -n pitin-service
kubectl rollout restart deployment/bsms-backend -n pitin-service

# BSMS 개발 Secret 업데이트
kubectl delete secret bsms-dev-backend-secret -n pitin-service
kubectl create secret generic bsms-dev-backend-secret --from-env-file=env/bsms.dev.env -n pitin-service
kubectl rollout restart deployment/bsms-dev-backend -n pitin-service
```

## 새 서비스 추가 시

1. 서비스 폴더 생성 (예: `membership/`)
2. `deployment.yaml`, `service.yaml` 작성 (namespace: `pitin-service`)
3. `ingress.yaml`에 새 경로 추가:
   ```yaml
   - path: /<service-name>
     pathType: Prefix
     backend:
       service:
         name: <service>-svc
         port:
           number: 80
   ```
4. `deploy.sh`에 새 서비스 추가
5. `env/` 폴더에 환경 변수 파일 추가
6. 애플리케이션에 `server.servlet.context-path=/<service-name>` 설정 필요 (Ingress에서 path rewrite 미사용)
