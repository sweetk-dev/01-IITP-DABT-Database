## Image Downloader (CSV-driven)

Downloads images to a date-based folder using URLs provided in a CSV file.

### Features
- Loads configuration from `.env`
- Validates CSV extension and headers: `No,Type,Title,Img-link`
- Threaded downloads (`THREADS`)
- Windows-safe filenames: `No.Type-Title_ yyyy_mm_dd_hh_mm.<ext>`
- Saves under `ROOT_DIR/YYYY-MM-DD/`
- Records failed rows to `<csv_basename>_errorRow.csv` next to the source CSV
- Prints and logs summary: total, success, failure; shows error file path when present

### Requirements
- Python 3.9+
- Windows-compatible paths (tested on PowerShell)

### Setup
1. Create and activate a virtual environment (recommended).
2. Install dependencies:
```bash
pip install -r requirements.txt
```
3. Copy `.env.example` to `.env` and set values:
   - `LOG_LEVEL` (e.g., INFO)
   - `ROOT_DIR` (absolute path)
   - `THREADS` (e.g., 8)
   - `URL_CSV_PATH` (absolute path to your CSV)

### Run
```bash
python downloader.py
```

The log file is written to the date-based output folder: `image_downloader_YYYYMMDD.log`.

### CSV Format
- File must be `.csv`.
- Headers must be exactly: `No,Type,Title,Img-link` (case-sensitive).
- Encoding: UTF-8 (BOM ok).

### Notes
- If the URL has no file extension, the program tries to infer it from the `Content-Type` header.
- Invalid filename characters are sanitized. Extremely long titles are truncated for filesystem safety.

## SQL

`SQL/` 아래에 스키마 초기화 스크립트와 데이터 교정 마이그레이션을 둔다.

| 파일 | 용도 |
|---|---|
| `iitp_db_schemas_init-*.sql` | 도메인별 스키마 생성 (basic / poi / emp / mobility / unst / admin / webPlatform) |
| `KOSIS_stats_data_creation.sql` | KOSIS 통계 테이블 |
| `mv_poi_latlng_fix.sql` | **mv_poi 위경도 뒤바뀜 교정 + CHECK 제약** (2026-07-16, GGTOUR 적재분 51,677건) |

교정 마이그레이션은 실행 전 백업이 필요하다.

```bash
pg_dump -U postgres -d iitp_db -t mv_poi --data-only -f mv_poi_backup.sql
psql -U postgres -d iitp_db -v ON_ERROR_STOP=1 -f SQL/mv_poi_latlng_fix.sql
```
