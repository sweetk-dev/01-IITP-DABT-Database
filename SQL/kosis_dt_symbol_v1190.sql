-- ============================================================================
-- 통계 수치 칸(dt)의 원천 기호 보존 — dt_symbol 칸 추가 (v1.19.0, 2026-11-13)
--
-- 배경
--   KOSIS 응답의 수치(DT)는 숫자가 아닌 기호로 오는 칸이 있다(예: '-').
--   지금까지 08 적재기는 '-'·빈 값을 0 으로 바꿔 통합 테이블에 넣었다.
--   그 결과 "0%" 와 "해당 없음(그 해 조사에 없던 응답 항목, 응답자가 없는 칸 등)" 이 같은 0 으로 섞였고,
--   평균 점수 표에서는 '-' 가 0점이 되었다. 2026-11-13 기준 운영 DB 에서 12개 통합 테이블,
--   1,437행이 이렇게 0 으로 들어가 있었다(원본 stats_kosis_origin_data 에는 '-' 그대로 남아 있다).
--   또 '-'·빈 값 외의 기호(x·… 등)가 오면 숫자 변환에 실패해 그 통계 적재 전체가 실패했다.
--
-- 이 스크립트가 하는 일 (숫자형 dt 를 가진 stats_* 통합 테이블 전부 — 2026-11-13 운영 기준 48개)
--   1) dt_symbol varchar(10) 칸 추가 — 원천 수치가 숫자가 아닐 때 그 원래 표기(예: '-')
--   2) dt 의 NOT NULL 해제 — 원천이 기호인 칸은 dt 를 비운다(0 으로 바꾸지 않는다)
--   3) CHECK 제약 ck_<테이블>_dt_value — dt 와 dt_symbol 중 정확히 하나만 값이 있어야 한다
--        · 숫자 행: dt = 숫자, dt_symbol = NULL
--        · 기호 행: dt = NULL,  dt_symbol = 원래 표기(빈 값이었으면 '')
--   4) 두 칸의 설명(COMMENT)
--
--   대상은 information_schema 에서 찾는다: public 스키마, 이름이 stats_ 로 시작, dt 가 numeric,
--   백업 사본(*_bak_*)은 제외. 문자형 dt 를 쓰는 stats_dis_hlth_disease_cost_sub(다빈도 상병 순위 —
--   값 자체가 질병코드·질병명)와 원본 stats_kosis_origin_data 는 대상이 아니다.
--   공개 API(09)가 숫자형 통계 테이블을 공통 엔티티로 읽으므로, 기호가 실제로 나온 테이블만이 아니라
--   숫자형 dt 테이블 전부에 같은 칸을 둔다.
--
-- 기존 행
--   이 스크립트는 데이터를 바꾸지 않는다. 이미 0 으로 들어간 행은 08 v1.26.0 적재기를 반영한 뒤
--   KOSIS 정기 배치와 같은 명령을 한 번 돌리면 원본에서 다시 옮겨지며 dt=NULL, dt_symbol='-' 로 바뀐다
--   (08 KOSIS 적재는 통계마다 통합 행을 지우고 원본에서 다시 넣는다).
--
-- 적용 순서
--   운영 DB: 08 v1.26.0 반영 전에 적용한다(새 적재기는 dt_symbol 칸에 쓴다).
--            이 스크립트만 적용하고 08 을 그대로 두어도 기존 적재기는 dt_symbol 을 비운 채 숫자만 넣으므로
--            CHECK 를 통과한다(동작 변화 없음).
--   새로 구축: basic init 과 v1.14.0·v1.15.0·v1.16.0 스크립트에는 칸 정의(dt NULL 허용·dt_symbol)가
--            이미 들어 있다. CHECK 제약과 설명은 이 스크립트가 넣으므로 그 뒤에 한 번 실행한다.
--
-- 모두 IF NOT EXISTS·존재 확인 뒤 추가라 재실행해도 결과가 같다.
-- ============================================================================

BEGIN;

DO $$
DECLARE
    t      text;
    ck     text;
    n_tbl  int := 0;
BEGIN
    FOR t IN
        SELECT c.table_name
          FROM information_schema.columns c
          JOIN information_schema.tables tb
            ON tb.table_schema = c.table_schema AND tb.table_name = c.table_name
         WHERE c.table_schema = 'public'
           AND tb.table_type = 'BASE TABLE'
           AND c.table_name LIKE 'stats\_%'
           AND c.table_name NOT LIKE '%\_bak\_%'
           AND c.column_name = 'dt'
           AND c.data_type = 'numeric'
         ORDER BY c.table_name
    LOOP
        -- 1) 기호 칸
        EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS dt_symbol varchar(10) NULL', t);
        -- 2) 원천이 기호인 칸은 dt 를 비우므로 NOT NULL 해제
        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN dt DROP NOT NULL', t);
        -- 3) dt 와 dt_symbol 중 정확히 하나 — 제약 이름은 63자 이내로 자른다
        ck := left('ck_' || t || '_dt_value', 63);
        IF NOT EXISTS (SELECT 1 FROM pg_constraint
                        WHERE conname = ck AND conrelid = format('public.%I', t)::regclass) THEN
            EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I CHECK ((dt IS NULL) <> (dt_symbol IS NULL))',
                           t, ck);
        END IF;
        -- 4) 설명
        EXECUTE format('COMMENT ON COLUMN public.%I.dt IS %L', t,
                       '수치 값 — 원천 값이 숫자가 아니면 NULL(원래 표기는 dt_symbol)');
        EXECUTE format('COMMENT ON COLUMN public.%I.dt_symbol IS %L', t,
                       '원천 수치가 숫자가 아닐 때 그 원래 표기(예: ''-''). 숫자 행은 NULL — dt 와 둘 중 하나만 값이 있다');
        n_tbl := n_tbl + 1;
    END LOOP;
    RAISE NOTICE 'dt_symbol 적용 테이블 수: %', n_tbl;
END $$;

COMMIT;

-- 확인용(실행 결과 비교): 숫자형 dt 통계 테이블과 dt_symbol 칸·제약이 있는 테이블 수가 같아야 한다.
-- SELECT count(*) FILTER (WHERE c.column_name = 'dt')        AS numeric_dt_tables,
--        count(*) FILTER (WHERE c.column_name = 'dt_symbol') AS dt_symbol_tables
--   FROM information_schema.columns c
--  WHERE c.table_schema = 'public' AND c.table_name LIKE 'stats\_%' AND c.table_name NOT LIKE '%\_bak\_%'
--    AND ((c.column_name = 'dt' AND c.data_type = 'numeric') OR c.column_name = 'dt_symbol');
