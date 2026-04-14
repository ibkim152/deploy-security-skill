# Streamlit 플러그인

## 감지 조건
- `requirements.txt`/`pyproject.toml`에 `streamlit` 존재
- 소스코드에 `import streamlit` 또는 `import streamlit as st`
- **최우선 감지**: starlette/tornado 감지만으로 FastAPI로 판정하면 안 됨

## 중요: Streamlit은 일반 웹 프레임워크가 아님
- 라우트 핸들러 없음 (FastAPI/Django/Flask 코드 주입 차단)
- CORS는 Streamlit 내장 관리
- Rate Limiting은 ASGI 미들웨어 불가
- 인증은 session_state 기반

**따라서 3-3(CORS), 3-5(Rate Limiting), 3-6(엔드포인트 인증)의 일반 코드를 삽입하지 않는다.**

---

## 추가 스캔 영역 (영역 8)

### 8-1. 인증 우회 점검
```
감지: auth 함수에서 조건부 bypass 패턴
- if not password: return True → 빈 비밀번호 시 인증 비활성화
- os.environ.get("...", "") → 빈 문자열 기본값

판정 (오탐 방지):
- 주석에 "로컬 개발용", "dev", "local" 포함 → 의도적 bypass (경고, 수정 안 함)
- 주석 없이 bypass → 상
- 프로덕션에서 bypass 가능 → 긴급
```

### 8-2. session_state PII 노출
- `session_state["token"]`, `session_state["access_token"]`, `session_state["password"]` → 상
- `session_state["user_id"]`, `session_state["email"]` → 중
- 이미 암호화된 값 → 정상

### 8-3. cache_data/cache_resource PII 누출
- `@st.cache_data`, `@st.cache_resource`가 PII 반환하는지 확인
- 사용자별 PII 캐시 → 상, 공통 데이터만 → 정상

### 8-4. Streamlit 서버 설정
- `.streamlit/config.toml` 존재 여부
- `enableXsrfProtection = false` → 상
- `server.enableCORS = false` → 중 (확인 필요)
- `browser.gatherUsageStats = true` → 하

### 8-5. TLS
- `--server.sslCertFile` 사용 여부, cert.pem/key.pem 존재
- TLS 미설정 → 상
- cert/key가 .gitignore에 없음 → 긴급

### 8-6. 암호화 인식
- cryptography/Fernet/bcrypt 사용 감지 → PII 판정 시 교차 확인
- Fernet 키 유도: PBKDF2/scrypt → 정상, 단순 SHA256 → 중, 하드코딩 → 상

---

## 자동 조치 (Streamlit 전용)

### 인증 강화 (3-8-1)
- **코드 자동 수정 안 함** (개발 bypass는 의도적)
- `.env.production.example`에 `DASHBOARD_PASSWORD` 필수 기재
- 보고서에 "프로덕션 배포 시 반드시 값 설정" 경고

### 서버 보안 설정 (3-8-2)
`.streamlit/config.toml` 생성 또는 보완:
```toml
[server]
enableCORS = true
enableXsrfProtection = true
headless = true
maxUploadSize = 10000

[browser]
gatherUsageStats = false
```

> **중요**: `maxUploadSize`는 Streamlit 자체 업로드 제한 (MB 단위).
> nginx의 `client_max_body_size`와 **별개**이므로 양쪽 모두 설정해야 한다.
> 기본값 200MB로 부족하면 `10000` (약 10GB) 등으로 설정.

### SQLite 파일 보호 (3-8-3)
- `.gitignore`에 `*.db` 추가
- 보고서에 WAL 모드 안전 백업 권고

### 암호화 키 관리 (3-8-4)
- `.env.production.example`에 키 생성 명령어 포함
- 기존 키 자동 교체 안 함 (암호화된 데이터 복호화 불가 위험)

### cert/key 보호 (3-8-5)
- `.gitignore`에 `*.pem`, `*.key` 추가

### 데이터 디렉토리 사전 생성 (3-8-6)

Streamlit 앱이 파일 업로드 기능을 갖고 있으면, 저장 대상 디렉토리가 서버에 존재해야 한다.
배포 가이드에 다음을 포함:

```bash
# 앱이 사용하는 데이터 디렉토리 사전 생성
# (app.py에서 감지된 경로를 기반으로 자동 생성)
sudo mkdir -p "/서비스경로/데이터폴더"
sudo chmod -R 777 "/서비스경로/데이터폴더"
```

> **왜 필요한가**: Git에 데이터 폴더를 포함하지 않는 경우 (용량, 민감 데이터),
> clone 후 서버에 해당 폴더가 없어 앱이 파일을 저장/읽기할 수 없다.
> 앱은 켜지지만 **데이터 없는 빈 화면**이 표시된다.

감지 방법: 앱 코드에서 `mkdir`, `Path(...).mkdir`, `os.makedirs`, `open(..., "wb")` 등을 검색하여
파일 쓰기가 발생하는 경로를 식별한다.

---

## 검증
- `.streamlit/config.toml`에 `enableXsrfProtection = true`
- `.streamlit/config.toml`에 `maxUploadSize` 설정 (기본 200MB 이상)
- `.gitignore`에 `*.db`, `*.pem`, `*.key` 포함
- `.env.production.example`에 `DASHBOARD_PASSWORD` 포함
- 데이터 디렉토리가 배포 가이드에 사전 생성 안내 포함
- FastAPI/Django 코드(Depends, @login_required, slowapi)가 삽입되지 않았는지 확인
