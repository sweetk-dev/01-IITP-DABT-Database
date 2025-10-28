import csv
import logging
import mimetypes
import os
import re
import sys
import json
import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse, unquote_to_bytes

import requests
from dotenv import load_dotenv

# ----------------------------
# Constants and configuration
# ----------------------------
EXPECTED_HEADERS = ["No", "Type", "Title", "Img-link"]
INVALID_FILENAME_CHARS = r'[<>:\\"/\|\?\*\x00-\x1F]'
MAX_TITLE_LEN = 120

CONTENT_TYPE_EXTENSION_MAP = {
	"image/jpeg": ".jpg",
	"image/jpg": ".jpg",
	"image/png": ".png",
	"image/gif": ".gif",
	"image/webp": ".webp",
	"image/bmp": ".bmp",
	"image/tiff": ".tif",
}

logger = logging.getLogger("image_downloader")
logger.setLevel(logging.INFO)
logger.addHandler(logging.StreamHandler(sys.stdout))


def parse_bool(value: str, default: bool) -> bool:
	if value is None or value == "":
		return default
	val = value.strip().lower()
	return val in ("1", "true", "yes", "y", "on")


def load_environment() -> Dict[str, str]:
	"""Load environment variables from .env and process settings.

	Behavior changes:
	- If ROOT_DIR is not set, default to the current working directory joined with 'downloads'.
	- Only URL_CSV_PATH is strictly required.
	"""
	# Try loading from current working dir and script dir
	load_dotenv(override=False)
	script_dir = Path(__file__).resolve().parent
	load_dotenv(dotenv_path=script_dir / ".env", override=False)

	env: Dict[str, str] = {}
	env["LOG_LEVEL"] = os.getenv("LOG_LEVEL", "INFO").upper()
	env["ROOT_DIR"] = (os.getenv("ROOT_DIR", "") or "").strip()
	env["THREADS"] = os.getenv("THREADS", "8").strip()
	env["URL_CSV_PATH"] = os.getenv("URL_CSV_PATH", "").strip()
	# New optional flags
	env["HEAD_CHECK"] = os.getenv("HEAD_CHECK", "false").strip()
	env["VERIFY_SSL"] = os.getenv("VERIFY_SSL", "true").strip()
	env["REQUEST_HEADERS_JSON"] = os.getenv("REQUEST_HEADERS_JSON", "").strip()

	# Validate required: only URL_CSV_PATH must be provided
	if not env["URL_CSV_PATH"]:
		raise ValueError("Missing required env var: URL_CSV_PATH")

	# Validate threads
	try:
		threads_val = int(env["THREADS"]) if env["THREADS"] else 8
		if threads_val <= 0:
			raise ValueError
		env["THREADS"] = str(threads_val)
	except ValueError:
		raise ValueError("THREADS must be a positive integer")

	# Validate CSV extension
	csv_path = Path(env["URL_CSV_PATH"]).expanduser().resolve()
	if csv_path.suffix.lower() != ".csv":
		raise SystemExit(f"ERROR: Only .csv is supported. Got: {csv_path.suffix}")

	# Determine ROOT_DIR
	if env["ROOT_DIR"]:
		root_dir = Path(env["ROOT_DIR"]).expanduser().resolve()
	else:
		# Default to CWD/downloads
		root_dir = Path.cwd() / "downloads"

	env["ROOT_DIR"] = str(root_dir)
	# Save resolved CSV path back
	env["URL_CSV_PATH"] = str(csv_path)
	return env


def configure_logging(log_level_name: str, output_dir: Path) -> Path:
	"""Configure logging to stdout and a file under CWD/logs with date-based filename."""
	level = getattr(logging, log_level_name.upper(), logging.INFO)
	logger.handlers.clear()
	logger.setLevel(level)

	# Console handler
	console_handler = logging.StreamHandler(sys.stdout)
	console_handler.setLevel(level)
	console_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
	console_handler.setFormatter(console_formatter)
	logger.addHandler(console_handler)

	# File handler in CWD/logs
	logs_dir = Path.cwd() / "logs"
	logs_dir.mkdir(parents=True, exist_ok=True)
	log_path = logs_dir / f"image_downloader_{date.today().strftime('%Y-%m-%d')}.log"

	# Ensure output dir for images exists as well
	output_dir.mkdir(parents=True, exist_ok=True)

	file_handler = logging.FileHandler(log_path, encoding="utf-8")
	file_handler.setLevel(level)
	file_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
	file_handler.setFormatter(file_formatter)
	logger.addHandler(file_handler)

	logger.debug("Logging configured. Level=%s, log_path=%s", log_level_name, log_path)
	return log_path


