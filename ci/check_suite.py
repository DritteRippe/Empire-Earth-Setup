#!/usr/bin/env python3
"""Checks the frame of the suite installer (suite/suite.iss, ADR 0013) that no compiler checks.

  python ci/check_suite.py [repo_dir]
  python ci/check_suite.py --self-test

The names, the record and the shortcuts are checked against the contract by ci/check_contract.py,
the messages and the message boxes by ci/check_messages.py. This check reads what the suite needs
to stay safe and installable:

  [Setup]   MinVersion=6.1sp1 (Windows 7 SP1 like the products and the launcher), the 64-bit install
            mode, PrivilegesRequired=admin, DiskSpanning=yes with DiskSliceSize from the define
            SliceSize (never a number written into the script: the build script and the CI pass the
            size, and a size below the setup program is refused by ISCC), no pages and no language
            dialog, SetupLogging=yes, CloseApplications=no
  [Files]   every entry is either a product setup (the sources {#EESetupFile} and {#NeoEESetupFile},
            with the flags dontcopy and nocompression and a DestName: byte for byte, extracted by the
            product runner) or a file of the launcher, the Mod Creator or the licenses below {app}
            (ignoreversion, and Check: IsDotNet48: without .NET Framework 4.8 only the games are
            installed)
  [Code]    the exit codes SuiteExit* of suite_common.iss are the numbers 10 to 15, each once; every
            precheck exits through SuiteStop (the only caller of ExitProcess), which writes the log
            line first; the precheck codes 10 to 14 are used by suite.iss

--self-test runs the check against changed temporary copies of the suite files (MinVersion 10.0, a
number as DiskSliceSize, a launcher entry without the Check, a product setup that is compressed,
an exit code twice, ExitProcess outside SuiteStop, ...) that must fail, and the unchanged copy,
which must pass. Exit code 0 if everything is as expected.
"""
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_contract import CheckError, logical_lines, parse_params  # noqa: E402

SUITE_FILES = ["suite/suite.iss", "suite/suite_common.iss", "suite/suite_messages.iss",
               "suite/suite_shortcuts.iss", "suite/suite_record.iss", "suite/suite_pages.iss"]
SETUP_EXPECTED = {
    "MinVersion": "6.1sp1",
    "PrivilegesRequired": "admin",
    "PrivilegesRequiredOverridesAllowed": "commandline",
    "DiskSpanning": "yes",
    "DiskSliceSize": "{#SliceSize}",
    "SolidCompression": "no",
    "UsePreviousAppDir": "yes",
    "DisableDirPage": "yes",
    "DisableProgramGroupPage": "yes",
    "DisableReadyPage": "yes",
    "DisableWelcomePage": "yes",
    "ShowLanguageDialog": "no",
    "SetupLogging": "yes",
    "CloseApplications": "no",
}
PRODUCT_SOURCES = ("{#EESetupFile}", "{#NeoEESetupFile}")
# the legal texts of the wizard: files of the product setups, only extracted to {tmp} by the wizard
# (ci/check_suite_texts.py compares them with the product's)
LEGAL_DESTNAMES = ("EULA_DSML.txt", "neoee_rules.rtf")
EXIT_CODES = {"SuiteExitSilentArguments": 10, "SuiteExitSlices": 11, "SuiteExitZipView": 12,
              "SuiteExitDiskSpace": 13, "SuiteExitRunning": 14, "SuiteExitProductSetup": 15}
# the codes of the prechecks of suite.iss (the code of an embedded setup that does not match its pin
# is used by the product runner)
PRECHECK_CODES = ("SuiteExitSilentArguments", "SuiteExitSlices", "SuiteExitZipView", "SuiteExitDiskSpace",
                  "SuiteExitRunning")


def read(root, rel):
    path = root / rel
    if not path.is_file():
        raise CheckError(f"{rel}: file not found")
    return path.read_text(encoding="utf-8-sig")


def sections(text, name):
    """[(line number, text)] of the entry lines of the section [name] (no comments, no directives)."""
    result, inside = [], False
    for no, line in logical_lines(text):
        stripped = line.strip()
        if re.fullmatch(r"\[[A-Za-z]+\]", stripped):
            inside = stripped[1:-1].lower() == name.lower()
            continue
        if inside and stripped and not stripped.startswith((";", "#", "//")):
            result.append((no, line))
    return result


