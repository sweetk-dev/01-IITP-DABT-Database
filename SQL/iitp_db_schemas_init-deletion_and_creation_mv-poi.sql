-- ## iitp DB Schemas - MV-POI Initial setup - Creation and Delete if tables exists 
-- ## ver 0.0.3 last update data : 2025.07.04
-- ## Only for PostgreSQL



-- public.mv_poi definition

-- Drop table
DROP TABLE IF EXISTS public.mv_poi;

-- DROP TABLE public.mv_poi;

CREATE TABLE public.mv_poi ( poi_id bigserial NOT NULL , language_code varchar(10) NOT NULL , title varchar(200) NOT NULL , summary text NULL , basic_info text NULL , address_code varchar(10) NULL , address_road varchar(200) NULL , address_detail varchar(200) NULL , latitude numeric(10, 8) NULL , longitude numeric(11, 8) NULL , detail_json jsonb NULL , search_filter_json jsonb NULL , publish_date timestamp NULL , update_date timestamp NULL , create_date timestamp DEFAULT CURRENT_TIMESTAMP NULL , is_deleted varchar(1) DEFAULT 'N'::bpchar NOT NULL , is_published varchar(1) DEFAULT 'N'::bpchar NOT NULL , source_organization varchar(100) NULL , source_id varchar(50) NULL , CONSTRAINT poi_pkey PRIMARY KEY (poi_id));
CREATE INDEX idx_address_code ON public.mv_poi USING btree (address_code);
CREATE INDEX idx_language_code ON public.mv_poi USING btree (language_code);
CREATE INDEX idx_location ON public.mv_poi USING btree (latitude, longitude);
CREATE INDEX idx_publish_status ON public.mv_poi USING btree (is_published, is_deleted);
CREATE INDEX idx_search_filter_json_gin ON public.mv_poi USING gin (search_filter_json);
CREATE INDEX idx_search_filter_json_path ON public.mv_poi USING gin (((search_filter_json -> 'search_filter'::text)));
COMMENT ON TABLE public.mv_poi IS '이동형 POI';

-- Column comments

COMMENT ON COLUMN public.mv_poi.poi_id IS 'POI 아이디';
COMMENT ON COLUMN public.mv_poi.language_code IS '언어 코드';
COMMENT ON COLUMN public.mv_poi.title IS '제목';
COMMENT ON COLUMN public.mv_poi.summary IS '요약 정보';
COMMENT ON COLUMN public.mv_poi.basic_info IS '기본 정보';
COMMENT ON COLUMN public.mv_poi.address_code IS '주소 코드 ';
COMMENT ON COLUMN public.mv_poi.address_road IS '도로명 주소';
COMMENT ON COLUMN public.mv_poi.address_detail IS '상세 주소';
COMMENT ON COLUMN public.mv_poi.latitude IS '위도';
COMMENT ON COLUMN public.mv_poi.longitude IS '경도';
COMMENT ON COLUMN public.mv_poi.detail_json IS '상세 정보';
COMMENT ON COLUMN public.mv_poi.search_filter_json IS '검색 필터 정보';
COMMENT ON COLUMN public.mv_poi.publish_date IS '발행일';
COMMENT ON COLUMN public.mv_poi.update_date IS '수정일';
COMMENT ON COLUMN public.mv_poi.create_date IS '생성일';
COMMENT ON COLUMN public.mv_poi.is_deleted IS '삭제 여부(Y/N)';
COMMENT ON COLUMN public.mv_poi.is_published IS '발행 여부(Y/N)';
COMMENT ON COLUMN public.mv_poi.source_organization IS '출처 기관';
COMMENT ON COLUMN public.mv_poi.source_id IS '출처 아이디';