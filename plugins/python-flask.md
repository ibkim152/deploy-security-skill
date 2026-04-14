# Flask 플러그인

## 감지 조건
- `requirements.txt`/`pyproject.toml`에 `flask` 존재 (django/fastapi/streamlit 미감지 시)
- 소스코드에 `from flask` 또는 `import flask`

## 스캔 패턴

### CORS
- 감지: `CORS(app, origins=["http://localhost:3000"])` 또는 `@cross_origin`

### 보안 헤더
- 감지: `flask-talisman` 사용 여부, `@app.after_request`에서 헤더 설정

### 인증
- 감지: `flask-login`의 `@login_required`, `flask-jwt-extended`

### Rate Limiting
- 라이브러리: `flask-limiter`

### 설정 파일
- `config.py`, `app/config.py`, `.env`

---

## 자동 조치

**수정 전 반드시 확인**: 코어 SKILL.md의 "코드 수정 전 존재 확인 규칙"을 따른다.
- CORS: `os.environ.get("CORS_ORIGINS")` 이미 사용 → 건너뜀
- Rate Limiting: `flask_limiter` 이미 import → 건너뜀
- 인증: 해당 라우트에 `@login_required` 이미 적용 → 건너뜀

### CORS (3-3)
```python
# Before
CORS(app, origins=["http://localhost:3000"])
# After
CORS(app, origins=os.environ.get("CORS_ORIGINS", "http://localhost:3000").split(","))
```

### Insecure Defaults (3-4)
`config.py`에 `_validate_secret` 함수 삽입 (FastAPI 플러그인과 동일 패턴).

### Rate Limiting (3-5)
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(app=app, key_func=get_remote_address, default_limits=["200/hour"])

@app.route("/login", methods=["POST"])
@limiter.limit("5/minute")
def login(): ...
```
`requirements.txt`에 `flask-limiter` 추가.

### 엔드포인트 인증 (3-6)
```python
@app.route("/admin")
@login_required
def admin_panel(): ...
```

---

## 검증
- CORS: localhost 하드코딩 0건
- Rate Limiting: 로그인 라우트에 `@limiter.limit` 존재
- 인증: 민감 라우트에 `@login_required` 존재
