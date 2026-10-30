#!/usr/bin/env python3
"""
Export an OCL concept set (default: PIH procedure set, concept 9779) to Excel.

For the top-level set, each member set gets its own sheet listing the
procedures inside it with their English and French names. An "All procedures"
sheet combines everything, and an "Overview" sheet lists the member sets.

Requirements:   pip install requests openpyxl
Usage:          python ocl_procedure_set_to_excel.py
Options:        python ocl_procedure_set_to_excel.py --concept 9779 --org PIH --source PIH --out my_file.xlsx

The PIH source is public, so no login is needed. If you ever need a token,
set the environment variable OCL_API_TOKEN before running.
"""

import argparse
import os
import sys
import time

import requests
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

API_BASE = "https://api.openconceptlab.org"
SET_MAP_TYPE = "CONCEPT-SET"

session = requests.Session()
session.headers["Accept"] = "application/json"
if os.environ.get("OCL_API_TOKEN"):
    session.headers["Authorization"] = "Token " + os.environ["OCL_API_TOKEN"]

_cache = {}


# ---------------------------------------------------------------- API helpers
def get_json(path, params=None, tries=5):
    """GET an OCL API path (e.g. /orgs/PIH/...) with simple retry/backoff."""
    url = path if path.startswith("http") else API_BASE + path
    for attempt in range(tries):
        try:
            r = session.get(url, params=params, timeout=60)
            if r.status_code == 200:
                return r.json()
            if r.status_code == 404:
                return None
            if r.status_code in (429, 500, 502, 503, 504):
                time.sleep(2 ** attempt)
                continue
            r.raise_for_status()
        except requests.RequestException as exc:
            if attempt == tries - 1:
                raise
            print(f"  network error ({exc}); retrying...", file=sys.stderr)
            time.sleep(2 ** attempt)
    raise RuntimeError(f"Gave up fetching {url}")


def get_concept(concept_url):
    """Fetch a concept (with its mappings) by its OCL URL, cached."""
    if not concept_url.endswith("/"):
        concept_url += "/"
    if concept_url not in _cache:
        data = get_json(concept_url, params={"includeMappings": "true", "verbose": "true"})
        _cache[concept_url] = data
    return _cache[concept_url]


def get_mappings(concept):
    """Return the concept's mappings, falling back to the /mappings/ endpoint."""
    if concept.get("mappings") is not None:
        return concept["mappings"]
    results, page, limit = [], 1, 500
    while True:
        batch = get_json(concept["url"] + "mappings/",
                         params={"verbose": "true", "limit": limit, "page": page}) or []
        results.extend(batch)
        if len(batch) < limit:
            return results
        page += 1


def set_members(concept):
    """Return URLs of the concept's set members, in set order."""
    code = concept.get("id")
    members = []
    for m in get_mappings(concept):
        if m.get("map_type") != SET_MAP_TYPE or m.get("retired"):
            continue
        if m.get("from_concept_code") not in (None, code):
            continue  # mapping pointing *to* this concept, not from it
        url = m.get("to_concept_url")
        if not url and m.get("to_source_url") and m.get("to_concept_code"):
            url = f"{m['to_source_url']}concepts/{m['to_concept_code']}/"
        if not url:
            print(f"  skipping member with no URL: {m.get('to_concept_code')}", file=sys.stderr)
            continue
        weight = (m.get("extras") or {}).get("sort_weight")
        try:
            weight = float(weight)
        except (TypeError, ValueError):
            weight = float("inf")
        members.append((weight, len(members), url))
    members.sort()
    return [url for _, _, url in members]


def is_set(concept):
    extras = concept.get("extras") or {}
    return bool(extras.get("is_set")) or concept.get("concept_class") in ("ConvSet", "Set")


# --------------------------------------------------------------- name helpers
def live_names(concept, locale):
    return [n for n in concept.get("names", [])
            if n.get("locale") == locale and not n.get("retired")]


def best_name(concept, locale):
    names = live_names(concept, locale)
    for test in (lambda n: n.get("locale_preferred"),
                 lambda n: n.get("name_type") == "FULLY_SPECIFIED",
                 lambda n: True):
        for n in names:
            if test(n):
                return n["name"]
    return ""


def other_names(concept, locale, chosen):
    return "; ".join(sorted({n["name"] for n in live_names(concept, locale)
                             if n["name"] != chosen and n.get("name_type") != "SHORT"}))


def concept_row(concept, subgroup):
    en = best_name(concept, "en")
    fr = best_name(concept, "fr")
    return {
        "Subgroup": subgroup,
        "Concept ID": concept.get("id"),
        "English name": en,
        "French name": fr,
        "Other French names": other_names(concept, "fr", fr),
        "Class": concept.get("concept_class", ""),
        "Retired": "Yes" if concept.get("retired") else "",
        "OCL URL": "https://app.v3.openconceptlab.org" + concept.get("url", ""),
    }


# ------------------------------------------------------------------ the walk
def collect_procedures(set_concept, path=(), seen=None):
    """Return rows for every non-set concept beneath set_concept (any depth)."""
    seen = set() if seen is None else seen
    rows = []
    for url in set_members(set_concept):
        if url in seen:
            continue  # guard against cycles
        child = get_concept(url)
        if child is None:
            print(f"  could not fetch {url}", file=sys.stderr)
            continue
        if is_set(child) and set_members(child):
            rows += collect_procedures(child, path + (best_name(child, "en"),), seen | {url})
        else:
            rows.append(concept_row(child, " > ".join(path)))
    return rows


