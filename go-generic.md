# Go 플러그인

## 감지 조건
- `go.mod` 존재

## 프레임워크 세부 감지
- `gin-gonic/gin` → Gin
- `gorilla/mux` → Gorilla
- `labstack/echo` → Echo
- `net/http` 직접 사용 → 표준 라이브러리

---

## 스캔 패턴

### CORS
- 감지: `cors.New(cors.Config{AllowOrigins: []string{"http://localhost"}})` 또는 헤더 직접 설정

### 보안 헤더
- 감지: 미들웨어에서 보안 헤더 설정 여부

### 인증
- 감지: JWT 미들웨어 (`jwt-go`, `golang-jwt`), 세션 미들웨어

### 설정 파일
- `.env`, `config.go`, `config.yaml`

---

## 자동 조치

### CORS (3-3)
```go
// Before
AllowOrigins: []string{"http://localhost:3000"}
// After
origins := os.Getenv("CORS_ORIGINS")
if origins == "" { origins = "http://localhost:3000" }
AllowOrigins: strings.Split(origins, ",")
```

### Insecure Defaults (3-4)
config 로드 시 시크릿 값 검증 함수 추가.

### Rate Limiting (3-5)
보고서에 `golang.org/x/time/rate` 또는 프레임워크별 rate limiter 권고.

### 엔드포인트 인증 (3-6)
보고서에 인증 미들웨어 적용 권고 (Go의 다양한 패턴으로 자동 주입 제한적).

---

## 검증
- CORS: 환경변수 기반 origin 설정 존재
- 시크릿: config에서 검증 로직 존재 또는 보고서 권고 기재
