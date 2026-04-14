# Spring 플러그인

## 감지 조건
- `pom.xml`에 `spring-boot-starter` 또는 `build.gradle`에 `org.springframework.boot`

## 버전 감지
```
[Spring Security 5.x+] SecurityFilterChain @Bean 패턴
[구버전] WebSecurityConfigurerAdapter 상속 패턴
코드 주입 시 프로젝트의 버전 패턴을 따른다.
```

---

## 스캔 패턴

### CORS
- 감지: `@CrossOrigin(origins = "http://localhost:3000")` 또는 `CorsConfiguration`
- 파일: *Controller.java, SecurityConfig.java, WebMvcConfig.java

### 보안 헤더
- 감지: `Spring Security` 의존성 및 `HttpSecurity` 설정

### 인증
- 감지: `@PreAuthorize`, `@Secured`, `httpSecurity.authorizeRequests()`

### Rate Limiting
- 라이브러리: `bucket4j`, `resilience4j`, Spring 필터

### 설정 파일
- `application.yml`, `application.properties`, `application-prod.yml`

---

## 자동 조치

**수정 전 반드시 확인**: 코어 SKILL.md의 "코드 수정 전 존재 확인 규칙"을 따른다.
- CORS: 환경변수 기반 설정 이미 존재 → 건너뜀
- 인증: SecurityFilterChain에 해당 경로 보호 이미 존재 → 건너뜀
- 보안 설정: `application-prod.yml` 이미 존재 → 누락 항목만 추가

### CORS (3-3)
```java
// application.yml에 추가:
cors:
  allowed-origins: ${CORS_ORIGINS:http://localhost:3000}
```
`@CrossOrigin` 하드코딩을 환경변수 기반으로 전환.

### Insecure Defaults (3-4)
`application.yml`의 시크릿 키에 검증 로직 추가 (커스텀 `@ConfigurationProperties` validator).

### Rate Limiting (3-5)
보고서에 `bucket4j-spring-boot-starter` 또는 `resilience4j` 도입 권고. 자동 코드 주입은 Spring의 다양한 설정 패턴으로 인해 **보고서 권고만** 수행.

### 엔드포인트 인증 (3-6)
```java
// SecurityFilterChain 패턴:
http.authorizeHttpRequests(auth -> auth
    .requestMatchers("/admin/**").hasRole("ADMIN")
    .requestMatchers("/api/public/**").permitAll()
    .anyRequest().authenticated()
);
```

### Spring 보안 설정
```yaml
# application-prod.yml
server:
  ssl:
    enabled: true
  servlet:
    session:
      cookie:
        secure: true
        http-only: true
```

---

## 검증
- CORS: `@CrossOrigin`에 localhost 하드코딩 0건
- 보안 설정: `application-prod.yml`에 SSL/세션 보안 설정 존재
- 인증: SecurityFilterChain에 민감 경로 보호 규칙 존재
