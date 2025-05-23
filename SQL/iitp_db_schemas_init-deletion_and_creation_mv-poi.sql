-- ## iitp DB Schemas - MV-POI Initial setup - Creation and Delete if tables exists 
-- ## ver 0.0.2 last update data : 2025.05.21
-- ## Only for PostgreSQL


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
        WHERE c.relkind = 'S'  -- 시퀀스만
          AND NOT EXISTS (
              SELECT 1
              FROM pg_depend d
              WHERE d.objid = c.oid
                AND d.deptype = 'a'  -- 자동 의존성 (예: OWNED BY)
          )
    LOOP
        RAISE NOTICE '고아 시퀀스 발견: %.% - 삭제합니다.', orphan_seq.schema_name, orphan_seq.sequence_name;
        EXECUTE format('DROP SEQUENCE IF EXISTS %I.%I', orphan_seq.schema_name, orphan_seq.sequence_name);
    END LOOP;
END
$$;


-- public.mv_poi definition

-- Drop table
DROP TABLE IF EXISTS public.mv_poi;

CREATE TABLE public.mv_poi (
	poi_id bigserial NOT NULL,
	language_code varchar(10) NOT NULL,
	title varchar(200) NOT NULL,
	summary text NULL,
	basic_info text NULL,
	address_code varchar(10) NULL,
	address_road varchar(200) NULL,
	address_detail varchar(200) NULL,
	latitude numeric(10, 8) NULL,
	longitude numeric(11, 8) NULL,
	detail_json jsonb NULL,
	search_filter_json jsonb NULL,
	publish_date timestamp NULL,
	update_date timestamp NULL,
	create_date timestamp DEFAULT CURRENT_TIMESTAMP NULL,
	is_deleted bpchar(1) DEFAULT 'N'::bpchar NOT NULL,
	is_published bpchar(1) DEFAULT 'N'::bpchar NOT NULL,
	source_organization varchar(100) NULL,
	source_id varchar(50) NULL,
	CONSTRAINT poi_pkey PRIMARY KEY (poi_id)
);
CREATE INDEX idx_address_code ON public.mv_poi USING btree (address_code);
CREATE INDEX idx_language_code ON public.mv_poi USING btree (language_code);
CREATE INDEX idx_location ON public.mv_poi USING btree (latitude, longitude);
CREATE INDEX idx_publish_status ON public.mv_poi USING btree (is_published, is_deleted);
CREATE INDEX idx_search_filter_json_gin ON public.mv_poi USING gin (search_filter_json);
CREATE INDEX idx_search_filter_json_path ON public.mv_poi USING gin (((search_filter_json -> 'search_filter'::text)));