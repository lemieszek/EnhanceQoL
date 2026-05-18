#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


HEADING = re.compile(r"^## \[(?P<tag>[^\]]+)\].*$")
PATCH_RELEASE = re.compile(r"^\d+\.\d+\.(?P<patch>\d+)$")


def parse_sections(changelog):
    lines = changelog.splitlines()
    sections = []
    current = None

    for index, line in enumerate(lines):
        match = HEADING.match(line)
        if not match:
            continue
        if current is not None:
            current["end"] = index
            sections.append(current)
        current = {
            "tag": match.group("tag"),
            "start": index,
            "end": len(lines),
        }

    if current is not None:
        sections.append(current)

    return lines, sections


def is_patch_release(tag):
    match = PATCH_RELEASE.match(tag)
    return bool(match and int(match.group("patch")) > 0)


def release_sections(changelog, tag):
    lines, sections = parse_sections(changelog)
    for index, section in enumerate(sections):
        if section["tag"] != tag:
            continue

        selected = [section]
        if is_patch_release(tag) and index + 1 < len(sections):
            selected.append(sections[index + 1])
        return lines, selected

    return lines, []


def build_changelog(lines, selected):
    output = ["# Changelog"]
    for section in selected:
        if output[-1] != "":
            output.append("")
        output.extend(lines[section["start"] : section["end"]])

    while output and output[-1].strip() in ("", "---"):
        output.pop()
    output.append("")
    return "\n".join(output)


def main():
    parser = argparse.ArgumentParser(description="Limit CHANGELOG.md to the sections that should be published for a release artifact.")
    parser.add_argument("tag", help="Release tag to extract from CHANGELOG.md.")
    parser.add_argument("--changelog", default="CHANGELOG.md", help="Path to the changelog file to rewrite.")
    args = parser.parse_args()

    changelog_path = Path(args.changelog)
    changelog = changelog_path.read_text(encoding="utf-8")
    lines, selected = release_sections(changelog, args.tag)
    if not selected:
        print(f"No CHANGELOG.md section found for tag {args.tag}.", file=sys.stderr)
        return 1

    changelog_path.write_text(build_changelog(lines, selected), encoding="utf-8")
    included = ", ".join(section["tag"] for section in selected)
    print(f"Prepared release changelog for {args.tag}; included sections: {included}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
