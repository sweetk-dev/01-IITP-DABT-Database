-- ## iitp DB Schemas - Mobility(교통약자 이동편의) Initial setup - Creation and Delete if tables exists
-- ## ver 0.0.3 last update data : 2026.09.02
-- ## Only for PostgreSQL
-- ## 3차년도 실증(이동경로 안내) 대비 이동편의 데이터 적재용 스키마
-- ## 소스: GBIS(경기버스정보), 한국철도공사 편의시설정보 API, 국가철도공단 역사 설비 CSV(휠체어리프트·엘리베이터·화장실·승강장·이격거리), 한국사회보장정보원 장애인편의시설 API


-- ################################################
-- ## 교통 - 버스 노선/배차 메타 (GBIS)
-- ################################################

-- public.tran_bus_route_info definition
-- 안양 연관 노선(regionName 기준) 노선번호/유형/기점종점/운수사/배차간격/첫차막차.
-- 실시간 위치 및 저상버스 여부(lowPlate)는 저장하지 않음 - 서비스가 GBIS API를 직접 호출.

-- Drop table
DROP TABLE IF EXISTS public.tran_bus_route_info;

CREATE TABLE public.tran_bus_route_info (
	route_id bigint NOT NULL ,                      -- GBIS 노선ID (자연키)
	route_name varchar(60) NOT NULL ,               -- 노선번호(명)
	route_type_cd integer NULL ,                    -- 노선유형코드 (GBIS routeTypeCd)
	route_type_name varchar(60) NULL ,              -- 노선유형명
	region_name varchar(200) NULL ,                 -- 운행지역명 (예: 안양,의왕)
	admin_name varchar(100) NULL ,                  -- 관할관청명 (예: 경기도 안양시)
	start_station_id bigint NULL ,                  -- 기점 정류소ID
	start_station_name varchar(200) NULL ,          -- 기점 정류소명
	end_station_id bigint NULL ,                    -- 종점 정류소ID
	end_station_name varchar(200) NULL ,            -- 종점 정류소명
	company_name varchar(200) NULL ,                -- 운수업체명
	company_tel varchar(40) NULL ,                  -- 운수업체 전화번호
	peek_alloc integer NULL ,                       -- 평일 최소 배차시간(분)
	npeek_alloc integer NULL ,                      -- 평일 최대 배차시간(분)
	sat_peek_alloc integer NULL ,                   -- 토요일 최소 배차시간(분)
	sat_npeek_alloc integer NULL ,                  -- 토요일 최대 배차시간(분)
	sun_peek_alloc integer NULL ,                   -- 일요일 최소 배차시간(분)
	sun_npeek_alloc integer NULL ,                  -- 일요일 최대 배차시간(분)
	we_peek_alloc integer NULL ,                    -- 공휴일 최소 배차시간(분)
	we_npeek_alloc integer NULL ,                   -- 공휴일 최대 배차시간(분)
	up_first_time varchar(5) NULL ,                 -- 평일 기점 첫차
	up_last_time varchar(5) NULL ,                  -- 평일 기점 막차
	down_first_time varchar(5) NULL ,               -- 평일 종점 첫차
	down_last_time varchar(5) NULL ,                -- 평일 종점 막차
	low_bus_yn bpchar(1) NULL ,                     -- 저상버스 운영 여부 (현재 미수집, 공식 소스 확보 시 사용)
	base_dt date NULL ,                             -- 데이터 기준 일자(수집일)
	del_yn bpchar(1) DEFAULT 'N' NULL ,             -- 삭제 여부 Y/N
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,               -- 데이터 생성자, "sys_work_type" 참조
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_tran_bus_route_info PRIMARY KEY (route_id)
);
CREATE INDEX idx_tran_bus_route_info_region ON public.tran_bus_route_info USING btree (region_name);
CREATE INDEX idx_tran_bus_route_info_name ON public.tran_bus_route_info USING btree (route_name);


-- ################################################
-- ## 교통 - 버스 정류장 마스터 (GBIS 경유정류소 목록조회)
-- ################################################

-- public.tran_bus_station_info definition
-- tran_bus_route_info 에 적재된 노선의 경유정류소를 정류장 단위로 중복 제거해 보관한다.
-- 노선 메타에는 기점/종점이 "이름"만 있어 좌표 기반 경로 안내가 불가능했던 문제를 해소한다.
-- 좌표는 GBIS 가 WGS84(x=경도, y=위도)로 제공하므로 변환 없이 그대로 저장한다.

