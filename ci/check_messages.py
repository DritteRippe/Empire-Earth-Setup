#!/usr/bin/env python3
"""Checks messages.iss and the own Inno Setup scripts for mistakes Inno Setup compiles without a
warning.

  python ci/check_messages.py [--coverage] [--sort] [repo_dir]
  python ci/check_messages.py --self-test

  --coverage  also prints, per game language, the custom messages that have no translation (they
              are shown in English) and the zh_TW texts that are copies of the zh_CN ones. This is
              a report for translators (see TRANSLATING.md), not an error.
  --sort      rewrites messages.iss with the translations of every message in the standard order
              (see below) and exits; the content of the messages does not change.
  --self-test runs this check against modified temporary copies of the repository (a new module
              with an undefined message, without BOM, with LF line ends, ...) that must fail, and
              against an unmodified copy that must pass. Exit code 0 if all cases behave.

The suite installer (suite/, ADR 0013) has its own messages in suite/suite_messages.iss: they are
checked like messages.iss (language prefixes against [Languages] of suite/suite.iss, duplicates,
standard order), and a suite script may only use messages defined there. In the suite scripts a
MsgBox or TaskDialogMsgBox call is an error: only SuppressibleMsgBox (and
SuppressibleTaskDialogMsgBox) stay quiet with /SUPPRESSMSGBOXES, and a precheck of the suite must
never wait for a click in an automated run.

The own scripts are found, not listed: every *.iss in the root folder, in ci/tests and in suite, plus every
file that an #include line with a plain file name ("...") names in setup_is6.iss or in a script
found that way, without third-party code under internal/ and without the temporary .iss files
listed in .gitignore (build copies). So a new module is checked from its first commit. An #include
built from an expression (config_<type>.iss) is covered by the root folder.

Errors (exit code 1):
  - a message defined twice for the same language (the later one silently wins), unless the two
    definitions are in different branches of the same #if/#elif/#else,
  - a value starting with "=" (a "key==value" typo),
  - "''" in a value: messages are not Pascal strings, the two apostrophes are shown as they are,
  - a language prefix that is not in [Languages] of setup_is6.iss,
  - a custom message with translations but without the default (English) entry,
  - a custom message used in the own scripts ({cm:Name}, CustomMessage('Name')) that is not
    defined. Names built at run time (e.g. 'LIQP_' + Langs[i]) cannot be checked, except for the
    language names LIQP_<name>: one for every game language in GameLangs of setup_is6.iss,
  - translations not in the standard order: in every group of consecutive entries, the entries of
    a message stay together, the English default first, then the languages in alphabetical order
    of their prefix (de, es, fr, it, ko, pl, pt_BR, ru, zh_CN, zh_TW, then the setup-only
    languages). Inno Setup does not care about the order; it keeps the file easy to compare,
  - an own script that does not start with the UTF-8 BOM (EF BB BF; Inno Setup 6.2 reads a file
    without BOM with the ANSI code page and breaks every non-ASCII text), that is not valid UTF-8,
    or that has a line end other than CRLF (a bare LF or CR),
  - an #include of an own script that does not exist,
  - a MsgBox or TaskDialogMsgBox call in a suite script.
"""
import fnmatch
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Custom messages of Inno Setup's own Default.isl, available without a definition in messages.iss
INNO_CUSTOM_MESSAGES = {
    "NameAndVersion", "AdditionalIcons", "CreateDesktopIcon", "CreateQuickLaunchIcon",
    "ProgramOnTheWeb", "UninstallProgram", "LaunchProgram", "AssocFileExtension",
    "AssocingFileExtension", "AutoStartProgramGroupDescription", "AutoStartProgram",
    "AddonHostProgramNotFound",
}
# Where the own scripts start: the main script; ci/tests holds the unit test setup
MAIN_SCRIPT = "setup_is6.iss"
OWN_SCRIPT_FOLDERS = [".", "ci/tests", "suite"]
# The suite installer: its main script (for [Languages]) and its own messages
SUITE_FOLDER = "suite"
SUITE_SCRIPT = "suite/suite.iss"
SUITE_MESSAGES = "suite/suite_messages.iss"
# Message boxes that wait for a click even with /SUPPRESSMSGBOXES (SuppressibleMsgBox does not)
LOUD_MESSAGE_BOX = re.compile(r"\b(MsgBox|TaskDialogMsgBox)\s*\(")
# Third-party code (download plug-in, music library, language files) keeps its own format
THIRD_PARTY_FOLDER = "internal"
INCLUDE_LINE = re.compile(r'^\s*#\s*include\s+"([^"]+)"\s*$')
# Messages that stay English in every language on purpose (see messages.iss), left out of --coverage
ENGLISH_ON_PURPOSE = {"SoundCtrlButtonCaptionSoundOn", "SoundCtrlButtonCaptionSoundOff"}


