# 배포 가이드 생성 템플릿

## 생성 전략
Word(.docx) 우선, python-docx 불가 시 Markdown fallback. report-template.md와 동일한 스타일 적용.

**작성 원칙**: 서버를 처음 만져보는 사람도 따라할 수 있도록, 모든 단계에 "왜 하는지"와 "정확히 뭘 입력하는지"를 명시한다. 용어는 첫 등장 시 반드시 풀어 설명한다.

---

## Step 0: 서버 권장 스펙

프로젝트 규모와 기술스택에 따라 최소/권장 스펙을 제시한다. Phase 0에서 감지된 정보를 기반으로 자동 산정.

### 스펙 산정 기준표

| 프로젝트 유형 | CPU | RAM | 디스크 | 예시 인스턴스 |
|-------------|-----|-----|--------|-------------|
| **소규모** (프론트 또는 백엔드 단독, SQLite) | 1코어 | 1GB | 20GB SSD | AWS t3.micro, OCI VM.Standard.A1.Flex(1/1) |
| **일반** (프론트+백엔드+DB, Docker Compose) | 2코어 | 4GB | 40GB SSD | AWS t3.medium, OCI VM.Standard.A1.Flex(2/4) |
| **중규모** (프론트+백엔드+DB+Redis+nginx) | 2코어 | 8GB | 60GB SSD | AWS t3.large, OCI VM.Standard.A1.Flex(2/8) |
| **대규모** (마이크로서비스, 다중 컨테이너) | 4코어+ | 16GB+ | 100GB+ SSD | AWS t3.xlarge, OCI VM.Standard.A1.Flex(4/16) |

### 자동 산정 로직
```
서비스 수 = docker-compose.yml의 services 개수 (없으면 1)
DB 사용 = PostgreSQL/MySQL 감지 시 +1GB RAM, +20GB 디스크
Redis 사용 = Redis 감지 시 +512MB RAM
프론트엔드 빌드 = Next.js/React 감지 시 빌드 중 +2GB RAM 필요 (빌드 후 반환)

최종 권장:
- RAM = 기본 1GB + (서비스당 512MB) + DB + Redis + 빌드 여유
- CPU = 서비스 수 ÷ 2 (최소 1코어)
- 디스크 = 기본 20GB + (Docker 이미지당 5GB) + DB 여유분
```

### 무료/저비용 옵션 안내
```
무료로 시작할 수 있는 클라우드:
- OCI (Oracle Cloud): 평생 무료 서버 제공 (ARM 4코어/24GB까지)
  → 소규모~중규모 프로젝트에 충분
- AWS Free Tier: 12개월 t2.micro 무료 (1코어/1GB)
  → 소규모 테스트용
- GCP Free Tier: e2-micro 무료 (0.25코어/1GB)
  → 소규모 테스트용

추천: 처음이면 OCI Always Free가 가장 넉넉합니다.
```

---

## Step 1: 서버 만들기

```
이 단계에서 하는 일:
클라우드(인터넷에 있는 컴퓨터 대여 서비스)에서 서버를 하나 만듭니다.
서버 = 24시간 켜져있는 컴퓨터. 여기에 코드를 올려서 다른 사람이 접속할 수 있게 합니다.

□ 1-1. 클라우드 서비스 가입
   - AWS: aws.amazon.com → 계정 생성 (신용카드 필요)
   - OCI: cloud.oracle.com → 계정 생성 (무료 서버 제공)
   - GCP: cloud.google.com → 계정 생성

□ 1-2. 서버(인스턴스) 생성
   - OS: Ubuntu 22.04 LTS 선택 (가장 보편적, 자료가 많음)
   - 스펙: Step 0에서 산정된 권장 사양
   - SSH 키: 생성 시 .pem 또는 .key 파일 다운로드 (로그인에 필요, 절대 잃어버리지 마세요)

□ 1-3. 보안그룹(방화벽) 설정
   "어떤 포트를 외부에서 접속 가능하게 할 것인가"를 정합니다.

   반드시 열어야 하는 포트:
   - 22 (SSH): 서버에 원격 접속하기 위한 포트
   - 80 (HTTP): 웹사이트 접속 포트
   - 443 (HTTPS): 보안 웹사이트 접속 포트 (도메인 있을 때)

   열면 안 되는 포트 (보안 위험):
   - 5432 (PostgreSQL), 3306 (MySQL), 27017 (MongoDB)
     → DB는 서버 안에서만 접근해야 합니다
   - 3000, 8000 (앱 포트)
     → nginx가 대신 처리하므로 직접 열 필요 없음

□ 1-4. 서버 IP 확인
   생성된 서버의 공인 IP 주소를 메모합니다.
   예: 152.67.xxx.xxx
   → 이 IP가 앞으로 모든 설정에서 "서버주소"가 됩니다.
```

