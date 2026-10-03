#!/usr/bin/env python3
"""Guard before the only upload of the real-data end-to-end test: refuses (exit code 1) unless the
report folder holds nothing but small text files.

Checked for the folder and everything below it:
  - the folder is a real folder outside every folder named with --forbid (the job workspace with
    the asset folders, the folder with the extracted setups and the built installers), and no entry
    below it is a symbolic link, junction or other reparse point;
  - only regular files with an allowed extension (.log .txt .md .xml .json .jsonl);
  - each file at most --max-file-mb, all together at most --max-total-mb, at most --max-files;
  - every file is text: no NUL byte (unless it is UTF-16 with a BOM), no file signature of an
    executable, image, audio, video or archive, almost no control characters;
  - no file has the SHA-1 of a file of the asset map (ci/e2e/assets-map.tsv), i.e. no game file
    was copied there under another name.
Only names and counts are printed, never content.

Usage: guard_upload.py --dir REPORT --map ci/e2e/assets-map.tsv [--forbid DIR ...]
                       [--max-file-mb 8] [--max-total-mb 64] [--max-files 400]
"""
import argparse
import hashlib
import os
import stat
import sys

ALLOWED_EXTENSIONS = {".log", ".txt", ".md", ".xml", ".json", ".jsonl"}
# Signatures of files that are not text: executables, images, audio, video, archives, fonts
SIGNATURES = (b"MZ", b"BM", b"\x89PNG", b"GIF8", b"\xff\xd8\xff", b"RIFF", b"fLaC", b"OggS", b"ID3",
              b"PK\x03\x04", b"7z\xbc\xaf", b"Rar!", b"BIK", b"KB2", b"%PDF", b"\x1f\x8b", b"MSCF",
              b"\x00\x00\x01\x00", b"OTTO", b"\x00\x01\x00\x00", b"ITSF", b"\xd0\xcf\x11\xe0")
FILE_ATTRIBUTE_REPARSE_POINT = 0x400


def is_link(path):
    """True for a symbolic link, a junction or any other reparse point."""
    if os.path.islink(path):
        return True
    try:
        st = os.lstat(path)
    except OSError:
        return True
    return bool(getattr(st, "st_file_attributes", 0) & FILE_ATTRIBUTE_REPARSE_POINT)


def inside(path, folder):
    path, folder = os.path.normcase(os.path.realpath(path)), os.path.normcase(os.path.realpath(folder))
    return path == folder or path.startswith(folder.rstrip("\\/") + os.sep)


def map_hashes(path):
    hashes = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            cols = line.rstrip("\r\n").split("\t")
            if len(cols) > 3 and len(cols[3]) == 40 and cols[0] in ("file", "generated"):
                hashes.add(cols[3].lower())
    return hashes


def text_problem(data):
    """Why data is not plain text, or None."""
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        try:
            data.decode("utf-16")
        except UnicodeDecodeError:
            return "not valid UTF-16"
        return None
    for signature in SIGNATURES:
        if data.startswith(signature):
            return "starts with the signature of a binary file"
    if b"\x00" in data:
        return "contains NUL bytes"
    sample = data[:1 << 20]
    controls = sum(1 for b in sample if b < 32 and b not in (9, 10, 12, 13, 27))
    if sample and controls * 200 > len(sample):
        return "contains control characters"
    return None


def check(folder, map_path, forbid, max_file, max_total, max_files):
    problems = []
    if not os.path.isdir(folder) or is_link(folder):
        return [f"{folder} is not a real folder"], 0, 0
    for other in forbid:
        if other and (inside(folder, other) or inside(other, folder)):
            problems.append(f"{folder} overlaps the forbidden folder {other}")
    known = map_hashes(map_path)
    count = total = 0
    for dirpath, dirnames, names in os.walk(folder, followlinks=False):
        for name in list(dirnames):
            if is_link(os.path.join(dirpath, name)):
                problems.append(f"link or junction: {os.path.relpath(os.path.join(dirpath, name), folder)}")
                dirnames.remove(name)
        for name in names:
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, folder)
            count += 1
            if is_link(path) or not stat.S_ISREG(os.lstat(path).st_mode):
                problems.append(f"not a regular file: {rel}")
                continue
            if os.path.splitext(name)[1].lower() not in ALLOWED_EXTENSIONS:
                problems.append(f"extension not allowed: {rel}")
                continue
            size = os.path.getsize(path)
            total += size
            if size > max_file:
                problems.append(f"larger than {max_file // (1 << 20)} MB: {rel}")
                continue
            with open(path, "rb") as fh:
                data = fh.read()
            why = text_problem(data)
            if why:
                problems.append(f"{rel} {why}")
            if hashlib.sha1(data).hexdigest() in known:
                problems.append(f"{rel} is a file of the asset map (game data)")
    if count > max_files:
        problems.append(f"{count} files, at most {max_files} allowed")
    if total > max_total:
        problems.append(f"{total // (1 << 20)} MB in total, at most {max_total // (1 << 20)} MB allowed")
    return problems, count, total


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--map", required=True)
    ap.add_argument("--forbid", nargs="*", default=[])
    ap.add_argument("--max-file-mb", type=int, default=8)
    ap.add_argument("--max-total-mb", type=int, default=64)
    ap.add_argument("--max-files", type=int, default=400)
    a = ap.parse_args(argv)
    problems, count, total = check(a.dir, a.map, a.forbid, a.max_file_mb << 20, a.max_total_mb << 20, a.max_files)
    for p in problems[:50]:
        print("REFUSED", p)
    if problems:
        print(f"upload refused: {len(problems)} problem(s) in {count} files")
        return 1
    print(f"upload allowed: {count} text files, {total / (1 << 20):.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
