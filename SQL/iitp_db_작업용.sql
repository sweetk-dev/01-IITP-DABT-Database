
-- ################################################
-- ## 작업용 SQL 문 또는 함수 생성 용 
-- ## Only for PostgreSQL
-- ## ver 0.0.1 last update data : 2025.05.21
-- ################################################


-- ################################################
-- ## data 삭제  -
-- ################################################
truncate table stats_kosis_origin_data


-- ################################################
-- ## 중복 데이터 제거 
-- ################################################
select distinct sdrnbn.src_latest_chn_dt from stats_dis_reg_natl_by_new sdrnbn 




-- ################################################
-- ## 시퀀스 조회 및 리셋 함수 사용 
-- ################################################
SELECT * FROM get_column_sequence_value('public', 'stats_kosis_origin_data', 'id');

SELECT * FROM get_column_sequence_value('public', 'mv_poi', 'poi_id');
SELECT * FROM get_sequences_in_schema('public');

SELECT * FROM reset_sequences_in_table('my_schema', 'my_table');




-- ################################################
-- ### 특정 테이블의 시퀀스 초기화 함수 생성 
-- ### 사용예) SELECT * FROM reset_sequences_in_table('my_schema', 'my_table');
-- ################################################
DROP FUNCTION IF EXISTS reset_sequences_in_table(text, text);
CREATE OR REPLACE FUNCTION reset_sequences_in_table(
    p_schema_name text,
    p_table_name text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    rec record;
    current_val bigint;
BEGIN
    FOR rec IN
        SELECT 
            n.nspname AS schema_name,
            t.relname AS table_name,
            a.attname AS column_name,
            s.relname AS seq_name
        FROM 
            pg_class t
        JOIN 
            pg_attribute a ON t.oid = a.attrelid
        JOIN 
            pg_depend d ON d.refobjid = t.oid AND d.refobjsubid = a.attnum
        JOIN 
            pg_class s ON s.oid = d.objid AND s.relkind = 'S'
        JOIN 
            pg_namespace n ON n.oid = t.relnamespace
        WHERE 
            n.nspname = p_schema_name
            AND t.relkind = 'r'
            AND t.relname = p_table_name
    LOOP
        BEGIN
            EXECUTE format('SELECT last_value FROM %I.%I', rec.schema_name, rec.seq_name) INTO current_val;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '시퀀스 % 불러오기 실패. 건너뜁니다.', rec.seq_name;
            CONTINUE;
        END;

        IF current_val > 1 THEN
            RAISE NOTICE '시퀀스 % 현재 값이 %입니다. 초기화합니다.', rec.seq_name, current_val;
            EXECUTE format('SELECT setval(%L, 1, false)', rec.schema_name || '.' || rec.seq_name);
        ELSE
            RAISE NOTICE '시퀀스 % 현재 값이 1 이하입니다. 초기화하지 않습니다.', rec.seq_name;
        END IF;
    END LOOP;
END;
$$;







-- ################################################
-- ### schema의 모든 시퀀스 현재 값 조회 함수 생성 
-- ### 사용예) SELECT * FROM get_sequences_in_schema('my_schema');
-- ### is_called = true → last_value는 실제로 사용된 값
-- ### is_called = false → last_value는 아직 사용되지 않았고 다음 값으로 반환 예정
-- ################################################
DROP FUNCTION IF EXISTS get_sequences_in_schema(text);
CREATE OR REPLACE FUNCTION get_sequences_in_schema(p_schema_name text)
RETURNS TABLE (
    schema_name text,
    table_name text,
    column_name text,
    sequence_name text,
    last_value bigint,
    is_called boolean
) AS $$
DECLARE
    rec RECORD;
    seq_full_name text;
    seq_last_value bigint;
    seq_is_called boolean;
BEGIN
    FOR rec IN
        SELECT
            n.nspname AS schema_name,
            t.relname AS table_name,
            a.attname AS column_name,
            pg_get_serial_sequence(format('%I.%I', n.nspname, t.relname), a.attname) AS sequence_name
        FROM
            pg_class t
            JOIN pg_namespace n ON t.relnamespace = n.oid
            JOIN pg_attribute a ON a.attrelid = t.oid
        WHERE
            n.nspname = p_schema_name
            AND a.attnum > 0
            AND NOT a.attisdropped
            AND pg_get_serial_sequence(format('%I.%I', n.nspname, t.relname), a.attname) IS NOT NULL
    LOOP
        seq_full_name := rec.sequence_name;

        -- 동적 쿼리로 last_value, is_called 추출 시도
        BEGIN
            EXECUTE format('SELECT last_value, is_called FROM %s', seq_full_name)
            INTO seq_last_value, seq_is_called;
        EXCEPTION WHEN OTHERS THEN
            seq_last_value := NULL;
            seq_is_called := NULL;
        END;

        schema_name := rec.schema_name;
        table_name := rec.table_name;
        column_name := rec.column_name;
        sequence_name := seq_full_name;
        last_value := seq_last_value;
        is_called := seq_is_called;

        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;









-- ################################################
-- ### 특정 테이블명으로 시퀀스 현재 값 조회 함수 생성 
-- ### 사용예) SELECT * FROM get_column_sequence_value('my_schema', 'my_table', 'column');
-- ### is_called = true → last_value는 실제로 사용된 값
-- ### is_called = false → last_value는 아직 사용되지 않았고 다음 값으로 반환 예정
-- ################################################
DROP FUNCTION IF EXISTS get_column_sequence_value(text, text, text);
CREATE OR REPLACE FUNCTION get_column_sequence_value(
    p_schema_name text,
    p_table_name text,
    p_column_name text
)
RETURNS TABLE (
    sequence_name text,
    last_value text,
    is_called text
) AS $$
DECLARE
    seq_full_name text;
    tbl_exists boolean;
    col_exists boolean;
    quoted_table text;
    quoted_column text;
BEGIN
    -- 테이블 존재 여부 확인
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = p_schema_name
          AND table_name = p_table_name
    ) INTO tbl_exists;

    IF NOT tbl_exists THEN
        RAISE EXCEPTION 'Table %.% does not exist', p_schema_name, p_table_name;
    END IF;

    -- 컬럼 존재 여부 확인
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = p_schema_name
          AND table_name = p_table_name
          AND column_name = p_column_name
    ) INTO col_exists;

    IF NOT col_exists THEN
        RAISE EXCEPTION 'Column %.%.% does not exist', p_schema_name, p_table_name, p_column_name;
    END IF;

    -- 테이블과 컬럼을 정규화 (따옴표 이슈 방지)
    quoted_table := format('%I.%I', p_schema_name, p_table_name);
    quoted_column := format('%I', p_column_name);

    -- 시퀀스 이름을 pg_get_serial_sequence 로 확인 (serial + identity 모두 대응)
    EXECUTE format(
        'SELECT pg_get_serial_sequence(%L, %L)',
        quoted_table,
        p_column_name
    ) INTO seq_full_name;

    -- 시퀀스가 없으면 N/A 반환
    IF seq_full_name IS NULL THEN
        RETURN QUERY SELECT 'N/A', 'N/A', 'N/A';
        RETURN;
    END IF;

    -- 시퀀스 값 조회
    RETURN QUERY EXECUTE format(
        'SELECT %L, last_value::text, is_called::text FROM %s',
        seq_full_name,
        seq_full_name
    );
