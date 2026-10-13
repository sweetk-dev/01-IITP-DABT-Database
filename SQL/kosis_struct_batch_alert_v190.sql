-- ============================================================================
-- KOSIS 통계표 구조 변경 대응 + 수집 배치 실행 기록·이상 알림 설정 (v1.9.0)
--
-- 배경
--   KOSIS 가 등록장애인 통계 3종(DT_11761_N007·N010·N008)과 장애인 사회참여 통계
--   (DT_438001_AC016)의 구조를 바꿨다. 예전에 "항목"이던 성별(T001 계·T002 남자·T003 여자)과
--   사회참여 활동(T001~T005)이 "분류"로 옮겨 가고, 항목은 T001(인원 등) 하나만 남았다.
--   예전 조회 주소는 분류 단계(objL)가 모자라 err=20 을 돌려받아 4종이 적재되지 않았다.
--
--   통합 통계 테이블(stats_dis_*)과 이를 읽는 쪽(공개 API·분석 대시보드)은 예전 형태
--   (성별·활동이 itm_id 칸)를 전제로 한다. 코드값이 신구 구조에서 같으므로, 새 구조로 받은 뒤
--   해당 분류를 itm_id 칸으로 되돌려 넣으면 통합 테이블 형태를 그대로 유지할 수 있다.
--   이 "통합 테이블 칸 배치 규칙"을 통계별로 적어 두는 칼럼이 intg_col_map 이다.
--
-- 하는 일 (전체가 한 트랜잭션, 재실행 안전)
--   [1] sys_stats_src_api_info.intg_col_map (jsonb, NULL 허용) 추가
--       NULL 이면 종전과 같다: c1←C1, c2←C2, c3←C3, itm_id←ITM_ID.
--       값이 있으면 적재 배치(08-IITP-DABT-PreProcessing)가 원본(stats_kosis_origin_data)에서
--       통합 테이블로 옮길 때 칸마다 어느 원본 칼럼을 쓸지 이 규칙을 따른다.
--         키   : 통합 테이블 칸 — "c1" | "c2" | "c3" | "itm_id"
--         값   : 원본 칼럼 — "C1" | "C2" | "C3" | "C4" | "ITM" | null(빈 값)
--         "item_obj": 메타데이터에서 "항목"으로 다룰 분류 객체 ID(OBJ_ID).
--                     이 객체의 행을 항목(obj_id='ITEM', obj_nm='항목')으로 바꾸고,
--                     원래의 항목 행은 버린다. itm_id 를 분류에서 가져올 때 함께 지정한다.
--         적지 않은 키는 종전 규칙을 따른다.
--   [2] 4종의 조회 주소(api_data_url)를 새 구조로 바꾸고 intg_col_map 을 채운다.
--       N010 은 예전과 같이 장애유형 6종·연령 6구간만 고른다(기존 데이터와 범위를 맞춘다).
--   [3] sys_batch_run_log 신설 — 수집 배치 1회 실행 = 1행 (성공·부분 실패·실패, 실패 통계·사유,
--       알림 발송 결과). 운영 콘솔이 최근 실행 상태를 보여 주고, 배치가 연속 실패 횟수와
--       복구 여부를 판단하는 데 쓴다.
--   [4] sys_ops_setting 신설 — 운영 설정 키/값. 이번에는 수집 이상 알림 설정 2개를 둔다.
--         batch_alert_enabled : 'Y' | 'N'
--         batch_alert_emails  : 수신 메일 주소(쉼표 구분, 최대 5개). 운영 콘솔에서 입력·수정한다.
--       주소 값은 이 스크립트에 넣지 않는다(빈 값으로 등록). 운영 콘솔 또는 운영자가 직접 넣는다.
--
-- 적용 순서 주의
--   [2]를 적용한 DB 에서 v1.17.0 이전의 적재 배치가 돌면, N007·AC016 은 intg_col_map 을 모른 채
--   새 구조 그대로 통합 테이블에 들어가고(성별이 c3, itm_id 는 T001 하나) N008·N010 은 4번째 분류가
--   버려져 실패한다. 08 v1.17.0 을 배포한 뒤, 또는 배치가 돌지 않는 시간에 적용한다.
--
-- 되돌리기
--   [2] 는 아래 "예전 주소" 주석의 값으로 되돌릴 수 있다. [1]·[3]·[4] 는 추가만 하므로
--   그대로 두어도 예전 배치 동작에 영향이 없다.
-- ============================================================================

BEGIN;

-- [1] 통합 테이블 칸 배치 규칙 -------------------------------------------------
ALTER TABLE public.sys_stats_src_api_info
    ADD COLUMN IF NOT EXISTS intg_col_map jsonb NULL;

