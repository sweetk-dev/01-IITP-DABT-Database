-- ============================================================================
-- mv_poi 위경도 뒤바뀜 교정 + 재발 방지 (2026-07-16)
--
-- 현상 : latitude 자리에 경도, longitude 자리에 위도가 저장됨.
--        예) 안양문화원 latitude=126.9257 — 위도는 정의상 -90~90 이라 불가능한 값.
-- 범위 : source_organization='GGTOUR' 적재분(2025-09-15) 51,677건 / 51,742건 (99.9%)
--        DANURIM 적재분 887건은 정상 — 조건으로 분리 보호한다.
-- 원인 : mv_poi 적재 코드가 어느 레포에도 없음(02·04·08 확인). 레포 체계 성립 이전
--        일회성 적재분의 매핑 오류. 스키마 정의(latitude='위도')는 정상.
--
-- ⚠️ 실행 전 백업 필수:
--    pg_dump -U postgres -d iitp_db -t mv_poi --data-only -f mv_poi_backup.sql
-- ============================================================================

BEGIN;

-- [1] 교정 — 위도 자리에 경도값(124~132), 경도 자리에 위도값(33~39)인 GGTOUR 행만.
--     이미 정상인 행은 조건에 걸리지 않으므로 재실행해도 안전하다(멱등).
UPDATE mv_poi
   SET latitude = longitude, longitude = latitude
 WHERE source_organization = 'GGTOUR'
   AND latitude  BETWEEN 124 AND 132
   AND longitude BETWEEN 33 AND 39;

-- [2] 원본 손상 2건 — 스왑이 아니라 원본 값 자체가 깨진 건.
--     등록된 도로명주소 기준으로 지오코딩해 복원했다.
--     1710  오산반려동물테마파크 (경기도 오산시 오산천로 72)  : lat=117.99/lng=19.69 — 뒤집어도 한국이 아님
--     16786 내 인생의 한방 축제  (대전광역시 동구 태전로 1)   : 경도 결측
UPDATE mv_poi SET latitude = 37.1554418, longitude = 127.0704943 WHERE poi_id = 1710;
UPDATE mv_poi SET latitude = 36.3374632, longitude = 127.4249826 WHERE poi_id = 16786;

-- [3] 재발 방지 — 적재 경로와 무관하게 범위를 벗어난 값을 삽입 시점에 거부한다.
--     위경도는 함께 있거나 함께 없어야 한다(한쪽만 결측 = 16786 사례).
ALTER TABLE public.mv_poi
  ADD CONSTRAINT ck_mv_poi_latlng_range
  CHECK (
    (latitude IS NULL AND longitude IS NULL)
    OR (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
  );

COMMENT ON CONSTRAINT ck_mv_poi_latlng_range ON public.mv_poi IS
  '위경도 범위·짝 강제 — GGTOUR 적재분 51,677건 위경도 스왑 사고(2026-07-16) 재발 방지';

COMMIT;

-- ── 검증 ────────────────────────────────────────────────────────────────────
-- 스왑 0건 / 좌표 보유분 전부 한국 범위여야 한다.
SELECT count(*) FILTER (WHERE latitude BETWEEN 124 AND 132 AND longitude BETWEEN 33 AND 39) AS still_swapped,
       count(*) FILTER (WHERE latitude BETWEEN 33 AND 39 AND longitude BETWEEN 124 AND 132) AS in_korea,
       count(*) FILTER (WHERE latitude IS NULL) AS no_coord,
       count(*) AS total
  FROM mv_poi;
