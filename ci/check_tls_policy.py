#!/usr/bin/env python3
"""Checks where the setup may ignore TLS certificate errors (ADR 0012).

  python ci/check_tls_policy.py [repo_dir]
  python ci/check_tls_policy.py --self-test

The setup validates the certificate of every request, with one exception: a pinned online file may
be downloaded from a server whose certificate is invalid, because its SHA-256 decides whether it is
installed (docs/adr/0012-pinned-downloads-despite-invalid-certificates.md). This check makes sure
that the exception stays where it is. It reads every script compiled into the setup, without "//"
comments: every *.iss file in the root folder and every file that an #include line names in
setup_is6.iss or in a file found that way, also third-party code under internal/
(internal/lib/bass/bass.iss). The unit tests in ci/tests call the WinHTTP helpers on purpose and
are not read. Pascal names are case-insensitive, and so is the search for them. It reports (exit
code 1):

  - an #include whose file does not exist or is outside the repository, and an #include built
    from an expression other than the one of config_<type>.iss (a file of the root folder);
  - a function of winhttp.dll declared anywhere but in utils.iss, under another name than its own
    (an alias such as "function SetOpt(...); external 'WinHttpSetOption@winhttp.dll ...'" would
    escape the rules below), twice, with another external text than
    '<name>@winhttp.dll stdcall delayload', or that is not one of WINHTTP_FUNCTIONS; an external
    declaration without '@<DLL>' or whose DLL name is built by ISPP ({#...}); any other mention of
    winhttp.dll; any mention of wininet, urlmon or XMLHTTP (other HTTP stacks that can ignore
    certificate errors); the address of a WinHTTP function or of the routines below taken with
    '@' (a call through a variable would escape the rules below);
  - the flags that ignore certificate errors ($3300, WINHTTP_OPTION_SECURITY_FLAGS = 31) anywhere
    but in ApplyCertificateErrorIgnoreFlags, or a WinHttpSetOption call outside it and
    OpenWinHttpRequest, or one in OpenWinHttpRequest with another option than the named constant
    WinHttpOptionSecureProtocols (a composed value such as 30 + 1 is refused that way), or a
    WinHttpOpenRequest call outside OpenWinHttpRequest;
  - a named option (NAMED_OPTIONS) not defined exactly once with its value;
  - a call of ApplyCertificateErrorIgnoreFlags anywhere but in OpenWinHttpRequest (exactly one);
  - a call of OpenWinHttpRequest whose IgnoreCertificateErrors argument is not the literal True or
    False, or that passes True anywhere but in GetHttpStatusIgnoringCertificate and
    DownloadPinnedFileWinHttp;
  - a call of GetHttpStatusIgnoringCertificate anywhere but in ProbeOnlineFilesServer, or of
    DownloadPinnedFileWinHttp anywhere but in DownloadOnlineFileFrom under
    "if Transport = DownloadTransportPinnedWinHttp then";
  - DownloadPinnedFileWinHttp without its first statement "if OnlineFiles[Index].SHA256 = '' then
    RaiseException(...)" (a file without pin never gets the transport that ignores certificate
    errors);
  - DownloadTransportPinnedWinHttp chosen anywhere but in GetOnlineFileTransport, and there not
    under a condition that requires a pinned file (Check = OnlineFilePinned);
  - the certificate option of the WinHttpRequest COM object (SslErrorIgnoreFlags, Option[4]) or any
    Option[...] index of it but the named constants WinHttpRequestOptionSecureProtocols and
    WinHttpRequestOptionEnableRedirects.

--self-test runs the check against modified temporary copies of the scripts (the flags in another
function, a second caller, True from another function, the guard removed, an alias of
WinHttpSetOption, the flags in an included file of a subfolder, ...) that must fail, and against
an unmodified copy that must pass. Exit code 0 if all cases behave.
"""
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

MAIN_SCRIPT = "setup_is6.iss"
APPLY = "ApplyCertificateErrorIgnoreFlags"
OPEN = "OpenWinHttpRequest"
PROBE = "GetHttpStatusIgnoringCertificate"
DOWNLOAD = "DownloadPinnedFileWinHttp"
MAY_IGNORE = {PROBE, DOWNLOAD}
# The routines the rules name; owner() returns these spellings whatever case the script uses
ROUTINES = {name.lower(): name for name in (APPLY, OPEN, PROBE, DOWNLOAD, "ProbeOnlineFilesServer",
                                            "DownloadOnlineFileFrom", "GetOnlineFileTransport")}
