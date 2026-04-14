# Express 플러그인

## 감지 조건
- `package.json`에 `express` 의존성
- 소스코드에 `require("express")` 또는 `import express from "express"`

## 모듈 시스템 감지 (중요 — 버전 분기)
```
[CommonJS] package.json에 "type": "module" 없음 → require/module.exports 사용
[ESM] package.json에 "type": "module" 있음 → import/export 사용
[TypeScript] tsconfig.json 존재 → import/export 사용

코드 주입 시 프로젝트의 모듈 시스템을 따른다.
```

## 스캔 패턴

### CORS
- 감지: `cors({ origin: "http://localhost:3000" })`

### 보안 헤더
- 감지: `helmet` 미들웨어 사용 여부

### 인증
- 감지: `authMiddleware`, `passport`, `express-session`, `jsonwebtoken`

### Rate Limiting
- 라이브러리: `express-rate-limit`

### 설정 파일
- `.env`, `.env.local`, `config.js`/`config.ts`

---

## 자동 조치

**수정 전 반드시 확인**: 코어 SKILL.md의 "코드 수정 전 존재 확인 규칙"을 따른다.
- CORS: `process.env.CORS_ORIGINS` 이미 사용 → 건너뜀
- Rate Limiting: `express-rate-limit` 이미 import → 건너뜀
- 인증: 해당 라우트에 `authMiddleware` 이미 적용 → 건너뜀
- import: `require` vs `import` — 프로젝트 모듈 시스템에 맞춰 선택

### CORS (3-3)
```javascript
// CommonJS:
const allowedOrigins = process.env.CORS_ORIGINS?.split(",") || ["http://localhost:3000"];
app.use(cors({ origin: allowedOrigins }));

// ESM:
const allowedOrigins = process.env.CORS_ORIGINS?.split(",") ?? ["http://localhost:3000"];
app.use(cors({ origin: allowedOrigins }));
```

### Insecure Defaults (3-4)
```javascript
const INSECURE_DEFAULTS = new Set([
  "changeme", "secret", "password", "test", "default", "example",
  "your-secret-key", "your-jwt-secret", "replace-me", "todo",
  "insecure", "development", "debug", "admin", "12345", "",
]);

function validateSecret(name, value) {
  if (INSECURE_DEFAULTS.has(value?.toLowerCase().trim()) || (value?.length ?? 0) < 16) {
    throw new Error(`환경변수 ${name}이(가) 안전하지 않습니다.`);
  }
  return value;
}
```

### Rate Limiting (3-5)
```javascript
// CommonJS:
const rateLimit = require("express-rate-limit");
// ESM:
import rateLimit from "express-rate-limit";

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  message: { error: "Too many login attempts. Try again later." },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use("/api/auth/login", loginLimiter);
```
- `package.json`에 `express-rate-limit` 추가
- Redis 감지 시: `rate-limit-redis` store 사용

### 엔드포인트 인증 (3-6)
```javascript
router.get("/scan-all", authMiddleware, scanAllHandler);
```

---

## 검증
- CORS: `process.env.CORS_ORIGINS` 기반 동적 설정 존재
- Rate Limiting: 로그인 라우트에 limiter 미들웨어 존재
- 보안 헤더: `helmet` 미들웨어 존재
- 모듈 시스템: 주입된 코드가 프로젝트의 CJS/ESM과 일치
