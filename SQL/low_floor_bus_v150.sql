-- ============================================================================
-- 저상버스 운행 노선 기준일 컬럼 추가 (v1.5.0, 2026-09-07) — Issue #46
--
-- tran_bus_route_info.low_bus_yn 은 GBIS 정적 노선 API 에 해당 항목이 없어 비어 있었다.
-- 경기버스정보 "저상버스 노선현황" 페이지(전일 기준 집계)를 08-IITP-DABT-PreProcessing
-- 의 GBIS_LOWFLOOR 수집기가 매일 읽어 채운다. 적재 규칙:
--   · 페이지 목록에 있는 노선(노선번호 + 운수사명 복합키 매칭) → low_bus_yn='Y'
--   · 안양 관할(admin_name) 노선 중 목록에 없는 노선           → 'N'
--   · low_bus_base_dt = 페이지 기준일(수집일 전일)
--   · 페이지 수집 실패 시 기존 값 유지
-- 소비 측(02-IITP-DABT-Route 저상버스 우선 모드)은 low_bus_yn='N' 노선을 후보에서 제외하고,
-- low_bus_base_dt 가 오래되면(예: 7일 초과) 값을 무시한다.
--
-- 같은 노선번호가 여러 운수사에 있으므로(5·6·9번) 번호만으로 매칭하지 않는다.
-- NULL 허용·기본값 없음, IF NOT EXISTS 라 재실행해도 안전하다.
-- ============================================================================

BEGIN;

ALTER TABLE public.tran_bus_route_info
    ADD COLUMN IF NOT EXISTS low_bus_base_dt date NULL;

COMMENT ON COLUMN public.tran_bus_route_info.low_bus_yn      IS '저상버스 운행 여부 Y/N (경기버스정보 저상버스 노선현황, 전일 기준)';
COMMENT ON COLUMN public.tran_bus_route_info.low_bus_base_dt IS 'low_bus_yn 판정 기준일(전일)';

INSERT INTO public.sys_common_code
    (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl,
     sort_order, use_yn, del_yn, code_des, memo, created_at, created_by)
SELECT 'ext_sys_code', '외부 연동 시스템 코드', 'GBIS_LOWFLOOR', '경기버스정보 저상버스 노선현황',
       null, null, 'S', 1, 7, 'Y', 'N',
       '전일 기준 저상버스 운행 노선 수집 (tran_bus_route_info.low_bus_yn)', '', CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code' AND code_id = 'GBIS_LOWFLOOR'
);

COMMIT;
