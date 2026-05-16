#!/usr/bin/env python3

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "EnhanceQoL/Modules/Tooltip/RealmInfoData.lua"
DEFAULT_REGIONS = ("eu", "us", "kr", "tw")
REGION_LOCALES = {
    "eu": "en_GB",
    "us": "en_US",
    "kr": "ko_KR",
    "tw": "zh_TW",
}
REGION_ALIAS_LOCALES = {
    "eu": ("ru_RU",),
}


def load_dotenv() -> None:
    for name in (".env.local", ".env"):
        path = ROOT / name
        if not path.exists() or not path.is_file():
            continue
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


def get_json(url: str, token: str) -> dict:
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def get_access_token(client_id: str, client_secret: str) -> str:
    body = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode("ascii")
    basic = base64.b64encode(f"{client_id}:{client_secret}".encode("utf-8")).decode("ascii")
    request = urllib.request.Request(
        "https://oauth.battle.net/token",
        data=body,
        headers={
            "Authorization": f"Basic {basic}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        payload = json.loads(response.read().decode("utf-8"))
    token = payload.get("access_token")
    if not token:
        raise ValueError("Battle.net OAuth response did not include an access token")
    return token


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def wow_locale_to_addon_locale(value: str | None) -> str:
    if not value:
        return "enUS"
    return value.replace("_", "")


def realm_type_to_rules(value: str | None) -> str:
    normalized = (value or "NORMAL").upper()
    if normalized == "NORMAL":
        return "PvE"
    if normalized == "RP":
        return "RP"
    if normalized == "PVP":
        return "PvP"
    return normalized


def localized_value(value: object, locale: str, fallback: str = "") -> str:
    if isinstance(value, dict):
        return str(value.get(locale) or value.get("en_GB") or value.get("en_US") or next(iter(value.values()), fallback))
    if value is None:
        return fallback
    return str(value)


def with_locale(url: str, locale: str) -> str:
    parts = urllib.parse.urlsplit(url)
    query = dict(urllib.parse.parse_qsl(parts.query, keep_blank_values=True))
    query["locale"] = locale
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc, parts.path, urllib.parse.urlencode(query), parts.fragment))


def fetch_blizzard_data(regions: list[str]) -> tuple[list[tuple[int, str]], list[str], str]:
    load_dotenv()
    client_id = os.environ.get("BATTLE_NET_CLIENT_ID")
    client_secret = os.environ.get("BATTLE_NET_CLIENT_SECRET")
    if not client_id or not client_secret:
        raise ValueError("Missing BATTLE_NET_CLIENT_ID or BATTLE_NET_CLIENT_SECRET in environment, .env.local, or a regular .env file")

    token = get_access_token(client_id, client_secret)
    realm_rows: dict[int, str] = {}
    connection_rows: list[str] = []
    fetched_regions: list[str] = []

    for region in regions:
        region = region.lower()
        locale = REGION_LOCALES.get(region, "en_US")
        namespace = f"dynamic-{region}"
        host = f"https://{region}.api.blizzard.com"
        index_url = f"{host}/data/wow/connected-realm/index?namespace={namespace}&locale={locale}"
        index = get_json(index_url, token)
        connected_realms = index.get("connected_realms") or []
        if not connected_realms:
            raise ValueError(f"No connected realms returned for region {region}")
        fetched_regions.append(region.upper())

        for entry in connected_realms:
            href = (entry.get("href") or "").replace("http://", "https://")
            if not href:
                continue
            data = get_json(href, token)
            localized_aliases: dict[int, set[str]] = {}
            for alias_locale in REGION_ALIAS_LOCALES.get(region, ()):
                alias_data = get_json(with_locale(href, alias_locale), token)
                for realm in alias_data.get("realms") or []:
                    realm_id = realm.get("id")
                    if realm_id is None:
                        continue
                    alias_name = localized_value(realm.get("name"), alias_locale)
                    if alias_name:
                        localized_aliases.setdefault(int(realm_id), set()).add(alias_name)

            ids: list[int] = []
            for realm in data.get("realms") or []:
                realm_id = realm.get("id")
                if realm_id is None:
                    continue
                realm_id = int(realm_id)
                ids.append(realm_id)

                slug = str(realm.get("slug") or realm_id)
                name = localized_value(realm.get("name"), locale, slug)
                rules = realm_type_to_rules((realm.get("type") or {}).get("type"))
                realm_locale = wow_locale_to_addon_locale(realm.get("locale"))
                timezone_name = str(realm.get("timezone") or "")
                game_client = "retail"
                aliases = sorted(alias for alias in localized_aliases.get(realm_id, set()) or set() if alias and alias != name and alias != slug)
                realm_rows[realm_id] = ",".join((name, rules, realm_locale, region.upper(), timezone_name, slug, game_client, ";".join(aliases)))

            if ids:
                connection_rows.append(",".join([region.upper(), *[str(realm_id) for realm_id in sorted(ids)]]))

    source_label = "Blizzard World of Warcraft Game Data API (" + ", ".join(fetched_regions) + ")"
    return sorted(realm_rows.items()), connection_rows, source_label


