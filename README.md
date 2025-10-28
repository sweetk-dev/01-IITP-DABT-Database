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