COM_OPTIONS = {"WinHttpRequestOptionSecureProtocols", "WinHttpRequestOptionEnableRedirects"}
# The only option OpenWinHttpRequest may set with WinHttpSetOption
OPEN_OPTIONS = {"WinHttpOptionSecureProtocols"}
# The named options the rules allow, with the value each must have (WINHTTP_OPTION_SECURE_PROTOCOLS,
# WinHttpRequestOption_SecureProtocols, WinHttpRequestOption_EnableRedirects)
NAMED_OPTIONS = {"WinHttpOptionSecureProtocols": 84, "WinHttpRequestOptionSecureProtocols": 9,
                 "WinHttpRequestOptionEnableRedirects": 6}
# The functions of winhttp.dll the setup declares, all in utils.iss, each under its own name
WINHTTP_FILE = "utils.iss"
WINHTTP_FUNCTIONS = {"WinHttpOpen", "WinHttpSetTimeouts", "WinHttpConnect", "WinHttpOpenRequest", "WinHttpSetOption",
                     "WinHttpSendRequest", "WinHttpReceiveResponse", "WinHttpQueryHeaders", "WinHttpReadData",
                     "WinHttpCloseHandle"}
# The one #include built from an expression: config_ee.iss or config_neoee.iss of the root folder
EXPRESSION_INCLUDES = {'AddBackslash(SourcePath) + "config_" + LowerCase(InstallType) + ".iss"'}
INCLUDE = re.compile(r"^\s*#\s*include\b\s*(.*?)\s*$", re.IGNORECASE)
EXTERNAL = re.compile(r"\bexternal\s+'([^']*)'", re.IGNORECASE)
# The header of the routine an external clause ends (the text before "external")
DECLARATION = re.compile(r"\b(?:function|procedure)\s+(\w+)\s*(?:\([^()]*\))?\s*(?::\s*\w+\s*)?;\s*\Z", re.IGNORECASE)
WINHTTP_DLL = re.compile(r"winhttp\.dll", re.IGNORECASE)
OTHER_HTTP = re.compile(r"wininet|urlmon|xmlhttp", re.IGNORECASE)
ADDRESS = re.compile(r"@\s*(WinHttp\w+|" + "|".join(ROUTINES.values()) + r")\b", re.IGNORECASE)
HEADER = re.compile(r"^(?:function|procedure)\s+(\w+)\b", re.IGNORECASE)
GUARD = re.compile(r"^\s*if\s+OnlineFiles\[Index\]\.SHA256\s*=\s*''\s+then\s+RaiseException\(", re.IGNORECASE)


def strip_comment(line):
    """The line without a "//" comment; single-quoted Pascal strings are kept."""
    in_string = False
    for i, c in enumerate(line):
        if c == "'":
            in_string = not in_string
        elif not in_string and line.startswith("//", i):
            return line[:i]
    return line


def blank_strings(line):
    """The line with the content of its single-quoted Pascal strings replaced by spaces."""
    return re.sub(r"'[^']*'", lambda match: "'" + " " * (len(match.group(0)) - 2) + "'", line)


def read_text(path):
    return path.read_bytes().decode("utf-8-sig", errors="replace").replace("\r\n", "\n")


