-- ============================================================================
-- 접근성 컬럼 추가 마이그레이션 (v1.4.0, 2026-09-05)
--
-- 1) poi_facility_accessibility — 기구표 항목 중 담을 컬럼이 없던 2종
--    · guide_facility_yn   유도 및 안내 설비         (안양 1,617개 시설 중 37건)
--    · accessible_room_yn  장애인사용가능객실       (23건)
--    적재 규칙(08-IITP-DABT-PreProcessing collectors/kowsi_facl.py):
--    · 기구표 원문에 항목이 있으면 'Y'
--    · guide_facility_yn 은 다른 5개 항목과 같이 정상 기구표에 항목이 없으면 'N'
--    · accessible_room_yn 은 숙박시설에만 해당하므로 항목이 없으면 'N' 이 아니라 NULL(판정 안 함)
--    · 기구표 미작성(더미 응답)·미조회는 전부 NULL
--    기존 행은 저장된 eval_info_raw 를 다시 파싱해 채운다(재수집 불필요).
--
-- 2) poi_public_toilet_info — 남녀공용 여부
--    · unisex_yn  원천(경기데이터드림 MALE_FEMALE_CMNUSE_TOILET_YN)이 제공하지만 컬럼이 없어 버리던 값.
--      이성 활동지원사·가족과 동행하는 이용자에게 필요한 정보.
--
-- 전부 NULL 허용·기본값 없음이라 기존 행·소비자 API 에 영향이 없다. 재실행해도 안전(IF NOT EXISTS).
-- ============================================================================

BEGIN;

ALTER TABLE public.poi_facility_accessibility
    ADD COLUMN IF NOT EXISTS guide_facility_yn  bpchar(1) NULL,
    ADD COLUMN IF NOT EXISTS accessible_room_yn bpchar(1) NULL;

COMMENT ON COLUMN public.poi_facility_accessibility.guide_facility_yn  IS '유도 및 안내 설비 Y/N (기구표 파싱, 미확인 NULL)';
COMMENT ON COLUMN public.poi_facility_accessibility.accessible_room_yn IS '장애인사용가능객실 Y (숙박시설 외·미확인 NULL)';

ALTER TABLE public.poi_public_toilet_info
    ADD COLUMN IF NOT EXISTS unisex_yn char(1) NULL;

COMMENT ON COLUMN public.poi_public_toilet_info.unisex_yn IS '남녀공용 화장실 여부 (Y/N)';

COMMIT;
