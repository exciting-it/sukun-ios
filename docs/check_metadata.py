"""Checks the App Store character limits in APP_STORE_METADATA.md. Usage: python3 docs/check_metadata.py"""
import pathlib
import re
import sys

LIMITS = {
    "Name": 30, "Subtitle": 30, "Untertitel": 30,
    "Promotional text": 170, "Werbetext": 170,
    "Keywords": 100, "Schlüsselwörter": 100,
    "Description": 4000, "Beschreibung": 4000,
}

text = (pathlib.Path(__file__).parent / "APP_STORE_METADATA.md").read_text()
failed = False
for lang_block in re.split(r"^## ", text, flags=re.M)[1:]:
    lang = lang_block.splitlines()[0]
    for field, body in re.findall(r"^### (.+?)\n(.*?)(?=^### |\Z)", lang_block, flags=re.S | re.M):
        if field not in LIMITS:
            continue
        value = body.strip()
        n = len(value)
        ok = n <= LIMITS[field]
        if field in ("Keywords", "Schlüsselwörter") and " " in value:
            ok = False
        failed |= not ok
        print(f"{'ok  ' if ok else 'FAIL'} {lang:14} {field:18} {n:5}/{LIMITS[field]}")
sys.exit(1 if failed else 0)