def script_files(root):
    """(relative paths with "/", problems) of the scripts compiled into the setup: every *.iss file
    of the root folder (without the temporary copies of ci/build.ps1) and every file an #include
    line names in one of them, recursively, wherever it is in the repository. ISPP looks for a
    plain file name next to the including file first, then next to the main script."""
    root = Path(root)
    problems = []
    found = []
    queue = [MAIN_SCRIPT] + sorted(path.name for path in root.glob("*.iss")
                                   if not path.name.startswith("_pp") and path.name != MAIN_SCRIPT)
    while queue:
        rel = queue.pop(0)
        path = root / rel
        if rel in found or not path.is_file():
            continue
        found.append(rel)
        for number, line in enumerate(read_text(path).split("\n"), 1):
            match = INCLUDE.match(line)
            if not match:
                continue
            argument = match.group(1)
            where = f"{rel}, line {number}: #include {argument}"
            literal = re.fullmatch(r'"([^"]+)"|<([^>]+)>', argument)
            if not literal:
                if argument not in EXPRESSION_INCLUDES:
                    problems.append(f"{where}: built from an expression this check cannot follow (use a plain file name)")
                continue
            name = (literal.group(1) or literal.group(2)).replace("\\", "/")
            target = next((candidate for candidate in (path.parent / name, root / name) if candidate.is_file()), None)
            if target is None:
                problems.append(f"{where}: file not found")
                continue
            target_rel = Path(os.path.relpath(os.path.normpath(target), root)).as_posix()
            if target_rel == ".." or target_rel.startswith("../"):
                problems.append(f"{where}: outside the repository")
                continue
            queue.append(target_rel)
    return found, problems


def read_scripts(root):
    """([(relative path, lines without comments)] of script_files, problems of script_files)."""
    files, problems = script_files(root)
    scripts = [(rel, [strip_comment(line) for line in read_text(Path(root) / rel).split("\n")]) for rel in files]
    return scripts, problems


def routines(lines):
    """(name, first line, last line) of every function and procedure with a body; external
    declarations have none. The bodies of the own scripts start with "begin" and end with "end;",
    both in the first column."""
    found = []
    i = 0
    while i < len(lines):
        match = HEADER.match(lines[i])
        if not match:
            i += 1
            continue
        j = i
        while j < len(lines) and not re.match(r"^begin\s*$", lines[j]) and not re.match(r"^\s*external\s", lines[j]):
            if j > i and HEADER.match(lines[j]):
                break
            j += 1
        if j >= len(lines) or not re.match(r"^begin\s*$", lines[j]):
            i += 1  # external declaration or a forward header
            continue
        k = j + 1
        while k < len(lines) and not re.match(r"^end;\s*$", lines[k]):
            k += 1
        found.append((match.group(1), i, k))
        i = k + 1
    return found


def owner(spans, index):
    """The routine whose body holds line index, in the spelling of ROUTINES if it is one of them."""
    for name, first, last in spans:
        if first <= index <= last:
            return ROUTINES.get(name.lower(), name)
    return None


def parse_number(text):
    """The value of a decimal or $hex Pascal literal, or None for anything else."""
    text = text.strip()
    if re.fullmatch(r"\d+", text):
        return int(text)
    if re.fullmatch(r"\$[0-9a-fA-F]+", text):
        return int(text[1:], 16)
    return None


def check_externals(scripts, problems):
    """The rules for external declarations and for the mentions of winhttp.dll and of the other HTTP
    stacks (see the module docstring)."""
    declared = {}
    accepted = set()  # (file, line index) of the external clauses of accepted winhttp.dll declarations
    for name, lines in scripts:
        text = "\n".join(lines)
        for match in EXTERNAL.finditer(text):
            spec = match.group(1)
            line_index = text.count("\n", 0, match.start())
            where = f"{name}, line {line_index + 1}"
            entry, at, rest = spec.partition("@")
            dll = re.split(r"[\\/:]", rest.split()[0])[-1] if rest.split() else ""
            if not at or not dll:
                problems.append(f"{where}: external '{spec}' without '<function>@<DLL>'")
                continue
            if "{" in dll:
                problems.append(f"{where}: external '{spec}': the DLL name is built by ISPP, this check cannot tell which DLL it is")
                continue
            if dll.lower() not in ("winhttp", "winhttp.dll"):
                continue
            header = DECLARATION.search(text[:match.start()])
            routine = header.group(1) if header else None
            if name != WINHTTP_FILE:
                problems.append(f"{where}: a function of winhttp.dll declared outside {WINHTTP_FILE}")
            if routine is None:
                problems.append(f"{where}: a declaration of winhttp.dll that this check cannot read")
            elif routine != entry:
                problems.append(f"{where}: {routine} declared for {entry} of winhttp.dll (every function of "
                                "winhttp.dll only under its own name)")
            elif entry not in WINHTTP_FUNCTIONS:
                problems.append(f"{where}: {entry} of winhttp.dll is not one of the functions the setup uses "
                                "(WINHTTP_FUNCTIONS in ci/check_tls_policy.py)")
            elif spec != f"{entry}@winhttp.dll stdcall delayload":
                problems.append(f"{where}: external '{spec}', expected '{entry}@winhttp.dll stdcall delayload'")
            elif entry in declared:
                problems.append(f"{where}: {entry} of winhttp.dll declared twice (also {declared[entry]})")
            elif name == WINHTTP_FILE:
                declared[entry] = where
                accepted.add((name, line_index))
    for name, lines in scripts:
        for i, line in enumerate(lines):
            where = f"{name}, line {i + 1}"
            if WINHTTP_DLL.search(line) and (name, i) not in accepted:
                problems.append(f"{where}: winhttp.dll named outside the declarations in {WINHTTP_FILE}")
            if OTHER_HTTP.search(line):
                problems.append(f"{where}: another HTTP stack ({OTHER_HTTP.search(line).group(0)}), the setup uses "
                                "Inno Setup's downloads, the WinHttpRequest COM object and winhttp.dll only")
            address = ADDRESS.search(blank_strings(line))
            if address:
                problems.append(f"{where}: the address of {address.group(1)} taken (a call through a variable "
                                "escapes this check)")