def build_output(realm_rows: list[tuple[int, str]], connection_rows: list[str], source_label: str) -> str:
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    lines: list[str] = [
        "-- This file is generated by scripts/update_tooltip_realm_info.py.",
        "-- Source data is generated from Blizzard's World of Warcraft Game Data API.",
        f"-- Generated at: {generated_at}",
        f"-- Source: {source_label}",
        "",
        'local parentAddonName = "EnhanceQoL"',
        "local addonName, addon = ...",
        "",
        "if _G[parentAddonName] then",
        "\taddon = _G[parentAddonName]",
        "else",
        '\terror(parentAddonName .. " is not loaded")',
        "end",
        "",
        "addon.Tooltip = addon.Tooltip or {}",
        "addon.Tooltip.variables = addon.Tooltip.variables or {}",
        "",
        "local realmInfo = addon.Tooltip.variables.realmInfo or {}",
        "addon.Tooltip.variables.realmInfo = realmInfo",
        "",
        f"realmInfo.generatedAt = {lua_quote(generated_at)}",
        f"realmInfo.source = {lua_quote(source_label)}",
        "",
        "local timezone2utc = {",
        "\tAEST = 10,",
        "\tBRT = -3,",
        "\tCET = 1,",
        "\tCNST = 8,",
        "\tCST = -6,",
        "\tEST = -5,",
        "\tKST = 9,",
        "\tMST = -7,",
        "\tPST = -8,",
        "}",
        "",
        "local rawRealmData = {",
    ]

    for realm_id, row in realm_rows:
        lines.append(f"\t[{realm_id}] = {lua_quote(row)},")

    lines.extend([
        "}",
        "",
        "local rawConnectionData = {",
    ])

    for row in connection_rows:
        lines.append(f"\t{lua_quote(row)},")

    lines.extend([
        "}",
        "",
        "local unpacked",
        "local currentRegion",
        "local realmsByRegionAndName = {}",
        "",
        "local function copyList(list)",
        "\tif type(list) ~= \"table\" then return nil end",
        "\tlocal copy = {}",
        "\tfor i = 1, #list do",
        "\t\tcopy[i] = list[i]",
        "\tend",
        "\treturn copy",
        "end",
        "",
        "local function getNameForAPI(name)",
        "\tif not name then return nil end",
        "\treturn (name:gsub(\"[%s%-]\", \"\"))",
        "end",
        "",
        "local function cloneRealm(realm)",
        "\tif type(realm) ~= \"table\" then return nil end",
        "\treturn {",
        "\t\tid = realm.id,",
        "\t\tname = realm.name,",
        "\t\tnameForAPI = realm.nameForAPI,",
        "\t\trules = realm.rules,",
        "\t\tlocale = realm.locale,",
        "\t\tregion = realm.region,",
        "\t\ttimezone = realm.timezone,",
        "\t\tutc = realm.utc,",
        "\t\tconnections = copyList(realm.connections),",
        "\t\tenglishName = realm.englishName,",
        "\t\tenglishNameForAPI = realm.englishNameForAPI,",
        "\t\tgameClient = realm.gameClient,",
        "\t\tfallback = realm.fallback,",
        "\t}",
        "end",
        "",
        "local function getFallbackRegion()",
        "\tif currentRegion then return currentRegion end",
        "\tlocal regionID = GetCurrentRegion and GetCurrentRegion()",
        "\tcurrentRegion = ({ \"US\", \"KR\", \"EU\", \"TW\", \"CN\" })[regionID] or \"US\"",
        "\treturn currentRegion",
        "end",
        "",
        "local function unpackData()",
        "\tif unpacked then return end",
        "\tfor id, info in pairs(rawRealmData) do",
		"\t\tlocal name, rules, locale, region, timezone, englishName, gameClient, aliases = strsplit(\",\", info)",
		"\t\trawRealmData[id] = {",
        "\t\t\tid = id,",
        "\t\t\tname = name,",
        "\t\t\tnameForAPI = getNameForAPI(name),",
        "\t\t\trules = rules and string.upper(rules) or nil,",
        "\t\t\tlocale = locale,",
        "\t\t\tregion = region,",
        "\t\t\ttimezone = timezone,",
        "\t\t\tutc = timezone2utc[timezone],",
		"\t\t\tenglishName = englishName,",
		"\t\t\tenglishNameForAPI = getNameForAPI(englishName),",
		"\t\t\tgameClient = gameClient,",
		"\t\t}",
		"\t\tif region then",
		"\t\t\trealmsByRegionAndName[region] = realmsByRegionAndName[region] or {}",
		"\t\t\tif rawRealmData[id].nameForAPI then realmsByRegionAndName[region][rawRealmData[id].nameForAPI] = id end",
		"\t\t\tif rawRealmData[id].englishNameForAPI then realmsByRegionAndName[region][rawRealmData[id].englishNameForAPI] = id end",
		"\t\t\tif aliases and aliases ~= \"\" then",
		"\t\t\t\tfor _, alias in ipairs({ strsplit(\";\", aliases) }) do",
		"\t\t\t\t\tlocal aliasNameForAPI = getNameForAPI(alias)",
		"\t\t\t\t\tif aliasNameForAPI then realmsByRegionAndName[region][aliasNameForAPI] = id end",
		"\t\t\t\tend",
		"\t\t\tend",
		"\t\tend",
        "\tend",
        "\tfor _, connectedRealmsStr in ipairs(rawConnectionData) do",
        "\t\tlocal connectedRealms = { strsplit(\",\", connectedRealmsStr) }",
        "\t\ttable.remove(connectedRealms, 1)",
        "\t\tfor i = 1, #connectedRealms do",
        "\t\t\tconnectedRealms[i] = tonumber(connectedRealms[i]) or connectedRealms[i]",
        "\t\tend",
        "\t\tfor _, id in ipairs(connectedRealms) do",
        "\t\t\tlocal realm = rawRealmData[id]",
        "\t\t\tif realm then realm.connections = connectedRealms end",
        "\t\tend",
        "\tend",
        "\tunpacked = true",
        "end",
        "",
        "local function getCurrentRegionFromGUID()",
        "\tif currentRegion then return currentRegion end",
        "\tunpackData()",
        "\tlocal guid = UnitGUID and UnitGUID(\"player\")",
        "\tif guid then",
        "\t\tlocal server = tonumber(strmatch(guid, \"^Player%-(%d+)\"))",
        "\t\tlocal realm = server and rawRealmData[server]",
        "\t\tif realm and realm.region then",
        "\t\t\tcurrentRegion = realm.region",
        "\t\t\treturn currentRegion",
        "\t\tend",
        "\tend",
        "\treturn getFallbackRegion()",
        "end",
        "",
        "local function findRealm(name, region)",
        "\tif type(name) ~= \"string\" or name == \"\" then return nil end",
        "\tlocal apiName = getNameForAPI(strtrim(name))",
        "\tif not apiName or apiName == \"\" then return nil end",
        "\tregion = region or getCurrentRegionFromGUID()",
        "\tlocal regionIndex = realmsByRegionAndName[region]",
        "\tlocal id = regionIndex and regionIndex[apiName]",
        "\treturn id and rawRealmData[id] or nil",
        "end",
        "",
        "local function addAutoCompleteFallbacks(region)",
        "\tif not GetAutoCompleteRealms then return end",
        "\tlocal names = GetAutoCompleteRealms()",
        "\tif type(names) ~= \"table\" or #names == 0 then return end",
        "\tregion = region or getCurrentRegionFromGUID()",
        "\tlocal connections = {}",
        "\tfor _, name in ipairs(names) do",
        "\t\tlocal realm = findRealm(name, region)",
        "\t\tif realm then",
        "\t\t\tconnections[#connections + 1] = realm.id",
        "\t\telse",
        "\t\t\tlocal apiName = getNameForAPI(name)",
        "\t\t\tlocal id = \"auto:\" .. apiName",
        "\t\t\tif not rawRealmData[id] then",
        "\t\t\t\trawRealmData[id] = {",
        "\t\t\t\t\tid = id,",
        "\t\t\t\t\tname = name,",
        "\t\t\t\t\tnameForAPI = apiName,",
        "\t\t\t\t\trules = \"PVE\",",
        "\t\t\t\t\tlocale = GetLocale and GetLocale() or \"enUS\",",
        "\t\t\t\t\tregion = region,",
        "\t\t\t\t\tfallback = true,",
        "\t\t\t\t}",
        "\t\t\t\trealmsByRegionAndName[region] = realmsByRegionAndName[region] or {}",
        "\t\t\t\trealmsByRegionAndName[region][apiName] = id",
        "\t\t\tend",
        "\t\t\tconnections[#connections + 1] = id",
        "\t\tend",
        "\tend",
        "\tif #connections == 0 then return end",
        "\tfor _, id in ipairs(connections) do",
        "\t\tlocal realm = rawRealmData[id]",
        "\t\tif realm and not realm.connections then realm.connections = connections end",
        "\tend",
        "end",
        "",
        "function realmInfo.GetCurrentRegion()",
        "\treturn getCurrentRegionFromGUID()",
        "end",
        "",
        "function realmInfo.GetRealmInfo(name, region)",
        "\tunpackData()",
        "\tif type(name) == \"number\" or (type(name) == \"string\" and name:match(\"^%d+$\")) then return realmInfo.GetRealmInfoByID(name) end",
        "\tlocal realm = findRealm(name, region)",
        "\tif not realm then",
        "\t\taddAutoCompleteFallbacks(region)",
        "\t\trealm = findRealm(name, region)",
        "\tend",
        "\treturn cloneRealm(realm)",
        "end",
        "",
        "function realmInfo.GetRealmInfoByID(id)",
        "\tunpackData()",
        "\tid = tonumber(id) or id",
        "\treturn cloneRealm(rawRealmData[id])",
        "end",
        "",
        "function realmInfo.GetConnectionNames(realm)",
        "\tunpackData()",
        "\tif type(realm) ~= \"table\" or type(realm.connections) ~= \"table\" then return nil end",
        "\tlocal names = {}",
        "\tfor _, id in ipairs(realm.connections) do",
        "\t\tlocal connectedRealm = rawRealmData[tonumber(id) or id]",
        "\t\tif connectedRealm and connectedRealm.name then names[#names + 1] = connectedRealm.name end",
        "\tend",
        "\tif #names == 0 then return nil end",
        "\ttable.sort(names)",
        "\treturn names",
        "end",
        "",
        "function realmInfo.GetRealmFromNameString(value)",
        "\tif type(value) ~= \"string\" then return GetRealmName and GetRealmName() or nil end",
        "\tlocal _, realm = strsplit(\"-\", value, 2)",
        "\tif realm and realm ~= \"\" then return realm end",
        "\treturn GetRealmName and GetRealmName() or nil",
        "end",
        "",
        "function realmInfo.FormatRealmType(realm)",
        "\tlocal rules = realm and realm.rules",
        "\tif type(rules) ~= \"string\" or rules == \"\" then return nil end",
        "\tlocal lower = rules:lower()",
        "\tif lower == \"rp\" or lower == \"rppvp\" then return \"RP PvE\" end",
        "\tif lower == \"pvp\" then return \"PvE\" end",
        "\treturn rules:gsub(\"V\", \"v\")",
        "end",
        "",
        "function realmInfo.FormatRealmTimezone(realm)",
        "\tif type(realm) ~= \"table\" then return nil end",
        "\tlocal utc = realm.utc or timezone2utc[realm.timezone]",
        "\tif not utc then return realm.timezone end",
        "\tif utc == 0 then return \"UTC\" end",
        "\treturn \"UTC\" .. (utc > 0 and \"+\" or \"\") .. tostring(utc)",
        "end",
    ])

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Update EnhanceQoL tooltip realm info data from Blizzard's World of Warcraft Game Data API")
    parser.add_argument("--regions", default=",".join(DEFAULT_REGIONS), help="Comma-separated Blizzard API regions. Default: eu,us,kr,tw.")
    args = parser.parse_args()

    try:
        regions = [part.strip().lower() for part in args.regions.split(",") if part.strip()]
        realm_rows, connection_rows, source_label = fetch_blizzard_data(regions)
        OUTPUT.write_text(build_output(realm_rows, connection_rows, source_label), encoding="utf-8")
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Updated {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