-- Drop table
DROP TABLE IF EXISTS public.tran_bus_station_info;

CREATE TABLE public.tran_bus_station_info (
	station_id bigint NOT NULL ,                    -- GBIS 정류소ID (자연키)
	mobile_no varchar(20) NULL ,                    -- 정류소번호(모바일 단축번호). 응답에 선행 공백이 있어 trim 후 저장
	station_name varchar(200) NOT NULL ,            -- 정류소명
	region_name varchar(100) NULL ,                 -- 정류소 위치 지역명 (예: 안양)
	admin_name varchar(100) NULL ,                  -- 관할관청명 (예: 경기도 안양시)
	latitude double precision NULL ,                -- 위도(WGS84, GBIS y)
	longitude double precision NULL ,               -- 경도(WGS84, GBIS x)
	center_yn bpchar(1) NULL ,                      -- 중앙차로 정류소 여부 Y/N. 교통약자 접근 동선(횡단 필요) 판단용
	district_cd integer NULL ,                      -- 관할지역 구분코드 (GBIS districtCd)
	base_dt date NULL ,                             -- 데이터 기준 일자(수집일)
	del_yn bpchar(1) DEFAULT 'N' NULL ,             -- 삭제 여부 Y/N
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,               -- 데이터 생성자, "sys_work_type" 참조
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_tran_bus_station_info PRIMARY KEY (station_id)
);
CREATE INDEX idx_tran_bus_station_info_name ON public.tran_bus_station_info USING btree (station_name);
CREATE INDEX idx_tran_bus_station_info_location ON public.tran_bus_station_info USING btree (latitude, longitude);
CREATE INDEX idx_tran_bus_station_info_region ON public.tran_bus_station_info USING btree (region_name);


-- ################################################
-- ## 교통 - 노선별 경유정류소 (GBIS 경유정류소 목록조회)
-- ################################################

-- public.tran_bus_route_station definition
-- 노선-정류장 경유 관계 및 순번. "이 정류장에서 어느 노선을 탈 수 있는가",
-- "승차 정류장이 하차 정류장보다 앞 순번인가" 를 판정하는 데 사용한다.
-- 참조 관계: route_id -> tran_bus_route_info.route_id / station_id -> tran_bus_station_info.station_id
-- 물리 FK 는 두지 않는다. 본 스키마 파일의 다른 테이블과 동일한 규약이며,
-- 노선 메타와 경유정류소가 각각 독립 배치로 갱신될 수 있어 적재 순서에 종속되지 않도록 하기 위함이다.

-- Drop table
DROP TABLE IF EXISTS public.tran_bus_route_station;

CREATE TABLE public.tran_bus_route_station (
	route_station_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL ,
	route_id bigint NOT NULL ,                      -- 노선ID (tran_bus_route_info.route_id)
	station_id bigint NOT NULL ,                    -- 정류소ID (tran_bus_station_info.station_id)
	station_seq integer NOT NULL ,                  -- 노선 내 정류소 순번 (GBIS stationSeq)
	turn_seq integer NULL ,                         -- 회차지 순번 (GBIS turnSeq)
	turn_yn bpchar(1) NULL ,                        -- 회차지 여부 Y/N (GBIS turnYn)
	base_dt date NULL ,                             -- 데이터 기준 일자(수집일)
	del_yn bpchar(1) DEFAULT 'N' NULL ,             -- 삭제 여부 Y/N
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,               -- 데이터 생성자, "sys_work_type" 참조
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_tran_bus_route_station PRIMARY KEY (route_station_id)
);
CREATE UNIQUE INDEX uidx_tran_bus_route_station_src ON public.tran_bus_route_station USING btree (route_id, station_id, station_seq);
CREATE INDEX idx_tran_bus_route_station_route ON public.tran_bus_route_station USING btree (route_id);
CREATE INDEX idx_tran_bus_route_station_station ON public.tran_bus_route_station USING btree (station_id);


-- ################################################
-- ## POI - 역 단위 교통약자 편의 현황 (한국철도공사 편의시설정보 API)
-- ################################################

-- public.poi_station_access_status definition
-- 코레일 관할 전 역(약 406건). 안양 7역(석수/관악/안양/명학/인덕원/평촌/범계)은 anyang_yn='Y'.

