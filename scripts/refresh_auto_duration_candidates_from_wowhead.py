#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOLTIP_URL = "https://nether.wowhead.com/tooltip/item/{item_id}?dataEnv={data_env}&locale={locale}"
TRINKETS_URL = "https://www.wowhead.com/items/armor/trinkets?filter=62;1;0"
DEFAULT_REVIEW_MEMORY_FILE = REPO_ROOT / "docs/CooldownPanelAutoDurationReview.json"

LISTVIEW_ITEMS_RE = re.compile(r"listviewitems\s*=\s*(?P<items>\[.*?\]);\s*new Listview", re.DOTALL)
LISTVIEW_ITEM_ID_RE = re.compile(r'"id":(\d+)')
USE_RE = re.compile(
    r"\bUse:\s*(?P<text>.*?)(?=(?:\s+(?:Equip:|Use:|Requires\b|Sell Price:|Max Stack:|Classes:|Races:))|$)",
    re.IGNORECASE,
)
DURATION_RE = re.compile(r"\b(?:for|lasts|lasting)\s+(?P<duration>\d+(?:\.\d+)?)\s*sec(?:onds?)?\b", re.IGNORECASE)
OVER_DURATION_RE = re.compile(r"\bover\s+\d+(?:\.\d+)?\s*sec(?:onds?)?\b", re.IGNORECASE)
NEXT_LIMIT_RE = re.compile(r"\bnext\b", re.IGNORECASE)

SAFE_DURATION_VERBS = (
    "gain",
    "gains",
    "grant",
    "grants",
    "increase",
    "increases",
    "provides",
    "provide",
    "become",
    "becomes",
    "enter",
    "enters",
    "activate",
    "activates",
    "empower",
    "empowers",
    "cloak",
    "cloaks",
)

REJECT_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
	("next_limited_effect", NEXT_LIMIT_RE),
	("stack_based", re.compile(r"\bstacks?\b|\bstacking\b", re.IGNORECASE)),
	("charge_based", re.compile(r"\bcharges?\b", re.IGNORECASE)),
	("cast_consumed_effect", re.compile(r"\bevery time you cast\b|\beach time you cast\b", re.IGNORECASE)),
	("channeled_effect", re.compile(r"\bchanneled\b", re.IGNORECASE)),
	("count_limited_effect", re.compile(r"\bup to\s+\d+\b|\bmaximum of\s+\d+\b|\bmax(?:imum)?\s+\d+\b", re.IGNORECASE)),
    ("conditional_until", re.compile(r"\bor until\b|\buntil cancelled\b|\bwhile\b", re.IGNORECASE)),
    ("chance_or_proc", re.compile(r"\bchance\b|\bproc\b|\bperiodically\b", re.IGNORECASE)),
    ("absorb_limited", re.compile(r"\babsorbs?\s+up to\b|\babsorb shield\b", re.IGNORECASE)),
    ("summon_or_create", re.compile(r"\bsummons?\b|\bcreates?\b|\bconjures?\b", re.IGNORECASE)),
    ("projectile_or_damage", re.compile(r"\bfires?\b|\blaunch(?:es)?\b|\bdeals?\b|\bdamage\b", re.IGNORECASE)),
    ("heal_or_restore_over_time", re.compile(r"\bheals?\b|\brestores?\b", re.IGNORECASE)),
]


@dataclass
class TooltipInfo:
    item_id: int
    name: str | None
    icon: str | None
    raw_tooltip: str
    text: str
    use_text: str | None


@dataclass
class Classification:
    status: str
    duration: float | None
    reason: str


@dataclass
class ProbeResult:
    item_id: int
    ok: bool
    tooltip: TooltipInfo | None = None
    classification: Classification | None = None
    error: str | None = None
    review_source: str | None = None
    review_note: str | None = None


