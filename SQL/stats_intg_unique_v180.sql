-- ============================================================================
-- 통합 통계 테이블 중복 방지 — 중복 행 정리 + 자연키 UNIQUE 인덱스 (v1.8.0)
--
-- 대상: KOSIS 통합 통계 테이블 24종(stats_dis_*). 목록은 아래 배열에 명시한다.
--
-- 배경
--   통합 테이블에는 PK(id) 외에 유일성 제약이 없다. 적재 배치가 같은 통계를 다시 이관할 때
--   기존 행을 지우지 못하면 같은 내용의 행이 2벌 이상 쌓이고, DB 는 이를 막지 못한다.
--   적재 코드(08-IITP-DABT-PreProcessing)는 "통계(src_data_id) 단위로 전부 지우고 다시 넣는"
--   방식이라 이 인덱스 없이도 1벌을 유지하지만, 다른 경로(수작업 INSERT, 구버전 배치)로
--   중복이 들어오는 것을 DB 수준에서 거부하기 위해 UNIQUE 인덱스를 둔다.
--
-- 하는 일 (테이블마다, 전체가 한 트랜잭션)
--   [0] 사전 검사 2종 — 하나라도 걸리면 예외로 중단하고 아무것도 바꾸지 않는다.
--       (a) 원본(stats_kosis_origin_data)에서 해당 통계가 4번째 분류(c4)를 쓰는지.
--           통합 테이블에는 c4 컬럼이 없어, c4 만 다른 행은 통합 테이블에서 키가 같아진다.
--           그런 통계에 UNIQUE 를 걸면 정상 데이터가 적재 때마다 거부된다.
--       (b) 키는 같은데 값(dt·unit_nm·lst_chn_de)이 다른 행이 있는지.
--           단순 중복이 아니므로 어느 행을 남길지 자동으로 정하지 않는다.
--           자료갱신일(src_latest_chn_dt)이 서로 달라도 값이 다르면 중단한다 — 갱신일이 늦은 쪽이
--           맞는 값일 가능성이 높지만, 이 스크립트가 값을 골라 지우지는 않는다. 이 경우에는
--           적재 배치를 먼저 실행해 통계별 최신 1벌로 만든 뒤 다시 적용한다.
--   [1] 중복 행 정리 — 키가 같은 행(위 검사로 값도 같음이 보장됨) 중 1행만 남긴다.
--       남기는 행: 자료갱신일이 가장 늦은 행, 갱신일이 같으면(또는 둘 다 NULL) id 가 가장 큰 행.
--       갱신일이 NULL 인 행은 가장 오래된 것으로 본다. 값이 같으므로 어느 행을 남겨도 수치는
--       같고, 갱신일 표기만 최신 것이 남는다.
--   [2] UNIQUE 인덱스 생성 — 키:
--         (src_data_id, prd_de, c1, COALESCE(c2,''), COALESCE(c3,''), itm_id)
--       · 자료갱신일(src_latest_chn_dt)은 키에 넣지 않는다. 통합 테이블은 통계별 최신 1벌만
--         보관하므로 같은 (통계, 시점, 분류, 항목)의 행은 갱신일과 무관하게 1행이어야 한다.
--         갱신일을 키에 넣으면 갱신일만 다른 같은 자료가 2벌로 공존하는 것을 막지 못한다.
--       · c2·c3 는 NULL 허용 컬럼이다. UNIQUE 는 NULL 을 서로 다른 값으로 취급하므로 그대로
--         두면 NULL 이 들어간 행은 중복이 걸러지지 않는다. COALESCE 표현식으로 NULL 을 ''
--         에 대응시킨다(NULLS NOT DISTINCT 는 PostgreSQL 15 이상에서만 쓸 수 있어 버전에
--         의존하지 않는 표현식 인덱스를 택했다).
--       · 적재 코드는 c2·c3 가 없을 때 빈 문자열('')을 넣는다. NULL 과 '' 를 같은 값으로 본다.
--   [3] src_data_id 조회용 인덱스 — 따로 만들지 않는다. [2]의 인덱스가 src_data_id 를 선두
--       컬럼으로 가지므로 적재 코드의 "DELETE ... WHERE src_data_id = ?" 가 이 인덱스를 쓴다.
--       같은 선두 컬럼의 인덱스를 하나 더 두면 쓰기 비용만 늘어난다.
--
-- 재실행 안전: [1]은 중복이 없으면 0행 삭제, [2]는 IF NOT EXISTS.
--
-- 적용 전 확인(읽기 전용, 운영 DB 에서 먼저 실행해 볼 것)
--   -- c4 를 쓰는 통계가 있는가 (0행이어야 한다)
--   SELECT src_data_id, tbl_id, count(*) FROM stats_kosis_origin_data
--    WHERE COALESCE(c4, '') <> '' GROUP BY 1, 2;
--   -- 테이블별 중복 규모 (예: stats_dis_reg_natl_by_new)
--   SELECT count(*) AS total,
--          count(*) - count(DISTINCT (src_data_id, prd_de, c1, COALESCE(c2,''), COALESCE(c3,''), itm_id)) AS extra
--     FROM stats_dis_reg_natl_by_new;
--
-- 권장 순서: 적재 배치(08)를 새 버전으로 한 번 정상 실행해 통계별 1벌로 만든 뒤 이 스크립트를
--   적용한다. 그러면 [1]에서 지울 행이 없거나 적고, [0](b) 에 걸릴 가능성도 낮다.
--   실행 전 백업: pg_dump -U <user> -d <db> -t 'stats_dis_*' --data-only -f stats_dis_backup.sql
-- ============================================================================

