
-- ## iitp DB Schemas - Initial setup - Insert Data for Required System Data
-- ## ver 0.0.9 last update data : 2025.07.04
-- ## Only for PostgreSQL
-- ## 초기 데이터 삽입 : 공통 코드 및 시스템 필수 데이터 


-- ################################################
-- ### 현재 시퀀스 값 조회
-- ################################################

DO $$
DECLARE
  rec RECORD;
  current_val bigint;
BEGIN
  FOR rec IN
    SELECT
      n.nspname AS schema_name,
      t.relname AS table_name,
      a.attname AS column_name,
      seq.relname AS sequence_name
    FROM
      pg_class t
      JOIN pg_namespace n ON t.relnamespace = n.oid
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum > 0
      JOIN pg_depend d ON d.refobjid = t.oid AND d.refobjsubid = a.attnum
      JOIN pg_class seq ON seq.oid = d.objid AND seq.relkind = 'S'
    WHERE
      n.nspname = 'public'  -- 스키마 이름 변경 가능
  LOOP
    EXECUTE format('SELECT last_value FROM %I.%I', rec.schema_name, rec.sequence_name)
    INTO current_val;

    RAISE INFO '스키마: %, 테이블: %, 컬럼: %, 시퀀스: %, 현재값: %',
      rec.schema_name, rec.table_name, rec.column_name, rec.sequence_name, current_val;
  END LOOP;
END;
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

        IF current_val > 0 THEN
            RAISE NOTICE '시퀀스 % 현재 값이 %입니다. 초기화합니다.', rec.seq_name, current_val;
            EXECUTE format('SELECT setval(%L, 1, false)', 'public.' || rec.seq_name);
        ELSE
            RAISE NOTICE '시퀀스 % 현재 값이 1 이하입니다. 초기화하지 않습니다.', rec.seq_name;
        END IF;
    END LOOP;
END
$$;



-- ################################################
-- ### 공통 코드 - 초기 데이터 삽입
-- ################################################


-- #### public.sys_common_code Data

