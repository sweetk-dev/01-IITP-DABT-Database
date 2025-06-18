-- ## iitp DB Schemas - Initial setup - Creation and Delete if tables exists 
-- ## ver 0.0.7 last update data : 2025.06.18
-- ## Only for PostgreSQL
-- ## Except "mv_poi" table
-- ## Designing a Custom Database Schema for KOSIS OpenAPI Integration (KOSIS OpenAPI 연동 맞춤으로 DB DDL 설계)


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
-- ## 시스템 테이블 생성 
-- ################################################


-- #### 시스템 공통 코드 테이블 ####
-- # public.sys_common_code definition

-- Drop table

DROP TABLE IF EXISTS public.sys_common_code;

CREATE TABLE public.sys_common_code (
	grp_id varchar(40) NOT NULL, -- 코드 그룹 ID (예: GENDER, REGION)
	grp_nm varchar(80) NOT NULL, -- 코드 그룹 이름 (예: 성별, 지역)
	code_id varchar(32) NOT NULL, -- 코드 ID (예: M, F, 1000)
	code_nm varchar(64) NOT NULL, -- 코드 이름 (예: 남성, 여성, 컴퓨터)
	
	parent_grp_id varchar(40) NULL, -- 상위 그룹 ID (optional)
	parent_code_id varchar(40) NULL, -- 상위 코드 ID (optional) (동일 그룹 내 계층형 코드 구조)
	
	code_type bpchar(1) NOT NULL, -- 코드 타입 코드 타입: B(서비스용), A(관리자서비스용) S(시스템용)
	code_lvl int4 DEFAULT 1 NULL, -- 코드 계층 레벨
	sort_order int2 DEFAULT 0 NULL, -- 정렬 순서 (UI 정렬 등에 사용)
	use_yn bpchar(1) DEFAULT 'Y'::bpchar NULL, -- 사용 여부 (Y: 사용, N: 미사용)
	del_yn bpchar(1) DEFAULT 'N'::bpchar NULL, -- 삭제 여부: N(정상), Y(삭제)
	code_des varchar(255) NULL, -- 코드 설명
	memo varchar(255) NULL, -- 메모: 버전정등 기타 기록 정보
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 생성 시각 (UTC)
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 수정 시각 (UTC)
	deleted_at timestamp NULL, -- 삭제 일시 (논리 삭제 시 기록)
	created_by varchar(40) NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조
	updated_by varchar(40) NULL, -- 수정자 ID
	deleted_by varchar(40) NULL, -- 삭제 처리자 ID 또는 시스템
	CONSTRAINT pkey_sys_common_code PRIMARY KEY (grp_id, code_id)
);
CREATE INDEX idx_sys_common_code_grp_parent ON public.sys_common_code USING btree (grp_id, parent_code_id);
CREATE INDEX idx_sys_common_code_type_grp_sort ON public.sys_common_code USING btree (code_type, grp_id, code_lvl, sort_order);
COMMENT ON TABLE public.sys_common_code IS '시스템 공통 코드 테이블';

-- Column comments

COMMENT ON COLUMN public.sys_common_code.grp_id IS '코드 그룹 ID (예: GENDER, REGION)';
COMMENT ON COLUMN public.sys_common_code.grp_nm IS '코드 그룹 이름 (예: 성별, 지역)';
COMMENT ON COLUMN public.sys_common_code.parent_grp_id IS '상위 그룹 ID (optional)';
COMMENT ON COLUMN public.sys_common_code.code_id IS '코드 ID (예: M, F, 1000)';
COMMENT ON COLUMN public.sys_common_code.parent_code_id IS '상위 코드 ID (optional) (동일 그룹 내 계층형 코드 구조)';
COMMENT ON COLUMN public.sys_common_code.code_nm IS '코드 이름 (예: 남성, 여성, 컴퓨터)';
COMMENT ON COLUMN public.sys_common_code.code_type IS '코드 타입 코드 타입: B(서비스용), A(관리자서비스용) S(시스템용)';
COMMENT ON COLUMN public.sys_common_code.code_lvl IS '코드 계층 레벨';
COMMENT ON COLUMN public.sys_common_code.sort_order IS '정렬 순서 (UI 정렬 등에 사용)';
COMMENT ON COLUMN public.sys_common_code.use_yn IS '사용 여부 (Y: 사용, N: 미사용)';
COMMENT ON COLUMN public.sys_common_code.del_yn IS '삭제 여부: N(정상), Y(삭제)';
COMMENT ON COLUMN public.sys_common_code.code_des IS '코드 설명';
COMMENT ON COLUMN public.sys_common_code.memo IS '메모: 버전정등 기타 기록 정보';
COMMENT ON COLUMN public.sys_common_code.created_at IS '생성 시각 (UTC)';
COMMENT ON COLUMN public.sys_common_code.updated_at IS '수정 시각 (UTC)';
COMMENT ON COLUMN public.sys_common_code.deleted_at IS '삭제 일시 (논리 삭제 시 기록)';
COMMENT ON COLUMN public.sys_common_code.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.sys_common_code.updated_by IS '수정자 ID';
COMMENT ON COLUMN public.sys_common_code.deleted_by IS '삭제 처리자 ID 또는 시스템';



-- #### SYS-외부 연동 OPENAPI 정보 테이블 (IITP-> 외부 Sys) ####
-- # public.sys_ext_api_info definition

-- Drop table if table exists
DROP TABLE IF EXISTS public.sys_ext_api_info;

-- Create table
CREATE TABLE public.sys_ext_api_info (
	ext_api_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	if_name varchar(60) NOT NULL, -- 연동 이름
	ext_sys varchar(20) NOT NULL, -- 연동 시스템 Code , "ext_sys_code" comm code 참조
	ext_url varchar(300) NOT NULL, -- 연동 url
	auth varchar(200) NULL, --  연동 인증키 
	data_format varchar(20) NULL, -- 데이타 형식 Array형태, "data_format" common code ( 예: JSON, XML 등)
	last_sync_time timestamptz NULL, -- 마지막 데이터 수집 시간
	memo varchar(100) NULL,
	status bpchar(1) DEFAULT 'A'::bpchar NOT NULL, -- 상태 : "data_status" comm code (예:P/R/A/I/D)
	del_yn bpchar(1) DEFAULT 'N'::bpchar NOT NULL, -- 삭제여부 (Y: 삭제)
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	deleted_at timestamptz NULL, -- 삭제 일시 (논리 삭제 시 기록)
	created_by varchar(40) NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조
	updated_by varchar(40) NULL, -- 데이터 수정자
	deleted_by varchar(40) NULL, -- 데이터 삭제자
	CONSTRAINT pkey_sys_ext_api_info PRIMARY KEY (ext_api_id)
);
CREATE UNIQUE INDEX uidx_sys_ext_api_info_if_name ON public.sys_ext_api_info USING btree (if_name);
CREATE INDEX idx_sys_ext_api_info_ext ON public.sys_ext_api_info USING btree (ext_sys);
COMMENT ON TABLE public.sys_ext_api_info IS 'SYS-외부 연동 open api  정보 테이블 (IITP-> 외부 Sys) ';

