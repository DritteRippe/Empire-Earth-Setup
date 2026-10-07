#!/usr/bin/env python3
"""Which files and empty folders below the gitignored asset folders a preprocessed setup script
reads: every [Files] Source is expanded like ISCC does (wildcards, recursesubdirs,
createallsubdirs -> empty folders become [Dirs] entries, external sources skipped), plus the file
directives of [Setup] (icon, wizard images, license and info files).

The preprocessed scripts come from ci/build.ps1 -KeepPreprocessed (<Type>_<Mode>.iss). With
--check-map the read set of each product is compared with the rows of the asset map
(ci/e2e/assets-map.tsv) for that product: a source the map does not name (a new or renamed asset
of the script) or a map row the script no longer reads is reported by its path, and the exit code
is 1. Without --check-map the read sets are printed as JSON (input of ci/e2e/gen_map.py).

Usage:
  readset.py --root ROOT --pp EE=EE_Regular.iss --pp NeoEE=NeoEE_Regular.iss [--check-map MAP]
Exit code 0: read sets printed or equal to the map; 1: a difference or a missing source; 2: usage.
"""
import argparse
import fnmatch
import json
import os
import re
import sys

ASSET_PREFIXES = ("data\\", "internal\\media\\", "internal\\misc\\", "internal\\runtime\\", "tools\\")
SETUP_FILE_KEYS = ("setupiconfile", "wizardimagefile", "wizardsmallimagefile", "licensefile",
                   "infobeforefile", "infoafterfile")


def sections(path):
    """(section, line) of the non-comment lines of the script, section lowercase."""
    current = None
    with open(path, encoding="utf-8-sig", errors="surrogateescape") as fh:
        for raw in fh:
            s = raw.strip()
            m = re.match(r"^\[([A-Za-z]+)\]\s*$", s)
            if m:
                current = m.group(1).lower()
                continue
            if s and not s.startswith(";"):
                yield current, s


def param(line, name):
    """The value of the parameter name of an entry line, or None."""
    m = re.search(r'(?:^|;)\s*' + name + r'\s*:\s*"((?:[^"]|"")*)"', line, re.I)
    if m:
        return m.group(1).replace('""', '"')
    m = re.search(r'(?:^|;)\s*' + name + r'\s*:\s*([^;]*)', line, re.I)
    return m.group(1).strip() if m else None


def resolve(root, winrel):
    """The local path of a Windows path relative to root, matched ignoring case, or None."""
    cur = root
    for part in [p for p in winrel.split("\\") if p]:
        if not os.path.isdir(cur):
            return None
        hit = [n for n in os.listdir(cur) if n.lower() == part.lower()]
        if not hit:
            return None
        cur = os.path.join(cur, hit[0])
    return cur


def read_set(root, pp):
    """{files, empty_dirs, missing} of one preprocessed script (Windows paths below root)."""
    files, dirs, missing = set(), set(), []
    for sec, s in sections(pp):
        if sec == "setup" and "=" in s:
            key, value = s.split("=", 1)
            if key.strip().lower() in SETUP_FILE_KEYS:
                files.add(value.strip())
            continue
        if sec != "files":
            continue
        src = param(s, "Source")
        if src is None:
            continue
        flags = set((param(s, "Flags") or "").lower().split())
        if "external" in flags or not src.lower().startswith(ASSET_PREFIXES):
            continue
        folder, pattern = src.rsplit("\\", 1)
        if "*" not in pattern and "?" not in pattern:
            p = resolve(root, src)
            if p is None or not os.path.isfile(p):
                if "skipifsourcedoesntexist" not in flags:
                    missing.append(src)
                continue
            files.add(src)
            continue
        base = resolve(root, folder)
        if base is None:
            if "skipifsourcedoesntexist" not in flags:
                missing.append(src)
            continue
        recurse = "recursesubdirs" in flags
        for dirpath, dirnames, names in os.walk(base):
            rel = os.path.relpath(dirpath, base)
            reldir = "" if rel == "." else rel.replace("/", "\\") + "\\"
            for name in names:
                if fnmatch.fnmatch(name.lower(), pattern.lower()):
                    files.add(folder + "\\" + reldir + name)
            if "createallsubdirs" in flags and recurse and not dirnames and not names and reldir:
                dirs.add(folder + "\\" + reldir.rstrip("\\"))
            if not recurse:
                dirnames[:] = []
    return {"files": sorted(files, key=str.lower), "empty_dirs": sorted(dirs, key=str.lower),
            "missing": missing}


def map_rows(path):
    rows, header = [], None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\r\n")
            if not line or line.startswith("#"):
                continue
            cols = line.split("\t")
            if header is None:
                header = cols
            else:
                rows.append(dict(zip(header, cols)))
    return rows


def compare(product, result, rows):
    """Problems of the read set of product against the map rows."""
    problems = [f"{product}: source missing: {src}" for src in result["missing"]]
    for kind, key in (("file", "files"), ("dir", "empty_dirs")):
        expected = {r["path"].lower(): r["path"] for r in rows
                    if r["kind"] == kind and product in r["products"].split("+")}
        actual = {p.lower(): p for p in result[key]}
        for low in sorted(set(actual) - set(expected)):
            problems.append(f"{product}: read by the script, not in the map ({kind}): {actual[low]}")
        for low in sorted(set(expected) - set(actual)):
            problems.append(f"{product}: in the map, not read by the script ({kind}): {expected[low]}")
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True)
    ap.add_argument("--pp", action="append", required=True, help="EE=<file> or NeoEE=<file>")
    ap.add_argument("--check-map")
    a = ap.parse_args(argv)
    scripts = {}
    for item in a.pp:
        product, sep, path = item.partition("=")
        if not sep or product not in ("EE", "NeoEE"):
            ap.error(f"--pp expects EE=<file> or NeoEE=<file>, got {item!r}")
        scripts[product] = path
    results = {product: read_set(a.root, path) for product, path in scripts.items()}
    if not a.check_map:
        json.dump(results, sys.stdout, indent=0)
        print()
        return 1 if any(r["missing"] for r in results.values()) else 0
    rows = map_rows(a.check_map)
    problems = []
    for product, result in results.items():
        problems += compare(product, result, rows)
        print(f"{product}: the script reads {len(result['files'])} files and "
              f"{len(result['empty_dirs'])} empty folders")
    print(f"read set against {os.path.basename(a.check_map)}: {len(problems)} difference(s)")
    for p in problems[:100]:
        print("PROBLEM", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