-- 객체(JSON object)만 허용한다. 배열·문자열 같은 잘못된 값이 들어가는 것을 DB 에서 막는다.
-- 키·값의 세부 검사(허용 칼럼 이름 등)는 적재 배치가 실행 시점에 하고, 어긋나면 그 통계만 실패시킨다.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'chk_sys_st_src_api_info_intg_col_map'
           AND conrelid = 'public.sys_stats_src_api_info'::regclass
    ) THEN
        ALTER TABLE public.sys_stats_src_api_info
            ADD CONSTRAINT chk_sys_st_src_api_info_intg_col_map
            CHECK (intg_col_map IS NULL OR jsonb_typeof(intg_col_map) = 'object');
    END IF;
END $$;

COMMENT ON COLUMN public.sys_stats_src_api_info.intg_col_map IS
    '통합 테이블 칸 배치 규칙(jsonb, NULL=종전 규칙). 키 c1|c2|c3|itm_id → 원본 칼럼 C1~C4|ITM|null, '
    'item_obj=메타에서 항목으로 다룰 분류 OBJ_ID. 예: {"c3":null,"itm_id":"C3","item_obj":"D"}';

-- [2] KOSIS 구조 변경 4종 -------------------------------------------------------
-- 예전 주소(되돌릴 때 사용):
--   N010 : itmId=T001+T002+T003+&objL1=CHUT0+CHU01+CHU03+CHU041+CHU051+CHU06+&objL2=000+0201+0202+0203+0204+0205+&objL3=ALL&objL4=
--   N007 : itmId=T001+T002+T003+&objL1=ALL&objL2=ALL&objL3=
--   N008 : itmId=T001+T002+T003+&objL1=ALL&objL2=ALL&objL3=ALL&objL4=
--   AC016: itmId=T001+T002+T003+T004+T005+&objL1=ALL&objL2=

-- 신규등록 장애인현황: 장애유형(C1)·연령(C2)·장애정도(C3)·성별(C4) → 성별을 itm_id 로
UPDATE public.sys_stats_src_api_info
   SET api_data_url = '{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=CHUT0+CHU01+CHU03+CHU041+CHU051+CHU06+&objL2=000+0201+0202+0203+0204+0205+&objL3=ALL&objL4=ALL&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11761_N010","format":"json"}',
       intg_col_map = '{"itm_id":"C4","item_obj":"D"}'::jsonb,
       updated_at   = CURRENT_TIMESTAMP,
       updated_by   = 'SYS-MANUAL'
 WHERE stat_tbl_id = 'DT_11761_N010';

-- 전국 연령별·장애정도별·성별 등록장애인수: 연령(C1)·장애정도(C2)·성별(C3) → 성별을 itm_id 로, c3 는 비운다
UPDATE public.sys_stats_src_api_info
   SET api_data_url = '{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=ALL&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11761_N007","format":"json"}',
       intg_col_map = '{"c3":null,"itm_id":"C3","item_obj":"D"}'::jsonb,
       updated_at   = CURRENT_TIMESTAMP,
       updated_by   = 'SYS-MANUAL'
 WHERE stat_tbl_id = 'DT_11761_N007';

-- 시도별·장애유형별·장애정도별·성별 등록장애인수: 장애유형(C1)·시도(C2)·장애정도(C3)·성별(C4) → 성별을 itm_id 로
UPDATE public.sys_stats_src_api_info
   SET api_data_url = '{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=ALL&objL4=ALL&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11761_N008","format":"json"}',
       intg_col_map = '{"itm_id":"C4","item_obj":"D"}'::jsonb,
       updated_at   = CURRENT_TIMESTAMP,
       updated_by   = 'SYS-MANUAL'
 WHERE stat_tbl_id = 'DT_11761_N008';

-- 장애인의 사회 참여: 참여여부(C1)·사회참여활동(C2) → 활동을 itm_id 로, c2 는 비운다
UPDATE public.sys_stats_src_api_info
   SET api_data_url = '{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AC016","format":"json"}',
       intg_col_map = '{"c2":null,"c3":null,"itm_id":"C2","item_obj":"B"}'::jsonb,
       updated_at   = CURRENT_TIMESTAMP,
       updated_by   = 'SYS-MANUAL'
 WHERE stat_tbl_id = 'DT_438001_AC016';