-- Column comments

COMMENT ON COLUMN public.sys_ext_api_info.ext_api_id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.sys_ext_api_info.if_name IS '연동 이름';
COMMENT ON COLUMN public.sys_ext_api_info.ext_sys IS '연동 시스템 Code , "ext_sys_code" comm code 참조';
COMMENT ON COLUMN public.sys_ext_api_info.ext_url IS '연동 url';
COMMENT ON COLUMN public.sys_ext_api_info.auth IS '연동 인증키 ';
COMMENT ON COLUMN public.sys_ext_api_info.data_format IS '데이타 포멧 ( 예: JSON, XML 등)';
COMMENT ON COLUMN public.sys_ext_api_info.last_sync_time IS '마지막 데이터 수집 시간';
COMMENT ON COLUMN public.sys_ext_api_info.del_yn IS '삭제여부 (Y: 삭제)';
COMMENT ON COLUMN public.sys_ext_api_info.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.sys_ext_api_info.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.sys_ext_api_info.deleted_at IS '삭제 일시 (논리 삭제 시 기록)';
COMMENT ON COLUMN public.sys_ext_api_info.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.sys_ext_api_info.updated_by IS '데이터 수정자';
COMMENT ON COLUMN public.sys_ext_api_info.deleted_by IS '데이터 삭제자';




-- ################################################
-- ## Open API Client 인증 키 관련 테이블 생성 
-- ################################################


-- #### IITP OPENAPI Client 정보 테이블 (Client -> IITP) ####

-- # public.open_api_client definition

DROP TABLE IF EXISTS public.open_api_client;


CREATE TABLE public.open_api_client (
	api_cli_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	client_id VARCHAR(40) NOT NULL,  -- client login id
	password VARCHAR(40) NOT NULL,	 -- client login password (encryption)
	client_name VARCHAR(90) NOT NULL, -- client name
	description VARCHAR(600), -- client 설명
	note VARCHAR(600), -- 비고
	is_deleted BOOLEAN NOT NULL DEFAULT false, -- 삭제 여부, 삭제 = true
	latest_key_created_at timestamptz, -- 마지막으로 KEY 발급받은 시간 
	latest_login_at timestamptz, -- latest login time 
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	deleted_at timestamptz NULL, -- 삭제 일시 (논리 삭제 시 기록)
	CONSTRAINT pkey_open_api_client PRIMARY KEY (api_cli_id)
);

CREATE UNIQUE INDEX uidx_open_api_client_cli_id ON public.open_api_client USING btree (client_id);
CREATE INDEX idx_open_api_client_cli_name ON public.open_api_client USING btree (client_name, is_deleted);
COMMENT ON TABLE public.open_api_client IS 'IITP OPENAPI Client 정보 테이블 (Client -> IITP)';

COMMENT ON COLUMN public.open_api_client.api_cli_id IS ' system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.open_api_client.client_id IS 'client login id';
COMMENT ON COLUMN public.open_api_client.password IS 'client login password (encryption)';
COMMENT ON COLUMN public.open_api_client.client_name IS 'client name';
COMMENT ON COLUMN public.open_api_client.description IS 'client 설명';
COMMENT ON COLUMN public.open_api_client.note IS '비고';
COMMENT ON COLUMN public.open_api_client.is_deleted IS '삭제 여부, 삭제 = true';

COMMENT ON COLUMN public.open_api_client.latest_key_created_at IS '마지막으로 KEY 발급받은 시간';
COMMENT ON COLUMN public.open_api_client.latest_login_at IS '마지막 로그인 시각';

COMMENT ON COLUMN public.open_api_client.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.open_api_client.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.open_api_client.deleted_at IS '삭제 일시 (논리 삭제 시 기록)';



-- #### IITP OPENAPI Client Key 정보 테이블 ####

-- # public.open_api_client_key definition

DROP TABLE IF EXISTS public.open_api_client_key ;
CREATE TABLE public.open_api_client_key  (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	api_cli_id int4 NOT NULL,  -- api client sys id. open_api_client.api_cli_id
	api_key VARCHAR(60) NOT NULL,	 -- client api auth key
	is_active BOOLEAN NOT NULL DEFAULT true, -- 활성화 여부, 활성화 = true
	is_deleted BOOLEAN NOT NULL DEFAULT false, -- 삭제 여부, 삭제 = true
	key_active_at timestamptz, -- key 활성화된 일시
	latest_acc_at timestamptz, -- latest access time 
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	deleted_at timestamptz NULL, -- 삭제 일시 (논리 삭제 시 기록)
	CONSTRAINT pkey_open_api_client_key  PRIMARY KEY (id)
);
CREATE UNIQUE INDEX uidx_open_api_client_key_key ON public.open_api_client_key USING btree (api_key);
CREATE INDEX idx_open_api_client_key_cli_id ON public.open_api_client_key USING btree (api_cli_id);
COMMENT ON TABLE public.open_api_client_key IS 'IITP OPENAPI Client Key 정보 테이블';


COMMENT ON COLUMN public.open_api_client_key.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.open_api_client_key.api_cli_id IS ' api client sys id. open_api_client.api_cli_id';
COMMENT ON COLUMN public.open_api_client_key.api_key IS 'client api auth key';
COMMENT ON COLUMN public.open_api_client_key.is_active IS '활성화 여부, 활성화 = true';
COMMENT ON COLUMN public.open_api_client_key.is_deleted IS '삭제 여부, 삭제 = true';

COMMENT ON COLUMN public.open_api_client_key.key_active_at IS 'key 활성화된 일시';
COMMENT ON COLUMN public.open_api_client_key.latest_acc_at IS 'latest access time ';

