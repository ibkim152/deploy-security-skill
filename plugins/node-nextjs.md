# Next.js 플러그인

## 감지 조건
- `package.json`에 `next` 의존성
- `next.config.js`/`next.config.mjs` 존재

## 라우터 감지 (중요 — 버전 분기)
```
[App Router] app/ 디렉토리 존재 → route.ts, layout.tsx 패턴
[Pages Router] pages/ 디렉토리 존재 → pages/api/*.ts 패턴
[Hybrid] 둘 다 존재 → 양쪽 모두 점검

인증 코드 주입 시 라우터 버전을 따른다.
```

## NextAuth 버전 감지
```
[NextAuth v4] next-auth 패키지 → getServerSession(authOptions)
[Auth.js v5] @auth/nextjs-auth 패키지 → auth() 함수
```

---

## 스캔 패턴

### CORS
- 감지: `next.config.js`의 `headers()` 또는 API route에서 `Access-Control-Allow-Origin` 하드코딩

### 보안 헤더
- 감지: `next.config.js`의 `headers()` 설정 또는 `middleware.ts`

### 인증
- App Router: `auth()` 또는 `getServerSession` 호출 여부
- Pages Router: `getServerSession(authOptions)` 호출 여부

### 설정 파일
- `.env`, `.env.local`, `next.config.js`

---

## 자동 조치

**수정 전 반드시 확인**: 코어 SKILL.md의 "코드 수정 전 존재 확인 규칙"을 따른다.
- CORS: 이미 환경변수 기반 설정 → 건너뜀
- Rate Limiting: 이미 rate limit 로직 존재 → 건너뜀
- 인증: 해당 API route에 `auth()`/`getServerSession` 이미 호출 → 건너뜀
- NextAuth 버전: v4(`getServerSession`) vs v5(`auth()`) 반드시 감지 후 일치하는 패턴 사용

### CORS (3-3)
`next.config.js`에서 하드코딩된 origin을 환경변수로 전환.

### Insecure Defaults (3-4)
Express 플러그인과 동일한 `validateSecret` 함수를 `src/lib/config.ts`에 삽입.

### Rate Limiting (3-5)
```typescript
// src/lib/rate-limit.ts (내장 구현, 추가 패키지 불필요)
const rateLimit = new Map<string, { count: number; resetTime: number }>();

export function rateLimiter(ip: string, limit = 5, window = 60000): boolean {
  const now = Date.now();
  const record = rateLimit.get(ip);
  if (!record || now > record.resetTime) {
    rateLimit.set(ip, { count: 1, resetTime: now + window });
    return true;
  }
  if (record.count >= limit) return false;
  record.count++;
  return true;
}
```
로그인 API route에서 호출.

### 엔드포인트 인증 (3-6)
```typescript
// App Router (Auth.js v5):
import { auth } from "@/auth";
const session = await auth();
if (!session) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

// App Router (NextAuth v4):
import { getServerSession } from "next-auth";
const session = await getServerSession(authOptions);
if (!session) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

// Pages Router:
import { getServerSession } from "next-auth/next";
const session = await getServerSession(req, res, authOptions);
if (!session) return res.status(401).json({ error: "Unauthorized" });
```

### 빌드 시점 환경변수 경고
`NEXT_PUBLIC_*` 변수는 빌드 시 코드에 고정됨 → 배포 가이드에 `--build` 필수 경고 포함.

---

## 검증
- CORS: 하드코딩된 origin 0건
- Rate Limiting: 로그인 API route에 rate limit 로직 존재
- 인증: 민감 API route에 세션 검증 존재, 라우터 버전과 코드 패턴 일치
- 빌드 변수: `NEXT_PUBLIC_*` 사용 파일 목록이 배포 가이드에 포함
