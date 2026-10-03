#!/usr/bin/env python3
"""Puts the files of the official 1.7.2 setups where the real-data build of v2 reads them.

Input:
  - the data-free asset map (ci/e2e/assets-map.tsv): one row per file or empty folder the build
    reads, with its path, size, SHA-1 and last write time, but no content;
  - the innoextract output of the official setups (innoextract -e --collisions=rename-all -d DIR);
  - their decompressed setup headers (ci/e2e/inno_headers.py, headers0.bin): the wizard images
    are stored there, not as [Files] entries.

Every file of the map is looked up by size and SHA-1 among the extracted files (names do not
matter, so the collision renaming of innoextract is irrelevant) or among the bitmaps of the setup
headers, copied to ROOT\\<path> and given the map's last write time (UTC, ISCC stores it in the
setup). Empty folders (kind dir, createallsubdirs) are created. Then everything is checked again:
size, SHA-1 and time of every file, every empty folder, and no other file in the asset folders.
Nothing is downloaded and no content is printed: the output only names counts and, on failure,
map paths.

The result is game data: it must stay in the job workspace (never commit, cache, upload or print
it). README.md, section "End-to-end test on Windows", describes the whole flow.

Usage:
  place_assets.py --map assets-map.tsv --root REPO --extract EE=DIR NeoEE=DIR
                  --headers EE=DIR NeoEE=DIR [--products EE NeoEE]
  place_assets.py --map assets-map.tsv --root REPO --verify-only [--products ...]
Exit code 0: every selected file is in place with the expected size, SHA-1 and time, and the asset
folders hold nothing else; 1: a problem (listed by map path); 2: wrong arguments.
"""
import argparse
import calendar
import hashlib
import os
import shutil
import struct
import sys
import time

# The gitignored folders the build reads its assets from (README, Assets)
ASSET_FOLDERS = ("data", "internal\\media", "internal\\misc", "internal\\runtime")
MAX_LISTED_PROBLEMS = 50


def sha1_file(path):
    digest = hashlib.sha1()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def header_bitmaps(headers0):
    """{(sha1, size): bytes} of the bitmaps stored raw in a decompressed setup header: a 32-bit
    length followed by a BITMAPFILEHEADER whose bfSize equals that length (WizardImageFile,
    WizardSmallImageFile)."""
    with open(headers0, "rb") as fh:
        data = fh.read()
    found, i = {}, 0
    while True:
        i = data.find(b"BM", i)
        if i < 0:
            return found
        if i >= 4 and i + 14 <= len(data):
            length = struct.unpack("<I", data[i - 4:i])[0]
            bfsize, reserved1, reserved2, offset = struct.unpack("<IHHI", data[i + 2:i + 14])
            if (length == bfsize and reserved1 == 0 and reserved2 == 0 and 26 <= offset < 2000
                    and i + length <= len(data)):
                blob = data[i:i + length]
                found[(hashlib.sha1(blob).hexdigest(), length)] = blob
        i += 2


def parse_time(text):
    return calendar.timegm(time.strptime(text, "%Y-%m-%dT%H:%M:%SZ"))


def read_map(path):
    """The rows of the map as dicts (kind, path, size, sha1, mtime_utc, products, origin)."""
    rows, header = [], None
    with open(path, encoding="utf-8") as fh:
        for no, line in enumerate(fh, 1):
            line = line.rstrip("\r\n")
            if not line or line.startswith("#"):
                continue
            cols = line.split("\t")
            if header is None:
                header = cols
                continue
            if len(cols) != len(header):
                raise ValueError(f"{path}:{no}: {len(cols)} columns, expected {len(header)}")
            rows.append(dict(zip(header, cols)))
    if header is None:
        raise ValueError(f"{path}: no header line")
    return rows


def select(rows, products):
    return [r for r in rows if set(r["products"].split("+")) & set(products)]


def local_path(root, map_path):
    return os.path.join(root, *map_path.split("\\"))


def parse_pairs(items, what):
    out = {}
    for item in items or []:
        key, sep, value = item.partition("=")
        if not sep or key not in ("EE", "NeoEE") or not value:
            raise SystemExit(f"--{what}: expected EE=<folder> or NeoEE=<folder>, got {item!r}")
        out[key] = value
    return out