COMMENT ON COLUMN public.open_api_client_key.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.open_api_client_key.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.open_api_client_key.deleted_at IS '삭제 일시 (논리 삭제 시 기록)';





-- ################################################
-- ## 기초 데이터 - KOSIS 원천 통계 데이터 관련 테이블 생성
-- ################################################


-- # public.stats_src_data_info definition

-- First, delete the related foreign key link table.
--- FR_KEY with stats_src_data_info
-- KOSIS 원천 통계 데이터 
-- DROP TABLE IF EXISTS public.stats_kosis_origin_data;
-- DROP TABLE IF EXISTS public.stats_kosis_metadata_code;

-- 주거 자립 현황
DROP TABLE IF EXISTS public.stats_dis_reg_natl_by_new;
DROP TABLE IF EXISTS public.stats_dis_reg_sido_by_type_sev_gen;
DROP TABLE IF EXISTS public.stats_dis_reg_natl_by_age_type_sev_gen;
DROP TABLE IF EXISTS public.stats_dis_life_supp_need_lvl;
DROP TABLE IF EXISTS public.stats_dis_life_maincarer;
DROP TABLE IF EXISTS public.stats_dis_life_primcarer;
DROP TABLE IF EXISTS public.stats_dis_life_supp_field;
-- 건강 관리 현황
DROP TABLE IF EXISTS public.stats_dis_hlth_medical_usage;
DROP TABLE IF EXISTS public.stats_dis_hlth_disease_cost_sub;
DROP TABLE IF EXISTS public.stats_dis_hlth_sport_exec_type;
DROP TABLE IF EXISTS public.stats_dis_hlth_exrc_best_aid;
-- 보조기기 사용 현황
DROP TABLE IF EXISTS public.stats_dis_aid_device_usage;
DROP TABLE IF EXISTS public.stats_dis_aid_device_need;
-- 진로 교육 현황
DROP TABLE IF EXISTS public.stats_dis_edu_voca_exec;
DROP TABLE IF EXISTS public.stats_dis_edu_voca_exec_way;
-- 고용 현황
DROP TABLE IF EXISTS public.stats_dis_emp_natl;
DROP TABLE IF EXISTS public.stats_dis_emp_natl_public;
DROP TABLE IF EXISTS public.stats_dis_emp_natl_private;
DROP TABLE IF EXISTS public.stats_dis_emp_natl_gov_org;
DROP TABLE IF EXISTS public.stats_dis_emp_natl_dis_type_sev;
DROP TABLE IF EXISTS public.stats_dis_emp_natl_dis_type_indust;
-- 사회망 현황
DROP TABLE IF EXISTS public.stats_dis_soc_partic_freq;
DROP TABLE IF EXISTS public.stats_dis_soc_contact_cntfreq;
-- 편의 시설 제공 현황
DROP TABLE IF EXISTS public.stats_dis_fclty_welfare_usage; 
 

-- Drop table

DROP TABLE IF EXISTS public.stats_src_data_info;

-- Create table
CREATE TABLE public.stats_src_data_info (
	src_data_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	ext_api_id int4 NOT NULL, -- 연동 시스템 정보 ID, sys_ext_api_info.ext_api_id
	ext_sys varchar(10) NULL, -- 데이터 수집한 외부 시스템 코드, "ext_sys_code" comm code 참조. ext_api_id.ext_sys_code 코드와 동일
	
	intg_tbl_id VARCHAR(50) NOT NULL,           -- 데이터 동합할 내부 db table id
	
	stat_title varchar(300) NOT NULL, -- 데이터명
	stat_org_id varchar(12) NOT NULL, -- 작성기관 코드 , "stats_src_orgId" comm code 참조
	stat_survey_name varchar(300) NOT NULL, -- 조사명
    stat_pub_dt varchar(12) NOT NULL, -- 작성시점
	
	periodicity varchar(10) not NULL, -- 데이터 수집 주기 (예: 년,2년...)
	collect_start_dt varchar(12) NOT NULL, -- 데이터 수집 기간-시작 (예: 2019-01 ~ 2024-12 이면 2019-01)
	collect_end_dt varchar(12) NOT NULL, -- 데이터 수집 기간-종료 (예: 2019-01 ~ 2024-12 이면 2024-12)
	
	stat_tbl_id varchar(40) NOT NULL, -- 원데이터 통계 id
	stat_tbl_name varchar(300) NOT NULL, -- 원데이터 통계표명
	
	stat_latest_chn_dt varchar(12) NOT NULL, -- 수집기관 최종 자료갱신일 (예:2024-07-19)
	stat_data_ref_dt varchar(12) NULL, -- KOSIS 통계 데이터를 iitp 시스템에서 마지막 수집/참조 일자 (예:2024-07-19)
	
	avail_cat_cols vachar(40) NULL, -- 사용가능한 Cagegorys (c1~c3) 예: "c1,c2"
	
	del_yn bpchar(1) DEFAULT 'N'::bpchar NOT NULL, -- 삭제여부 (Y: 삭제)
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	deleted_at timestamptz NULL, -- 삭제 일시 (논리 삭제 시 기록)
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조
	updated_by varchar(40) NULL, -- 데이터 수정자
	deleted_by varchar(40) NULL, -- 데이터 삭제자
	CONSTRAINT pkey_st_src_data_info PRIMARY KEY (src_data_id)
);
CREATE UNIQUE INDEX uidx_st_src_data_info_title_tbl_id ON public.stats_src_data_info USING btree (stat_title, stat_tbl_ID );
CREATE INDEX idx_st_src_data_info_org_ext ON public.stats_src_data_info USING btree (stat_org_id, ext_sys );
COMMENT ON TABLE public.stats_src_data_info IS '통계성 데이터 수집 소스 데이터 정보';

-- Column comments

COMMENT ON COLUMN public.stats_src_data_info.src_data_id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_src_data_info.ext_api_id IS '연동 시스템 정보 ID, sys_ext_api_info.ext_api_id';
COMMENT ON COLUMN public.stats_src_data_info.ext_sys IS '데이터 수집한 외부 시스템 코드, "ext_sys_code" comm code 참조. ext_api_id.ext_sys_code 코드와 동일';

