# deploy.sh 자동 생성 템플릿

## 개요

`/deploy-security` Phase 3에서 프로젝트 분석 결과를 기반으로
`scripts/deploy.sh`를 자동 생성한다. 사용자는 서버에서 이 스크립트 하나만 실행하면 된다.

## 생성 규칙

### 입력 변수 (Phase 0 감지 결과에서 수집)

| 변수 | 감지 방법 | 예시 |
|------|----------|------|
| `APP_NAME` | 프로젝트 디렉토리명 또는 package.json name | `csap-manager` |
| `FRAMEWORK` | Phase 0-1 기술스택 감지 | `streamlit`, `fastapi`, `nextjs` |
| `APP_ENTRY` | 메인 파일 경로 | `app.py`, `main.py`, `src/index.ts` |
| `APP_DIR` | 앱 코드가 있는 하위 디렉토리 (없으면 `.`) | `csap_manager`, `backend`, `.` |
| `APP_PORT` | 프레임워크 기본 포트 또는 설정에서 감지 | `8501`, `8000`, `3000` |
| `PYTHON_DEPS` | requirements.txt 경로 | `requirements.txt` |
| `NODE_DEPS` | package.json 경로 | `package.json` |
| `DATA_DIRS` | Git에 미포함된 데이터 디렉토리 (코드 분석) | `정책 및 절차서/증적` |
| `ENV_TEMPLATE` | .env 템플릿 파일 경로 | `.env.production.example` |
| `STREAMLIT_CONFIG` | .streamlit/config.toml 존재 여부 | `true/false` |

### 스크립트 구조

```bash
#!/bin/bash
set -euo pipefail

# ============================================================
# {APP_NAME} 배포 스크립트
# 생성: /deploy-security (자동 생성됨 — 수동 수정 가능)
# ============================================================

# ── 설정 (프로젝트별 자동 생성) ──
APP_NAME="{APP_NAME}"
APP_DIR="{APP_DIR}"
APP_ENTRY="{APP_ENTRY}"
APP_PORT="{APP_PORT}"
FRAMEWORK="{FRAMEWORK}"
INSTALL_DIR="/opt/$APP_NAME"

# ── 색상 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── 1. OS 감지 ──
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
    else
        error "지원하지 않는 OS입니다."
    fi

    case "$OS_ID" in
        ubuntu|debian)
            PKG="apt"
            PKG_UPDATE="sudo apt update -y"
            PKG_INSTALL="sudo apt install -y"
            ;;
        ol|centos|rhel|rocky|almalinux)
            PKG="dnf"
            PKG_UPDATE="sudo dnf update -y"
            PKG_INSTALL="sudo dnf install -y"
            ;;
        amzn)
            PKG="dnf"
            PKG_UPDATE="sudo dnf update -y"
            PKG_INSTALL="sudo dnf install -y"
            ;;
        *)
            error "지원하지 않는 OS: $OS_ID"
            ;;
    esac

    info "OS 감지: $PRETTY_NAME (패키지 매니저: $PKG)"
}

# ── 2. 시스템 패키지 설치 ──
install_packages() {
    info "시스템 업데이트 중..."
    $PKG_UPDATE > /dev/null 2>&1

    # Python (프레임워크별 분기)
    {PYTHON_INSTALL_BLOCK}

    # nginx
    $PKG_INSTALL nginx > /dev/null 2>&1 || true
    info "nginx 설치 완료"
}

# ── 3. 방화벽 + SELinux ──
configure_firewall() {
    # OS 방화벽
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-service=http 2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        info "firewalld: http/https 허용"
    elif command -v ufw &> /dev/null; then
        sudo ufw allow 80/tcp 2>/dev/null || true
        sudo ufw allow 443/tcp 2>/dev/null || true
        info "ufw: 80/443 허용"
    fi

    # SELinux (RHEL 계열)
    if command -v getenforce &> /dev/null; then
        if [ "$(getenforce)" = "Enforcing" ]; then
            sudo setsebool -P httpd_can_network_connect 1 2>/dev/null || true
            info "SELinux: nginx 프록시 허용"
        fi
    fi
}

# ── 4. 앱 설정 ──
setup_app() {
    cd "$INSTALL_DIR"

    {SETUP_BLOCK}

    # 환경변수
    if [ -f "$APP_DIR/{ENV_TEMPLATE}" ] && [ ! -f "$APP_DIR/.env" ]; then
        cp "$APP_DIR/{ENV_TEMPLATE}" "$APP_DIR/.env"
        info ".env 파일 생성 (템플릿에서 복사)"
        warn ".env 파일을 편집하여 API 키 등을 입력하세요: nano $INSTALL_DIR/$APP_DIR/.env"
    fi

    # 데이터 디렉토리 생성
    {DATA_DIR_BLOCK}
}

# ── 5. systemd 서비스 등록 ──
create_service() {
    cat << SERVICEEOF | sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null
[Unit]
Description=$APP_NAME
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR/$APP_DIR
{EXEC_START_LINE}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

    sudo systemctl daemon-reload
    sudo systemctl enable $APP_NAME
    info "systemd 서비스 등록: $APP_NAME"
}

# ── 6. nginx 리버스 프록시 ──
create_nginx() {
    {NGINX_BLOCK}

    # 기존 default 비활성화
    sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

    sudo nginx -t 2>/dev/null && info "nginx 설정 검증 통과" || error "nginx 설정 오류"
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    info "nginx 시작 완료"
}

# ── 7. 서비스 시작 + 확인 ──
start_and_verify() {
    sudo systemctl start $APP_NAME
    sleep 3

    if sudo systemctl is-active --quiet $APP_NAME; then
        info "서비스 시작 성공"
    else
        error "서비스 시작 실패. 로그 확인: sudo journalctl -u $APP_NAME -n 30"
    fi

    # 내부 접속 테스트
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        info "내부 접속 테스트 통과 (HTTP 200)"
    else
        warn "내부 접속 테스트: HTTP $HTTP_CODE — nginx 또는 앱 로그를 확인하세요"
    fi
}

# ── 실행 ──
echo "============================================================"
echo "  $APP_NAME 배포 스크립트"
echo "============================================================"
echo ""

detect_os
install_packages
configure_firewall
setup_app
create_service
create_nginx
start_and_verify

echo ""
echo "============================================================"
info "배포 완료!"
echo ""
echo "  서버 IP 확인:  curl -s ifconfig.me"
echo "  접속 주소:     http://\$(curl -s ifconfig.me)"
echo ""
warn "클라우드 보안 규칙에서 포트 80을 열어야 외부 접속 가능합니다!"
warn "  OCI: Security List → Ingress Rules → TCP 80"
warn "  AWS: Security Group → Inbound Rules → TCP 80"
echo ""
{POST_DEPLOY_MESSAGES}
echo "============================================================"
```