---

## Step 2: 서버에 접속하고 기본 설정하기

```
이 단계에서 하는 일:
만든 서버에 접속해서, 코드를 실행할 준비를 합니다.

□ 2-1. 서버 접속 (SSH)
   터미널(Mac) 또는 PowerShell(Windows)에서:

   ssh -i ~/Downloads/내키파일.pem ubuntu@서버IP주소

   예: ssh -i ~/Downloads/my-key.pem ubuntu@152.67.100.50

   "Are you sure?" 물으면 → yes 입력

□ 2-2. 시스템 업데이트
   (서버에 접속한 상태에서)

   sudo apt update && sudo apt upgrade -y

   → "sudo"는 관리자 권한으로 실행한다는 뜻입니다
   → 5~10분 걸릴 수 있습니다

□ 2-3. Docker 설치
   Docker = 앱을 "컨테이너"라는 상자에 담아서 실행하는 도구.
   어떤 서버에서든 동일하게 작동하게 해줍니다.

   # Docker 설치 (공식 방법)
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker $USER

   # Docker Compose 확인
   docker compose version

   → "permission denied" 에러가 나면:
     exit 입력 후 다시 ssh로 접속하세요 (그룹 설정 반영)

□ 2-4. Git 설치 확인
   git --version
   → 이미 설치되어 있을 겁니다. 없으면: sudo apt install git -y
```

---

## Step 3: 코드 가져오기 + 환경 설정

```
이 단계에서 하는 일:
내 컴퓨터의 코드를 서버로 복사하고, 서버용 설정을 합니다.

□ 3-1. 코드 다운로드
   git clone https://github.com/내계정/내프로젝트.git
   cd 내프로젝트

   → GitHub에 올리지 않은 경우: scp로 직접 복사
     scp -i 키파일.pem -r ./내프로젝트 ubuntu@서버IP:~/

□ 3-2. 환경변수 파일 생성
   .env.production.example 파일을 .env로 복사합니다.

   cp .env.production.example .env

   → .env 파일 = 비밀번호, API 키 등 민감한 설정을 모아놓은 파일
   → 이 파일은 절대 GitHub에 올리면 안 됩니다

□ 3-3. .env 파일 편집
   nano .env    (← 서버에서 파일 편집하는 명령어)

   수정해야 하는 항목들:

   [서버 주소 관련] — "localhost"를 서버 IP로 변경
   FRONTEND_URL=http://서버IP주소
   BACKEND_URL=http://서버IP주소:8000
   NEXTAUTH_URL=http://서버IP주소
   (프로젝트에서 감지된 URL 변수를 모두 나열)

   [시크릿 키 생성] — 각 키에 강력한 랜덤 값 입력
   다른 터미널을 열어서 아래 명령어로 생성:
   openssl rand -hex 32

   생성된 값을 복사해서 .env에 붙여넣기:
   SECRET_KEY=생성된값
   JWT_SECRET_KEY=생성된값 (다른 값으로!)

   nano 저장: Ctrl+O → Enter → Ctrl+X
```

---

## Step 4: 외부 서비스 설정 (감지된 것만 표시)

```
이 단계에서 하는 일:
Google 로그인, Slack 연동 등 외부 서비스를 사용하는 경우,
해당 서비스에 "서버 주소가 바뀌었어요"라고 알려줘야 합니다.

왜 필요한가:
외부 서비스는 "이 주소에서 오는 요청만 허용할게"라는 설정이 있습니다.
localhost에서 서버IP로 바뀌었으니, 새 주소를 등록해야 합니다.
```

### 외부 서비스 감지 패턴

감지된 서비스만 가이드에 포함. 미감지 서비스는 제외.

