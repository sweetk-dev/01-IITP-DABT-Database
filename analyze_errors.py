import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, List

EXPECTED_HEADERS = ["No", "Type", "Title", "Img-link", "error"]


def read_error_rows(csv_path: Path) -> List[Dict[str, str]]:
	rows: List[Dict[str, str]] = []
	with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
		reader = csv.DictReader(f)
		if reader.fieldnames is None:
			raise SystemExit("ERROR: CSV has no header")
		if any(h not in reader.fieldnames for h in EXPECTED_HEADERS):
			raise SystemExit(f"ERROR: CSV must include headers: {EXPECTED_HEADERS}")
		for r in reader:
			rows.append({h: (r.get(h, "") or "").strip() for h in EXPECTED_HEADERS})
	return rows


def main() -> None:
	if len(sys.argv) < 2:
		print("Usage: python analyze_errors.py <path_to_errorRow.csv>")
		sys.exit(1)

	csv_path = Path(sys.argv[1]).expanduser().resolve()
	if not csv_path.exists():
		raise SystemExit(f"ERROR: File not found: {csv_path}")

	rows = read_error_rows(csv_path)
	filtered = [r for r in rows if r.get("error", "") and r["error"] != "Empty Img-link"]

	# Normalize error messages lightly (strip spaces)
	for r in filtered:
		r["error"] = r["error"].strip()

	counter = Counter(r["error"] for r in filtered)

	# Map error -> sample rows (up to 5 samples)
	samples: Dict[str, List[Dict[str, str]]] = defaultdict(list)
	for r in filtered:
		key = r["error"]
		if len(samples[key]) < 5:
			samples[key].append({"No": r["No"], "Title": r["Title"], "Img-link": r["Img-link"]})

	print(f"Total rows in file: {len(rows)}")
	print(f"Non-empty errors: {len(filtered)}")
	print("")
	print("Distinct failure reasons (excluding 'Empty Img-link'):")
	for err, cnt in counter.most_common():
		print(f"- {cnt} x {err}")
		for s in samples[err]:
			no = s["No"]
			title = s["Title"]
			print(f"    sample -> No={no}, Title={title}")

	# Save a compact summary CSV next to the file
	summary_csv = csv_path.with_name(csv_path.stem + "_summary.csv")
	with summary_csv.open("w", encoding="utf-8-sig", newline="") as f:
		writer = csv.writer(f)
		writer.writerow(["reason", "count"]) 
		for err, cnt in counter.most_common():
			writer.writerow([err, cnt])

	print("")
	print(f"Summary saved: {summary_csv}")


if __name__ == "__main__":
	main()