BEGIN;

DO $$
DECLARE
    t         text;
    n_c4      bigint;
    n_diff    bigint;
    n_deleted bigint;
    tables    text[] := ARRAY[
        'stats_dis_reg_natl_by_new',
        'stats_dis_reg_natl_by_age_type_sev_gen',
        'stats_dis_reg_sido_by_type_sev_gen',
        'stats_dis_life_supp_need_lvl',
        'stats_dis_life_maincarer',
        'stats_dis_life_primcarer',
        'stats_dis_life_supp_field',
        'stats_dis_hlth_medical_usage',
        'stats_dis_hlth_disease_cost_sub',
        'stats_dis_hlth_sport_exec_type',
        'stats_dis_hlth_exrc_best_aid',
        'stats_dis_aid_device_usage',
        'stats_dis_aid_device_need',
        'stats_dis_edu_voca_exec',
        'stats_dis_edu_voca_exec_way',
        'stats_dis_emp_natl',
        'stats_dis_emp_natl_public',
        'stats_dis_emp_natl_private',
        'stats_dis_emp_natl_gov_org',
        'stats_dis_emp_natl_dis_type_sev',
        'stats_dis_emp_natl_dis_type_indust',
        'stats_dis_soc_partic_freq',
        'stats_dis_soc_contact_cntfreq',
        'stats_dis_fclty_welfare_usage'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP

        -- [0](a) 이 통합 테이블에 들어 있는 통계가 원본에서 c4 를 쓰는지 검사
        EXECUTE format(
            'SELECT count(*) FROM public.stats_kosis_origin_data o '
            ' WHERE COALESCE(o.c4, '''') <> '''' '
            '   AND o.src_data_id IN (SELECT DISTINCT src_data_id FROM public.%I)', t)
           INTO n_c4;
        IF n_c4 > 0 THEN
            RAISE EXCEPTION '%: 원본 데이터에 c4 분류를 가진 행이 % 건 있다. 통합 테이블에는 c4 가 없어 키가 겹치므로 UNIQUE 인덱스를 걸 수 없다. 전체 작업을 중단한다.', t, n_c4;
        END IF;

        -- [0](b) 키는 같고 값이 다른 그룹 수 (자료갱신일이 같든 다르든 값이 다르면 중단)
        --     lst_chn_de 의 DATE '0001-01-01' 은 NULL 끼리를 같은 값으로 세기 위한 대역이다
        --     (실제 수정일로 나올 수 없는 값).
        EXECUTE format(
            'SELECT count(*) FROM ('
            '  SELECT 1 FROM public.%I '
            '   GROUP BY src_data_id, prd_de, c1, COALESCE(c2, ''''), COALESCE(c3, ''''), itm_id '
            '  HAVING count(DISTINCT (dt::text, COALESCE(unit_nm, ''''), COALESCE(lst_chn_de, DATE ''0001-01-01''))) > 1'
            ') g', t)
           INTO n_diff;
        IF n_diff > 0 THEN
            RAISE EXCEPTION '%: 키가 같고 값(dt·unit_nm·lst_chn_de)이 다른 그룹이 % 개 있다. 남길 행을 자동으로 정할 수 없어 전체 작업을 중단한다.', t, n_diff;
        END IF;

        -- [1] 중복 정리 — 같은 키(위 검사로 값도 같음이 보장됨) 안에서 1행만 남긴다.
        --     정렬: 자료갱신일 내림차순(NULL 은 맨 뒤 = 가장 오래된 것으로 취급) → id 내림차순.
        --     즉 갱신일이 가장 늦은 행, 같으면 가장 나중에 들어온 행이 rn = 1 로 남는다.
        --     PARTITION BY 는 인덱스 키와 같은 COALESCE 표현식을 쓴다(NULL 과 '' 를 같은 값으로).
        EXECUTE format(
            'DELETE FROM public.%I WHERE id IN ('
            '  SELECT id FROM ('
            '    SELECT id, row_number() OVER ('
            '             PARTITION BY src_data_id, prd_de, c1, COALESCE(c2, ''''), COALESCE(c3, ''''), itm_id '
            '             ORDER BY src_latest_chn_dt DESC NULLS LAST, id DESC) AS rn '
            '      FROM public.%I'
            '  ) x WHERE x.rn > 1'
            ')', t, t);
        GET DIAGNOSTICS n_deleted = ROW_COUNT;
        RAISE NOTICE '%: 중복 행 % 건 삭제', t, n_deleted;

        -- [2] UNIQUE 인덱스. 이름 규칙: uidx_<테이블명에서 stats_ 를 st_ 로 줄인 것>_key
        --     (기존 인덱스 idx_st_..._year_c1t3 와 같은 축약 규칙, 최장 44자로 63자 제한 안쪽)
        EXECUTE format(
            'CREATE UNIQUE INDEX IF NOT EXISTS %I ON public.%I USING btree '
            '(src_data_id, prd_de, c1, COALESCE(c2, ''''), COALESCE(c3, ''''), itm_id)',
            'uidx_' || replace(t, 'stats_', 'st_') || '_key', t
        );
    END LOOP;
END
$$;

COMMIT;

-- ── 검증 ────────────────────────────────────────────────────────────────────
-- 24행이 나와야 한다(테이블마다 UNIQUE 인덱스 1개).
SELECT tablename, indexname
  FROM pg_indexes
 WHERE schemaname = 'public' AND indexname LIKE 'uidx\_st\_dis\_%\_key'
 ORDER BY tablename;