COMMENT ON COLUMN public.stats_src_data_info.intg_tbl_id IS '데이터 동합할 내부 db table id';
COMMENT ON COLUMN public.stats_src_data_info.stat_title IS '데이터명';
COMMENT ON COLUMN public.stats_src_data_info.stat_org_id IS '작성기관 코드 , "stats_src_orgId" comm code 참조';
COMMENT ON COLUMN public.stats_src_data_info.stat_survey_name IS '조사명';
COMMENT ON COLUMN public.stats_src_data_info.periodicity IS '데이터 수집 주기  (예: 년,2년...)';
COMMENT ON COLUMN public.stats_src_data_info.collect_start_dt IS '데이터 수집 기간-시작 (예: 2019-01 ~ 2024-12 이면 2019-01)';
COMMENT ON COLUMN public.stats_src_data_info.collect_end_dt IS '데이터 수집 기간-종료 (예: 2019-01 ~ 2024-12 이면 2024-12)';
COMMENT ON COLUMN public.stats_src_data_info.stat_tbl_id IS '원데이터 통계 id';
COMMENT ON COLUMN public.stats_src_data_info.stat_tbl_name IS '원데이터 통계표명';
COMMENT ON COLUMN public.stats_src_data_info.stat_latest_chn_dt IS '수집기관 최종 자료갱신일 (예:2024-07-19)';
COMMENT ON COLUMN public.stats_src_data_info.stat_data_ref_dt IS 'KOSIS 통계 데이터를 iitp 시스템에서 마지막 수집/참조 일자';
COMMENT ON COLUMN public.stats_src_data_info.avail_cat_cols IS '사용가능한 Cagegorys (c1~c3) 예: "c1,c2"';

COMMENT ON COLUMN public.stats_src_data_info.del_yn IS '삭제여부 (Y: 삭제)';
COMMENT ON COLUMN public.stats_src_data_info.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_src_data_info.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_src_data_info.deleted_at IS '삭제 일시 (논리 삭제 시 기록)';
COMMENT ON COLUMN public.stats_src_data_info.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_src_data_info.updated_by IS '데이터 수정자';
COMMENT ON COLUMN public.stats_src_data_info.deleted_by IS '데이터 삭제자';



-- #### KOSIS 원천 통계 데이터의 분류/항목 코드 정보 ####

-- # public.stats_kosis_metadata_code definition

-- Drop table if table exists
DROP TABLE IF EXISTS public.stats_kosis_metadata_code;

CREATE TABLE stats_kosis_metadata_code (
    id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
    src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
    tbl_id VARCHAR(40) NOT NULL,           -- 통계표ID
    
    obj_id VARCHAR(40) NOT null	,	-- 분류 ID
    obj_nm VARCHAR(300) NOT NULL,	-- 분류명 (한글)
   
    itm_id VARCHAR(40) NOT NULL,	-- 자료코드 ID
    itm_nm VARCHAR(300) NOT NULL,	-- 자료코드명 (한글)
    
    up_itm_id VARCHAR(40),			-- 상위 자료코드 ID
    obj_id_sn SMALLINT,				-- 분류값 순번
    
    unit_id VARCHAR(40),			-- 단위 ID
    unit_nm VARCHAR(20),			-- 
   
    stat_latest_chn_dt date,         -- 수집기관 최종 자료갱신일 (예:2024-07-19)
    
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_by VARCHAR(50),
    CONSTRAINT pkey_st_kosis_metadata_code PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uidx_st_kosis_metadata_code_obj_itm_id ON public.stats_kosis_metadata_code USING btree (src_data_id, tbl_id, obj_id, itm_id );

COMMENT ON TABLE public.stats_kosis_metadata_code IS '수집해 온 KOSIS 원천 통계 데이터의 분류/항목 코드 정보';

COMMENT ON COLUMN public.stats_kosis_metadata_code.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_kosis_metadata_code.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_kosis_metadata_code.tbl_id IS '통계표 ID';

COMMENT ON COLUMN public.stats_kosis_metadata_code.obj_id IS '분류 ID';
COMMENT ON COLUMN public.stats_kosis_metadata_code.obj_nm IS '분류명 (한글)';
COMMENT ON COLUMN public.stats_kosis_metadata_code.itm_id IS '자료코드 ID';
COMMENT ON COLUMN public.stats_kosis_metadata_code.itm_nm IS '자료코드명 (한글)';

COMMENT ON COLUMN public.stats_kosis_metadata_code.up_itm_id IS '상위 자료코드 ID';
COMMENT ON COLUMN public.stats_kosis_metadata_code.obj_id_sn IS '분류값 순번';
COMMENT ON COLUMN public.stats_kosis_metadata_code.unit_id IS '단위 ID';
COMMENT ON COLUMN public.stats_kosis_metadata_code.unit_nm IS '단위명 (한글)';

COMMENT ON COLUMN public.stats_kosis_metadata_code.stat_latest_chn_dt IS '수집기관 최종 자료갱신일 (예:2024-07-19)';

COMMENT ON COLUMN public.stats_kosis_metadata_code.created_at IS '생성 일시';
COMMENT ON COLUMN public.stats_kosis_metadata_code.created_by IS '생성자';
COMMENT ON COLUMN public.stats_kosis_metadata_code.updated_at IS '최종 수정 일시';
COMMENT ON COLUMN public.stats_kosis_metadata_code.updated_by IS '최종 수정자';



-- #### KOSIS 원천 통계 데이터 ####

-- # public.stats_kosis_origin_data definition

-- Drop table if table exists
DROP TABLE IF EXISTS public.stats_kosis_origin_data;

-- Create table
CREATE TABLE stats_kosis_origin_data (
    id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
    src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
    
    
    org_id int2 NOT NULL,           -- 기관코드
    tbl_id VARCHAR(40) NOT NULL,           -- 통계표ID
    tbl_nm VARCHAR(300) NOT NULL,          -- 통계표명
	
    c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), c4 VARCHAR(24), -- 분류값 ID1 ~ 4, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류'
	
    c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), c4_obj_nm VARCHAR(300), -- 분류명1 ~ 4
	
    c1_nm VARCHAR(300) NOT NULL, c2_nm VARCHAR(300), c3_nm VARCHAR(300), c4_nm VARCHAR(300), -- 분류값 명1 ~ 4

	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    itm_nm VARCHAR(300) NOT NULL,         -- 항목명
    
    unit_nm VARCHAR(20),                 -- 단위명
	
    prd_se VARCHAR(2) NOT NULL,                    -- 수록주기
    prd_de VARCHAR(10) NOT NULL,                     -- 수록시점
	
    dt  VARCHAR(100)  NOT NULL,                       -- 수치 값
	
    lst_chn_de VARCHAR(10),                 -- 데이터별 최종수정일 (예:2024-07-19)
  
    stat_latest_chn_dt VARCHAR(10),         -- 수집기관 최종 자료갱신일 (예:2024-07-19)
    data_ref_dt date NULL, 					-- KOSIS 통계 데이터를 iitp 시스템에서 마지막 수집/참조 일자
    
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
    created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조
    
	CONSTRAINT pkey_stats_kosis_org_data PRIMARY KEY (id)
);

