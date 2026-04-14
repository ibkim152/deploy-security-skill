#!/bin/bash
# deploy-security 스킬 설치 스크립트
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/deploy-security"

if [ -d "$SKILL_DIR" ]; then
    echo "[!] 기존 설치 발견. 업데이트합니다..."
    rm -rf "$SKILL_DIR"
fi

mkdir -p "$SKILL_DIR"

# 현재 디렉토리에서 복사 (git clone 후 실행하는 경우)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp -r "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/"
cp -r "$SCRIPT_DIR/references" "$SKILL_DIR/"
cp -r "$SCRIPT_DIR/plugins" "$SKILL_DIR/"

echo ""
echo "============================================================"
echo "  deploy-security 스킬 설치 완료!"
echo "============================================================"
echo ""
echo "  설치 위치: $SKILL_DIR"
echo ""
echo "  사용법:"
echo "    Claude Code에서 /deploy-security 입력"
echo ""
echo "  명령어:"
echo "    /deploy-security          # 전체 점검 + 조치 + 배포 스크립트 생성"
echo "    /deploy-security scan     # 점검만"
echo "    /deploy-security dry-run  # 점검 + 계획만 (수정 안 함)"
echo ""
echo "============================================================"