def read_lines(path):
    """Logical lines (ISPP joins a line ending with a backslash with the next one) with their number."""
    lines, buf, start = [], None, 0
    for no, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if buf is None:
            buf, start = raw, no
        else:
            buf += raw
        if buf.rstrip().endswith("\\"):
            buf = buf.rstrip()[:-1]
            continue
        lines.append((start, buf))
        buf = None
    if buf is not None:
        lines.append((start, buf))
    return lines


def entry_runs(text_lines):
    """Groups of consecutive message entries of [CustomMessages]/[Messages] as lists of entries;
    an entry is (name, language, physical lines incl. continuation lines, number of its first line).
    Blank lines, comments, directives and section headers end a group."""
    runs, run, section, i = [], [], "", 0
    while i < len(text_lines):
        line = text_lines[i]
        stripped = line.strip()
        is_entry = (section in ("CustomMessages", "Messages") and stripped and "=" in line
                    and not stripped.startswith((";", "//", "#", "[")))
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
        if not is_entry:
            if run:
                runs.append(run)
            run = []
            i += 1
            continue
        start = i
        while text_lines[i].rstrip().endswith("\\") and i + 1 < len(text_lines):
            i += 1
        key = line.split("=", 1)[0].strip()
        lang, name = key.split(".", 1) if "." in key else ("", key)
        run.append((name, lang, text_lines[start:i + 1], start + 1))
        i += 1
    if run:
        runs.append(run)
    return runs


def sorted_run(run, lang_rank):
    """The entries of a group in the standard order (see the module docstring)."""
    first = {}
    for name, _, _, _ in run:
        first.setdefault(name, len(first))
    return sorted(run, key=lambda e: (first[e[0]], lang_rank(e[1])))


def exclusive(path_a, path_b):
    """True if two #if branch paths can never be active together."""
    branches_b = dict(path_b)
    return any(if_id in branches_b and branches_b[if_id] != branch for if_id, branch in path_a)


def relative(root, path):
    """Path relative to the repository with forward slashes, for messages and comparisons. Links
    are not followed (a linked asset folder stays inside the repository); a path outside the
    repository raises ValueError."""
    rel = os.path.relpath(os.path.abspath(path), os.path.abspath(root))
    if rel == os.pardir or rel.startswith(os.pardir + os.sep):
        raise ValueError(rel)
    return Path(rel).as_posix()