def sanitize_for_windows(filename_stem: str) -> str:
	"""Remove characters not allowed on Windows and trim length."""
	# Replace invalid characters with underscore
	sanitized = re.sub(INVALID_FILENAME_CHARS, "_", filename_stem)
	# Collapse whitespace
	sanitized = re.sub(r"\s+", " ", sanitized).strip()
	# Trim trailing dots or spaces
	sanitized = sanitized.rstrip(" .")
	# Truncate the title-heavy part if too long
	if len(sanitized) > 240:
		sanitized = sanitized[:240]
	return sanitized


def infer_extension_from_headers(headers: requests.structures.CaseInsensitiveDict) -> str:
	content_type = headers.get("Content-Type", "").split(";")[0].strip().lower()
	if content_type in CONTENT_TYPE_EXTENSION_MAP:
		return CONTENT_TYPE_EXTENSION_MAP[content_type]
	# Fall back to mimetypes
	ext = mimetypes.guess_extension(content_type) or ""
	# Normalize odd returns like .jpe -> .jpg
	if ext == ".jpe":
		return ".jpg"
	return ext


def infer_extension_from_mime(content_type: str) -> str:
	ct = (content_type or "").split(";")[0].strip().lower()
	if ct in CONTENT_TYPE_EXTENSION_MAP:
		return CONTENT_TYPE_EXTENSION_MAP[ct]
	return mimetypes.guess_extension(ct) or ""


def build_filename(no_val: str, type_val: str, title_val: str, ext: str, ts: datetime, index_suffix: Optional[int] = None) -> str:
	# Enforce Title length budgeting to keep final filename reasonable
	title_budget = MAX_TITLE_LEN
	title_trimmed = title_val if len(title_val) <= title_budget else title_val[:title_budget]
	stem = f"{no_val}.{type_val}-{title_trimmed}_ {ts.strftime('%Y_%m_%d_%H_%M')}"
	if index_suffix is not None and index_suffix >= 1:
		stem = f"{stem}_{index_suffix}"
	stem = sanitize_for_windows(stem)
	return stem + ext


def read_csv_rows(csv_file: Path) -> List[Dict[str, str]]:
	with csv_file.open("r", encoding="utf-8-sig", newline="") as f:
		reader = csv.DictReader(f)
		if reader.fieldnames is None:
			raise ValueError("CSV has no headers")
		# Normalize headers by exact match requirement
		if [h.strip() for h in reader.fieldnames] != EXPECTED_HEADERS:
			raise SystemExit(
				f"ERROR: CSV headers must be exactly: {', '.join(EXPECTED_HEADERS)}; got: {reader.fieldnames}"
			)
		rows: List[Dict[str, str]] = []
		for row in reader:
			# Strip whitespace/newlines/tabs in fields
			cleaned = {k: (row.get(k, "") or "").strip() for k in EXPECTED_HEADERS}
			# Collapse internal whitespace for Title
			cleaned["Title"] = re.sub(r"\s+", " ", cleaned["Title"]).strip()
			rows.append(cleaned)
		return rows


def fix_malformed_scheme(url: str) -> str:
	# Fix patterns like http:/example.com or https:/example.com -> http(s)://example.com
	return re.sub(r"^(https?):/+", r"\1://", url, flags=re.IGNORECASE)


def split_urls(raw: str) -> List[str]:
	if not raw:
		return []
	# Remove wrapping quotes and whitespace
	candidate = raw.strip().strip('"').strip("'")
	# Replace encoded newlines with real newline, then we'll split
	candidate = candidate.replace("%0A", "\n")

	urls: List[str] = []
	# 1) Extract complete data:image URLs first so we don't split on their comma
	# Pattern captures: data:image/<mime>[;base64],<payload>
	data_url_pattern = re.compile(r"data:image/[^,]+,[A-Za-z0-9+/=%]+", re.IGNORECASE)
	for m in data_url_pattern.finditer(candidate):
		data_url = m.group(0).strip()
		if data_url:
			urls.append(data_url)
	# Remove extracted data URLs from the candidate to avoid duplication; replace with spaces
	candidate_wo_data = data_url_pattern.sub(" ", candidate)

	# 2) Split the rest by common separators (newline, tabs, commas, semicolons, spaces)
	parts = re.split(r"[\n\r\t,;\s]+", candidate_wo_data)
	for part in parts:
		p = part.strip()
		if not p:
			continue
		p = fix_malformed_scheme(p)
		# Accept http(s) and data URLs (data ones already added; keep dedupe later)
		if p.startswith("http://") or p.startswith("https://") or p.lower().startswith("data:image/"):
			urls.append(p)
	# De-duplicate preserving order
	seen = set()
	unique: List[str] = []
	for u in urls:
		if u not in seen:
			seen.add(u)
			unique.append(u)
	return unique