| 패턴 | 서비스 | 설정 URL |
|------|--------|---------|
| `google_oauth`, `GOOGLE_CLIENT` | Google OAuth | console.cloud.google.com/apis/credentials |
| `kakao`, `KAKAO_` | Kakao 로그인 | developers.kakao.com |
| `naver`, `NAVER_` | Naver 로그인 | developers.naver.com |
| `github`, `GITHUB_CLIENT` | GitHub OAuth | github.com/settings/developers |
| `NEXTAUTH`, `next-auth` | NextAuth.js | (프로젝트 설정) |
| `stripe`, `STRIPE_` | Stripe 결제 | dashboard.stripe.com |
| `slack`, `SLACK_BOT` | Slack Bot | api.slack.com/apps |
| `openai`, `OPENAI_API_KEY` | OpenAI API | platform.openai.com/api-keys |
| `anthropic`, `ANTHROPIC_API_KEY` | Claude API | console.anthropic.com |

### 서비스별 상세 안내 (감지된 것만 생성)

```
[Google OAuth 감지 시]
□ 4-A. Google Cloud Console 접속
  1. console.cloud.google.com/apis/credentials 열기
  2. 사용 중인 OAuth 2.0 클라이언트 ID 클릭
  3. "승인된 리디렉션 URI"에 추가:
     http://서버IP/api/auth/callback/google
     (코드에서 감지된 실제 callback 경로를 표시)
  4. "승인된 JavaScript 원본"에 추가:
     http://서버IP
  5. 저장

[Slack Bot 감지 시]
□ 4-B. Slack App 설정
  1. api.slack.com/apps → 해당 앱 선택
  2. "OAuth & Permissions" → "Redirect URLs"에 추가:
     http://서버IP/profile/slack-callback
     (코드에서 감지된 실제 경로를 표시)
  3. Bot Token은 기존 것 그대로 사용 (서버 IP 변경과 무관)
  → 주의: Slack Redirect URL은 HTTPS만 허용합니다.
    자체 서명 인증서(cert.pem)로 HTTPS 설정이 필요합니다.
```

---

## Step 5: 빌드 + 실행

```
이 단계에서 하는 일:
코드를 실행 가능한 상태로 만들고(빌드), 서버를 켭니다.
```

### 빌드 시점 환경변수 경고 (중요)

| 프레임워크 | 빌드 시 고정 접두사 | 의미 |
|-----------|-------------------|------|
| Next.js | `NEXT_PUBLIC_` | 빌드할 때 코드에 박힘, 나중에 .env만 바꿔도 안 바뀜 |
| React CRA | `REACT_APP_` | 동일 |
| Vite | `VITE_` | 동일 |
| Vue CLI | `VUE_APP_` | 동일 |
| Nuxt | `NUXT_PUBLIC_` | 동일 |

```
주의: 위 접두사가 붙은 환경변수는 .env를 수정한 후
반드시 --build 옵션으로 다시 빌드해야 합니다!

.env만 바꾸고 재시작하면 → 이전 값이 그대로 남아있음 (매우 흔한 실수)
```

### 실행 명령어 (인프라 타겟별)

```
[Docker Compose 감지 시]
□ 5-1. 빌드 + 실행
  docker compose -f docker-compose.prod.yml up -d --build

  → -f: 프로덕션 설정 파일 사용
  → -d: 백그라운드 실행 (터미널 닫아도 계속 돌아감)
  → --build: 코드를 새로 빌드

  처음 실행 시 5~15분 걸릴 수 있습니다 (이미지 다운로드 + 빌드).

□ 5-2. 실행 확인
  docker compose -f docker-compose.prod.yml ps

  → 모든 서비스가 "Up" 상태여야 합니다
  → "Exit" 또는 "Restarting"이면 → Step 7(문제 해결)로

□ 5-3. 브라우저에서 접속
  http://서버IP 입력
  → 페이지가 보이면 성공!
  → 안 보이면 → Step 7(문제 해결)로
```

---

## Step 6: 동작 확인 체크리스트

```
이 단계에서 하는 일:
서버에서 모든 기능이 정상 작동하는지 하나씩 확인합니다.

□ 6-1. 메인 페이지 접속: http://서버IP
□ 6-2. 회원가입/로그인 테스트
□ 6-3. 소셜 로그인 테스트 (Google/Kakao/Naver 등 — 감지된 것만)
□ 6-4. 주요 기능 동작 확인 (프로젝트에 따라 다름)
□ 6-5. 로그 확인 (에러가 없는지):
  docker compose -f docker-compose.prod.yml logs --tail 50

  특정 서비스만 보기:
  docker compose -f docker-compose.prod.yml logs backend --tail 50
  docker compose -f docker-compose.prod.yml logs frontend --tail 50

모두 확인되면 배포 완료!
```

---

## Step 7: 문제가 생겼을 때 (트러블슈팅)