def check_named_options(scripts, problems):
    """Every named option of NAMED_OPTIONS defined exactly once, with its value."""
    for option, value in NAMED_OPTIONS.items():
        pattern = re.compile(r"^\s*" + option + r"\s*(?::\s*\w+\s*)?=\s*(.+?)\s*;\s*$", re.IGNORECASE)
        places = [(name, i + 1, match.group(1)) for name, lines in scripts
                  for i, line in enumerate(lines) for match in [pattern.match(line)] if match]
        if len(places) != 1 or parse_number(places[0][2]) != value:
            problems.append(f"{option} must be defined exactly once as {value}: " +
                            (", ".join(f"{f}, line {n}: {v}" for f, n, v in places) or "not found"))


def call_arguments(text, start):
    """The top-level arguments of the call whose "(" is at text[start]; None if unbalanced."""
    depth, args, current, in_string = 0, [], "", False
    for c in text[start:]:
        if c == "'":
            in_string = not in_string
        if not in_string:
            if c == "(":
                depth += 1
                if depth == 1:
                    continue
            elif c == ")":
                depth -= 1
                if depth == 0:
                    args.append(current.strip())
                    return args
            elif c == "," and depth == 1:
                args.append(current.strip())
                current = ""
                continue
        current += c
    return None


def check(root):
    problems = []
    calls = {}  # name -> list of (file, line number, owner, arguments, line index)
    texts = {}
    spans_of = {}
    scripts, include_problems = read_scripts(root)
    problems.extend(include_problems)
    check_externals(scripts, problems)
    check_named_options(scripts, problems)
    for name, lines in scripts:
        spans = routines(lines)
        spans_of[name] = spans
        text = "\n".join(lines)
        texts[name] = (text, lines)
        for callee in (APPLY, OPEN, PROBE, DOWNLOAD, "WinHttpSetOption", "WinHttpOpenRequest"):
            for match in re.finditer(r"\b" + callee + r"\s*\(", text, re.IGNORECASE):
                line_index = text.count("\n", 0, match.start())
                line = lines[line_index]
                if HEADER.match(line) or re.match(r"^\s*external\s", line, re.IGNORECASE):
                    continue  # the declaration itself
                args = call_arguments(text, match.end() - 1)
                calls.setdefault(callee, []).append((name, line_index + 1, owner(spans, line_index), args, line_index))

        for i, line in enumerate(lines):
            where = f"{name}, line {i + 1}"
            routine = owner(spans, i)
            if re.search(r"\$0*3300\b|\b13056\b", line, re.IGNORECASE) and routine != APPLY:
                problems.append(f"{where}: the flags that ignore certificate errors ($3300) outside {APPLY}")
            if re.search(r"SslErrorIgnoreFlags|SECURITY_FLAG_IGNORE|WINHTTP_OPTION_SECURITY_FLAGS", line, re.IGNORECASE):
                problems.append(f"{where}: a certificate option named outside a comment")
            for option in re.finditer(r"\.Option\[\s*([^\]]*)\]", line):
                if option.group(1).strip() not in COM_OPTIONS:
                    problems.append(f"{where}: WinHttpRequest option '{option.group(1).strip()}' (only {', '.join(sorted(COM_OPTIONS))})")
            if re.search(r":=\s*DownloadTransportPinnedWinHttp\b", line, re.IGNORECASE):
                if routine != "GetOnlineFileTransport":
                    problems.append(f"{where}: DownloadTransportPinnedWinHttp chosen outside GetOnlineFileTransport")
                else:
                    condition = (lines[i - 1] if i > 0 else "") + " " + line
                    if not re.search(r"Check\s*=\s*OnlineFilePinned", condition, re.IGNORECASE):
                        problems.append(f"{where}: DownloadTransportPinnedWinHttp not under the condition Check = OnlineFilePinned")

    apply_calls = calls.get(APPLY, [])
    if len(apply_calls) != 1 or apply_calls[0][2] != OPEN:
        problems.append(f"{APPLY} must be called exactly once, in {OPEN}: " +
                        ", ".join(f"{f}, line {n} ({o})" for f, n, o, _, _ in apply_calls))
    for f, n, o, args, _ in calls.get("WinHttpSetOption", []):
        if o not in (APPLY, OPEN):
            problems.append(f"{f}, line {n}: WinHttpSetOption outside {APPLY} and {OPEN} ({o})")
        elif o == OPEN and (not args or len(args) != 4 or args[1].lower() not in {x.lower() for x in OPEN_OPTIONS}):
            option = args[1] if args and len(args) > 1 else None
            problems.append(f"{f}, line {n}: WinHttpSetOption in {OPEN} with the option '{option}' (only "
                            f"{', '.join(sorted(OPEN_OPTIONS))}; the security flags only in {APPLY})")
    for f, n, o, _, _ in calls.get("WinHttpOpenRequest", []):
        if o != OPEN:
            problems.append(f"{f}, line {n}: WinHttpOpenRequest outside {OPEN} ({o})")
    for f, n, o, args, _ in calls.get(OPEN, []):
        flag = args[2] if args and len(args) > 2 else None
        if flag is None or flag.lower() not in ("true", "false"):
            problems.append(f"{f}, line {n}: {OPEN} with IgnoreCertificateErrors '{flag}', not the literal True or False")
        elif flag.lower() == "true" and o not in MAY_IGNORE:
            problems.append(f"{f}, line {n}: {OPEN} ignores certificate errors in {o} (only {', '.join(sorted(MAY_IGNORE))})")
    for f, n, o, _, _ in calls.get(PROBE, []):
        if o != "ProbeOnlineFilesServer":
            problems.append(f"{f}, line {n}: {PROBE} called in {o} (only ProbeOnlineFilesServer)")
    download_calls = calls.get(DOWNLOAD, [])
    if not download_calls:
        problems.append(f"{DOWNLOAD} is not called (expected in DownloadOnlineFileFrom)")
    for f, n, o, _, i in download_calls:
        if o != "DownloadOnlineFileFrom":
            problems.append(f"{f}, line {n}: {DOWNLOAD} called in {o} (only DownloadOnlineFileFrom)")
            continue
        lines = texts[f][1]
        before = " ".join(lines[max(0, i - 4):i + 1])
        if not re.search(r"if\s+Transport\s*=\s*DownloadTransportPinnedWinHttp\s+then", before, re.IGNORECASE):
            problems.append(f"{f}, line {n}: {DOWNLOAD} not under 'if Transport = DownloadTransportPinnedWinHttp then'")

    guarded = False
    for name, (text, lines) in texts.items():
        for routine, first, last in spans_of[name]:
            if routine.lower() != DOWNLOAD.lower():
                continue
            body = [line for line in lines[first:last + 1]]
            begin = next((k for k, line in enumerate(body) if re.match(r"^begin\s*$", line)), None)
            statements = [line for line in body[begin + 1:] if line.strip()] if begin is not None else []
            joined = " ".join(line.strip() for line in statements[:2])
            guarded = bool(GUARD.match(joined))
    if not guarded:
        problems.append(f"{DOWNLOAD} does not start with \"if OnlineFiles[Index].SHA256 = '' then RaiseException(...)\"")
    return problems


