-- ============================================================================
-- 긴급대응 지원시설 — 설치 지점 구분 + 전국 원천 코드 등록 (v1.7.0, 2026-09-09)
--
-- 1) poi_emergency_support.install_desc
--    자연키가 (support_type, name, coalesce(addr_road,'')) 뿐이라 **같은 건물에
--    설치 지점이 여러 곳인 충전기**를 구분하지 못한다. 전국전동휠체어급속충전기
--    표준데이터 4,191행 중 380행이 185개 키로 겹치며, 그대로 적재하면 195행이
--    조용히 사라진다. 좌표까지 다른 경우가 있어 병합으로는 정보가 손실된다.
--      예) 김포시청 / 경기도 김포시 사우중로 1
--            - "제3별관 1층 로비"
--            - "민원동 장애인화장실 옆"
--          운정중앙역 환승센터 — 북측 대합실(37.7163)·남측 대합실(37.7159)
--    설치 지점 설명을 컬럼으로 올리고 자연키에 포함한다.
--
-- 2) 자연키 확장
--    (support_type, name, coalesce(addr_road,''), coalesce(install_desc,''))
--    install_desc 가 NULL 인 기존 행(수리센터·콜택시)은 종전과 동일하게 동작한다.
--
-- 3) 외부 연동 시스템 코드 4건
--    STD_WCHAIR_CHARGER / KNAT_REPAIR / KNAT_CENTER / NHIS_ASSIST_STORE
--
-- 모두 IF NOT EXISTS 라 재실행해도 안전하다.
-- ============================================================================

BEGIN;

-- 1) 설치 지점 -------------------------------------------------------------
ALTER TABLE public.poi_emergency_support
    ADD COLUMN IF NOT EXISTS install_desc varchar(300) NULL;

COMMENT ON COLUMN public.poi_emergency_support.install_desc
    IS '설치 지점 설명 — 같은 건물 내 복수 설치를 구분한다(자연키 구성요소). 충전기 전용, 수리센터는 NULL';

-- 2) 자연키 확장 -----------------------------------------------------------
--    기존 인덱스를 지우고 다시 만든다. install_desc 가 전부 NULL 인 상태에서는
--    기존 키와 동일하게 동작하므로 기존 행에 영향이 없다.
DROP INDEX IF EXISTS uidx_poi_emergency_support_key;
CREATE UNIQUE INDEX IF NOT EXISTS uidx_poi_emergency_support_key
    ON public.poi_emergency_support USING btree
       (support_type, name, coalesce(addr_road, ''), coalesce(install_desc, ''));

-- 3) 외부 연동 시스템 코드 ---------------------------------------------------
INSERT INTO public.sys_common_code
    (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl,
     sort_order, use_yn, del_yn, code_des, memo, created_at, created_by)
SELECT 'ext_sys_code', '외부 연동 시스템 코드', 'STD_WCHAIR_CHARGER', '전국전동휠체어급속충전기표준데이터',
       null, null, 'S', 1, 9, 'Y', 'N',
       '행정안전부 개방표준(데이터 15034533) 전국 충전기 (poi_emergency_support, support_type=charge)', '',
       CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code' AND code_id = 'STD_WCHAIR_CHARGER'
);

INSERT INTO public.sys_common_code
    (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl,
     sort_order, use_yn, del_yn, code_des, memo, created_at, created_by)
SELECT 'ext_sys_code', '외부 연동 시스템 코드', 'KNAT_REPAIR', '중앙보조기기센터 수리센터 지정업체 명부',
       null, null, 'S', 1, 10, 'Y', 'N',
       '지자체 수리 지원사업 지정업체 명부 (poi_emergency_support, support_type=repair). 원천에 주소·좌표 없음 — confidence=L', '',
       CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code' AND code_id = 'KNAT_REPAIR'
);

INSERT INTO public.sys_common_code
    (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl,
     sort_order, use_yn, del_yn, code_des, memo, created_at, created_by)
SELECT 'ext_sys_code', '외부 연동 시스템 코드', 'KNAT_CENTER', '중앙보조기기센터 전국 보조기기센터',
       null, null, 'S', 1, 11, 'Y', 'N',
       '공공 위탁 보조기기센터 33곳 — 수리·개조·세척 수행 (poi_emergency_support, support_type=repair)', '',
       CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code' AND code_id = 'KNAT_CENTER'
);

INSERT INTO public.sys_common_code
    (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl,
     sort_order, use_yn, del_yn, code_des, memo, created_at, created_by)
SELECT 'ext_sys_code', '외부 연동 시스템 코드', 'NHIS_ASSIST_STORE', '국민건강보험공단 보조기기 급여 등록업소',
       null, null, 'S', 1, 12, 'Y', 'N',
       '전동보장구 취급 등록업소 (poi_emergency_support, support_type=repair). 급여 구입처 등록이지 수리 역량 보증이 아님 — confidence=L', '',
       CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code' AND code_id = 'NHIS_ASSIST_STORE'
);

COMMIT;