-- # SYSTEM 용, code_type = S
-- sys_work_type : 시스템 동작 타입
DELETE FROM public.sys_common_code WHERE grp_id='sys_work_type';
INSERT INTO public.sys_common_code (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl, sort_order, use_yn, del_yn, code_des, memo, created_at, updated_at, deleted_at, created_by, updated_by, deleted_by) 
			values
				('sys_work_type', '시스템 동작 타입', 'SYS-BACH', '시스템 Bach 처리', null, null, 'S', 1, 0, 'Y'::bpchar, 'N'::bpchar, '시스템의 Bach에 의해 자동으로 처리된 경우.', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('sys_work_type', '시스템 동작 타입', 'SYS-MANUAL', '시스템 수동 처리', null, null, 'S', 1, 0, 'Y'::bpchar, 'N'::bpchar, '관리자시스템 외에서 수동 처리시, 관리시스템에서 처리된 경우 관리자 ID 삽입.', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null);
					

-- data_status : 데이터 상태
DELETE FROM public.sys_common_code WHERE grp_id='data_status';
INSERT INTO public.sys_common_code (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl, sort_order, use_yn, del_yn, code_des, memo, created_at, updated_at, deleted_at, created_by, updated_by, deleted_by) 
			values
				('data_status', '데이터 상태', 'P', '대기 중', null, null, 'S', 1, 1, 'Y'::bpchar, 'N'::bpchar, 'Pending: 내부 승인·검토 전', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
    			('data_status', '데이터 상태', 'R', '준비 완료', null, null, 'S', 1, 2, 'Y'::bpchar, 'N'::bpchar, 'Ready: 승인 완료, 활성화 조건 대기 중', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
    			('data_status', '데이터 상태', 'A', '활성', null, null, 'S', 1, 3, 'Y'::bpchar, 'N'::bpchar, 'Active: 현재 사용 가능한 상태', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
    			('data_status', '데이터 상태', 'I', '비활성', null, null, 'S', 1, 4, 'Y'::bpchar, 'N'::bpchar, 'Inactive: 일시적으로 비활성화된 상태', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
    			('data_status', '데이터 상태', 'D', '삭제됨', null, null, 'S', 1, 5, 'N'::bpchar, 'Y'::bpchar, 'Deleted: 논리적으로 삭제된 상태', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null);


-- data_format : 데이터 형식(format)
DELETE FROM public.sys_common_code WHERE grp_id='data_format';
INSERT INTO public.sys_common_code (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl, sort_order, use_yn, del_yn, code_des, memo, created_at, updated_at, deleted_at, created_by, updated_by, deleted_by) 
			values
				('data_format', '데이터 형식', 'JSON', 'JSON', null, null, 'S', 1, 1, 'Y'::bpchar, 'N'::bpchar, 'JSON', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
    			('data_format', '데이터 형식', 'XML', 'XML', null, null, 'S', 1, 2, 'Y'::bpchar, 'N'::bpchar, 'XML', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
    			('data_format', '데이터 형식', 'ARRAY', 'ARRAY', null, null, 'S', 1, 3, 'Y'::bpchar, 'N'::bpchar, 'ARRAY', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null);


-- ext_sys_code : 외부 연동 시스템 코드
DELETE FROM public.sys_common_code WHERE grp_id='ext_sys_code';
INSERT INTO public.sys_common_code (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl, sort_order, use_yn, del_yn, code_des, memo, created_at, updated_at, deleted_at, created_by, updated_by, deleted_by) 
				VALUES('ext_sys_code', '외부 연동 시스템 코드', 'KOSIS', 'KOSIS 국가통계포털', null, null, 'S', 1, 0, 'Y'::bpchar, 'N'::bpchar, '정형-기초 데이터용 통계 데이터 수집을 위한 연동 시스템', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null);


-- # 서비스용, code_type = B
-- stats_src_orgId : 통계 데이터 출처 기관 ID
DELETE FROM public.sys_common_code WHERE grp_id='stats_src_orgId';
INSERT INTO public.sys_common_code (grp_id, grp_nm, code_id, code_nm, parent_grp_id, parent_code_id, code_type, code_lvl, sort_order, use_yn, del_yn, code_des, memo, created_at, updated_at, deleted_at, created_by, updated_by, deleted_by) 
			values
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_101', '통계청', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '통계청(kostat)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_112', '교육부', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '교육부(moe)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_113', '문화체육관광부', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '문화체육관광부(mcst)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_117', '보건복지부', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '보건복지부(mohw)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_118', '고용노동부', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '고용노동부(moel)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_322', '국민연금공단', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '국민연금공단(nps)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_383', '한국장애인고용공단', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '한국장애인고용공단(kead)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null),
				('stats_src_orgId', '통계 데이터 출처 기관 ID', 'KOSIS_438', '한국장애인개발원', null, null, 'B', 1, 0, 'Y'::bpchar, 'N'::bpchar, '한국장애인개발원(koddi)', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null);
				





-- ################################################
-- ### 외부 연동 시스템 정보 - 초기 데이터 삽입
-- ################################################


-- #### public.sys_ext_api_info Data

TRUNCATE TABLE  public.sys_ext_api_info;
INSERT INTO public.sys_ext_api_info (if_name, ext_sys, ext_url, auth, data_format, latest_sync_time, memo, del_yn, created_at, updated_at, deleted_at, created_by, updated_by, deleted_by) 
			values
				('KOSIS 국가통계포털', 'KOSIS', 'https://kosis.kr/statisticsList/statisticsListIndex.do?vwcd=MT_ZTITLE&menuId=M_01_01', 'MjBjZGE5MjlkM2U5ZjE3NWZiMWU2OTkwN2Y4YjgwZTA=', '[JOSN,XML]', null, '', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, null, 'SYS-MANUAL', null, null);



-- ################################################
-- ### 통계성 데이터 수집 소스 데이터 정보 - 초기 데이터 삽입
-- ### 이 데이터는 향후 연동에 의해 삽입될 수 있음. 
-- ################################################

-- #### public.sys_stats_src_api_info Data
TRUNCATE TABLE public.sys_stats_src_api_info CASCADE;

INSERT INTO public.sys_stats_src_api_info (ext_api_id, status, del_yn, stat_title, stat_tbl_id, use_base_url_yn, api_data_url, api_meta_url, api_latest_chn_dt_url, created_at, updated_at, created_by) 
			VALUES
			    (1,'A','N','신규등록 장애인현황','DT_11761_N010','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+T002+T003+&objL1=CHUT0+CHU01+CHU03+CHU041+CHU051+CHU06+&objL2=000+0201+0202+0203+0204+0205+&objL3=ALL&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11761_N010","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=117&tblId=DT_11761_N010","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=117&tblId=DT_11761_N010","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','전국 연령별,장애등급별,성별 등록장애인수','DT_11761_N007','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+T002+T003+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11761_N007","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=117&tblId=DT_11761_N007","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=117&tblId=DT_11761_N007","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','시도별,장애유형별,장애정도별,성별 등록장애인수','DT_11761_N008','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+T002+T003+&objL1=ALL&objL2=ALL&objL3=ALL&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11761_N008","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=117&tblId=DT_11761_N008","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=117&tblId=DT_11761_N008","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','일상생활 필요 지원 정도','DT_11732S0110','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=00+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=F&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11732S0110","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=117&tblId=DT_11732S0110","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=117&tblId=DT_11732S0110","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','주로 지원해주는 사람의 유형','DT_11732S0112','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=00+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=F&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_11732S0112","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=117&tblId=DT_11732S0112","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=117&tblId=DT_11732S0112","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','일상생활 도와주는 사람(1순위)','DT_438001_AE001','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AE001","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=438&tblId=DT_438001_AE001","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=438&tblId=DT_438001_AE001","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','도움받는 분야','DT_438001_AE002','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AE002","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=438&tblId=DT_438001_AE002","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=438&tblId=DT_438001_AE002&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애인 의료이용 현황','DT_117102_A050','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_117102_A050","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=117&tblId=DT_117102_A050","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=117&tblId=DT_117102_A050","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애인 장애유형별 다빈도질환별 진료비현황: 소분류','DT_117102_A047','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+T002+T003+T004+T005+T006+T007+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=117&tblId=DT_117102_A047","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=117&tblId=DT_117102_A047","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=117&tblId=DT_117102_A047&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애인 생활체육 실행 유형','DT_113_STBL_1030517','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=13103133057T1+13103133057T2+13103133057T3+13103133057T4+&objL1=ALL&objL2=&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=113&tblId=DT_113_STBL_1030517","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=113&tblId=DT_113_STBL_1030517","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=113&tblId=DT_113_STBL_1030517&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','운동 시 가장 도움이 되는 지원 사항','DT_113_STBL_1029644','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=13103131499T1+13103131499T2+13103131499T3+13103131499T4+13103131499T5+13103131499T6+13103131499T7+13103131499T8+&objL1=ALL&objL2=&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=113&tblId=DT_113_STBL_1029644","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=113&tblId=DT_113_STBL_1029644","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=113&tblId=DT_113_STBL_1029644&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애인보조기기 사용여부','DT_438001_AE023','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AE023","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=438&tblId=DT_438001_AE023","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=438&tblId=DT_438001_AE023&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애인보조기기 필요여부','DT_438001_AE022','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AE022","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=438&tblId=DT_438001_AE022","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=438&tblId=DT_438001_AE022&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','진로 및 직업교육 실시 여부','DT_112014_2023_01_135','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+T002+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=F&startPrdDe={from}&endPrdDe={to}&orgId=112&tblId=DT_112014_2023_01_135","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=112&tblId=DT_112014_2023_01_135","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=112&tblId=DT_112014_2023_01_135&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','진로 및 직업교육 운영 방법','DT_112014_2023_01_137','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+T002+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=F&startPrdDe={from}&endPrdDe={to}&orgId=112&tblId=DT_112014_2023_01_137","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=112&tblId=DT_112014_2023_01_137","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=112&tblId=DT_112014_2023_01_137&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애인 근로자 고용현황','DT_38302_2016_N008','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T1+T2+T3+T4+T5+&objL1=ALL&objL2=&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=383&tblId=DT_38302_2016_N008","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=383&tblId=DT_38302_2016_N008","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=383&tblId=DT_38302_2016_N008&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','공공기관 장애인고용 현황','DT_11830_N003','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=01+02+03+04+&objL1=ALL&objL2=&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=118&tblId=DT_11830_N003","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=118&tblId=DT_11830_N003","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=118&tblId=DT_11830_N003&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','민간기업 장애인고용 현황','DT_11830_N004_001','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=01+02+03+04+&objL1=ALL&objL2=&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=118&tblId=DT_11830_N004_001","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=118&tblId=DT_11830_N004_001","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=118&tblId=DT_11830_N004_001&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','정부부문 장애인고용 현황','DT_11830_N002_001','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=01+02+03+04+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=118&tblId=DT_11830_N002_001","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=118&tblId=DT_11830_N002_001","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=118&tblId=DT_11830_N002_001&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애유형 및 장애정도별 장애인 근로자 고용현황','DT_38302_2016_N011','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T3+T4+&objL1=ALL&objL2=&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=383&tblId=DT_38302_2016_N011","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=383&tblId=DT_38302_2016_N011","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=383&tblId=DT_38302_2016_N011&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애유형 및 산업별 장애인 근로자 고용현황','DT_38302_2016_N016','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T3+T4+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=383&tblId=DT_38302_2016_N016","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=383&tblId=DT_38302_2016_N016","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=383&tblId=DT_38302_2016_N016&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','장애인의 사회 참여','DT_438001_AC016','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+T002+T003+T004+T005+&objL1=ALL&objL2=&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AC016","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=438&tblId=DT_438001_AC016","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=438&tblId=DT_438001_AC016&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','가까이 지내는 친구, 이웃, 지인 수 및 만남 빈도','DT_438001_AC011','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AC011","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=438&tblId=DT_438001_AC011","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=438&tblId=DT_438001_AC011&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL'),
				(1,'A','N','사회복지시설 이용 현황','DT_438001_AF005','N','{ "url":"https://kosis.kr/openapi/Param/statisticsParameterData.do?method=getList&apiKey={API_AUTH_KEY}&itmId=T001+&objL1=ALL&objL2=ALL&objL3=&objL4=&objL5=&objL6=&objL7=&objL8=&format=json&jsonVD=Y&prdSe=Y&startPrdDe={from}&endPrdDe={to}&orgId=438&tblId=DT_438001_AF005","format":"json"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=ITM&orgId=438&tblId=DT_438001_AF005","format":"xml"}','{"url":"https://kosis.kr/openapi/statisticsData.do?method=getMeta&apiKey={API_AUTH_KEY}&format=xml&type=NCD&orgId=438&tblId=DT_438001_AF005&jsonVD=Y","format":"xml"}',CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,'SYS-MANUAL');



-- #### public.stats_src_data_info Data
TRUNCATE TABLE public.stats_src_data_info CASCADE;

INSERT INTO public.stats_src_data_info (ext_api_id, ext_sys, stat_api_id, intg_tbl_id, stat_title, stat_org_id, stat_survey_name, stat_pub_dt, periodicity, collect_start_dt, collect_end_dt, stat_tbl_id, stat_tbl_name, stat_latest_chn_dt, stat_data_ref_dt, del_yn, created_at, updated_at, deleted_at, created_by, updated_by, deleted_by) 
			VALUES
				(1, 'KOSIS', 1, 'stats_dis_reg_natl_by_new', '신규등록 장애인현황', 'KOSIS_117', '「장애인현황」', '2024', '년', '2019', '2024', 'DT_11761_N010', '신규등록 장애인현황', '2025-04-18', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 2, 'stats_dis_reg_natl_by_age_type_sev_gen', '전국 연령별,장애등급별,성별 등록장애인수', 'KOSIS_117', '「장애인현황」', '2024', '년', '2019', '2024', 'DT_11761_N007', '전국 연령별,장애정도별,성별 등록장애인수', '2025-04-18', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 3, 'stats_dis_reg_sido_by_type_sev_gen', '시도별,장애유형별,장애정도별,성별 등록장애인수', 'KOSIS_117', '「장애인현황」', '2024', '년', '2019', '2024', 'DT_11761_N008', '시도별,장애유형별,장애정도별,성별 등록장애인수', '2025-04-18', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 4, 'stats_dis_life_supp_need_lvl', '일상생활 필요 지원 정도', 'KOSIS_117', '「장애인실태조사」', '2020', '3년', '1995', '2020', 'DT_11732S0110', '일상생활 필요 지원 정도', '2022-11-11', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 5, 'stats_dis_life_maincarer', '주로 지원해주는 사람의 유형', 'KOSIS_117', '「장애인실태조사」', '2020', '3년', '1995', '2020', 'DT_11732S0112', '주로 지원해주는 사람의 유형', '2022-11-11', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 6, 'stats_dis_life_primcarer', '일상생활 도와주는 사람(1순위)', 'KOSIS_438', '「장애인삶패널조사」', '2023', '년', '2018', '2023', 'DT_438001_AE001', '일상생활 도와주는 사람(1순위)', '2025-02-04', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 7, 'stats_dis_life_supp_field', '도움받는 분야', 'KOSIS_438', '「장애인삶패널조사」', '2023', '년', '2018', '2023', 'DT_438001_AE002', '도움받는 분야', '2025-02-04', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 8, 'stats_dis_hlth_medical_usage', '장애인 의료이용 현황', 'KOSIS_117', '「장애인건강보건통계」', '2022', '년', '2016', '2022', 'DT_117102_A050', '장애인 의료이용 현황', '2024-07-19', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 9, 'stats_dis_hlth_disease_cost_sub', '장애인 장애유형별 다빈도질환별 진료비현황: 소분류', 'KOSIS_117', '「장애인건강보건통계」', '2022', '년', '2016', '2022', 'DT_117102_A047', '장애인 장애유형별 다빈도질환별 진료비현황: 소분류', '2024-07-19', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 10, 'stats_dis_hlth_sport_exec_type', '장애인 생활체육 실행 유형', 'KOSIS_113', '「장애인생활체육조사」', '2024', '년', '2020', '2024', 'DT_113_STBL_1030517', '장애인 생활체육 실행 유형', '2025-03-19', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 11, 'stats_dis_hlth_exrc_best_aid', '운동 시 가장 도움이 되는 지원 사항', 'KOSIS_113', '「장애인생활체육조사」', '2021', '년', '2019', '2021', 'DT_113_STBL_1029644', '운동 시 가장 도움이 되는 지원 사항', '2023-04-21', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 12, 'stats_dis_aid_device_usage', '장애인보조기기 사용여부', 'KOSIS_438', '「장애인삶패널조사」', '2023', '년', '2018', '2023', 'DT_438001_AE023', '장애인보조기기 사용여부', '2025-02-04', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 13, 'stats_dis_aid_device_need', '장애인보조기기 필요여부', 'KOSIS_438', '「장애인삶패널조사」', '2023', '년', '2018', '2023', 'DT_438001_AE022', '장애인보조기기 필요여부', '2025-02-04', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 14, 'stats_dis_edu_voca_exec', '진로 및 직업교육 실시 여부', 'KOSIS_112', '「특수교육실태조사」', '2023', '3년', '2023', '2023', 'DT_112014_2023_01_135', '진로 및 직업교육 실시 여부', '2024-10-23', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 15, 'stats_dis_edu_voca_exec_way', '진로 및 직업교육 운영 방법', 'KOSIS_112', '「특수교육실태조사」', '2023', '3년', '2023', '2023', 'DT_112014_2023_01_137', '진로 및 직업교육 운영 방법', '2024-10-23', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 16, 'stats_dis_emp_natl', '장애인 근로자 고용현황', 'KOSIS_383', '「기업체장애인고용실태조사」', '2023', '년, 2년', '2012', '2023', 'DT_38302_2016_N008', '장애인 근로자 고용현황', '2025-03-06', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 17, 'stats_dis_emp_natl_public', '공공기관 장애인고용 현황', 'KOSIS_118', '「장애인의무고용현황」', '2023', '년', '2008', '2023', 'DT_11830_N003', '공공기관 장애인고용 현황', '2025-05-09', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 18, 'stats_dis_emp_natl_private', '민간기업 장애인고용 현황', 'KOSIS_118', '「장애인의무고용현황」', '2023', '년', '2009', '2023', 'DT_11830_N004_001', '민간기업 장애인고용 현황', '2025-05-09', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 19, 'stats_dis_emp_natl_gov_org', '정부부문 장애인고용 현황', 'KOSIS_118', '「장애인의무고용현황」', '2023', '년', '2010', '2023', 'DT_11830_N002_001', '정부부문 장애인고용 현황', '2025-05-09', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 20, 'stats_dis_emp_natl_dis_type_sev', '장애유형 및 장애정도별 장애인 근로자 고용현황', 'KOSIS_383', '「기업체장애인고용실태조사」', '2023', '년, 2년', '2012', '2023', 'DT_38302_2016_N011', '장애유형 및 장애정도별 장애인 근로자 고용현황', '2025-03-06', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 21, 'stats_dis_emp_natl_dis_type_indust', '장애유형 및 산업별 장애인 근로자 고용현황', 'KOSIS_383', '「기업체장애인고용실태조사」', '2023', '년, 2년', '2012', '2023', 'DT_38302_2016_N016', '장애유형 및 산업별 장애인 근로자 고용현황', '2025-03-06', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 22, 'stats_dis_soc_partic_freq', '장애인의 사회 참여', 'KOSIS_438', '「장애인삶패널조사」', '2023', '년', '2020', '2023', 'DT_438001_AC016', '장애인의 사회 참여', '2025-02-04', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 23, 'stats_dis_soc_contact_cntfreq', '가까이 지내는 친구, 이웃, 지인 수 및 만남 빈도', 'KOSIS_438', '「장애인삶패널조사」', '2023', '년', '2020', '2023', 'DT_438001_AC011', '가까이 지내는 친구, 이웃, 지인 수 및 만남 빈도', '2025-02-04', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', ''),
				(1, 'KOSIS', 24, 'stats_dis_fclty_welfare_usage', '사회복지시설 이용 현황', 'KOSIS_438', '「장애인삶패널조사」', '2023', '년', '2018', '2023', 'DT_438001_AF005', '사회복지시설 이용 현황', '2025-02-04', '2025-05-16', 'N'::bpchar, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,null, 'SYS-MANUAL', '', '');
							

-- # sys_stats_src_api_info.stat_api_id 를 sys_stats_src_api_info.stat_api_id로 업데이트
UPDATE stats_src_data_info sdi 
	SET stat_api_id = sai.stat_api_id
FROM sys_stats_src_api_info sai 
WHERE sdi.stat_tbl_id = sai.stat_tbl_id AND sdi.ext_api_id = sai.ext_api_id