def run(root):
    problems = check(root)
    for problem in problems:
        print(f"ERROR {problem}")
    if problems:
        print(f"TLS policy: {len(problems)} problem(s), see ADR 0012")
        return 1
    print(f"TLS policy: certificate errors are only ignored in {APPLY}, called by {OPEN} for "
          f"{PROBE} and {DOWNLOAD} (pinned files only)")
    return 0


def self_test(source_root):
    source = Path(source_root)

    def edit(rel, old, new):
        def apply(root):
            path = root / rel
            data = path.read_bytes()
            old_b, new_b = old.replace("\n", "\r\n").encode("utf-8"), new.replace("\n", "\r\n").encode("utf-8")
            if data.count(old_b) != 1:
                raise AssertionError(f"self-test: {old!r} not found exactly once in {rel}")
            path.write_bytes(data.replace(old_b, new_b))
        return apply

    def append_code(rel, code):
        def apply(root):
            path = root / rel
            path.write_bytes(path.read_bytes() + ("\r\n" + code.replace("\n", "\r\n")).encode("utf-8"))
        return apply

    def new_file(rel, code):
        def apply(root):
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"\xef\xbb\xbf" + code.replace("\n", "\r\n").encode("utf-8"))
        return apply

    def both(*steps):
        def apply(root):
            for step in steps:
                step(root)
        return apply

    # The finding of the review of S-WP12: an alias of WinHttpSetOption with a composed option and
    # composed flags, in a file without any WinHTTP code
    alias = ("function SetOpt(Handle: Cardinal; Option: Cardinal; var Value: Cardinal; ValueLength: Cardinal): BOOL;\n"
             "  external 'WinHttpSetOption@winhttp.dll stdcall delayload';\n\n"
             "procedure SelfTestExtra(R: Cardinal);\nvar\n  F: Cardinal;\nbegin\n"
             "  F := $1000 or $2000 or $100;\n  SetOpt(R, 30 + 1, F, 4);\nend;\n")
    set_option = "  external 'WinHttpSetOption@winhttp.dll stdcall delayload';"

    cases = [
        ("the flags in another function",
         edit("utils.iss", "  Result := HttpRequestFailed;\n  Log('HTTP GET ' + Url + ' without certificate validation (WinHTTP)');",
              "  Result := HttpRequestFailed;\n  Flags := $3300;\n  Log('HTTP GET ' + Url + ' without certificate validation (WinHTTP)');")),
        ("option 31 set in OpenWinHttpRequest",
         edit("utils.iss", "        if not WinHttpSetOption(Session, WinHttpOptionSecureProtocols, Protocols, 4) then",
              "        if not WinHttpSetOption(Session, 31, Protocols, 4) then")),
        ("a second caller of ApplyCertificateErrorIgnoreFlags",
         append_code("downloads.iss", "procedure SelfTestExtra;\nbegin\n  ApplyCertificateErrorIgnoreFlags(0);\nend;\n")),
        ("WinHttpSetOption in another function",
         append_code("downloads.iss", "procedure SelfTestExtra;\nvar\n  F: Cardinal;\nbegin\n  WinHttpSetOption(0, 84, F, 4);\nend;\n")),
        ("WinHttpOpenRequest in another function",
         append_code("downloads.iss", "procedure SelfTestExtra;\nbegin\n  WinHttpOpenRequest(0, 'GET', '/', 0, 0, 0, 0);\nend;\n")),
        ("True from another function",
         append_code("downloads.iss", "procedure SelfTestExtra;\nvar\n  S, C, R: Cardinal;\n  E: String;\nbegin\n"
                     "  OpenWinHttpRequest('GET', 'https://x/', True, S, C, R, E);\nend;\n")),
        ("a variable as IgnoreCertificateErrors",
         edit("utils.iss", "OpenWinHttpRequest('GET', Url, True, Session, Connection, Request, Error)",
              "OpenWinHttpRequest('GET', Url, Url <> '', Session, Connection, Request, Error)")),
        ("the probe without validation called elsewhere",
         append_code("downloads.iss", "procedure SelfTestExtra;\nbegin\n  GetHttpStatusIgnoringCertificate('https://x/');\nend;\n")),
        ("the pinned download called elsewhere",
         append_code("downloads.iss", "procedure SelfTestExtra;\nbegin\n  DownloadPinnedFileWinHttp(0, 'https://x/');\nend;\n")),
        ("the pinned download for every transport",
         edit("downloads.iss", "  if Transport = DownloadTransportPinnedWinHttp then\n  begin\n    try\n      Result := DownloadPinnedFileWinHttp(Index, Url);",
              "  if Transport <> DownloadTransportNone then\n  begin\n    try\n      Result := DownloadPinnedFileWinHttp(Index, Url);")),
        ("the guard of the pinned download removed",
         edit("downloads.iss", "  if OnlineFiles[Index].SHA256 = '' then\n    RaiseException('DownloadPinnedFileWinHttp: ",
              "  if OnlineFiles[Index].Size < 0 then\n    RaiseException('DownloadPinnedFileWinHttp: ")),
        ("the pinned transport for files without pin",
         edit("utils.iss", "  else if (ServerState = OnlineServerCertificateInvalid) and (Check = OnlineFilePinned) then",
              "  else if (ServerState = OnlineServerCertificateInvalid) and (Check = OnlineFileTlsOnly) then")),
        ("the pinned transport chosen elsewhere",
         append_code("downloads.iss", "procedure SelfTestExtra;\nvar\n  T: Integer;\nbegin\n  T := DownloadTransportPinnedWinHttp;\nend;\n")),
        ("the COM certificate option",
         edit("utils.iss", "      WinHttpRequest.Option[WinHttpRequestOptionEnableRedirects] := False;",
              "      WinHttpRequest.Option[4] := 13056;")),
        ("the COM certificate option by its index",
         edit("utils.iss", "      WinHttpRequest.Option[WinHttpRequestOptionEnableRedirects] := False;",
              "      WinHttpRequest.Option[4] := False;")),
        ("the COM option by name",
         edit("utils.iss", "  WinHttpRequestOptionEnableRedirects = 6;",
              "  WinHttpRequestOptionEnableRedirects = 6;\n  WinHttpRequestOption_SslErrorIgnoreFlags = 4;")),
        ("an alias of WinHttpSetOption in another file",
         append_code("telemetry.iss", alias),
         "SetOpt declared for WinHttpSetOption of winhttp.dll"),
        ("an alias of WinHttpSetOption in utils.iss",
         append_code("utils.iss", alias),
         "SetOpt declared for WinHttpSetOption of winhttp.dll"),
        ("a function of winhttp.dll under its own name outside utils.iss",
         append_code("downloads.iss", "function WinHttpAddRequestHeaders(Request: Cardinal; Headers: String; Length, Modifiers: Cardinal): BOOL;\n"
                     "  external 'WinHttpAddRequestHeaders@winhttp.dll stdcall delayload';\n"),
         "a function of winhttp.dll declared outside utils.iss"),
        ("a function of winhttp.dll the setup does not use",
         append_code("utils.iss", "function WinHttpSetCredentials(Request: Cardinal): BOOL;\n"
                     "  external 'WinHttpSetCredentials@winhttp.dll stdcall delayload';\n"),
         "WinHttpSetCredentials of winhttp.dll is not one of the functions"),
        ("winhttp.dll by another path",
         edit("utils.iss", set_option, "  external 'WinHttpSetOption@{sys}\\WINHTTP stdcall delayload';"),
         "expected 'WinHttpSetOption@winhttp.dll stdcall delayload'"),
        ("the DLL name built by ISPP",
         edit("utils.iss", set_option, "  external 'WinHttpSetOption@{#WinHttpDll} stdcall delayload';"),
         "the DLL name is built by ISPP"),
        ("winhttp.dll named in code",
         append_code("pages.iss", "procedure SelfTestExtra;\nvar\n  S: String;\nbegin\n  S := 'WinHTTP.dll';\nend;\n"),
         "winhttp.dll named outside the declarations"),
        ("another HTTP stack (COM)",
         append_code("downloads.iss", "procedure SelfTestExtra;\nvar\n  R: Variant;\nbegin\n"
                     "  R := CreateOleObject('Msxml2.ServerXMLHTTP.6.0');\nend;\n"),
         "another HTTP stack (XMLHTTP)"),
        ("another HTTP stack (DLL)",
         append_code("downloads.iss", "function InternetSetOptionW(Handle, Option: Cardinal; var Value: Cardinal; Length: Cardinal): BOOL;\n"
                     "  external 'InternetSetOptionW@wininet.dll stdcall';\n"),
         "another HTTP stack (wininet)"),
        ("the address of WinHttpSetOption taken",
         append_code("downloads.iss", "procedure SelfTestExtra;\nbegin\n  SelfTestHook := @WinHttpSetOption;\nend;\n"),
         "the address of WinHttpSetOption taken"),
        ("WinHttpSetOption in lowercase in another function",
         append_code("downloads.iss", "procedure SelfTestExtra;\nvar\n  F: Cardinal;\nbegin\n  winhttpsetoption(0, 31, F, 4);\nend;\n"),
         "WinHttpSetOption outside ApplyCertificateErrorIgnoreFlags and OpenWinHttpRequest"),
        ("a composed option in OpenWinHttpRequest",
         edit("utils.iss", "        if not WinHttpSetOption(Session, WinHttpOptionSecureProtocols, Protocols, 4) then",
              "        if not WinHttpSetOption(Session, 30 + 1, Protocols, 4) then"),
         "WinHttpSetOption in OpenWinHttpRequest with the option '30 + 1'"),
        ("the named option of OpenWinHttpRequest with another value",
         edit("utils.iss", "  WinHttpOptionSecureProtocols = 84;", "  WinHttpOptionSecureProtocols = 30 + 1;"),
         "WinHttpOptionSecureProtocols must be defined exactly once as 84"),
        ("a named COM option with another value",
         edit("utils.iss", "  WinHttpRequestOptionEnableRedirects = 6;", "  WinHttpRequestOptionEnableRedirects = 4;"),
         "WinHttpRequestOptionEnableRedirects must be defined exactly once as 6"),
        ("the flags in the included third-party file internal/lib/bass/bass.iss",
         append_code("internal/lib/bass/bass.iss", "procedure SelfTestExtra;\nvar\n  F: Cardinal;\nbegin\n  F := $3300;\nend;\n"),
         "internal/lib/bass/bass.iss, line"),
        ("a module in a subfolder, only reached by #include",
         both(new_file("modules/selftest.iss", "[Code]\nprocedure SelfTestExtra;\nvar\n  F: Cardinal;\nbegin\n"
                       "  WinHttpSetOption(0, 31, F, 4);\nend;\n"),
              append_code("setup_is6.iss", '#include "modules\\selftest.iss"\n')),
         "modules/selftest.iss, line 6: WinHttpSetOption outside"),
        ("an #include of a file that does not exist",
         append_code("setup_is6.iss", '#include "missing_selftest.iss"\n'),
         '#include "missing_selftest.iss": file not found'),
        ("an #include built from another expression",
         append_code("setup_is6.iss", '#include AddBackslash(SourcePath) + "internal\\selftest.iss"\n'),
         "built from an expression this check cannot follow"),
    ]
    failures = 0
    with tempfile.TemporaryDirectory() as temp:
        copy = Path(temp) / "repo"

        files, _ = script_files(source)

        def fresh():
            if copy.exists():
                shutil.rmtree(copy)
            for rel in files:
                (copy / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source / rel, copy / rel)

        fresh()
        if "internal/lib/bass/bass.iss" not in files:
            failures += 1
            print("FAIL self-test: internal/lib/bass/bass.iss is not among the scripts read: " + ", ".join(files))
        if check(copy):
            failures += 1
            print("FAIL self-test: the unmodified copy does not pass: " + "; ".join(check(copy)))
        for name, apply, *expected in cases:
            fresh()
            apply(copy)
            problems = check(copy)
            hits = [problem for problem in problems if not expected or expected[0] in problem]
            if not problems:
                failures += 1
                print(f"FAIL self-test: {name}: not detected")
            elif not hits:
                failures += 1
                print(f"FAIL self-test: {name}: no problem with '{expected[0]}': " + "; ".join(problems))
            else:
                print(f"ok   {name}: {hits[0]}")
    if failures:
        print(f"self-test: FAIL ({failures} of {len(cases) + 1} cases)")
        return 1
    print(f"self-test: PASS ({len(cases) + 1} cases)")
    return 0


def main():
    args = sys.argv[1:]
    root = Path(__file__).resolve().parent.parent
    if args and args[0] == "--self-test":
        return self_test(root)
    if args:
        root = Path(args[0])
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