def check_setup(text, errors):
    found = {}
    for no, line in sections(text, "Setup"):
        key, sep, value = line.partition("=")
        if sep:
            found.setdefault(key.strip(), []).append((no, value.strip()))
    for key, wanted in SETUP_EXPECTED.items():
        if key not in found:
            errors.append(f"suite/suite.iss: [Setup] has no {key} (expected {wanted})")
        for no, value in found.get(key, []):
            if value.lower() != wanted.lower():
                errors.append(f"suite/suite.iss:{no}: {key}={value}, expected {wanted}")
    for no, value in found.get("ArchitecturesInstallIn64BitMode", [("", "")]):
        if not value.lower().startswith("x64"):
            errors.append(f"suite/suite.iss:{no}: ArchitecturesInstallIn64BitMode={value}: the suite installs in the "
                          "64-bit mode like the products (its record is in the 64-bit view, contract 1.6)")
    for no, value in found.get("Compression", [("", "")]):
        if not value.lower().startswith("lzma"):
            errors.append(f"suite/suite.iss:{no}: Compression={value}, expected lzma or lzma2")
    return len(found)


def check_files(text, errors):
    entries = sections(text, "Files")
    products = launcher = legal = 0
    for no, line in entries:
        params = parse_params(line)
        flags = params.get("flags", "").lower().split()
        source = params.get("source", "")
        where = f"suite/suite.iss:{no}"
        if source in PRODUCT_SOURCES:
            products += 1
            for flag in ("dontcopy", "nocompression"):
                if flag not in flags:
                    errors.append(f"{where}: the product setup {source} has no flag {flag}: it is stored byte for byte "
                                  "and only extracted when its product runs")
            if not params.get("destname"):
                errors.append(f"{where}: the product setup {source} has no DestName (the product runner extracts it "
                              "by a fixed name)")
        elif params.get("destname") in LEGAL_DESTNAMES:
            legal += 1
            if "dontcopy" not in flags:
                errors.append(f"{where}: the legal text {source} has no flag dontcopy: it is shown by the wizard, "
                              "never installed")
        elif params.get("destdir", "").lower().startswith("{app}"):
            launcher += 1
            if params.get("check", "") != "IsDotNet48":
                errors.append(f"{where}: {source} is installed without Check: IsDotNet48 (the launcher needs "
                              ".NET Framework 4.8; without it only the games are installed)")
            if "ignoreversion" not in flags:
                errors.append(f"{where}: {source} has no flag ignoreversion (contract 2.3 style: every run installs "
                              "every file)")
        else:
            errors.append(f"{where}: {source or line.strip()} is neither a product setup, a legal text nor a file below {{app}}")
    if products != 2:
        errors.append(f"suite/suite.iss: [Files] has {products} product setups, expected the two sources "
                      f"{', '.join(PRODUCT_SOURCES)}")
    if legal != len(LEGAL_DESTNAMES):
        errors.append(f"suite/suite.iss: [Files] has {legal} legal texts, expected {len(LEGAL_DESTNAMES)} "
                      f"(DestName {', '.join(LEGAL_DESTNAMES)})")
    if launcher == 0:
        errors.append("suite/suite.iss: [Files] installs nothing below {app} (the launcher is missing)")
    return products, launcher + legal


def code_lines(text):
    """The code lines of the [Code] sections without comments."""
    result = []
    for no, line in sections(text, "Code"):
        code = "" if line.lstrip().startswith("//") else line.split("//", 1)[0]
        if code.strip():
            result.append((no, code))
    return result