END;
$$ LANGUAGE plpgsql;






-- ################################################
-- ### 현재 시퀀스 값 조회
-- ################################################

DO $$
DECLARE
    rec RECORD;
    current_val bigint;
BEGIN
    FOR rec IN
        SELECT n.nspname AS schema_name, c.relname AS sequence_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'S'
          AND n.nspname = 'public'  -- 스키마명 변경 가능
        ORDER BY sequence_name
    LOOP
        BEGIN
            EXECUTE format('SELECT last_value FROM %I.%I', rec.schema_name, rec.sequence_name) INTO current_val;
            RAISE INFO 'Sequence %.% current last_value = %', rec.schema_name, rec.sequence_name, current_val;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Sequence %.% 값을 조회하는 중 오류 발생: %', rec.schema_name, rec.sequence_name, SQLERRM;
        END;
    END LOOP;
END
$$;



-- ################################################
-- ### 현재 시퀀스 값 초기화 : 1보다 큰 경우에만 초기화
-- ### mv_poi 테이블 제외
-- ################################################

DO $$
DECLARE
    rec record;
    current_val bigint;
BEGIN
    FOR rec IN
        SELECT 
            n.nspname AS schema_name,
            t.relname AS table_name,
            a.attname AS column_name,
            s.relname AS seq_name
        FROM 
            pg_class t
        JOIN 
            pg_attribute a ON t.oid = a.attrelid
        JOIN 
            pg_depend d ON d.refobjid = t.oid AND d.refobjsubid = a.attnum
        JOIN 
            pg_class s ON s.oid = d.objid AND s.relkind = 'S'
        JOIN 
            pg_namespace n ON n.oid = t.relnamespace
        WHERE 
            n.nspname = 'public'
            AND t.relkind = 'r'
            AND t.relname NOT IN ('mv_poi') -- 제외할 테이블 명시
    LOOP
        BEGIN
            EXECUTE format('SELECT last_value FROM %I.%I', 'public', rec.seq_name) INTO current_val;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '시퀀스 % 불러오기 실패. 건너뜁니다.', rec.seq_name;
            CONTINUE;
        END;

        IF current_val > 1 THEN
            RAISE NOTICE '시퀀스 % 현재 값이 %입니다. 초기화합니다.', rec.seq_name, current_val;
            EXECUTE format('SELECT setval(%L, 1, false)', 'public.' || rec.seq_name);
        ELSE
            RAISE NOTICE '시퀀스 % 현재 값이 1 이하입니다. 초기화하지 않습니다.', rec.seq_name;
        END IF;
    END LOOP;