def tooltip_to_text(raw_tooltip: str) -> str:
    text = re.sub(r"<br\s*/?>", "\n", raw_tooltip, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def extract_use_text(text: str) -> str | None:
    match = USE_RE.search(text)
    if not match:
        return None
    use_text = match.group("text").strip()
    return use_text or None


def parse_tooltip_payload(item_id: int, payload: dict) -> TooltipInfo:
    raw_tooltip = payload.get("tooltip") or ""
    text = tooltip_to_text(raw_tooltip)
    return TooltipInfo(
        item_id=item_id,
        name=payload.get("name"),
        icon=payload.get("icon"),
        raw_tooltip=raw_tooltip,
        text=text,
        use_text=extract_use_text(text),
    )


def classify_tooltip(tooltip: TooltipInfo) -> Classification:
    use_text = tooltip.use_text
    if not use_text:
        return Classification("rejected", None, "no_use_effect")

    duration_matches = list(DURATION_RE.finditer(use_text))
    if not duration_matches:
        if OVER_DURATION_RE.search(use_text):
            return Classification("rejected", None, "over_time_not_duration_window")
        return Classification("rejected", None, "no_fixed_duration")

    durations = {float(match.group("duration")) for match in duration_matches}
    if len(durations) != 1:
        return Classification("needs_review", None, "multiple_durations")

    for reason, pattern in REJECT_PATTERNS:
        if pattern.search(use_text):
            return Classification("rejected", next(iter(durations)), reason)

    lowered = use_text.lower()
    if not any(re.search(rf"\b{re.escape(verb)}\b", lowered) for verb in SAFE_DURATION_VERBS):
        return Classification("needs_review", next(iter(durations)), "duration_found_but_unrecognized_effect")

    return Classification("accepted", next(iter(durations)), "simple_fixed_duration")


def fetch_html(url: str, *, timeout: float) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Raizor-AutoDurationRefresh/1.0 (+local tooling)",
            "Accept": "text/html,application/xhtml+xml,text/plain,*/*",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read()
    return raw.decode("utf-8", errors="replace")


def split_top_level_objects(raw_items: str) -> list[str]:
    objects: list[str] = []
    start = None
    depth = 0
    in_string = False
    escaped = False

    for index, ch in enumerate(raw_items):
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            continue

        if ch == '"':
            in_string = True
            continue
        if ch == "{":
            if depth == 0:
                start = index
            depth += 1
            continue
        if ch == "}":
            depth = max(0, depth - 1)
            if depth == 0 and start is not None:
                objects.append(raw_items[start:index + 1])
                start = None
    return objects


def extract_listview_item_ids(page_html: str, *, slot: int | None = None) -> list[int]:
    match = LISTVIEW_ITEMS_RE.search(page_html)
    if not match:
        raise ValueError("Could not locate Wowhead listviewitems payload on the page")

    seen: set[int] = set()
    ordered: list[int] = []
    for raw_item in split_top_level_objects(match.group("items")):
        if slot is not None:
            slot_match = re.search(r'"slot":\s*(\d+)', raw_item)
            if not slot_match or int(slot_match.group(1)) != slot:
                continue
        id_match = re.search(r'"id":\s*(\d+)', raw_item)
        if not id_match:
            continue
        item_id = int(id_match.group(1))
        if item_id in seen:
            continue
        seen.add(item_id)
        ordered.append(item_id)
    return ordered


def fetch_tooltip(item_id: int, *, locale: int, data_env: int, timeout: float) -> TooltipInfo:
    url = TOOLTIP_URL.format(item_id=item_id, locale=locale, data_env=data_env)
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Raizor-AutoDurationRefresh/1.0 (+local tooling)",
            "Accept": "application/json,text/plain,*/*",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    return parse_tooltip_payload(item_id, payload)


def probe_single_item(item_id: int, *, locale: int, data_env: int, timeout: float, retries: int) -> ProbeResult:
    for attempt in range(max(0, retries) + 1):
        try:
            tooltip = fetch_tooltip(item_id, locale=locale, data_env=data_env, timeout=timeout)
            return ProbeResult(item_id=item_id, ok=True, tooltip=tooltip, classification=classify_tooltip(tooltip))
        except urllib.error.HTTPError as exc:
            return ProbeResult(item_id=item_id, ok=False, error=str(exc))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError) as exc:
            if attempt >= retries:
                return ProbeResult(item_id=item_id, ok=False, error=str(exc))
            time.sleep(min(2.0, 0.25 * (attempt + 1)))
    return ProbeResult(item_id=item_id, ok=False, error="unknown probe failure")


