# PostgreSQL-Oracle 연동 가이드

이 저장소는 PostgreSQL과 Oracle 데이터베이스를 연동하기 위한 가이드와 스크립트를 포함하고 있습니다.

## 디렉토리 구조

```
.
├── guide/                  # 상세 설치 및 설정 가이드
│   └── oracle_fdw_guide_ko.md
├── prompt/                 # 원본 프롬프트
│   └── oracle_fdw_setup_prompt.md
└── scripts/                # 설치 스크립트
    └── install_oracle_fdw.sh
```

## 시작하기

### 사전 요구사항
- Ubuntu 20.04/22.04 LTS
- sudo 권한
- 인터넷 연결

### 설치 방법

1. 저장소 복제:
   ```bash
   git clone https://github.com/hiwylee/postgre2adb.git
   cd postgre2adb
   ```

2. 설치 스크립트 실행:
   ```bash
   sudo ./scripts/install_oracle_fdw.sh
   ```

3. 설치 완료 후 가이드 문서 확인:
   ```
   guide/oracle_fdw_guide_ko.md
   ```

## 문서

- [상세 설치 가이드](guide/oracle_fdw_guide_ko.md) - 단계별 설치 및 설정 방법
- [원본 프롬프트](prompt/oracle_fdw_setup_prompt.md) - 이 가이드를 생성한 프롬프트

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 기여

버그 수정이나 개선 사항이 있으면 이슈를 등록하거나 풀 리퀘스트를 보내주세요.
# postgre2adb
