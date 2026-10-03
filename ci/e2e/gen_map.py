#!/usr/bin/env python3
"""MAINTAINERS, LOCAL ONLY: (re)generates the data-free asset map ci/e2e/assets-map.tsv.

Needs a folder with the complete asset folders of a real-data build (data\\, internal\\media,
internal\\misc, internal\\runtime: the files of the official 1.7.2 setups at the paths the build
reads), the scripts ci/build.ps1 preprocessed for EE/Regular and NeoEE/Regular (-KeepPreprocessed;
the [Files] sections decide what is read), and the innoextract output and decompressed headers
(ci/e2e/inno_headers.py) of the two official setups, which tell where each file comes from.
Run it after a change of [Files] or [Setup] that adds, renames or removes an asset (the CI step
"read set against the map" fails until then). Only names, sizes, SHA-1 values and times are
written, never content; the asset folders and the extraction stay where they are (never commit
them).

Columns (TSV, UTF-8, LF; a comment line, then the header line):
  kind      file | dir (empty folder that createallsubdirs turns into a [Dirs] entry) |
            generated (written by ci/build.ps1 before ISCC runs; listed to check it)
  path      Windows path relative to the repository root, exact case
  size      bytes
  sha1      SHA-1 of the content (lowercase hex)
  mtime_utc last write time, UTC, ISO 8601 with seconds (ISCC stores it in the setup); "-" for the
            wizard bitmaps (ISCC does not store their time) and the generated file
  products  EE, NeoEE or EE+NeoEE (which build reads it)
  origin    setup:<EE|NeoEE|EE+NeoEE> (a file of that official setup, found by SHA-1 and size),
            header:<...> (a bitmap of the decompressed setup header), createallsubdirs, or the
            generator of a generated file

Usage:
  gen_map.py --assets ROOT --pp EE=EE_Regular.iss --pp NeoEE=NeoEE_Regular.iss
             --extract EE=DIR NeoEE=DIR --headers EE=DIR NeoEE=DIR --out ci/e2e/assets-map.tsv
Exit code 0: map written, every file has an origin; 1: a problem (listed, the map is still written
for inspection).
"""
import argparse
import datetime
import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import place_assets  # noqa: E402  (same folder)
import readset  # noqa: E402

COMMENT = ("# Data-free asset map of the v2 real-data build: names, sizes, SHA-1 values and times of "
           "the files of the official 1.7.2 setups, no content (ci/e2e/gen_map.py).")
HEADER = ("kind", "path", "size", "sha1", "mtime_utc", "products", "origin")
GENERATED = "data\\localized-text.sha256"
GENERATOR = "ci/build.ps1 Write-DownloadHashes"


def index(folder):
    """{(sha1, size)} of every file below folder."""
    found = set()
    for dirpath, _, names in os.walk(folder):
        for name in names:
            path = os.path.join(dirpath, name)
            found.add((place_assets.sha1_file(path), os.path.getsize(path)))
    return found


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--assets", required=True)
    ap.add_argument("--pp", action="append", required=True)
    ap.add_argument("--extract", nargs="+", required=True)
    ap.add_argument("--headers", nargs="+", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    scripts = dict(item.split("=", 1) for item in a.pp)
    extract = place_assets.parse_pairs(a.extract, "extract")
    headers = place_assets.parse_pairs(a.headers, "headers")
    products = ("EE", "NeoEE")
    if set(scripts) != set(products) or set(extract) != set(products) or set(headers) != set(products):
        ap.error("--pp, --extract and --headers need EE=... and NeoEE=...")

    problems = []
    files, dirs = {}, {}
    for product in products:
        result = readset.read_set(a.assets, scripts[product])
        problems += [f"{product}: source missing: {src}" for src in result["missing"]]
        for p in result["files"]:
            files.setdefault(p, []).append(product)
        for p in result["empty_dirs"]:
            dirs.setdefault(p, []).append(product)
    stores = {product: index(extract[product]) for product in products}
    bitmaps = {product: set(place_assets.header_bitmaps(os.path.join(headers[product], "headers0.bin")))
               for product in products}

    rows = []
    for p in sorted(files, key=str.lower):
        local = place_assets.local_path(a.assets, p)
        st = os.stat(local)
        key = (place_assets.sha1_file(local), st.st_size)
        in_setup = [v for v in products if key in stores[v]]
        in_header = [v for v in products if key in bitmaps[v]]
        if in_setup:
            origin = "setup:" + "+".join(in_setup)
        elif in_header:
            origin = "header:" + "+".join(in_header)
        else:
            origin = "?"
            problems.append(f"no origin for {p}")
        if origin.startswith("setup:") and st.st_mtime_ns % 10**9:
            problems.append(f"sub-second time of {p}")
        mtime = "-"
        if origin.startswith("setup:"):
            stamp = datetime.datetime.fromtimestamp(st.st_mtime_ns // 10**9, datetime.timezone.utc)
            mtime = stamp.strftime("%Y-%m-%dT%H:%M:%SZ")
        rows.append(("file", p, str(st.st_size), key[0], mtime, "+".join(files[p]), origin))
    for p in sorted(dirs, key=str.lower):
        local = place_assets.local_path(a.assets, p)
        if not os.path.isdir(local) or os.listdir(local):
            problems.append(f"not an empty folder: {p}")
        rows.append(("dir", p, "", "", "", "+".join(dirs[p]), "createallsubdirs"))
    generated = place_assets.local_path(a.assets, GENERATED)
    if os.path.isfile(generated):
        with open(generated, "rb") as fh:
            content = fh.read().replace(b"\r\n", b"\n")   # the map holds the LF form
        rows.append(("generated", GENERATED, str(len(content)), hashlib.sha1(content).hexdigest(), "-",
                     "+".join(products), GENERATOR))
    else:
        problems.append(f"{GENERATED} missing (run ci/build.ps1 -DownloadHashesOnly first)")
    seen = {}
    for r in rows:
        if r[1].lower() in seen:
            problems.append(f"paths that differ only in case: {r[1]}")
        seen[r[1].lower()] = r
        if any(ord(c) > 127 for c in r[1]):
            problems.append(f"path is not ASCII: {r[1]}")

    with open(a.out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(COMMENT + "\n")
        fh.write("\t".join(HEADER) + "\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    print(f"{a.out}: {len(rows)} rows ({len(files)} files, {len(dirs)} empty folders, 1 generated); "
          f"{len(problems)} problem(s)")
    for p in problems:
        print("PROBLEM", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