def check_exit_codes(common, main, errors):
    values = {}
    for no, line in code_lines(common):
        match = re.match(r"^\s*(SuiteExit\w+)\s*=\s*(\d+)\s*;", line)
        if match:
            values.setdefault(match.group(1), []).append(int(match.group(2)))
    for name, number in EXIT_CODES.items():
        if values.get(name) != [number]:
            errors.append(f"suite/suite_common.iss: {name} is {values.get(name, 'not defined')}, expected {number}")
    for name in sorted(set(values) - set(EXIT_CODES)):
        errors.append(f"suite/suite_common.iss: exit code {name} is not one of {', '.join(EXIT_CODES)}")
    if len({v[0] for v in values.values() if v}) != len([v for v in values.values() if v]):
        errors.append("suite/suite_common.iss: two SuiteExit codes have the same number")
    main_code = code_lines(main)
    for name in PRECHECK_CODES:
        if not any(re.search(rf"\bSuiteStop\s*\(\s*{name}\b", line) for _, line in main_code):
            errors.append(f"suite/suite.iss: no SuiteStop({name}, ...): the precheck does not exit with its code")
    inside_stop, exits = False, 0
    for no, line in main_code:
        if re.match(r"^\s*procedure\s+SuiteStop\b", line):
            inside_stop = True
        elif re.match(r"^\s*(procedure|function)\s", line) and not re.match(r"^\s*procedure\s+ExitProcess\b", line):
            inside_stop = False
        if re.search(r"\bExitProcess\s*\(", line) and not re.match(r"^\s*procedure\s+ExitProcess\b", line):
            exits += 1
            if not inside_stop:
                errors.append(f"suite/suite.iss:{no}: ExitProcess outside SuiteStop (it writes the log line first)")
    if exits == 0:
        errors.append("suite/suite.iss: SuiteStop never calls ExitProcess")
    return len(EXIT_CODES)


def check(root):
    """(errors, summary) for the repository root."""
    errors = []
    if not (root / SUITE_FILES[0]).is_file():
        return [], "suite/suite.iss not present, suite frame rules skipped"
    try:
        main = read(root, SUITE_FILES[0])
        common = read(root, SUITE_FILES[1])
    except CheckError as error:
        return [str(error)], ""
    directives = check_setup(main, errors)
    products, launcher = check_files(main, errors)
    codes = check_exit_codes(common, main, errors)
    return errors, (f"suite frame: {directives} [Setup] directives, {products} product setups and {launcher} "
                    f"launcher, license and legal text entries in [Files], {codes} exit codes")