def place(rows, root, extract, headers):
    """Copies every file row from the extracted setups or the header bitmaps; returns problems."""
    files = [r for r in rows if r["kind"] == "file"]
    dirs = [r for r in rows if r["kind"] == "dir"]
    problems = []
    wanted = {(r["sha1"], int(r["size"])) for r in files}
    sizes = {size for _, size in wanted}
    store = {}
    for folder in extract.values():
        if not os.path.isdir(folder):
            problems.append(f"extraction folder missing: {folder}")
            continue
        for dirpath, _, names in os.walk(folder):
            for name in names:
                path = os.path.join(dirpath, name)
                size = os.path.getsize(path)
                if size in sizes:   # hash only what can match
                    key = (sha1_file(path), size)
                    if key in wanted:
                        store.setdefault(key, path)
    blobs = {}
    for folder in headers.values():
        headers0 = os.path.join(folder, "headers0.bin")
        if not os.path.isfile(headers0):
            problems.append(f"setup header missing: {headers0}")
            continue
        blobs.update(header_bitmaps(headers0))
    copied = from_header = 0
    for r in files:
        key = (r["sha1"], int(r["size"]))
        dst = local_path(root, r["path"])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if r["origin"].startswith("setup:") and key in store:
            shutil.copyfile(store[key], dst)
            copied += 1
        elif r["origin"].startswith("header:") and key in blobs:
            with open(dst, "wb") as fh:
                fh.write(blobs[key])
            from_header += 1
        else:
            problems.append(f"no source for {r['path']} ({r['origin']})")
            continue
        if r["mtime_utc"] != "-":
            t = parse_time(r["mtime_utc"])
            os.utime(dst, (t, t))
    for r in dirs:
        os.makedirs(local_path(root, r["path"]), exist_ok=True)
    print(f"placed {copied} files from the setups, {from_header} from the setup headers, "
          f"{len(dirs)} empty folders")
    return problems


def verify(rows, all_rows, root, check_extra):
    """Checks every selected file and empty folder; with check_extra also that the asset folders
    hold no file the map does not name (for any product). Returns problems."""
    problems = []
    files = [r for r in rows if r["kind"] == "file"]
    dirs = [r for r in rows if r["kind"] == "dir"]
    for r in files:
        p = local_path(root, r["path"])
        if not os.path.isfile(p):
            problems.append(f"missing {r['path']}")
            continue
        if os.path.getsize(p) != int(r["size"]) or sha1_file(p) != r["sha1"]:
            problems.append(f"content differs {r['path']}")
        if r["mtime_utc"] != "-" and int(os.stat(p).st_mtime) != parse_time(r["mtime_utc"]):
            problems.append(f"time differs {r['path']}")
    for r in dirs:
        p = local_path(root, r["path"])
        if not os.path.isdir(p) or os.listdir(p):
            problems.append(f"not an empty folder {r['path']}")
    if check_extra:
        known = {r["path"].lower() for r in all_rows if r["kind"] in ("file", "generated")}
        for folder in ASSET_FOLDERS:
            base = local_path(root, folder)
            for dirpath, _, names in os.walk(base):
                for name in names:
                    rel = os.path.relpath(os.path.join(dirpath, name), root).replace("/", "\\")
                    if rel.lower() not in known:
                        problems.append(f"not in the map: {rel}")
    print(f"verified {len(files)} files and {len(dirs)} empty folders: {len(problems)} problem(s)")
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--map", required=True, help="ci/e2e/assets-map.tsv")
    ap.add_argument("--root", required=True, help="repository root (the asset folders are below it)")
    ap.add_argument("--extract", nargs="+", default=[], help="EE=<folder> NeoEE=<folder> (innoextract output)")
    ap.add_argument("--headers", nargs="+", default=[], help="EE=<folder> NeoEE=<folder> (with headers0.bin)")
    ap.add_argument("--products", nargs="+", default=["EE", "NeoEE"], choices=["EE", "NeoEE"])
    ap.add_argument("--verify-only", action="store_true", help="only check what is in place")
    a = ap.parse_args(argv)

    all_rows = read_map(a.map)
    rows = select(all_rows, a.products)
    start = time.time()
    problems = []
    if not a.verify_only:
        extract = parse_pairs(a.extract, "extract")
        headers = parse_pairs(a.headers, "headers")
        if not extract or not headers:
            ap.error("--extract and --headers are required unless --verify-only is given")
        problems += place(rows, a.root, extract, headers)
    # Extra files only count when both products are selected: a single product reads a subset
    problems += verify(rows, all_rows, a.root, set(a.products) == {"EE", "NeoEE"})
    print(f"{'+'.join(a.products)}: {len(problems)} problem(s) in {time.time() - start:.0f} s")
    for p in problems[:MAX_LISTED_PROBLEMS]:
        print("PROBLEM", p)
    if len(problems) > MAX_LISTED_PROBLEMS:
        print(f"... and {len(problems) - MAX_LISTED_PROBLEMS} more")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
