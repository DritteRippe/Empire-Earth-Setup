#!/usr/bin/env python3
"""Checks that the legal texts the suite installer shows are the texts of the product setups.

  python ci/check_suite_texts.py [repo_dir]
  python ci/check_suite_texts.py --self-test

A product setup that runs silently skips its legal question, its license page and its information page
(setup_is6.iss ConfirmLegalCopy, LicenseFile, InfoBeforeFile), so the suite (suite/suite_pages.iss)
shows them itself (docs/CONTRACT.md 1.7 point 4). They must not drift from the product's texts:

  question  SuiteLegalQuestion in suite/suite_messages.iss is word for word LegalQuestion of messages.iss,
            in English, German and French (the three languages of the suite; the other languages of
            the product are not in the suite)
  EULA      the file the suite embeds (Source of its [Files] entry, DestName EULA_DSML.txt) is the
            LicenseFile of setup_is6.iss: the same path, or a copy with the same bytes
  rules     the file the suite embeds (DestName neoee_rules.rtf) is MyInfoBeforeFile of config_neoee.iss:
            the same path, or a copy with the same bytes
  pages     suite/suite_pages.iss extracts both files by those DestNames

--self-test runs the check against changed temporary copies (a changed German question, a missing
translation, a copy of the EULA or the rules with other bytes, a source that does not exist, a changed
question in messages.iss, a page script that loads another file) that must fail, and the unchanged
copy, which must pass. Exit code 0 if everything is as expected.
"""
import hashlib
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_contract import CheckError, logical_lines, parse_params  # noqa: E402

LANGUAGES = ("", "de.", "fr.")  # the entry without a prefix is English
FILES = ["messages.iss", "setup_is6.iss", "config_neoee.iss", "suite/suite.iss", "suite/suite_messages.iss",
         "suite/suite_pages.iss"]
EULA_DEST, RULES_DEST = "EULA_DSML.txt", "neoee_rules.rtf"


def read(root, rel):
    path = root / rel
    if not path.is_file():
        raise CheckError(f"{rel}: file not found")
    return path.read_text(encoding="utf-8-sig")


def message(text, name, prefix):
    """The text of the message line '<prefix><name>=...' (None if there is no such line)."""
    found = None
    for line in text.splitlines():
        if line.startswith(f"{prefix}{name}="):
            found = line.split("=", 1)[1]
    return found


def check_question(root, errors):
    product = read(root, "messages.iss")
    suite = read(root, "suite/suite_messages.iss")
    for prefix in LANGUAGES:
        lang = prefix.rstrip(".") or "en"
        wanted = message(product, "LegalQuestion", prefix)
        got = message(suite, "SuiteLegalQuestion", prefix)
        if wanted is None:
            errors.append(f"messages.iss: no {prefix}LegalQuestion (the source of the suite's question, {lang})")
        elif got is None:
            errors.append(f"suite/suite_messages.iss: no {prefix}SuiteLegalQuestion (copy of {prefix}LegalQuestion)")
        elif got != wanted:
            errors.append(f"suite/suite_messages.iss: {prefix}SuiteLegalQuestion differs from {prefix}LegalQuestion "
                          f"of messages.iss ({lang}); the suite shows the product's legal question word for word")


def files_entry(main, dest):
    """(line number, Source) of the [Files] entry of suite.iss with that DestName."""
    inside = False
    for no, line in logical_lines(main):
        stripped = line.strip()
        if re.fullmatch(r"\[[A-Za-z]+\]", stripped):
            inside = stripped[1:-1].lower() == "files"
            continue
        if inside and stripped and not stripped.startswith((";", "#", "//")):
            params = parse_params(line)
            if params.get("destname", "") == dest:
                return no, params.get("source", "")
    return None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_embedded(root, main, rel_source_of_product, what, dest, errors):
    """The file suite.iss embeds as dest is the product's file (same path or same bytes)."""
    entry = files_entry(main, dest)
    if entry is None:
        errors.append(f"suite/suite.iss: no [Files] entry with DestName {dest}: the suite does not embed the {what}")
        return
    no, source = entry
    if "{#" in source:
        errors.append(f"suite/suite.iss:{no}: the Source of the {what} uses a define ({source}); write the path out")
        return
    ours = (root / "suite" / source.replace("\\", "/")).resolve()
    theirs = (root / rel_source_of_product.replace("\\", "/")).resolve()
    if not theirs.is_file():
        errors.append(f"the {what} of the product setup does not exist: {rel_source_of_product}")
    elif not ours.is_file():
        errors.append(f"suite/suite.iss:{no}: the {what} {source} does not exist")
    elif ours != theirs and sha(ours) != sha(theirs):
        errors.append(f"suite/suite.iss:{no}: the {what} {source} differs from the one of the product setup "
                      f"({rel_source_of_product}); embed that file itself")


def check_pages(pages, errors):
    for dest in (EULA_DEST, RULES_DEST):
        if not re.search(r"ExtractTemporaryFile\s*\(\s*'" + re.escape(dest) + r"'\s*\)", pages):
            errors.append(f"suite/suite_pages.iss: does not extract {dest} (ExtractTemporaryFile('{dest}')): the page "
                          "would show another text than the one the check compared")


