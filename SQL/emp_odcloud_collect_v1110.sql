-- ============================================================================
-- 장애인 고용 파일데이터 14종 정기 수집 준비 (v1.11.0, 2026-10-15)
--
-- emp_dis_* 표 15종은 2025-07 공공데이터포털 파일데이터를 한 번 받아 넣은 뒤 갱신되지 않았다.
-- 08-IITP-DABT-PreProcessing v1.19.0 의 수집 작업 ODCLOUD_EMP 가 같은 원천을 포털의 자동 변환
-- OpenAPI(odcloud)로 매월 확인해, 새 판(edition)이 올라오면 표를 갱신한다.
-- (emp_dis_obligation_by_type 은 2023-12-31 판 1회로 끝난 데이터라 수집하지 않는다 — 등록 안 함)
--
-- 이 스크립트가 하는 일
--   1) 발달장애인 지원기관 표에 '최중증 통합돌봄' 칸 추가 — 2025-09-30 판에 새로 생긴 원천 칸.
--      옛 판으로 넣은 기존 행은 NULL(원천에 정보 없음)이고, 수집기의 첫 적재 때 모든 행이 채워진다.
--   2) 새 판에서 실제로 빈 값이 나오는 칸 4개의 NOT NULL 해제 (2026-10-15 드라이런 실측)
--        emp_dis_jobseeker_status.salary_type·salary_amount  — 희망임금 '()0'(미기재) 323행,
--                                                              금액 없는 '(시급)' 등 89행 / 44,588행
--        emp_dis_job_posting.job_type                         — 모집직종 빈 값 2행 / 7,085행
--        emp_dis_std_workplace.tel                            — 전화번호 빈 값 98행 / 877행
--      칸을 비워 두지 않으면 그 판 전체를 적재할 수 없다. '' 나 0 으로 채우면 집계(평균 임금 등)가
--      틀어지므로 NULL 로 둔다. 공개 API(09)는 이 칸들을 Integer/String 래퍼 타입으로 읽어 NULL 을 받는다.
--   3) 외부 연동 시스템 코드 ODCLOUD_EMP 등록
--   4) 외부 API 정보 ODCLOUD_EMP 1행 등록 — 인증키는 저장소에 두지 않는다. 같은 공공데이터포털
--      키를 쓰는 기존 행(GBIS·KORAIL_CONV·KOWSI_FACL·TOUR_BF_API)의 값을 복사하고, 없으면 NULL 로 둔다
--      (수집기는 환경변수 ODCLOUD_EMP_API_KEY / DATA_GO_KR_API_KEY 로도 키를 받는다).
--   5) 표별 판 추적 행 14개(sys_stats_src_api_info) 등록 — 새 표를 만들지 않고 기존 추적 표를 쓴다.
--        stat_tbl_id   = 적재 표 이름
--        api_meta_url  = 판 목록·칸 정의 명세 주소 https://infuser.odcloud.kr/oas/docs?namespace={데이터ID}/v1
--        api_data_url  = 이 수집기가 마지막으로 적재한 판의 경로 '/{데이터ID}/v1/uddi:...'.
--                        처음에는 '' (칸이 NOT NULL 이라 NULL 대신 빈 문자열) — 첫 실행이 14종 모두
--                        최신 판을 적재한다. 2025-07 첫 적재 때의 기준일은 sys_data_summary_info.
--                        src_latest_chn_dt 에 그대로 남아 있다(첫 적재 판 일부는 원천에서 이미 사라졌다).
--      KOSIS 수집기는 이 표를 KOSIS 의 ext_api_id 로만 골라 읽으므로 여기 등록하는 행을 읽지 않는다.
--
-- 모두 IF NOT EXISTS / NOT EXISTS / DROP NOT NULL 이라 재실행해도 결과가 같다.
-- 08 v1.19.0 배포 전에 적용한다(적용 전 수집기는 'ODCLOUD_EMP 행 없음' 으로 즉시 멈춘다).
-- ============================================================================

BEGIN;

-- 1) 최중증 통합돌봄 칸 ------------------------------------------------------
ALTER TABLE public.emp_dis_dev_support_org
    ADD COLUMN IF NOT EXISTS severe_integrated_care boolean NULL;
COMMENT ON COLUMN public.emp_dis_dev_support_org.severe_integrated_care
    IS '최중증 통합돌봄 (true/false). 2025-09-30 판부터 원천 제공 — 그 이전 판으로 넣은 행은 NULL';

-- 2) 원천에 빈 값이 있는 칸의 NOT NULL 해제 ------------------------------------
ALTER TABLE public.emp_dis_jobseeker_status ALTER COLUMN salary_type DROP NOT NULL;
ALTER TABLE public.emp_dis_jobseeker_status ALTER COLUMN salary_amount DROP NOT NULL;
COMMENT ON COLUMN public.emp_dis_jobseeker_status.salary_type
    IS '급여타입 (월급/시급). 원천 희망임금이 ''()0''(미기재)이면 NULL';
COMMENT ON COLUMN public.emp_dis_jobseeker_status.salary_amount
    IS '급여금액 (원 단위). 원천 희망임금이 ''()0''(미기재)이거나 ''(시급)''처럼 금액이 없으면 NULL';

