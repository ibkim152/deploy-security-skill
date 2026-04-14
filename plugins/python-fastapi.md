# FastAPI 플러그인

## 감지 조건
- `requirements.txt`/`pyproject.toml`/`Pipfile`에 `fastapi` 존재
- 소스코드에 `from fastapi` 또는 `import fastapi`
- 우선순위: Streamlit > FastAPI (streamlit이 먼저 감지되면 이 플러그인 로드 안 함)

## 스캔 패턴

### CORS
- 감지: `allow_origins=["http://localhost` 하드코딩
- 파일: *.py (main.py, app.py 등)

### 보안 헤더
- 감지: FastAPI 미들웨어로 보안 헤더 설정 여부
- 확인: `TrustedHostMiddleware`, 커스텀 미들웨어에서 헤더 설정

### 인증
- 감지: `Depends(get_current_user)` 또는 동등한 인증 의존성
- 패턴: `Depends\(.*(?:get_current_user|verify_token|auth)`
- 민감 엔드포인트: `/admin`, `/scan`, `/export`, `/users`, `/config`, `/debug`

### Rate Limiting
- 감지: `from slowapi` 또는 `slowapi` 의존성
- 대상: `/login`, `/auth`, `/token`, `/reset-password`, `/verify`

### 설정 파일
- 시크릿: `.env`, `config.py`, `settings.py`
- DB: `DATABASE_URL` 환경변수

---

## 자동 조치 (fix)

**수정 전 반드시 확인**: 코어 SKILL.md의 "코드 수정 전 존재 확인 규칙"을 따른다.
- CORS: `os.environ.get("CORS_ORIGINS")` 이미 존재 → 건너뜀
- Rate Limiting: `from slowapi` 이미 존재 → 건너뜀
- 인증: 해당 라우트에 `Depends(...)` 이미 존재 → 건너뜀
- Insecure Defaults: `_INSECURE_DEFAULTS` 이미 존재 → 누락 패턴만 추가

### CORS 환경변수화 (3-3)
```python
# Before
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost:3000"], ...)

# After
import os
ALLOWED_ORIGINS = os.environ.get("CORS_ORIGINS", "http://localhost:3000").split(",")
app.add_middleware(CORSMiddleware, allow_origins=ALLOWED_ORIGINS, ...)
```
`.env.production.example`에 `CORS_ORIGINS=https://yourdomain.com` 추가.

### Insecure Defaults 검증 확장 (3-4)
`config.py` 또는 시크릿 로드 파일에 검증 함수 삽입:
```python
_INSECURE_DEFAULTS = {
    "changeme", "secret", "password", "test", "default", "example",
    "your-secret-key", "your-jwt-secret", "replace-me", "todo",
    "insecure", "development", "debug", "admin", "12345", "",
}

def _validate_secret(name: str, value: str) -> str:
    if value.lower().strip() in _INSECURE_DEFAULTS or len(value) < 16:
        raise ValueError(
            f"환경변수 {name}이(가) 안전하지 않습니다. "
            f"python -c \"import secrets; print(secrets.token_hex(32))\""
        )
    return value
```
기존 검증 목록이 있으면 누락 패턴만 추가.

### Rate Limiting 추가 (3-5)
```python
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# 로그인 엔드포인트:
@limiter.limit("5/minute")
```
- `requirements.txt`에 `slowapi` 추가
- Redis 감지 시: `storage_uri=os.environ.get("REDIS_URL", "memory://")`

### 미인증 엔드포인트 보호 (3-6)
```python
# 민감 라우트에 인증 의존성 추가
@router.get("/scan-all")
async def scan_all(current_user: User = Depends(get_current_user)):

# /admin 패턴은 관리자 검증 추가
async def require_admin(current_user: User = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user
```
- public API (회원가입, 로그인, healthcheck)에는 추가 안 함
- 프로젝트에 인증 시스템이 없으면 → 보고서에 "인증 시스템 구축 필요" 권고만

---

## 검증 (verify)

- CORS: 소스코드에 localhost 직접 하드코딩 0건, 환경변수 기반 분기 존재
- Insecure Defaults: `_INSECURE_DEFAULTS`에 15개+ 패턴 포함, 검증 함수 호출 확인
- Rate Limiting: 로그인 엔드포인트에 `@limiter.limit` 존재, `slowapi` 의존성 포함
- 엔드포인트 인증: 민감 라우트에 `Depends(...)` 존재, public API는 인증 없이 접근 가능
