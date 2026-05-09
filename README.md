# Hatchgundam 배포용

Claude Code와 Codex 상태를 함께 반영하는 Hatchgundam 데스크톱 오버레이 배포 폴더임.

## 포함 파일

- `hatchgundam.exe`: Python 없이 실행하는 오버레이 본체
- `install.ps1`: 앱 설치, Codex hook 연결, 시작 프로그램 등록, 즉시 실행
- `uninstall.ps1`: 시작 프로그램, 관리 hook 블록, 앱 파일 제거
- `hooks/codex-pet-status.ps1`: Codex 상태 writer
- `assets/spritesheet.webp`: Hatchgundam 전용 애니메이션 스프라이트
- `src/hatchgundam_overlay.py`: exe 빌드 원본
- `build.ps1`: PyInstaller 빌드 스크립트

## 설치

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
```

설치 후 Codex를 새로 시작하면 Codex hook이 적용됨. Claude 상태는 기존 Claude Status Writer가 `~\.claude\claude_status.json`을 갱신하는 구성에서 함께 반영됨.

## 제거

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\uninstall.ps1"
```

## 동작 기준

오버레이는 `~\.codex\codex_status.json`과 `~\.claude\claude_status.json`을 모두 읽고, 더 최근에 갱신된 상태를 표시함. 하단 라벨은 `idle`, `run`, `wait`, `perm` 상태만 간단히 표시함.

## 이미지 리소스

현재 `assets/spritesheet.webp`는 배포 폴더 안에서 생성한 Hatchgundam용 원본 메카 스프라이트임. 특정 상표 캐릭터를 그대로 복제한 파일이 아니라, 흰색 장갑·V형 안테나·파란 몸통·빨간 발·노란 포인트를 가진 건담풍 원본 펫으로 구성함.
