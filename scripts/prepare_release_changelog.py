#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


HEADING = re.compile(r"^## \[(?P<tag>[^\]]+)\].*$")
PRERELEASE_RE = re.compile(r"^(?P<base>.+?)-(?:alpha|beta|rc)\d*$", re.IGNORECASE)
SEMVER_RE = re.compile(r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)$")


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


def release_sections(changelog, tag):
    lines, sections = parse_sections(changelog)
    index = next((i for i, section in enumerate(sections) if section["tag"] == tag), None)
    if index is None:
        return lines, []

    base = prerelease_base(tag)
    if base:
        selected = []
        include_family = patch_family(base)
        for section in sections:
            if prerelease_base(section["tag"]) == base:
                selected.append(section)
            elif selected and include_family and section_in_patch_family(section, include_family):
                selected.append(section)
            elif selected:
                break
        return lines, selected or [sections[index]]

    family = patch_family(tag)
    if family:
        selected = []
        for section in sections[index:]:
            if section_in_patch_family(section, family):
                selected.append(section)
            else:
                break
        return lines, selected or [sections[index]]

    return lines, [sections[index]]


def prerelease_base(tag):
    match = PRERELEASE_RE.match(tag or "")
    return match.group("base") if match else None


def patch_family(tag):
    match = SEMVER_RE.match(tag or "")
    if not match:
        return None

    patch = int(match.group("patch"))
    if patch <= 0:
        return None

    return f"{match.group('major')}.{match.group('minor')}"


def section_in_patch_family(section, family):
    match = SEMVER_RE.match(section["tag"] or "")
    if not match:
        return False

    return f"{match.group('major')}.{match.group('minor')}" == family


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
    parser = argparse.ArgumentParser(
        description="Limit CHANGELOG.md to the sections that should be published for a release artifact."
    )
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