def own_scripts(root, errors):
    """The own scripts (see the module docstring) as sorted relative paths with forward slashes.
    An #include of an own script that does not exist is added to errors."""
    gitignore = root / ".gitignore"
    temporary = []
    if gitignore.is_file():
        temporary = [line.strip() for line in gitignore.read_text(encoding="utf-8").splitlines()
                     if line.strip().lower().endswith(".iss") and not line.lstrip().startswith("#")]

    def is_own(rel):
        name = rel.rsplit("/", 1)[-1]
        return (rel.split("/", 1)[0].lower() != THIRD_PARTY_FOLDER
                and not any(fnmatch.fnmatch(name, pattern) or fnmatch.fnmatch(rel, pattern)
                            for pattern in temporary))

    found = set()
    for folder in OWN_SCRIPT_FOLDERS:
        for path in (root / folder).glob("*.iss"):
            rel = relative(root, path)
            if is_own(rel):
                found.add(rel)
    todo = [MAIN_SCRIPT] + sorted(found - {MAIN_SCRIPT})
    seen = set()
    while todo:
        rel = todo.pop(0)
        if rel in seen:
            continue
        seen.add(rel)
        path = root / rel
        if not path.is_file():
            continue
        text = path.read_bytes().decode("utf-8-sig", errors="replace")
        for no, line in enumerate(text.splitlines(), 1):
            match = INCLUDE_LINE.match(line)
            if not match:
                continue
            name = match.group(1).replace("\\", "/")
            # ISPP looks next to the including file first, then next to the main script
            candidates = [path.parent / name, root / name]
            target = next((c for c in candidates if c.is_file()), candidates[0])
            try:
                target_rel = relative(root, target)
            except ValueError:
                errors.append(f"{rel}:{no}: #include \"{match.group(1)}\" is outside the repository")
                continue
            if not is_own(target_rel):
                continue
            if not target.is_file():
                errors.append(f"{rel}:{no}: #include \"{match.group(1)}\": file not found")
                continue
            found.add(target_rel)
            todo.append(target_rel)
    return sorted(found)


def check_encoding(root, rel, errors):
    """UTF-8 with BOM and only CRLF line ends (see the module docstring)."""
    raw = (root / rel).read_bytes()
    if not raw.startswith(b"\xef\xbb\xbf"):
        errors.append(f"{rel}: does not start with the UTF-8 BOM (EF BB BF); Inno Setup 6.2 would "
                      "read it with the ANSI code page (see .editorconfig)")
    try:
        raw.decode("utf-8")
    except UnicodeDecodeError as error:
        errors.append(f"{rel}: not valid UTF-8 (byte {error.start})")
    bare = [m.start() for m in re.finditer(rb"\r(?!\n)|(?<!\r)\n", raw)]
    if bare:
        line = raw.count(b"\n", 0, bare[0]) + 1
        errors.append(f"{rel}:{line}: line end other than CRLF ({len(bare)} in the file; "
                      "the own scripts use CRLF only, see .gitattributes)")


def check_message_file(root, rel, languages, lang_rank, errors, sort):
    """Checks (or, with sort, sorts) the message file rel: the translations of a message in the
    standard order, a known language prefix, no '==' typo or doubled apostrophe, no message defined
    twice, a default (English) entry for every message. Returns (groups of entries, custom message
    names); both are empty after sorting."""
    path = root / rel
    raw = path.read_bytes()
    newline = "\r\n" if b"\r\n" in raw else "\n"
    text_lines = raw.decode("utf-8-sig").split(newline)
    runs = entry_runs(text_lines)
    if sort:
        for run in runs:
            start = run[0][3] - 1
            block = [line for entry in sorted_run(run, lang_rank) for line in entry[2]]
            text_lines[start:start + len(block)] = block
        bom = b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b""
        path.write_bytes(bom + newline.join(text_lines).encode("utf-8"))
        return [], set()
    for run in runs:
        if [e[3] for e in run] != [e[3] for e in sorted_run(run, lang_rank)]:
            errors.append(f"{rel}:{run[0][3]}: translations not in the standard order "
                          "(python ci/check_messages.py --sort fixes it)")

    section, stack, if_count = "", [], 0
    defined = {}  # (section, name, lang) -> [(line, branch path)]
    for no, line in read_lines(path):
        text = line.strip()
        if not text or text.startswith(";") or text.startswith("//"):
            continue
        if text.startswith("#"):
            directive = text[1:].split(None, 1)[0] if len(text) > 1 else ""
            if directive in ("if", "ifdef", "ifndef", "ifexist", "ifnexist"):
                if_count += 1
                stack.append([if_count, 0])
            elif directive in ("elif", "else") and stack:
                stack[-1][1] += 1
            elif directive == "endif" and stack:
                stack.pop()
            continue
        if text.startswith("[") and text.endswith("]"):
            section = text[1:-1]
            continue
        if section not in ("CustomMessages", "Messages") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        lang, name = key.split(".", 1) if "." in key else ("", key)
        where = f"{rel}:{no}: {key}"
        if lang and lang not in languages:
            errors.append(f"{where}: language '{lang}' is not in [Languages]")
        if value.startswith("="):
            errors.append(f"{where}: value starts with '=' (typo '==')")
        if "''" in value:
            errors.append(f"{where}: \"''\" is shown as two apostrophes, use one")
        branch_path = [tuple(b) for b in stack]
        for other_no, other_path in defined.get((section, name, lang), []):
            if not exclusive(branch_path, other_path):
                errors.append(f"{where}: already defined in line {other_no}")
        defined.setdefault((section, name, lang), []).append((no, branch_path))

    custom = {name for (section, name, _) in defined if section == "CustomMessages"}
    for name in sorted(custom):
        if ("CustomMessages", name, "") not in defined:
            errors.append(f"{rel}: custom message {name} has translations but no default entry")
    return runs, custom


