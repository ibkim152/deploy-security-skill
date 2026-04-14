# Django 플러그인

## 감지 조건
- `requirements.txt`/`pyproject.toml`에 `django` 존재
- 소스코드에 `from django` 또는 `import django`

## 스캔 패턴

### CORS
- 감지: `CORS_ALLOWED_ORIGINS = ["http://localhost:3000"]` (settings.py)

### 보안 헤더
- 감지: `django.middleware.security.SecurityMiddleware` 및 관련 설정
- 확인: `SECURE_HSTS_SECONDS`, `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`

### 인증
- 감지: `@login_required` 데코레이터 유무
- 민감 뷰에 적용 여부 확인

### Rate Limiting
- 라이브러리: `django-ratelimit`

### 설정 파일
- `settings.py`, `settings/production.py`, `.env`

---

## 자동 조치

**수정 전 반드시 확인**: 코어 SKILL.md의 "코드 수정 전 존재 확인 규칙"을 따른다.
- CORS: `os.environ.get("CORS_ORIGINS")` 이미 사용 → 건너뜀
- Rate Limiting: `django_ratelimit` 이미 import → 건너뜀
- 인증: 해당 뷰에 `@login_required` 이미 적용 → 건너뜀
- 보안 설정: `SECURE_HSTS_SECONDS` 이미 설정 → 값만 확인

### CORS (3-3)
```python
# Before
CORS_ALLOWED_ORIGINS = ["http://localhost:3000"]
# After
CORS_ALLOWED_ORIGINS = os.environ.get("CORS_ORIGINS", "http://localhost:3000").split(",")
```

### Insecure Defaults (3-4)
settings.py에 SECRET_KEY 검증 삽입. 기존 Django의 `SECRET_KEY` 로드 직후에 `_validate_secret` 호출.

### Rate Limiting (3-5)
```python
from django_ratelimit.decorators import ratelimit

@ratelimit(key="ip", rate="5/m", block=True)
def login_view(request): ...
```
`requirements.txt`에 `django-ratelimit` 추가.

### 엔드포인트 인증 (3-6)
```python
@login_required
def sensitive_view(request): ...
```

### Django 보안 설정 강화
```python
# settings.py에 추가/수정
SECURE_HSTS_SECONDS = 31536000
SECURE_SSL_REDIRECT = os.environ.get("DJANGO_SSL_REDIRECT", "True") == "True"
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
```

---

## 검증
- CORS: settings.py에 localhost 하드코딩 0건
- Rate Limiting: 로그인 뷰에 `@ratelimit` 존재
- 보안 설정: `SECURE_HSTS_SECONDS > 0`, `SESSION_COOKIE_SECURE = True`