-- Drop table
DROP TABLE IF EXISTS public.poi_station_access_status;

CREATE TABLE public.poi_station_access_status (
	station_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL ,
	stn_cd varchar(16) NOT NULL ,                   -- 코레일 역코드
	stn_name varchar(120) NOT NULL ,                -- 역명
	line_name varchar(60) NULL ,                    -- 선명(보강용, API 미제공 시 NULL)
	elevator_cnt integer NULL ,                     -- 엘리베이터 수
	escalator_cnt integer NULL ,                    -- 에스컬레이터 수
	wheelchair_lift_cnt integer NULL ,              -- 휠체어리프트 수
	dis_slope_yn bpchar(1) NULL ,                   -- 장애인 경사로 유무 Y/N
	dis_toilet_yn bpchar(1) NULL ,                  -- 장애인 화장실 유무 Y/N
	gen_toilet_yn bpchar(1) NULL ,                  -- 일반 화장실 유무 Y/N
	nursing_room_yn bpchar(1) NULL ,                -- 수유실 유무 Y/N
	info_center_yn bpchar(1) NULL ,                 -- 종합안내센터 유무 Y/N
	latitude double precision NULL ,                -- 역 대표 위도(WGS84, 후속 보강)
	longitude double precision NULL ,               -- 역 대표 경도(WGS84, 후속 보강)
	anyang_yn bpchar(1) DEFAULT 'N' NOT NULL ,      -- 안양 관할/인접 실증 대상 역 여부
	base_dt date NULL ,                             -- 데이터 기준 일자
	del_yn bpchar(1) DEFAULT 'N' NULL ,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_poi_station_access_status PRIMARY KEY (station_id)
);
CREATE UNIQUE INDEX uidx_poi_station_access_status_stn_cd ON public.poi_station_access_status USING btree (stn_cd);
CREATE INDEX idx_poi_station_access_status_name ON public.poi_station_access_status USING btree (stn_name);
CREATE INDEX idx_poi_station_access_status_anyang ON public.poi_station_access_status USING btree (anyang_yn);


-- ################################################
-- ## POI - 설비 단위 휠체어리프트 상세 (국가철도공단 CSV)
-- ################################################

-- public.poi_station_wheelchair_lift definition
-- 수도권 1/4호선 휠체어리프트 설비별 상세위치/제원. 분기 1회 파일 갱신 확인.

-- Drop table
DROP TABLE IF EXISTS public.poi_station_wheelchair_lift;

CREATE TABLE public.poi_station_wheelchair_lift (
	lift_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL ,
	oper_org varchar(60) NULL ,                     -- 철도운영기관명 (예: 코레일)
	line_name varchar(60) NOT NULL ,                -- 선명 (예: 1호선)
	stn_name varchar(120) NOT NULL ,                -- 역명
	mng_no varchar(20) NOT NULL ,                   -- 관리번호
	exit_no varchar(20) NULL ,                      -- 출입구번호 (내부 설치 시 "내부")
	detail_loc varchar(300) NULL ,                  -- 상세위치 설명
	length_mm integer NULL ,                        -- 길이(mm)
	width_mm integer NULL ,                         -- 폭(mm)
	start_floor varchar(20) NULL ,                  -- 시작층
	end_floor varchar(20) NULL ,                    -- 종료층
	base_dt date NULL ,                             -- 데이터 기준 일자(파일 기준일)
	del_yn bpchar(1) DEFAULT 'N' NULL ,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_poi_station_wheelchair_lift PRIMARY KEY (lift_id)
);
CREATE UNIQUE INDEX uidx_poi_station_wheelchair_lift_src ON public.poi_station_wheelchair_lift USING btree (line_name, stn_name, mng_no);
CREATE INDEX idx_poi_station_wheelchair_lift_stn ON public.poi_station_wheelchair_lift USING btree (stn_name);


-- ################################################
-- ## POI - 설비 단위 엘리베이터 상세 (국가철도공단 CSV, v1.3.0)
-- ################################################

-- public.poi_station_elevator_unit definition
-- 수도권 1/4호선 엘리베이터 설비별 출입구·상세위치·정원. 연 1회 파일 갱신(노선 파일 단위 전체 교체).
-- poi_station_access_status.elevator_cnt 는 개수뿐이라 "어느 출입구 엘리베이터인지"를 안내하려면 이 표가 필요하다.