def self_test(source_root):
    def replace(rel, old, new, count=1):
        def apply(root):
            path = root / rel
            text = path.read_bytes().decode("utf-8")
            old_text, new_text = (value.replace("\r\n", "\n").replace("\n", "\r\n") for value in (old, new))
            if "\r\n" not in text:
                old_text, new_text = old_text.replace("\r\n", "\n"), new_text.replace("\r\n", "\n")
            if text.count(old_text) != count:
                raise AssertionError(f"self-test modification: '{old}' found {text.count(old_text)} times in {rel}, "
                                     f"expected {count}")
            path.write_bytes(text.replace(old_text, new_text).encode("utf-8"))
        return apply

    main, common = "suite/suite.iss", "suite/suite_common.iss"
    cases = [
        ("MinVersion 10.0", replace(main, "MinVersion=6.1sp1", "MinVersion=10.0"), "MinVersion=10.0, expected 6.1sp1"),
        ("no MinVersion", replace(main, "MinVersion=6.1sp1\n", ""), "[Setup] has no MinVersion"),
        ("DiskSliceSize written as a number", replace(main, "DiskSliceSize={#SliceSize}", "DiskSliceSize=50000000"),
         "DiskSliceSize=50000000, expected {#SliceSize}"),
        ("no disk spanning", replace(main, "DiskSpanning=yes", "DiskSpanning=no"), "DiskSpanning=no, expected yes"),
        ("per user installation", replace(main, "PrivilegesRequired=admin", "PrivilegesRequired=lowest"),
         "PrivilegesRequired=lowest, expected admin"),
        ("32-bit install mode", replace(main, "ArchitecturesInstallIn64BitMode=x64 arm64\n", ""),
         "ArchitecturesInstallIn64BitMode=: the suite installs in the 64-bit mode"),
        ("language dialog", replace(main, "ShowLanguageDialog=no", "ShowLanguageDialog=yes"),
         "ShowLanguageDialog=yes, expected no"),
        ("launcher files without Check: IsDotNet48",
         replace(main, 'Source: "{#LauncherDir}\\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsDotNet48',
                 'Source: "{#LauncherDir}\\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs'),
         "installed without Check: IsDotNet48"),
        ("launcher files without ignoreversion",
         replace(main, 'DestDir: "{app}\\Mod Creator"; Excludes: "*.pdb"; Flags: ignoreversion ', 'DestDir: "{app}\\Mod Creator"; Excludes: "*.pdb"; Flags: '),
         "has no flag ignoreversion"),
        ("product setup that is compressed",
         replace(main, 'DestName: "EE_Setup.exe"; Flags: dontcopy nocompression', 'DestName: "EE_Setup.exe"; Flags: dontcopy'),
         "has no flag nocompression"),
        ("product setup that is installed",
         replace(main, 'DestName: "NeoEE_Setup.exe"; Flags: dontcopy nocompression', 'DestName: "NeoEE_Setup.exe"; Flags: nocompression'),
         "has no flag dontcopy"),
        ("product setup without a DestName",
         replace(main, 'DestName: "EE_Setup.exe"; ', ''), "has no DestName"),
        ("a file that is neither",
         replace(main, '[Files]\n', '[Files]\nSource: "x.txt"; DestDir: "{tmp}"\n'), "is neither a product setup, a legal text nor a file below {app}"),
        ("legal text that is installed",
         replace(main, 'DestName: "EULA_DSML.txt"; Flags: dontcopy', 'DestName: "EULA_DSML.txt"; Flags: ignoreversion'),
         "has no flag dontcopy"),
        ("a legal text missing",
         replace(main, 'DestName: "neoee_rules.rtf"; Flags: dontcopy', 'DestName: "rules.rtf"; Flags: dontcopy'),
         "[Files] has 1 legal texts, expected 2"),
        ("exit code 15 as 16", replace(common, "SuiteExitProductSetup = 15;", "SuiteExitProductSetup = 16;"),
         "SuiteExitProductSetup is [16], expected 15"),
        ("exit code twice", replace(common, "SuiteExitRunning = 14;", "SuiteExitRunning = 13;"), "SuiteExitRunning is [13], expected 14"),
        ("another exit code", replace(common, "SuiteExitProductSetup = 15; ", "SuiteExitProductSetup = 15;\n  SuiteExitMore = 16; "),
         "exit code SuiteExitMore is not one of"),
        ("a precheck without its code",
         replace(main, "SuiteStop(SuiteExitRunning,", "SuiteStop(SuiteExitSlices,"), "no SuiteStop(SuiteExitRunning, ...)"),
        ("ExitProcess outside SuiteStop",
         replace(main, "function InitializeSetup(): Boolean;\n", "function InitializeSetup(): Boolean;\nbegin\n  ExitProcess(1);\nend;\n\nfunction InitializeSetup2(): Boolean;\n"),
         "ExitProcess outside SuiteStop"),
    ]
    passing = [("unchanged copy", None, None)]
    failures = 0
    with tempfile.TemporaryDirectory(prefix="check_suite_selftest_") as temp:
        for number, (name, change, expected) in enumerate(passing + cases):
            root = Path(temp) / f"case{number}"
            for rel in SUITE_FILES:
                (root / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source_root / rel, root / rel)
            try:
                if change:
                    change(root)
                errors, summary = check(root)
            except AssertionError as error:
                ok, errors = False, [str(error)]
            else:
                ok = (not errors) if expected is None else any(expected in error for error in errors)
            print(f"{'PASS' if ok else 'FAIL'} {name}")
            if not ok:
                failures += 1
                want = "no problem" if expected is None else f"a problem containing '{expected}'"
                print(f"  expected {want}, got:")
                for error in errors or ["(no problem)"]:
                    print("    " + error)
            shutil.rmtree(root)
    total = len(passing) + len(cases)
    print(f"RESULT: {'PASS' if not failures else 'FAIL'} ({total - failures} of {total} cases)")
    return 1 if failures else 0


def main_function(argv):
    args = [a for a in argv if not a.startswith("--")]
    options = {a for a in argv if a.startswith("--")}
    if options - {"--self-test"}:
        print(f"unknown option(s): {', '.join(sorted(options - {'--self-test'}))}")
        return 2
    root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
    if "--self-test" in options:
        return self_test(root)
    errors, summary = check(root)
    for error in errors:
        print(error)
    print(f"{len(errors)} problem(s) found" if errors else summary)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main_function(sys.argv[1:]))
