# /deploy-security — Claude Code 프로덕션 배포 보안 스킬

AI가 생성한 코드를 클라우드 서버에 배포할 때, **보안 점검 + 자동 조치 + 원클릭 배포 스크립트**를 생성합니다.

## 설치

```bash
git clone https://github.com/ibkim152/deploy-security-skill.git
cd deploy-security-skill
bash install.sh
```

## 사용법

Claude Code에서 프로젝트 디렉토리에서 실행:

```
/deploy-security              # 전체 점검 + 조치 + 배포 스크립트 생성
/deploy-security scan         # 점검만 (코드 수정 안 함)
/deploy-security dry-run      # 점검 + 조치 계획만 (실제 수정 안 함)
/deploy-security fix          # 이전 결과 기반 조치만
```

## 지원 프레임워크

| 프레임워크 | 지원 수준 |
|-----------|----------|
| Python Streamlit | 완전 지원 (전용 플러그인) |
| Python FastAPI | 완전 지원 |
| Python Django | 완전 지원 |
| Python Flask | 완전 지원 |
| Node.js Express | 완전 지원 |
| Node.js Next.js | 완전 지원 |
| Java Spring | 완전 지원 |
| Go | 완전 지원 |
| Rust | 완전 지원 |
| PHP Laravel | 완전 지원 |
| 기타 | 공통 규칙 스캔 (프레임워크 특화 없음) |

## 지원 인프라

| 인프라 | 지원 수준 |
|--------|----------|
| Bare metal (직접 서버) | 완전 지원 + deploy.sh 생성 |
| Docker / Docker Compose | 완전 지원 |
| Kubernetes | 스캔 + 체크리스트 |
| Serverless | 스캔 + 체크리스트 |
| PaaS (Vercel/Netlify) | 스캔 + 체크리스트 |

## 지원 OS (deploy.sh 자동 분기)

- Ubuntu / Debian (`apt`)
- Oracle Linux / RHEL / Rocky / CentOS (`dnf`)
- Amazon Linux (`dnf`)

## 점검 영역 (7+1)

1. **시크릿 노출** — API 키 하드코딩, .gitignore/.dockerignore 상태
2. **localhost 하드코딩** — CORS, URL 직접 구성 (오탐 방지 포함)
3. **Docker 보안** — root 실행, .env 포함, latest 태그
4. **HTTPS/TLS** — 리버스 프록시, SSL 설정
5. **보안 헤더** — HSTS, CSP, X-Frame-Options 등
6. **개인정보(PII)** — 주민번호, 이메일, 전화번호, 로컬 경로
7. **인프라 설정** — DB 포트 외부 노출, healthcheck, 백업
8. **프레임워크 특화** — 프레임워크별 플러그인 자동 로드

## 산출물

```
_workspace/
  deploy_security_report.md       # 점검 보고서
  production_deploy_guide.md      # 배포 가이드

scripts/
  deploy.sh                       # 원클릭 배포 스크립트 (서버에서 실행)

프로젝트 루트/
  .gitignore                      # (없으면 생성)
  .env.production.example         # 프로덕션 환경변수 템플릿
  nginx/nginx.conf                # (리버스 프록시 필요 시)
```

## 파일 구조

```
deploy-security/
├── SKILL.md                    # 코어 오케스트레이터
├── references/
│   ├── core-scan-rules.md      # 공통 스캔 규칙
│   ├── report-template.md      # 보고서 생성 템플릿
│   ├── deploy-guide-template.md # 배포 가이드 템플릿
│   ├── deploy-script-template.md # deploy.sh 생성 규칙
│   ├── infra-targets.md        # 인프라 타겟 감지
│   └── os-commands.md          # OS별 명령어 + 트러블슈팅
└── plugins/
    ├── python-streamlit.md
    ├── python-fastapi.md
    ├── python-django.md
    ├── python-flask.md
    ├── node-express.md
    ├── node-nextjs.md
    ├── java-spring.md
    ├── go-generic.md
    ├── rust-generic.md
    └── php-laravel.md
```