def check(root):
    """(errors, summary) for the repository root."""
    errors = []
    if not (root / "suite/suite.iss").is_file():
        return [], "suite/suite.iss not present, suite text rules skipped"
    try:
        main = read(root, "suite/suite.iss")
        pages = read(root, "suite/suite_pages.iss")
        setup = read(root, "setup_is6.iss")
        config = read(root, "config_neoee.iss")
        check_question(root, errors)
    except CheckError as error:
        return [str(error)], ""
    license_match = re.search(r"^LicenseFile=(.+?)\s*$", setup, re.M)
    rules_match = re.search(r'^#define\s+MyInfoBeforeFile\s+"([^"]+)"', config, re.M)
    if not license_match:
        errors.append("setup_is6.iss: no LicenseFile= (the EULA the suite has to show)")
    else:
        check_embedded(root, main, license_match.group(1), "EULA", EULA_DEST, errors)
    if not rules_match:
        errors.append("config_neoee.iss: no MyInfoBeforeFile (the NeoEE rules the suite has to show)")
    else:
        check_embedded(root, main, rules_match.group(1), "NeoEE rules", RULES_DEST, errors)
    check_pages(pages, errors)
    return errors, "suite texts: legal question en/de/fr, EULA and NeoEE rules are the product's"


def self_test(source_root):
    def replace(rel, old, new):
        def apply(root):
            path = root / rel
            raw = path.read_bytes().decode("utf-8")
            if raw.count(old) != 1:
                raise AssertionError(f"self-test modification: '{old}' found {raw.count(old)} times in {rel}")
            path.write_bytes(raw.replace(old, new).encode("utf-8"))
        return apply

    def copy_as(rel, source_rel, new_text):
        """suite/<rel> becomes a copy of the product file with new_text appended; suite.iss embeds it."""
        def apply(root):
            target = root / "suite" / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((root / source_rel).read_bytes() + new_text.encode("utf-8"))
        return apply

    def both(*steps):
        def apply(root):
            for step in steps:
                step(root)
        return apply

    eula_src = "data/Empire Earth Base/Empire Earth/EULA_DSML.txt"
    rules_src = "data/NeoEE Base/shared/neoee_rules.rtf"
    eula_line = '..\\data\\Empire Earth Base\\Empire Earth\\EULA_DSML.txt'
    rules_line = '..\\data\\NeoEE Base\\shared\\neoee_rules.rtf'
    cases = [
        ("German question changed", replace("suite/suite_messages.iss", "de.SuiteLegalQuestion=Haben Sie das",
                                            "de.SuiteLegalQuestion=Hast du das"), "de.SuiteLegalQuestion differs"),
        ("English question changed", replace("suite/suite_messages.iss", "SuiteLegalQuestion=Do you have",
                                             "SuiteLegalQuestion=Have you"), "SuiteLegalQuestion differs"),
        ("French question changed", replace("suite/suite_messages.iss", "fr.SuiteLegalQuestion=Avez-vous",
                                            "fr.SuiteLegalQuestion=Avez vous"), "fr.SuiteLegalQuestion differs"),
        ("question changed in the product", replace("messages.iss", "de.LegalQuestion=Haben Sie das",
                                                    "de.LegalQuestion=Haben Sie dein"), "de.SuiteLegalQuestion differs"),
        ("French question missing", replace("suite/suite_messages.iss", "fr.SuiteLegalQuestion=", "fr.SuiteLegalQuestionX="),
         "no fr.SuiteLegalQuestion"),
        ("EULA copy with other bytes",
         both(copy_as("copy/EULA_DSML.txt", eula_src, " extra"),
              replace("suite/suite.iss", eula_line, "copy\\EULA_DSML.txt")), "the EULA copy\\EULA_DSML.txt differs"),
        ("rules copy with other bytes",
         both(copy_as("copy/neoee_rules.rtf", rules_src, " extra"),
              replace("suite/suite.iss", rules_line, "copy\\neoee_rules.rtf")), "the NeoEE rules copy\\neoee_rules.rtf differs"),
        ("EULA source missing", replace("suite/suite.iss", eula_line, "..\\data\\nowhere.txt"), "does not exist"),
        ("EULA not embedded", replace("suite/suite.iss", 'DestName: "EULA_DSML.txt"', 'DestName: "other.txt"'),
         "no [Files] entry with DestName EULA_DSML.txt"),
        ("source with a define", replace("suite/suite.iss", eula_line, "{#LicenseDir}\\EULA_DSML.txt"), "uses a define"),
        ("page loads another file", replace("suite/suite_pages.iss", "ExtractTemporaryFile('neoee_rules.rtf')",
                                            "ExtractTemporaryFile('other.rtf')"), "does not extract neoee_rules.rtf"),
    ]
    passing = [("unchanged copy", None, None)]
    failures = 0
    with tempfile.TemporaryDirectory(prefix="check_suite_texts_selftest_") as temp:
        for number, (name, change, expected) in enumerate(passing + cases):
            root = Path(temp) / f"case{number}"
            for rel in FILES + [eula_src, rules_src]:
                (root / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source_root / rel, root / rel)
            try:
                if change:
                    change(root)
                errors, _ = check(root)
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
