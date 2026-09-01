# 01-IITP-DABT-Database
1.장애인 통합 데이터베이스

![version](https://img.shields.io/badge/version-v1.2.0-blue)

장애인 자립 생활 지원 플랫폼 데이터베이스(`iitp_db`)의 **스키마 정의·초기화·데이터 교정 마이그레이션 스크립트** 저장소.

## 이미지 다운로더 소스 이관 안내

CSV 기반 이미지 다운로더(`downloader.py`)와 실패 로그 분석 유틸(`analyze_errors.py`)은
[04-IITP-DABT-DataCollector](https://github.com/sweetk-dev/04-IITP-DABT-DataCollector) 저장소로 **일원화**되었다.

- 본 저장소에 있던 사본은 v1.1.2 에서 제거됨 (구본 — 원자적 저장 개선 이전 버전)
- 최신 소스는 04 저장소에서 단일 관리: 다중 소스 수집 계층(`collectors/`), 원자적 저장, 후처리 모듈(라벨 보강·중복 검사·학습셋 분할) 포함
- 관련 실행 방법·CSV 규격은 04 저장소 README 참조

## SQL

`SQL/` 아래에 스키마 초기화 스크립트와 데이터 교정 마이그레이션을 둔다.

| 파일 | 용도 |
|---|---|
| `iitp_db_schemas_init-*.sql` | 도메인별 스키마 생성 (basic / poi / emp / mobility / unst / admin / webPlatform) |
| `KOSIS_stats_data_creation.sql` | KOSIS 통계 테이블 |
| `mv_poi_latlng_fix.sql` | **mv_poi 위경도 뒤바뀜 교정 + CHECK 제약** (2026-07-16, GGTOUR 적재분 51,677건) |

교정 마이그레이션은 실행 전 백업이 필요하다.

```bash
pg_dump -U postgres -d iitp_db -t mv_poi --data-only -f mv_poi_backup.sql
psql -U postgres -d iitp_db -v ON_ERROR_STOP=1 -f SQL/mv_poi_latlng_fix.sql
```

## 라이선스

이 프로젝트는 MIT 라이선스로 배포됩니다. 전문은 [LICENSE](LICENSE) 파일을 참고하십시오.

본 연구는 정부(과학기술정보통신부)의 재원으로 정보통신기획평가원의 지원을 받아 수행된 연구입니다.
(연구개발과제번호 RS-2024-003976, 데이터 기반 장애인 데이터 탐색·활용 해결기술 개발)