def probe_items(item_ids: list[int], *, locale: int, data_env: int, timeout: float, workers: int, retries: int) -> list[ProbeResult]:
    results_by_id: dict[int, ProbeResult] = {}
    with ThreadPoolExecutor(max_workers=max(1, workers)) as executor:
        futures = {
            executor.submit(probe_single_item, item_id, locale=locale, data_env=data_env, timeout=timeout, retries=retries): item_id
            for item_id in item_ids
        }
        for future in as_completed(futures):
            result = future.result()
            results_by_id[result.item_id] = result
    return [results_by_id[item_id] for item_id in item_ids if item_id in results_by_id]


def parse_ids_text(raw: str) -> list[int]:
    seen: set[int] = set()
    ordered: list[int] = []
    for match in re.finditer(r"\d+", raw):
        item_id = int(match.group(0))
        if item_id in seen:
            continue
        seen.add(item_id)
        ordered.append(item_id)
    return ordered


def load_item_ids(args: argparse.Namespace) -> list[int]:
    item_ids: list[int] = []
    if args.ids:
        item_ids.extend(parse_ids_text(args.ids))
    if args.ids_file:
        item_ids.extend(parse_ids_text(args.ids_file.read_text(encoding="utf-8")))

    seen: set[int] = set()
    ordered: list[int] = []
    for item_id in item_ids:
        if item_id in seen:
            continue
        seen.add(item_id)
        ordered.append(item_id)
    return ordered


def discover_item_ids(url: str, *, timeout: float, slot: int | None) -> list[int]:
    return extract_listview_item_ids(fetch_html(url, timeout=timeout), slot=slot)


def load_review_memory(path: pathlib.Path | None) -> dict[int, dict]:
    if path is None or not path.exists():
        return {}
    payload = json.loads(path.read_text(encoding="utf-8"))
    raw_items = payload.get("items", payload)
    if not isinstance(raw_items, dict):
        raise ValueError(f"Review memory must contain an object of items: {path}")
    memory: dict[int, dict] = {}
    for raw_id, raw_entry in raw_items.items():
        try:
            item_id = int(raw_id)
        except (TypeError, ValueError):
            continue
        if isinstance(raw_entry, dict):
            memory[item_id] = raw_entry
    return memory


def append_missing_ids(item_ids: list[int], extra_ids: list[int]) -> list[int]:
    seen = set(item_ids)
    merged = list(item_ids)
    for item_id in extra_ids:
        if item_id in seen:
            continue
        seen.add(item_id)
        merged.append(item_id)
    return merged


