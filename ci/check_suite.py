#!/usr/bin/env python3
"""Checks the frame of the suite installer (suite/suite.iss, ADR 0013) that no compiler checks.

  python ci/check_suite.py [repo_dir]
  python ci/check_suite.py --self-test

The names, the record and the shortcuts are checked against the contract by ci/check_contract.py,
the messages and the message boxes by ci/check_messages.py. This check reads what the suite needs
to stay safe and installable:

  [Setup]   MinVersion=6.1sp1 (Windows 7 SP1 like the products and the launcher), the 64-bit install
            mode, PrivilegesRequired=admin without PrivilegesRequiredOverridesAllowed (no /CURRENTUSER
            mode, contract 0), DiskSpanning=yes with DiskSliceSize from the define
            SliceSize (never a number written into the script: the build script and the CI pass the
            size, and a size below the setup program is refused by ISCC), no pages and no language
            dialog, SetupLogging=yes, CloseApplications=no
  [Files]   every entry is either a product setup (the sources {#EESetupFile} and {#NeoEESetupFile},
            with the flags dontcopy and nocompression and a DestName: byte for byte, extracted by the
            product runner) or a file of the launcher, the Mod Creator or the licenses below {app}
            (ignoreversion, and Check: IsDotNet48: without .NET Framework 4.8 only the games are
            installed)
  [Slices]  the build records the number and the total size of the slices (SliceCount, SliceTotal), never
            their single sizes (the digits changed setup.exe and with it slice 1: the build never became
            stable); the first pass is named "PASS1 DO NOT SHIP"
  [Modes]   InitializeSetup stops outside the admin install mode; no HKLM64 or HKCU64 (they raise an error on a
            32-bit Windows, which the suite supports; HKLM and HKCU are the 64-bit views in its install mode)
  [Code]    the exit codes SuiteExit* of suite_common.iss are the numbers 10 to 15, each once; every
            precheck exits through SuiteStop (the only caller of ExitProcess), which writes the log
            line first; the precheck codes 10 to 14 are used by suite.iss

  [Runner]  suite/suite_run.iss (the product runner): suite.iss includes it, runs it at ssInstall and
            creates the shortcuts, writes the record and marks its own uninstall key
            (MarkSuiteUninstallKey) only at ssPostInstall (so after the legacy shortcut cleanup);
            the product setup is started by SuiteStartProduct, called once in SuiteRunProduct after
            SuiteExtractAndCheck (which compares size and SHA-256 with SuitePinMatches), no Exec and no
            ShellExec, the lock of the extracted file is kept until the wait has returned, and
            PrepareToInstall stops with SuiteExitProductSetup; no DelTree and no registry deletion;
            DeleteFile only on the extracted product setup, the log of the product setup and the old
            shortcut files of SuiteLegacyShortcutPath
  [Process] the product setup as a process (suite 1.1.0, S2): exactly one CreateProcessW (SuiteCreateProcess in
            SuiteStartProduct, which starts the process suspended, puts it in a job object and only then resumes
            it), no other import that starts a program or limits a job (no kill on close); TerminateJobObject and
            TerminateProcess only in SuiteKillProduct, which only SuiteStartProduct (a start that failed) and
            SuiteStopProduct call, and SuiteStopProduct only in the three places of SuiteWaitForProduct that may
            stop a product setup (the confirmed cancel before the point of no return, the answer to the stall
            question, the cap with a job); every wait for a process is bounded; the wait pumps the messages and
            watches the limits; CancelButtonClick answers while a product setup runs; /TestCancel is read once;
            after a cancel no further product setup starts and Setup ends with Abort
  [Display] the progress in the window of the suite (suite 1.1.0, S4): SuiteShowProgress (called by SuiteLookAtLog) leaves
            the advanced mode alone, takes the bar from SuiteRunningPermille (never 100 percent while a product setup
            runs), fails only into a log line (try/except, SuiteProgressBroken) and does not touch the bar's end; the bar
            reaches the end of a step in SuiteEndProductDisplay only, which SuiteRunProducts calls after
            SuiteRunProduct returned; SuiteRunProducts puts the style, Max and Position of the bar back; the list
            of the finished steps shows only (SuiteStageClickCheck puts a clicked box back)
  [Shortcuts] suite/suite_shortcuts.iss (contract 1.7 point 8, revision 6): SuiteRemoveOldSuiteShortcuts deletes the
            paths of SuiteOldSuiteShortcutPath only (DeleteFile(Path)), each only after SuiteOldSuiteShortcutRemovable
            said so, and ApplySuiteShortcuts calls it before the first SuiteShortcut, so that every install, update,
            repair and uninstallation deletes the shortcuts of suite 1.0.0 and, while installing, creates the one shortcut
            after that; when removing, SuiteShortcut deletes the shortcut file it names (DeleteFile(Link)); no other file
            is deleted by suite_shortcuts.iss
  [Marker]  MarkSuiteUninstallKey (suite/suite_record.iss, contract 1.3, revision 5) asks RegKeyExists
            before it writes with RegWriteDWordValue (no stub key is created) and deletes nothing
            (ci/check_contract.py checks the value, its type and the key)
  [Uninstaller] suite/suite_uninstall.iss: suite.iss includes it and runs the product uninstallers at
            usUninstall, the shortcuts, the record and the user data at usPostUninstall; InitializeUninstall
            checks the game and launcher mutexes, holds the setup mutex of [Setup] and asks one question
            (not in a silent run); the only programs it starts are the uninstaller of a product (after
            SuiteIsProductUninstaller) and ping for a pause; the data folders it offers are no link and not behind
            one, and not those of a product that stays installed; DelTree only in SuiteDeleteDataFolders, called only
            after the answer "Delete" (the second button, never in a silent run); DeleteFile and RemoveDir only
            on the paths of the helpers of suite_common.iss, and RemoveDir on the empty {app} in
            SuiteRemoveEmptyRoot (not a link, not behind one); no registry deletion except RemoveSuiteRecord;
            [UninstallDelete] names {app}\Logs only; no Setup-only function (WizardSilent)
  [Safety]  no suite file mentions the registry key of the CD keys of the original game, the library of the
            NeoEE CD key registration or its function (the suite never reimplements or bypasses the
            registration, contract 1.7 point 5)
  [Log]     the lines of the product logs the suite parses for its progress (the SuiteLog* constants of
            suite/suite_common.iss, contract 1.7 point 5) are still written by the product scripts
            (downloads.iss, installstate.iss, setup_is6.iss, utils.iss), each of them marked there with a
            comment "suite parses this line"; every constant is listed here and used by the parser, and a
            comment of that kind stands only above a listed line; the marker line of the point of no return
            (SuiteLogInstallPhase) is the first statement of CurStepChanged(ssInstall) in setup_is6.iss, before
            anything changes the game folder (DeleteInstallState, VerifyDownloadedFiles, PrepareRandomMapScripts)

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
               "suite/suite_shortcuts.iss", "suite/suite_record.iss", "suite/suite_pages.iss", "suite/suite_run.iss",
               "suite/suite_uninstall.iss"]
SETUP_EXPECTED = {
    "MinVersion": "6.1sp1",
    "PrivilegesRequired": "admin",
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
# the product log lines the suite parses (S3, contract 1.7 point 5): per product script the SuiteLog* constants of
# suite/suite_common.iss whose texts all stand in one line of that script. A reworded line there, or a constant
# that is not listed here, is an error.
PRODUCT_LOG_LINES = [
    ("downloads.iss", ("SuiteLogProbe",)),
    ("downloads.iss", ("SuiteLogCount", "SuiteLogCountEnd")),
    ("downloads.iss", ("SuiteLogFile", "SuiteLogFrom")),
    ("downloads.iss", ("SuiteLogOf", "SuiteLogBytesEnd")),
    ("downloads.iss", ("SuiteLogFileDownloaded",)),
    ("downloads.iss", ("SuiteLogFileFailedBoth",)),
    ("downloads.iss", ("SuiteLogFileNotRetried",)),
    ("downloads.iss", ("SuiteLogFileUnexpected",)),
    ("downloads.iss", ("SuiteLogFileStopped",)),
    ("downloads.iss", ("SuiteLogVerified", "SuiteLogVerifiedEnd")),
    ("downloads.iss", ("SuiteLogAccepted", "SuiteLogAcceptedEnd")),
    ("downloads.iss", ("SuiteLogOf", "SuiteLogMissingEnd")),
    ("setup_is6.iss", ("SuiteLogInstallPhase",)),
    ("setup_is6.iss", ("SuiteLogNoDownload",)),
    ("setup_is6.iss", ("SuiteLogCdKeysStart",)),
    ("setup_is6.iss", ("SuiteLogCdKeysResult",)),
    ("installstate.iss", ("SuiteLogChecking", "SuiteLogCheckingEnd")),
    ("utils.iss", ("SuiteLogManifest",)),
]
# Inno Setup's own lines: nothing in the product scripts to check. "Starting the installation process." is no point of no
# return: the product's CurStepChanged(ssInstall) runs before it and already changes the game folder, so the point of no
# return is the marker line SuiteLogInstallPhase, which the product script logs as the first statement of that step
# (check_install_marker).
INNO_LOG_CONSTANTS = ("SuiteLogInstallStart", "SuiteLogTempFile", "SuiteLogInstallDone", "SuiteLogDestFile", "SuiteLogClosed")
PRODUCT_LOG_FILES = tuple(sorted({rel for rel, _ in PRODUCT_LOG_LINES}))
LOG_LINE_COMMENT = "suite parses this line"
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


def check_shortcuts(text, errors):
    """Rules for suite/suite_shortcuts.iss (contract 1.7 point 8): the shortcuts of suite 1.0.0 are deleted by
    SuiteRemoveOldSuiteShortcuts only (the paths of SuiteOldSuiteShortcutPath, each after SuiteOldSuiteShortcutRemovable),
    ApplySuiteShortcuts calls it before the first SuiteShortcut, the removal of SuiteShortcut deletes the shortcut it
    names, and nothing else is deleted."""
    where = "suite/suite_shortcuts.iss"
    code = code_lines(text)
    bodies = function_bodies(code)
    old = bodies.get("SuiteRemoveOldSuiteShortcuts", "")
    path_at, removable_at, delete_at = old.find("SuiteOldSuiteShortcutPath("), old.find("SuiteOldSuiteShortcutRemovable("), \
        old.find("DeleteFile(Path)")
    if path_at < 0 or delete_at < 0 or path_at > delete_at or len(re.findall(r"\bPath\s*:=", old)) != 1:
        errors.append(f"{where}: SuiteRemoveOldSuiteShortcuts must delete the paths of SuiteOldSuiteShortcutPath only "
                      "(DeleteFile(Path) after the one assignment Path := SuiteOldSuiteShortcutPath(...))")
    elif removable_at < 0 or removable_at > delete_at:
        errors.append(f"{where}: SuiteRemoveOldSuiteShortcuts must ask SuiteOldSuiteShortcutRemovable before DeleteFile(Path): "
                      "the desktop shortcut Empire Earth is the EE setup's own unless it starts the launcher")
    apply = bodies.get("ApplySuiteShortcuts", "")
    old_at, first_at = apply.find("SuiteRemoveOldSuiteShortcuts;"), apply.find("SuiteShortcut(")
    if old_at < 0 or first_at < 0 or old_at > first_at:
        errors.append(f"{where}: ApplySuiteShortcuts must call SuiteRemoveOldSuiteShortcuts before the first SuiteShortcut "
                      "(for installing and for removing)")
    shortcut = bodies.get("SuiteShortcut", "")
    if not re.search(r"if\s+SuiteShortcutsRemoving\s+then.*?\bDeleteFile\(Link\).*?\bExit;", shortcut, re.DOTALL):
        errors.append(f"{where}: when removing, SuiteShortcut must delete the shortcut file it names (DeleteFile(Link)) and "
                      "exit before it creates anything")
    for no, line in code:
        for argument in call_arguments(line, "DeleteFile"):
            if argument not in ("Link", "Path"):
                errors.append(f"{where}:{no}: DeleteFile({argument}): the suite deletes the shortcut it names (Link) and the "
                              "shortcuts of suite 1.0.0 (Path of SuiteOldSuiteShortcutPath), no other file")


def check_frame_rules(main, files, errors):
    """Rules for the slice check, the install mode and the registry views; the number of rules checked."""
    main_code = "\n".join(line for _, line in code_lines(main))
    if re.search(r"SliceSizes", main):
        errors.append("suite/suite.iss: SliceSizes: the build records the number and the total size of the slices "
                      "(SliceCount, SliceTotal), not their single sizes (they change with setup.exe, the build "
                      "never becomes stable)")
    for needed, text in (("#define SliceTotal", "define SliceTotal"),
                         ("SuiteSliceTotal = {#SliceTotal};", "compile SuiteSliceTotal from SliceTotal"),
                         ("SuiteSliceMax = {#SliceSize};", "compile SuiteSliceMax from SliceSize"),
                         ('#define SuiteOutputFile SuiteOutputName + " PASS1 DO NOT SHIP"', "name the output of the first pass "
                          '"PASS1 DO NOT SHIP" (it has no slice check)'),
                         ("OutputBaseFilename={#SuiteOutputFile}", "use SuiteOutputFile as OutputBaseFilename")):
        if needed not in main:
            errors.append(f"suite/suite.iss: must {text} ({needed})")
    if not re.search(r"\bSuiteFindSliceProblems\(Src, SuiteSetupBaseName, SuiteSliceCount, SuiteSliceMax, SuiteSliceTotal,", main_code):
        errors.append("suite/suite.iss: InitializeSetup must call SuiteFindSliceProblems with the count, the largest "
                      "size and the total size of the slices")
    if re.search(r"^\s*PrivilegesRequiredOverridesAllowed\s*=", main, re.MULTILINE):
        errors.append("suite/suite.iss: PrivilegesRequiredOverridesAllowed is set: the suite is only installed for all "
                      "users (contract 0), /CURRENTUSER must not work, not even in a test build")
    init = function_bodies(code_lines(main)).get("InitializeSetup", "")
    guard = re.search(r"if\s+not\s+IsAdminInstallMode\s+then\s+SuiteStop\(", init)
    if not guard or guard.start() > init.find("SuiteSilentArgumentsProblem("):
        errors.append("suite/suite.iss: InitializeSetup must stop first if not IsAdminInstallMode")
    check_shortcuts(files.get("suite/suite_shortcuts.iss", ""), errors)
    for rel, text in files.items():
        for no, line in code_lines(text):
            if re.search(r"\b(HKLM64|HKCU64|HKLM32|HKCU32)\b", line):
                errors.append(f"{rel}:{no}: HKLM64, HKCU64, HKLM32 and HKCU32 raise an error on a 32-bit Windows (the "
                              "suite supports it) or leave the 64-bit view: use HKLM and HKCU")
    return 6


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


FORBIDDEN_WORDS = re.compile(r"sierra|authtools|generate_cdkeys", re.IGNORECASE)
# the arguments the runner may give DeleteFile: its extracted product setup (Exe, or {tmp} plus the name of
# the embedded setup), the log of the product setup it starts, and an old shortcut file of SuiteLegacyShortcutPath
DELETE_FILE_ARGUMENTS = {"Exe", "LogFile", "Path", "ExpandConstant('{tmp}\\') + SuiteProductSetupFile(Product)"}


def call_arguments(line, name):
    """The texts between the parentheses of every call of name in a line (nested parentheses balanced)."""
    result = []
    for match in re.finditer(rf"\b{name}\s*\(", line):
        depth, start = 1, match.end()
        for index in range(start, len(line)):
            depth += {"(": 1, ")": -1}.get(line[index], 0)
            if depth == 0:
                result.append(line[start:index].strip())
                break
    return result


def function_bodies(code):
    """{name: text} of the functions and procedures of a list of (line number, code) lines."""
    bodies, name = {}, None
    for _, line in code:
        match = re.match(r"^(?:function|procedure)\s+(\w+)", line)
        if match:
            name = match.group(1)
            bodies[name] = ""
        if name:
            bodies[name] += line + "\n"
    return bodies


def check_runner(runner, main, errors):
    """Rules for suite/suite_run.iss and for how suite/suite.iss uses it; the number of rules checked."""
    where = "suite/suite_run.iss"
    code = code_lines(runner)
    bodies = function_bodies(code)
    all_code = "\n".join(line for _, line in code)
    main_code = "\n".join(line for _, line in code_lines(main))
    if not re.search(r'^#include\s+"suite_run\.iss"', main, re.MULTILINE):
        errors.append('suite/suite.iss: no #include "suite_run.iss" (the product runner)')
    step = re.search(r"CurStepChanged.*?\bif\s+CurStep\s*=\s*ssInstall\s+then\s+SuiteRunProducts\b"
                     r".*?\belse\s+if\s+CurStep\s*=\s*ssPostInstall\s+then\s+begin\s+ApplySuiteShortcuts\(False\);"
                     r"\s+WriteSuiteRecord;\s+MarkSuiteUninstallKey;", main_code, re.DOTALL)
    if not step:
        errors.append("suite/suite.iss: CurStepChanged must run SuiteRunProducts at ssInstall and create the shortcuts "
                      "and the record and mark the uninstall key of the suite (ApplySuiteShortcuts(False), WriteSuiteRecord, "
                      "MarkSuiteUninstallKey) only at ssPostInstall, after the legacy shortcut cleanup of the runner")
    execs = [e.replace(" ", "") for e in re.findall(r"\b(?:Exec|ExecAsOriginalUser|ShellExec|ShellExecAsOriginalUser)\s*\(", all_code)]
    if execs:
        errors.append(f"{where}: the runner must not start a program with Exec or ShellExec (they give no process handle, "
                      f"so Cancel and the time limits could not stop it): SuiteStartProduct starts the product setup "
                      f"(found: {', '.join(execs)})")
    run = bodies.get("SuiteRunProduct", "")
    start_at = run.find("SuiteStartProduct(")
    check_at = run.find("SuiteExtractAndCheck(")
    if start_at < 0 or check_at < 0 or check_at > start_at:
        errors.append(f"{where}: SuiteRunProduct must call SuiteExtractAndCheck (the pin check) before SuiteStartProduct")
    extract = bodies.get("SuiteExtractAndCheck", "")
    if "SuitePinMatches(" not in extract:
        errors.append(f"{where}: SuiteExtractAndCheck does not compare size and SHA-256 with SuitePinMatches")
    lock_at, hash_at = extract.find("TFileStream.Create("), extract.find("GetSHA256OfFile(")
    if "fmShareDenyWrite" not in extract or lock_at < 0 or hash_at < 0 or lock_at > hash_at:
        errors.append(f"{where}: SuiteExtractAndCheck must lock the extracted file against writing "
                      "(TFileStream.Create(..., fmOpenRead or fmShareDenyWrite)) before it computes the SHA-256")
    # the lock of the extracted file is kept until the wait for the product setup has returned: no Lock.Free between the
    # start and the end of the wait, and one after it
    wait_at = run.find("SuiteWaitForProduct(")
    frees = [m.start() for m in re.finditer(r"Lock\.Free", run)]
    failed = re.search(r"\bExit;\s*end;", run[max(check_at, 0):])  # the end of the branch of a failed pin check
    checked = max(check_at, 0) + (failed.end() if failed else 0)
    if start_at < 0 or wait_at < start_at or not frees or frees[-1] < wait_at or any(checked < free < wait_at for free in frees):
        errors.append(f"{where}: SuiteRunProduct must keep the lock of the extracted file until the wait for the product "
                      "setup has returned (Lock.Free after SuiteWaitForProduct, none before the pin check has passed)")
    prepare = bodies.get("PrepareToInstall", "")
    if "SuiteExtractAndCheck(" not in prepare or not re.search(r"\bSuiteStop\s*\(\s*SuiteExitProductSetup\b", prepare):
        errors.append(f"{where}: PrepareToInstall must check every selected setup and stop with SuiteExitProductSetup "
                      "before any product setup runs")
    if re.search(r"\b(DelTree|RegDeleteKeyIncludingSubkeys|RegDeleteKeyIfEmpty|RegDeleteValue)\s*\(", all_code):
        errors.append(f"{where}: the runner must not call DelTree or delete registry keys or values")
    for no, line in code:
        for argument in call_arguments(line, "DeleteFile"):
            if argument not in DELETE_FILE_ARGUMENTS:
                errors.append(f"{where}:{no}: DeleteFile({argument}): the runner deletes only its extracted "
                              "product setup, the log of the product setup and the old shortcut files of "
                              "SuiteLegacyShortcutPath")
    removes = call_arguments(all_code, "RemoveDir")
    if removes != ["Group"]:
        errors.append(f"{where}: RemoveDir may only remove the start menu folder of the products (Group), found {removes}")
    legacy = bodies.get("SuiteRemoveLegacyShortcuts", "")
    if "SuiteLegacyShortcutPath(" not in legacy or "DeleteFile(Path)" not in legacy:
        errors.append(f"{where}: SuiteRemoveLegacyShortcuts must delete the paths of SuiteLegacyShortcutPath only")
    if not re.search(r"\bSuiteRemoveLegacyShortcuts\(Product\)", run) or \
            run.find("SuiteRunSucceeded(") > run.find("SuiteRemoveLegacyShortcuts(Product)"):
        errors.append(f"{where}: the legacy shortcuts are deleted only after SuiteRunSucceeded said the product succeeded")
    return 9


# the Windows functions that start a program or end one, or give a job object a limit: the runner has exactly one
# CreateProcessW (SuiteStartProduct), one TerminateJobObject and one TerminateProcess (SuiteKillProduct)
PROGRAM_IMPORTS_FORBIDDEN = re.compile(r"^(CreateProcess(?!W$)\w*|ShellExecute\w*|WinExec|CreateRemoteThread|"
                                       r"SetInformationJobObject|NtTerminate\w*|CreateThread)$")
PROGRAM_IMPORTS = {"CreateProcessW": "SuiteCreateProcess", "TerminateProcess": "SuiteTerminateProcess",
                   "TerminateJobObject": "SuiteTerminateJob"}
# who may call what: name -> the functions that call it (each of them must, the rest must not)
PROGRAM_CALLERS = {"SuiteCreateProcess": {"SuiteStartProduct"}, "SuiteTerminateProcess": {"SuiteKillProduct"},
                   "SuiteTerminateJob": {"SuiteKillProduct"}, "SuiteKillProduct": {"SuiteStartProduct", "SuiteStopProduct"},
                   "SuiteStopProduct": {"SuiteWaitForProduct"}, "SuiteStartProduct": {"SuiteRunProduct"}}


def dll_imports(code):
    """[(name in the script, name in the DLL)] of the imports of a text of code lines."""
    result = []
    for match in re.finditer(r"external\s+'([A-Za-z0-9_]+)@", code):
        names = re.findall(r"\b(?:function|procedure)\s+(\w+)", code[:match.start()])
        result.append((names[-1] if names else "?", match.group(1)))
    return result


def call_sites(files, name):
    """[(file, function, number of calls)] of the calls of name( in the functions of the suite files."""
    result = []
    for rel, text in files.items():
        for function, body in function_bodies(code_lines(text)).items():
            calls = len(re.findall(rf"\b{name}\s*\(", body))
            if function == name:
                calls -= 1  # its own declaration
            if calls > 0:
                result.append((rel, function, calls))
    return result


def check_process(files, errors):
    """Rules for the product setup as a process (S2, ADR 0013 amendment): who starts and who stops a program, the job
    object without limits, the bounded waits, Cancel before the point of no return and the end of the run after a
    cancel; the number of rules checked."""
    code = {rel: "\n".join(line for _, line in code_lines(text)) for rel, text in files.items()}
    imports = [(rel, local, win) for rel, text in code.items() for local, win in dll_imports(text)]
    for rel, local, win in imports:
        if PROGRAM_IMPORTS_FORBIDDEN.match(win):
            errors.append(f"{rel}: {local} imports {win}: the suite starts its product setup with SuiteStartProduct "
                          "(CreateProcessW) only, and puts no limit on the job object (a kill on close would leave half "
                          "installed games)")
    for win, local in PROGRAM_IMPORTS.items():
        found = [name for _, name, other in imports if other == win]
        if found != [local]:
            errors.append(f"suite files import {win} as {found}, expected exactly one import named {local}")
    for name, allowed in PROGRAM_CALLERS.items():
        sites = call_sites(files, name)
        callers = {function for _, function, _ in sites}
        if callers != allowed:
            errors.append(f"{name} is called by {sorted(callers) or 'nobody'}, expected {sorted(allowed)}: the one place that "
                          "starts a product setup, the one that stops it and who may call them are fixed")
    counts = {name: sum(n for _, _, n in call_sites(files, name)) for name in ("SuiteCreateProcess", "SuiteStartProduct", "SuiteStopProduct")}
    for name, number in (("SuiteCreateProcess", 1), ("SuiteStartProduct", 1), ("SuiteStopProduct", 3)):
        if counts[name] != number:
            errors.append(f"{name} is called {counts[name]} times, expected {number}")
    bodies = {}
    for text in files.values():
        bodies.update(function_bodies(code_lines(text)))
    wait = bodies.get("SuiteWaitForProduct", "")
    cancel = re.search(r"SuiteCancelRequested then.*?SuiteProgressInstalling\(SuiteChildProgress\) then.*?\bend\s+else\s+begin\s+"
                       r"SuiteStopProduct\(", wait, re.DOTALL)
    stall = re.search(r"SuiteTimeoutStall:.*?SuiteStallStopWanted\(.*?SuiteStopProduct\(", wait, re.DOTALL)
    cap = re.search(r"SuiteTimeoutCap:.*?SuiteProgressInstalling\(SuiteChildProgress\)\s+then\s+Log\(.*?"
                    r"SuiteChildJob\s*<>\s*0\s+then\s+begin\s+SuiteStopProduct\(", wait, re.DOTALL)
    if not (cancel and stall and cap):
        errors.append("suite/suite_run.iss: SuiteWaitForProduct may stop the product setup only (1) after the user confirmed "
                      "the cancel and the log shows that it has not started to install (SuiteCancelRequested, "
                      "SuiteProgressInstalling), (2) after the user answered the stall question (SuiteStallStopWanted) and "
                      "(3) at the cap, only before it started to install (SuiteProgressInstalling is looked at first) and "
                      "with a job (SuiteChildJob <> 0)")
    if "SuiteTimeoutCapInstalling:" not in wait or not re.search(r"SuiteTimeoutCheck\([^;]*SuiteProgressInstalling\(SuiteChildProgress\)", wait):
        errors.append("suite/suite_run.iss: SuiteWaitForProduct must give SuiteTimeoutCheck whether the product setup is installing "
                      "and only log the cap then (SuiteTimeoutCapInstalling): a product setup that installs is never stopped "
                      "for its time")
    ask = bodies.get("SuiteStallStopWanted", "")
    if "SuiteAskStop(" not in ask or "SuiteProductRuns" not in ask or "SuiteLookAtLog(" not in ask:
        errors.append("suite/suite_run.iss: SuiteStallStopWanted must look at the product setup again after the user answered "
                      "the stall question (SuiteProductRuns, SuiteLookAtLog): it may have ended or started to install while "
                      "the question was open")
    if not re.search(r"\bSuiteProgressInstalling\(SuiteChildProgress\)\s+then\s+Log\(.*?/TestCancel not requested", wait, re.DOTALL):
        errors.append("suite/suite_run.iss: /TestCancel must not request a cancel of a product setup that is installing already")
    for needed in ("SuitePumpMessages", "SuiteTimeoutCheck(", "SuiteLookAtLog(", "Terminated"):
        if needed not in wait:
            errors.append(f"suite/suite_run.iss: SuiteWaitForProduct must keep the window alive and watch the limits ({needed})")
    start = bodies.get("SuiteStartProduct", "")
    assign_at, resume_at = start.find("SuiteAssignJob("), start.find("SuiteResumeThread(")
    if "SuiteCreateSuspended" not in start or assign_at < 0 or resume_at < assign_at:
        errors.append("suite/suite_common.iss: SuiteStartProduct must start the process suspended (SuiteCreateSuspended), put it "
                      "in the job (SuiteAssignJob) and only then resume it: a loader that already started the real setup "
                      "could not be stopped with it")
    waits = [argument.split(",")[-1].strip() for text in code.values() for argument in re.findall(r"(?<!function )\bSuiteWaitObject\s*\(([^()]*)\)", text)]
    if not waits or any(argument not in ("SuiteWaitSliceMs", "0") for argument in waits):
        errors.append(f"every wait for a process must be bounded (SuiteWaitSliceMs or 0 milliseconds), found {waits}")
    if sum(text.count("SuiteHasParam('/TestCancel')") for text in code.values()) != 1 \
            or "SuiteHasParam('/TestCancel')" not in bodies.get("SuiteRunProducts", ""):
        errors.append("suite/suite_run.iss: /TestCancel (CI scenario S11) must be read once, in SuiteRunProducts")
    button = bodies.get("CancelButtonClick", "")
    for needed in ("Cancel := False;", "Confirm := False;", "SuiteCancelMode(", "SuiteAskCancel"):
        if needed not in button:
            errors.append(f"suite/suite_run.iss: CancelButtonClick must answer the click while a product setup runs ({needed})")
    products = bodies.get("SuiteRunProducts", "")
    if not re.search(r"and\s+not\s+SuiteRunStopped\s+and\s+not\s+SuiteRunCancelled\s+then", products) \
            or not re.search(r"if\s+SuiteRunCancelled\s+then\s+begin\s+if\s+SuiteProductsOk\s*=\s*''\s+then\s+begin.*?\bAbort;", products, re.DOTALL) \
            or products.find("Abort;") < products.find("finally"):
        errors.append("suite/suite_run.iss: after a cancel SuiteRunProducts must start no further product setup and end Setup "
                      "with Abort only if no product succeeded in this run (SuiteProductsOk = ''), after the progress bar was "
                      "restored: a product that finished before the cancel has lost its old shortcuts already, so the run "
                      "goes on to the launcher, the shortcuts and the record for it")
    if "SuiteCancelledProduct" not in bodies.get("SuiteProductResult", ""):
        errors.append("suite/suite_pages.iss: the last page must name the product the user cancelled (SuiteProductResult)")
    if "SuiteChildTimeout" not in bodies.get("SuiteReasonText", ""):
        errors.append("suite/suite_run.iss: SuiteReasonText must name the reason of a product setup the suite stopped")
    return 12


def check_display(files, errors):
    """Rules for what the window shows of the progress of a product setup (S4); the number of rules checked."""
    bodies = {}
    for text in files.values():
        bodies.update(function_bodies(code_lines(text)))
    show = bodies.get("SuiteShowProgress", "")
    if not re.search(r"if\s+SuiteAdvanced\s+or\s+SuiteProgressBroken\s+then\s+Exit;", show):
        errors.append("suite/suite_run.iss: SuiteShowProgress must leave the advanced mode (its wizard is the display, no log is "
                      "read) and a display that failed alone (SuiteAdvanced, SuiteProgressBroken)")
    if not re.search(r"\btry\b.*\bexcept\b.*SuiteProgressBroken\s*:=\s*True;", show, re.DOTALL):
        errors.append("suite/suite_run.iss: SuiteShowProgress must catch its own failure (try, except, SuiteProgressBroken := True): "
                      "the display is never a reason to stop an installation")
    if "SuiteRunningPermille(" not in show or re.search(r"SuiteSetPosition\s*\([^;]*\b1000\b", show):
        errors.append("suite/suite_run.iss: SuiteShowProgress must take the bar from SuiteRunningPermille and never set the end of "
                      "the bar: 100 percent only when the exit code is known (SuiteEndProductDisplay)")
    if "SuiteShowProgress(" not in bodies.get("SuiteLookAtLog", ""):
        errors.append("suite/suite_run.iss: SuiteLookAtLog must show what it read (SuiteShowProgress)")
    ends = [name for name, body in bodies.items()
            if re.search(r"SuiteOverallPermille\s*\([^;]*,\s*1000\s*\)", body) and name != "SuiteOverallPermille"]
    if ends != ["SuiteEndProductDisplay"]:
        errors.append(f"the bar reaches the end of a step in SuiteEndProductDisplay only (found: {ends})")
    products = bodies.get("SuiteRunProducts", "")
    if not re.search(r"if\s+SuiteRunProduct\s*\(.*?\)\s+then\s+SuiteEndProductDisplay\s*\(\s*True\s*\)", products, re.DOTALL) \
            or not re.search(r"SuiteEndProductDisplay\s*\(\s*False\s*\)", products):
        errors.append("suite/suite_run.iss: SuiteRunProducts must end the display of a product with its result after "
                      "SuiteRunProduct returned (SuiteEndProductDisplay(True) or (False))")
    for needed in ("ProgressGauge.Style := OldStyle;", "ProgressGauge.Max := OldMax;", "ProgressGauge.Position := OldPosition;"):
        after_finally = products.split("finally", 1)[1] if "finally" in products else ""
        if needed not in after_finally:
            errors.append(f"suite/suite_run.iss: SuiteRunProducts must put the bar back after the products ({needed})")
    click = bodies.get("SuiteStageClickCheck", "")
    if "SuiteStageTicks" not in click or "Checked[I] :=" not in click \
            or not re.search(r"OnClickCheck\s*:=\s*@SuiteStageClickCheck", bodies.get("SuiteBuildProgressControls", "")):
        errors.append("suite/suite_pages.iss: the list of the finished steps only shows: SuiteBuildProgressControls must set "
                      "OnClickCheck to SuiteStageClickCheck, which puts a clicked box back")
    return 8


def check_marker(record, errors):
    """MarkSuiteUninstallKey (suite_record.iss): RegKeyExists before RegWriteDWordValue, so that no stub key is
    created, and no registry deletion (Inno Setup's uninstaller removes the value with the key); the number of
    rules checked."""
    where = "suite/suite_record.iss"
    body = function_bodies(code_lines(record)).get("MarkSuiteUninstallKey")
    if body is None:
        errors.append(f"{where}: no procedure MarkSuiteUninstallKey (contract 1.3, revision 5)")
        return 2
    exists_at, write_at = body.find("RegKeyExists("), body.find("RegWriteDWordValue(")
    if write_at < 0:
        errors.append(f"{where}: MarkSuiteUninstallKey does not write the marker with RegWriteDWordValue")
    elif exists_at < 0 or exists_at > write_at:
        errors.append(f"{where}: MarkSuiteUninstallKey must ask RegKeyExists for the uninstall key before it writes "
                      "(it must not create a stub key)")
    if re.search(r"\bRegDelete\w*\s*\(", body):
        errors.append(f"{where}: MarkSuiteUninstallKey must not delete registry keys or values")
    return 2


def check_uninstaller(uninstaller, main, files, errors):
    """Rules for suite/suite_uninstall.iss and for how suite/suite.iss uses it; the number of rules checked.
    files is {relative path: text} of every suite file."""
    where = "suite/suite_uninstall.iss"
    code = code_lines(uninstaller)
    bodies = function_bodies(code)
    all_code = "\n".join(line for _, line in code)
    main_code = "\n".join(line for _, line in code_lines(main))
    if not re.search(r'^#include\s+"suite_uninstall\.iss"', main, re.MULTILINE):
        errors.append('suite/suite.iss: no #include "suite_uninstall.iss" (the uninstaller)')
    steps = re.search(r"CurUninstallStepChanged.*?\bif\s+CurUninstallStep\s*=\s*usUninstall\s+then\s+SuiteRemoveProducts\b"
                      r".*?\belse\s+if\s+CurUninstallStep\s*=\s*usPostUninstall\s+then\s+begin\s+ApplySuiteShortcuts\(True\);"
                      r"\s+RemoveSuiteRecord;\s+SuiteRemoveUserData;", main_code, re.DOTALL)
    if not steps:
        errors.append("suite/suite.iss: CurUninstallStepChanged must run SuiteRemoveProducts at usUninstall and "
                      "ApplySuiteShortcuts(True), RemoveSuiteRecord and SuiteRemoveUserData at usPostUninstall")
    # the setup mutex: the same name as [Setup] SetupMutex, checked and held by InitializeUninstall
    declared = re.search(r"\bSuiteSetupMutexName\s*=\s*'([^']*)'", all_code)
    setup_mutex = re.search(r"^SetupMutex=(.*)$", main, re.MULTILINE)
    if not declared or not setup_mutex or declared.group(1) != setup_mutex.group(1).strip():
        errors.append(f"{where}: SuiteSetupMutexName ({declared.group(1) if declared else 'missing'}) must be the "
                      f"[Setup] SetupMutex of suite.iss ({setup_mutex.group(1).strip() if setup_mutex else 'missing'})")
    init = bodies.get("InitializeUninstall", "")
    for needed, text in (("CheckForMutexes(SuiteMutexes)", "check the game and launcher mutexes"),
                         ("CheckForMutexes(SuiteSetupMutexName)", "check the setup mutex of the suite"),
                         ("CreateMutex(SuiteSetupMutexName)", "hold the setup mutex of the suite")):
        if needed not in init:
            errors.append(f"{where}: InitializeUninstall must {text} ({needed})")
    question = re.search(r"if\s+not\s+UninstallSilent\s+then.*?\bSuppressibleMsgBox\s*\(.*?MB_YESNO", init, re.DOTALL)
    if not question:
        errors.append(f"{where}: InitializeUninstall must ask its one question with SuppressibleMsgBox (MB_YESNO) "
                      "and not in a silent run (if not UninstallSilent)")
    # the programs it starts
    execs = re.findall(r"\bExec\s*\(\s*([^,]*),", all_code)
    shell = re.findall(r"\b(?:ShellExec|ShellExecAsOriginalUser|ExecAsOriginalUser)\s*\(", all_code)
    if shell or sorted(e.strip() for e in execs) != sorted(["Exe", "ExpandConstant('{sys}\\ping.exe')"]):
        errors.append(f"{where}: the uninstaller may start only the uninstaller of a product (Exec(Exe, ...)) and "
                      f"ping.exe for a pause (found: {', '.join(e.strip() for e in execs) or 'none'}"
                      f"{', ' + str(len(shell)) + ' ShellExec' if shell else ''})")
    remove = bodies.get("SuiteRemoveProduct", "")
    exec_at = re.search(r"\bExec\s*\(", remove)
    guard = re.search(r"if\s+not\s+SuiteIsProductUninstaller\(Exe,\s*Root\)\s+or\s+not\s+FileExists\(Exe\)\s+then", remove)
    if not exec_at or not guard or guard.start() > exec_at.start():
        errors.append(f"{where}: SuiteRemoveProduct must check SuiteIsProductUninstaller(Exe, Root) and the file before Exec")
    if "'/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'" not in remove:
        errors.append(f"{where}: SuiteRemoveProduct must run the uninstaller with /VERYSILENT /SUPPRESSMSGBOXES /NORESTART")
    if "SuiteUninstallWaitState(" not in remove or "RegKeyExists(HKLM, Key)" not in remove or "FileExists(Exe)" not in remove:
        errors.append(f"{where}: SuiteRemoveProduct must wait with SuiteUninstallWaitState on the uninstall key and the "
                      "program file (the exit code of the first process decides nothing)")
    # the deletions
    trees = call_arguments(all_code, "DelTree")
    if trees != ["Folders[I], True, True, True"] or "DelTree(" not in bodies.get("SuiteDeleteDataFolders", ""):
        errors.append(f"{where}: DelTree may only be called in SuiteDeleteDataFolders, for the folders of its list "
                      f"(found: {trees})")
    data = bodies.get("SuiteRemoveUserData", "")
    calls = re.findall(r"\bSuiteDeleteDataFolders\s*\(", all_code)
    delete_if = re.search(r"if\s+DeleteData\s+then\s+SuiteDeleteDataFolders\(Folders\);", data)
    asked = re.search(r"if\s+UninstallSilent\s+then\s+Log\(.*?\bDeleteData\s*:=\s*SuppressibleTaskDialogMsgBox\(.*?IDYES\)\s*=\s*IDNO;",
                      data, re.DOTALL)
    if len(calls) != 2 or not delete_if or not asked or data.find("SuiteDeleteDataFolders(") < data.find("SuppressibleTaskDialogMsgBox("):
        errors.append(f"{where}: SuiteDeleteDataFolders is only called in SuiteRemoveUserData, after the task dialog of "
                      "the question, with 'if DeleteData then', and DeleteData is only True for the second button "
                      "(IDNO), never in a silent run; the answer of a suppressed box is IDYES (keep)")
    existing = bodies.get("SuiteExistingDataFolders", "")
    if "SuiteDataFolder(" not in existing or "SuiteLauncherDataFolder(" not in existing or "DirExists(" not in existing:
        errors.append(f"{where}: SuiteExistingDataFolders must list only the folders of SuiteDataFolder and "
                      "SuiteLauncherDataFolder that exist")
    if existing.count("SuiteIsBehindLink(") != 2 or "SuiteIsFolderOfInstalledProduct(" not in existing:
        errors.append(f"{where}: SuiteExistingDataFolders must leave out a data folder that is a link or behind one "
                      "(SuiteIsBehindLink, for the folders of the products and of the launcher) and one that belongs to "
                      "a product that stays installed (SuiteIsFolderOfInstalledProduct): DelTree follows such a link")
    for argument in call_arguments(all_code, "DeleteFile"):
        if argument != "Target":
            errors.append(f"{where}: DeleteFile({argument}): the uninstaller deletes only the launcher files of "
                          "SuiteLauncherDataFile")
    if "SuiteLauncherDataFile(" not in data:
        errors.append(f"{where}: SuiteRemoveUserData must take the files it deletes from SuiteLauncherDataFile")
    # RemoveDir(Root) only in SuiteRemoveEmptyRoot, where Root is the folder of the suite and no link
    empty_root = bodies.get("SuiteRemoveEmptyRoot", "")
    root_ok = (re.findall(r"\bRoot\s*:=\s*([^;]*);", empty_root) == ["RemoveBackslash(ExpandConstant('{app}'))"]
               and all_code.count("RemoveDir(Root)") == empty_root.count("RemoveDir(Root)") == 1)
    for argument in call_arguments(all_code, "RemoveDir"):
        if argument != "Target" and not (argument == "Root" and root_ok):
            errors.append(f"{where}: RemoveDir({argument}): the uninstaller removes only the folders of "
                          "SuiteEmptyFolder and SuiteLauncherDataDir, and the empty {app} in SuiteRemoveEmptyRoot")
    if empty_root and not re.search(r"if\s+not\s+DirExists\(Root\)\s+or\s+SuiteIsBehindLink\(Root,\s*Root\)\s+then\s+Exit;",
                                    empty_root):
        errors.append(f"{where}: SuiteRemoveEmptyRoot must leave {{app}} alone if it is a link (SuiteIsBehindLink)")
    if "SuiteEmptyFolder(" not in data or "SuiteLauncherDataDir(" not in data:
        errors.append(f"{where}: SuiteRemoveUserData must take the folders it removes from SuiteEmptyFolder and SuiteLauncherDataDir")
    if re.search(r"\bWizardSilent\b|\bSuiteSilent\b|\bWizardForm\b", all_code):
        errors.append(f"{where}: the uninstaller uses a function of Setup (WizardSilent, SuiteSilent, WizardForm): "
                      "it has UninstallSilent and UninstallProgressForm")
    # no registry deletion but the record's
    for rel, text in files.items():
        for no, line in code_lines(text):
            if re.search(r"\b(RegDeleteKeyIncludingSubkeys|RegDeleteKeyIfEmpty|RegDeleteValue)\s*\(", line) \
                    and rel != "suite/suite_record.iss":
                errors.append(f"{rel}:{no}: only RemoveSuiteRecord deletes registry keys (suite_record.iss)")
    # [UninstallDelete]: the logs folder of the suite and nothing else
    entries = [line.strip() for _, line in sections(main, "UninstallDelete")]
    if entries != ['Type: filesandordirs; Name: "{app}\\Logs"']:
        errors.append(f"suite/suite.iss: [UninstallDelete] must name {{app}}\\Logs only, found {entries}")
    return 12


def check_forbidden_words(root, errors):
    """No suite file (comments included) names what only the NeoEE setup may touch."""
    for rel in SUITE_FILES:
        path = root / rel
        if not path.is_file():
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            match = FORBIDDEN_WORDS.search(line)
            if match:
                errors.append(f"{rel}:{number}: '{match.group(0)}': the suite never touches the CD key registration "
                              "of the NeoEE setup (contract 1.7 point 5)")


def log_constants(common):
    """{name: text} of the SuiteLog* constants of suite_common.iss (the lines of the product logs the suite reads)."""
    pattern = re.compile(r"^[ \t]*(SuiteLog\w+)[ \t]*=[ \t]*'((?:[^']|'')*)';", re.MULTILINE)
    return {match.group(1): match.group(2).replace("''", "'") for match in pattern.finditer(common)}


def check_product_log_lines(root, common, errors):
    """The product log lines the suite parses are still there, marked, listed and used. Returns the number of rows."""
    constants = log_constants(common)
    listed = {name for _, names in PRODUCT_LOG_LINES for name in names} | set(INNO_LOG_CONSTANTS)
    for name in sorted(set(constants) - listed):
        errors.append(f"suite/suite_common.iss: {name} names a product log line the suite reads, but ci/check_suite.py "
                      "does not list it (PRODUCT_LOG_LINES)")
    for name in sorted(listed - set(constants)):
        errors.append(f"ci/check_suite.py lists {name}, which suite/suite_common.iss does not declare")
    for name in sorted(constants):
        if len(re.findall(rf"\b{name}\b", common)) < 2:
            errors.append(f"suite/suite_common.iss: {name} is declared, but the progress parser does not use it")
    lines = {}
    for rel in PRODUCT_LOG_FILES:
        try:
            lines[rel] = list(enumerate(read(root, rel).splitlines(), 1))
        except CheckError as error:
            errors.append(str(error))
    matched = {rel: set() for rel in lines}
    for rel, names in PRODUCT_LOG_LINES:
        if rel not in lines or any(name not in constants for name in names):
            continue
        texts = [constants[name] for name in names]
        found = [no for no, line in lines[rel] if not line.lstrip().startswith("//") and all(text in line for text in texts)]
        if not found:
            errors.append(f"{rel}: no line contains {' and '.join(repr(text) for text in texts)} ({', '.join(names)}): "
                          "the suite parses this line of the product log (contract 1.7 point 5); a change of it "
                          "changes suite/suite_common.iss and the contract in the same commit")
        matched[rel].update(found)
    for rel, entries in lines.items():
        for index, (no, line) in enumerate(entries):
            if no in matched[rel]:
                before = next((text for _, text in reversed(entries[:index]) if text.strip()), "")
                if not (before.lstrip().startswith("//") and LOG_LINE_COMMENT in before):
                    errors.append(f"{rel}:{no}: this log line is parsed by the suite and needs the comment "
                                  f"\"{LOG_LINE_COMMENT}\" in the line above (contract 1.7 point 5)")
            elif line.lstrip().startswith("//") and LOG_LINE_COMMENT in line:
                after = next(((n, text) for n, text in entries[index + 1:] if text.strip() and not text.lstrip().startswith("//")),
                             (0, ""))
                if after[0] not in matched[rel]:
                    errors.append(f"{rel}:{no}: the comment \"{LOG_LINE_COMMENT}\" stands above a line that "
                                  "ci/check_suite.py does not list as a product log line the suite parses")
    return len(PRODUCT_LOG_LINES) + len(INNO_LOG_CONSTANTS)


def check_install_marker(root, common, errors):
    """The marker line of the point of no return is the very first statement of CurStepChanged(ssInstall) of the
    product script: everything that changes the game folder follows it. Returns the number of rules."""
    marker = log_constants(common).get("SuiteLogInstallPhase")
    if marker is None:
        errors.append("suite/suite_common.iss: SuiteLogInstallPhase is not declared")
        return 1
    try:
        lines = read(root, "setup_is6.iss").splitlines()
    except CheckError as error:
        errors.append(str(error))
        return 1
    start = next((i for i, line in enumerate(lines) if re.match(r"\s*procedure CurStepChanged\b", line)), None)
    if start is None:
        errors.append("setup_is6.iss: no procedure CurStepChanged")
        return 1
    step = next((i for i in range(start, len(lines)) if re.match(r"\s*if \(?CurStep = ssInstall\)? then\s*$", lines[i])), None)
    if step is None or step + 1 >= len(lines) or lines[step + 1].strip().lower() != "begin":
        errors.append("setup_is6.iss: CurStepChanged has no block 'if (CurStep = ssInstall) then begin'")
        return 1
    first = next((line.strip() for line in lines[step + 2:] if line.strip() and not line.strip().startswith("//")), "")
    if f"Log('{marker}')" not in first:
        errors.append(f"setup_is6.iss: the first statement of CurStepChanged(ssInstall) must be Log('{marker}') (the point "
                      f"of no return of the suite, contract 1.7 point 5), before DeleteInstallState and every other "
                      f"step that changes the game folder; it is: {first[:80]}")
    return 1


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
    try:
        runner = read(root, SUITE_FILES[6])
    except CheckError as error:
        errors.append(str(error))
        runner = ""
    steps = check_runner(runner, main, errors)
    try:
        marker = check_marker(read(root, SUITE_FILES[4]), errors)
    except CheckError as error:
        errors.append(str(error))
        marker = 0
    try:
        uninstaller = read(root, SUITE_FILES[7])
    except CheckError as error:
        errors.append(str(error))
        uninstaller = ""
    files = {rel: read(root, rel) for rel in SUITE_FILES if (root / rel).is_file()}
    frame = check_frame_rules(main, files, errors)
    removal = check_uninstaller(uninstaller, main, files, errors)
    process = check_process(files, errors)
    display = check_display(files, errors)
    check_forbidden_words(root, errors)
    log_lines = check_product_log_lines(root, common, errors)
    check_install_marker(root, common, errors)
    return errors, (f"suite frame: {directives} [Setup] directives, {products} product setups and {launcher} "
                    f"launcher, license and legal text entries in [Files], {codes} exit codes, {frame} slice, mode and registry view rules, product runner "
                    f"{steps} rules, process {process} rules, display {display} rules, uninstall key marker {marker} rules, uninstaller {removal} rules, no CD key registry or library reference, {log_lines} product log lines the suite parses, the install marker first in CurStepChanged(ssInstall)")


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

    main, common, run = "suite/suite.iss", "suite/suite_common.iss", "suite/suite_run.iss"
    uninstall = "suite/suite_uninstall.iss"
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
        ("a list of the single slice sizes", replace(main, "  #define SliceTotal 0\n", "  #define SliceTotal 0\n  #define SliceSizes \"\"\n"),
         "SliceSizes: the build records the number and the total size"),
        ("slice total not compiled in", replace(main, "SuiteSliceTotal = {#SliceTotal};", "SuiteSliceTotal = 0;"),
         "must compile SuiteSliceTotal from SliceTotal"),
        ("first pass named like a release",
         replace(main, '#define SuiteOutputFile SuiteOutputName + " PASS1 DO NOT SHIP"', '#define SuiteOutputFile SuiteOutputName'),
         'must name the output of the first pass "PASS1 DO NOT SHIP"'),
        ("slice check without the total",
         replace(main, "SuiteSliceMax, SuiteSliceTotal, 6)", "SuiteSliceMax, 0, 6)"),
         "InitializeSetup must call SuiteFindSliceProblems with the count"),
        ("overrides of the privileges allowed",
         replace(main, "PrivilegesRequired=admin\n", "PrivilegesRequired=admin\nPrivilegesRequiredOverridesAllowed=commandline\n"),
         "PrivilegesRequiredOverridesAllowed is set"),
        ("no admin install mode check",
         replace(main, "  if not IsAdminInstallMode then\n", "  if False then\n"), "must stop first if not IsAdminInstallMode"),
        ("64-bit registry view of HKLM",
         replace("suite/suite_pages.iss", "RegValueExists(HKLM, Key,", "RegValueExists(HKLM64, Key,"), "HKLM64, HKCU64, HKLM32 and HKCU32 raise an error"),
        ("the shortcuts of suite 1.0.0 of another list",
         replace("suite/suite_shortcuts.iss", "    if FileExists(Path) then\n    begin\n      if not SuiteOldSuiteShortcutRemovable",
                 "    Path := ExpandConstant('{autodesktop}\\Empire Earth.lnk');\n    if FileExists(Path) then\n    begin\n      if not SuiteOldSuiteShortcutRemovable"),
         "SuiteRemoveOldSuiteShortcuts must delete the paths of SuiteOldSuiteShortcutPath only"),
        ("a shortcut of suite 1.0.0 deleted without asking SuiteOldSuiteShortcutRemovable",
         replace("suite/suite_shortcuts.iss", "      if not SuiteOldSuiteShortcutRemovable(I, SuiteLinkStartsLauncher(Path)) then\n"
                 "        Log('Shortcut of suite 1.0.0 kept, it does not start the launcher: ' + Path)\n      else if DeleteFile(Path) then",
                 "      if DeleteFile(Path) then"),
         "must ask SuiteOldSuiteShortcutRemovable before DeleteFile(Path)"),
        ("a file deleted that is no shortcut",
         replace("suite/suite_shortcuts.iss", "      else if DeleteFile(Path) then", "      else if DeleteFile(ExpandConstant('{app}\\unins000.exe')) then"),
         "DeleteFile(ExpandConstant('{app}\\unins000.exe')): the suite deletes the shortcut it names"),
        ("the shortcuts of suite 1.0.0 deleted after the new ones",
         replace("suite/suite_shortcuts.iss", "  SuiteRemoveOldSuiteShortcuts;\n  SuiteShortcut('{autodesktop}'", "  SuiteShortcut('{autodesktop}'"),
         "ApplySuiteShortcuts must call SuiteRemoveOldSuiteShortcuts before the first SuiteShortcut"),
        ("the uninstaller keeps the shortcuts",
         replace("suite/suite_shortcuts.iss", "      if DeleteFile(Link) then\n        Log('Shortcut removed: ' + Link)", "      if True then\n        Log('Shortcut removed: ' + Link)"),
         "when removing, SuiteShortcut must delete the shortcut file it names"),
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
        ("runner not included", replace(main, '#include "suite_run.iss"\n', ""), 'no #include "suite_run.iss"'),
        ("products not run at ssInstall", replace(main, "    SuiteRunProducts\n", "    Log('x')\n"),
         "CurStepChanged must run SuiteRunProducts at ssInstall"),
        ("shortcuts created before the runner",
         replace(main, "  if CurStep = ssInstall then\n    SuiteRunProducts\n  else if CurStep = ssPostInstall then\n  begin\n    ApplySuiteShortcuts(False);",
                 "  if CurStep = ssInstall then\n    ApplySuiteShortcuts(False)\n  else if CurStep = ssPostInstall then\n  begin\n    SuiteRunProducts;"),
         "CurStepChanged must run SuiteRunProducts at ssInstall"),
        ("the uninstall key is no longer marked at ssPostInstall",
         replace(main, "    WriteSuiteRecord;\n    MarkSuiteUninstallKey;\n", "    WriteSuiteRecord;\n"),
         "CurStepChanged must run SuiteRunProducts at ssInstall"),
        ("marker written without asking RegKeyExists",
         replace("suite/suite_record.iss", "if not RegKeyExists(HKLM, SuiteUninstallKey('{#SuiteAppID}')) then", "if False then"),
         "MarkSuiteUninstallKey must ask RegKeyExists"),
        ("marker procedure deletes a value",
         replace("suite/suite_record.iss", "    Exit;\n  end;\n  RegWriteDWordValue(", "    Exit;\n  end;\n  RegDeleteValue(HKLM, 'Software', 'x');\n  RegWriteDWordValue("),
         "MarkSuiteUninstallKey must not delete registry keys or values"),
        ("a second start of the product setup",
         replace(run, "  Started := SuiteStartProduct(Exe, Params, ExpandConstant('{tmp}'), Proc, Job, Err);\n",
                 "  SuiteStartProduct(Exe, Params, ExpandConstant('{tmp}'), Proc, Job, Err);\n  Started := SuiteStartProduct(Exe, Params, ExpandConstant('{tmp}'), Proc, Job, Err);\n"),
         "SuiteStartProduct is called 2 times, expected 1"),
        ("a second CreateProcessW", replace(common, "  CmdLine := '\"' + Exe + '\"';\n", "  SuiteCreateProcess(Exe, '', 0, 0, False, 0, 0, WorkDir, Startup, Created);\n  CmdLine := '\"' + Exe + '\"';\n"),
         "SuiteCreateProcess is called 2 times, expected 1"),
        ("Exec reintroduced",
         replace(run, "  Started := SuiteStartProduct(Exe, Params, ExpandConstant('{tmp}'), Proc, Job, Err);\n",
                 "  Started := Exec(Exe, Params, ExpandConstant('{tmp}'), SW_SHOWNORMAL, ewWaitUntilTerminated, Code);\n  Proc := 0;\n  Job := 0;\n"),
         "must not start a program with Exec or ShellExec"),
        ("a program started by ShellExec", replace(run, "  DeleteFile(LogFile);\n", "  DeleteFile(LogFile);\n  ShellExec('open', Exe, '', '', SW_SHOW, ewNoWait, Code);\n"),
         "must not start a program with Exec or ShellExec"),
        ("ShellExecuteW imported", replace(common, "function SuiteTickCount: DWORD;", "function SuiteShellExecute(hwnd: DWORD; a, b, c, d: String; e: Integer): DWORD;\n  external 'ShellExecuteW@shell32.dll stdcall';\nfunction SuiteTickCount: DWORD;"),
         "imports ShellExecuteW"),
        ("CreateProcessA imported", replace(common, "function SuiteTickCount: DWORD;", "function SuiteCreateProcessA(a: String): BOOL;\n  external 'CreateProcessA@kernel32.dll stdcall';\nfunction SuiteTickCount: DWORD;"),
         "imports CreateProcessA"),
        ("a kill on close job", replace(common, "function SuiteTickCount: DWORD;", "function SuiteSetJob(hJob: THandle; c: Integer; var d: Integer; e: Integer): BOOL;\n  external 'SetInformationJobObject@kernel32.dll stdcall';\nfunction SuiteTickCount: DWORD;"),
         "imports SetInformationJobObject"),
        ("TerminateProcess outside the stop", replace(run, "  SuiteLogProgressEnd(Product);\n\n  // (e)", "  SuiteLogProgressEnd(Product);\n  SuiteTerminateProcess(Proc, 1);\n\n  // (e)"),
         "SuiteTerminateProcess is called by ['SuiteKillProduct', 'SuiteRunProduct']"),
        ("the stop of the job outside SuiteKillProduct", replace(run, "  SuiteLogProgressEnd(Product);\n\n  // (e)", "  SuiteLogProgressEnd(Product);\n  SuiteTerminateJob(Job, 1);\n\n  // (e)"),
         "SuiteTerminateJob is called by"),
        ("a product setup stopped outside the cancel and the limits",
         replace(run, "    Waited := SuiteWaitObject(SuiteChildProc, SuiteWaitSliceMs);\n", "    SuiteStopProduct(Product, 'x');\n    Waited := SuiteWaitObject(SuiteChildProc, SuiteWaitSliceMs);\n"),
         "SuiteStopProduct is called 4 times, expected 3"),
        ("a stop outside the wait", replace(run, "  SuiteLogProgressEnd(Product);\n\n  // (e)", "  SuiteLogProgressEnd(Product);\n  SuiteKillProduct(Proc, Job);\n\n  // (e)"),
         "SuiteKillProduct is called by"),
        ("cancel while the product setup installs",
         replace(run, "      if SuiteProgressInstalling(SuiteChildProgress) then\n      begin\n        Log('Product ' + Product + ': the cancel came too late, its setup has started",
                 "      if False then\n      begin\n        Log('Product ' + Product + ': the cancel came too late, its setup has started"),
         "SuiteWaitForProduct may stop the product setup only"),
        ("a stall stopped without the question", replace(run, "            if SuiteStallStopWanted(Product, LogFile, Phase) then\n", "            if True then\n"),
         "SuiteWaitForProduct may stop the product setup only"),
        ("the cap stops without a job", replace(run, "          else if SuiteChildJob <> 0 then\n          begin\n            SuiteStopProduct(Product, 'runs for more than '",
                                               "          else if True then\n          begin\n            SuiteStopProduct(Product, 'runs for more than '"),
         "SuiteWaitForProduct may stop the product setup only"),
        ("an unbounded wait", replace(run, "SuiteWaitObject(SuiteChildProc, SuiteWaitSliceMs)", "SuiteWaitObject(SuiteChildProc, $FFFFFFFF)"),
         "every wait for a process must be bounded"),
        ("the wait does not keep the window alive", replace(run, "    if not SuitePumpMessages or Terminated then\n", "    if Terminated then\n"),
         "SuiteWaitForProduct must keep the window alive and watch the limits (SuitePumpMessages)"),
        ("the wait does not look at the limits", replace(run, "    case SuiteTimeoutCheck(", "    case 0 + Ord(SuiteTimeoutCheck"),
         "(SuiteTimeoutCheck()"),
        ("the process is resumed before it is in the job", replace(common, "  if Job <> 0 then\n    if not SuiteAssignJob(Job, Proc) then", "  SuiteResumeThread(Created.hThread);\n  if Job <> 0 then\n    if not SuiteAssignJob(Job, Proc) then"),
         "SuiteStartProduct must start the process suspended"),
        ("/TestCancel read twice", replace(run, "  SuiteRunCancelled := False;\n  SuiteCancelledProduct := '';\n  SuiteRunStep := 0;", "  SuiteRunCancelled := SuiteHasParam('/TestCancel') and False;\n  SuiteCancelledProduct := '';\n  SuiteRunStep := 0;"),
         "/TestCancel (CI scenario S11) must be read once"),
        ("the click on Cancel is Setup's", replace(run, "  Cancel := False;\n  Confirm := False;\n", ""),
         "CancelButtonClick must answer the click"),
        ("no end of Setup after a cancel", replace(run, "    Abort;\n", "    Log('x');\n"),
         "after a cancel SuiteRunProducts must start no further product setup"),
        ("the next product after a cancel", replace(run, " and not SuiteRunStopped and not SuiteRunCancelled then", " and not SuiteRunStopped then"),
         "after a cancel SuiteRunProducts must start no further product setup"),
        ("no reason text for a stopped product setup", replace(run, "    SuiteChildTimeout:\n      begin", "    SuiteChildPrecondition + 100:\n      begin"),
         "SuiteReasonText must name the reason"),
        ("no pin check before the start", replace(run, "if not SuiteExtractAndCheck(Product, Reason, Mismatch, Lock) then", "if False then"),
         "must call SuiteExtractAndCheck (the pin check) before SuiteStartProduct"),
        ("extracted file not locked against writing",
         replace(run, "fmOpenRead or fmShareDenyWrite", "fmOpenRead or fmShareDenyNone"), "must lock the extracted file against writing"),
        ("lock released before the wait",
         replace(run, "      Outcome := SuiteWaitForProduct(Product, LogFile, Code);\n", "      Lock.Free;\n      Outcome := SuiteWaitForProduct(Product, LogFile, Code);\n"),
         "must keep the lock of the extracted file until the wait for the product setup has returned"),
        ("lock released before the start", replace(run, "  Started := SuiteStartProduct(Exe, Params, ExpandConstant('{tmp}'), Proc, Job, Err);\n",
                                                  "  Lock.Free;\n  Started := SuiteStartProduct(Exe, Params, ExpandConstant('{tmp}'), Proc, Job, Err);\n"),
         "must keep the lock of the extracted file until the wait for the product setup has returned"),
        ("pin check that does not compare",
         replace(run, "SuitePinMatches(Hash, SuiteProductSetupSHA256(Product), Size, SuiteProductSetupSize(Product))", "(Hash <> '')"),
         "does not compare size and SHA-256 with SuitePinMatches"),
        ("PrepareToInstall without exit code 15", replace(run, "SuiteStop(SuiteExitProductSetup,", "SuiteStop(SuiteExitSlices,", 2),
         "PrepareToInstall must check every selected setup"),
        ("DeleteFile of another file", replace(run, "  DeleteFile(LogFile);\n", "  DeleteFile(ExpandConstant('{app}\\Empire Earth Launcher.exe'));\n"),
         "the runner deletes only its extracted product setup"),
        ("DelTree in the runner", replace(run, "  DeleteFile(LogFile);\n", "  DelTree(ExpandConstant('{app}'), True, True, True);\n"),
         "must not call DelTree"),
        ("registry deletion in the runner", replace(run, "  DeleteFile(LogFile);\n", "  RegDeleteValue(HKLM, 'Software', 'x');\n"),
         "must not call DelTree or delete registry keys"),
        ("RemoveDir of another folder", replace(run, "RemoveDir(Group)", "RemoveDir(Desktop)"), "RemoveDir may only remove the start menu folder"),
        ("legacy shortcuts before the result is known",
         replace(run, "  Started := SuiteStartProduct(Exe, Params,", "  SuiteRemoveLegacyShortcuts(Product);\n  Started := SuiteStartProduct(Exe, Params,"),
         "deleted only after SuiteRunSucceeded"),
        ("legacy shortcuts of another list", replace(run, "Path := SuiteLegacyShortcutPath(Product, I, Desktop, Group);", "Path := Desktop + 'x.lnk';"),
         "must delete the paths of SuiteLegacyShortcutPath only"),
        ("the CD key registry key in a comment", replace(main, "#define SuiteName", "; Software\\Sierra\\CDKeys\n#define SuiteName"),
         "the suite never touches the CD key registration"),
        ("the CD key library in the code", replace(run, "  SuiteRunStopped := False;\n", "  SuiteRunStopped := False;\n  Log('authtools.dll');\n"),
         "the suite never touches the CD key registration"),
        ("uninstaller not included", replace(main, '#include "suite_uninstall.iss"\n', ""), 'no #include "suite_uninstall.iss"'),
        ("products not removed at usUninstall", replace(main, "    SuiteRemoveProducts\n", "    Log('x')\n"),
         "CurUninstallStepChanged must run SuiteRemoveProducts at usUninstall"),
        ("user data not handled at usPostUninstall", replace(main, "    SuiteRemoveUserData;\n", ""),
         "CurUninstallStepChanged must run SuiteRemoveProducts at usUninstall"),
        ("no check of the game mutexes", replace(uninstall, "if CheckForMutexes(SuiteMutexes) then", "if CheckForMutexes('x') then"),
         "InitializeUninstall must check the game and launcher mutexes"),
        ("setup mutex not held", replace(uninstall, "  CreateMutex(SuiteSetupMutexName);\n", ""),
         "InitializeUninstall must hold the setup mutex of the suite"),
        ("another setup mutex name", replace(uninstall, "SuiteSetupMutexName = 'EmpireEarthCommunity_Suite'", "SuiteSetupMutexName = 'Other'"),
         "SuiteSetupMutexName (Other) must be the [Setup] SetupMutex"),
        ("question in a silent run", replace(uninstall, "  if not UninstallSilent then\n  begin\n    Items := '';", "  begin\n    Items := '';"),
         "InitializeUninstall must ask its one question with SuppressibleMsgBox"),
        ("second program started", replace(uninstall, "  Started := Exec(Exe,", "  Exec(ExpandConstant('{app}\\x.exe'), '', '', SW_SHOW, ewNoWait, Code);\n  Started := Exec(Exe,"),
         "the uninstaller may start only the uninstaller of a product"),
        ("ShellExec in the uninstaller", replace(uninstall, "  Started := Exec(Exe,", "  ShellExec('open', Exe, '', '', SW_SHOW, ewNoWait, Code);\n  Started := Exec(Exe,"),
         "the uninstaller may start only the uninstaller of a product"),
        ("product uninstaller without the check", replace(uninstall, "if not SuiteIsProductUninstaller(Exe, Root) or not FileExists(Exe) then", "if False then"),
         "must check SuiteIsProductUninstaller(Exe, Root)"),
        ("product uninstaller judged by its exit code",
         replace(uninstall, "State := SuiteUninstallWaitState(KeyPresent, FileExists(Exe), Elapsed);", "State := SuiteWaitDone;"),
         "must wait with SuiteUninstallWaitState"),
        ("DelTree in the product removal", replace(uninstall, "  Total := 0;\n", "  DelTree(ExpandConstant('{app}'), True, True, True);\n  Total := 0;\n"),
         "DelTree may only be called in SuiteDeleteDataFolders"),
        ("a data folder behind a link is offered",
         replace(uninstall, "          if SuiteIsBehindLink(Folder, SuiteUninstallRoot[I]) then", "          if False then"),
         "SuiteExistingDataFolders must leave out a data folder that is a link"),
        ("a data folder of an installed product is offered",
         replace(uninstall, "          else if SuiteIsFolderOfInstalledProduct(Folder) then", "          else if False then"),
         "SuiteExistingDataFolders must leave out a data folder that is a link"),
        ("data folders deleted without the answer", replace(uninstall, "  if DeleteData then\n    SuiteDeleteDataFolders(Folders);", "  SuiteDeleteDataFolders(Folders);"),
         "SuiteDeleteDataFolders is only called in SuiteRemoveUserData"),
        ("data folders deleted for the first button", replace(uninstall, "IDYES) = IDNO;", "IDYES) = IDYES;"),
         "DeleteData is only True for the second button"),
        ("data folders deleted in a silent run", replace(uninstall, "    if UninstallSilent then\n      Log('Silent uninstallation", "    if False then\n      Log('Silent uninstallation"),
         "DeleteData is only True for the second button"),
        ("DeleteFile of another file", replace(uninstall, "if DeleteFile(Target) then", "if DeleteFile(ExpandConstant('{app}\\x.exe')) then"),
         "the uninstaller deletes only the launcher files"),
        ("RemoveDir of another folder", replace(uninstall, "RemoveDir(Target)", "RemoveDir(ExpandConstant('{app}'))", 2),
         "the uninstaller removes only the folders of SuiteEmptyFolder"),
        ("RemoveDir(Root) of another folder", replace(uninstall, "Root := RemoveBackslash(ExpandConstant('{app}'));",
                                                      "Root := ExpandConstant('{localappdata}');"),
         "the uninstaller removes only the folders of SuiteEmptyFolder"),
        ("empty {app} removed through a link", replace(uninstall, "if not DirExists(Root) or SuiteIsBehindLink(Root, Root) then",
                                                       "if not DirExists(Root) then"),
         "SuiteRemoveEmptyRoot must leave {app} alone if it is a link"),
        ("registry deletion in the uninstaller", replace(uninstall, "  Total := 0;\n", "  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\\Microsoft');\n  Total := 0;\n"),
         "only RemoveSuiteRecord deletes registry keys"),
        ("WizardSilent in the uninstaller", replace(uninstall, "  Total := 0;\n", "  if WizardSilent then Total := 0;\n  Total := 0;\n"),
         "the uninstaller uses a function of Setup"),
        ("the logs folder is not the only deletion", replace(main, 'Name: "{app}\\Logs"', 'Name: "{app}"'), "[UninstallDelete] must name {app}\\Logs only"),
        ("the CD key registry key in the uninstaller", replace(uninstall, "  Total := 0;\n", "  Log('Software\\Sierra');\n  Total := 0;\n"),
         "the suite never touches the CD key registration"),        ("a parsed product log line reworded",
         replace("downloads.iss", "Log('Downloading ' + IntToStr(Count) + ' online files, one at a time');",
                 "Log('Fetching ' + IntToStr(Count) + ' online files, one at a time');"),
         "no line contains 'Downloading ' and ' online files, one at a time'"),
        ("a parsed product log line of the CD key step reworded",
         replace("setup_is6.iss", "Log('CD Keys generation result: ' + IntToStr(AuthExitCode));", "Log('CD keys result: ' + IntToStr(AuthExitCode));"),
         "no line contains 'CD Keys generation result:'"),
        ("the install marker reworded in the product script",
         replace("setup_is6.iss", "Log('Install step: the game folder is changed from here on');", "Log('Install step: begins');"),
         "no line contains 'Install step: the game folder is changed from here on'"),
        ("the install marker after DeleteInstallState",
         lambda root: (replace("setup_is6.iss", "    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss\n    Log('Install step: the game folder is changed from here on');\n", "")(root),
                       replace("setup_is6.iss", "    DeleteInstallState();\n", "    DeleteInstallState();\n    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss\n    Log('Install step: the game folder is changed from here on');\n")(root)),
         "the first statement of CurStepChanged(ssInstall) must be"),
        ("the install marker missing",
         replace("setup_is6.iss", "    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss\n    Log('Install step: the game folder is changed from here on');\n", ""),
         "no line contains 'Install step: the game folder is changed from here on'"),
        ("the cap is not told whether the product setup installs",
         replace(run, "SuiteProgressInstalling(SuiteChildProgress), StallDone, CapDone) of", "False, StallDone, CapDone) of"),
         "must give SuiteTimeoutCheck whether the product setup is installing"),
        ("the cap stops a product setup without looking whether it installs",
         replace(run, "          if SuiteProgressInstalling(SuiteChildProgress) then\n            Log('Product ' + Product + ': runs for more than ' + IntToStr(SuiteProductCapMs div 60000) +\n              ' minutes and has started to install, it is not stopped for its time, waiting on')\n          else if SuiteChildJob <> 0 then",
                 "          if SuiteChildJob <> 0 then"),
         "SuiteWaitForProduct may stop the product setup only"),
        ("the stall question is not looked at again after the answer",
         replace(run, "  SuiteLookAtLog(Product, LogFile, Phase);\n  if not WasInstalling and", "  if not WasInstalling and"),
         "SuiteStallStopWanted must look at the product setup again"),
        ("/TestCancel on a product setup that installs already",
         replace(run, "        if SuiteProgressInstalling(SuiteChildProgress) then\n          Log('Product ' + Product + ': /TestCancel not requested", "        if False then\n          Log('Product ' + Product + ': /TestCancel not requested"),
         "/TestCancel must not request a cancel"),
        ("Abort after a cancel although a product succeeded",
         replace(run, "    if SuiteProductsOk = '' then\n    begin\n      // nothing of this run is installed", "    begin\n      // nothing of this run is installed"),
         "only if no product succeeded in this run"),
        ("the last page does not name the cancelled product",
         replace("suite/suite_pages.iss", ", SuiteCancelledProduct, Product);", ", '', Product);"),
         "the last page must name the product the user cancelled"),
        ("the progress line of the validated TLS transport without the comment",
         replace("downloads.iss", "    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss\n    Log('  ' + IntToStr(Progress)", "    Log('  ' + IntToStr(Progress)"),
         "needs the comment"),
        ("a parsed product log line of the manifest reworded",
         replace("utils.iss", "Result := 'Manifest: ' + IntToStr(FileCount)", "Result := 'Manifest written: ' + IntToStr(FileCount)"),
         "no line contains 'Manifest: '"),
        ("a parsed product log line without the comment",
         replace("downloads.iss", "  // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss\n  Log('Downloading ' + IntToStr(Count)", "  Log('Downloading ' + IntToStr(Count)"),
         "needs the comment"),
        ("the text of a log line changed in the suite", replace(common, "SuiteLogProbe = 'Online files server ';", "SuiteLogProbe = 'Online file server ';"),
         "no line contains 'Online file server '"),
        ("a log line that is not listed", replace(common, "  SuiteLogClosed = 'Log closed.';", "  SuiteLogClosed = 'Log closed.';\n  SuiteLogMore = 'More';"),
         "SuiteLogMore names a product log line the suite reads"),
        ("a log line the parser does not use", replace(common, "else if SuiteStartsWith(T, SuiteLogClosed) then", "else if False then"),
         "SuiteLogClosed is declared, but the progress parser does not use it"),
        ("the comment above a line that is not a parsed log line",
         replace("installstate.iss", "    Log('Wrote ' + IniPath", "    // The suite parses this line (contract 1.7 point 5): x\n    Log('Wrote ' + IniPath"),
         "stands above a line that"),
        ("the display without its own failure handling",
         replace(run, "    SuiteProgressBroken := True;\n    Log('The progress display failed", "    Log('The progress display failed"),
         "SuiteShowProgress must catch its own failure"),
        ("the display in the advanced mode", replace(run, "  if SuiteAdvanced or SuiteProgressBroken then\n    Exit;\n  try\n    Text := SuiteStatusText",
                                                     "  try\n    Text := SuiteStatusText"),
         "SuiteShowProgress must leave the advanced mode"),
        ("the bar from the log without a limit", replace(run, "SuiteRunningPermille(SuiteChildProgress)));\n    SuiteShowStages", "SuiteProgressPermille(SuiteChildProgress)));\n    SuiteShowStages"),
         "SuiteShowProgress must take the bar from SuiteRunningPermille"),
        ("the end of the bar set while the product setup runs",
         replace(run, "    SuiteShowStages(SuiteChildProgress);\n  except", "    SuiteSetPosition(1000);\n    SuiteShowStages(SuiteChildProgress);\n  except"),
         "never set the end of the bar"),
        ("the log is not shown", replace(run, "  SuiteShowProgress(Product);\nend;", "end;"), "SuiteLookAtLog must show what it read"),
        ("the end of a step in another place",
         replace(run, "    SuiteShownPosition := Permille;\n", "    SuiteShownPosition := Permille;\n    if SuiteOverallPermille(1, 1, 1000) = 0 then Exit;\n"),
         "the bar reaches the end of a step in SuiteEndProductDisplay only"),
        ("the product display not ended with the result", replace(run, "          SuiteEndProductDisplay(True)\n", "          SuiteBeginProductDisplay('x')\n"),
         "SuiteRunProducts must end the display of a product with its result"),
        ("the bar not put back", replace(run, "    WizardForm.ProgressGauge.Max := OldMax;\n", ""), "must put the bar back after the products"),
        ("the list of the steps can be ticked", replace("suite/suite_pages.iss", "  SuiteStageList.OnClickCheck := @SuiteStageClickCheck;\n", ""),
         "the list of the finished steps only shows"),
    ]
    passing = [("unchanged copy", None, None)]
    failures = 0
    with tempfile.TemporaryDirectory(prefix="check_suite_selftest_") as temp:
        for number, (name, change, expected) in enumerate(passing + cases):
            root = Path(temp) / f"case{number}"
            for rel in SUITE_FILES + list(PRODUCT_LOG_FILES):
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
