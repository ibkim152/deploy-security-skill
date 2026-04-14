# OS별 명령어 참조 + 클라우드별 트러블슈팅

## Phase 0에서 OS 감지

서버 배포 가이드 생성 시, 대상 OS를 감지하거나 사용자에게 확인하여 명령어를 분기한다.

### 감지 방법
```bash
cat /etc/os-release
```

| ID 값 | OS | 패키지 매니저 | 계열 |
|--------|-----|-------------|------|
| `ubuntu`, `debian` | Ubuntu/Debian | `apt` | Debian |
| `ol`, `centos`, `rhel`, `rocky`, `almalinux` | Oracle Linux/CentOS/RHEL/Rocky | `dnf` | RHEL |
| `amzn` | Amazon Linux | `dnf` (AL2023) / `yum` (AL2) | RHEL |

---

## 명령어 매핑 (Ubuntu vs RHEL 계열)

### 시스템 업데이트

| Ubuntu | Oracle Linux / RHEL / Rocky |
|--------|---------------------------|
| `sudo apt update && sudo apt upgrade -y` | `sudo dnf update -y` |

### Python 설치

| Ubuntu | Oracle Linux 9 |
|--------|---------------|
| `sudo add-apt-repository ppa:deadsnakes/ppa -y` | (기본 Python 3.9 사용 또는) |
| `sudo apt install python3.14 python3.14-venv -y` | `sudo dnf install python3.11 python3.11-pip python3.11-devel -y` |

> **주의**: Oracle Linux 9 기본은 Python 3.9. 3.11은 AppStream에서 설치 가능.
> Python 3.12+는 소스 빌드 필요할 수 있음. 가이드 생성 시 서버의 가용 버전에 맞춰 작성.

### nginx 설치

| Ubuntu | Oracle Linux / RHEL |
|--------|-------------------|
| `sudo apt install nginx -y` | `sudo dnf install nginx -y` |

### 방화벽

| Ubuntu (ufw) | Oracle Linux (firewalld) |
|-------------|------------------------|
| `sudo ufw allow 80/tcp` | `sudo firewall-cmd --permanent --add-service=http` |
| `sudo ufw allow 443/tcp` | `sudo firewall-cmd --permanent --add-service=https` |
| `sudo ufw enable` | `sudo firewall-cmd --reload` |

### SELinux (RHEL 계열 전용 — 매우 중요)

Ubuntu에는 SELinux가 없지만, **Oracle Linux / RHEL / Rocky / CentOS**에는 기본 활성화.
nginx가 백엔드(Streamlit, FastAPI 등)에 프록시하려면 반드시 설정 필요:

```bash
# nginx → 백엔드 프록시 허용 (필수!)
sudo setsebool -P httpd_can_network_connect 1

# SELinux 상태 확인
getenforce
# "Enforcing" → 활성 상태, "Permissive" → 경고만, "Disabled" → 비활성
```

> **이걸 안 하면**: nginx 502 Bad Gateway 발생. 로그에 `(13: Permission denied) while connecting to upstream` 표시.

### Docker 설치

| Ubuntu | Oracle Linux 9 |
|--------|---------------|
| `curl -fsSL https://get.docker.com \| sudo sh` | `sudo dnf install -y dnf-utils` |
| | `sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo` |
| | `sudo dnf install docker-ce docker-ce-cli containerd.io -y` |
| | `sudo systemctl enable --now docker` |

### Let's Encrypt (certbot)

| Ubuntu | Oracle Linux 9 |
|--------|---------------|
| `sudo apt install certbot python3-certbot-nginx -y` | `sudo dnf install certbot python3-certbot-nginx -y` |

### systemd (동일)

systemctl 명령은 양쪽 모두 동일:
```bash
sudo systemctl daemon-reload
sudo systemctl enable 서비스명
sudo systemctl start 서비스명
sudo systemctl status 서비스명
```

---

## 클라우드별 SSH 기본 사용자

| 클라우드 | OS | 기본 사용자 |
|---------|-----|-----------|
| OCI | Oracle Linux | `opc` |
| OCI | Ubuntu | `ubuntu` |
| AWS | Amazon Linux | `ec2-user` |
| AWS | Ubuntu | `ubuntu` |
| GCP | 모든 OS | `사용자명` (gcloud 설정에 따름) |
| NCP | 모든 OS | `root` |

---

## 클라우드별 방화벽 2중 구조 (핵심 트러블슈팅)

**클라우드 서버는 방화벽이 2겹**이다. 둘 다 열어야 외부에서 접속 가능:

```
[외부] → [클라우드 보안 규칙] → [OS 방화벽] → [앱]
           ↑ 여기도 열어야 함     ↑ 여기도 열어야 함
```

### OCI (Oracle Cloud)
1. **OCI Security List** (콘솔): Networking → VCN → Subnet → Security Lists → Ingress Rules
2. **OS firewalld** (서버): `sudo firewall-cmd --permanent --add-service=http && sudo firewall-cmd --reload`

### AWS
1. **Security Group** (콘솔): EC2 → Security Groups → Inbound Rules
2. **OS 방화벽**: Ubuntu는 ufw 기본 비활성, Amazon Linux는 iptables

### GCP
1. **VPC Firewall Rules** (콘솔): VPC Network → Firewall → Create Rule
2. **OS 방화벽**: 보통 비활성 상태

### NCP (네이버 클라우드)
1. **ACG** (콘솔): Server → ACG → Inbound Rules
2. **OS 방화벽**: Ubuntu는 ufw 기본 비활성

> **가장 흔한 실수**: 클라우드 콘솔에서 포트를 열었는데 OS 방화벽을 안 열어서 "연결할 수 없음" 발생.
> 반대로 OS 방화벽만 열고 클라우드 규칙을 안 열어도 동일 증상.
> **배포 가이드에 반드시 양쪽 모두 안내할 것.**

---

## Git Clone 시 주의사항

### 토큰 포함 URL의 줄바꿈 문제

터미널에서 긴 URL이 자동 줄바꿈되면 명령이 깨진다:
```
# 나쁜 예 (줄바꿈 발생 가능):
git clone https://user:ghp_very_long_token_here@github.com/user/repo.git /path

# 좋은 예 (토큰 없이 clone → 프롬프트에서 입력):
git clone https://github.com/user/repo.git /path
# Username: user
# Password: (토큰 붙여넣기)
```

**배포 가이드에서는 토큰을 URL에 넣지 않는 방식을 기본으로 안내한다.**

### Private 저장소 접근

```bash
# 방법 1: gh CLI (가장 편리)
gh auth login
gh repo clone user/repo

# 방법 2: HTTPS + 프롬프트
git clone https://github.com/user/repo.git
# → 사용자명 + 토큰 입력

# 방법 3: SSH
git clone git@github.com:user/repo.git
# → 서버에 SSH 키 등록 필요
```

---

## nginx 기본 설정 충돌 (RHEL 계열)

Oracle Linux / RHEL의 `/etc/nginx/nginx.conf`에 기본 `server {}` 블록이 있어
커스텀 설정과 `server_name _` 충돌 발생:

```
nginx: [warn] conflicting server name "_" on 0.0.0.0:80, ignored
```

**해결**: warn은 동작에 영향 없으므로 무시 가능. 깔끔하게 하려면:
```bash
# 기본 server 블록 비활성화
sudo sed -i '/^    server {/,/^    }/d' /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl reload nginx
```

Ubuntu는 `sites-enabled/default`를 삭제:
```bash
sudo rm /etc/nginx/sites-enabled/default
```
