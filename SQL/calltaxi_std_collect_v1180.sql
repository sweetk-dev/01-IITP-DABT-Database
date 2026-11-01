-- ============================================================================
-- 교통약자이동지원센터(장애인콜택시) 표준데이터 정기 수집 등록 (v1.18.0, 2026-11-02)
--
-- 공공데이터포털 표준데이터 「전국교통약자이동지원센터정보표준데이터」(데이터 ID 15028207)를
-- 08-IITP-DABT-PreProcessing v1.23.0 의 수집 작업 STD_CALLTAXI 가 매월 OpenAPI 로 받아
-- poi_emergency_support 에 support_type='calltaxi', source='STD_CALLTAXI' 로 동기화한다.
-- 적재 표·자연키는 v1.6.0·v1.7.0 그대로라 표 변경은 없다.
--
-- 이 스크립트가 하는 일
--   1) 외부 연동 시스템 코드 STD_CALLTAXI 등록
--   2) 외부 API 정보 STD_CALLTAXI 1행 — 인증키는 저장소에 두지 않는다. 같은 공공데이터포털 키를 쓰는
--      ODCLOUD_EMP 등의 행 값을 복사하고, 없으면 NULL(수집기는 환경변수 STD_CALLTAXI_API_KEY·
--      DATA_GO_KR_API_KEY 로도 받는다). 표준데이터 OpenAPI 도 활용신청이 있어야 응답한다.
--
-- 공개 데이터 요약표(sys_data_summary_info)에는 행을 넣지 않는다 — 06 플랫폼·OPEN API(09) 노출은 별도 작업.
-- 모두 NOT EXISTS 라 재실행해도 결과가 같다. 08 v1.23.0 배포 전에 적용한다.
-- ============================================================================

BEGIN;

-- 1) 외부 연동 시스템 코드 ---------------------------------------------------
INSERT INTO public.sys_common_code
    (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl,
     sort_order, use_yn, del_yn, code_des, memo, created_at, created_by)
SELECT 'ext_sys_code', '외부 연동 시스템 코드', 'STD_CALLTAXI', '전국교통약자이동지원센터정보표준데이터(OpenAPI)',
       null, null, 'S', 1,
       (SELECT coalesce(max(sort_order), 0) + 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code'),
       'Y', 'N',
       '표준데이터 OpenAPI 로 전국 교통약자이동지원센터(장애인콜택시) 목록 수집 (poi_emergency_support, calltaxi)', '',
       CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code' AND code_id = 'STD_CALLTAXI'
);

-- 2) 외부 API 정보 ------------------------------------------------------------
INSERT INTO public.sys_ext_api_info
    (if_name, ext_sys, ext_url, auth, data_format, latest_sync_time, memo, del_yn,
     created_at, updated_at, created_by)
SELECT '전국교통약자이동지원센터정보 표준데이터', 'STD_CALLTAXI',
       'https://api.data.go.kr/openapi/tn_pubr_public_tfcwker_mvmn_cnter_api',
       (SELECT auth FROM public.sys_ext_api_info
         WHERE ext_sys IN ('ODCLOUD_EMP', 'ODCLOUD_DIS', 'GBIS', 'KORAIL_CONV', 'KOWSI_FACL', 'TOUR_BF_API')
           AND del_yn = 'N' AND auth IS NOT NULL AND auth <> ''
         ORDER BY CASE ext_sys WHEN 'ODCLOUD_EMP' THEN 0 ELSE 1 END, ext_api_id LIMIT 1),
       'JSON', null,
       '공공데이터포털 데이터 15028207. 센터 목록·접수 전화·운영 시간·차량·요금. 매월 수집, 원천에서 사라진 센터는 논리삭제. 포털 활용신청 필요', 'N',
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_ext_api_info WHERE ext_sys = 'STD_CALLTAXI'
);

COMMIT;