def download_data_url(url: str, row: Dict[str, str], output_dir: Path, index_suffix: Optional[int] = None, now_provider: Optional[datetime] = None) -> Tuple[bool, Optional[str]]:
	"""Handle data:image/... URLs by decoding and saving to a file."""
	no_val = row.get("No", "")
	type_val = row.get("Type", "")
	title_val = row.get("Title", "")

	try:
		if not url.lower().startswith("data:image/"):
			return False, "Unsupported data URL"
		# Format: data:[<mediatype>][;base64],<data>
		head, _, data_part = url.partition(",")
		if not _:
			return False, "Malformed data URL"
		mime = head.split(":", 1)[1]
		is_base64 = ";base64" in mime.lower()
		content_type = mime.replace(";base64", "").strip()
		# Decode data
		if is_base64:
			payload = base64.b64decode(data_part, validate=False)
		else:
			payload = unquote_to_bytes(data_part)

		# Determine extension
		final_ext = infer_extension_from_mime(content_type) or ".img"

		# Timestamp for filename
		ts = now_provider or datetime.now()
		filename = build_filename(no_val, type_val, title_val, final_ext, ts, index_suffix=index_suffix)
		out_path = output_dir / filename
		with out_path.open("wb") as f:
			f.write(payload)
		logger.info("Saved (data URL): %s", out_path)
		return True, None
	except Exception as e:
		return False, str(e)


def download_one(url: str, row: Dict[str, str], output_dir: Path, session: requests.Session, index_suffix: Optional[int] = None, now_provider: Optional[datetime] = None, head_check: bool = False) -> Tuple[bool, Optional[str]]:
	"""Download a single image URL. Returns (success, error_message)."""
	no_val = row.get("No", "")
	type_val = row.get("Type", "")
	title_val = row.get("Title", "")

	if not url:
		return False, "Empty Img-link"

	# Handle data URLs
	if url.lower().startswith("data:image/"):
		return download_data_url(url, row, output_dir, index_suffix=index_suffix, now_provider=now_provider)

	parsed = urlparse(url)
	ext = os.path.splitext(parsed.path)[1]
	
	# Ignore .do extension (treat as no extension)
	if ext.lower() == ".do":
		ext = ""

	# Timestamp for filename
	ts = now_provider or datetime.now()

	try:
		# Optional HEAD check
		if head_check:
			try:
				head_resp = session.head(url, allow_redirects=True, timeout=(10, 30))
				head_resp.raise_for_status()
				ct = head_resp.headers.get("Content-Type", "")
				if not ct.lower().startswith("image/"):
					return False, f"HEAD non-image Content-Type: {ct}"
			except Exception as he:
				# If HEAD fails, fall back to GET to be permissive
				logger.debug("HEAD check failed, falling back to GET: %s", he)

		# Request
		resp = session.get(url, stream=True, timeout=(10, 60))
		resp.raise_for_status()

		# Determine extension if missing
		final_ext = ext if ext else infer_extension_from_headers(resp.headers)
		if not final_ext:
			# Default to .jpg for images without detectable extension
			final_ext = ".jpg"

		filename = build_filename(no_val, type_val, title_val, final_ext, ts, index_suffix=index_suffix)
		out_path = output_dir / filename

		# Write to disk
		with out_path.open("wb") as out_f:
			for chunk in resp.iter_content(chunk_size=8192):
				if chunk:
					out_f.write(chunk)

		logger.info("Saved: %s", out_path)
		return True, None
	except Exception as e:
		return False, str(e)


def write_error_rows(error_rows: List[Dict[str, str]], error_file: Path) -> None:
	# Write with UTF-8 BOM for Excel-friendliness on Windows
	with error_file.open("w", encoding="utf-8-sig", newline="") as f:
		fieldnames = EXPECTED_HEADERS + ["url_index", "url", "error"]
		writer = csv.DictWriter(f, fieldnames=fieldnames)
		writer.writeheader()
		for row in error_rows:
			writer.writerow(row)