# --------------------------------------------------------------- Excel output
HEADER_FONT = Font(name="Arial", bold=True, color="FFFFFF")
HEADER_FILL = PatternFill("solid", fgColor="305496")
BODY_FONT = Font(name="Arial")
MISSING_FILL = PatternFill("solid", fgColor="FFF2CC")
WIDTHS = {"Member set": 32, "Subgroup": 28, "Concept ID": 12, "English name": 45,
          "French name": 45, "Other French names": 40, "Class": 14, "Retired": 9, "OCL URL": 20}


def safe_sheet_name(name, used):
    clean = "".join("-" if c in '[]:*?/\\' else c for c in name).strip() or "Set"
    base = clean[:31]
    candidate, i = base, 2
    while candidate.lower() in used:
        suffix = f" ({i})"
        candidate = base[:31 - len(suffix)] + suffix
        i += 1
    used.add(candidate.lower())
    return candidate


def write_table(ws, columns, rows):
    ws.append(columns)
    for cell in ws[1]:
        cell.font, cell.fill = HEADER_FONT, HEADER_FILL
        cell.alignment = Alignment(vertical="center")
    for row in rows:
        ws.append([row.get(c, "") for c in columns])
    fr_col = columns.index("French name") + 1 if "French name" in columns else None
    for r in ws.iter_rows(min_row=2):
        for cell in r:
            cell.font = BODY_FONT
        if fr_col and not r[fr_col - 1].value:
            r[fr_col - 1].fill = MISSING_FILL
    if "OCL URL" in columns:
        url_col = columns.index("OCL URL") + 1
        for r in ws.iter_rows(min_row=2, min_col=url_col, max_col=url_col):
            if r[0].value:
                r[0].hyperlink = r[0].value
                r[0].value = "Open in OCL"
                r[0].font = Font(name="Arial", color="0563C1", underline="single")
    for i, c in enumerate(columns, 1):
        ws.column_dimensions[get_column_letter(i)].width = WIDTHS.get(c, 18)
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--org", default="PIH")
    ap.add_argument("--source", default="PIH")
    ap.add_argument("--concept", default="9779")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    root_url = f"/orgs/{args.org}/sources/{args.source}/concepts/{args.concept}/"
    print(f"Fetching {root_url} ...")
    root = get_concept(root_url)
    if root is None:
        sys.exit(f"Concept {args.concept} not found in {args.org}/{args.source}.")
    root_name = best_name(root, "en") or args.concept
    print(f"Top-level set: {root_name}")

    # Group 1: each direct member set. Direct members that are not sets go to "Other".
    groups, loose = [], []
    for url in set_members(root):
        member = get_concept(url)
        if member is None:
            print(f"  could not fetch {url}", file=sys.stderr)
            continue
        name = best_name(member, "en") or member.get("id")
        if is_set(member) and set_members(member):
            print(f"  member set: {name}")
            groups.append((member, collect_procedures(member, seen={url})))
        else:
            loose.append(concept_row(member, ""))
    if loose:
        groups.append(({"id": "", "names": [{"locale": "en", "name": "Other procedures"}]}, loose))

    if not groups:
        sys.exit("No set members were found. Check the concept ID, or try setting OCL_API_TOKEN.")

    wb = Workbook()
    overview = wb.active
    overview.title = "Overview"
    used = {"overview", "all procedures"}
    cols = ["Subgroup", "Concept ID", "English name", "French name",
            "Other French names", "Class", "Retired", "OCL URL"]

    all_rows, overview_rows = [], []
    for member, rows in groups:
        en, fr = best_name(member, "en"), best_name(member, "fr")
        sheet = safe_sheet_name(en or member.get("id"), used)
        ws = wb.create_sheet(sheet)
        sheet_cols = cols if any(r["Subgroup"] for r in rows) else cols[1:]
        write_table(ws, sheet_cols, rows)
        overview_rows.append((en, fr, member.get("id"), sheet, len(rows)))
        all_rows += [{"Member set": en, **r} for r in rows]

    write_table(wb.create_sheet("All procedures", 1), ["Member set"] + cols, all_rows)

    overview.append([f"{root_name} (OCL {args.org}/{args.source} concept {args.concept})"])
    overview["A1"].font = Font(name="Arial", bold=True, size=13)
    overview.append(["Yellow cells on the other sheets mark procedures with no French name in OCL."])
    overview["A2"].font = Font(name="Arial", italic=True)
    overview.append([])
    overview.append(["Member set (English)", "Member set (French)", "Concept ID", "Sheet", "Procedures"])
    for cell in overview[4]:
        cell.font, cell.fill = HEADER_FONT, HEADER_FILL
    for en, fr, cid, sheet, _ in overview_rows:
        ref = sheet.replace("'", "''")
        id_col = "B" if wb[sheet]["A1"].value == "Subgroup" else "A"
        overview.append([en, fr, cid, sheet, f"=COUNTA('{ref}'!{id_col}:{id_col})-1"])
    for r in overview.iter_rows(min_row=5):
        for cell in r:
            cell.font = BODY_FONT
    for col, width in zip("ABCDE", (40, 40, 12, 32, 12)):
        overview.column_dimensions[col].width = width

    out = args.out or f"{args.org}_concept_{args.concept}_procedures.xlsx"
    wb.save(out)
    missing = sum(1 for r in all_rows if not r["French name"])
    print(f"\nSaved {out}: {len(groups)} member sheet(s), {len(all_rows)} procedure row(s), "
          f"{missing} without a French name.")


if __name__ == "__main__":
    main()

