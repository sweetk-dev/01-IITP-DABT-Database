-- ## iitp DB Schemas - Initial setup - Tirgger Creation and Setting
-- ## ver 0.0.2 last update data : 2025.05.22
-- ## trigger 함수 생성 및 trigger 생성 설정

-- ################################################
-- ## 이미 존재하는 trigger 함수 및 trigger 삭제
-- ################################################

-- ## update_modified_column() 를 사용하는 trigger 먼저 삭제

-- 시스템 테이블
DROP TRIGGER IF EXISTS trg_update_sys_common_code ON sys_common_code;
DROP TRIGGER IF EXISTS trg_update_sys_ext_api_info ON sys_ext_api_info;

-- 통계 원본 및 연계 테이블
DROP TRIGGER IF EXISTS trg_update_stats_kosis_origin_data ON stats_kosis_origin_data;
DROP TRIGGER IF EXISTS trg_update_stats_kosis_metadata_code ON stats_kosis_metadata_code;
DROP TRIGGER IF EXISTS trg_update_stats_src_data_info ON stats_src_data_info;

-- 등록 장애 통계
DROP TRIGGER IF EXISTS trg_update_stats_dis_reg_natl_by_new ON stats_dis_reg_natl_by_new;
DROP TRIGGER IF EXISTS trg_update_stats_dis_reg_natl_by_age_type_sev_gen ON stats_dis_reg_natl_by_age_type_sev_gen;
DROP TRIGGER IF EXISTS trg_update_stats_dis_reg_sido_by_age_type_sev_gen ON stats_dis_reg_sido_by_age_type_sev_gen;

-- 생활 실태
DROP TRIGGER IF EXISTS trg_update_stats_dis_life_supp_need_lvl ON stats_dis_life_supp_need_lvl;
DROP TRIGGER IF EXISTS trg_update_stats_dis_life_maincarer ON stats_dis_life_maincarer;
DROP TRIGGER IF EXISTS trg_update_stats_dis_life_primcarer ON stats_dis_life_primcarer;
DROP TRIGGER IF EXISTS trg_update_stats_dis_life_supp_field ON stats_dis_life_supp_field;

-- 건강
DROP TRIGGER IF EXISTS trg_update_stats_dis_hlth_medical_usage ON stats_dis_hlth_medical_usage;
DROP TRIGGER IF EXISTS trg_update_stats_dis_hlth_disease_cost_sub ON stats_dis_hlth_disease_cost_sub;
DROP TRIGGER IF EXISTS trg_update_stats_dis_hlth_sport_exec_type ON stats_dis_hlth_sport_exec_type;
DROP TRIGGER IF EXISTS trg_update_stats_dis_hlth_exrc_best_aid ON stats_dis_hlth_exrc_best_aid;

-- 보조기기
DROP TRIGGER IF EXISTS trg_update_stats_dis_aid_device_usage ON stats_dis_aid_device_usage;
DROP TRIGGER IF EXISTS trg_update_stats_dis_aid_device_need ON stats_dis_aid_device_need;

-- 교육 및 직업
DROP TRIGGER IF EXISTS trg_update_stats_dis_edu_voca_exec ON stats_dis_edu_voca_exec;
DROP TRIGGER IF EXISTS trg_update_stats_dis_edu_voca_exec_way ON stats_dis_edu_voca_exec_way;

-- 고용
DROP TRIGGER IF EXISTS trg_update_stats_dis_emp_natl ON stats_dis_emp_natl;
DROP TRIGGER IF EXISTS trg_update_stats_dis_emp_natl_public ON stats_dis_emp_natl_public;
DROP TRIGGER IF EXISTS trg_update_stats_dis_emp_natl_private ON stats_dis_emp_natl_private;
DROP TRIGGER IF EXISTS trg_update_stats_dis_emp_natl_gov_org ON stats_dis_emp_natl_gov_org;
DROP TRIGGER IF EXISTS trg_update_stats_dis_emp_natl_dis_type_sev ON stats_dis_emp_natl_dis_type_sev;
DROP TRIGGER IF EXISTS trg_update_stats_dis_emp_natl_dis_type_indust ON stats_dis_emp_natl_dis_type_indust;

-- 사회참여
DROP TRIGGER IF EXISTS trg_update_stats_dis_soc_partic_freq ON stats_dis_soc_partic_freq;
DROP TRIGGER IF EXISTS trg_update_stats_dis_soc_contact_cntfreq ON stats_dis_soc_contact_cntfreq;

-- 복지시설 이용
DROP TRIGGER IF EXISTS trg_update_stats_dis_fclty_welfare_usage ON stats_dis_fclty_welfare_usage;

-- 이동형 POI 
-- DROP TRIGGER IF EXISTS trg_update_mv_poi ON mv_poi;


