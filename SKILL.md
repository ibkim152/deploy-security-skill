---
name: deploy-security
description: "프로덕션 배포 보안 점검 — 시크릿 노출, localhost 하드코딩, Docker 보안, HTTPS, 보안 헤더, 개인정보 검출, 인프라 설정을 한번에 점검하고 조치. 트리거: 배포 보안, 프로덕션 준비, deploy security, 배포 점검, 서버 배포, 프로덕션 체크"
---

# Deploy Security — 프로덕션 배포 보안 점검 및 조치 (모듈형)

AI가 생성한 코드를 클라우드 서버에 배포할 때 보안 점검을 자동 수행하고, 발견된 문제를 조치한다.

## 사용법

```
/deploy-security                       # 전체 점검 + 조치
/deploy-security scan                  # 점검만 (조치 안 함)
/deploy-security fix                   # 이전 결과 기반 조치만
/deploy-security dry-run               # 점검 + 조치 계획만 (실제 수정 안 함)
/deploy-security [aws|oci|gcp]         # 특정 클라우드 타겟 지정
```

## 모듈 구조

이 스킬은 코어 + references + plugins로 구성된다.

```
deploy-security/
  SKILL.md                          # 이 파일 (코어 오케스트레이터)
  references/
    core-scan-rules.md              # 프레임워크 무관 공통 스캔 규칙
    report-template.md              # 보고서 생성 (Word + Markdown fallback)
    deploy-guide-template.md        # 배포 가이드 생성 템플릿
    infra-targets.md                # 인프라 타겟 감지 (Docker/K8s/Serverless/PaaS)
  plugins/
    python-fastapi.md
    python-django.md
    python-flask.md
    python-streamlit.md
    node-express.md
    node-nextjs.md
    java-spring.md
    go-generic.md
    rust-generic.md
```

**실행 규칙**: 각 Phase에서 필요한 모듈을 Read로 로드하여 지시를 따른다. 불필요한 모듈은 로드하지 않는다.

---

## Phase 0: 프로젝트 자동 감지 (4단계)

### 0-0. 배포 대상 OS/클라우드 감지 (배포 가이드 생성 시)

배포 가이드(Phase 4) 생성 시, 대상 서버의 OS를 사용자에게 확인하거나 클라우드 타겟에서 추정한다.
`references/os-commands.md`를 Read로 로드하여 OS별 명령어를 분기한다.

| 클라우드 | 기본 OS | 패키지 매니저 | 주의사항 |
|---------|--------|-------------|---------|
| OCI | Oracle Linux 9 | `dnf` | SELinux 활성, firewalld, SSH 사용자 `opc` |
| AWS | Amazon Linux 2023 / Ubuntu | `dnf` / `apt` | Security Group + OS 방화벽 2중 |
| GCP | Debian / Ubuntu | `apt` | VPC Firewall Rules |
| NCP | Ubuntu / CentOS | `apt` / `dnf` | ACG + OS 방화벽 2중 |

**핵심**: 클라우드 서버는 **방화벽이 2겹** (클라우드 콘솔 + OS). 배포 가이드에 반드시 양쪽 모두 안내.

### 0-1. 기술스택 감지

프로젝트 루트를 스캔하여 기술스택을 판별한다:

| 시그니처 파일 | 기술스택 |
|-------------|---------|
| `package.json` | Node.js → 내부에서 Express/Next.js 구분 |
| `requirements.txt`, `pyproject.toml`, `Pipfile`, `setup.py` | Python → FastAPI/Django/Flask/Streamlit 구분 |
| `pom.xml`, `build.gradle` | Java (Spring) |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `composer.json` | PHP (미지원 프레임워크 — 스캔만) |
| `Gemfile` | Ruby (미지원 프레임워크 — 스캔만) |
| `*.csproj`, `*.sln` | .NET (미지원 프레임워크 — 스캔만) |

**Python 세부 감지 우선순위** (먼저 매칭되는 것 사용):
1. `streamlit` 임포트/의존성 → Streamlit
2. `fastapi` → FastAPI
3. `django` → Django
4. `flask` → Flask

### 0-2. 인프라 타겟 감지

`references/infra-targets.md`를 Read로 로드하여, 프로젝트의 배포 대상 인프라를 판별한다.

| 시그니처 | 인프라 타겟 |
|---------|-----------|
| `docker-compose*` | Docker Compose (완전 지원) |
| `Dockerfile` 단독 | Docker 단독 (완전 지원) |
| `k8s/`, `kubernetes/`, `deployment.yaml` | Kubernetes (스캔 + 경고) |
| `serverless.yml`, `template.yaml`(SAM) | Serverless (스캔 + 경고) |
| `vercel.json`, `netlify.toml` | PaaS (스캔 + 경고) |
| 위 모두 없음 | Bare metal (완전 지원) |

