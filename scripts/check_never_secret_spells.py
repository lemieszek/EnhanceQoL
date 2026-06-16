#!/usr/bin/env python3
"""Check Wago SpellMisc never-secret attributes against a checked-in baseline."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import sys
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_URL = "https://wago.tools/db2/spellmisc/csv"
DEFAULT_BASELINE = "docs/data/wago_spellmisc_never_secret_baseline.json"

ATTRIBUTES_COLUMN = "Attributes_15"
SPELL_ID_COLUMN = "SpellID"
RECORD_ID_COLUMN = "ID"

FLAGS = {
    "aura_never_secret": {
        "bit": 0x04000000,
        "label": "Aura never secret",
        "note": "Usually relevant for aura filtering / Unit Frame ignore handling.",
    },
    "cd_never_secret": {
        "bit": 0x80000000,
        "label": "Cooldown never secret",
        "note": "Usually relevant for cooldown / aura visibility review.",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_URL, help="SpellMisc CSV URL. Defaults to Wago's latest SpellMisc CSV.")
    parser.add_argument("--csv", dest="csv_path", help="Use an already downloaded SpellMisc CSV instead of downloading.")
    parser.add_argument("--baseline", default=DEFAULT_BASELINE, help="JSON baseline path.")
    parser.add_argument("--write-baseline", action="store_true", help="Write the current CSV result as the new baseline.")
    parser.add_argument("--report", default="never-secret-spellmisc-report.md", help="Markdown report path.")
    return parser.parse_args()


def read_csv_bytes(args: argparse.Namespace) -> tuple[str, dict[str, str], bytes]:
    if args.csv_path:
        path = Path(args.csv_path)
        return str(path), {}, path.read_bytes()

    request = urllib.request.Request(args.url, headers={"User-Agent": "EnhanceQoL never-secret spell checker"})
    with urllib.request.urlopen(request, timeout=120) as response:
        headers = {key: value for key, value in response.headers.items()}
        return args.url, headers, response.read()


def parse_int(value: str | None) -> int:
    if value is None:
        return 0
    value = value.strip()
    if not value:
        return 0
    return int(value, 10)


def collect_flags(csv_text: str) -> dict[str, Any]:
    reader = csv.DictReader(csv_text.splitlines())
    result: dict[str, Any] = {
        "row_count": 0,
        "max_record_id": 0,
        "max_spell_id": 0,
        "flags": {
            key: {
                "spell_ids": set(),
                "record_ids_by_spell_id": {},
            }
            for key in FLAGS
        },
    }

    for row in reader:
        result["row_count"] += 1
        record_id = parse_int(row.get(RECORD_ID_COLUMN))
        spell_id = parse_int(row.get(SPELL_ID_COLUMN))
        attributes_15 = parse_int(row.get(ATTRIBUTES_COLUMN)) & 0xFFFFFFFF
        result["max_record_id"] = max(result["max_record_id"], record_id)
        result["max_spell_id"] = max(result["max_spell_id"], spell_id)
        if spell_id <= 0:
            continue

        for key, flag in FLAGS.items():
            if attributes_15 & int(flag["bit"]):
                flag_result = result["flags"][key]
                flag_result["spell_ids"].add(spell_id)
                records = flag_result["record_ids_by_spell_id"].setdefault(str(spell_id), set())
                if record_id > 0:
                    records.add(record_id)

    for flag_result in result["flags"].values():
        flag_result["spell_ids"] = sorted(flag_result["spell_ids"])
        flag_result["record_ids_by_spell_id"] = {
            spell_id: sorted(record_ids)
            for spell_id, record_ids in sorted(flag_result["record_ids_by_spell_id"].items(), key=lambda item: int(item[0]))
        }

    return result


def build_snapshot(source: str, headers: dict[str, str], collected: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "source": source,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "source_headers": {
            key: headers[key]
            for key in ("ETag", "Last-Modified", "Content-Length")
            if key in headers
        },
        "csv_stats": {
            "row_count": collected["row_count"],
            "max_record_id": collected["max_record_id"],
            "max_spell_id": collected["max_spell_id"],
        },
        "attributes_15": {
            key: {
                "label": flag["label"],
                "bit_hex": f"0x{int(flag['bit']):08X}",
                "spell_ids": collected["flags"][key]["spell_ids"],
                "record_ids_by_spell_id": collected["flags"][key]["record_ids_by_spell_id"],
            }
            for key, flag in FLAGS.items()
        },
    }


def load_baseline(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def spell_ids(snapshot: dict[str, Any], key: str) -> set[int]:
    return {int(value) for value in snapshot.get("attributes_15", {}).get(key, {}).get("spell_ids", [])}


def write_report(path: Path, baseline: dict[str, Any] | None, current: dict[str, Any]) -> bool:
    changed = False
    lines: list[str] = []
    lines.append("# Wago SpellMisc Never-Secret Check")
    lines.append("")
    lines.append(f"- Source: `{current.get('source', DEFAULT_URL)}`")
    lines.append(f"- Checked at: `{current.get('generated_at_utc', '')}`")
    stats = current.get("csv_stats", {})
    lines.append(f"- Rows: `{stats.get('row_count', 0)}`")
    lines.append(f"- Max SpellID: `{stats.get('max_spell_id', 0)}`")
    if current.get("source_headers"):
        header_bits = ", ".join(f"{key}: `{value}`" for key, value in current["source_headers"].items())
        lines.append(f"- Source headers: {header_bits}")
    lines.append("")

    if not baseline:
        lines.append("No baseline exists yet. Run with `--write-baseline` after reviewing the current output.")
        changed = True
    else:
        base_stats = baseline.get("csv_stats", {})
        lines.append(f"- Baseline rows: `{base_stats.get('row_count', 0)}`")
        lines.append(f"- Baseline max SpellID: `{base_stats.get('max_spell_id', 0)}`")
        lines.append("")

    for key, flag in FLAGS.items():
        current_ids = spell_ids(current, key)
        baseline_ids = spell_ids(baseline or {}, key)
        added = sorted(current_ids - baseline_ids)
        removed = sorted(baseline_ids - current_ids)
        changed = changed or bool(added or removed)
        lines.append(f"## {flag['label']} (`0x{int(flag['bit']):08X}`)")
        lines.append("")
        lines.append(flag["note"])
        lines.append("")
        lines.append(f"- Current count: `{len(current_ids)}`")
        if baseline is not None:
            lines.append(f"- Baseline count: `{len(baseline_ids)}`")
        lines.append(f"- Added: `{len(added)}`")
        if added:
            lines.append("")
            lines.append("Added SpellIDs:")
            for spell_id in added:
                lines.append(f"- `{spell_id}`")
        lines.append(f"- Removed: `{len(removed)}`")
        if removed:
            lines.append("")
            lines.append("Removed SpellIDs:")
            for spell_id in removed:
                lines.append(f"- `{spell_id}`")
        lines.append("")

    if changed:
        lines.append("## Review checklist")
        lines.append("")
        lines.append("- Look up added SpellIDs on Wowhead or Wago to identify player-facing names.")
        lines.append("- For Aura never secret, decide whether entries belong in `UF_GlobalAuraIgnore.lua`, are healer-placement relevant, or should be ignored as DNT/internal.")
        lines.append("- For CD never secret, decide whether any Cooldown Panels or cooldown visibility logic needs a new allow/block entry.")
        lines.append("- If accepted, update the addon data and then regenerate this baseline with `--write-baseline`.")
        lines.append("")
    else:
        lines.append("No differences from baseline.")
        lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")
    return changed


def main() -> int:
    args = parse_args()
    source, headers, csv_bytes = read_csv_bytes(args)
    current = build_snapshot(source, headers, collect_flags(csv_bytes.decode("utf-8-sig")))
    baseline_path = Path(args.baseline)

    if args.write_baseline:
        baseline_path.parent.mkdir(parents=True, exist_ok=True)
        baseline_path.write_text(json.dumps(current, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"Wrote baseline: {baseline_path}")
        return 0

    baseline = load_baseline(baseline_path) if baseline_path.exists() else None
    changed = write_report(Path(args.report), baseline, current)
    if changed:
        print(f"Never-secret SpellMisc differences detected. See {args.report}.", file=sys.stderr)
        return 1
    print(f"Never-secret SpellMisc baseline is current. Report: {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