ALTER TABLE public.emp_dis_job_posting ALTER COLUMN job_type DROP NOT NULL;
COMMENT ON COLUMN public.emp_dis_job_posting.job_type
    IS '모집직종. 원천이 비어 있으면 NULL';

ALTER TABLE public.emp_dis_std_workplace ALTER COLUMN tel DROP NOT NULL;
COMMENT ON COLUMN public.emp_dis_std_workplace.tel
    IS '전화번호. 원천이 비어 있으면 NULL';

-- 3) 외부 연동 시스템 코드 ---------------------------------------------------
INSERT INTO public.sys_common_code
    (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl,
     sort_order, use_yn, del_yn, code_des, memo, created_at, created_by)
SELECT 'ext_sys_code', '외부 연동 시스템 코드', 'ODCLOUD_EMP', '공공데이터포털 장애인 고용 파일데이터(OpenAPI)',
       null, null, 'S', 1,
       (SELECT coalesce(max(sort_order), 0) + 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code'),
       'Y', 'N',
       '파일데이터 자동 변환 OpenAPI(odcloud)로 emp_dis_* 14종 판 갱신 수집', '',
       CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_common_code WHERE grp_id = 'ext_sys_code' AND code_id = 'ODCLOUD_EMP'
);

-- 4) 외부 API 정보 ------------------------------------------------------------
-- ext_url 은 데이터 API 의 공통 주소다. 수집기가 뒤에 판 경로(/{데이터ID}/v1/uddi:...)를 붙여 호출한다.
INSERT INTO public.sys_ext_api_info
    (if_name, ext_sys, ext_url, auth, data_format, latest_sync_time, memo, del_yn,
     created_at, updated_at, created_by)
SELECT '공공데이터포털 장애인 고용 파일데이터', 'ODCLOUD_EMP', 'https://api.odcloud.kr/api',
       (SELECT auth FROM public.sys_ext_api_info
         WHERE ext_sys IN ('GBIS', 'KORAIL_CONV', 'KOWSI_FACL', 'TOUR_BF_API')
           AND del_yn = 'N' AND auth IS NOT NULL AND auth <> ''
         ORDER BY ext_api_id LIMIT 1),
       'JSON', null,
       'emp_dis_* 14종. 판(기준일) 변경 시 갱신, 매월 수집', 'N',
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYS-MANUAL'
WHERE NOT EXISTS (
    SELECT 1 FROM public.sys_ext_api_info WHERE ext_sys = 'ODCLOUD_EMP'
);

-- 5) 표별 판 추적 행 -----------------------------------------------------------
INSERT INTO public.sys_stats_src_api_info
    (ext_api_id, status, del_yn, stat_title, stat_tbl_id, use_base_url_yn,
     api_data_url, api_meta_url, api_latest_chn_dt_url, latest_sync_time,
     created_at, updated_at, created_by)
SELECT e.ext_api_id, 'A', 'N', v.stat_title, v.stat_tbl_id, 'Y',
       '', 'https://infuser.odcloud.kr/oas/docs?namespace=' || v.data_id || '/v1', null, null,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SYS-MANUAL'
  FROM public.sys_ext_api_info e
 CROSS JOIN (VALUES
    ('emp_dis_jobseeker_status',       '15014774', '한국장애인고용공단_장애인 구직자 현황'),
    ('emp_dis_job_posting',            '3072637',  '한국장애인고용공단_장애인 구인 정보'),
    ('emp_dis_center_usage',           '15118552', '한국장애인고용공단_발달장애인훈련센터 이용자현황'),
    ('emp_dis_obligation_status',      '15014785', '한국장애인고용공단_장애인 고용의무 현황 통계'),
    ('emp_dis_consulting_his',         '15014777', '한국장애인고용공단_장애인 고용컨설팅'),
    ('emp_dis_burden_workplace',       '15067959', '한국장애인고용공단_장애인고용 부담금감면 연계고용사업장 정보'),
    ('emp_dis_regional_status',        '15080750', '한국장애인고용공단_지역별 장애인 고용 현황'),
    ('emp_dis_staff_train_crs',        '15004132', '한국장애인고용공단_장애인고용 전문인력 양성교육정보'),
    ('emp_dis_dev_support_org',        '15072489', '한국장애인개발원_발달장애인 지원 기관 및 제공서비스'),
    ('emp_dis_startup_lecture',        '15035266', '(재)장애인기업종합지원센터 창업넷 일반강좌 정보'),
    ('emp_dis_std_workplace',          '3033670',  '한국장애인고용공단_장애인 표준사업장 현황'),
    ('emp_dis_emp_incentive',          '15121124', '한국장애인고용공단_신규고용장려금 지역별 지급 현황'),
    ('emp_dis_obligation_by_indust',   '15131080', '한국장애인고용공단_산업별 의무고용 현황'),
    ('emp_dis_obligation_fulfillment', '15028087', '고용노동부_장애인 의무고용 현황')
 ) AS v(stat_tbl_id, data_id, stat_title)
 WHERE e.ext_sys = 'ODCLOUD_EMP' AND e.del_yn = 'N'
   AND NOT EXISTS (
       SELECT 1 FROM public.sys_stats_src_api_info s
        WHERE s.ext_api_id = e.ext_api_id AND s.stat_tbl_id = v.stat_tbl_id
   );

COMMIT;
