# 보고서 생성 템플릿

## 생성 전략

1. `python3 -c "import docx"` 성공 → Word(.docx) 생성
2. 실패 시 → `python3 -m venv /tmp/deploy-sec-venv && /tmp/deploy-sec-venv/bin/pip install python-docx` 시도
3. 여전히 실패 → Markdown(.md) fallback

**프로젝트 venv를 절대 오염시키지 않는다** — 임시 venv(`/tmp/deploy-sec-venv`)만 사용.

---

## Word(.docx) 보고서 구조

### 스타일 규칙
- 본문: 맑은 고딕 10pt (한글), Calibri 10pt (영문)
- 표: Table Grid, 헤더 행 배경색
- 우선순위 색상: 긴급=빨강(DC3545), 상=주황(FD7E14), 중=노랑(FFC107), 하=초록(19875A), 정상=회색(6C757D)
- 페이지: A4, 여백 2.5cm

### 보고서 섹션
1. **표지**: 프로젝트명, 점검일, 기술스택, 인프라 타겟
2. **범위 제한 경고**: 인프라 타겟별 미커버 영역 명시
3. **요약 표**: 긴급/상/중/하/정상 카운트
4. **영역별 상세** (7+1개): 항목 | 상태 | 우선순위 | 조치 (표)
5. **자동 조치 내역**: 수정한 파일 + 변경 전/후
6. **수동 조치 가이드**: 자동화 불가 항목
7. **부록**: 점검 기준 설명

### generate_report.py 핵심

```python
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from datetime import datetime

PRIORITY_COLORS = {
    "긴급": "DC3545", "상": "FD7E14", "중": "FFC107",
    "하": "19875A", "정상": "6C757D",
}

def create_report(findings, project_name, tech_stack, infra_target,
                  auto_fixes, manual_items, scope_warnings):
    doc = Document()
    # 기본 스타일
    style = doc.styles['Normal']
    style.font.name = 'Calibri'
    style.font.size = Pt(10)
    style.element.rPr.rFonts.set(qn('w:eastAsia'), '맑은 고딕')
    # A4 + 2.5cm 여백
    section = doc.sections[0]
    section.page_width, section.page_height = Cm(21), Cm(29.7)
    for m in ['top_margin','bottom_margin','left_margin','right_margin']:
        setattr(section, m, Cm(2.5))
    # 1. 표지  2. 범위 경고  3. 요약  4. 영역별 상세  5. 조치 내역  6. 수동 가이드
    doc.save('_workspace/deploy_security_report.docx')
```

스캔 결과 데이터를 findings/auto_fixes/manual_items에 직접 삽입하여 실행한다.

---

## Markdown fallback 구조

python-docx 사용 불가 시 `_workspace/deploy_security_report.md`로 동일 내용 생성:

```markdown
# 프로덕션 배포 보안 점검 보고서

- 프로젝트: {name}
- 기술스택: {stack}
- 인프라 타겟: {target}
- 점검일: {date}

> ⚠ 점검 범위 제한: {scope_warnings}

## 점검 요약
| 긴급 | 상 | 중 | 하 | 정상 | 합계 |
|------|-----|-----|-----|------|------|
| {n}  | {n} | {n} | {n} | {n}  | {n}  |

## 1. 시크릿 노출
| 항목 | 상태 | 우선순위 | 조치 |
|------|------|---------|------|
...

## 자동 조치 내역
### {파일명}
- 변경 사유: {reason}
- 변경 내용: (코드 블록)

## 수동 조치 가이드
### {항목}
{가이드 내용}
```