---

## 프레임워크별 블록 생성 규칙

### Python (Streamlit / FastAPI / Flask / Django)

**PYTHON_INSTALL_BLOCK**:
```bash
    # Python
    if command -v python3 &> /dev/null; then
        PY_VERSION=$(python3 --version | awk '{print $2}')
        info "Python $PY_VERSION 감지"
    else
        $PKG_INSTALL python3 python3-pip python3-devel > /dev/null 2>&1
        info "Python 설치 완료"
    fi
```

**SETUP_BLOCK** (Python):
```bash
    # 가상환경
    cd "$APP_DIR"
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        info "가상환경 생성"
    fi
    venv/bin/pip install --upgrade pip -q
    venv/bin/pip install -r {PYTHON_DEPS} -q
    info "의존성 설치 완료"
```

**EXEC_START_LINE**:
- Streamlit: `ExecStart=$INSTALL_DIR/$APP_DIR/venv/bin/streamlit run {APP_ENTRY} --server.headless true --server.port {APP_PORT} --server.address 127.0.0.1`
- FastAPI: `ExecStart=$INSTALL_DIR/$APP_DIR/venv/bin/uvicorn {MODULE}:app --host 127.0.0.1 --port {APP_PORT}`
- Flask: `ExecStart=$INSTALL_DIR/$APP_DIR/venv/bin/gunicorn -b 127.0.0.1:{APP_PORT} {MODULE}:app`
- Django: `ExecStart=$INSTALL_DIR/$APP_DIR/venv/bin/gunicorn -b 127.0.0.1:{APP_PORT} {PROJECT}.wsgi:application`

### Node.js (Express / Next.js)

**SETUP_BLOCK** (Node):
```bash
    # Node.js
    if ! command -v node &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash - 2>/dev/null || \
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - 2>/dev/null
        $PKG_INSTALL nodejs > /dev/null 2>&1
    fi
    cd "$APP_DIR"
    npm ci --production -q
    {BUILD_COMMAND}
    info "의존성 설치 완료"
```

### NGINX_BLOCK (공통, Streamlit은 WebSocket 추가)

Streamlit:
```bash
    cat << NGINXEOF | sudo tee /etc/nginx/conf.d/$APP_NAME.conf > /dev/null
server {
    listen 80;
    server_name _;
    client_max_body_size 0;
    ...WebSocket 포함...
}
NGINXEOF
```

일반 (FastAPI/Express 등):
```bash
    cat << NGINXEOF | sudo tee /etc/nginx/conf.d/$APP_NAME.conf > /dev/null
server {
    listen 80;
    server_name _;
    client_max_body_size 50M;
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host $host;
        ...
    }
}
NGINXEOF
```

---

## DATA_DIR_BLOCK 생성 규칙

코드에서 감지된 데이터 디렉토리를 mkdir -p로 생성:

```bash
    mkdir -p "$INSTALL_DIR/데이터경로1"
    mkdir -p "$INSTALL_DIR/데이터경로2"
    chmod -R 777 "$INSTALL_DIR/데이터경로1"
    info "데이터 디렉토리 생성"
```

감지 방법: .gitignore에 있으면서 코드에서 참조되는 경로.

---

## POST_DEPLOY_MESSAGES

프레임워크별 추가 안내:
- Streamlit: `warn ".env 파일에서 DASHBOARD_PASSWORD를 설정하세요"`
- FastAPI: `warn "API 문서: http://서버IP/docs"`
- Next.js: `warn "NEXT_PUBLIC_ 변수 변경 시 재빌드 필요: npm run build"`