-- [3] 수집 배치 실행 기록 -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sys_batch_run_log (
    run_id        bigint GENERATED BY DEFAULT AS IDENTITY NOT NULL, -- system id, 고유 식별자 (자동 증가)
    ext_sys       varchar(40) NOT NULL,      -- 외부 시스템 식별자 (KOSIS, GBIS, ...) — 같은 값끼리 연속 실패·복구를 판단한다
    run_mode      varchar(10) NULL,          -- 실행 모드 (file: 파일 저장만 / db: 적재까지)
    run_scope     varchar(10) NULL,          -- 수집 범위 (ALL / PARTIAL)
    started_at    timestamptz NOT NULL,      -- 시작 시각
    finished_at   timestamptz NULL,          -- 종료 시각
    exit_code     smallint NOT NULL,         -- 종료 코드 (0 성공 / 2 일부 실패 / 1 치명적 오류)
    status        varchar(10) NOT NULL,      -- SUCCESS | PARTIAL | ERROR
    targets       int DEFAULT 0 NOT NULL,    -- 대상 건수
    ok_cnt        int DEFAULT 0 NOT NULL,    -- 성공 건수 (db 모드는 적재 성공, file 모드는 수집 성공)
    fail_cnt      int DEFAULT 0 NOT NULL,    -- 실패 건수 (수집 실패 + 적재 실패)
    failures      jsonb NULL,                -- 실패 목록 [{"id":통계표ID,"stage":"collect|db","reason":사유}]
    error_summary varchar(1000) NULL,        -- 실패 요약 한 줄 (배치 전체 오류 포함)
    alert_status  varchar(10) NULL,          -- 알림 처리 결과: SENT | SKIP | FAIL | NONE
    alert_detail  varchar(500) NULL,         -- 알림 처리 상세 (발송 대상 수, 건너뛴 이유, 실패 사유)
    created_at    timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
    CONSTRAINT pkey_sys_batch_run_log PRIMARY KEY (run_id)
);
CREATE INDEX IF NOT EXISTS idx_sys_batch_run_log_sys_started
    ON public.sys_batch_run_log USING btree (ext_sys, started_at DESC);

COMMENT ON TABLE  public.sys_batch_run_log IS '데이터 수집 배치 실행 기록 (실행 1회 = 1행)';
COMMENT ON COLUMN public.sys_batch_run_log.run_id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.sys_batch_run_log.ext_sys IS '외부 시스템 식별자 (sys_ext_api_info.ext_sys)';
COMMENT ON COLUMN public.sys_batch_run_log.run_mode IS '실행 모드 (file / db)';
COMMENT ON COLUMN public.sys_batch_run_log.run_scope IS '수집 범위 (ALL / PARTIAL)';
COMMENT ON COLUMN public.sys_batch_run_log.started_at IS '시작 시각';
COMMENT ON COLUMN public.sys_batch_run_log.finished_at IS '종료 시각';
COMMENT ON COLUMN public.sys_batch_run_log.exit_code IS '종료 코드 (0 성공 / 2 일부 실패 / 1 치명적 오류)';
COMMENT ON COLUMN public.sys_batch_run_log.status IS 'SUCCESS | PARTIAL | ERROR';
COMMENT ON COLUMN public.sys_batch_run_log.targets IS '대상 건수';
COMMENT ON COLUMN public.sys_batch_run_log.ok_cnt IS '성공 건수';
COMMENT ON COLUMN public.sys_batch_run_log.fail_cnt IS '실패 건수 (수집 실패 + 적재 실패)';
COMMENT ON COLUMN public.sys_batch_run_log.failures IS '실패 목록 [{"id","stage","reason"}]';
COMMENT ON COLUMN public.sys_batch_run_log.error_summary IS '실패 요약 한 줄';
COMMENT ON COLUMN public.sys_batch_run_log.alert_status IS '알림 처리 결과 (SENT / SKIP / FAIL / NONE)';
COMMENT ON COLUMN public.sys_batch_run_log.alert_detail IS '알림 처리 상세';
COMMENT ON COLUMN public.sys_batch_run_log.created_at IS '레코드 생성 시각';

-- [4] 운영 설정 ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sys_ops_setting (
    setting_key   varchar(60) NOT NULL,               -- 설정 키
    setting_value varchar(1000) DEFAULT '' NOT NULL,  -- 설정 값
    description   varchar(300) NULL,                  -- 설정 설명
    updated_at    timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 마지막 수정 시각
    updated_by    varchar(40) NULL,                   -- 마지막 수정자
    CONSTRAINT pkey_sys_ops_setting PRIMARY KEY (setting_key)
);
COMMENT ON TABLE  public.sys_ops_setting IS '운영 설정 (키/값)';
COMMENT ON COLUMN public.sys_ops_setting.setting_key IS '설정 키';
COMMENT ON COLUMN public.sys_ops_setting.setting_value IS '설정 값';
COMMENT ON COLUMN public.sys_ops_setting.description IS '설정 설명';
COMMENT ON COLUMN public.sys_ops_setting.updated_at IS '마지막 수정 시각';
COMMENT ON COLUMN public.sys_ops_setting.updated_by IS '마지막 수정자';

-- 이미 있으면 값을 덮어쓰지 않는다(운영 중 입력한 수신 주소 보존).
INSERT INTO public.sys_ops_setting (setting_key, setting_value, description, updated_by) VALUES
    ('batch_alert_enabled', 'Y', '데이터 수집 이상 알림 메일 사용 여부 (Y/N)', 'SYS-MANUAL'),
    ('batch_alert_emails',  '',  '데이터 수집 이상 알림 수신 메일 주소 (쉼표 구분, 최대 5개)', 'SYS-MANUAL')
ON CONFLICT (setting_key) DO NOTHING;

COMMIT;