def main() -> None:
	# Load env and basic paths
	env = load_environment()
	head_check_enabled = parse_bool(env.get("HEAD_CHECK", "false"), False)
	verify_ssl_enabled = parse_bool(env.get("VERIFY_SSL", "true"), True)
	request_headers_json = env.get("REQUEST_HEADERS_JSON", "")

	today_folder = date.today().strftime("%Y-%m-%d")
	root_dir = Path(env["ROOT_DIR"])
	output_dir = root_dir / today_folder
	log_path = configure_logging(env["LOG_LEVEL"], output_dir)

	csv_file = Path(env["URL_CSV_PATH"])  # already resolved
	logger.info("CSV: %s", csv_file)
	logger.info("Output dir: %s", output_dir)
	logger.info("Log file: %s", log_path)
	logger.info("Threads: %s", env["THREADS"])
	logger.info("HEAD_CHECK: %s", head_check_enabled)
	logger.info("VERIFY_SSL: %s", verify_ssl_enabled)

	# Read and validate CSV
	rows = read_csv_rows(csv_file)

	# Prepare HTTP session
	session = requests.Session()
	session.verify = verify_ssl_enabled
	session.headers.update({
		"User-Agent": "img-downloader/1.0 (+https://example.local)"
	})
	# Merge extra headers if provided
	if request_headers_json:
		try:
			extra = json.loads(request_headers_json)
			if isinstance(extra, dict):
				# Normalize header keys to str
				session.headers.update({str(k): str(v) for k, v in extra.items()})
				logger.info("Merged extra headers from REQUEST_HEADERS_JSON")
		except Exception as e:
			logger.warning("Failed to parse REQUEST_HEADERS_JSON: %s", e)

	# Build per-image tasks by splitting Img-link
	tasks: List[Tuple[Dict[str, str], str, int]] = []  # (row, url, index starting at 1)
	for row in rows:
		url_field = row.get("Img-link", "")
		candidates = split_urls(url_field)
		if not candidates:
			# Still record as one failed attempt with empty url
			tasks.append((row, "", 1))
			continue
		for idx, url in enumerate(candidates, start=1):
			tasks.append((row, url, idx))

	total = len(tasks)
	if total == 0:
		logger.warning("No urls found in CSV.")

	success_count = 0
	error_rows: List[Dict[str, str]] = []

	with ThreadPoolExecutor(max_workers=int(env["THREADS"])) as executor:
		future_to_task = {executor.submit(download_one, url, row, output_dir, session, idx, None, head_check_enabled): (row, url, idx) for (row, url, idx) in tasks}
		for future in as_completed(future_to_task):
			row, url, idx = future_to_task[future]
			try:
				success, err_msg = future.result()
				if success:
					success_count += 1
				else:
					err_entry = {
						"No": row.get("No", ""),
						"Type": row.get("Type", ""),
						"Title": row.get("Title", ""),
						"Img-link": row.get("Img-link", ""),
						"url_index": idx,
						"url": url,
						"error": err_msg or "unknown error",
					}
					error_rows.append(err_entry)
					logger.error("Failed [No=%s, Title=%s, idx=%s]: %s", row.get("No", ""), row.get("Title", ""), idx, err_msg)
			except Exception as e:
				err_entry = {
					"No": row.get("No", ""),
					"Type": row.get("Type", ""),
					"Title": row.get("Title", ""),
					"Img-link": row.get("Img-link", ""),
					"url_index": idx,
					"url": url,
					"error": str(e),
				}
				error_rows.append(err_entry)
				logger.exception("Unexpected failure [No=%s, Title=%s, idx=%s]", row.get("No", ""), row.get("Title", ""), idx)

	fail_count = total - success_count

	# Write error rows file if any
	error_file_path: Optional[Path] = None
	if fail_count > 0:
		csv_base = csv_file.with_suffix("")
		error_file_path = csv_base.parent / f"{csv_base.name}_errorRow.csv"
		write_error_rows(error_rows, error_file_path)

	# Summary to stdout and log
	summary_lines = [
		f"Total links: {total}",
		f"Succeeded: {success_count}",
		f"Failed: {fail_count}",
	]
	if error_file_path is not None:
		summary_lines.append(f"Error rows file: {error_file_path}")

	for line in summary_lines:
		logger.info(line)
		print(line)


if __name__ == "__main__":
	try:
		main()
	except SystemExit as e:
		# Print system-exit messages as plain output too
		msg = str(e)
		if msg:
			print(msg)
			raised = True
		sys.exit(1)
	except Exception:
		logger.exception("Fatal error")
		sys.exit(1)