CREATE INDEX idx_st_kosis_org_data_src_data_org_tbl_id ON public.stats_kosis_origin_data USING btree (src_data_id, org_id,tbl_id );
CREATE INDEX idx_st_kosis_org_data_src_data_latest_chn_dt ON public.stats_kosis_origin_data USING btree (src_data_id, stat_latest_chn_dt );
COMMENT ON TABLE public.stats_kosis_origin_data IS '수집해 온 KOSIS 원천 통계 데이터';


-- 필드별 COMMENT 추가
COMMENT ON COLUMN public.stats_kosis_origin_data.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_kosis_origin_data.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';


COMMENT ON COLUMN public.stats_kosis_origin_data.org_id IS '기관 코드';
COMMENT ON COLUMN public.stats_kosis_origin_data.tbl_id IS '통계표 ID';
COMMENT ON COLUMN public.stats_kosis_origin_data.tbl_nm IS '통계표명';

COMMENT ON COLUMN public.stats_kosis_origin_data.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_kosis_origin_data.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_kosis_origin_data.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_kosis_origin_data.c4 IS '분류값 ID4, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';


COMMENT ON COLUMN public.stats_kosis_origin_data.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_kosis_origin_data.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_kosis_origin_data.c3_obj_nm IS '분류명3';
COMMENT ON COLUMN public.stats_kosis_origin_data.c4_obj_nm IS '분류명4';


COMMENT ON COLUMN public.stats_kosis_origin_data.c1_nm IS '분류값 명1';
COMMENT ON COLUMN public.stats_kosis_origin_data.c2_nm IS '분류값 명2';
COMMENT ON COLUMN public.stats_kosis_origin_data.c3_nm IS '분류값 명3';
COMMENT ON COLUMN public.stats_kosis_origin_data.c4_nm IS '분류값 명4';

COMMENT ON COLUMN public.stats_kosis_origin_data.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';
COMMENT ON COLUMN public.stats_kosis_origin_data.itm_nm IS '항목명, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_kosis_origin_data.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_kosis_origin_data.prd_se IS '수록주기';
COMMENT ON COLUMN public.stats_kosis_origin_data.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_kosis_origin_data.dt IS '수치 값';

COMMENT ON COLUMN public.stats_kosis_origin_data.lst_chn_de IS '데이터별 최종수정일 (예:2024-07-19)';
COMMENT ON COLUMN public.stats_kosis_origin_data.stat_latest_chn_dt IS '수집기관 최종 자료갱신일 (예:2024-07-19)';

COMMENT ON COLUMN public.stats_kosis_origin_data.data_ref_dt IS 'KOSIS 통계 데이터를 iitp 시스템에서 마지막 수집/참조 일자 (예:2024-07-19)';

COMMENT ON COLUMN public.stats_kosis_origin_data.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_kosis_origin_data.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';



-- ################################################
-- ## 기초 데이터 - 통합된 KOSIS 통계 데이터 관련 테이블 생성
-- ################################################


-- #### 주거 자립 현황 ####

-- # public.stats_dis_reg_natl_by_new definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_reg_natl_by_new;