-- ## update_modified_column() trigger 먼저 삭제
DROP FUNCTION IF EXISTS update_modified_column();


-- ################################################
-- ## trigger 함수 생성
-- ################################################

CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;



-- ################################################
-- ## trigger 생성 및 설정
-- ################################################

-- 시스템 테이블
CREATE TRIGGER trg_update_sys_common_code
BEFORE INSERT OR UPDATE ON sys_common_code
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_sys_ext_api_info
BEFORE INSERT OR UPDATE ON sys_ext_api_info
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 통계 원본 및 연계 테이블
CREATE TRIGGER trg_update_stats_kosis_origin_data
BEFORE INSERT OR UPDATE ON stats_kosis_origin_data
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_kosis_metadata_code
BEFORE INSERT OR UPDATE ON stats_kosis_metadata_code
FOR EACH ROW EXECUTE FUNCTION update_modified_column();


CREATE TRIGGER trg_update_stats_src_data_info
BEFORE INSERT OR UPDATE ON stats_src_data_info
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 등록 장애 통계
CREATE TRIGGER trg_update_stats_dis_reg_natl_by_new
BEFORE INSERT OR UPDATE ON stats_dis_reg_natl_by_new
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_reg_natl_by_age_type_sev_gen
BEFORE INSERT OR UPDATE ON stats_dis_reg_natl_by_age_type_sev_gen
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_reg_sido_by_age_type_sev_gen
BEFORE INSERT OR UPDATE ON stats_dis_reg_sido_by_age_type_sev_gen
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 생활 실태
CREATE TRIGGER trg_update_stats_dis_life_supp_need_lvl
BEFORE INSERT OR UPDATE ON stats_dis_life_supp_need_lvl
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_life_maincarer
BEFORE INSERT OR UPDATE ON stats_dis_life_maincarer
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_life_primcarer
BEFORE INSERT OR UPDATE ON stats_dis_life_primcarer
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_life_supp_field
BEFORE INSERT OR UPDATE ON stats_dis_life_supp_field
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 건강
CREATE TRIGGER trg_update_stats_dis_hlth_medical_usage
BEFORE INSERT OR UPDATE ON stats_dis_hlth_medical_usage
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_hlth_disease_cost_sub
BEFORE INSERT OR UPDATE ON stats_dis_hlth_disease_cost_sub
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_hlth_sport_exec_type
BEFORE INSERT OR UPDATE ON stats_dis_hlth_sport_exec_type
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_hlth_exrc_best_aid
BEFORE INSERT OR UPDATE ON stats_dis_hlth_exrc_best_aid
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 보조기기
CREATE TRIGGER trg_update_stats_dis_aid_device_usage
BEFORE INSERT OR UPDATE ON stats_dis_aid_device_usage
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_aid_device_need
BEFORE INSERT OR UPDATE ON stats_dis_aid_device_need
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 교육 및 직업
CREATE TRIGGER trg_update_stats_dis_edu_voca_exec
BEFORE INSERT OR UPDATE ON stats_dis_edu_voca_exec
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_edu_voca_exec_way
BEFORE INSERT OR UPDATE ON stats_dis_edu_voca_exec_way
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 고용
CREATE TRIGGER trg_update_stats_dis_emp_natl
BEFORE INSERT OR UPDATE ON stats_dis_emp_natl
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_emp_natl_public
BEFORE INSERT OR UPDATE ON stats_dis_emp_natl_public
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_emp_natl_private
BEFORE INSERT OR UPDATE ON stats_dis_emp_natl_private
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_emp_natl_gov_org
BEFORE INSERT OR UPDATE ON stats_dis_emp_natl_gov_org
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_emp_natl_dis_type_sev
BEFORE INSERT OR UPDATE ON stats_dis_emp_natl_dis_type_sev
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_emp_natl_dis_type_indust
BEFORE INSERT OR UPDATE ON stats_dis_emp_natl_dis_type_indust
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 사회참여
CREATE TRIGGER trg_update_stats_dis_soc_partic_freq
BEFORE INSERT OR UPDATE ON stats_dis_soc_partic_freq
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_update_stats_dis_soc_contact_cntfreq
BEFORE INSERT OR UPDATE ON stats_dis_soc_contact_cntfreq
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 복지시설 이용
CREATE TRIGGER trg_update_stats_dis_fclty_welfare_usage
BEFORE INSERT OR UPDATE ON stats_dis_fclty_welfare_usage
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 이동형 POI
-- CREATE TRIGGER trg_update_mv_poi
-- BEFORE INSERT OR UPDATE ON mv_poi
-- FOR EACH ROW EXECUTE FUNCTION update_modified_column();



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