#!/usr/bin/env python3
"""Checks where the setup may ignore TLS certificate errors (ADR 0012).

  python ci/check_tls_policy.py [repo_dir]
  python ci/check_tls_policy.py --self-test

The setup validates the certificate of every request, with one exception: a pinned online file may
be downloaded from a server whose certificate is invalid, because its SHA-256 decides whether it is
installed (docs/adr/0012-pinned-downloads-despite-invalid-certificates.md). This check makes sure
that the exception stays where it is. It reads the own scripts of the setup (every *.iss file in
the root folder; the unit tests in ci/tests call the WinHTTP helpers on purpose and are not read),
without "//" comments, and reports (exit code 1):

  - the flags that ignore certificate errors ($3300, WINHTTP_OPTION_SECURITY_FLAGS = 31) anywhere
    but in ApplyCertificateErrorIgnoreFlags, or a WinHttpSetOption call outside it and
    OpenWinHttpRequest, or a WinHttpOpenRequest call outside OpenWinHttpRequest;
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
function, a second caller, True from another function, the guard removed, ...) that must fail, and
against an unmodified copy that must pass. Exit code 0 if all cases behave.
"""
import re
import shutil
import sys
import tempfile
from pathlib import Path

APPLY = "ApplyCertificateErrorIgnoreFlags"
OPEN = "OpenWinHttpRequest"
PROBE = "GetHttpStatusIgnoringCertificate"
DOWNLOAD = "DownloadPinnedFileWinHttp"
MAY_IGNORE = {PROBE, DOWNLOAD}
COM_OPTIONS = {"WinHttpRequestOptionSecureProtocols", "WinHttpRequestOptionEnableRedirects"}
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


def read_scripts(root):
    """(file name, lines without comments) of every own *.iss file of the root folder."""
    scripts = []
    for path in sorted(Path(root).glob("*.iss")):
        if path.name.startswith("_pp"):
            continue  # temporary copies of ci/build.ps1
        text = path.read_bytes().decode("utf-8-sig", errors="replace").replace("\r\n", "\n")
        scripts.append((path.name, [strip_comment(line) for line in text.split("\n")]))
    return scripts


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
    for name, first, last in spans:
        if first <= index <= last:
            return name
    return None


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
    for name, lines in read_scripts(root):
        spans = routines(lines)
        spans_of[name] = spans
        text = "\n".join(lines)
        texts[name] = (text, lines)
        for callee in (APPLY, OPEN, PROBE, DOWNLOAD, "WinHttpSetOption", "WinHttpOpenRequest"):
            for match in re.finditer(r"\b" + callee + r"\s*\(", text):
                line_index = text.count("\n", 0, match.start())
                line = lines[line_index]
                if HEADER.match(line) or re.match(r"^\s*external\s", line):
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
            if re.search(r"\bDownloadTransportPinnedWinHttp\b", line) and re.search(r":=\s*DownloadTransportPinnedWinHttp\b", line):
                if routine != "GetOnlineFileTransport":
                    problems.append(f"{where}: DownloadTransportPinnedWinHttp chosen outside GetOnlineFileTransport")
                else:
                    condition = (lines[i - 1] if i > 0 else "") + " " + line
                    if not re.search(r"Check\s*=\s*OnlineFilePinned", condition):
                        problems.append(f"{where}: DownloadTransportPinnedWinHttp not under the condition Check = OnlineFilePinned")

    apply_calls = calls.get(APPLY, [])
    if len(apply_calls) != 1 or apply_calls[0][2] != OPEN:
        problems.append(f"{APPLY} must be called exactly once, in {OPEN}: " +
                        ", ".join(f"{f}, line {n} ({o})" for f, n, o, _, _ in apply_calls))
    for f, n, o, args, _ in calls.get("WinHttpSetOption", []):
        if o not in (APPLY, OPEN):
            problems.append(f"{f}, line {n}: WinHttpSetOption outside {APPLY} and {OPEN} ({o})")
        elif o == OPEN and args and len(args) > 1 and re.fullmatch(r"31|\$0*1F|.*Security.*", args[1], re.IGNORECASE):
            problems.append(f"{f}, line {n}: the security flags set in {OPEN} instead of {APPLY}")
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
        if not re.search(r"if\s+Transport\s*=\s*DownloadTransportPinnedWinHttp\s+then", before):
            problems.append(f"{f}, line {n}: {DOWNLOAD} not under 'if Transport = DownloadTransportPinnedWinHttp then'")

    guarded = False
    for name, (text, lines) in texts.items():
        for routine, first, last in spans_of[name]:
            if routine != DOWNLOAD:
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
    ]
    failures = 0
    with tempfile.TemporaryDirectory() as temp:
        copy = Path(temp) / "repo"

        def fresh():
            if copy.exists():
                shutil.rmtree(copy)
            copy.mkdir()
            for path in source.glob("*.iss"):
                if not path.name.startswith("_pp"):
                    shutil.copy2(path, copy / path.name)

        fresh()
        if check(copy):
            failures += 1
            print("FAIL self-test: the unmodified copy does not pass: " + "; ".join(check(copy)))
        for name, apply in cases:
            fresh()
            apply(copy)
            problems = check(copy)
            if not problems:
                failures += 1
                print(f"FAIL self-test: {name}: not detected")
            else:
                print(f"ok   {name}: {problems[0]}")
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