def apply_review_memory(results: list[ProbeResult], memory: dict[int, dict]) -> None:
    for result in results:
        entry = memory.get(result.item_id)
        if not entry or not result.ok:
            continue
        status = entry.get("status")
        if status not in ("accepted", "needs_review", "rejected"):
            continue
        duration = entry.get("duration")
        if duration is not None:
            try:
                duration = float(duration)
            except (TypeError, ValueError):
                duration = None
        if status == "accepted" and not duration:
            continue
        reason = str(entry.get("reason") or f"review_memory_{status}")
        result.classification = Classification(status, duration, reason)
        result.review_source = str(entry.get("source") or "wowhead_reviewed")
        note = entry.get("note")
        result.review_note = str(note) if note else None


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def render_lua(results: list[ProbeResult]) -> str:
    accepted = [
        result for result in results
        if result.ok and result.tooltip and result.classification and result.classification.status == "accepted"
    ]
    accepted.sort(key=lambda result: result.item_id)
    lines = [
        "-- This file is generated by scripts/refresh_auto_duration_candidates_from_wowhead.py.",
        "-- Review before copying entries into runtime data.",
        "addon.CooldownPanelAutoDurationCandidates = {",
    ]
    for result in accepted:
        tooltip = result.tooltip
        classification = result.classification
        assert tooltip is not None
        assert classification is not None
        name = tooltip.name or f"item {result.item_id}"
        duration = classification.duration
        duration_text = str(int(duration)) if duration and duration.is_integer() else str(duration)
        lines.append(f"\t[{result.item_id}] = {{ duration = {duration_text}, name = {lua_string(name)} }},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def render_runtime_lua(results: list[ProbeResult]) -> str:
    accepted = [
        result for result in results
        if result.ok and result.tooltip and result.classification and result.classification.status == "accepted"
    ]
    accepted.sort(key=lambda result: result.item_id)
    lines = [
        "-- This file is generated by scripts/refresh_auto_duration_candidates_from_wowhead.py.",
        "local parentAddonName = \"EnhanceQoL\"",
        "local addon = select(2, ...)",
        "",
        "if _G[parentAddonName] then",
        "\taddon = _G[parentAddonName]",
        "else",
        "\terror(parentAddonName .. \" is not loaded\")",
        "end",
        "",
        "addon.Aura = addon.Aura or {}",
        "addon.Aura.CooldownPanels = addon.Aura.CooldownPanels or {}",
        "local CooldownPanels = addon.Aura.CooldownPanels",
        "",
        "CooldownPanels.autoCooldownDurationByItemID = {",
    ]
    for result in accepted:
        tooltip = result.tooltip
        classification = result.classification
        assert tooltip is not None
        assert classification is not None
        name = tooltip.name or f"item {result.item_id}"
        duration = classification.duration
        duration_text = str(int(duration)) if duration and duration.is_integer() else str(duration)
        lines.append(f"\t[{result.item_id}] = {{ duration = {duration_text}, name = {lua_string(name)} }},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def result_to_json(result: ProbeResult) -> dict:
    payload: dict = {
        "item_id": result.item_id,
        "ok": result.ok,
    }
    if not result.ok:
        payload["error"] = result.error
        return payload
    tooltip = result.tooltip
    classification = result.classification
    payload.update(
        {
            "name": tooltip.name if tooltip else None,
            "icon": tooltip.icon if tooltip else None,
            "status": classification.status if classification else None,
            "duration": classification.duration if classification else None,
            "reason": classification.reason if classification else None,
            "review_source": result.review_source,
            "review_note": result.review_note,
            "use_text": tooltip.use_text if tooltip else None,
            "tooltip_text": tooltip.text if tooltip else None,
        }
    )
    return payload


def render_markdown(results: list[ProbeResult]) -> str:
    groups = {
        "accepted": [],
        "needs_review": [],
        "rejected": [],
        "errors": [],
    }
    for result in results:
        if not result.ok:
            groups["errors"].append(result)
            continue
        status = result.classification.status if result.classification else "needs_review"
        groups.setdefault(status, []).append(result)

    lines = [
        "# Cooldown Panel Auto-Duration Candidates",
        "",
        f"- Accepted: {len(groups['accepted'])}",
        f"- Needs review: {len(groups['needs_review'])}",
        f"- Rejected: {len(groups['rejected'])}",
        f"- Errors: {len(groups['errors'])}",
        "",
    ]
    for status in ("accepted", "needs_review", "rejected", "errors"):
        title = status.replace("_", " ").title()
        lines.extend([f"## {title}", ""])
        if not groups[status]:
            lines.extend(["None.", ""])
            continue
        lines.append("| Item ID | Name | Duration | Reason | Use text |")
        lines.append("|---:|---|---:|---|---|")
        for result in groups[status]:
            tooltip = result.tooltip
            classification = result.classification
            name = (tooltip.name if tooltip and tooltip.name else "") or f"item {result.item_id}"
            duration = classification.duration if classification else None
            duration_text = "" if duration is None else (str(int(duration)) if float(duration).is_integer() else str(duration))
            reason = result.error or (classification.reason if classification else "")
            if result.review_note:
                reason = f"{reason}: {result.review_note}"
            use_text = tooltip.use_text if tooltip and tooltip.use_text else ""
            use_text = use_text.replace("|", "\\|")
            name = name.replace("|", "\\|")
            lines.append(f"| {result.item_id} | {name} | {duration_text} | {reason} | {use_text} |")
        lines.append("")
    return "\n".join(lines)


def write_outputs(results: list[ProbeResult], args: argparse.Namespace) -> None:
    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(
            json.dumps([result_to_json(result) for result in results], indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    if args.output_markdown:
        args.output_markdown.parent.mkdir(parents=True, exist_ok=True)
        args.output_markdown.write_text(render_markdown(results), encoding="utf-8")
    if args.output_lua:
        args.output_lua.parent.mkdir(parents=True, exist_ok=True)
        args.output_lua.write_text(render_lua(results), encoding="utf-8")
    if args.output_runtime_lua:
        args.output_runtime_lua.parent.mkdir(parents=True, exist_ok=True)
        args.output_runtime_lua.write_text(render_runtime_lua(results), encoding="utf-8")


def self_test() -> int:
    accepted = parse_tooltip_payload(
        1,
        {
            "name": "Simple Power",
            "tooltip": "Use: Increases your Intellect by 1000 for 30 sec. Requires Level 81 Max Stack: 200",
        },
    )
    accepted_class = classify_tooltip(accepted)
    assert accepted_class.status == "accepted"
    assert accepted_class.duration == 30
    assert accepted.use_text == "Increases your Intellect by 1000 for 30 sec."

    invisible = parse_tooltip_payload(
        2,
        {
            "name": "Simple Invisibility",
            "tooltip": "Use: Provides invisibility for 18 sec.",
        },
    )
    invisible_class = classify_tooltip(invisible)
    assert invisible_class.status == "accepted"
    assert invisible_class.duration == 18

    limited = parse_tooltip_payload(
        3,
        {
            "name": "Limited Power",
            "tooltip": "Use: Increases your damage for 30 sec, affecting your next 5 spells.",
        },
    )
    limited_class = classify_tooltip(limited)
    assert limited_class.status == "rejected"
    assert limited_class.reason == "next_limited_effect"

    over_time = parse_tooltip_payload(
        4,
        {
            "name": "Damage Beam",
            "tooltip": "Use: Deals 1000 damage over 10 sec.",
        },
    )
    over_time_class = classify_tooltip(over_time)
    assert over_time_class.status == "rejected"

    page = """
        <script>
        listviewitems = [{"id":1,"name":"A"},{"id":2,"name":"B"},{"id":1,"name":"A"}];
        new Listview({template: 'item'});
        </script>
    """
    assert extract_listview_item_ids(page) == [1, 2]

    slotted_page = """
        <script>
        listviewitems = [
            {"id":10,"slot":1,"nested":{"id":999}},
            {"id":20,"slot":12,"nested":{"id":888}},
            {"id":30,"slot":12}
        ];
        new Listview({template: 'item'});
        </script>
    """
    assert extract_listview_item_ids(slotted_page, slot=12) == [20, 30]

    memory_result = ProbeResult(
        item_id=4,
        ok=True,
        tooltip=over_time,
        classification=over_time_class,
    )
    apply_review_memory(
        [memory_result],
        {4: {"status": "accepted", "duration": 10, "source": "wowhead_reviewed", "reason": "manual_area_duration"}},
    )
    assert memory_result.classification is not None
    assert memory_result.classification.status == "accepted"
    assert memory_result.classification.duration == 10
    assert memory_result.review_source == "wowhead_reviewed"
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch Wowhead item tooltips and classify simple fixed auto-duration candidates.")
    parser.add_argument("--discover", action="store_true", help="Fetch item ids from a Wowhead listview page")
    parser.add_argument("--discover-url", default=TRINKETS_URL, help="Wowhead listview URL used by --discover")
    parser.add_argument("--slot", type=int, default=12, help="Only keep discovered Wowhead items from this inventory slot, default: 12 (trinket)")
    parser.add_argument("--no-slot-filter", action="store_true", help="Do not filter discovered Wowhead listview items by inventory slot")
    parser.add_argument("--discover-output-ids", type=pathlib.Path, help="Write discovered item ids, one per line")
    parser.add_argument("--discover-limit", type=int, help="Only probe the first N discovered ids")
    parser.add_argument("--ids", help="Comma-separated item ids to probe")
    parser.add_argument("--ids-file", type=pathlib.Path, help="File containing item ids to probe")
    parser.add_argument("--output-json", type=pathlib.Path, help="Write full probe/classification results as JSON")
    parser.add_argument("--output-markdown", type=pathlib.Path, help="Write a human review report as Markdown")
    parser.add_argument("--output-lua", type=pathlib.Path, help="Write accepted candidates as a Lua proposal")
    parser.add_argument("--output-runtime-lua", type=pathlib.Path, help="Write accepted candidates as EnhanceQoL runtime Lua")
    parser.add_argument("--review-memory", type=pathlib.Path, default=DEFAULT_REVIEW_MEMORY_FILE, help="JSON file with reviewed item decisions")
    parser.add_argument("--no-review-memory", action="store_true", help="Ignore the review memory file")
    parser.add_argument("--include-review-memory-ids", action="store_true", help="Also probe item ids present in review memory")
    parser.add_argument("--locale", type=int, default=0, help="Wowhead locale id, default: 0 (enUS)")
    parser.add_argument("--data-env", type=int, default=1, help="Wowhead dataEnv query parameter")
    parser.add_argument("--timeout", type=float, default=10.0, help="HTTP timeout in seconds")
    parser.add_argument("--workers", type=int, default=12, help="Concurrent workers for tooltip probes")
    parser.add_argument("--retries", type=int, default=2, help="Retries for transient tooltip fetch failures")
    parser.add_argument("--self-test", action="store_true", help="Run offline parser tests and exit")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.self_test:
        return self_test()

    item_ids = load_item_ids(args)
    review_memory = {} if args.no_review_memory else load_review_memory(args.review_memory)
    if args.discover:
        if item_ids:
            print("Use either --discover or --ids/--ids-file, not both.", file=sys.stderr)
            return 2
        slot_filter = None if args.no_slot_filter else args.slot
        item_ids = discover_item_ids(args.discover_url, timeout=args.timeout, slot=slot_filter)
        if args.discover_output_ids:
            args.discover_output_ids.parent.mkdir(parents=True, exist_ok=True)
            args.discover_output_ids.write_text("\n".join(str(item_id) for item_id in item_ids) + "\n", encoding="utf-8")
        if args.discover_limit is not None:
            item_ids = item_ids[: max(0, args.discover_limit)]
    if args.include_review_memory_ids and review_memory:
        item_ids = append_missing_ids(item_ids, sorted(review_memory))

    if not item_ids:
        print("No item ids provided. Use --discover, --ids, or --ids-file.", file=sys.stderr)
        return 2

    results = probe_items(item_ids, locale=args.locale, data_env=args.data_env, timeout=args.timeout, workers=args.workers, retries=args.retries)
    apply_review_memory(results, review_memory)
    write_outputs(results, args)

    counts = {"accepted": 0, "needs_review": 0, "rejected": 0, "errors": 0}
    for result in results:
        if not result.ok:
            counts["errors"] += 1
        elif result.classification:
            counts[result.classification.status] = counts.get(result.classification.status, 0) + 1
    print(
        "Probed {total} items: accepted={accepted}, needs_review={needs_review}, rejected={rejected}, errors={errors}".format(
            total=len(results),
            **counts,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