-- Drop table
DROP TABLE IF EXISTS public.poi_station_elevator_unit;

CREATE TABLE public.poi_station_elevator_unit (
	ev_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL ,
	oper_org varchar(60) NULL ,                     -- 철도운영기관명 (예: 코레일)
	line_name varchar(60) NOT NULL ,                -- 선명 (예: 1호선)
	stn_name varchar(120) NOT NULL ,                -- 역명
	unit_seq integer NOT NULL ,                     -- 역 내 설비 순번 (파일 등장 순, 적재 시 부여)
	exit_no varchar(20) NULL ,                      -- 출입구번호 (내부 설치 시 "내부")
	detail_loc varchar(300) NULL ,                  -- 상세위치 설명
	capacity_person integer NULL ,                  -- 정원(인원)
	capacity_kg integer NULL ,                      -- 정원(중량 kg)
	base_dt date NULL ,                             -- 데이터 기준 일자(파일 기준일)
	del_yn bpchar(1) DEFAULT 'N' NULL ,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_poi_station_elevator_unit PRIMARY KEY (ev_id)
);
CREATE UNIQUE INDEX uidx_poi_station_elevator_unit_src ON public.poi_station_elevator_unit USING btree (line_name, stn_name, unit_seq);
CREATE INDEX idx_poi_station_elevator_unit_stn ON public.poi_station_elevator_unit USING btree (stn_name);


-- ################################################
-- ## POI - 설비 단위 화장실 상세 (국가철도공단 CSV, v1.3.0)
-- ################################################

-- public.poi_station_toilet_unit definition
-- 수도권 1/4호선 화장실·장애인화장실 위치(게이트 안/밖·출구·상세위치). disabled_yn='Y' 가 장애인화장실 파일분.
-- 코레일 편의시설 API 가 응답하지 않는 역(안양 7역 중 6역)의 dis_toilet_yn NULL 을 이 표로 보완한다.

-- Drop table
DROP TABLE IF EXISTS public.poi_station_toilet_unit;

CREATE TABLE public.poi_station_toilet_unit (
	toilet_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL ,
	oper_org varchar(60) NULL ,                     -- 철도운영기관명
	line_name varchar(60) NOT NULL ,                -- 선명
	stn_name varchar(120) NOT NULL ,                -- 역명
	disabled_yn bpchar(1) DEFAULT 'N' NOT NULL ,    -- 장애인화장실 여부 (Y: 장애인화장실 파일, N: 일반 화장실 파일)
	unit_seq integer NOT NULL ,                     -- 역·구분 내 순번 (파일 등장 순, 적재 시 부여)
	ground_dv varchar(10) NULL ,                    -- 지상구분 (지상/지하)
	floor_no varchar(20) NULL ,                     -- 역층
	gate_inout varchar(10) NULL ,                   -- 게이트내외 (내/외)
	exit_no varchar(20) NULL ,                      -- 출구번호
	detail_loc varchar(300) NULL ,                  -- 상세위치
	toilet_kind varchar(30) NULL ,                  -- 화장실구분 (남자/여자/장애인 등 원문)
	base_dt date NULL ,                             -- 데이터 기준 일자(파일 기준일)
	del_yn bpchar(1) DEFAULT 'N' NULL ,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_poi_station_toilet_unit PRIMARY KEY (toilet_id)
);
CREATE UNIQUE INDEX uidx_poi_station_toilet_unit_src ON public.poi_station_toilet_unit USING btree (line_name, stn_name, disabled_yn, unit_seq);
CREATE INDEX idx_poi_station_toilet_unit_stn ON public.poi_station_toilet_unit USING btree (stn_name);


-- ################################################
-- ## POI - 승강장 정보 + 열차 이격거리 요약 (국가철도공단 CSV, v1.3.0)
-- ################################################

-- public.poi_station_platform definition
-- 수도권 1/4호선 승강장별 상하행·지상구분·역층·승강장연결·스크린도어·안전발판 유무 (승강장 정보 파일)
-- + 승강장이격거리 파일(출입문별 안전거리 cm)을 승강장 단위로 요약(min/max/avg, 출입문 수).
-- 휠체어 승차 시 발판 필요 여부·틈 크기를 안내하기 위한 자료. 연 1회 갱신.

-- Drop table
DROP TABLE IF EXISTS public.poi_station_platform;

