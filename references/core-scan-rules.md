# 공통 스캔 규칙 (프레임워크 무관)

## 1. 시크릿 노출

### 검색 대상
- .env, .env.* 파일 내 실제 키 값
- 소스코드 하드코딩 패턴: `xoxb-`, `xoxp-`, `sk-`, `pk_`, `AKIA`, `AIza`, `ghp_`, `gho_`
- Base64 인코딩된 40자 이상 문자열
- .gitignore 존재 여부 + .env 포함 여부
- .dockerignore 존재 여부 + .env 포함 여부

### 판정 분기
- [.gitignore에 .env + .dockerignore에 .env] → .env 내 시크릿: 정상, 취약 시크릿: 경고
- [.gitignore에 .env 없음] → 긴급 (git push 시 노출)
- [.dockerignore에 .env 없음] → 긴급 (Docker 이미지에 포함)
- 소스코드에 API 키 하드코딩 → 상 (.gitignore 여부 무관)
- .env.example에 실제 값 → 중

### 시크릿 키 취약 판정 기준
```
취약 패턴: 길이 16자 미만, "changeme", "secret", "password", "test", "default",
"example", "your-secret", "insecure", "dev", "local", 반복 문자(aaaa, 1234)

대상 키: SECRET_KEY, JWT_SECRET*, APP_SECRET, NEXTAUTH_SECRET, SESSION_SECRET,
ENCRYPTION_KEY, API_SECRET, *_SECRET, *_SECRET_KEY
```

### 외부 등록 시크릿 보호 (절대 자동 교체 금지)
`*_CLIENT_ID`, `*_CLIENT_SECRET`, `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET`, `GOOGLE_CLIENT_*`, `*_API_KEY`, `*_WEBHOOK_SECRET` → 보고서에 "외부 등록 시크릿 — 수동 관리 필요" 기재, 값 강도만 점검

### 시크릿 교체 명령
- Python: `python -c "import secrets; print(secrets.token_hex(32))"`
- Node.js: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`
- 범용: `openssl rand -hex 32`

---

## 2. localhost 하드코딩

### 검색 대상
`localhost`, `127.0.0.1`, `0.0.0.0` — 범위: *.py, *.ts, *.tsx, *.js, *.yml, *.yaml, *.json, .env*, Dockerfile, docker-compose*

### 오탐 방지 규칙 (중요)
- 환경변수 기본값 (`|| "http://localhost"`, `os.environ.get("X", "localhost")`) → 무시
- Dockerfile CMD의 `0.0.0.0` → 무시 (컨테이너 바인딩)
- docker-compose 내부 서비스명 → 무시 (Docker 네트워크)
- 삼항 연산자 분기 (`isProduction ? prodUrl : "localhost"`) → 무시
- **테스트 파일** (*.test.*, *.spec.*, __tests__/) → 무시
- CORS/allow_origins에 직접 하드코딩 → 수정 필요
- 코드 본문에 직접 URL 구성 → 수정 필요

---

## 3. Docker 보안

| 점검 항목 | 기준 | 우선순위 |
|----------|------|---------|
| USER 지시문 없음 (root 실행) | Dockerfile에 USER 존재 여부 | 상 |
| .env가 이미지에 포함 가능 | COPY . . + .dockerignore 미설정 | 긴급 |
| .dockerignore 없음 | 파일 존재 여부 | 중 |
| latest 태그 사용 | 베이스 이미지 태그 확인 | 하 |
| 포트 외부 바인딩 과다 | docker-compose ports 확인 | 중 |

---

## 4. HTTPS/TLS

- nginx/caddy/traefik 설정 유무
- SSL 인증서 설정 유무
- docker-compose에 443 포트 유무
- 리버스 프록시 없음 → 상, HTTPS 설정 없음 → 상

---

## 5. 보안 헤더

nginx 또는 앱 미들웨어에서 확인:
| 헤더 | 우선순위 |
|------|---------|
| Strict-Transport-Security (HSTS) | 상 |
| Content-Security-Policy (CSP) | 중 |
| X-Content-Type-Options | 하 |
| X-Frame-Options | 하 |
| X-XSS-Protection | 하 |
| Referrer-Policy | 하 |

---

## 6. 개인정보(PII) 검출

### 패턴
- 주민번호: `\d{6}-[1-4]\d{6}` → 긴급
- 이메일 (테스트/더미 제외): `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}` → 상
- 전화번호: `010-\d{4}-\d{4}` → 상
- 로컬 경로: `/Users/`, `/home/`, `C:\Users\` → 중
- 공인 IP 주소 → 중
- 더미/테스트 데이터 (`test@example.com`, `010-0000-0000`) → 하 (허용)

### 기존 암호화 인식
`cryptography`, `Fernet`, `AES`, `bcrypt` 등 감지 시 해당 필드는 "암호화 적용됨" 판정. 키 관리만 추가 점검.

---

## 7. 인프라 설정

| 점검 항목 | 우선순위 |
|----------|---------|
| DB 포트(5432, 3306, 27017) 외부 노출 | 긴급 |
| ENV=production 미설정 | 상 |
| 로그 레벨 DEBUG | 중 |
| healthcheck 미설정 | 중 |
| 백업 미설정 | 중 |

---

## DB 백업 스크립트 생성 규칙

| DB | 감지 패턴 | 백업 명령 |
|----|----------|----------|
| PostgreSQL | `postgres://`, `psycopg2` | `pg_dump` |
| MySQL | `mysql://`, `pymysql` | `mysqldump` |
| MongoDB | `mongodb://`, `pymongo`, `mongoose` | `mongodump` |
| SQLite | `sqlite:///`, `*.db`, `sqlite3` | `cp` (파일 복사) |

`scripts/backup-db.sh` 생성: 환경변수 기반, gzip 압축, 7일 보관, docker exec 사용(컨테이너 환경 시).

---

## 선택적 도구 통합

외부 도구가 설치된 경우 자동 활용:

| 도구 | 감지 | 활용 | 없을 때 fallback |
|------|------|------|-----------------|
| gitleaks | `which gitleaks` | 시크릿 검출 정밀화 (영역 1) | 내장 패턴 grep |
| semgrep | `which semgrep` | AST 기반 코드 패턴 분석 | 내장 패턴 grep |
| trivy | `which trivy` | 의존성 CVE + Dockerfile 분석 | Dockerfile 직접 분석만 |
| npm audit / pip audit | 패키지 매니저 존재 시 | 의존성 취약점 보고 | 보고서에 "수동 실행 권고" |
