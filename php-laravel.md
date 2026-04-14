# PHP Laravel 플러그인

## 감지 조건
- `composer.json`에 `laravel/framework` 존재
- 소스코드에 `use Illuminate\` 패턴
- `artisan` 파일 존재

## 스캔 패턴

### CORS
- 감지: `config/cors.php`에서 `allowed_origins => ['http://localhost:3000']` 하드코딩
- 또는: `app/Http/Middleware/Cors.php`에서 헤더 직접 설정

### 보안 헤더
- 감지: `app/Http/Middleware/SecurityHeaders.php` 존재 여부
- 또는: `config/secure-headers.php` (bepsvpt/secure-headers 패키지)

### 인증
- 감지: `auth` 미들웨어 적용 여부
- 패턴: `->middleware('auth')`, `Route::middleware(['auth'])`
- 민감 라우트: `/admin`, `/dashboard`, `/export`, `/users`, `/config`

### Rate Limiting
- 감지: `RouteServiceProvider`에서 `RateLimiter::for()` 정의 여부
- 또는: `routes/api.php`에 `throttle` 미들웨어

### 설정 파일
- `.env`, `config/app.php`, `config/database.php`, `config/session.php`

---

## 자동 조치

**수정 전 반드시 확인**: 코어 SKILL.md의 "코드 수정 전 존재 확인 규칙"을 따른다.
- CORS: `env('CORS_ORIGINS')` 이미 사용 → 건너뜀
- Rate Limiting: `RateLimiter::for('login')` 이미 정의 → 건너뜀
- 인증: 해당 라우트에 `->middleware('auth')` 이미 적용 → 건너뜀
- APP_KEY: `php artisan key:generate`로 이미 생성 → 건너뜀

### CORS 환경변수화 (3-3)
```php
// config/cors.php
// Before
'allowed_origins' => ['http://localhost:3000'],

// After
'allowed_origins' => explode(',', env('CORS_ORIGINS', 'http://localhost:3000')),
```
`.env.production.example`에 `CORS_ORIGINS=https://yourdomain.com` 추가.

### Insecure Defaults 검증 (3-4)
`app/Providers/AppServiceProvider.php`의 `boot()`에 검증 삽입:
```php
public function boot(): void
{
    if (app()->environment('production')) {
        $insecure = ['changeme','secret','password','test','default','example',
                     'your-secret-key','replace-me','todo','insecure','12345',''];
        $key = config('app.key');
        if (in_array(strtolower(trim($key)), $insecure) || strlen($key) < 16) {
            throw new \RuntimeException("APP_KEY가 안전하지 않습니다. php artisan key:generate 실행하세요.");
        }
    }
}
```

### Rate Limiting 강화 (3-5)
```php
// app/Providers/RouteServiceProvider.php (또는 bootstrap/app.php Laravel 11+)
RateLimiter::for('login', function (Request $request) {
    return Limit::perMinute(5)->by($request->ip());
});

// routes/web.php 또는 routes/api.php
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
```

### 미인증 엔드포인트 보호 (3-6)
```php
// routes/web.php
Route::middleware(['auth'])->group(function () {
    Route::get('/admin', [AdminController::class, 'index']);
    Route::get('/export', [ExportController::class, 'download']);
    Route::get('/users', [UserController::class, 'list']);
});
```

### Laravel 보안 설정 강화
```php
// config/session.php
'secure' => env('SESSION_SECURE_COOKIE', true),  // HTTPS only
'http_only' => true,
'same_site' => 'lax',

// .env.production.example에 추가
APP_ENV=production
APP_DEBUG=false
SESSION_SECURE_COOKIE=true
```

---

## 검증
- CORS: `config/cors.php`에 localhost 하드코딩 0건, `env('CORS_ORIGINS')` 사용
- Rate Limiting: 로그인 라우트에 `throttle` 미들웨어 존재
- 인증: 민감 라우트에 `auth` 미들웨어 존재
- 보안 설정: `APP_DEBUG=false`, `SESSION_SECURE_COOKIE=true`
- APP_KEY: `php artisan key:generate`로 생성된 안전한 키 사용
