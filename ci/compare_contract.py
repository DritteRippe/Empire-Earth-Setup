#!/usr/bin/env python3
"""Checks that the two copies of docs/CONTRACT.md and of docs/contract-samples (setup and launcher
repository) are identical.

  python ci/compare_contract.py [--repo DIR] OTHER
  python ci/compare_contract.py --self-test

The contract between the Empire Earth Community Setup and the Empire Earth Launcher exists twice, as
docs/CONTRACT.md in both repositories, and both copies must be byte-identical (contract section 5,
question O12). So must the byte samples of the contract next to it, docs/contract-samples (install.ini
of the three install modes, the integrity manifest files.sha256 and the install record as a .reg
file): the launcher tests its readers against them and the setup its writers, so the two folders
must hold the same files with the same bytes. CI has no access to the other repository, so this
check runs locally: after every change of the contract or of a sample, which is always one step in
both repositories.

  OTHER        the other clone (its root folder) or the other CONTRACT.md itself (the samples are
               the folder contract-samples next to it)
  --repo DIR   this clone (default: the repository that contains this script)
  --self-test  checks this script with temporary files and exits

Exit codes:
  0  the copies are identical; the SHA-256 of the contract and of the samples is printed
  1  the copies differ; both SHA-256 values and the first differing line are printed (for the
     samples: per file, and the files only one folder has), and a hint if they only differ in line
     endings (core.autocrlf of one clone; the samples are -text in .gitattributes)
  2  a file or the samples folder is missing or cannot be read, both paths name the same file, or
     wrong usage
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
# The byte samples of the contract, the folder next to CONTRACT.md
SAMPLES = "contract-samples"
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


def sample_files(folder):
    """{relative path with "/": bytes} of every file below the samples folder."""
    return {path.relative_to(folder).as_posix(): path.read_bytes()
            for path in sorted(folder.rglob("*")) if path.is_file()}


def compare_samples(this_dir, other_dir):
    """Compares the two samples folders file by file and returns the exit code (see the module
    documentation)."""
    for path in (this_dir, other_dir):
        if not path.is_dir():
            print(f"compare_contract: folder not found: {path} (the byte samples of the contract)", file=sys.stderr)
            return 2
    try:
        this_files, other_files = sample_files(this_dir), sample_files(other_dir)
    except OSError as error:
        print(f"compare_contract: {error}", file=sys.stderr)
        return 2
    if not this_files:
        print(f"compare_contract: no file in {this_dir} (the byte samples of the contract)", file=sys.stderr)
        return 2

    listing = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n" for name, data in this_files.items())
    if this_files == other_files:
        print(f"docs/{SAMPLES}: both copies are identical ({len(this_files)} files), "
              f"SHA-256 of the list of their hashes {hashlib.sha256(listing.encode('utf-8')).hexdigest()}")
        print(f"  {this_dir}")
        print(f"  {other_dir}")
        return 0

    print(f"docs/{SAMPLES}: the copies DIFFER")
    print(f"  this:  {this_dir}")
    print(f"  other: {other_dir}")
    line_ends_only = True
    for name in sorted(set(this_files) | set(other_files)):
        if name not in other_files:
            print(f"  {name}: only in this copy")
            line_ends_only = False
        elif name not in this_files:
            print(f"  {name}: only in the other copy")
            line_ends_only = False
        elif this_files[name] != other_files[name]:
            a, b = this_files[name], other_files[name]
            print(f"  {name}: differs from line {first_different_line(a, b)} on, SHA-256 "
                  f"{hashlib.sha256(a).hexdigest()} (this) and {hashlib.sha256(b).hexdigest()} (other)")
            if a.replace(b"\r\n", b"\n") != b.replace(b"\r\n", b"\n"):
                line_ends_only = False
    if line_ends_only:
        print("  they differ only in line endings (CRLF/LF): the samples are -text in .gitattributes of both "
              "repositories, git must not convert them; check the attributes and core.autocrlf")
    else:
        print("  change a sample in both repositories in one step, like the contract")
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
    # The byte samples as the real folder has them: install.ini with CRLF, the manifest with LF, a .reg file in UTF-16 LE
    samples = {
        "install-admin.ini": b"[Install]\r\nContractVersion=1\r\nProduct=NeoEE\r\n",
        "files.sha256": b"0" * 64 + b"  Empire Earth/Empire Earth.exe\n",
        "record.reg": "\ufeffWindows Registry Editor Version 5.00\r\n\r\n".encode("utf-16-le"),
    }

    def write_samples(clone, files):
        folder = clone / "docs" / SAMPLES
        if folder.exists():
            for path in folder.iterdir():
                path.unlink()
        else:
            folder.mkdir(parents=True)
        for name, data in files.items():
            (folder / name).write_bytes(data)

    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        setup, launcher, other = temp / "setup", temp / "launcher", temp / "other"
        for clone in (setup, launcher, other):
            (clone / "docs").mkdir(parents=True)
            write_samples(clone, samples)
        (setup / CONTRACT).write_bytes(text)
        (launcher / CONTRACT).write_bytes(text)
        setup_hash = hashlib.sha256(text).hexdigest()

        expect("identical clones", ["--repo", str(setup), str(launcher)], 0, setup_hash,
               "contract-samples: both copies are identical (3 files)")
        expect("identical, other direction", ["--repo", str(launcher), str(setup)], 0, setup_hash)
        expect("identical, file arguments (the samples next to them)",
               ["--repo", str(setup / CONTRACT), str(launcher / CONTRACT)], 0, "identical (3 files)")

        # the byte samples: one byte, a file more or less, line endings converted by git, the folder missing
        write_samples(other, dict(samples, **{"files.sha256": samples["files.sha256"].replace(b"Earth.exe", b"Earth.exf")}))
        (other / CONTRACT).write_bytes(text)
        expect("a sample changed", ["--repo", str(setup), str(other)], 1,
               "contract-samples: the copies DIFFER", "files.sha256: differs from line 1 on",
               "change a sample in both repositories")
        write_samples(other, dict(samples, **{"install-user.ini": b"[Install]\r\n"}))
        expect("a sample only in the other copy", ["--repo", str(setup), str(other)], 1, "install-user.ini: only in the other copy")
        expect("a sample only in this copy", ["--repo", str(other), str(setup)], 1, "install-user.ini: only in this copy")
        write_samples(other, dict(samples, **{"install-admin.ini": samples["install-admin.ini"].replace(b"\r\n", b"\n")}))
        expect("a sample with LF instead of CRLF", ["--repo", str(setup), str(other)], 1,
               "install-admin.ini: differs from line 1 on", "differ only in line endings", "-text in .gitattributes")
        write_samples(other, dict(samples, **{"record.reg": "\ufeffWindows Registry Editor Version 5.00\r\n\r\n".encode("utf-8")}))
        expect("the .reg sample in UTF-8 instead of UTF-16", ["--repo", str(setup), str(other)], 1, "record.reg: differs")
        write_samples(other, samples)
        expect("the samples identical again", ["--repo", str(setup), str(other)], 0, "identical (3 files)")
        for path in (other / "docs" / SAMPLES).iterdir():
            path.unlink()
        (other / "docs" / SAMPLES).rmdir()
        expect("the samples folder missing", ["--repo", str(setup), str(other)], 2, "folder not found", "contract-samples")
        expect("the contract identical, the samples missing: the contract is still compared", ["--repo", str(setup), str(other)], 2,
               "docs/CONTRACT.md: both copies are identical")
        (other / "docs" / SAMPLES).mkdir()
        expect("the samples folder empty here", ["--repo", str(other), str(setup)], 2, "no file in")
        write_samples(other, samples)

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
    this_file, other_file = contract_file(args.repo), contract_file(args.other)
    contract_code = compare(this_file, other_file)
    samples_code = compare_samples(this_file.parent / SAMPLES, other_file.parent / SAMPLES)
    return max(contract_code, samples_code)


if __name__ == "__main__":
    sys.exit(main())