def check_suite_message_boxes(rel, text, errors):
    """MsgBox and TaskDialogMsgBox in a suite script (comments left out)."""
    for no, line in enumerate(text.splitlines(), 1):
        code = line.split("//", 1)[0]
        match = LOUD_MESSAGE_BOX.search(code)
        if match:
            errors.append(f"{rel}:{no}: {match.group(1)} waits for a click even with /SUPPRESSMSGBOXES; "
                          "use SuppressibleMsgBox (suite scripts, ADR 0013)")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    options = {a for a in sys.argv[1:] if a.startswith("--")}
    unknown = options - {"--coverage", "--sort", "--self-test"}
    if unknown:
        print(f"unknown option(s): {', '.join(sorted(unknown))}")
        return 2
    root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
    if "--self-test" in options:
        return self_test(root)
    errors = []

    setup_text = (root / "setup_is6.iss").read_text(encoding="utf-8-sig")
    languages = set(re.findall(r'^Name:\s*"([^"]+)";\s*MessagesFile:', setup_text, re.M))
    if not languages:
        errors.append("setup_is6.iss: no [Languages] entries found")
    game_langs = re.search(r'^#dim\s+GameLangs\s*\[[^\]]*\]\s*\{([^}]*)\}', setup_text, re.M)
    game_lang_names = re.findall(r'"([^"]+)"', game_langs.group(1)) if game_langs else []

    # Standard order of the translations: English default, game languages, setup-only languages,
    # each alphabetically; an unknown prefix (reported below) last
    order = [""] + sorted(game_lang_names) + sorted(languages - set(game_lang_names))

    def lang_rank(lang):
        return order.index(lang) if lang in order else len(order)

    runs, custom = check_message_file(root, "messages.iss", languages, lang_rank, errors, "--sort" in options)
    # The suite installer's messages: its own languages (de, en, fr) and its own standard order
    suite_custom = set()
    suite_present = (root / SUITE_SCRIPT).is_file()
    if suite_present:
        suite_text = (root / SUITE_SCRIPT).read_text(encoding="utf-8-sig")
        suite_languages = set(re.findall(r'^Name:\s*"([^"]+)";\s*MessagesFile:', suite_text, re.M))
        suite_order = [""] + sorted(suite_languages)
        if not suite_languages:
            errors.append(f"{SUITE_SCRIPT}: no [Languages] entries found")
        if not (root / SUITE_MESSAGES).is_file():
            errors.append(f"{SUITE_MESSAGES}: file not found (the messages of {SUITE_SCRIPT})")
        else:
            _, suite_custom = check_message_file(
                root, SUITE_MESSAGES, suite_languages,
                lambda lang: suite_order.index(lang) if lang in suite_order else len(suite_order), errors,
                "--sort" in options)
    if "--sort" in options:
        print("messages.iss" + (f" and {SUITE_MESSAGES}" if suite_present else "") + ": translations sorted")
        return 0

    # Game languages: the language page and [Components] (generated) use LIQP_<name>
    if not game_langs:
        errors.append("setup_is6.iss: no '#dim GameLangs[...] {...}' list found")
    else:
        for lang in game_lang_names:
            if "LIQP_" + lang not in custom:
                errors.append(f"setup_is6.iss: game language {lang} has no custom message LIQP_{lang}")

    scripts = own_scripts(root, errors)
    for script in scripts:
        check_encoding(root, script, errors)
        text = (root / script).read_bytes().decode("utf-8-sig", errors="replace")
        in_suite = script.startswith(SUITE_FOLDER + "/")
        available = suite_custom if in_suite else custom
        for name in sorted(set(re.findall(r"\{cm:(\w+)[,}]", text)) | set(re.findall(r"CustomMessage\('(\w+)'\)", text))):
            if name not in available and name not in INNO_CUSTOM_MESSAGES:
                errors.append(f"{script}: custom message {name} is used but not defined"
                              + (f" in {SUITE_MESSAGES}" if in_suite else ""))
        if in_suite:
            check_suite_message_boxes(script, text, errors)

    if "--coverage" in options:
        print_coverage(runs, custom, game_lang_names)

    for error in errors:
        print(error)
    if not errors:
        print(f"{len(scripts)} own scripts (UTF-8 BOM, CRLF, messages used): {', '.join(scripts)}")
    print(f"{len(errors)} problem(s) found" if errors else "messages.iss: OK")
    return 1 if errors else 0


