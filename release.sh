#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

GRADLE_FILE="android/app/build.gradle.kts"

flutter build appbundle --release --dart-define=ANTHROPIC_API_KEY=YOUR_API_KEY_HERE

python3 - <<'PY'
import re
from pathlib import Path

gradle_file = Path("android/app/build.gradle.kts")
text = gradle_file.read_text(encoding="utf-8")

vc_match = re.search(r'(?m)^\s*versionCode\s*=\s*(\d+)\s*$', text)
if not vc_match:
    raise SystemExit("versionCode not found in build.gradle.kts")

vn_match = re.search(
    r'(?m)^\s*versionName\s*=\s*"([0-9]+(?:\.[0-9]+)?)',
    text,
)
if not vn_match:
    raise SystemExit("versionName not found in build.gradle.kts")

old_vc = int(vc_match.group(1))
old_vn = vn_match.group(1).strip()

new_vc = old_vc + 1

try:
    vn_float = float(old_vn)
except ValueError as e:
    raise SystemExit(f"versionName is not a float: {old_vn}") from e

new_vn = f"{vn_float + 0.1:.1f}"

text = re.sub(
    r'(?m)^(\s*versionCode\s*=\s*)\d+(\s*)$',
    rf"\g<1>{new_vc}\g<2>",
    text,
)
text = re.sub(
    r'(?m)^(\s*versionName\s*=\s*).*$',
    rf'\g<1>"{new_vn}"',
    text,
)

gradle_file.write_text(text, encoding="utf-8")

print(f"Updated versionCode: {old_vc} -> {new_vc}")
print(f"Updated versionName: {old_vn} -> {new_vn}")
PY

aab_path="$(ls -1 build/app/outputs/bundle/release/*.aab 2>/dev/null | sort | tail -n 1 || true)"
if [[ -z "$aab_path" ]]; then
  echo "Release AAB not found."
  exit 1
fi

echo "$aab_path"

