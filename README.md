# 01-IITP-DABT-Database
1.장애인 통합 데이터베이스

![version](https://img.shields.io/badge/version-v1.7.0-blue)

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
| `iitp_db_schemas_init-deletion_and_creation_mobility.sql` | 이동편의 스키마 — 버스 노선·정류장(GBIS), 역 편의 현황·**설비 단위 승강기·화장실·승강장(국가철도공단, v1.3.0)**, 건물 편의시설 |
| `KOSIS_stats_data_creation.sql` | **참고용(실행 금지)** — 초기 설계 시점(ver 0.0.3)의 KOSIS 테이블 정의. 현행 KOSIS 테이블은 `iitp_db_schemas_init-deletion_and_creation_basic.sql` 이 만든다. basic 적용 후 이 파일을 실행하면 `stats_kosis_origin_data` 가 구버전 정의로 다시 만들어져 수집 데이터가 지워지고 적재 배치가 실패한다 |
| `mv_poi_latlng_fix.sql` | **mv_poi 위경도 뒤바뀜 교정 + CHECK 제약** (2026-07-16, GGTOUR 적재분 51,677건). 같은 CHECK 제약은 poi init 의 `mv_poi` 정의에도 들어 있으며, 제약이 이미 있으면 추가를 건너뛰므로 재실행 안전 |
| `accessibility_columns_v140.sql` | **접근성 컬럼 추가** (v1.4.0) — `poi_facility_accessibility.guide_facility_yn`·`accessible_room_yn`, `poi_public_toilet_info.unisex_yn`. NULL 허용·`IF NOT EXISTS` 라 재실행 안전 |
| `emergency_support_v160.sql` | **긴급대응 지원시설 표 신설 + 편의정보 원문 보존** (v1.6.0) — `poi_emergency_support`(보장구 수리·충전·콜택시, 운영시간·출처 신뢰도 포함) 신설, `poi_tour_bf_facility.detail_raw` 추가, ext_sys_code `GG_ASSIST_REPAIR`. 적재는 08 `GG_ASSIST_REPAIR` 수집기. 재실행 안전 |
| `emergency_support_v170.sql` | **설치 지점 구분 + 전국 원천 코드** (v1.7.0) — `poi_emergency_support.install_desc` 추가, 자연키를 `(support_type, name, addr_road, install_desc)` 로 확장. 같은 건물에 충전기가 여러 대 설치된 경우(김포시청 제3별관·민원동)를 별개 행으로 보존한다. ext_sys_code `STD_WCHAIR_CHARGER`·`KNAT_REPAIR`·`KNAT_CENTER`·`NHIS_ASSIST_STORE`. 재실행 안전 |
| `low_floor_bus_v150.sql` | **저상버스 운행 노선 기준일 컬럼** (v1.5.0) — `tran_bus_route_info.low_bus_base_dt` 추가, `low_bus_yn` 주석 갱신, ext_sys_code `GBIS_LOWFLOOR`. 적재는 08 `GBIS_LOWFLOOR` 수집기(노선번호+운수사 복합키). 재실행 안전 |
| `stats_intg_unique_v180.sql` | **통합 통계 테이블 중복 방지** — KOSIS 통합 테이블 24종(`stats_dis_*`)의 중복 행을 정리하고 자연키 `(src_data_id, prd_de, c1, c2, c3, itm_id)` 에 UNIQUE 인덱스를 건다(NULL 허용인 `c2`·`c3` 는 COALESCE 표현식, 자료갱신일은 키에 넣지 않는다 — 통계별 최신 1벌만 보관). 값이 같고 갱신일만 다른 행은 갱신일이 가장 늦은 1행을 남긴다. 키가 같고 값이 다른 행이나 `c4` 분류를 쓰는 통계가 있으면 아무것도 바꾸지 않고 중단한다. 같은 인덱스가 basic init 에도 들어 있다. 재실행 안전 |

### 스크립트 적용 순서

**새 DB 를 만들 때** — 아래 순서대로 적용한다. init 스크립트는 `DROP TABLE IF EXISTS` 로 시작하므로 **데이터가 있는 DB 에는 실행하지 않는다.**

| 순서 | 파일 | 비고 |
|---|---|---|
| 1 | `iitp_db_schemas_init-deletion_and_creation_basic.sql` | 공통 코드·외부 API 정보·KOSIS 원본/통합 통계 테이블. 다른 파일이 참조하는 `sys_common_code`, `stats_src_data_info` 를 만든다 |
| 2 | `iitp_db_schemas_init-deletion_and_creation_poi.sql` | |
| 3 | `iitp_db_schemas_init-deletion_and_creation_emp.sql` | |
| 4 | `iitp_db_schemas_init-deletion_and_creation_mobility.sql` | |
| 5 | `iitp_db_schemas_init-deletion_and_creation_unst.sql` | |
| 6 | `iitp_db_schemas_init-deletion_and_creation_admin.sql` | |
| 7 | `iitp_db_schemas_init-deletion_and_creation_webPlatform.sql` | |
| 8 | `iitp_db_schemas_init-Required_data_insert-Sys.sql` | 공통 코드·외부 API·통계 소스 초기 데이터. 대상 테이블을 비우고 다시 넣는다(`TRUNCATE ... CASCADE` 포함 — 통계 소스 정보를 참조하는 통합 통계 테이블도 함께 비워진다) |
| 9 | 버전별 마이그레이션 (아래) | |

2~7 은 서로 참조하지 않아 순서를 바꿔도 되지만, 1 은 맨 앞, 8 은 테이블 생성이 모두 끝난 뒤여야 한다.

**버전별 마이그레이션** — 파일명의 버전 순서대로 적용한다. 모두 재실행해도 결과가 같다.

| 순서 | 파일 | 새 DB(위 1~8 적용 직후)에서 |
|---|---|---|
| 1 | `mv_poi_latlng_fix.sql` | 데이터 교정 대상 없음, CHECK 제약은 이미 있어 건너뜀 |
| 2 | `accessibility_columns_v140.sql` | 컬럼이 이미 있어 변화 없음 |
| 3 | `low_floor_bus_v150.sql` | 컬럼이 이미 있어 변화 없음 |
| 4 | `emergency_support_v160.sql` | 테이블·컬럼은 이미 있음. 공통 코드 `GG_ASSIST_REPAIR` 등록 |
| 5 | `emergency_support_v170.sql` | 컬럼·인덱스는 이미 있음. 공통 코드 4건 등록 |
| 6 | `stats_intg_unique_v180.sql` | 인덱스가 이미 있어 변화 없음 |

init 스크립트는 최신 버전의 테이블 정의를 담고 있으므로, 새 DB 에서 마이그레이션이 하는 일은 공통 코드(`ext_sys_code`) 등록뿐이다. 8번(초기 데이터)은 `ext_sys_code` 그룹을 지우고 다시 넣으므로 **마이그레이션은 반드시 8번 뒤에** 적용한다(먼저 적용하면 마이그레이션이 등록한 코드가 지워진다).

**운영 중인 DB** 에는 init·초기 데이터 스크립트를 실행하지 않고, 아직 적용하지 않은 마이그레이션만 버전 순서대로 적용한다. 데이터를 고치는 마이그레이션(`mv_poi_latlng_fix.sql`, `stats_intg_unique_v180.sql`)은 실행 전 대상 테이블을 백업한다.

`KOSIS_stats_data_creation.sql` 은 위 순서에 포함되지 않는다(참고용).

### 이동편의 역 설비 단위 테이블 (v1.3.0)

`poi_station_access_status` 는 역별 개수·유무만 가진다. 국가철도공단 파일데이터를 설비 단위로 적재하는 표 3종을 더했다
(적재는 08-IITP-DABT-PreProcessing `scripts/load_krna_station_csv.py`).

| 테이블 | 원천 파일(공공데이터포털) | 내용 |
|---|---|---|
| `poi_station_elevator_unit` | 수도권1호선_엘리베이터 15041389 · 수도권4호선_엘리베이터 15041392 | 출입구번호·상세위치·정원 |
| `poi_station_toilet_unit` | 수도권1/4호선_화장실 15041254·15041257 · 장애인화장실 15041222·15041225 | 게이트 안/밖·출구·상세위치·구분 (`disabled_yn`) |
| `poi_station_platform` | 수도권1/4호선_승강장_정보 15041192·15041194 · 승강장이격거리 15041514·15041517 | 상하행·안전발판·스크린도어 + 열차 이격거리 min/max/avg(cm) |

⚠️ 이 파일은 앞부분에 `DROP TABLE IF EXISTS` 가 있으므로 운영 DB 에는 **신규 테이블 블록만 발췌**해 적용한다.

교정 마이그레이션은 실행 전 백업이 필요하다.

```bash
pg_dump -U postgres -d iitp_db -t mv_poi --data-only -f mv_poi_backup.sql
psql -U postgres -d iitp_db -v ON_ERROR_STOP=1 -f SQL/mv_poi_latlng_fix.sql
```

## 라이선스

이 프로젝트는 MIT 라이선스로 배포됩니다. 전문은 [LICENSE](LICENSE) 파일을 참고하십시오.

본 연구는 정부(과학기술정보통신부)의 재원으로 정보통신기획평가원의 지원을 받아 수행된 연구입니다.
(연구개발과제번호 RS-2024-003976, 데이터 기반 장애인 데이터 탐색·활용 해결기술 개발)