### 가장 먼저: "연결할 수 없음" 진단 순서

```
브라우저에서 "연결할 수 없음" 뜰 때, 이 순서로 확인:

1. 앱이 실행 중인가?
   → systemctl status 서비스명 / docker compose ps

2. 앱 포트가 열려있는가?
   → ss -tlnp | grep 포트번호

3. nginx가 실행 중인가? (리버스 프록시 사용 시)
   → systemctl status nginx
   → curl http://localhost (서버 안에서 테스트)

4. OS 방화벽이 열려있는가?
   → [Ubuntu] sudo ufw status
   → [Oracle Linux/RHEL] sudo firewall-cmd --list-all
   → http가 services 목록에 있는지 확인!

5. 클라우드 보안 규칙이 열려있는가? (가장 많이 놓치는 부분!)
   → [OCI] Security List → Ingress Rules → 포트 80 TCP
   → [AWS] Security Group → Inbound Rules → 포트 80
   → [NCP] ACG → Inbound Rules → 포트 80
   → 소스 IP가 맞는지 확인 (0.0.0.0/0 또는 내 IP)

6. SELinux가 차단하는가? (Oracle Linux/RHEL 전용)
   → getenforce → "Enforcing"이면:
   → sudo setsebool -P httpd_can_network_connect 1

위 순서대로 하면 99%의 "연결할 수 없음" 문제를 찾을 수 있습니다.
```

```
[페이지가 안 열려요]
1. 서버가 돌고 있는지 확인:
   docker compose -f docker-compose.prod.yml ps
2. 보안그룹에서 80포트가 열려있는지 확인
3. 서버 IP가 맞는지 확인

[502 Bad Gateway 에러]
→ 백엔드가 아직 시작 안 된 것. 1~2분 기다린 후 새로고침.
→ 계속되면: docker compose logs nginx --tail 20

[로그인이 안 돼요]
1. .env에 서버 IP가 정확히 입력되었는지 확인
2. 외부 서비스(Google 등)에 서버 IP가 등록되었는지 확인 (Step 4)
3. 브라우저 개발자 도구(F12) → 콘솔 탭에서 에러 메시지 확인

[.env 수정 후 반영이 안 돼요]
→ 반드시 --build로 재빌드:
  docker compose -f docker-compose.prod.yml up -d --build

[디스크 용량 부족]
→ 오래된 Docker 이미지 정리:
  docker system prune -a --volumes
  (주의: 사용 중이 아닌 모든 이미지/볼륨 삭제)

[서버 재시작 후 앱이 안 켜져요]
→ Docker가 자동 시작되도록 설정:
  sudo systemctl enable docker
→ 앱 재시작:
  cd 프로젝트폴더 && docker compose -f docker-compose.prod.yml up -d
```

---

## Step 8: 유지 관리

```
[코드 업데이트 방법]
서버에 접속 후:
  cd 프로젝트폴더
  git pull                    # 최신 코드 가져오기
  docker compose -f docker-compose.prod.yml up -d --build   # 재빌드

[DB 백업 (scripts/backup-db.sh가 생성된 경우)]
  bash scripts/backup-db.sh

  자동 백업 설정 (매일 새벽 3시):
  crontab -e
  아래 한 줄 추가:
  0 3 * * * cd /home/ubuntu/프로젝트폴더 && bash scripts/backup-db.sh

[로그 확인]
  docker compose -f docker-compose.prod.yml logs --tail 100
  docker compose -f docker-compose.prod.yml logs --tail 100 --follow  (실시간)

[서버 모니터링]
  htop     (CPU/RAM 사용량 — 없으면: sudo apt install htop)
  df -h    (디스크 사용량)
```

---

## 수동 조치 가이드 (자동화 불가)

| 항목 | 왜 자동화 불가? | 어떻게 하나요? |
|------|---------------|--------------|
| 외부 API 키 입력 | 각 서비스 사이트에서 직접 발급받아야 함 | Step 4의 서비스별 안내 참조 |
| 서버 IP 입력 | 서버를 만들어야 IP를 알 수 있음 | Step 3-3에서 .env에 입력 |
| 방화벽 규칙 | 클라우드 콘솔에서 직접 설정 | Step 1-3 참조 |
| SSL 인증서 | 도메인이 있어야 발급 가능 | nginx/certbot-init.sh 실행 |
| DNS 설정 | 도메인 구매 사이트에서 설정 | A 레코드에 서버 IP 입력 |