CREATE TABLE public.stats_dis_reg_natl_by_new (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3

    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_reg_natl_by_new PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_reg_natl_by_new_year_c1t3 ON public.stats_dis_reg_natl_by_new USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_reg_natl_by_new IS '기초-주거 자립 현황- 전국 장애인 신규등록 장애인 현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_new.updated_by IS '데이터 수정자';


-- public.stats_dis_reg_natl_by_new foreign keys

ALTER TABLE public.stats_dis_reg_natl_by_new ADD CONSTRAINT fk_st_dis_reg_natl_by_new FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_reg_natl_by_age_type_sev_gen definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_reg_natl_by_age_type_sev_gen;

CREATE TABLE public.stats_dis_reg_natl_by_age_type_sev_gen (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_reg_natl_by_age_type_sev_gen PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_reg_natl_by_age_type_sev_gen_year_c1t3 ON public.stats_dis_reg_natl_by_age_type_sev_gen USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_reg_natl_by_age_type_sev_gen IS '기초-주거 자립 현황-전국 연령별,장애등급별,성별 등록장애인수';

-- Column comments

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_reg_natl_by_age_type_sev_gen.updated_by IS '데이터 수정자';


-- public.stats_dis_reg_natl_by_age_type_sev_gen foreign keys

ALTER TABLE public.stats_dis_reg_natl_by_age_type_sev_gen ADD CONSTRAINT fk_st_dis_reg_natl_by_age_type_sev_gen FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_reg_sido_by_type_sev_gen definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_reg_sido_by_type_sev_gen;

CREATE TABLE public.stats_dis_reg_sido_by_type_sev_gen (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_reg_sido_by_type_sev_gen PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_reg_sido_by_type_sev_gen_year_c1t3 ON public.stats_dis_reg_sido_by_type_sev_gen USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_reg_sido_by_type_sev_gen IS '기초-주거 자립 현황-시도별,장애유형별,장애정도별,성별 등록장애인수';

-- Column comments

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_reg_sido_by_type_sev_gen.updated_by IS '데이터 수정자';


-- public.stats_dis_reg_sido_by_type_sev_gen foreign keys

ALTER TABLE public.stats_dis_reg_sido_by_type_sev_gen ADD CONSTRAINT fk_st_dis_reg_sido_by_type_sev_gen FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_life_supp_need_lvl definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_life_supp_need_lvl;

CREATE TABLE public.stats_dis_life_supp_need_lvl (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_life_supp_need_lvl PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_life_supp_need_lvl_year_c1t3 ON public.stats_dis_life_supp_need_lvl USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_life_supp_need_lvl IS '기초-주거 자립 현황-일상생활 필요 지원 정도';

-- Column comments

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_life_supp_need_lvl.updated_by IS '데이터 수정자';


-- public.stats_dis_life_supp_need_lvl foreign keys

ALTER TABLE public.stats_dis_life_supp_need_lvl ADD CONSTRAINT fk_st_dis_life_supp_need_lvl FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_life_maincarer definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_life_maincarer;

CREATE TABLE public.stats_dis_life_maincarer (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_life_maincarer PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_life_maincarer_year_c1t3 ON public.stats_dis_life_maincarer USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_life_maincarer IS '기초-주거 자립 현황-주로 지원해주는 사람의 유형';

-- Column comments

COMMENT ON COLUMN public.stats_dis_life_maincarer.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_life_maincarer.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_life_maincarer.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_life_maincarer.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_maincarer.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_maincarer.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_life_maincarer.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_life_maincarer.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_life_maincarer.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_life_maincarer.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_life_maincarer.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_life_maincarer.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_life_maincarer.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_life_maincarer.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_life_maincarer.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_life_maincarer.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_life_maincarer.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_life_maincarer.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_life_maincarer.updated_by IS '데이터 수정자';


-- public.stats_dis_life_maincarer foreign keys

ALTER TABLE public.stats_dis_life_maincarer ADD CONSTRAINT fk_st_dis_life_maincarer FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_life_primcarer definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_life_primcarer;

CREATE TABLE public.stats_dis_life_primcarer (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_life_primcarer PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_life_primcarer_year_c1t3 ON public.stats_dis_life_primcarer USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_life_primcarer  IS '기초-주거 자립 현황-일상생활 도와주는 사람(1순위)';

-- Column comments

COMMENT ON COLUMN public.stats_dis_life_primcarer.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_life_primcarer.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_life_primcarer.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_life_primcarer.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_primcarer.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_primcarer.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_life_primcarer.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_life_primcarer.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_life_primcarer.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_life_primcarer.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_life_primcarer.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_life_primcarer.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_life_primcarer.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_life_primcarer.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_life_primcarer.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_life_primcarer.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_life_primcarer.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_life_primcarer.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_life_primcarer.updated_by IS '데이터 수정자';


-- public.stats_dis_life_primcarer foreign keys

ALTER TABLE public.stats_dis_life_primcarer ADD CONSTRAINT fk_st_dis_life_primcarer FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);


-- # public.stats_dis_life_supp_field definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_life_supp_field;

CREATE TABLE public.stats_dis_life_supp_field (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_life_supp_field PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_life_supp_field_year_c1t3 ON public.stats_dis_life_supp_field USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_life_supp_field  IS '기초-주거 자립 현황-도움받는 분야';

-- Column comments

COMMENT ON COLUMN public.stats_dis_life_supp_field.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_life_supp_field.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_life_supp_field.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_life_supp_field.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_supp_field.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_life_supp_field.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_life_supp_field.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_life_supp_field.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_life_supp_field.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_life_supp_field.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_life_supp_field.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_life_supp_field.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_life_supp_field.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_life_supp_field.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_life_supp_field.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_life_supp_field.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_life_supp_field.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_life_supp_field.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_life_supp_field.updated_by IS '데이터 수정자';


-- public.stats_dis_life_supp_field foreign keys

ALTER TABLE public.stats_dis_life_supp_field ADD CONSTRAINT fk_st_dis_life_supp_field FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);




-- #### 건강 관리 현황 ####

-- # public.stats_dis_hlth_medical_usage definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_hlth_medical_usage;

CREATE TABLE public.stats_dis_hlth_medical_usage (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
	
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_hlth_medi_usage PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_hlth_medi_usageyear_c1t3 ON public.stats_dis_hlth_medical_usage USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_hlth_medical_usage IS '기초-건강 관리 현황-장애인 의료이용 현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_hlth_medical_usage.updated_by IS '데이터 수정자';


-- public.stats_dis_hlth_medical_usage foreign keys

ALTER TABLE public.stats_dis_hlth_medical_usage ADD CONSTRAINT fk_st_dis_hlth_medi_usage FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);


-- # public.stats_dis_hlth_disease_cost_sub definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_hlth_disease_cost_sub;

CREATE TABLE public.stats_dis_hlth_disease_cost_sub (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
	
	dt  VARCHAR(100)  NOT NULL,                       -- 수치 값
    -- dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_hlth_dcost_sub PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_hlth_dcost_subyear_c1t3 ON public.stats_dis_hlth_disease_cost_sub USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_hlth_disease_cost_sub IS '기초-건강 관리 현황-장애인 장애유형별 다빈도질환별 진료비현황: 소분류 (maj(대)/mid(중)/sub(소))';

-- Column comments

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_hlth_disease_cost_sub.updated_by IS '데이터 수정자';


-- public.stats_dis_hlth_disease_cost_sub foreign keys

ALTER TABLE public.stats_dis_hlth_disease_cost_sub ADD CONSTRAINT fk_st_dis_hlth_dcost_sub FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);


-- # public.stats_dis_hlth_sport_exec_type definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_hlth_sport_exec_type;

CREATE TABLE public.stats_dis_hlth_sport_exec_type (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
	
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_hlth_sport_exec_type PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_hlth_sport_exec_type_year_c1t3 ON public.stats_dis_hlth_sport_exec_type USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_hlth_sport_exec_type IS '기초-건강 관리 현황-장애인 생활체육 실행 유형';

-- Column comments

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_hlth_sport_exec_type.updated_by IS '데이터 수정자';


-- public.stats_dis_hlth_sport_exec_type foreign keys

ALTER TABLE public.stats_dis_hlth_sport_exec_type ADD CONSTRAINT fk_st_dis_hlth_sport_exec_type FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);


-- # public.stats_dis_hlth_exrc_best_aid definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_hlth_exrc_best_aid;

CREATE TABLE public.stats_dis_hlth_exrc_best_aid (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
	
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_hlth_exrc_best_aid PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_hlth_exrc_best_aid_year_c1t3 ON public.stats_dis_hlth_exrc_best_aid USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_hlth_exrc_best_aid IS '기초-건강 관리 현황-운동 시 가장 도움이 되는 지원 사항';

-- Column comments

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_hlth_exrc_best_aid.updated_by IS '데이터 수정자';


-- public.stats_dis_hlth_exrc_best_aid foreign keys

ALTER TABLE public.stats_dis_hlth_exrc_best_aid ADD CONSTRAINT fk_st_dis_hlth_exrc_best_aid FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);




-- #### 보조기기 사용 현황 ####

-- # public.stats_dis_aid_device_usage definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_aid_device_usage;

CREATE TABLE public.stats_dis_aid_device_usage (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
	
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_aid_device_usage PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_aid_device_usage_year_c1t3 ON public.stats_dis_aid_device_usage USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_aid_device_usage IS '기초-보조기기 사용 현황-장애인보조기기 사용여부';

-- Column comments

COMMENT ON COLUMN public.stats_dis_aid_device_usage.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_aid_device_usage.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_aid_device_usage.updated_by IS '데이터 수정자';


-- public.stats_dis_aid_device_usage foreign keys

ALTER TABLE public.stats_dis_aid_device_usage ADD CONSTRAINT fk_st_dis_aid_device_usage FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);


-- # public.stats_dis_aid_device_need definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_aid_device_need;

CREATE TABLE public.stats_dis_aid_device_need (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_aid_device_need PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_aid_device_need_year_c1t3 ON public.stats_dis_aid_device_need USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_aid_device_need IS '기초-보조기기 사용 현황-장애인보조기기 필요여부';

-- Column comments

COMMENT ON COLUMN public.stats_dis_aid_device_need.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_aid_device_need.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_aid_device_need.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_aid_device_need.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_aid_device_need.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_aid_device_need.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_aid_device_need.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_aid_device_need.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_aid_device_need.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_aid_device_need.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_aid_device_need.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_aid_device_need.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_aid_device_need.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_aid_device_need.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_aid_device_need.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_aid_device_need.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_aid_device_need.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_aid_device_need.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_aid_device_need.updated_by IS '데이터 수정자';


-- public.stats_dis_aid_device_need foreign keys

ALTER TABLE public.stats_dis_aid_device_need ADD CONSTRAINT fk_st_dis_aid_device_need FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);





-- #### 진로 교육 현황 ####


-- # public.stats_dis_edu_voca_exec definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_edu_voca_exec;

CREATE TABLE public.stats_dis_edu_voca_exec (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_edu_voca_exec PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_edu_voca_exec_year_c1t3 ON public.stats_dis_edu_voca_exec USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_edu_voca_exec IS '기초-진로 교육 현황-장애인 진로 및 직업교육 실시 여부';

-- Column comments

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec.updated_by IS '데이터 수정자';


-- public.stats_dis_edu_voca_exec foreign keys

ALTER TABLE public.stats_dis_edu_voca_exec ADD CONSTRAINT fk_st_dis_edu_voca_exec FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_edu_voca_exec_way definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_edu_voca_exec_way;

CREATE TABLE public.stats_dis_edu_voca_exec_way (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_edu_voca_exec_way PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_edu_voca_exec_way_year_c1t3 ON public.stats_dis_edu_voca_exec_way USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_edu_voca_exec_way IS '기초-진로 교육 현황-장애인 진로 및 직업교육 운영 방법';

-- Column comments

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_edu_voca_exec_way.updated_by IS '데이터 수정자';


-- public.stats_dis_edu_voca_exec_way foreign keys

ALTER TABLE public.stats_dis_edu_voca_exec_way ADD CONSTRAINT fk_st_dis_edu_voca_exec_way FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);





-- #### 고용 현황 ####

-- # public.stats_dis_emp_natl definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_emp_natl;

CREATE TABLE public.stats_dis_emp_natl (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_emp_natl PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_emp_natl_year_c1t3 ON public.stats_dis_emp_natl USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_emp_natl IS '기초-고용 현황-장애인 근로자 고용현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_emp_natl.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_emp_natl.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_emp_natl.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_emp_natl.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_emp_natl.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_emp_natl.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_emp_natl.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_emp_natl.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_emp_natl.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_emp_natl.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_emp_natl.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_emp_natl.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_emp_natl.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_emp_natl.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_emp_natl.updated_by IS '데이터 수정자';


-- public.stats_dis_emp_natl foreign keys

ALTER TABLE public.stats_dis_emp_natl ADD CONSTRAINT fk_st_dis_emp_natl FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_emp_natl_public definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_emp_natl_public;

CREATE TABLE public.stats_dis_emp_natl_public (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_emp_natl_pub PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_emp_natl_pub_year_c1t3 ON public.stats_dis_emp_natl_public USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_emp_natl_public IS '기초-고용 현황-공공기관 장애인고용 현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_emp_natl_public.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_emp_natl_public.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_emp_natl_public.updated_by IS '데이터 수정자';


-- public.stats_dis_emp_natl_public foreign keys

ALTER TABLE public.stats_dis_emp_natl_public ADD CONSTRAINT fk_st_dis_emp_natl_pub FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_emp_natl_private definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_emp_natl_private;

CREATE TABLE public.stats_dis_emp_natl_private (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_emp_natl_priv PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_emp_natl_priv_year_c1t3 ON public.stats_dis_emp_natl_private USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_emp_natl_private IS '기초-고용 현황-민간기업 장애인고용 현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_emp_natl_private.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_emp_natl_private.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_emp_natl_private.updated_by IS '데이터 수정자';


-- public.stats_dis_emp_natl_private foreign keys

ALTER TABLE public.stats_dis_emp_natl_private ADD CONSTRAINT fk_st_dis_emp_natl_priv FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_emp_natl_gov_org definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_emp_natl_gov_org;

CREATE TABLE public.stats_dis_emp_natl_gov_org (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_emp_natl_gov_org PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_emp_natl_gov_org_year_c1t3 ON public.stats_dis_emp_natl_gov_org USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_emp_natl_gov_org IS '기초-고용 현황-정부부문 장애인고용 현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_emp_natl_gov_org.updated_by IS '데이터 수정자';


-- public.stats_dis_emp_natl_gov_org foreign keys

ALTER TABLE public.stats_dis_emp_natl_gov_org ADD CONSTRAINT fk_st_dis_emp_natl_gov_org FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_emp_natl_dis_type_sev definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_emp_natl_dis_type_sev;

CREATE TABLE public.stats_dis_emp_natl_dis_type_sev (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_emp_natl_dis_ty_sev PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_emp_natl_dis_ty_sev_year_c1t3 ON public.stats_dis_emp_natl_dis_type_sev USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_emp_natl_dis_type_sev IS '기초-고용 현황-장애유형 및 장애정도별 장애인 근로자 고용현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_sev.updated_by IS '데이터 수정자';


-- public.stats_dis_emp_natl_dis_type_sev foreign keys

ALTER TABLE public.stats_dis_emp_natl_dis_type_sev ADD CONSTRAINT fk_st_dis_emp_natl_dis_ty_sev FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_emp_natl_dis_type_indust definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_emp_natl_dis_type_indust;

CREATE TABLE public.stats_dis_emp_natl_dis_type_indust (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_emp_natl_dis_ty_ind PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_emp_natl_dis_ty_ind_year_c1t3 ON public.stats_dis_emp_natl_dis_type_indust USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_emp_natl_dis_type_indust IS '기초-고용 현황-장애유형 및 산업별 장애인 근로자 고용현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_emp_natl_dis_type_indust.updated_by IS '데이터 수정자';


-- public.stats_dis_emp_natl_dis_type_indust foreign keys

ALTER TABLE public.stats_dis_emp_natl_dis_type_indust ADD CONSTRAINT fk_st_dis_emp_natl_dis_ty_ind FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- #### 사회망 현황 ####


-- # public.stats_dis_soc_partic_freq definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_soc_partic_freq;

CREATE TABLE public.stats_dis_soc_partic_freq (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_soc_partic_freq PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_soc_partic_freq_year_c1t3 ON public.stats_dis_soc_partic_freq USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_soc_partic_freq IS '기초-사회망 현황-장애인의 사회 참여';

-- Column comments

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_soc_partic_freq.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_soc_partic_freq.updated_by IS '데이터 수정자';


-- public.stats_dis_soc_partic_freq foreign keys

ALTER TABLE public.stats_dis_soc_partic_freq ADD CONSTRAINT fk_st_dis_soc_partic_freq FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



-- # public.stats_dis_soc_contact_cntfreq definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_soc_contact_cntfreq;

CREATE TABLE public.stats_dis_soc_contact_cntfreq (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_soc_contact_cntfreq PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_soc_contact_cntfreq_year_c1t3 ON public.stats_dis_soc_contact_cntfreq USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_soc_contact_cntfreq IS '기초-사회망 현황-가까이 지내는 친구, 이웃, 지인 수 및 만남 빈도';

-- Column comments

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_soc_contact_cntfreq.updated_by IS '데이터 수정자';


-- public.stats_dis_soc_contact_cntfreq foreign keys

ALTER TABLE public.stats_dis_soc_contact_cntfreq ADD CONSTRAINT fk_st_dis_soc_contact_cntfreq FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);






-- #### 편의 시설 제공 현황 ####


-- # public.stats_dis_fclty_welfare_usage definition

-- Drop table

-- DROP TABLE IF EXISTS public.stats_dis_fclty_welfare_usage;

CREATE TABLE public.stats_dis_fclty_welfare_usage (
	id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 CYCLE) NOT NULL, -- system id, 고유 식별자 (자동 증가)
	src_data_id int4 NOT NULL, -- 소스 데이터 정보 ID, stats_src_data_info.src_data_id
	
	prd_de int2 NOT NULL, -- 수록시점, 연도 (예: 2024)
	
	c1 VARCHAR(24) NOT NULL, c2 VARCHAR(24), c3 VARCHAR(24), -- 분류값 ID1 ~ 3, 값 > 3자일 일경우: 앞3자리는  group id, 검색 후 group id nm으 로표시. c#_obj하위에 group임. c#_obj > c# group > c#, itm_id는 별도 분류
	c1_obj_nm VARCHAR(300) NOT NULL, c2_obj_nm VARCHAR(300), c3_obj_nm VARCHAR(300), -- -- 분류명1 ~ 3
	
    itm_id VARCHAR(24) NOT NULL,           -- 항목 ID
    
    unit_nm VARCHAR(20),                 -- 단위명
    
    dt  NUMERIC(15,3)  NOT NULL,                       -- 수치 값
	
    lst_chn_de date,                 -- 데이터별 최종수정일
	src_latest_chn_dt date,         -- 수집기관 최종 자료갱신일
	
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL, -- 레코드 생성 시각
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP, -- 레코드 수정 시각
	created_by varchar(40) NOT NULL, -- 데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조 (BACH, MANUAL, user id)
	updated_by varchar(40) NULL, -- 데이터 수정자
	
	CONSTRAINT pkey_st_dis_fclty_welfare_usage PRIMARY KEY (id)
);
CREATE INDEX idx_st_dis_fclty_welfare_usage_year_c1t3 ON public.stats_dis_fclty_welfare_usage USING btree (prd_de, c1, c2, c3);
COMMENT ON TABLE public.stats_dis_fclty_welfare_usage IS '기초-편의 시설 제공 현황-사회복지시설 이용 현황';

-- Column comments

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.id IS 'system id, 고유 식별자 (자동 증가)';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.src_data_id IS '소스 데이터 정보 ID, stats_src_data_info.src_data_id';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.prd_de IS '수록시점, 연도 (예: 2024)';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.c1 IS '분류값 ID1, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.c2 IS '분류값 ID2, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.c3 IS '분류값 ID3, C#의 group은 c#_obj_nm, meta에서 obj_nm=c#_obj_nm으로 매칭, itm_id는 별도 분류';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.c1_obj_nm IS '분류명1';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.c2_obj_nm IS '분류명2';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.c3_obj_nm IS '분류명3';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.itm_id IS '항목 ID, meta에서 obj_id = ITEM or obj_nm=항목으로 매핑';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.unit_nm IS '단위명';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.prd_de IS '수록시점';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.dt IS '수치 값';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.lst_chn_de IS ' 데이터별 최종 수정일';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.src_latest_chn_dt IS ' 수집기관 최종 자료갱신일';

COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.created_at IS '레코드 생성 시각';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.updated_at IS '레코드 수정 시각';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.created_by IS '데이터 생성자 (SYS-BACH, SYS-MANUAL, user id), "sys_work_type" comm code 참조';
COMMENT ON COLUMN public.stats_dis_fclty_welfare_usage.updated_by IS '데이터 수정자';


-- public.stats_dis_fclty_welfare_usage foreign keys

ALTER TABLE public.stats_dis_fclty_welfare_usage ADD CONSTRAINT fk_st_dis_fclty_welfare_usage FOREIGN KEY (src_data_id) REFERENCES public.stats_src_data_info(src_data_id);



