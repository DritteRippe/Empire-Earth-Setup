#!/usr/bin/env python3
"""Checks that the two copies of docs/CONTRACT.md (setup and launcher repository) are identical.

  python ci/compare_contract.py [--repo DIR] OTHER
  python ci/compare_contract.py --self-test

The contract between the Empire Earth Community Setup and the Empire Earth Launcher exists twice, as
docs/CONTRACT.md in both repositories, and both copies must be byte-identical (contract section 5,
question O12). CI has no access to the other repository, so this check runs locally: after every
change of the contract, which is always one step in both repositories.

  OTHER        the other clone (its root folder) or the other CONTRACT.md itself
  --repo DIR   this clone (default: the repository that contains this script)
  --self-test  checks this script with temporary files and exits

Exit codes:
  0  the copies are identical; their SHA-256 is printed
  1  the copies differ; both SHA-256 values and the first differing line are printed, and a hint if
     they only differ in line endings (core.autocrlf of one clone)
  2  a file is missing or cannot be read, both paths name the same file, or wrong usage
"""
import argparse
import contextlib
import hashlib
import io
import os
import sys
import tempfile
from pathlib import Path

CONTRACT = Path("docs") / "CONTRACT.md"
REPO = Path(__file__).resolve().parent.parent


def contract_file(path):
    """The CONTRACT.md of a clone, or the path itself if it is not a folder."""
    path = Path(path)
    return path / CONTRACT if path.is_dir() else path


def first_different_line(a, b):
    """Number (1-based) of the line of the first byte that differs between a and b."""
    offset = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    return a.count(b"\n", 0, offset) + 1


def compare(this_file, other_file):
    """Compares the two files and returns the exit code (see the module documentation)."""
    for path in (this_file, other_file):
        if not path.is_file():
            print(f"compare_contract: file not found: {path}", file=sys.stderr)
            return 2
    try:
        if os.path.samefile(this_file, other_file):
            print(f"compare_contract: both paths name the same file: {this_file}", file=sys.stderr)
            return 2
        this_bytes, other_bytes = this_file.read_bytes(), other_file.read_bytes()
    except OSError as error:
        print(f"compare_contract: {error}", file=sys.stderr)
        return 2

    this_hash = hashlib.sha256(this_bytes).hexdigest()
    other_hash = hashlib.sha256(other_bytes).hexdigest()
    if this_bytes == other_bytes:
        print(f"docs/CONTRACT.md: both copies are identical, SHA-256 {this_hash}")
        print(f"  {this_file}")
        print(f"  {other_file}")
        return 0

    print("docs/CONTRACT.md: the copies DIFFER")
    print(f"  {this_hash}  {this_file}")
    print(f"  {other_hash}  {other_file}")
    print(f"  first difference in line {first_different_line(this_bytes, other_bytes)}")
    if this_bytes.replace(b"\r\n", b"\n") == other_bytes.replace(b"\r\n", b"\n"):
        print("  they differ only in line endings (CRLF/LF): check core.autocrlf of both clones")
    else:
        print("  change the contract in both repositories in one step (same text, same commit subject)")
    return 1


def self_test():
    """Runs compare() and main() against temporary copies; returns 0 if every case behaves."""
    failures, cases = [], []

    def run(argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = main(argv)
            except SystemExit as exit_:  # argparse errors
                code = exit_.code
        return code, out.getvalue() + err.getvalue()

    def expect(name, argv, code, *texts):
        cases.append(name)
        actual, output = run(argv)
        if actual != code or not all(text in output for text in texts):
            failures.append(f"{name}: exit code {actual} (expected {code}), output:\n{output}")

    text = "# Setup and launcher contract\n\nLine 3 of the contract.\nLine 4.\n".encode("utf-8")
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        setup, launcher, other = temp / "setup", temp / "launcher", temp / "other"
        for clone in (setup, launcher, other):
            (clone / "docs").mkdir(parents=True)
        (setup / CONTRACT).write_bytes(text)
        (launcher / CONTRACT).write_bytes(text)
        setup_hash = hashlib.sha256(text).hexdigest()

        expect("identical clones", ["--repo", str(setup), str(launcher)], 0, setup_hash)
        expect("identical, other direction", ["--repo", str(launcher), str(setup)], 0, setup_hash)
        expect("identical, file arguments", ["--repo", str(setup / CONTRACT), str(launcher / CONTRACT)], 0)

        changed = text.replace(b"Line 4.", b"Line 4!")
        (other / CONTRACT).write_bytes(changed)
        changed_hash = hashlib.sha256(changed).hexdigest()
        expect("one character changed", ["--repo", str(setup), str(other)], 1,
               setup_hash, changed_hash, "line 4")
        expect("one character changed, other direction", ["--repo", str(other), str(setup)], 1,
               setup_hash, changed_hash, "line 4")

        (other / CONTRACT).write_bytes(text + b"Line 5.\n")
        expect("line added", ["--repo", str(setup), str(other)], 1, "line 5")

        (other / CONTRACT).write_bytes(text.replace(b"\n", b"\r\n"))
        expect("CRLF instead of LF", ["--repo", str(setup), str(other)], 1, "line endings")

        (other / CONTRACT).write_bytes(text[:-1])
        expect("last line end missing", ["--repo", str(setup), str(other)], 1, "line 4")

        (other / CONTRACT).unlink()
        expect("other copy missing", ["--repo", str(setup), str(other)], 2, "file not found")
        expect("this copy missing", ["--repo", str(other), str(setup)], 2, "file not found")
        expect("other clone missing", ["--repo", str(setup), str(temp / "nowhere")], 2, "file not found")
        expect("same file twice", ["--repo", str(setup), str(setup / CONTRACT)], 2, "same file")
        expect("no argument", [], 2)

    if failures:
        print("compare_contract self-test FAILED:")
        for failure in failures:
            print("  " + failure.replace("\n", "\n    "))
        return 1
    print(f"compare_contract self-test passed ({len(cases)} cases)")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n\n")[0], formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="exit codes: 0 identical, 1 different, 2 file missing or wrong usage")
    parser.add_argument("other", nargs="?", help="the other clone or its docs/CONTRACT.md")
    parser.add_argument("--repo", default=str(REPO), help="this clone (default: %(default)s)")
    parser.add_argument("--self-test", action="store_true", help="test this script and exit")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    if not args.other:
        parser.error("the path of the other clone is required")
    return compare(contract_file(args.repo), contract_file(args.other))


if __name__ == "__main__":
    sys.exit(main())