END
$$;



-- ################################################
-- ### 현재 시퀀스 값 초기화 : 1보다 큰 경우에만 초기화
-- ### mv_poi 테이블 제외
-- ################################################

DO $$
DECLARE
    rec record;
    current_val bigint;
BEGIN
    FOR rec IN
        SELECT 
            n.nspname AS schema_name,
            t.relname AS table_name,
            a.attname AS column_name,
            s.relname AS seq_name
        FROM 
            pg_class t
        JOIN 
            pg_attribute a ON t.oid = a.attrelid
        JOIN 
            pg_depend d ON d.refobjid = t.oid AND d.refobjsubid = a.attnum
        JOIN 
            pg_class s ON s.oid = d.objid AND s.relkind = 'S'
        JOIN 
            pg_namespace n ON n.oid = t.relnamespace
        WHERE 
            n.nspname = 'public'
            AND t.relkind = 'r'
            AND t.relname NOT IN ('mv_poi') -- 제외할 테이블 명시
    LOOP
        BEGIN
            EXECUTE format('SELECT last_value FROM %I.%I', 'public', rec.seq_name) INTO current_val;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '시퀀스 % 불러오기 실패. 건너뜁니다.', rec.seq_name;
            CONTINUE;
        END;

        IF current_val > 1 THEN
            RAISE NOTICE '시퀀스 % 현재 값이 %입니다. 초기화합니다.', rec.seq_name, current_val;
            EXECUTE format('SELECT setval(%L, 1, false)', 'public.' || rec.seq_name);
        ELSE
            RAISE NOTICE '시퀀스 % 현재 값이 1 이하입니다. 초기화하지 않습니다.', rec.seq_name;
        END IF;
    END LOOP;
END
$$;


-- ################################################
-- ## 고아 시퀀스 삭제 (더 이상 어떤 테이블 컬럼에도 연결되지 않은 시퀀스) 
-- ################################################

DO $$
DECLARE
    orphan_seq RECORD;
BEGIN
    FOR orphan_seq IN
        SELECT n.nspname AS schema_name,
               c.relname AS sequence_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'S' -- 시퀀스만
          AND NOT EXISTS (
              -- 직접적으로 OWNED BY 컬럼과 연결된 시퀀스는 제외
              SELECT 1
              FROM pg_depend d
              JOIN pg_attribute a ON d.refobjid = a.attrelid AND d.refobjsubid = a.attnum
              WHERE d.objid = c.oid
                AND d.classid = 'pg_class'::regclass
                AND d.refclassid = 'pg_class'::regclass
                AND (d.deptype = 'a' OR d.deptype = 'i')  -- 'a' 자동 의존성, 'i' 내부 의존성 포함
          )
          AND NOT EXISTS (
              -- identity 컬럼이 사용하는 시퀀스 제외
              SELECT 1
              FROM pg_attribute a
              JOIN pg_class t ON t.oid = a.attrelid
              WHERE a.attidentity IN ('a','d') -- 'a' = always identity, 'd' = default identity
                AND t.relkind = 'r'
                AND (SELECT pg_get_serial_sequence(t.relname, a.attname)) = n.nspname || '.' || c.relname
          )
    LOOP
        RAISE NOTICE '고아 시퀀스 발견: %.% - 삭제합니다.', orphan_seq.schema_name, orphan_seq.sequence_name;
        EXECUTE format('DROP SEQUENCE IF EXISTS %I.%I', orphan_seq.schema_name, orphan_seq.sequence_name);
    END LOOP;
END
$$;


-- ################################################
-- ## public(기본) schema 테이블 목록 조회 
-- ################################################
SELECT tablename FROM pg_catalog.pg_tables
where 1=1
and schemaname = 'public'

-- ################################################
-- ## trigger 함수 조회 - 생성결과 확인용
-- ################################################
SELECT proname, prosrc
FROM pg_proc
WHERE proname = 'update_modified_column';


-- ################################################
-- ## trigger 조회 - 생성결과 확인용
-- ################################################

SELECT 
  tgname AS trigger_name,
  relname AS table_name,
  pg_get_triggerdef(pg_trigger.oid, true) AS trigger_definition
FROM 
  pg_trigger
JOIN 
  pg_class ON pg_trigger.tgrelid = pg_class.oid
WHERE 
  NOT pg_trigger.tgisinternal
  AND tgname LIKE 'trg_update_%';


