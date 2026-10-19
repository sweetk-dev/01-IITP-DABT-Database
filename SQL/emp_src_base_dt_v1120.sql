-- ============================================================================
-- 장애인 고용 파일데이터 — 판(edition) 기준일 칸 추가 (v1.12.0, 2026-10-16)
--
-- 배경
--   v1.11.0 의 정기 수집(08 ODCLOUD_EMP v1.19.0)은 연도 칸이 없는 표를 새 판으로 통째로 바꿨다.
--   그러면 지난 판(예: 2024년 구직자 현황)이 사라진다. 지난 판을 남겨 두기로 하면서, 연도 칸이 없는
--   표에도 "이 행이 어느 판에서 왔는가" 를 적을 칸이 필요해졌다.
--   (표준사업장의 인증일자처럼 날짜 칸이 있어도 그것은 판 구분이 아니다.)
--
-- 이 스크립트가 하는 일
--   1) 수집 대상 14개 표에 src_base_dt date 칸 추가
--        = 원천 판 기준일 — 이 행을 넣은 공공데이터포털 파일데이터 판의 기준일(판 이름 끝 _YYYYMMDD)
--      08 v1.20.0 부터 적재기가 모든 행에 채운다.
--        · 연도 칸이 없는 9개 표: 같은 기준일의 행만 지우고 다시 넣는다(다른 판의 행은 보존).
--        · 연도 칸이 있는 5개 표: 지금처럼 판에 실린 연도만 교체하고, 넣는 행에 그 판의 기준일을 적는다.
--      emp_dis_obligation_by_type(1회성 데이터, 수집 대상 아님)에는 추가하지 않는다.
--   2) 연도 칸이 없는 9개 표에 src_base_dt 인덱스 — 적재기가 판 단위로 지우고 세며, 조회하는 쪽도
--      "가장 최근 판" 으로 거르는 일이 많다. 연도 표 5개는 연도 인덱스로 충분해 만들지 않는다.
--
-- 기존 행
--   이 스크립트는 데이터를 채우지 않는다(칸은 NULL 로 생긴다). 이미 들어 있는 행의 판 기준일은
--   운영 환경별로 다르므로, 필요하면 운영자가 별도 절차로 채운다.
--   08 적재기는 기준일이 NULL 인 행을 "판을 모르는 옛 행" 으로 보고 지우지 않는다.
--
-- 모두 IF NOT EXISTS 라 재실행해도 결과가 같다. 08 v1.20.0 배포 전에 적용한다
-- (적용 전 v1.20.0 적재기는 표 정의 검사에서 'src_base_dt 칸 없음' 으로 그 표를 실패시킨다).
-- ============================================================================

BEGIN;

-- 1) 칸 추가 + 설명 ------------------------------------------------------------
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        -- 연도 칸이 없는 9개 표(판 단위 교체)
        'emp_dis_jobseeker_status', 'emp_dis_job_posting', 'emp_dis_center_usage',
        'emp_dis_obligation_status', 'emp_dis_consulting_his', 'emp_dis_staff_train_crs',
        'emp_dis_dev_support_org', 'emp_dis_std_workplace', 'emp_dis_emp_incentive',
        -- 연도 칸이 있는 5개 표(연도 단위 교체)
        'emp_dis_burden_workplace', 'emp_dis_regional_status', 'emp_dis_startup_lecture',
        'emp_dis_obligation_by_indust', 'emp_dis_obligation_fulfillment'
    ] LOOP
        EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS src_base_dt date NULL', t);
        EXECUTE format('COMMENT ON COLUMN public.%I.src_base_dt IS %L', t,
                       '원천 판 기준일 — 이 행을 넣은 공공데이터포털 파일데이터 판의 기준일');
    END LOOP;
END $$;

-- 2) 판 단위 교체 표의 인덱스 ---------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_emp_dis_jobseeker_status_src_base_dt  ON public.emp_dis_jobseeker_status  USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_job_posting_src_base_dt       ON public.emp_dis_job_posting       USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_center_usage_src_base_dt      ON public.emp_dis_center_usage      USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_obligation_status_src_base_dt ON public.emp_dis_obligation_status USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_consulting_his_src_base_dt    ON public.emp_dis_consulting_his    USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_staff_train_crs_src_base_dt   ON public.emp_dis_staff_train_crs   USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_dev_support_org_src_base_dt   ON public.emp_dis_dev_support_org   USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_std_workplace_src_base_dt     ON public.emp_dis_std_workplace     USING btree (src_base_dt);
CREATE INDEX IF NOT EXISTS idx_emp_dis_emp_incentive_src_base_dt     ON public.emp_dis_emp_incentive     USING btree (src_base_dt);

COMMIT;
