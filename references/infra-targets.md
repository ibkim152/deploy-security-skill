# 인프라 타겟 감지

## 감지 규칙

| 시그니처 | 인프라 타겟 | 지원 수준 |
|---------|-----------|----------|
| `docker-compose*.yml` | Docker Compose | 완전 지원 (파일 생성 + 코드 수정) |
| `Dockerfile` (compose 없음) | Docker 단독 | 완전 지원 |
| 위 모두 없음 + 서버 대상 | Bare metal | 완전 지원 (nginx 생성 포함) |
| `k8s/`, `kubernetes/`, `*deployment.yaml`, `*ingress.yaml` | Kubernetes | 스캔 + 보고서 경고 |
| `serverless.yml`, `template.yaml`(SAM), `amplify.yml` | Serverless | 스캔 + 보고서 경고 |
| `vercel.json`, `netlify.toml`, `railway.toml`, `fly.toml` | PaaS | 스캔 + 보고서 경고 |

---

## 타겟별 범위 제한 경고

### Kubernetes 감지 시
```
⚠ Kubernetes 환경이 감지되었습니다. 이 스킬은 애플리케이션 레벨 보안을 점검합니다.
다음은 별도 점검이 필요합니다:
- K8s Secret 암호화 (etcd encryption, sealed-secrets)
- Ingress TLS 설정
- NetworkPolicy (Pod 간 통신 제어)
- RBAC (서비스 계정 최소 권한)
- PodSecurityPolicy / PodSecurityStandards
- Resource limits/requests
추천 도구: kube-bench, kubesec, trivy k8s
```

### Serverless 감지 시
```
⚠ Serverless 환경이 감지되었습니다.
다음은 별도 점검이 필요합니다:
- IAM 역할 최소 권한 (Lambda/Cloud Function)
- API Gateway 인증 및 쓰로틀링
- 환경변수 KMS 암호화
- VPC 연결 설정 (DB 접근 시)
- 레이어/의존성 보안
추천 도구: prowler, ScoutSuite
```

### PaaS 감지 시
```
⚠ PaaS 환경이 감지되었습니다.
다음은 이 스킬의 범위 밖입니다:
- 플랫폼 보안 설정 (대시보드에서 확인)
- 보안 헤더 (플랫폼이 관리, vercel.json/netlify.toml에서 커스터마이즈)
- SSL 인증서 (플랫폼 자동 발급)
주의: nginx.conf, docker-compose.prod.yml은 PaaS에서 불필요하므로 생성하지 않습니다.
```

---

## 타겟별 Phase 3 분기

| 조치 항목 | Docker Compose | Docker 단독 | Bare metal | K8s | Serverless | PaaS |
|----------|:-:|:-:|:-:|:-:|:-:|:-:|
| .gitignore/.dockerignore | O | O | O | O | O | O |
| .env.production.example | O | O | O | O | O | O |
| nginx/nginx.conf | O | O | O | X | X | X |
| docker-compose.prod.yml | O | X | X | X | X | X |
| certbot-init.sh | O | O | O | X | X | X |
| scripts/backup-db.sh | O | O | O | X (별도) | X | X |
| CORS/Rate Limit/Auth (코드) | O | O | O | O | O | O |
| K8s 보안 체크리스트 | X | X | X | 보고서 | X | X |
| Serverless 체크리스트 | X | X | X | X | 보고서 | X |
| PaaS 체크리스트 | X | X | X | X | X | 보고서 |
