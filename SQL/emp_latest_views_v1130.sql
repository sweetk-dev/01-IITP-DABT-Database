-- ============================================================================
-- 장애인 고용 파일데이터 — 최신 판 조회용 뷰 (v1.13.0, 2026-10-15)
--
-- 배경
--   v1.12.0 부터 연도 칸이 없는 9개 emp_dis_* 표는 원천 판을 쌓아 둔다(src_base_dt = 판 기준일).
--   분석 도구(Metabase) 질문처럼 하위 쿼리를 쓰기 어려운 조회는 표를 그대로 읽으면 여러 판이 섞여
--   건수·합계가 판 수만큼 늘어난다.
--
-- 이 스크립트가 하는 일
--   연도 칸이 없는 9개 표마다 "가장 최근 판의 행만" 보여 주는 뷰를 만든다.
--     v_<표 이름>_latest = 원본 표 전체 칸 + 조건 src_base_dt IS NOT DISTINCT FROM max(src_base_dt)
--   · 데이터를 따로 저장하지 않는다(일반 뷰). 새 판이 적재되면 바로 그 판을 보여 준다.
--   · IS NOT DISTINCT FROM: 판 기준일이 모두 비어 있는(NULL) DB 에서도 표 전체를 보여 준다.
--   · 연도 칸이 있는 5개 표는 판 하나가 한 해를 맡으므로 뷰를 만들지 않는다(연도로 거른다).
--
-- 주의
--   뷰의 칸 목록은 만들 때 고정된다. 원본 표에 칸을 추가하면 이 스크립트를 다시 실행해야 새 칸이
--   뷰에 나타난다(CREATE OR REPLACE VIEW 는 칸을 뒤에 덧붙이는 변경만 허용 — 칸을 지우거나 순서를
--   바꾼 경우에는 뷰를 지우고 다시 만든다).
--   재실행 안전. 01 v1.12.0(src_base_dt) 적용 뒤에 실행한다.
-- ============================================================================

BEGIN;

DO $$
DECLARE
    t text;
    tbls text[] := ARRAY[
        'emp_dis_jobseeker_status',   -- 장애인 구직자 현황
        'emp_dis_job_posting',        -- 장애인 구인 정보
        'emp_dis_center_usage',       -- 발달장애인훈련센터 이용자현황
        'emp_dis_obligation_status',  -- 장애인 고용의무 현황 통계
        'emp_dis_consulting_his',     -- 장애인 고용컨설팅
        'emp_dis_staff_train_crs',    -- 장애인고용 전문인력 양성교육정보
        'emp_dis_dev_support_org',    -- 발달장애인 지원 기관 및 제공서비스
        'emp_dis_std_workplace',      -- 장애인 표준사업장 현황
        'emp_dis_emp_incentive'       -- 신규고용장려금 지역별 지급 현황
    ];
BEGIN
    FOREACH t IN ARRAY tbls LOOP
        EXECUTE format(
            'CREATE OR REPLACE VIEW public.%1$I AS
               SELECT * FROM public.%2$I
                WHERE src_base_dt IS NOT DISTINCT FROM (SELECT max(src_base_dt) FROM public.%2$I)',
            'v_' || t || '_latest', t);
        EXECUTE format(
            'COMMENT ON VIEW public.%1$I IS %2$L',
            'v_' || t || '_latest',
            t || ' 의 가장 최근 원천 판(src_base_dt 최댓값) 행만 보여 주는 뷰 — 분석 도구 조회용');
    END LOOP;
END $$;

COMMIT;