CREATE TABLE public.poi_station_platform (
	platform_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL ,
	oper_org varchar(60) NULL ,                     -- 철도운영기관명
	line_name varchar(60) NOT NULL ,                -- 선명
	stn_name varchar(120) NOT NULL ,                -- 역명
	platform_no varchar(10) NOT NULL ,              -- 승강장번호
	updown varchar(10) NULL ,                       -- 상하행
	ground_dv varchar(10) NULL ,                    -- 지상구분
	floor_no varchar(20) NULL ,                     -- 역층
	platform_connect_yn bpchar(1) NULL ,            -- 승강장연결 여부 Y/N
	screen_door_yn bpchar(1) NULL ,                 -- 스크린도어 유무 Y/N
	safety_plate_yn bpchar(1) NULL ,                -- 안전발판 유무 Y/N
	gap_min_cm numeric(6,1) NULL ,                  -- 열차 이격거리 최소(cm)
	gap_max_cm numeric(6,1) NULL ,                  -- 열차 이격거리 최대(cm)
	gap_avg_cm numeric(6,1) NULL ,                  -- 열차 이격거리 평균(cm)
	door_cnt integer NULL ,                         -- 이격거리 측정 출입문 수
	base_dt date NULL ,                             -- 데이터 기준 일자(파일 기준일)
	del_yn bpchar(1) DEFAULT 'N' NULL ,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_poi_station_platform PRIMARY KEY (platform_id)
);
CREATE UNIQUE INDEX uidx_poi_station_platform_src ON public.poi_station_platform USING btree (line_name, stn_name, platform_no);
CREATE INDEX idx_poi_station_platform_stn ON public.poi_station_platform USING btree (stn_name);


-- ################################################
-- ## POI - 건물 장애인 편의시설 (한국사회보장정보원 API)
-- ################################################

-- public.poi_facility_accessibility definition
-- 전국장애인편의시설 표준 기반. 1차 적재 범위는 안양시 소재 시설(주소 필터).

-- Drop table
DROP TABLE IF EXISTS public.poi_facility_accessibility;

CREATE TABLE public.poi_facility_accessibility (
	facl_id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL ,
	facl_inf_id varchar(30) NOT NULL ,              -- 사회보장정보원 시설정보ID (faclInfId)
	wfclt_id varchar(30) NULL ,                     -- 기구표 조회용 관리시설ID (형식 상이, 매핑 확인 후 채움)
	facl_name varchar(200) NOT NULL ,               -- 시설명
	facl_type varchar(100) NULL ,                   -- 시설유형 (faclTyCd)
	addr varchar(600) NULL ,                        -- 소재지 주소 (lcMnad)
	latitude double precision NULL ,                -- 위도(WGS84)
	longitude double precision NULL ,               -- 경도(WGS84)
	estb_date varchar(10) NULL ,                    -- 설치/등록일 (YYYYMMDD)
	elevator_yn bpchar(1) NULL ,                    -- 승강기 Y/N (기구표 파싱)
	dis_toilet_yn bpchar(1) NULL ,                  -- 장애인사용가능화장실 Y/N
	dis_parking_yn bpchar(1) NULL ,                 -- 장애인전용주차구역 Y/N
	entrance_ramp_yn bpchar(1) NULL ,               -- 주출입구 높이차이 제거 Y/N
	entrance_door_yn bpchar(1) NULL ,               -- 주출입구(문) Y/N
	approach_road_yn bpchar(1) NULL ,               -- 주출입구 접근로 Y/N
	eval_info_raw varchar(1000) NULL ,              -- 기구표 원문(콤마 구분 목록)
	base_dt date NULL ,                             -- 데이터 기준 일자
	del_yn bpchar(1) DEFAULT 'N' NULL ,
	created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL ,
	updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL ,
	deleted_at timestamptz NULL ,
	created_by varchar(40) NOT NULL ,
	updated_by varchar(40) NULL ,
	deleted_by varchar(40) NULL ,
	CONSTRAINT pkey_poi_facility_accessibility PRIMARY KEY (facl_id)
);
CREATE UNIQUE INDEX uidx_poi_facility_accessibility_inf_id ON public.poi_facility_accessibility USING btree (facl_inf_id);
CREATE INDEX idx_poi_facility_accessibility_location ON public.poi_facility_accessibility USING btree (latitude, longitude);
CREATE INDEX idx_poi_facility_accessibility_type ON public.poi_facility_accessibility USING btree (facl_type);