### 0-3. 모노레포 감지

다음 패턴 감지 시 모노레포로 판정:
- `pnpm-workspace.yaml`, `lerna.json`, `nx.json`, `turbo.json`
- 루트 `package.json`에 `workspaces` 필드
- `apps/` 또는 `services/` 또는 `packages/` 디렉토리에 하위 프로젝트

**모노레포 대응**: 각 서비스 디렉토리를 개별 식별하고, 서비스별로 Phase 1~5를 반복 실행한다. 루트의 공통 설정(.gitignore, docker-compose)은 한 번만 점검한다.

### 0-4. 매칭 플러그인 로드

감지된 프레임워크에 해당하는 `plugins/{framework}.md`를 Read로 로드한다.

**미지원 프레임워크 안전 가드**:
- Phase 1 스캔: 공통 규칙만 적용 (프레임워크 특화 패턴 없음)
- Phase 2 보고서: 상단에 다음 경고 삽입:
  ```
  ⚠ 부분 스캔 (Partial Scan)
  이 프로젝트의 프레임워크({framework})는 전용 스캔 패턴이 없습니다.
  공통 규칙(시크릿, Docker, PII 등)만 적용되었으며,
  프레임워크 특화 취약점(CORS, 인증, Rate Limiting 등)은 검출되지 않았을 수 있습니다.
  → 프레임워크별 보안 가이드를 참조하여 수동 점검을 권장합니다.
  ```
- Phase 3 자동 조치: 파일 생성(3-1)만 허용, 코드 수정(3-3~3-6) 차단

---

## Phase 1: 7개 영역 스캔

`references/core-scan-rules.md`를 Read로 로드하여 공통 스캔 규칙을 따른다.

### 스캔 전 도구 확인 (선택적 강화)

```bash
which gitleaks && gitleaks detect --source . --report-format json --report-path _workspace/gitleaks.json
which semgrep && semgrep --config=auto --json -o _workspace/semgrep.json .
which trivy && trivy fs . --format json -o _workspace/trivy.json
```

도구가 있으면 결과를 활용하여 정확도 향상, 없으면 내장 grep 패턴으로 스캔.

### 7개 영역

