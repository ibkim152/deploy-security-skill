# Rust 플러그인

## 감지 조건
- `Cargo.toml` 존재

## 프레임워크 세부 감지
- `actix-web` → Actix
- `axum` → Axum
- `rocket` → Rocket
- `warp` → Warp

---

## 스캔 패턴

### CORS
- 감지: `Cors::default()` 또는 `.allowed_origin("http://localhost")`

### 보안 헤더
- 감지: 미들웨어/guard에서 보안 헤더 설정 여부

### 인증
- 감지: JWT 크레이트 (`jsonwebtoken`), 세션 크레이트

### 설정 파일
- `.env`, `config.toml`, `Config.rs`

---

## 자동 조치

Rust의 강타입 시스템과 다양한 웹 프레임워크로 인해 **자동 코드 주입이 제한적**:
- CORS: 보고서에 환경변수 기반 전환 코드 예시 제공
- Rate Limiting: 보고서에 `actix-governor` 또는 `tower::limit` 권고
- 인증: 보고서에 미들웨어 적용 권고

**자동 조치 가능 항목**:
- `.gitignore`, `.dockerignore` 생성 (3-1)
- `.env.production.example` 생성 (3-1)
- 시크릿 키 검증 (3-2, .env 파일 대상)
- DB 백업 스크립트 (3-7)

---

## 검증
- 보고서에 프레임워크별 보안 설정 권고 기재 확인
- .gitignore에 `target/`, `.env` 포함
