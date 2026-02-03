# CLAUDE.md

이 파일은 Claude Code가 이 저장소에서 작업할 때 참고하는 가이드입니다.

## 프로젝트 개요

Pitin의 모든 서비스를 AWS EKS에 배포하기 위한 Kubernetes 매니페스트 저장소입니다.

## 디렉토리 구조

```
pitin-eks/
├── deploy.sh              # 배포 스크립트 (envsubst로 변수 치환)
├── namespace.yaml         # pitin-service 네임스페이스 (공용)
├── ingressclass.yaml      # ALB IngressClass (클러스터당 1회 적용)
├── ingress.yaml           # 통합 Ingress (경로 기반 라우팅)
├── env/
│   ├── common.env         # 공통 환경 변수 (CERTIFICATE_ARN)
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

| 서비스 | 네임스페이스 | 경로 | 환경 |
|--------|-------------|------|------|
| BSMS | pitin-service | service.pitin-ev.com/bsms | Live |
| BSMS-dev | pitin-service | service.pitin-ev.com/bsms-dev | Dev |

## 아키텍처

- **단일 ALB**: 모든 서비스가 하나의 ALB 공유
- **단일 네임스페이스**: 모든 서비스가 `pitin-service` 네임스페이스에 배포
- **경로 기반 라우팅**: URL 경로로 서비스 분기 (`/bsms`, `/bsms-dev` 등)
- **HTTPS**: ACM 인증서를 통한 TLS 종료

## 배포 방법

```bash
# 서비스 배포 (envsubst로 CERTIFICATE_ARN 치환)
./deploy.sh bsms
./deploy.sh bsms-dev
./deploy.sh all

# dry-run (적용 전 확인)
./deploy.sh bsms --dry-run
```

## 새 서비스 추가 시

README.md의 "새 서비스 추가 시" 섹션 참고

### 핵심 규칙

1. 서비스 폴더 생성 시 `deployment.yaml`, `service.yaml` 필수
2. 모든 리소스의 namespace는 `pitin-service`
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
4. `deploy.sh`의 case문에 새 서비스 추가
5. `env/` 폴더에 환경 변수 파일 추가