| 영역 | 내용 | 참조 |
|------|------|------|
| 1. 시크릿 노출 | API 키, 토큰 하드코딩, .gitignore/.dockerignore 상태 | core-scan-rules.md |
| 2. localhost 하드코딩 | CORS, URL 직접 구성 (오탐 방지 규칙 포함) | core-scan-rules.md |
| 3. Docker 보안 | root 실행, .env 포함, latest 태그 | core-scan-rules.md |
| 4. HTTPS/TLS | 리버스 프록시, SSL 설정 | core-scan-rules.md |
| 5. 보안 헤더 | HSTS, CSP, X-Frame-Options 등 | core-scan-rules.md |
| 6. 개인정보(PII) | 주민번호, 이메일, 전화번호, 로컬 경로 | core-scan-rules.md |
| 7. 인프라 설정 | DB 포트 외부 노출, ENV=production, healthcheck, 백업 | core-scan-rules.md |
| 8. 프레임워크 특화 | 로드된 plugin의 scan 섹션 참조 | plugins/*.md |

### 검색 제외 (중요 — 오탐 방지)

```
항상 제외: .venv/, node_modules/, .git/, __pycache__/, *.pyc, dist/, build/, .next/
테스트 제외: *.test.*, *.spec.*, __tests__/, tests/, test/, *_test.go, *_test.rs
문서 제외: *.md (README 등), docs/, CHANGELOG*
```

---

## Phase 2: 보고서 생성

`references/report-template.md`를 Read로 로드하여 보고서를 생성한다.

**생성 전략**:
1. `python3 -c "import docx"` 성공 → Word(.docx) 보고서 생성
2. 실패 → `pip install python-docx` 시도 (시스템 Python이 아닌 임시 venv 사용)
3. 여전히 실패 → **Markdown 보고서로 fallback** (`_workspace/deploy_security_report.md`)

**Markdown fallback 시에도 동일한 구조**: 표지, 요약표, 영역별 상세, 자동 조치 내역, 수동 가이드.

---

## Phase 3: 자동 조치

### 3-1. 공통 파일 생성 (모든 프레임워크)

| 파일 | 조건 | 내용 |
|------|------|------|
| `.gitignore` | 없을 때 | .env, *.db, __pycache__, .venv, node_modules 등 |
| `.dockerignore` | 없을 때 | .env, .git, .venv, node_modules, *.db 등 |
| `.env.production.example` | 항상 | 프로덕션 환경변수 템플릿 + 시크릿 생성 명령어 |

### 3-2. 시크릿 키 점검 (`core-scan-rules.md` 참조)

- .gitignore에 .env 포함 → 보고서 경고만 (.env 직접 수정 안 함)
- .gitignore에 .env 없음 → .gitignore에 추가 + 취약 시크릿 자동 교체
- 소스코드 하드코딩 → 환경변수 참조로 교체
- **외부 등록 시크릿 보호**: `*_CLIENT_ID`, `*_CLIENT_SECRET`, `*_API_KEY`, `*_BOT_TOKEN` 등은 절대 자동 교체하지 않음

### 3-3~3-6. 프레임워크 코드 수정 (plugin 참조)

로드된 `plugins/*.md`의 fix 섹션을 따라 수행:
- **3-3**: CORS 환경변수화
- **3-4**: Insecure defaults 검증 확장
- **3-5**: Rate limiting 추가
- **3-6**: 미인증 엔드포인트 보호

**코드 수정 전 존재 확인 규칙 (필수)**:
```
모든 코드 수정(3-3~3-6)은 다음 의사결정 트리를 따른다:

1. 해당 기능이 이미 존재하는가? (Grep으로 확인)
   → 존재 + 올바름: 건너뜀 (보고서에 "정상" 기재)
   → 존재 + 불완전: 기존 코드를 확장/보완 (신규 삽입 아님)
   → 미존재: plugin의 fix 패턴으로 신규 삽입

2. 신규 삽입 시 import 중복 확인:
   → 파일 상단에 동일 import가 있으면 추가하지 않음

3. 프로젝트의 코드 스타일 준수:
   → ESM(import) vs CJS(require) 감지 후 일치하는 패턴 사용
   → TypeScript vs JavaScript 감지 후 일치하는 문법 사용
```

**미지원 프레임워크에서는 3-3~3-6 전체 차단**, 보고서에 수동 조치 가이드만 기재.

### 3-7. DB 백업 스크립트 (`core-scan-rules.md` 참조)

감지된 DB(PostgreSQL/MySQL/MongoDB/SQLite)에 맞는 `scripts/backup-db.sh` 자동 생성.

### 3-8. 인프라 타겟별 추가 조치

| 타겟 | 추가 생성 | 추가 조치 |
|------|----------|----------|
| Docker Compose | `docker-compose.prod.yml`, `nginx/nginx.conf` | 포트 내부 제한, nginx 보안 헤더 |
| Docker 단독 | `nginx/nginx.conf` | Dockerfile에 USER 추가 |
| Bare metal | `nginx/nginx.conf`, `nginx/certbot-init.sh` | Let's Encrypt 가이드 |
| K8s | 생성 안 함 | 보고서에 K8s 보안 체크리스트 기재 |
| Serverless | 생성 안 함 | 보고서에 IAM/API Gateway 체크리스트 기재 |
| PaaS | 생성 안 함 | 보고서에 플랫폼별 보안 설정 가이드 기재 |

### 3-9. 원클릭 배포 스크립트 생성 (`scripts/deploy.sh`)

`references/deploy-script-template.md`를 Read로 로드하여 프로젝트 맞춤 배포 스크립트를 생성한다.

**생성 조건**: 항상 생성 (Docker/Bare metal/K8s 무관)

**스크립트가 자동 처리하는 것**:
1. OS 감지 (Ubuntu/Oracle Linux/RHEL/CentOS/Amazon Linux)
2. 패키지 매니저 분기 (apt/dnf)
3. Python/Node.js + nginx 설치
4. 방화벽 설정 (firewalld/ufw)
5. SELinux 설정 (RHEL 계열)
6. 가상환경 + 의존성 설치
7. 환경변수 파일 생성
8. 데이터 디렉토리 사전 생성
9. systemd 서비스 등록
10. nginx 리버스 프록시 설정
11. 서비스 시작 + 접속 테스트

**사용자가 할 것**: 서버 생성 → git clone → `bash scripts/deploy.sh` → 클라우드 포트 열기 → .env 편집

**프로젝트별 커스터마이징**: Phase 0 감지 결과를 스크립트 상단의 변수에 반영:
- `APP_NAME`, `APP_DIR`, `APP_ENTRY`, `APP_PORT`: 프로젝트 구조에서 감지
- `ExecStart`: 프레임워크별 실행 명령 (streamlit/uvicorn/gunicorn/node)
- `nginx location`: 프레임워크별 프록시 설정 (WebSocket 필요 여부 등)
- `mkdir -p`: .gitignore에 있으면서 코드에서 참조되는 데이터 경로

---

## Phase 4: 배포 가이드 생성

`references/deploy-guide-template.md`와 `references/os-commands.md`를 Read로 로드하여 맞춤 배포 가이드를 생성한다.

**생성 전략**: Phase 2와 동일 (Word 우선 → Markdown fallback)

**OS 분기 규칙**: 사용자가 클라우드/OS를 지정한 경우 해당 OS 명령어로 생성. 미지정 시 Ubuntu + RHEL 계열 양쪽 명령어를 병기.

포함 내용:
1. 외부 서비스 감지 및 설정 가이드 (OAuth, 결제, API 등 — 감지된 것만)
2. 빌드 시점 환경변수 경고 (NEXT_PUBLIC_, VITE_ 등)
3. 서버 배포 체크리스트 (인프라 타겟별 + **OS별** 맞춤)
4. **방화벽 2중 구조 안내** (클라우드 콘솔 + OS 방화벽 — 둘 다 열어야 함)
5. **SELinux 설정** (RHEL 계열: `setsebool -P httpd_can_network_connect 1`)
6. **Git clone 안내** (토큰을 URL에 넣지 않는 방식 기본)
7. **데이터 디렉토리 사전 생성** (Git에 미포함된 데이터 폴더)
8. 트러블슈팅 가이드 (**"연결할 수 없음" 진단 순서** 포함)

---

## Phase 5: 검증

Phase 1을 재실행하여 조치 결과를 확인한다.

검증 항목:
- 시크릿: .env의 SECRET_KEY가 64자 이상 hex인지
- CORS: localhost 직접 하드코딩 0건
- Rate Limiting: 로그인 엔드포인트에 제한 존재
- 엔드포인트 인증: 민감 라우트에 인증 체크 존재
- DB 백업: scripts/backup-db.sh 존재 + 실행 권한
- 프레임워크 특화: 로드된 plugin의 verify 섹션 참조

**검증 실패 시**: 해당 항목만 재조치 (전체 재실행 아님)

---

## 산출물

```
_workspace/
  deploy_security_report.docx (또는 .md)   # 점검 보고서
  production_deploy_guide.docx (또는 .md)  # 배포 가이드
  generate_report.py                        # Word 보고서 생성 스크립트 (docx 사용 시)
  generate_deploy_guide.py                  # Word 배포 가이드 생성 스크립트 (docx 사용 시)

프로젝트 루트/
  .gitignore, .dockerignore                # (없으면 생성)
  .env.production.example                  # 프로덕션 환경변수 템플릿
  docker-compose.prod.yml                  # (Docker 사용 시)
  nginx/nginx.conf, nginx/certbot-init.sh  # (리버스 프록시 필요 시)
  scripts/deploy.sh                          # 원클릭 배포 스크립트 (항상 생성)
  scripts/backup-db.sh                     # (DB 감지 시)
```

---

## 에러 핸들링

| 상황 | 대응 |
|------|------|
| .env 없음 | .env.example 또는 환경변수만 스캔 |
| Docker 미사용 | Docker 영역 건너뛰기 |
| git 미사용 | .gitignore 건너뛰기 |
| 모노레포 | 서비스별 개별 스캔 (0-3 참조) |
| 미지원 프레임워크 | Phase 1~2 수행, Phase 3 코드 수정 차단, 수동 가이드 제공 |
| python-docx 설치 불가 | Markdown fallback 자동 전환 |
| K8s/Serverless/PaaS | 스캔 수행 + 범위 제한 경고 + 플랫폼별 체크리스트 제공 |
| 기존 암호화 존재 | PII 검출 시 암호화 적용 여부 교차 확인 |
| 이미 프로덕션 배포 상태 | 긴급 항목 우선 알림 |

## 범위 제한 경고 (중요)

다음 상황에서 보고서 상단에 경고를 삽입한다:

```
⚠ 점검 범위 제한 알림
- 이 점검은 애플리케이션 코드 및 설정 파일 수준의 보안을 다룹니다
- 다음 영역은 별도 점검이 필요합니다:
  - 클라우드 IAM/접근제어 (AWS IAM, GCP SA 등)
  - 네트워크 보안 (VPC, 서브넷, 방화벽)
  - 의존성 CVE 취약점 (npm audit / pip audit / trivy 권장)
  - OWASP Top 10 동적 취약점 (침투 테스트 권장)
{인프라 타겟별 추가 경고}
```