def self_test(source_root):
    """Runs this script against temporary copies of the repository (own scripts and .gitignore):
    the unmodified copy must pass, every modified copy must fail with the expected problem."""
    crlf = b"\r\n"
    bom = b"\xef\xbb\xbf"
    module = bom + b"; self-test module" + crlf + b"[Code]" + crlf

    def new_file(rel, content):
        return lambda root: (root / rel).parent.mkdir(parents=True, exist_ok=True) or (root / rel).write_bytes(content)

    def include(rel):
        def apply(root):
            main = root / MAIN_SCRIPT
            main.write_bytes(main.read_bytes() + b'#include "' + rel.encode() + b'"' + crlf)
        return apply

    def both(*steps):
        return lambda root: [step(root) for step in steps]

    cases = [
        ("unmodified copy", None, None),
        ("new root module with an undefined {cm:...}",
         new_file("selftest.iss", module + b"// {cm:SelfTestUndefinedFoo}" + crlf),
         "selftest.iss: custom message SelfTestUndefinedFoo is used but not defined"),
        ("new root module with an undefined CustomMessage('...')",
         new_file("selftest.iss", module + b"S := CustomMessage('SelfTestUndefinedBar');" + crlf),
         "selftest.iss: custom message SelfTestUndefinedBar is used but not defined"),
        ("new root module without BOM",
         new_file("selftest.iss", module[len(bom):]),
         "selftest.iss: does not start with the UTF-8 BOM"),
        ("new root module with an LF line end",
         new_file("selftest.iss", module + b"// LF only\n"),
         "selftest.iss:3: line end other than CRLF"),
        ("new root module with a CR line end",
         new_file("selftest.iss", module + b"// CR only\r"),
         "selftest.iss:3: line end other than CRLF"),
        ("new root module that is not UTF-8",
         new_file("selftest.iss", module + b"// \xe9" + crlf),
         "selftest.iss: not valid UTF-8"),
        ("module in a subfolder, only reached by #include, with an undefined {cm:...}",
         both(new_file("modules/selftest.iss", module + b"// {cm:SelfTestIncluded}" + crlf),
              include("modules\\selftest.iss")),
         "modules/selftest.iss: custom message SelfTestIncluded is used but not defined"),
        ("module in a subfolder, only reached by #include, without BOM",
         both(new_file("modules/selftest.iss", module[len(bom):]), include("modules\\selftest.iss")),
         "modules/selftest.iss: does not start with the UTF-8 BOM"),
        ("#include of a module that does not exist",
         include("missing_selftest.iss"),
         '#include "missing_selftest.iss": file not found'),
        ("unit test setup with an LF line end",
         lambda root: (root / "ci/tests/unit_tests.iss").write_bytes(
             (root / "ci/tests/unit_tests.iss").read_bytes() + b"// LF only\n"),
         "ci/tests/unit_tests.iss:"),
        ("message used in setup_is6.iss but not defined",
         lambda root: (root / MAIN_SCRIPT).write_bytes(
             (root / MAIN_SCRIPT).read_bytes() + b"// {cm:SelfTestMain}" + crlf),
         "setup_is6.iss: custom message SelfTestMain is used but not defined"),
        ("'==' typo in messages.iss",
         lambda root: (root / "messages.iss").write_bytes(
             (root / "messages.iss").read_bytes() + crlf + b"[CustomMessages]" + crlf
             + b"SelfTestTypo==text" + crlf),
         "SelfTestTypo: value starts with '='"),
        # the suite installer (suite/): its own messages, its own languages, no loud message boxes
        ("message used in a suite script but not defined in suite_messages.iss",
         new_file("suite/selftest.iss", module + b"// {cm:SelfTestSuiteFoo}" + crlf),
         "suite/selftest.iss: custom message SelfTestSuiteFoo is used but not defined in suite/suite_messages.iss"),
        ("message of messages.iss used in a suite script",
         new_file("suite/selftest.iss", module + b"S := CustomMessage('LegalQuestion');" + crlf),
         "suite/selftest.iss: custom message LegalQuestion is used but not defined in suite/suite_messages.iss"),
        ("MsgBox in a suite script",
         new_file("suite/selftest.iss", module + b"MsgBox('x', mbInformation, MB_OK);" + crlf),
         "suite/selftest.iss:3: MsgBox waits for a click even with /SUPPRESSMSGBOXES"),
        ("TaskDialogMsgBox in a suite script",
         new_file("suite/selftest.iss", module + b"  R := TaskDialogMsgBox('a', 'b', 'c', mbInformation, [], 0);" + crlf),
         "suite/selftest.iss:3: TaskDialogMsgBox waits for a click"),
        ("suite script without BOM",
         new_file("suite/selftest.iss", module[len(bom):]),
         "suite/selftest.iss: does not start with the UTF-8 BOM"),
        ("language prefix of a suite message that the suite does not have",
         lambda root: (root / "suite/suite_messages.iss").write_bytes(
             (root / "suite/suite_messages.iss").read_bytes() + b"es.SuiteRunning=x" + crlf),
         "suite/suite_messages.iss:"),
        ("suite message defined twice",
         lambda root: (root / "suite/suite_messages.iss").write_bytes(
             (root / "suite/suite_messages.iss").read_bytes() + b"SuiteRunning=again" + crlf),
         "SuiteRunning: already defined in line"),
        ("suite message with a translation but no English default",
         lambda root: (root / "suite/suite_messages.iss").write_bytes(
             (root / "suite/suite_messages.iss").read_bytes() + b"de.SuiteSelfTestOnly=nur" + crlf),
         "suite/suite_messages.iss: custom message SuiteSelfTestOnly has translations but no default entry"),
        ("suite message translations not in the standard order",
         lambda root: (root / "suite/suite_messages.iss").write_bytes(
             (root / "suite/suite_messages.iss").read_bytes() + b"fr.SuiteSelfTestOrder=fr" + crlf
             + b"de.SuiteSelfTestOrder=de" + crlf + b"SuiteSelfTestOrder=en" + crlf),
         "suite/suite_messages.iss:"),
        ("suite_messages.iss missing",
         lambda root: (root / "suite/suite_messages.iss").unlink(),
         "suite/suite_messages.iss: file not found"),
    ]
    # Must pass: third-party code below internal/ and the temporary build copies of .gitignore
    passing = [
        ("suite script with SuppressibleMsgBox, a MsgBox in a comment and a suite message",
         new_file("suite/selftest.iss", module + b"// MsgBox('x') and {cm:SuiteRunning} are fine here" + crlf
                  + b"SuppressibleMsgBox(CustomMessage('SuiteRunning'), mbError, MB_OK, IDOK);" + crlf
                  + b"SuppressibleTaskDialogMsgBox('a', 'b', mbError, MB_OK, [], 0, MB_OK, IDOK);" + crlf)),
        ("third-party module below internal/ without BOM, with LF and an unknown {cm:...}",
         both(new_file("internal/lib/selftest/selftest.iss", b"// {cm:SelfTestThirdParty}\n"),
              include("internal\\lib\\selftest\\selftest.iss"))),
        ("temporary build copy (_pp_*.iss) without BOM, with LF",
         new_file("_pp_EE_Regular.iss", b"// {cm:SelfTestTemporary}\n")),
    ]
    failures = 0
    with tempfile.TemporaryDirectory(prefix="check_messages_selftest_") as temp:
        for number, (name, change, expected) in enumerate(cases + [(n, c, None) for n, c in passing]):
            root = Path(temp) / f"case{number}"
            for folder in OWN_SCRIPT_FOLDERS:
                (root / folder).mkdir(parents=True, exist_ok=True)
                for path in (source_root / folder).glob("*.iss"):
                    if not fnmatch.fnmatch(path.name, "_pp*_*.iss"):
                        shutil.copy2(path, root / folder / path.name)
            shutil.copy2(source_root / ".gitignore", root / ".gitignore")
            if change:
                change(root)
            result = subprocess.run([sys.executable, str(Path(__file__).resolve()), str(root)],
                                    capture_output=True, text=True, encoding="utf-8")
            output = result.stdout + result.stderr
            if expected is None:
                ok = result.returncode == 0
                want = "exit code 0"
            else:
                ok = result.returncode == 1 and expected in output
                want = f"exit code 1 and '{expected}'"
            print(f"{'PASS' if ok else 'FAIL'} {name}")
            if not ok:
                failures += 1
                print(f"  expected {want}, got exit code {result.returncode}:")
                print("  " + output.strip().replace("\n", "\n  "))
            shutil.rmtree(root)
    total = len(cases) + len(passing)
    print(f"RESULT: {'PASS' if not failures else 'FAIL'} ({total - failures} of {total} cases)")
    return 1 if failures else 0


def print_coverage(runs, custom, game_lang_names):
    """Per game language: custom messages without translation, and zh_TW copies of zh_CN."""
    values = {}  # (name, lang) -> value of the [CustomMessages] entry
    for run in runs:
        for name, lang, lines, _ in run:
            if name in custom:
                values[(name, lang)] = "".join(lines).split("=", 1)[1]
    wanted = sorted(custom - ENGLISH_ON_PURPOSE)
    print(f"Translation coverage: {len(wanted)} custom messages to translate "
          f"(without {', '.join(sorted(ENGLISH_ON_PURPOSE))}, English on purpose)")
    for lang in sorted(game_lang_names):
        if lang == "en":
            continue
        missing = [name for name in wanted if (name, lang) not in values]
        print(f"  {lang:6} {len(wanted) - len(missing):3} translated, {len(missing):3} missing"
              + (": " + ", ".join(missing) if missing else ""))
    copies = [name for name in wanted
              if (name, "zh_TW") in values and values[(name, "zh_TW")] == values.get((name, "zh_CN"))]
    print(f"  zh_TW texts identical to zh_CN ({len(copies)}): " + (", ".join(copies) if copies else "none"))


if __name__ == "__main__":
    sys.exit(main())
