#!/usr/bin/env python3
"""Checks that the tables of docs/CONTRACT.md match the setup script, and lints the [Files] flags.

  python ci/check_contract.py [repo_dir]
  python ci/check_contract.py --self-test
  python ci/check_contract.py --preprocessed <folder> [repo_dir]

docs/CONTRACT.md is shared with the launcher repository and repeats values whose source of truth
is the setup script. This check reads only TABLES of the contract, never its prose:

  contract                                     script
  header, row "Contract version"               #define ContractVersion (setup_is6.iss)
  0 Products, row "Publisher in the uninstall  per product: MyAppPublisher of config_ee.iss and
  key" (columns EE, NeoEE)                     config_neoee.iss, and the constants
                                               CommunityPublisherEE and CommunityPublisherNeoEE
                                               of utils.iss (the environment checks leave out the
                                               uninstall entries of both community products by
                                               them, ADR 0007)
  2.4, row "code" (column "Extensions")        CodeFileExtensions (utils.iss)
  3.2, Value | Type | Data | Class             the [Registry] values of the game settings keys
                                               (BaseRegEE, BaseRegAoC and their "Game Options"
                                               subkeys, i.e. the GameSettings block) for both
                                               games: name, type, data, class S or D =
                                               deletevalue, P = createvalueifdoesntexist; data
                                               that the script computes or that differs between
                                               entries is "see 3.3"; per-game data such as the
                                               ending epoch is "Empire Earth `13` ..., The Art of
                                               Conquest `14` ..."
  3.3, Value | ... | Minimum | Maximum          the constants MinGameWindowWidth, MaxGameWindowWidth,
                                               MinGameWindowHeight and MaxGameWindowHeight
                                               ('<name> = <number>;', each exactly once in
                                               setup_is6.iss or its #include files, today
                                               utils.iss), rows Game Window Width and Game Window
                                               Height
  3.4, Value name | Component | Data |         the [Registry] entries below
       Windows versions | Task                 Software\\Microsoft\\DirectX\\UserGpuPreferences
                                               (HKCU, REG_SZ, uninsdeletevalue): value name with
                                               {app} as <root>, Components, ValueData, the Windows
                                               versions of the entry and its task, Tasks; the same
                                               in all variants
  3.7, Task | Values | Windows versions |      the compatibility entries of [Registry]
       Root (admin/user/portable)              (AppCompatFlags\\Layers): the flags each task adds
                                               (BuildCompatibilityFlags in utils.iss with the tasks
                                               GetCompatibilityFlags passes; several tasks joined by
                                               'or' are one row each), the Windows compatibility
                                               mode appended by the entries (e.g. WIN7RTM), the
                                               Windows versions from MinVersion and OnlyBelowVersion
                                               of the tasks and of the entries ("all", "8 and
                                               later", "7 only"), "(opt-in)" = the task has
                                               Flags: unchecked, the root per install mode, and the
                                               order of the rows (the order of the value); two
                                               entries for the same program and root that can both
                                               apply in one run are an error

Suite (contract revision 4, setup ADR 0013): suite/suite.iss and the files its #include "..." lines
name. While suite/suite.iss does not exist, the check prints "suite/suite.iss not present, suite
rules skipped" and passes. The suite writes its record and creates its shortcuts in code at
ssPostInstall (ADR 0013 Evidence: the Check functions of [Icons] and [Registry] did not reliably see
what ssInstall had set), so the rules read them from the [Code] lines of the script; entries of a
[Registry] or [Icons] section are read as well and count the same.

  contract                                     suite/suite.iss
  0 "Suite and launcher", rows "Suite setup    [Setup] SetupMutex names the suite setup mutex;
  mutex (SetupMutex)", "Launcher mutex",       AppMutex names the launcher mutex and every name
  "Suite AppMutex"                             of the row "Suite AppMutex" (every occurrence of
                                               the directive, order free)
  1.6, Value | Type, with the row "Suite       the registry values written in code, one call
  record key" of 0                             RegWrite<Type>Value(<root>, '<key>', '<name>', <data>)
                                               per value (literal key and name), or the [Registry]
                                               entries of that key: Root HKLM64, or HKLM with
                                               ArchitecturesInstallIn64BitMode; exactly the value
                                               names of the table with their types; a plain
                                               ContractVersion equal to the contract version; the
                                               removal of the record: the flag uninsdeletekey, or in
                                               code RegDeleteKeyIncludingSubkeys(<root>, '<key>')
                                               and RegDeleteKeyIfEmpty(<root>, '<parent key>')
  1.7, Shortcut | Product | Places | Target |  the calls SuiteShortcut('<place>', '<name>',
       Parameters | Without .NET Framework 4.8 '<target>', '<parameters>', '<product>',
                                               '<fallback>') (literal arguments; the fallback is
                                               the game program below the product root), or the
                                               [Icons] entries: per row and place a shortcut
                                               <place>\<shortcut> that starts the launcher (row
                                               "Launcher program" of 0) with the row's
                                               parameters ({group} is DefaultGroupName below
                                               {autoprograms}); every shortcut with a game
                                               shortcut name starts the launcher with exactly
                                               those parameters, and, as the fallback, the program
                                               of the fallback column without parameters; every
                                               shortcut that passes --product= starts the launcher
                                               and names that product
  0 "Suite and launcher", row "Suite uninstall  the uninstall key of the suite (revision 5): exactly one
  key marker" (name and data in backticks)     RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\
                                               CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1',
                                               '<name>', <data>) (or the [Registry] entry): root
                                               HKLM, REG_DWORD, the data of the row, the AppId of
                                               the suite, never one of the products
  3.8 (protected keys)                         no code line (comments left out) names Software\Sierra,
                                               CDKeys or authtools: the CD key registration stays
                                               the NeoEE setup's own

The suite script is read as written, without evaluating #if: {#Name} is expanded from plain
'#define Name "text"' and '#define Name <number>' lines (a name defined with two values, or
another ISPP expression, stops the check with an error), so the game shortcut names must be
written out (no {cm:...}).

The [Registry] section is preprocessed for each of the four build variants (EE/NeoEE x
Regular/Portable; Regular gives the install modes admin and user, Portable the mode portable) by a
small interpreter of the ISPP directives it uses: #define, #expr, #sub/#endsub, #call,
#if/#ifdef/#ifndef/#elif/#else/#endif and {#...}, with string and integer literals, + - ! == !=
< > <= >= && || and ?:. Any other directive or function there stops the check with an error, so a
construct it does not understand is never guessed. The defines it needs from above [Registry]
(Win8, EEExe, BaseRegEE, ...) are collected from the plain #define lines of setup_is6.iss and of
config_<type>.iss.

[Files] lint (contract 2.3): every [Files] entry whose DestDir is {app} or below has the flag
ignoreversion and none of onlyifdoesntexist, promptifolder and confirmoverwrite, so that every
run processes every file it lists and the integrity manifest can list it. There are no exceptions:
the rule is a MUST of the contract, an exception would need a change of the contract first.
Every such entry also records its files for the manifest (ADR 0004 point 3): a compiled entry has
"AfterInstall: RecordInstalledFile"; an entry that the manifest leaves out must not have it: the
setup data folder (DestDir {app}\\{#SetupDataDir}, preprocessed {app}\\_setupdata_<product>),
deleteafterinstall files, and external entries (Inno Setup calls their AfterInstall once for all
files with the folder as CurrentFileName; the verified online files are added by
installstate.iss). The entries are read as written (also those in #sub blocks, with ISPP line
continuations joined) in setup_is6.iss and in every file its #include "..." lines name.

Verified online files (contract 2.3, ADR 0004 point 3): the external [Files] entries whose Source
is below {tmp}\verified\ install the downloads, and RecordVerifiedOnlineFiles (installstate.iss)
adds what they installed to the manifest with its own copy of their sources, folders and
components. Both sides must name the same (Source, DestDir, Components) triples: from the code,
the components of 'if not WizardIsComponentSelected(...) then Exit;' plus those of the
'if WizardIsComponentSelected(...) then' block, CollectExternalFiles(ExpandConstant('<folder>'),
ExpandConstant('<dest>'), ...) as Source <folder>\* and DestDir <dest>, and a single file
(ExpandConstant('{tmp}\verified\...') and InstalledFiles.Add(ExpandConstant('<dest file>'))) as
that Source and the folder of <dest file>, with the same file name; from [Files], Components may
only join names with 'and'.

--self-test runs the check against modified temporary copies of the repository (one changed
value per rule, e.g. Music Volume $2C -> $2D, a missing extension, another publisher, a window
limit 1920 -> 2560,
GpuPreference=2; -> GpuPreference=1;, WIN7RTM -> WIN8RTM, a missing row compatibility_legacy, a
[Files] entry without ignoreversion, another component of a verified online file entry, and a
minimal suite/suite.iss written by the self-test, in the form of [Registry] and [Icons] and in the
form of code, with one change: the launcher mutex missing in AppMutex, a record value missing or
added, a game shortcut to the wrong target, a reference to a protected key) that must fail
with the expected message, and against copies that must pass (also without suite/suite.iss, and
with the unchanged minimal suite script, checked by the text of the summary).

--preprocessed <folder> takes the scripts that ISCC itself preprocessed (ci/build.ps1
-KeepPreprocessed <folder>: EE_Regular.iss, NeoEE_Regular.iss, EE_Portable.iss,
NeoEE_Portable.iss) and checks that the [Registry] entries of the interpreter above are exactly
those of ISCC for every variant, and lints their fully expanded [Files] sections (the CI workflow
runs it after the placeholder build). This keeps the interpreter honest as the script changes.
The build switch SetupBuild changes [Registry] (the install record's value SetupBuild exists only
if it is set) and ci/build.ps1 sets it in CI and for test builds, so the interpreter takes the
value ISCC got from the preprocessed script: the data of that value, '' (the default) without it.

Exit code 0 if everything matches (resp. all self-test cases behave), else 1.
"""
import re
import shutil
import sys
import tempfile
from pathlib import Path

CONTRACT = "docs/CONTRACT.md"
MAIN_SCRIPT = "setup_is6.iss"
UTILS_SCRIPT = "utils.iss"
VARIANTS = [("EE", "Regular"), ("NeoEE", "Regular"), ("EE", "Portable"), ("NeoEE", "Portable")]
MODES = {"Regular": ["admin", "user"], "Portable": ["portable"]}
ALL_MODES = ["admin", "user", "portable"]
# Dummy AppIds: the checked sections do not use them, but the defines of config_*.iss name them
FIXED_DEFINES = {"EE_AppID": "00000000-0000-0000-0000-0000000000EE",
                 "NeoEE_AppID": "00000000-0000-0000-0000-000000000AEE"}
# Build switch whose value --preprocessed takes from the install record of the preprocessed script
SETUP_BUILD = "SetupBuild"
INSTALL_RECORD_KEY = "\\installations\\"
GAME_NAMES = ["Empire Earth", "The Art of Conquest"]
REG_TYPES = {"string": "REG_SZ", "expandsz": "REG_EXPAND_SZ", "multisz": "REG_MULTI_SZ",
             "dword": "REG_DWORD", "qword": "REG_QWORD", "binary": "REG_BINARY"}
COMPAT_KEY_SUFFIX = "appcompatflags\\layers"
COMPAT_FLAGS_CODE = "{code:GetCompatibilityFlags}"
FILES_REQUIRED_FLAG = "ignoreversion"
FILES_FORBIDDEN_FLAGS = ["onlyifdoesntexist", "promptifolder", "confirmoverwrite"]
# AfterInstall of the compiled [Files] entries below {app} (installstate.iss, ADR 0004 point 3)
FILES_RECORD_PROC = "RecordInstalledFile"
SETUP_DATA_DIR = re.compile(r"^\{app\}\\(\{#SetupDataDir\}|_setupdata_[A-Za-z]+)$", re.I)
# The external [Files] entries of the verified downloads and the code that records their files
VERIFIED_SOURCE = "{tmp}\\verified\\"
VERIFIED_RECORD_PROC = "RecordVerifiedOnlineFiles"
INCLUDE_LINE = re.compile(r'^\s*#\s*include\s+"([^"]+)"\s*$')


class CheckError(Exception):
    """A construct of the script or the contract this check cannot read."""


# ---------------------------------------------------------------------------------------------
# Reading files

def read_text(path):
    return path.read_text(encoding="utf-8-sig")


def logical_lines(text):
    """(number of the first line, text) of every logical line: ISPP joins a line that ends with a
    backslash with the next one."""
    lines, buf, start = [], None, 0
    for no, raw in enumerate(text.splitlines(), 1):
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


def section(lines, name):
    """The logical lines of the Inno Setup section [name] (without its header line)."""
    result, inside = [], False
    for no, text in lines:
        stripped = text.strip()
        if re.fullmatch(r"\[[A-Za-z]+\]", stripped):
            inside = stripped[1:-1].lower() == name.lower()
            continue
        if inside:
            result.append((no, text))
    return result


def parse_params(text):
    """{lowercase name: value} of an Inno Setup entry line ("Name: value; Name: "value"; ...")."""
    params, i, n = {}, 0, len(text)
    while i < n:
        while i < n and text[i] in " \t;":
            i += 1
        if i >= n:
            break
        colon = text.find(":", i)
        if colon < 0:
            raise CheckError(f"cannot read the parameters of '{text.strip()}'")
        key = text[i:colon].strip().lower()
        i = colon + 1
        while i < n and text[i] in " \t":
            i += 1
        if i < n and text[i] == '"':
            value, i = [], i + 1
            while i < n:
                if text[i] == '"':
                    if i + 1 < n and text[i + 1] == '"':
                        value.append('"')
                        i += 2
                        continue
                    i += 1
                    break
                value.append(text[i])
                i += 1
            value = "".join(value)
            while i < n and text[i] != ";":
                i += 1
        else:
            end = text.find(";", i)
            end = n if end < 0 else end
            value, i = text[i:end].strip(), end
        params[key] = value
    return params


# ---------------------------------------------------------------------------------------------
# ISPP subset

ISPP_TOKEN = re.compile(r'\s*(?:(?P<str>"[^"]*")|(?P<num>\d+)|(?P<id>[A-Za-z_]\w*)'
                        r'|(?P<op>==|!=|<=|>=|&&|\|\||\+\+|--|[-+?:()!<>,=]))')


def ispp_tokens(text):
    tokens, pos = [], 0
    while pos < len(text):
        if not text[pos:].strip():
            break
        match = ISPP_TOKEN.match(text, pos)
        if not match:
            raise CheckError(f"ISPP expression not supported by this check: '{text.strip()}'")
        pos = match.end()
        kind = match.lastgroup
        value = match.group(kind)
        if kind == "str":
            tokens.append(("str", value[1:-1]))
        elif kind == "num":
            tokens.append(("num", int(value)))
        else:
            tokens.append((kind, value))
    return tokens


class IsppExpression:
    """Recursive descent evaluation of an ISPP expression (the subset the [Registry] section uses)."""

    def __init__(self, text, defines):
        self.text, self.defines = text, defines
        self.tokens, self.pos = ispp_tokens(text), 0

    def evaluate(self):
        value = self.ternary()
        if self.pos != len(self.tokens):
            raise CheckError(f"ISPP expression not supported by this check: '{self.text.strip()}'")
        return value

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else (None, None)

    def take(self, op=None):
        token = self.peek()
        if token[0] is None or (op is not None and token != ("op", op)):
            raise CheckError(f"ISPP expression not supported by this check: '{self.text.strip()}'")
        self.pos += 1
        return token

    def ternary(self):
        condition = self.logic_or()
        if self.peek() == ("op", "?"):
            self.take("?")
            yes = self.ternary()
            self.take(":")
            no = self.ternary()
            return yes if truthy(condition) else no
        return condition

    def logic_or(self):
        value = self.logic_and()
        while self.peek() == ("op", "||"):
            self.take()
            right = self.logic_and()
            value = int(truthy(value) or truthy(right))
        return value

    def logic_and(self):
        value = self.compare()
        while self.peek() == ("op", "&&"):
            self.take()
            right = self.compare()
            value = int(truthy(value) and truthy(right))
        return value

    def compare(self):
        value = self.additive()
        token = self.peek()
        if token[0] == "op" and token[1] in ("==", "!=", "<", ">", "<=", ">="):
            self.take()
            right = self.additive()
            if isinstance(value, str) != isinstance(right, str):
                raise CheckError(f"ISPP comparison of a string with a number: '{self.text.strip()}'")
            result = {"==": value == right, "!=": value != right, "<": value < right,
                      ">": value > right, "<=": value <= right, ">=": value >= right}[token[1]]
            return int(result)
        return value

    def additive(self):
        value = self.unary()
        while self.peek() in (("op", "+"), ("op", "-")):
            op = self.take()[1]
            right = self.unary()
            if op == "+" and (isinstance(value, str) or isinstance(right, str)):
                value = str(value) + str(right)
            elif isinstance(value, int) and isinstance(right, int):
                value = value + right if op == "+" else value - right
            else:
                raise CheckError(f"ISPP '-' on a string: '{self.text.strip()}'")
        return value

    def unary(self):
        if self.peek() == ("op", "!"):
            self.take()
            return int(not truthy(self.unary()))
        if self.peek() == ("op", "-"):
            self.take()
            value = self.unary()
            if not isinstance(value, int):
                raise CheckError(f"ISPP '-' on a string: '{self.text.strip()}'")
            return -value
        return self.primary()

    def primary(self):
        kind, value = self.take()
        if kind in ("str", "num"):
            return value
        if kind == "op" and value == "(":
            inner = self.ternary()
            self.take(")")
            return inner
        if kind == "id":
            if self.peek() == ("op", "("):
                raise CheckError(f"ISPP function {value}() is not supported by this check: "
                                 f"'{self.text.strip()}'")
            return lookup(self.defines, value)
        raise CheckError(f"ISPP expression not supported by this check: '{self.text.strip()}'")


def truthy(value):
    return value != 0 if isinstance(value, int) else value != ""


def lookup(defines, name):
    if name in defines:
        return defines[name]
    for key, value in defines.items():  # ISPP ignores the case of identifiers (ISCC 6.2.2)
        if key.lower() == name.lower():
            return value
    if name.lower() in ("true", "false"):
        return int(name.lower() == "true")
    raise CheckError(f"ISPP identifier {name} is not defined (or not readable by this check)")


def split_top_level(text, separator=","):
    """Splits at the separator outside of quotes and parentheses."""
    parts, depth, quoted, current = [], 0, False, []
    for char in text:
        if char == '"':
            quoted = not quoted
        elif not quoted and char == "(":
            depth += 1
        elif not quoted and char == ")":
            depth -= 1
        if char == separator and not quoted and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
    parts.append("".join(current))
    return parts


# Marks the value of a {#...} in an entry line that this check cannot evaluate
UNREADABLE = "\x00"


def unreadable(no, params, rule):
    """Raises CheckError if an entry that a rule needs contains a {#...} this check cannot read."""
    for name, value in params.items():
        if UNREADABLE in value:
            expression = value.split(UNREADABLE)[1]
            raise CheckError(f"{MAIN_SCRIPT}:{no}: {{#{expression}}} in {name} cannot be evaluated by "
                             f"this check, but the entry matters for {rule}")


DEFINE = re.compile(r"^(?:(?:public|private|protected)\s+)?([A-Za-z_]\w*)(\()?\s*(?:=\s*)?(.*)$")
DIRECTIVE = re.compile(r"^#\s*([A-Za-z]+)\b\s*(.*)$")


class Preprocessor:
    """Runs the ISPP directives of a list of logical lines and returns the resulting entry lines."""

    def __init__(self, defines, where):
        self.defines, self.subs, self.where = defines, {}, where

    def define(self, rest):
        match = DEFINE.match(rest.strip())
        if not match or match.group(2):
            raise CheckError(f"#define '{rest.strip()}' is not supported by this check")
        expression = match.group(3).strip()
        self.defines[match.group(1)] = IsppExpression(expression, self.defines).evaluate() if expression else ""

    def expr(self, rest):
        for part in split_top_level(rest):
            part = part.strip()
            increment = re.fullmatch(r"([A-Za-z_]\w*)\s*(\+\+|--)", part)
            assignment = re.fullmatch(r"([A-Za-z_]\w*)\s*=(?!=)\s*(.+)", part, re.S)
            if increment:
                value = lookup(self.defines, increment.group(1))
                self.defines[increment.group(1)] = value + (1 if increment.group(2) == "++" else -1)
            elif assignment:
                self.defines[assignment.group(1)] = IsppExpression(assignment.group(2), self.defines).evaluate()
            else:
                raise CheckError(f"#expr '{part}' is not supported by this check")

    def substitute(self, text, no):
        """The line with every {#...} replaced by its value. A {#...} this check cannot evaluate
        becomes UNREADABLE + its text: an error only if the entry matters for a rule (unreadable)."""
        def replace(match):
            try:
                return str(IsppExpression(match.group(1), self.defines).evaluate())
            except CheckError:
                return UNREADABLE + match.group(1).replace(";", ",").replace('"', "'") + UNREADABLE
        return re.sub(r"\{#([^}]*)\}", replace, text)

    def run(self, lines):
        """[(line number, substituted entry line)] of the active non-directive lines."""
        out, stack, i = [], [], 0
        while i < len(lines):
            no, text = lines[i]
            i += 1
            stripped = text.strip()
            active = all(level["active"] for level in stack)
            directive = DIRECTIVE.match(stripped) if stripped.startswith("#") else None
            if not directive:
                if active and stripped and not stripped.startswith(";"):
                    out.append((no, self.substitute(text, no)))
                continue
            name, rest = directive.group(1).lower(), directive.group(2)
            if name in ("if", "ifdef", "ifndef"):
                value = False
                if active:
                    try:
                        if name == "if":
                            value = truthy(IsppExpression(rest, self.defines).evaluate())
                        else:
                            known = True
                            try:
                                lookup(self.defines, rest.strip())
                            except CheckError:
                                known = False
                            value = known == (name == "ifdef")
                    except CheckError as error:
                        raise CheckError(f"{self.where}:{no}: {error}")
                stack.append({"active": value, "taken": value})
            elif name == "elif":
                if not stack:
                    raise CheckError(f"{self.where}:{no}: #elif without #if")
                level = stack[-1]
                parent_active = all(lvl["active"] for lvl in stack[:-1])
                level["active"] = False
                if parent_active and not level["taken"]:
                    try:
                        level["active"] = truthy(IsppExpression(rest, self.defines).evaluate())
                    except CheckError as error:
                        raise CheckError(f"{self.where}:{no}: {error}")
                    level["taken"] = level["active"]
            elif name == "else":
                if not stack:
                    raise CheckError(f"{self.where}:{no}: #else without #if")
                level = stack[-1]
                level["active"] = not level["taken"]
                level["taken"] = True
            elif name == "endif":
                if not stack:
                    raise CheckError(f"{self.where}:{no}: #endif without #if")
                stack.pop()
            elif name == "sub":
                body, depth = [], 1
                while i < len(lines):
                    inner = lines[i][1].strip()
                    i += 1
                    if re.match(r"^#\s*sub\b", inner):
                        depth += 1
                    elif re.match(r"^#\s*endsub\b", inner):
                        depth -= 1
                        if depth == 0:
                            break
                    body.append(lines[i - 1])
                else:
                    raise CheckError(f"{self.where}:{no}: #sub without #endsub")
                if active:
                    self.subs[rest.strip()] = body
            elif not active:
                continue
            elif name in ("define", "expr"):
                try:
                    (self.define if name == "define" else self.expr)(rest)
                except CheckError as error:
                    raise CheckError(f"{self.where}:{no}: {error}")
            elif name == "call":
                sub = rest.strip()
                if sub not in self.subs:
                    raise CheckError(f"{self.where}:{no}: #call of the unknown sub {sub}")
                out.extend(self.run(self.subs[sub]))
            elif name in ("error",) or (name == "pragma" and rest.strip().lower().startswith("error")):
                raise CheckError(f"{self.where}:{no}: the script stops with {stripped}")
            elif name == "pragma":
                continue
            else:
                raise CheckError(f"{self.where}:{no}: #{name} is not supported by this check "
                                 "(it reads #define, #expr, #sub, #call and #if only)")
        if stack:
            raise CheckError(f"{self.where}: #if without #endif")
        return out


def collect_defines(root, install_type, install_mode, switches=None):
    """The plain #define values of config_<type>.iss and of setup_is6.iss above [Registry], for one
    build variant, with the build switches given as ISCC /D switches (switches, e.g. SetupBuild)
    instead of their defaults. Lines this check cannot evaluate are skipped: only the names the
    checked sections use matter, and using an unreadable one is an error there."""
    defines = dict(FIXED_DEFINES, InstallType=install_type, InstallMode=install_mode, **(switches or {}))
    fixed = set(defines)
    files = [root / f"config_{install_type.lower()}.iss", root / MAIN_SCRIPT]
    for path in files:
        in_sub = 0
        for no, text in logical_lines(read_text(path)):
            stripped = text.strip()
            if path.name == MAIN_SCRIPT and stripped.lower() == "[registry]":
                break
            directive = DIRECTIVE.match(stripped) if stripped.startswith("#") else None
            if not directive:
                continue
            name = directive.group(1).lower()
            if name == "sub":
                in_sub += 1
            elif name == "endsub":
                in_sub -= 1
            elif name == "define" and not in_sub:
                match = DEFINE.match(directive.group(2).strip())
                if not match or match.group(2) or match.group(1) in fixed:
                    continue
                try:
                    expression = match.group(3).strip()
                    defines[match.group(1)] = IsppExpression(expression, defines).evaluate() if expression else ""
                except CheckError:
                    continue
    return defines


def registry_entries(root, install_type, install_mode, switches=None):
    """[(line, params)] of the [Registry] section of setup_is6.iss after preprocessing, and the
    defines, for one build variant (switches: build switches as with ISCC /D)."""
    defines = collect_defines(root, install_type, install_mode, switches)
    lines = section(logical_lines(read_text(root / MAIN_SCRIPT)), "Registry")
    entries = []
    for no, text in Preprocessor(defines, MAIN_SCRIPT).run(lines):
        try:
            entries.append((no, parse_params(text)))
        except CheckError as error:
            raise CheckError(f"{MAIN_SCRIPT}:{no}: {error}")
    return entries, defines


# ---------------------------------------------------------------------------------------------
# Inno Setup boolean expressions (Tasks, Components, Check)

INNO_TOKEN = re.compile(r"\s*(\(|\)|[A-Za-z_][\w\\]*(?:\([^()]*\))?)")


def parse_bool(text):
    """AST of an Inno Setup boolean expression: ("atom", name) | ("not", a) | ("and"/"or", a, b)."""
    tokens, pos, text = [], 0, text.strip()
    while pos < len(text):
        match = INNO_TOKEN.match(text, pos)
        if not match:
            raise CheckError(f"cannot read the expression '{text}'")
        tokens.append(match.group(1))
        pos = match.end()
        while pos < len(text) and text[pos].isspace():
            pos += 1
    index = [0]

    def peek():
        return tokens[index[0]].lower() if index[0] < len(tokens) else None

    def take():
        index[0] += 1
        return tokens[index[0] - 1]

    def or_expr():
        node = and_expr()
        while peek() == "or":
            take()
            node = ("or", node, and_expr())
        return node

    def and_expr():
        node = not_expr()
        while peek() == "and":
            take()
            node = ("and", node, not_expr())
        return node

    def not_expr():
        token = peek()
        if token is None:
            raise CheckError(f"cannot read the expression '{text}'")
        if token == "not":
            take()
            return ("not", not_expr())
        if token == "(":
            take()
            node = or_expr()
            if peek() != ")":
                raise CheckError(f"cannot read the expression '{text}'")
            take()
            return node
        if token in ("and", "or", ")"):
            raise CheckError(f"cannot read the expression '{text}'")
        return ("atom", take().lower())

    node = or_expr()
    if index[0] != len(tokens):
        raise CheckError(f"cannot read the expression '{text}'")
    return node


def atoms(node):
    if node[0] == "atom":
        return {node[1]}
    return set().union(*(atoms(child) for child in node[1:]))


def evaluate_bool(node, values):
    kind = node[0]
    if kind == "atom":
        return values[node[1]]
    if kind == "not":
        return not evaluate_bool(node[1], values)
    if kind == "and":
        return evaluate_bool(node[1], values) and evaluate_bool(node[2], values)
    return evaluate_bool(node[1], values) or evaluate_bool(node[2], values)


def satisfiable(node, fixed):
    """True if some values of the atoms not in fixed make the expression true."""
    free = sorted(atoms(node) - set(fixed))
    for bits in range(2 ** len(free)):
        values = dict(fixed)
        values.update({atom: bool(bits >> i & 1) for i, atom in enumerate(free)})
        if evaluate_bool(node, values):
            return True
    return False


TRUE = ("atom", "#true")


def parse_bool_or_true(text):
    return parse_bool(text) if text and text.strip() else TRUE


def satisfiable_with_true(node, fixed):
    return satisfiable(node, dict(fixed, **{"#true": True}))


# ---------------------------------------------------------------------------------------------
# Markdown tables of the contract

def contract_section(lines, number):
    """[(line number, text)] of the section '### <number> ...' of the contract."""
    result, inside, level = [], False, 0
    for no, text in enumerate(lines, 1):
        heading = re.match(r"^(#{1,6})\s+(\S+)", text)
        if heading:
            if inside and len(heading.group(1)) <= level:
                break
            if heading.group(2) == number:
                inside, level = True, len(heading.group(1))
                continue
        if inside:
            result.append((no, text))
    return result


def first_table(numbered_lines, where):
    """(header cells, [(line number, cells)]) of the first Markdown table of the lines."""
    header, rows = None, []
    for no, text in numbered_lines:
        if not text.startswith("|"):
            if header is not None:
                break
            continue
        cells = [cell.strip() for cell in text.strip().strip("|").split("|")]
        if header is None:
            header = cells
        elif not all(re.fullmatch(r":?-+:?", cell) for cell in cells):
            rows.append((no, dict(zip(header, cells))))
    if header is None:
        raise CheckError(f"{CONTRACT}: no table in {where}")
    return header, rows


def plain(cell):
    return cell.replace("`", "").replace("**", "").strip()


def require_columns(header, columns, where):
    missing = [column for column in columns if column not in header]
    if missing:
        raise CheckError(f"{CONTRACT}: the table of {where} has no column {', '.join(missing)} "
                         f"(columns: {', '.join(header)})")


# ---------------------------------------------------------------------------------------------
# Rule: contract version

def check_contract_version(root, contract_lines, errors):
    contract_version, contract_line = None, None
    for no, text in enumerate(contract_lines, 1):
        if text.startswith("## "):
            break
        match = re.match(r"^\|\s*Contract version\s*\|\s*\*{0,2}(\d+)\*{0,2}\s*\|", text)
        if match:
            contract_version, contract_line = int(match.group(1)), no
            break
    if contract_version is None:
        errors.append(f"{CONTRACT}: no row 'Contract version' in the header table")
    defines = [(no, text) for no, text in logical_lines(read_text(root / MAIN_SCRIPT))
               if re.match(r"^\s*#\s*define\s+ContractVersion\b", text)]
    if len(defines) != 1:
        errors.append(f"{MAIN_SCRIPT}: expected exactly one '#define ContractVersion <number>', "
                      f"found {len(defines)}")
        return None
    no, text = defines[0]
    match = re.fullmatch(r"\s*#\s*define\s+ContractVersion\s+(\d+)\s*", text)
    if not match:
        errors.append(f"{MAIN_SCRIPT}:{no}: ContractVersion must be a plain number: '{text.strip()}'")
        return None
    script_version = int(match.group(1))
    if contract_version is not None and script_version != contract_version:
        errors.append(f"{CONTRACT}:{contract_line} (header): contract version {contract_version}, "
                      f"but {MAIN_SCRIPT}:{no} has '#define ContractVersion {script_version}'")
    return script_version


# ---------------------------------------------------------------------------------------------
# Rule 0, Products: publishers of the community setups

# Row of the table "Products" and, per product column, the constant of utils.iss
PUBLISHER_ROW = "Publisher in the uninstall key"
PUBLISHER_CONSTANTS = {"EE": "CommunityPublisherEE", "NeoEE": "CommunityPublisherNeoEE"}


def check_publishers(root, contract_lines, errors):
    """Contract 0, Products, row "Publisher in the uninstall key": per product the same text as
    MyAppPublisher of config_<product>.iss (AppPublisher of the setup, the Publisher of its
    uninstall key) and as the constant CommunityPublisher<product> of utils.iss, by which the
    environment checks leave out the uninstall entries of both community products (ADR 0007).
    Returns the number of products checked."""
    header, rows = first_table(contract_section(contract_lines, "Products"), "0 (Products)")
    require_columns(header, list(PUBLISHER_CONSTANTS), "0 (Products)")
    found = [(no, row) for no, row in rows if plain(row[header[0]]) == PUBLISHER_ROW]
    if len(found) != 1:
        errors.append(f"{CONTRACT} (0, Products): expected one row '{PUBLISHER_ROW}', found {len(found)}")
        return 0
    no, row = found[0]
    utils = logical_lines(read_text(root / UTILS_SCRIPT))
    for product, constant in PUBLISHER_CONSTANTS.items():
        expected = plain(row[product])
        where = f"{CONTRACT}:{no} (0, Products) {product}"
        config = f"config_{product.lower()}.iss"
        defines = [(line, match.group(1)) for line, text in logical_lines(read_text(root / config))
                   for match in [re.fullmatch(r'\s*#\s*define\s+MyAppPublisher\s+"([^"]*)"\s*', text)] if match]
        if len(defines) != 1:
            errors.append(f"{config}: expected exactly one '#define MyAppPublisher \"<text>\"', found {len(defines)}")
        elif defines[0][1] != expected:
            errors.append(f"{where}: publisher '{expected}' in the contract, '{defines[0][1]}' in "
                          f"{config}:{defines[0][0]} (MyAppPublisher)")
        constants = [(line, match.group(1)) for line, text in utils
                     for match in [re.fullmatch(rf"\s*{constant}\s*=\s*'([^']*)'\s*;.*", text)] if match]
        if len(constants) != 1:
            errors.append(f"{UTILS_SCRIPT}: expected exactly one constant '{constant} = '<text>';', found {len(constants)}")
        elif constants[0][1] != expected:
            errors.append(f"{where}: publisher '{expected}' in the contract, '{constants[0][1]}' in "
                          f"{UTILS_SCRIPT}:{constants[0][0]} ({constant})")
    return len(PUBLISHER_CONSTANTS)


# ---------------------------------------------------------------------------------------------
# Rule 2.4: file classes, row "code"

def check_code_extensions(root, contract_lines, errors):
    header, rows = first_table(contract_section(contract_lines, "2.4"), "2.4")
    require_columns(header, ["Class", "Extensions"], "2.4")
    code_rows = [(no, row) for no, row in rows if plain(row["Class"]) == "code"]
    if len(code_rows) != 1:
        errors.append(f"{CONTRACT} (2.4): expected one row 'code', found {len(code_rows)}")
        return 0
    no, row = code_rows[0]
    contract_ext = " ".join(re.findall(r"`([^`]*)`", row["Extensions"])).split()

    text = read_text(root / UTILS_SCRIPT)
    match = re.search(r"\bCodeFileExtensions\s*=\s*((?:'[^']*'\s*\+?\s*)+);", text)
    if not match:
        errors.append(f"{UTILS_SCRIPT}: constant CodeFileExtensions not found (a sum of string literals)")
        return 0
    script_line = text.count("\n", 0, match.start()) + 1
    joined = "".join(re.findall(r"'([^']*)'", match.group(1)))
    if not (joined.startswith("|") and joined.endswith("|")):
        errors.append(f"{UTILS_SCRIPT}:{script_line}: CodeFileExtensions must start and end with '|'")
    script_ext = joined.strip("|").split("|")
    if "" in script_ext:
        errors.append(f"{UTILS_SCRIPT}:{script_line}: CodeFileExtensions has an empty extension ('||')")
    for name, values, where in (("contract", contract_ext, f"{CONTRACT}:{no}"),
                                ("script", script_ext, f"{UTILS_SCRIPT}:{script_line}")):
        duplicates = sorted({value for value in values if values.count(value) > 1})
        if duplicates:
            errors.append(f"{where}: extensions listed twice: {' '.join(duplicates)}")
        upper = [value for value in values if value != value.lower()]
        if upper:
            errors.append(f"{where}: extensions must be lowercase: {' '.join(upper)}")
    missing_in_contract = [ext for ext in script_ext if ext and ext not in contract_ext]
    missing_in_script = [ext for ext in contract_ext if ext not in script_ext]
    if missing_in_contract:
        errors.append(f"{CONTRACT}:{no} (2.4, row code): missing {' '.join(missing_in_contract)}, "
                      f"which CodeFileExtensions ({UTILS_SCRIPT}:{script_line}) lists")
    if missing_in_script:
        errors.append(f"{CONTRACT}:{no} (2.4, row code): lists {' '.join(missing_in_script)}, which "
                      f"CodeFileExtensions ({UTILS_SCRIPT}:{script_line}) does not have")
    return len(script_ext)


# ---------------------------------------------------------------------------------------------
# Rule 3.2: game settings

def inno_number(text):
    text = text.strip()
    if re.fullmatch(r"\$[0-9A-Fa-f]+", text):
        return int(text[1:], 16)
    if re.fullmatch(r"-?\d+", text):
        return int(text)
    return None


def describe(value_type, value):
    if value is None:
        return "computed (see 3.3)"
    if value_type == "REG_DWORD" and isinstance(value, int):
        return f"{value} (0x{value:X})"
    return f"'{value}'"


def script_game_settings(entries, defines):
    """{value name: {"type", "class", "data": {game: value or None}, "line"}} of the [Registry]
    values below the game settings keys, or raises CheckError."""
    keys = {}
    for game, define in zip(GAME_NAMES, ("BaseRegEE", "BaseRegAoC")):
        base = lookup(defines, define)
        keys[base.lower()] = (game, "")
        keys[(base + "\\Game Options").lower()] = (game, "Game Options\\")
    values = {}
    for no, params in entries:
        key = params.get("subkey", "").lower()
        if UNREADABLE in key:
            unreadable(no, params, "contract 3.2 (it may be a game settings key)")
        if key not in keys:
            continue
        unreadable(no, params, "contract 3.2")
        if params.get("root", "").upper() != "HKCU":
            raise CheckError(f"{MAIN_SCRIPT}:{no}: a game settings value outside HKCU (contract 3.1: always HKCU)")
        if "valuename" not in params:
            continue
        game, prefix = keys[key]
        name = prefix + params["valuename"]
        value_type = REG_TYPES.get(params.get("valuetype", "").lower())
        if value_type is None:
            raise CheckError(f"{MAIN_SCRIPT}:{no}: {name}: ValueType '{params.get('valuetype', '')}' "
                             "is not supported by this check")
        flags = params.get("flags", "").lower().split()
        if "createvalueifdoesntexist" in flags:
            kind = "P"
        elif "deletevalue" in flags:
            kind = "S/D"
        else:
            kind = "neither deletevalue nor createvalueifdoesntexist"
        info = values.setdefault(name, {"types": set(), "classes": set(), "data": {}, "line": no})
        info["types"].add(value_type)
        info["classes"].add(kind)
        info["data"].setdefault(game, []).append(params.get("valuedata", ""))
    result = {}
    for name, info in values.items():
        if len(info["types"]) != 1:
            raise CheckError(f"{MAIN_SCRIPT}:{info['line']}: {name} has entries of different types")
        value_type = info["types"].pop()
        data = {}
        for game in GAME_NAMES:
            raw = info["data"].get(game)
            if raw is None:
                data[game] = "missing"
                continue
            if len(set(raw)) > 1 or any("{" in item for item in raw):
                data[game] = None  # computed (code, constants) or different by condition
            elif value_type == "REG_DWORD":
                data[game] = inno_number(raw[0])
                if data[game] is None:
                    raise CheckError(f"{MAIN_SCRIPT}:{info['line']}: {name}: dword data '{raw[0]}' "
                                     "is not a number")
            else:
                data[game] = raw[0]
        result[name] = {"type": value_type, "classes": info["classes"], "data": data,
                        "line": info["line"]}
    return result


def contract_data(cell, value_type, where):
    """None (computed, "see 3.3") or {game: value} from a Data cell of 3.2."""
    def number(literal, hex_text, game=""):
        if value_type != "REG_DWORD":
            return literal
        if not re.fullmatch(r"-?\d+", literal):
            raise CheckError(f"{where}: data '{literal}' of a REG_DWORD is not a decimal number")
        value = int(literal)
        if hex_text and int(hex_text, 16) != value:
            raise CheckError(f"{where}: {game}data `{literal}` and ({hex_text}) differ in the contract")
        return value

    if "`" not in cell:
        if re.search(r"\b3\.3\b", cell):
            return None
        raise CheckError(f"{where}: data '{cell}' is neither a `value` nor 'see 3.3'")
    games = re.findall(r"(Empire Earth|The Art of Conquest)\s+`([^`]*)`(?:\s*\((0x[0-9A-Fa-f]+)\b[^)]*\))?", cell)
    if games:
        result = {game: number(literal, hex_text, game + " ") for game, literal, hex_text in games}
        if sorted(result) != sorted(GAME_NAMES):
            raise CheckError(f"{where}: per-game data must name Empire Earth and The Art of Conquest")
        return result
    match = re.match(r"\s*`([^`]*)`(?:\s*\((0x[0-9A-Fa-f]+)\b[^)]*\))?", cell)
    if not match:
        raise CheckError(f"{where}: cannot read the data '{cell}'")
    value = number(match.group(1), match.group(2))
    return {game: value for game in GAME_NAMES}


def check_game_settings(contract_lines, script, errors):
    header, rows = first_table(contract_section(contract_lines, "3.2"), "3.2")
    require_columns(header, ["Value", "Type", "Data", "Class"], "3.2")
    contract = {}
    for no, row in rows:
        name = plain(row["Value"])
        where = f"{CONTRACT}:{no} (3.2)"
        if name in contract:
            errors.append(f"{where}: {name} is listed twice")
            continue
        value_type = plain(row["Type"])
        try:
            data = contract_data(row["Data"], value_type, f"{where} {name}")
        except CheckError as error:
            errors.append(str(error))
            continue
        contract[name] = {"no": no, "type": value_type, "data": data, "class": plain(row["Class"])}

    found = []
    for name, info in script.items():
        where_script = f"{MAIN_SCRIPT}:{info['line']}"
        if name not in contract:
            errors.append(f"{CONTRACT} (3.2): {name} is missing, {where_script} writes it")
            continue
        row = contract[name]
        where = f"{CONTRACT}:{row['no']} (3.2) {name}"
        found.append(name)
        missing_games = [game for game in GAME_NAMES if info["data"][game] == "missing"]
        if missing_games:
            errors.append(f"{where}: {where_script} writes it only for "
                          f"{', '.join(g for g in GAME_NAMES if g not in missing_games)}; the table "
                          "has no way to say that")
            continue
        if row["type"] != info["type"]:
            errors.append(f"{where}: type {row['type']} in the contract, {info['type']} in {where_script}")
            continue
        if len(info["classes"]) != 1:
            errors.append(f"{where}: the entries in {MAIN_SCRIPT} use different flags "
                          f"({', '.join(sorted(info['classes']))})")
        else:
            script_class = next(iter(info["classes"]))
            expected = {"S": "S/D", "D": "S/D", "P": "P"}.get(row["class"])
            if expected is None:
                errors.append(f"{where}: class '{row['class']}' is not S, D or P")
            elif script_class != expected:
                flag = {"P": "createvalueifdoesntexist", "S/D": "deletevalue"}.get(script_class, script_class)
                errors.append(f"{where}: class {row['class']} in the contract, but {where_script} "
                              f"uses {flag} (S and D: deletevalue, P: createvalueifdoesntexist)")
        for game in GAME_NAMES:
            want, have = row["data"], info["data"][game]
            want = None if want is None else want[game]
            if want != have:
                errors.append(f"{where}: {game}: data {describe(row['type'], want)} in the contract, "
                              f"{describe(info['type'], have)} in {where_script}")
    for name, row in contract.items():
        if name not in script:
            errors.append(f"{CONTRACT}:{row['no']} (3.2): {name} is not written by {MAIN_SCRIPT} "
                          "(no [Registry] value of that name below the game settings keys)")
    return len(found)


# ---------------------------------------------------------------------------------------------
# Rule 3.7: compatibility values

def nt_version(text):
    """(major, minor) of the NT part of a MinVersion value ("0.0,6.2", "6.2", "0,10"); (0, 0) if empty."""
    if not text or not text.strip():
        return (0, 0)
    part = text.split(",")[-1].strip()
    match = re.match(r"^(\d+)(?:\.(\d+))?", part)
    if not match:
        raise CheckError(f"cannot read the Windows version '{text}'")
    return (int(match.group(1)), int(match.group(2) or 0))


def version_range(min_version, only_below_version):
    """(lowest NT version, NT version it is only below or None) of MinVersion and OnlyBelowVersion.
    An OnlyBelowVersion of 0 means no limit, as in Inno Setup."""
    below = nt_version(only_below_version)
    return (nt_version(min_version), None if below == (0, 0) else below)


def intersect(first, second):
    """The versions two ranges have in common, None if there are none."""
    if first is None or second is None:
        return None
    low = max(first[0], second[0])
    highs = [high for high in (first[1], second[1]) if high is not None]
    high = min(highs) if highs else None
    return None if high is not None and high <= low else (low, high)


def union(ranges):
    """The smallest range that holds all ranges (None if there are none)."""
    ranges = [r for r in ranges if r is not None]
    if not ranges:
        return None
    high = None if any(r[1] is None for r in ranges) else max(r[1] for r in ranges)
    return (min(r[0] for r in ranges), high)


# Windows names of NT versions, and of the version just below an OnlyBelowVersion
WINDOWS_NAMES = {(6, 1): "7", (6, 2): "8", (6, 3): "8.1", (10, 0): "10"}
WINDOWS_BELOW = {(6, 2): "7", (6, 3): "8", (10, 0): "8.1"}


def version_label(version):
    """The 'Windows versions' text of contract 3.7 (and 3.4) for a range: setups made with Inno
    Setup 6 start on Windows 7 SP1 and later, so any minimum up to NT 6.1 is Windows 7, and a range
    without an upper limit that starts there is 'all'. Examples: 'all', '8 and later', '7 only'."""
    low, high = version
    first = "7" if low <= (6, 1) else WINDOWS_NAMES.get(low, f"NT {low[0]}.{low[1]}")
    if high is None:
        return "all" if low <= (6, 1) else f"{first} and later"
    last = WINDOWS_BELOW.get(high, f"below NT {high[0]}.{high[1]}")
    return f"{first} only" if first == last else f"{first} to {last}"


OPT_IN = "(opt-in)"


def compatibility_flag_tasks(root):
    """[(task, flags)] in the order BuildCompatibilityFlags appends them, with the tasks that
    GetCompatibilityFlags passes for its parameters. A parameter may get several tasks joined by
    'or' (WizardIsTaskSelected('a') or WizardIsTaskSelected('b')): each of them is a row with the
    same flags, in that order."""
    utils = read_text(root / UTILS_SCRIPT)
    header = re.search(r"function\s+BuildCompatibilityFlags\s*\(([^)]*)\)\s*:\s*String\s*;", utils)
    if not header:
        raise CheckError(f"{UTILS_SCRIPT}: function BuildCompatibilityFlags(...): String not found")
    params = []
    for group in header.group(1).split(";"):
        names = group.split(":")[0]
        names = re.sub(r"^\s*(const|var)\s+", "", names)
        params += [name.strip() for name in names.split(",") if name.strip()]
    end = re.search(r"^end;", utils[header.end():], re.M)
    body = utils[header.end():header.end() + (end.start() if end else len(utils))]
    if not re.search(r"Result\s*:=\s*'~'\s*;", body):
        raise CheckError(f"{UTILS_SCRIPT}: BuildCompatibilityFlags does not start with Result := '~'")
    appended = re.findall(r"if\s+(\w+)\s+then\s+Result\s*:=\s*Result\s*\+\s*'([^']*)'\s*;", body)
    if not appended:
        raise CheckError(f"{UTILS_SCRIPT}: BuildCompatibilityFlags appends no flags "
                         "('if <parameter> then Result := Result + ' FLAGS';')")

    main = read_text(root / MAIN_SCRIPT)
    function = re.search(r"function\s+GetCompatibilityFlags\s*\([^)]*\)\s*:\s*String\s*;(.*?)^end;",
                         main, re.S | re.M)
    call = re.search(r"BuildCompatibilityFlags\s*\((.*?)\)\s*;", function.group(1), re.S) if function else None
    if not call:
        raise CheckError(f"{MAIN_SCRIPT}: GetCompatibilityFlags does not call BuildCompatibilityFlags")
    arguments = split_top_level(call.group(1) + ")" * (call.group(1).count("(") - call.group(1).count(")")))
    tasks = []
    for argument in arguments:
        names = []
        for part in re.split(r"\s+or\s+", argument.strip(), flags=re.I):
            match = re.fullmatch(r"\s*WizardIsTaskSelected\s*\(\s*'([^']+)'\s*\)\s*", part)
            if not match:
                raise CheckError(f"{MAIN_SCRIPT}: GetCompatibilityFlags passes '{argument.strip()}' to "
                                 "BuildCompatibilityFlags, expected WizardIsTaskSelected('<task>'), "
                                 "or several of them joined by 'or'")
            names.append(match.group(1).lower())
        tasks.append(names)
    if len(tasks) != len(params):
        raise CheckError(f"{MAIN_SCRIPT}: GetCompatibilityFlags passes {len(tasks)} tasks, "
                         f"BuildCompatibilityFlags has {len(params)} parameters")
    by_param = {param.lower(): names for param, names in zip(params, tasks)}
    result = []
    for param, flags in appended:
        if param.lower() not in by_param:
            raise CheckError(f"{UTILS_SCRIPT}: BuildCompatibilityFlags tests '{param}', which is not a parameter")
        result += [(task, " ".join(flags.split())) for task in by_param[param.lower()]]
    return result


def script_tasks(root):
    """{task: {"check": AST, "range": versions, "optin": bool, "line": n}} of [Tasks] in
    setup_is6.iss, read as written (an #if around a task is ignored; a task defined twice must be
    defined the same way). range: MinVersion and OnlyBelowVersion; optin: Flags: unchecked."""
    defines = collect_defines(root, "EE", "Regular")
    tasks = {}
    for no, text in section(logical_lines(read_text(root / MAIN_SCRIPT)), "Tasks"):
        stripped = text.strip()
        if not stripped or stripped.startswith((";", "#")):
            continue
        try:
            text = re.sub(r"\{#([^}]*)\}", lambda m: str(IsppExpression(m.group(1), defines).evaluate()), text)
        except CheckError:
            pass  # e.g. a description: only Name, MinVersion, OnlyBelowVersion, Flags and Check are used
        params = parse_params(text)
        if "name" not in params:
            continue
        name = params["name"].lower()
        info = {"check": parse_bool_or_true(params.get("check", "")),
                "range": version_range(params.get("minversion", ""), params.get("onlybelowversion", "")),
                "optin": "unchecked" in params.get("flags", "").lower().split(), "line": no}
        if name in tasks and (tasks[name]["check"], tasks[name]["range"], tasks[name]["optin"]) != \
                (info["check"], info["range"], info["optin"]):
            raise CheckError(f"{MAIN_SCRIPT}:{no}: task {name} is defined twice with different "
                             "Check, Windows versions or Flags")
        tasks[name] = info
    return tasks


def assignments(node, fixed):
    """Every assignment of the atoms (fixed ones kept) that makes the expression true."""
    free = sorted(atoms(node) - set(fixed))
    for bits in range(2 ** len(free)):
        values = dict(fixed)
        values.update({atom: bool(bits >> i & 1) for i, atom in enumerate(free)})
        if evaluate_bool(node, values):
            yield values


def selected_range(node, fixed, versions, tasks):
    """The Windows versions (within versions) on which the tasks can be selected so that the
    expression is true, as the union over every such selection: a selected task exists only on its
    own Windows versions. None if there is no such selection."""
    found = []
    for values in assignments(node, dict(fixed, **{"#true": True})):
        current = versions
        for name, selected in values.items():
            if selected and name in tasks:
                current = intersect(current, tasks[name]["range"])
        if current is not None:
            found.append(current)
    return union(found)


def script_compatibility_rows(entries, flag_tasks, tasks, modes):
    """The rows of contract 3.7 as the script implies them for the install modes of one variant:
    [{"task", "values", "version": Windows versions with a value or None, "roots": {mode: root
    or "-"}, "task_range", "optin", "line"}]. Raises CheckError for entries that this check cannot
    read and for two entries that can write the value of the same program at once."""
    compat = []
    for no, params in entries:
        if UNREADABLE in params.get("subkey", ""):
            unreadable(no, params, "contract 3.7 (it may be a compatibility value)")
        if not params.get("subkey", "").lower().endswith(COMPAT_KEY_SUFFIX):
            continue
        unreadable(no, params, "contract 3.7")
        data = params.get("valuedata", "")
        if not data.startswith(COMPAT_FLAGS_CODE):
            raise CheckError(f"{MAIN_SCRIPT}:{no}: compatibility value '{data}' does not start with "
                             f"{COMPAT_FLAGS_CODE}")
        compat.append({"line": no, "root": params.get("root", "").upper(),
                       "check": parse_bool_or_true(params.get("check", "")),
                       "tasks": parse_bool_or_true(params.get("tasks", "")),
                       "range": version_range(params.get("minversion", ""), params.get("onlybelowversion", "")),
                       "layer": " ".join(data[len(COMPAT_FLAGS_CODE):].split()),
                       "components": params.get("components", "").strip().lower(),
                       "signature": (params.get("root", "").upper(), params.get("check", ""),
                                     params.get("tasks", ""), params.get("minversion", ""),
                                     params.get("onlybelowversion", ""), data)})
    # Every entry exists for both programs (component game: Empire Earth.exe, gameaoc: EE-AOC.exe)
    by_signature = {}
    for entry in compat:
        by_signature.setdefault(entry["signature"], []).append(entry)
    for group in by_signature.values():
        components = sorted(entry["components"] for entry in group)
        if components != ["game", "gameaoc"]:
            raise CheckError(f"{MAIN_SCRIPT}:{group[0]['line']}: this compatibility entry exists for "
                             f"the components {', '.join(components)}, contract 3.7 needs it for "
                             "game (Empire Earth.exe) and gameaoc (EE-AOC.exe) alike")

    names = {task for task, _ in flag_tasks}
    for entry in compat:
        names |= {atom for atom in atoms(entry["tasks"]) if atom != "#true"}
    for name in sorted(names):
        if name not in tasks:
            raise CheckError(f"{MAIN_SCRIPT}: task {name} is used by the compatibility values but "
                             "not defined in [Tasks]")

    def available(task, mode):
        return satisfiable_with_true(tasks[task]["check"], {"isadmininstallmode": mode == "admin"})

    def applies(entry, mode):
        return satisfiable_with_true(entry["check"], {"isadmininstallmode": mode == "admin"})

    def unavailable(mode):
        return {name: False for name in names if not available(name, mode)}

    def selection(entry, task, mode):
        """Windows versions on which the entry writes a value with the task selected, or None."""
        if not (available(task, mode) and applies(entry, mode)):
            return None
        fixed = dict(unavailable(mode), **{task: True})
        return selected_range(entry["tasks"], fixed, entry["range"], tasks)

    def implied(entry):
        return {name for name in names if not satisfiable_with_true(entry["tasks"], {name: False})}

    # Two entries for the same program and root must never apply in the same run: the value would
    # depend on the order of [Registry]
    for mode in modes:
        for index, first in enumerate(compat):
            for second in compat[index + 1:]:
                if (first["root"], first["components"]) != (second["root"], second["components"]):
                    continue
                if not (applies(first, mode) and applies(second, mode)):
                    continue
                both = ("and", first["tasks"], second["tasks"])
                if selected_range(both, unavailable(mode), intersect(first["range"], second["range"]), tasks):
                    raise CheckError(f"{MAIN_SCRIPT}:{first['line']} and {second['line']}: both "
                                     f"compatibility entries can write the value of the component "
                                     f"{first['components']} in {first['root']} in the same run "
                                     f"({mode} mode); their Tasks or Windows versions must exclude "
                                     "each other")

    rows = [(task, flags, lambda entry: True) for task, flags in flag_tasks]
    layers = []
    for entry in compat:
        if entry["layer"] and entry["layer"] not in layers:
            layers.append(entry["layer"])
    for layer in layers:
        group = [entry for entry in compat if entry["layer"] == layer]
        candidates = set.intersection(*(implied(entry) for entry in group))
        if len(candidates) > 1:
            candidates -= {task for task, _ in flag_tasks}
        if len(candidates) != 1:
            raise CheckError(f"{MAIN_SCRIPT}:{group[0]['line']}: cannot tell which task adds "
                             f"'{layer}' (every entry with it must require the same task)")
        rows.append((candidates.pop(), layer, lambda entry, layer=layer: entry["layer"] == layer))

    result = []
    for task, values, selects in rows:
        roots, versions = {}, []
        for mode in modes:
            if not available(task, mode):
                roots[mode] = "-"
                continue
            found = []
            for entry in compat:
                if selects(entry):
                    version = selection(entry, task, mode)
                    if version is not None:
                        found.append(entry["root"])
                        versions.append(version)
            roots[mode] = "+".join(sorted(set(found))) if found else "-"
        result.append({"task": task, "values": values, "version": union(versions), "roots": roots,
                       "task_range": tasks[task]["range"], "optin": tasks[task]["optin"],
                       "line": tasks[task]["line"]})
    return result


def check_compatibility(contract_lines, per_variant, errors):
    """per_variant: {(type, mode): rows of script_compatibility_rows}."""
    header, rows = first_table(contract_section(contract_lines, "3.7"), "3.7")
    root_column = next((column for column in header if column.startswith("Root")), None)
    require_columns(header, ["Task", "Values", "Windows versions"], "3.7")
    if root_column is None:
        raise CheckError(f"{CONTRACT}: the table of 3.7 has no column Root (admin/user/portable)")
    contract = []
    for no, row in rows:
        roots = [part.strip() for part in plain(row[root_column]).split("/")]
        if len(roots) != 3:
            errors.append(f"{CONTRACT}:{no} (3.7): root '{row[root_column]}' is not "
                          "'<admin> / <user> / <portable>'")
            continue
        version = " ".join(plain(row["Windows versions"]).split())
        optin = version.endswith(OPT_IN)
        if optin:
            version = version[:-len(OPT_IN)].strip()
        contract.append({"no": no, "task": plain(row["Task"]).lower(),
                         "values": " ".join(plain(row["Values"]).split()),
                         "version": version, "optin": optin, "roots": dict(zip(ALL_MODES, roots))})

    # Merge the variants: admin and user come from the Regular variants, portable from Portable;
    # the Windows versions of a row are those of the variants in which the task writes a value
    merged, first_variant = None, None
    for (install_type, install_mode), variant_rows in per_variant.items():
        variant = f"{install_type}/{install_mode}"
        if merged is None:
            first_variant = variant
            merged = [dict(row, version=None, roots={}) for row in variant_rows]
        if [(row["task"], row["values"]) for row in variant_rows] != [(row["task"], row["values"]) for row in merged]:
            errors.append(f"{MAIN_SCRIPT}: the compatibility values of {variant} differ from those of "
                          f"{first_variant}; contract 3.7 has one table for all variants")
            continue
        for row, variant_row in zip(merged, variant_rows):
            row["version"] = union([row["version"], variant_row["version"]])
            for mode, root in variant_row["roots"].items():
                if mode in row["roots"] and row["roots"][mode] != root:
                    errors.append(f"{MAIN_SCRIPT}: {row['task']}: root {root} in {variant}, "
                                  f"{row['roots'][mode]} in another variant of the mode {mode}")
                row["roots"][mode] = root

    for row in merged:
        if row["version"] is None:
            errors.append(f"{MAIN_SCRIPT}:{row['line']}: task {row['task']} writes no compatibility value")
        elif version_label(row["task_range"]) != version_label(row["version"]):
            errors.append(f"{MAIN_SCRIPT}:{row['line']}: task {row['task']} is offered on the Windows "
                          f"versions '{version_label(row['task_range'])}', but its compatibility value "
                          f"applies only on '{version_label(row['version'])}': give the task the "
                          "MinVersion/OnlyBelowVersion of its entries (contract 3.7: on other Windows "
                          "versions the setup neither shows nor selects the task)")
    script_order = [row["task"] for row in merged]
    contract_order = [row["task"] for row in contract]
    for task in sorted({task for task in script_order if script_order.count(task) > 1}):
        values = " and ".join(f"`{row['values']}`" for row in merged if row["task"] == task)
        errors.append(f"{MAIN_SCRIPT}: task {task} adds {values}; contract 3.7 has one row per task")
    if script_order != contract_order:
        if sorted(script_order) == sorted(contract_order):
            errors.append(f"{CONTRACT} (3.7): rows in the order {', '.join(contract_order)}, but the "
                          f"value lists them in the order {', '.join(script_order)} "
                          f"(BuildCompatibilityFlags, then the Windows compatibility mode)")
        else:
            missing = [task for task in script_order if task not in contract_order]
            extra = [task for task in contract_order if task not in script_order]
            if missing:
                errors.append(f"{CONTRACT} (3.7): no row for the task(s) {', '.join(missing)}, which "
                              f"add compatibility values in {MAIN_SCRIPT}")
            if extra:
                errors.append(f"{CONTRACT} (3.7): the task(s) {', '.join(extra)} add no compatibility "
                              f"value in {MAIN_SCRIPT}")
    script_by_task = {row["task"]: row for row in merged}
    for row in contract:
        script = script_by_task.get(row["task"])
        if script is None:
            continue
        where = f"{CONTRACT}:{row['no']} (3.7) {row['task']}"
        if row["values"] != script["values"]:
            errors.append(f"{where}: values `{row['values']}` in the contract, `{script['values']}` "
                          f"in {MAIN_SCRIPT} / {UTILS_SCRIPT}")
        if script["version"] is not None and row["version"] != version_label(script["version"]):
            errors.append(f"{where}: Windows versions '{row['version']}' in the contract, "
                          f"'{version_label(script['version'])}' in {MAIN_SCRIPT} (MinVersion and "
                          "OnlyBelowVersion of the task and its entries)")
        if row["optin"] != script["optin"]:
            errors.append(f"{where}: {'opt-in' if row['optin'] else 'selected by default'} in the "
                          f"contract ('{OPT_IN}' after the Windows versions), but the task "
                          f"{'is selected by default' if not script['optin'] else 'has Flags: unchecked'}"
                          f" in {MAIN_SCRIPT}")
        for mode in ALL_MODES:
            have = script["roots"].get(mode)
            if have is not None and row["roots"][mode] != have:
                errors.append(f"{where}: root in the {mode} mode {row['roots'][mode]} in the contract, "
                              f"{have} in {MAIN_SCRIPT}")
    return len(merged)


# ---------------------------------------------------------------------------------------------
# Rule 3.3: window size limits

# The rows of the table of 3.3 and the dimension of their constants (Min<...>/Max<...>)
WINDOW_LIMITS = {"Game Window Width": "GameWindowWidth", "Game Window Height": "GameWindowHeight"}


def script_window_limits(root):
    """{constant: (value, "file:line")} of MinGameWindowWidth ... MaxGameWindowHeight, each defined
    exactly once as '<name> = <number>;' in setup_is6.iss or a file of its #include lines (wherever
    a refactoring moves them)."""
    names = [bound + dimension for dimension in WINDOW_LIMITS.values() for bound in ("Min", "Max")]
    found = {name: [] for name in names}
    for rel in own_include_closure(root):
        for no, text in logical_lines(read_text(root / rel)):
            match = re.match(r"^\s*(\w+)\s*=\s*(\d+)\s*;", text)
            if match and match.group(1) in found:
                found[match.group(1)].append((int(match.group(2)), f"{rel.as_posix()}:{no}"))
    result = {}
    for name, places in found.items():
        if len(places) != 1:
            where = ", ".join(place for _, place in places) or "nowhere"
            raise CheckError(f"the constant {name} must be defined exactly once ('{name} = <number>;' in "
                             f"{MAIN_SCRIPT} or its #include files), found {len(places)} times: {where}")
        result[name] = places[0]
    return result


def check_window_limits(root, contract_lines, errors):
    header, rows = first_table(contract_section(contract_lines, "3.3"), "3.3")
    require_columns(header, ["Value", "Minimum", "Maximum"], "3.3")
    script = script_window_limits(root)
    seen = []
    for no, row in rows:
        name = plain(row["Value"])
        where = f"{CONTRACT}:{no} (3.3) {name}"
        if name not in WINDOW_LIMITS:
            errors.append(f"{where}: not a window size value (expected {', '.join(WINDOW_LIMITS)})")
            continue
        if name in seen:
            errors.append(f"{where}: listed twice")
            continue
        seen.append(name)
        for column, bound in (("Minimum", "Min"), ("Maximum", "Max")):
            constant = bound + WINDOW_LIMITS[name]
            value, place = script[constant]
            cell = plain(row[column])
            if not re.fullmatch(r"\d+", cell):
                errors.append(f"{where}: {column.lower()} '{row[column]}' is not a number")
            elif int(cell) != value:
                errors.append(f"{where}: {column.lower()} {cell} in the contract, {value} in {place} "
                              f"({constant})")
    for name in WINDOW_LIMITS:
        if name not in seen:
            errors.append(f"{CONTRACT} (3.3): no row {name} in the table of the window size limits")
    return len(seen)


# ---------------------------------------------------------------------------------------------
# Rule 3.4: GPU preference (uses the Windows version helpers of rule 3.7)

GPU_KEY = "software\\microsoft\\directx\\usergpupreferences"
APP_PREFIX = "{app}\\"
ROOT_PLACEHOLDER = "<root>\\"


def script_gpu_preferences(entries, tasks):
    """{value name with <root>: {"component", "data", "version", "task", "line"}} of the [Registry]
    entries below UserGpuPreferences of one variant; version: Windows versions of the entry and of
    its task."""
    result = {}
    for no, params in entries:
        key = params.get("subkey", "")
        if UNREADABLE in key:
            unreadable(no, params, "contract 3.4 (it may be a GPU preference)")
        if key.lower() != GPU_KEY:
            continue
        unreadable(no, params, "contract 3.4")
        where = f"{MAIN_SCRIPT}:{no}"
        if params.get("root", "").upper() != "HKCU":
            raise CheckError(f"{where}: a GPU preference outside HKCU (contract 3.4: Windows has it per user)")
        if params.get("valuetype", "").lower() != "string":
            raise CheckError(f"{where}: a GPU preference of ValueType '{params.get('valuetype', '')}', "
                             "contract 3.4 says REG_SZ")
        if "uninsdeletevalue" not in params.get("flags", "").lower().split():
            raise CheckError(f"{where}: a GPU preference without the flag uninsdeletevalue (contract 3.4: "
                             "the uninstaller removes it)")
        name = params.get("valuename", "")
        if not name.lower().startswith(APP_PREFIX):
            raise CheckError(f"{where}: GPU preference value name '{name}' is not a path below {{app}}")
        name = ROOT_PLACEHOLDER + name[len(APP_PREFIX):]
        if name in result:
            raise CheckError(f"{where}: two GPU preference entries for {name}")
        task = " ".join(params.get("tasks", "").split()).lower()
        version = version_range(params.get("minversion", ""), params.get("onlybelowversion", ""))
        if task in tasks:
            version = intersect(version, tasks[task]["range"])
        result[name] = {"component": params.get("components", "").strip().lower(),
                        "data": params.get("valuedata", ""), "task": task,
                        "version": version_label(version) if version else "none", "line": no}
    return result


def check_gpu_preferences(contract_lines, per_variant, errors):
    """per_variant: {(type, mode): script_gpu_preferences of that variant}."""
    header, rows = first_table(contract_section(contract_lines, "3.4"), "3.4")
    columns = ["Value name", "Component", "Data", "Windows versions", "Task"]
    require_columns(header, columns, "3.4")
    variants = list(per_variant.items())
    (first_type, first_mode), script = variants[0]
    for (install_type, install_mode), other in variants[1:]:
        if {name: {k: v for k, v in info.items() if k != "line"} for name, info in other.items()} != \
                {name: {k: v for k, v in info.items() if k != "line"} for name, info in script.items()}:
            errors.append(f"{MAIN_SCRIPT}: the GPU preference entries of {install_type}/{install_mode} differ "
                          f"from those of {first_type}/{first_mode}; contract 3.4 has one table for all variants")
    seen = []
    for no, row in rows:
        name = plain(row["Value name"])
        where = f"{CONTRACT}:{no} (3.4) {name}"
        if name in seen:
            errors.append(f"{where}: listed twice")
            continue
        seen.append(name)
        info = script.get(name)
        if info is None:
            errors.append(f"{where}: {MAIN_SCRIPT} writes no GPU preference for this program")
            continue
        script_where = f"{MAIN_SCRIPT}:{info['line']}"
        for column, key, contract_value in (
                ("Component", "component", plain(row["Component"]).lower()),
                ("Data", "data", plain(row["Data"])),
                ("Windows versions", "version", " ".join(plain(row["Windows versions"]).split())),
                ("Task", "task", " ".join(plain(row["Task"]).split()).lower())):
            if contract_value != info[key]:
                errors.append(f"{where}: {column.lower()} `{contract_value}` in the contract, "
                              f"`{info[key]}` in {script_where}")
    for name, info in script.items():
        if name not in seen:
            errors.append(f"{CONTRACT} (3.4): {name} is missing in the contract, {MAIN_SCRIPT}:{info['line']} "
                          "writes a GPU preference for it")
    return len(seen)


# ---------------------------------------------------------------------------------------------
# [Files] lint

def own_include_closure(root):
    """setup_is6.iss and every file named by an #include "..." line, recursively."""
    found, queue = [], [Path(MAIN_SCRIPT)]
    while queue:
        rel = queue.pop(0)
        if rel in found or not (root / rel).is_file():
            continue
        found.append(rel)
        for _, text in logical_lines(read_text(root / rel)):
            match = INCLUDE_LINE.match(text)
            if match:
                queue.append(Path(match.group(1).replace("\\", "/")))
    return found


def lint_files(root, errors):
    """Lints the [Files] entries as written in setup_is6.iss and its #include files; returns the
    number of entries below {app} and the number of those with AfterInstall: RecordInstalledFile."""
    counts = [lint_lines(rel.as_posix(), logical_lines(read_text(root / rel)), errors)
              for rel in own_include_closure(root)]
    return sum(c[0] for c in counts), sum(c[1] for c in counts)


def lint_lines(name, lines, errors):
    """Lints the [Files] entries among the logical lines; returns the number below {app} and the
    number of those that record their files."""
    checked, recording = 0, 0
    for no, text in lines:
        if not re.match(r"^\s*Source\s*:(?!=)", text):
            continue
        try:
            params = parse_params(text)
        except CheckError:
            continue
        if "destdir" not in params:
            continue  # dontcopy entries (no DestDir) or Pascal code
        where = f"{name}:{no}: [Files] Source \"{params.get('source', '')}\""
        destdir = params["destdir"].strip()
        if destdir.startswith("{#"):
            errors.append(f"{where}: DestDir '{destdir}' is computed by ISPP; write {{app}} (or "
                          "another constant) literally so that the flags can be checked")
            continue
        if not re.match(r"^\{app\}(\\|$)", destdir, re.I):
            continue
        checked += 1
        if "{#" in params.get("flags", ""):
            errors.append(f"{where}: Flags are computed by ISPP and cannot be checked")
            continue
        flags = params.get("flags", "").lower().split()
        if FILES_REQUIRED_FLAG not in flags:
            errors.append(f"{where}: DestDir {destdir} without the flag {FILES_REQUIRED_FLAG} "
                          "(contract 2.3: every [Files] entry below the install root has it)")
        for flag in FILES_FORBIDDEN_FLAGS:
            if flag in flags:
                errors.append(f"{where}: DestDir {destdir} with the flag {flag} (contract 2.3: "
                              "no entry below the install root may keep an existing file)")
        after_install = params.get("afterinstall", "").strip()
        if "external" in flags:
            left_out = ("an external entry (Inno Setup calls its AfterInstall once, with the folder; "
                        "installstate.iss adds the verified online files itself)")
        elif "deleteafterinstall" in flags:
            left_out = "a deleteafterinstall file (contract 2.3: not in the manifest)"
        elif SETUP_DATA_DIR.match(destdir):
            left_out = "the setup data folder (contract 2.3: not in the manifest)"
        else:
            left_out = None
        if left_out:
            if after_install.lower() == FILES_RECORD_PROC.lower():
                errors.append(f"{where}: DestDir {destdir} with AfterInstall: {FILES_RECORD_PROC}, but it is "
                              f"{left_out}")
        elif after_install.lower() != FILES_RECORD_PROC.lower():
            errors.append(f"{where}: DestDir {destdir} without AfterInstall: {FILES_RECORD_PROC} (ADR 0004 "
                          "point 3: every compiled entry below the install root records its files for the "
                          "manifest)" + (f", it has AfterInstall: {after_install}" if after_install else ""))
        else:
            recording += 1
    return checked, recording


def verified_files_entries(root):
    """{(source, destdir, components): "file:line"} of the [Files] entries whose Source is below
    {tmp}\\verified\\, as written in setup_is6.iss and its #include files (lowercase paths,
    components as a frozenset)."""
    entries = {}
    for rel in own_include_closure(root):
        for no, text in logical_lines(read_text(root / rel)):
            if not re.match(r"^\s*Source\s*:(?!=)", text):
                continue
            try:
                params = parse_params(text)
            except CheckError:
                continue
            source = params.get("source", "").strip()
            if not source.lower().startswith(VERIFIED_SOURCE):
                continue
            where = f"{rel.as_posix()}:{no}"
            if "external" not in params.get("flags", "").lower().split():
                raise CheckError(f"{where}: [Files] Source \"{source}\" below {{tmp}}\\verified without the flag external")
            components = params.get("components", "").strip()
            names = [name.strip() for name in re.split(r"\s+and\s+", components)] if components else []
            if not names or any(not re.fullmatch(r"[\w\\]+", name) for name in names):
                raise CheckError(f"{where}: [Files] Source \"{source}\": Components '{components}' is not a list "
                                 "of component names joined by 'and'")
            key = (source.lower(), params.get("destdir", "").strip().lower(), frozenset(n.lower() for n in names))
            entries[key] = where
    return entries


def verified_code_records(root):
    """{(source, destdir, components): "file:line"} of what RecordVerifiedOnlineFiles adds to the
    manifest (see the module documentation)."""
    for rel in own_include_closure(root):
        text = read_text(root / rel)
        match = re.search(r"^procedure\s+" + VERIFIED_RECORD_PROC + r"\s*;.*?^begin\s*$(.*?)^end;", text, re.M | re.S | re.I)
        if match:
            break
    else:
        raise CheckError(f"procedure {VERIFIED_RECORD_PROC} not found in setup_is6.iss or its #include files")
    body, first = match.group(1), text[:match.start(1)].count("\n") + 1
    where = f"{rel.as_posix()}:{first}"
    guard = {name.lower() for name in re.findall(
        r"if\s+not\s+WizardIsComponentSelected\('([^']+)'\)\s+then\s+Exit\s*;", body, re.I)}
    blocks = list(re.finditer(r"(?<!not )WizardIsComponentSelected\('([^']+)'\)\s+then", body, re.I))
    records = {}
    for index, block in enumerate(blocks):
        end = blocks[index + 1].start() if index + 1 < len(blocks) else len(body)
        part = body[block.end():end]
        components = frozenset(guard | {block.group(1).lower()})
        collect = r"CollectExternalFiles\(ExpandConstant\('([^']+)'\),\s*ExpandConstant\('([^']+)'\)"
        for folder, dest in re.findall(collect, part, re.I):
            records[((folder + "\\*").lower(), dest.lower(), components)] = where
        sources = re.findall(r"ExpandConstant\('(\{tmp\}\\verified\\[^']+)'\)", re.sub(collect, "", part, flags=re.I), re.I)
        targets = re.findall(r"InstalledFiles\.Add\(ExpandConstant\('([^']+)'\)\)", part, re.I)
        if len(sources) != len(targets):
            raise CheckError(f"{where}: {VERIFIED_RECORD_PROC}: {len(sources)} single files below {{tmp}}\\verified "
                             f"but {len(targets)} InstalledFiles.Add calls in the block of '{block.group(1)}'")
        for source, target in zip(sources, targets):
            folder, _, name = target.rpartition("\\")
            if name.lower() != source.rpartition("\\")[2].lower():
                raise CheckError(f"{where}: {VERIFIED_RECORD_PROC}: records {target} for {source}, another file name")
            records[(source.lower(), folder.lower(), components)] = where
    return records


def check_verified_online_files(root, errors):
    """The [Files] entries of {tmp}\\verified and RecordVerifiedOnlineFiles name the same files;
    returns the number of entries."""
    entries, records = verified_files_entries(root), verified_code_records(root)
    def show(key):
        return f"Source {key[0]}, DestDir {key[1]}, Components {' and '.join(sorted(key[2]))}"
    for key in sorted(set(entries) - set(records), key=str):
        errors.append(f"{entries[key]}: [Files] installs verified online files ({show(key)}) that "
                      f"{VERIFIED_RECORD_PROC} does not add to the manifest (contract 2.3) [2.3]")
    for key in sorted(set(records) - set(entries), key=str):
        errors.append(f"{records[key]}: {VERIFIED_RECORD_PROC} adds verified online files ({show(key)}) to the "
                      "manifest that no [Files] entry installs (contract 2.3) [2.3]")
    return len(entries)


# ---------------------------------------------------------------------------------------------
# Rules of the suite (contract 0 "Suite and launcher", 1.6, 1.7): suite/suite.iss

SUITE_SCRIPT = "suite/suite.iss"
SUITE_SKIPPED = f"{SUITE_SCRIPT} not present, suite rules skipped"
SUITE_NAMES_SECTION = "Suite and launcher"
# Rows of the table "Suite and launcher" (plain text of the column "Name")
SUITE_SETUP_MUTEX_ROW = "Suite setup mutex (SetupMutex)"
SUITE_LAUNCHER_MUTEX_ROW = "Launcher mutex"
SUITE_APP_MUTEX_ROW = "Suite AppMutex"
SUITE_LAUNCHER_ROW = "Launcher program"
SUITE_RECORD_KEY_ROW = "Suite record key"
SUITE_UNINSTALL_MARKER_ROW = "Suite uninstall key marker"
# The uninstall key of the suite itself, as written in the script (raw: the AppId of the suite is a define)
SUITE_UNINSTALL_MARKER_KEY = "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1"
SUITE_DEFINE = re.compile(r'^\s*#\s*define\s+([A-Za-z_]\w*)\s*(?:=\s*)?(?:"([^"]*)"|(\d+))\s*$')
SUITE_DEFINE_REF = re.compile(r"\{#\s*([A-Za-z_]\w*)\s*\}")
SUITE_RECORD_ROOTS = ("hklm", "hklm64")
# The suite writes its record and creates its shortcuts in code (ADR 0013 Evidence): one statement
# per line with literal arguments, as the checks below read them
SUITE_CODE_REG_WRITE = re.compile(
    r"^\s*RegWrite(String|DWord|ExpandString|MultiString|Binary)Value\s*\(\s*(\w+)\s*,\s*'((?:[^']|'')*)'\s*,\s*"
    r"'((?:[^']|'')*)'\s*,\s*(.*)\)\s*;\s*(?://.*)?$")
SUITE_CODE_REG_DELETE = re.compile(
    r"^\s*RegDelete(KeyIncludingSubkeys|KeyIfEmpty)\s*\(\s*(\w+)\s*,\s*'((?:[^']|'')*)'\s*\)\s*;")
SUITE_CODE_SHORTCUT = re.compile(r"^\s*SuiteShortcut\s*\((.*)\)\s*;\s*(?://.*)?$")
SUITE_CODE_REG_TYPES = {"string": "string", "dword": "dword", "expandstring": "expandsz",
                        "multistring": "multisz", "binary": "binary"}
SUITE_PROTECTED = re.compile(r"software\\+sierra|\bcdkeys\b|authtools", re.IGNORECASE)


def contract_named_section(lines, title):
    """[(line number, text)] of the section '#... <title>' of the contract (heading text compared
    exactly), up to the next heading of the same or a higher level."""
    result, inside, level = [], False, 0
    for no, text in enumerate(lines, 1):
        heading = re.match(r"^(#{1,6})\s+(.*?)\s*$", text)
        if heading:
            if inside and len(heading.group(1)) <= level:
                break
            if heading.group(2) == title:
                inside, level = True, len(heading.group(1))
                continue
        if inside:
            result.append((no, text))
    if not result:
        raise CheckError(f"{CONTRACT}: no section '{title}'")
    return result


def code_spans(cell):
    return re.findall(r"`([^`]+)`", cell)


def suite_include_closure(root):
    """suite/suite.iss and the files of the repository its #include "..." lines name, recursively
    (relative to the including file, else to the repository root)."""
    found, queue = [], [Path(SUITE_SCRIPT)]
    while queue:
        rel = queue.pop(0)
        if rel in found or not (root / rel).is_file():
            continue
        found.append(rel)
        for _, text in logical_lines(read_text(root / rel)):
            match = INCLUDE_LINE.match(text)
            if match:
                name = Path(match.group(1).replace("\\", "/"))
                beside = rel.parent / name
                queue.append(beside if (root / beside).is_file() else name)
    return found


def pascal_literals(text, where):
    """The comma separated string literals ('a', 'b''c') of a call as a list of plain strings; any
    other argument stops the check, so that nothing is guessed."""
    args, i, n = [], 0, len(text)
    while True:
        while i < n and text[i] in " \t":
            i += 1
        if i >= n or text[i] != "'":
            raise CheckError(f"{where}: cannot read the arguments of '{text.strip()}': this check reads "
                             "only string literals there")
        i += 1
        value = []
        while True:
            if i >= n:
                raise CheckError(f"{where}: cannot read the arguments of '{text.strip()}': a string is not closed")
            if text[i] == "'":
                if i + 1 < n and text[i + 1] == "'":
                    value.append("'")
                    i += 2
                    continue
                i += 1
                break
            value.append(text[i])
            i += 1
        args.append("".join(value))
        while i < n and text[i] in " \t":
            i += 1
        if i >= n:
            return args
        if text[i] != ",":
            raise CheckError(f"{where}: cannot read the arguments of '{text.strip()}': ',' expected")
        i += 1


class SuiteScript:
    """The [Setup], [Registry] and [Icons] lines of suite/suite.iss and its #include files, as
    written, and the plain #define lines (string or number) to expand {#Name}. #if blocks are not
    evaluated: every entry of every branch is checked."""

    def __init__(self, root):
        self.lines, self.defines = [], {}
        for rel in suite_include_closure(root):
            for no, text in logical_lines(read_text(root / rel)):
                where = f"{rel.as_posix()}:{no}"
                self.lines.append((where, text))
                match = SUITE_DEFINE.match(text)
                if match:
                    value = match.group(2) if match.group(2) is not None else match.group(3)
                    if self.defines.get(match.group(1), value) != value:
                        value = UNREADABLE
                    self.defines[match.group(1)] = value

    def expand(self, text, where):
        for _ in range(20):
            def value(match):
                name = match.group(1)
                found = self.defines.get(name)
                if found is None or found == UNREADABLE:
                    reason = "is defined with different values" if found == UNREADABLE else "has no plain #define"
                    raise CheckError(f"{where}: cannot read '{{#{name}}}' ({name} {reason} in {SUITE_SCRIPT} "
                                     "or its #include files; this check expands only plain string and "
                                     "number #defines)")
                return found
            expanded = SUITE_DEFINE_REF.sub(value, text)
            if expanded == text:
                break
            text = expanded
        if "{#" in text:
            raise CheckError(f"{where}: cannot read the ISPP expression in '{text}'")
        return text

    def section(self, name):
        """[(where, text)] of the entry lines of the section (no comments, no ISPP directives)."""
        result, inside = [], False
        for where, text in self.lines:
            stripped = text.strip()
            if re.fullmatch(r"\[[A-Za-z]+\]", stripped):
                inside = stripped[1:-1].lower() == name.lower()
                continue
            if inside and stripped and not stripped.startswith((";", "#", "//")):
                result.append((where, text))
        return result

    def directives(self, name):
        """[(where, expanded value)] of the [Setup] directive name (every occurrence)."""
        result = []
        for where, text in self.section("Setup"):
            key, sep, value = text.partition("=")
            if sep and key.strip().lower() == name.lower():
                result.append((where, self.expand(value.strip(), where)))
        return result

    def entries(self, name):
        return [(where, parse_params(text)) for where, text in self.section(name)]

    def code_lines(self):
        """[(where, text)] of the [Code] lines without comment lines and trailing // comments."""
        result = []
        for where, text in self.section("Code"):
            code = text.split("//", 1)[0] if text.lstrip().startswith("//") else text
            result.append((where, code))
        return result

    def code_registry_entries(self):
        """The registry values the code writes, as the entries of a [Registry] section (Root,
        Subkey, ValueName, ValueType, ValueData) that the record rules read."""
        result = []
        for where, text in self.code_lines():
            match = SUITE_CODE_REG_WRITE.match(text)
            if match:
                kind, root, key, name, data = match.groups()
                result.append((where, {"root": root, "subkey": key.replace("''", "'"),
                                       "valuename": name.replace("''", "'"),
                                       "valuetype": SUITE_CODE_REG_TYPES[kind.lower()],
                                       "valuedata": data.strip()}))
        return result

    def code_registry_deletes(self):
        """[(where, 'KeyIncludingSubkeys' or 'KeyIfEmpty', root, key)] of the keys the code deletes."""
        result = []
        for where, text in self.code_lines():
            match = SUITE_CODE_REG_DELETE.match(text)
            if match:
                result.append((where, match.group(1), match.group(2), match.group(3).replace("''", "'")))
        return result

    def code_shortcut_entries(self):
        """The SuiteShortcut calls of the code as ([Icons] entries, problems): one entry with the
        target and the parameters, and one more with the game program of the fallback."""
        entries, problems = [], []
        for where, text in self.code_lines():
            match = SUITE_CODE_SHORTCUT.match(text)
            if not match:
                continue
            args = pascal_literals(match.group(1), where)
            if len(args) != 6:
                raise CheckError(f"{where}: SuiteShortcut has {len(args)} arguments, this check reads six "
                                 "(place, name, target, parameters, product, fallback)")
            place, short, target, parameters, product, fallback = args
            name = f"{place}\\{short}"
            entries.append((where, {"name": name, "filename": target, "parameters": parameters}))
            if parameters.startswith("--product=") and parameters[len("--product="):] != product:
                problems.append(f"{where}: {name} passes {parameters} but names the product '{product}' "
                                "(contract 1.7) [suite 1.7]")
            if fallback:
                entries.append((where, {"name": name, "filename": "{code:ProductRoot|" + product + "}" + fallback}))
            elif parameters.startswith("--product="):
                problems.append(f"{where}: the game shortcut {name} has no fallback to the game program for a "
                                "computer without .NET Framework 4.8 (contract 1.7 point 8) [suite 1.7]")
        return entries, problems


def suite_names(contract_lines):
    """{row: [code values]} of the table 'Suite and launcher' of contract 0."""
    header, rows = first_table(contract_named_section(contract_lines, SUITE_NAMES_SECTION),
                               SUITE_NAMES_SECTION)
    require_columns(header, ["Name", "Value"], SUITE_NAMES_SECTION)
    names = {plain(row["Name"]): code_spans(row["Value"]) for _, row in rows}
    for row in (SUITE_SETUP_MUTEX_ROW, SUITE_LAUNCHER_MUTEX_ROW, SUITE_APP_MUTEX_ROW, SUITE_LAUNCHER_ROW,
                SUITE_RECORD_KEY_ROW, SUITE_UNINSTALL_MARKER_ROW):
        if not names.get(row):
            raise CheckError(f"{CONTRACT}: the table of '{SUITE_NAMES_SECTION}' has no row '{row}' with a "
                             "value in backticks")
    return names


def mutex_list(value):
    return [name.strip() for name in value.split(",") if name.strip()]


def check_suite_mutexes(script, names, errors):
    """[Setup] SetupMutex names the suite setup mutex; AppMutex names the launcher mutex and every
    name of the row 'Suite AppMutex'. Returns the number of names checked."""
    expected = {"SetupMutex": names[SUITE_SETUP_MUTEX_ROW],
                "AppMutex": list(dict.fromkeys(names[SUITE_LAUNCHER_MUTEX_ROW] + names[SUITE_APP_MUTEX_ROW]))}
    for directive, wanted in expected.items():
        found = script.directives(directive)
        if not found:
            errors.append(f"{SUITE_SCRIPT}: [Setup] has no {directive}; contract 0 '{SUITE_NAMES_SECTION}' "
                          f"needs {', '.join(wanted)} [suite 0]")
        for where, value in found:
            missing = [name for name in wanted if name not in mutex_list(value)]
            if missing:
                errors.append(f"{where}: {directive}={value} does not name {', '.join(missing)} "
                              f"(contract 0 '{SUITE_NAMES_SECTION}') [suite 0]")
    return sum(len(wanted) for wanted in expected.values())


def check_suite_record(script, contract_lines, names, version, errors):
    """The [Registry] entries of the suite record key: Root HKLM in 64-bit install mode or HKLM64,
    exactly the value names of the table of contract 1.6 with their types, uninsdeletekey, and a
    plain ContractVersion equal to the contract version. Returns the number of value names."""
    header, rows = first_table(contract_section(contract_lines, "1.6"), "1.6")
    require_columns(header, ["Value", "Type"], "1.6")
    table = {}
    for no, row in rows:
        value_names = code_spans(row["Value"])
        if len(value_names) != 1:
            raise CheckError(f"{CONTRACT}:{no}: the column Value of 1.6 must hold one name in backticks")
        table[value_names[0].lower()] = (value_names[0], plain(row["Type"]))
    key = names[SUITE_RECORD_KEY_ROW][0].strip("\\").lower()
    entries = [(where, params) for where, params in script.entries("Registry") + script.code_registry_entries()
               if script.expand(params.get("subkey", ""), where).strip("\\").lower() == key]
    if not entries:
        errors.append(f"{SUITE_SCRIPT}: [Registry] has no entry for the suite record key "
                      f"{names[SUITE_RECORD_KEY_ROW][0]} (contract 1.6) [suite 1.6]")
        return len(table)
    in_64_bit_mode = any(value for _, value in script.directives("ArchitecturesInstallIn64BitMode"))
    found = {}
    for where, params in entries:
        root = params.get("root", "").strip().lower()
        if root not in SUITE_RECORD_ROOTS:
            errors.append(f"{where}: the suite record has Root {params.get('root', '(none)')}; contract 1.6 "
                          "needs HKLM in the 64-bit view (HKLM64, or HKLM in 64-bit install mode) [suite 1.6]")
        elif root == "hklm" and not in_64_bit_mode:
            errors.append(f"{where}: the suite record has Root HKLM, but [Setup] has no "
                          "ArchitecturesInstallIn64BitMode, so it lands in the 32-bit view (contract 1.6) "
                          "[suite 1.6]")
        name = params.get("valuename")
        if name is None:
            continue
        name = script.expand(name, where)
        value_type = REG_TYPES.get(params.get("valuetype", "").strip().lower(), params.get("valuetype", ""))
        found.setdefault(name.lower(), []).append((where, name, value_type, params))
    # removed on uninstall: the flag uninsdeletekey, or the code of the uninstaller deletes the key and,
    # if empty, the key above it (what the flag uninsdeletekeyifempty does for the parent)
    deletes = [(kind, root.lower(), script.expand(deleted, where).strip("\\").lower())
               for where, kind, root, deleted in script.code_registry_deletes()]
    parent = key.rpartition("\\")[0]
    by_flag = any("uninsdeletekey" in params.get("flags", "").lower().split() for _, params in entries)
    by_code = (("KeyIncludingSubkeys", "hklm", key) in deletes or ("KeyIncludingSubkeys", "hklm64", key) in deletes)
    if not by_flag and not by_code:
        errors.append(f"{SUITE_SCRIPT}: no [Registry] entry of the suite record key has the flag uninsdeletekey "
                      f"and the code has no RegDeleteKeyIncludingSubkeys(HKLM, '{names[SUITE_RECORD_KEY_ROW][0]}') "
                      "(contract 1.6) [suite 1.6]")
    elif not by_flag and not (("KeyIfEmpty", "hklm", parent) in deletes or ("KeyIfEmpty", "hklm64", parent) in deletes):
        errors.append(f"{SUITE_SCRIPT}: the code removes the suite record key but has no "
                      f"RegDeleteKeyIfEmpty(HKLM, '{names[SUITE_RECORD_KEY_ROW][0].rpartition(chr(92))[0]}') for the key "
                      "above it (contract 1.6, uninsdeletekeyifempty) [suite 1.6]")
    for lower, (name, value_type) in table.items():
        if lower not in found:
            errors.append(f"{SUITE_SCRIPT}: the suite record has no value {name} (table of contract 1.6) "
                          "[suite 1.6]")
            continue
        for where, written, script_type, params in found[lower]:
            if written != name:
                errors.append(f"{where}: value name {written}, the contract writes {name} [suite 1.6]")
            if script_type != value_type:
                errors.append(f"{where}: {name} is {script_type or '(no ValueType)'}, contract 1.6 {value_type} "
                              "[suite 1.6]")
            if lower == "contractversion" and version is not None:
                data = script.expand(params.get("valuedata", ""), where).strip()
                if data.isdigit() and int(data) != version:
                    errors.append(f"{where}: ContractVersion {data}, but the contract version is {version} "
                                  "[suite 1.6]")
    for lower in sorted(set(found) - set(table)):
        where, name = found[lower][0][0], found[lower][0][1]
        errors.append(f"{where}: the suite record value {name} is not in the table of contract 1.6 "
                      "(add it there first, in both repositories) [suite 1.6]")
    return len(table)


def check_suite_uninstall_marker(script, names, errors):
    """The suite marks its own uninstall key (contract 0 row 'Suite uninstall key marker', 1.3, 1.4 source 3,
    revision 5): exactly one write of that value name, Root HKLM (the 64-bit view in the 64-bit install mode;
    HKLM64 is not used by the suite), REG_DWORD, the data of the row, into {<suite AppId>}_is1 and never into
    the key of a product. Returns the number of checked writes (1)."""
    values = names[SUITE_UNINSTALL_MARKER_ROW]
    if len(values) != 2 or not values[1].isdigit():
        raise CheckError(f"{CONTRACT}: the row '{SUITE_UNINSTALL_MARKER_ROW}' of '{SUITE_NAMES_SECTION}' must "
                         "hold the value name and the data, both in backticks")
    name, data = values
    entries = [(where, params) for where, params in script.entries("Registry") + script.code_registry_entries()
               if params.get("valuename", "").strip().lower() == name.lower()]
    if not entries:
        errors.append(f"{SUITE_SCRIPT}: the suite does not write the value {name} into its uninstall key "
                      f"(row '{SUITE_UNINSTALL_MARKER_ROW}' of contract 0) [suite 1.3]")
        return 0
    if len(entries) > 1:
        errors.append(f"{entries[1][0]}: the value {name} is written more than once "
                      f"(first at {entries[0][0]}) [suite 1.3]")
    for where, params in entries:
        written = params.get("valuename", "").strip()
        root = params.get("root", "").strip().lower()
        value_type = params.get("valuetype", "").strip().lower()
        key = params.get("subkey", "").strip().strip('"').strip("\\").lower()
        if written != name:
            errors.append(f"{where}: value name {written}, the contract writes {name} [suite 1.3]")
        if root != "hklm":
            errors.append(f"{where}: {name} is written to Root {params.get('root', '(none)')}; the uninstall key "
                          "of the suite is in HKLM, which is the 64-bit view in its 64-bit install mode; "
                          "the suite does not use HKLM64 [suite 1.3]")
        if value_type != "dword":
            errors.append(f"{where}: {name} is {REG_TYPES.get(value_type, value_type) or '(no ValueType)'}, "
                          "contract 0 REG_DWORD [suite 1.3]")
        if params.get("valuedata", "").strip().strip('"') != data:
            errors.append(f"{where}: {name} has the data {params.get('valuedata', '(none)')}, contract 0 {data} "
                          "[suite 1.3]")
        if key != SUITE_UNINSTALL_MARKER_KEY.lower():
            errors.append(f"{where}: {name} is written to {params.get('subkey', '(none)')}, not to the uninstall "
                          f"key of the suite ({SUITE_UNINSTALL_MARKER_KEY}); the uninstall keys of the products "
                          "never get it [suite 1.3]")
    return len(entries)


def check_suite_shortcuts(script, contract_lines, names, errors):
    """[Icons]: per row of the table of contract 1.7 and per place, an entry <place>\\<shortcut>
    that starts the launcher with the row's parameters; every entry of a game shortcut name starts
    the launcher with exactly those parameters or, without them, the game program of the row's
    fallback; every entry that passes --product= starts the launcher. {group} is DefaultGroupName
    below {autoprograms}. Returns the number of game shortcuts checked."""
    header, rows = first_table(contract_section(contract_lines, "1.7"), "1.7")
    columns = ["Shortcut", "Product", "Places", "Target", "Parameters", "Without .NET Framework 4.8"]
    require_columns(header, columns, "1.7")
    launcher = names[SUITE_LAUNCHER_ROW][0]
    shortcuts = {}
    for no, row in rows:
        values = {column: code_spans(row[column]) for column in columns}
        if any(len(values[column]) != 1 for column in columns if column != "Places") or not values["Places"]:
            raise CheckError(f"{CONTRACT}:{no}: a row of the table of 1.7 needs one value in backticks per "
                             "column (Places: one or more)")
        target, parameters = values["Target"][0], values["Parameters"][0]
        if target.lower() != launcher.lower() or parameters != f"--product={values['Product'][0]}":
            raise CheckError(f"{CONTRACT}:{no}: the game shortcut must start {launcher} with "
                             f"--product={values['Product'][0]}")
        fallback = values["Without .NET Framework 4.8"][0]
        if not fallback.startswith("<product root>\\"):
            raise CheckError(f"{CONTRACT}:{no}: the column 'Without .NET Framework 4.8' must start with "
                             "<product root>\\")
        shortcuts[values["Shortcut"][0].lower()] = (values["Shortcut"][0], values["Places"], parameters,
                                                    fallback[len("<product root>"):])
    groups = script.directives("DefaultGroupName")
    group = groups[0][1] if groups else None

    def place_and_name(where, params):
        name = script.expand(params.get("name", ""), where)
        if name.lower().startswith("{group}\\") and group is not None:
            name = "{autoprograms}\\" + group + name[len("{group}"):]
        place, _, short = name.rpartition("\\")
        return place, short

    icons = []
    code_entries, code_problems = script.code_shortcut_entries()
    errors.extend(code_problems)
    for where, params in script.entries("Icons") + code_entries:
        place, short = place_and_name(where, params)
        icons.append((where, place, short, script.expand(params.get("filename", ""), where),
                      script.expand(params.get("parameters", ""), where).strip()))
    for where, place, short, filename, parameters in icons:
        row = shortcuts.get(short.lower())
        if "--product=" in parameters and filename.lower() != launcher.lower():
            errors.append(f"{where}: {place}\\{short} passes {parameters} but starts {filename}, not the launcher "
                          f"{launcher} (contract 1.7) [suite 1.7]")
            continue
        if row is None:
            if "--product=" in parameters:
                errors.append(f"{where}: {place}\\{short} starts the launcher with {parameters}, but "
                              f"{short} is no game shortcut of the table of contract 1.7 [suite 1.7]")
            continue
        name, _, wanted, fallback = row
        if filename.lower() == launcher.lower():
            if parameters != wanted:
                errors.append(f"{where}: {place}\\{short} starts the launcher with '{parameters}' instead of "
                              f"{wanted} (contract 1.7) [suite 1.7]")
        elif not filename.lower().endswith(fallback.lower()) or parameters:
            errors.append(f"{where}: the game shortcut {place}\\{short} starts {filename} {parameters}".rstrip()
                          + f"; contract 1.7 allows the launcher {launcher} {wanted} or, without .NET "
                          f"Framework 4.8, <product root>{fallback} without parameters [suite 1.7]")
    count = 0
    for name, places, wanted, _ in shortcuts.values():
        for place in places:
            count += 1
            if not any(p.lower() == place.lower() and s.lower() == name.lower() and f.lower() == launcher.lower()
                       and a == wanted for _, p, s, f, a in icons):
                errors.append(f"{SUITE_SCRIPT}: no [Icons] entry {place}\\{name} that starts the launcher "
                              f"{launcher} with {wanted} (contract 1.7) [suite 1.7]")
    return count


def check_suite_protected(script, errors):
    """No code line of the suite (comments left out) names the protected keys of contract 3.8 or the
    CD key registration (authtools.dll): it stays the NeoEE setup's own (ADR 0013, contract 1.7
    point 5). Returns the number of lines read."""
    count = 0
    for where, text in script.lines:
        stripped = text.strip()
        if not stripped or stripped.startswith(";"):
            continue
        code = "" if stripped.startswith("//") else text.split("//", 1)[0]
        count += 1
        if SUITE_PROTECTED.search(code):
            errors.append(f"{where}: the suite names a protected key or the CD key registration "
                          f"('{stripped}'); only the NeoEE setup registers the CD keys (contract 3.8, 1.7) [suite 3.8]")
    return count


def check_suite(root, contract_lines, version, errors):
    """The suite rules; a summary text. Skipped (no error) while suite/suite.iss does not exist."""
    if not (root / SUITE_SCRIPT).is_file():
        return SUITE_SKIPPED
    script = SuiteScript(root)
    names = suite_names(contract_lines)
    mutexes = check_suite_mutexes(script, names, errors)
    values = check_suite_record(script, contract_lines, names, version, errors)
    shortcuts = check_suite_shortcuts(script, contract_lines, names, errors)
    check_suite_uninstall_marker(script, names, errors)
    lines = check_suite_protected(script, errors)
    return (f"suite: SetupMutex and AppMutex ({mutexes} names), record with {values} values, "
            f"{shortcuts} game shortcuts to the launcher, the uninstall key marker, no protected key in "
            f"{lines} code lines")


# ---------------------------------------------------------------------------------------------

def check(root):
    """(errors, summary) for the repository root."""
    errors = []
    contract_path = root / CONTRACT
    for path in (contract_path, root / MAIN_SCRIPT, root / UTILS_SCRIPT):
        if not path.is_file():
            return [f"{path}: file not found"], ""
    contract_lines = contract_path.read_text(encoding="utf-8-sig").splitlines()
    summary = []

    def rule(name, function):
        try:
            return function()
        except CheckError as error:
            errors.append(f"{error} [{name}]")
            return None

    version = rule("header", lambda: check_contract_version(root, contract_lines, errors))
    summary.append(f"contract version {version}")
    count = rule("0", lambda: check_publishers(root, contract_lines, errors))
    summary.append(f"0: {count} publishers")
    count = rule("2.4", lambda: check_code_extensions(root, contract_lines, errors))
    summary.append(f"2.4: {count} code extensions")

    variant_errors = {}
    game_counts, compat_rows, gpu_rows = set(), {}, {}
    flag_tasks = rule("3.7", lambda: compatibility_flag_tasks(root))
    tasks = rule("3.4, 3.7", lambda: script_tasks(root))
    for install_type, install_mode in VARIANTS:
        variant = f"{install_type}/{install_mode}"
        try:
            entries, defines = registry_entries(root, install_type, install_mode)
        except CheckError as error:
            variant_errors.setdefault(f"{error} [3.2, 3.7]", []).append(variant)
            continue
        local = []
        try:
            settings = script_game_settings(entries, defines)
            game_counts.add(check_game_settings(contract_lines, settings, local))
        except CheckError as error:
            local.append(f"{error} [3.2]")
        if tasks is not None:
            try:
                gpu_rows[(install_type, install_mode)] = script_gpu_preferences(entries, tasks)
            except CheckError as error:
                local.append(f"{error} [3.4]")
        if flag_tasks is not None and tasks is not None:
            try:
                compat_rows[(install_type, install_mode)] = script_compatibility_rows(
                    entries, flag_tasks, tasks, MODES[install_mode])
            except CheckError as error:
                local.append(f"{error} [3.7]")
        for message in local:
            variant_errors.setdefault(message, []).append(variant)
    all_variants = [f"{t}/{m}" for t, m in VARIANTS]
    for message, variants in variant_errors.items():
        errors.append(message if variants == all_variants else f"{message} (variant {', '.join(variants)})")
    summary.append(f"3.2: {'/'.join(str(c) for c in sorted(game_counts if game_counts else {0}))} values "
                   f"of both games in {len(VARIANTS)} variants")
    count = rule("3.3", lambda: check_window_limits(root, contract_lines, errors))
    summary.append(f"3.3: {count} window size limits")
    if gpu_rows and len(gpu_rows) == len(VARIANTS):
        count = rule("3.4", lambda: check_gpu_preferences(contract_lines, gpu_rows, errors))
        summary.append(f"3.4: {count} GPU preference values")
    if compat_rows and len(compat_rows) == len(VARIANTS):
        count = rule("3.7", lambda: check_compatibility(contract_lines, compat_rows, errors))
        summary.append(f"3.7: {count} rows")
    count, recording = lint_files(root, errors)
    summary.append(f"[Files]: {count} entries below {{app}} with {FILES_REQUIRED_FLAG} and without "
                   f"{', '.join(FILES_FORBIDDEN_FLAGS)}, {recording} of them with AfterInstall: "
                   f"{FILES_RECORD_PROC}")
    count = rule("2.3", lambda: check_verified_online_files(root, errors))
    summary.append(f"2.3: {count} [Files] entries of verified online files, the same in {VERIFIED_RECORD_PROC}")
    suite = rule("suite", lambda: check_suite(root, contract_lines, version, errors))
    summary.append(suite if suite is not None else "suite: not checked")
    return errors, "; ".join(summary)


def check_preprocessed(root, folder):
    """Compares the [Registry] entries of this check's ISPP interpreter with the scripts that ISCC
    preprocessed (ci/build.ps1 -KeepPreprocessed <folder>: <Type>_<Mode>.iss), and lints the fully
    expanded [Files] sections of those scripts. Returns the errors."""
    errors = []
    for install_type, install_mode in VARIANTS:
        path = Path(folder) / f"{install_type}_{install_mode}.iss"
        if not path.is_file():
            errors.append(f"{path}: preprocessed script not found (ci/build.ps1 -KeepPreprocessed)")
            continue
        lines = logical_lines(path.read_text(encoding="utf-8-sig", errors="replace"))
        real = [parse_params(text) for _, text in section(lines, "Registry")
                if text.strip() and not text.strip().startswith(";")]
        # SetupBuild as ISCC got it: the data of the install record's value SetupBuild, if any
        builds = [params.get("valuedata", "") for params in real
                  if params.get("valuename", "") == SETUP_BUILD
                  and INSTALL_RECORD_KEY in params.get("subkey", "").lower()]
        switches = {SETUP_BUILD: builds[0] if builds else ""}
        try:
            mine = [params for _, params in registry_entries(root, install_type, install_mode, switches)[0]]
        except CheckError as error:
            errors.append(f"{install_type}/{install_mode}: {error}")
            continue

        def normalized(entries):
            return [sorted((key, value.strip()) for key, value in params.items()) for params in entries]

        real_entries, my_entries = normalized(real), normalized(mine)
        if real_entries != my_entries:
            index = next((i for i, (a, b) in enumerate(zip(real_entries, my_entries)) if a != b),
                         min(len(real_entries), len(my_entries)))
            errors.append(f"{path.name}: [Registry] of ISCC ({len(real_entries)} entries) and of this "
                          f"check ({len(my_entries)} entries) differ at entry {index + 1}:\n"
                          f"  ISCC:  {real_entries[index] if index < len(real_entries) else '-'}\n"
                          f"  check: {my_entries[index] if index < len(my_entries) else '-'}")
        lint_lines(path.name, section(lines, "Files"), errors)
    return errors


def main(argv):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")  # the messages quote the contract
    if "--self-test" in argv:
        return self_test(Path(__file__).resolve().parent.parent)
    if "--preprocessed" in argv:
        index = argv.index("--preprocessed")
        if index + 1 >= len(argv):
            print("usage: check_contract.py --preprocessed <folder of ci/build.ps1 -KeepPreprocessed> [repo_dir]")
            return 1
        folder = argv[index + 1]
        rest = argv[:index] + argv[index + 2:]
        root = Path(rest[0]) if rest else Path(__file__).resolve().parent.parent
        errors = check_preprocessed(root, folder)
        for error in errors:
            print(error)
        if errors:
            print(f"{len(errors)} problem(s) found in the preprocessed scripts of {folder}")
            return 1
        print(f"The preprocessed scripts of {folder}: [Registry] of all {len(VARIANTS)} variants is what "
              "this check reads, every [Files] entry below {app} passes the lint")
        return 0
    args = [arg for arg in argv if not arg.startswith("--")]
    root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
    errors, summary = check(root)
    for error in errors:
        print(error)
    if errors:
        print(f"{len(errors)} problem(s) found: change docs/CONTRACT.md (in both repositories, see "
              "its section 5) or the script so that they match")
        return 1
    print(f"docs/CONTRACT.md matches the script: {summary}")
    return 0


# ---------------------------------------------------------------------------------------------
# Self-test

def self_test(source_root):
    """Runs check() against temporary copies of the repository: the unmodified copy and the
    copies in "passing" must pass, every copy in "cases" must fail with the expected text."""
    def replace(rel, old, new, count=1):
        """Replaces old by new in the file; line ends in old and new may be written as "\n" or
        "\r\n" and are converted to those of the file (the checkout may have either)."""
        def apply(root):
            path = root / rel
            text = path.read_bytes().decode("utf-8")
            newline = "\r\n" if "\r\n" in text else "\n"
            old_text, new_text = (value.replace("\r\n", "\n").replace("\n", newline) for value in (old, new))
            found = text.count(old_text)
            if found != count:
                raise AssertionError(f"self-test modification: '{old}' found {found} times in {rel}, "
                                     f"expected {count}")
            path.write_bytes(text.replace(old_text, new_text).encode("utf-8"))
        return apply

    def both(*steps):
        return lambda root: [step(root) for step in steps]

    def write(rel, text):
        """Writes the file as the own .iss files are kept (UTF-8 with BOM, CRLF)."""
        def apply(root):
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"\xef\xbb\xbf" + text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))
        return apply

    def remove(rel):
        def apply(root):
            if (root / rel).exists():
                (root / rel).unlink()
        return apply

    suite = SUITE_SCRIPT
    # A minimal suite script as contract 0, 1.6 and 1.7 describe it (WP3 writes the real one).
    SUITE_FIXTURE = r"""; self-test fixture of ci/check_contract.py
#define SuiteName "Empire Earth Community"
#define LauncherExe "Empire Earth Launcher.exe"
#define SuiteKey "Software\Empire Earth Community\Suite"
#define SuiteAppID ""
#define ContractVersion 1

[Setup]
AppName={#SuiteName}
ArchitecturesInstallIn64BitMode=x64 arm64
DefaultGroupName={#SuiteName}
SetupMutex=EmpireEarthCommunity_Suite
AppMutex=StainlessSteelStudiosPresentsEmpireEarth,MadDocSoftwarePresentsEmpireEarthExpansion,EmpireEarthCommunityLauncher

[Registry]
Root: HKLM; Subkey: "Software\Empire Earth Community"; Flags: uninsdeletekeyifempty
Root: HKLM; Subkey: "{#SuiteKey}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: dword; ValueName: "ContractVersion"; ValueData: "{#ContractVersion}"
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "SuiteVersion"; ValueData: "1.0.0"
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "Products"; ValueData: "{code:SuiteProducts}"
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "SourceDir"; ValueData: "{src}"
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "EEAppId"; ValueData: "{code:EEAppId}"
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "NeoEEAppId"; ValueData: "{code:NeoEEAppId}"
Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "Written"; ValueData: "{code:WrittenTime}"
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#SuiteAppID}}_is1"; ValueType: dword; ValueName: "Empire Earth Community: Suite"; ValueData: "1"

[Icons]
Name: "{autodesktop}\Empire Earth"; Filename: "{app}\{#LauncherExe}"; Parameters: "--product=EE"; WorkingDir: "{app}"; Check: ProductOk('EE') and IsDotNet48
Name: "{group}\Empire Earth"; Filename: "{app}\{#LauncherExe}"; Parameters: "--product=EE"; WorkingDir: "{app}"; Check: ProductOk('EE') and IsDotNet48
Name: "{autodesktop}\Neo Empire Earth"; Filename: "{app}\{#LauncherExe}"; Parameters: "--product=NeoEE"; WorkingDir: "{app}"; Check: ProductOk('NeoEE') and IsDotNet48
Name: "{autoprograms}\Empire Earth Community\Neo Empire Earth"; Filename: "{app}\{#LauncherExe}"; Parameters: "--product=NeoEE"; WorkingDir: "{app}"; Check: ProductOk('NeoEE') and IsDotNet48
Name: "{autodesktop}\Empire Earth"; Filename: "{code:ProductRoot|EE}\Empire Earth\Empire Earth.exe"; Check: ProductOk('EE') and not IsDotNet48
Name: "{group}\Empire Earth Launcher"; Filename: "{app}\{#LauncherExe}"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#SuiteName}}"; Filename: "{uninstallexe}"
"""
    fixture = write(suite, SUITE_FIXTURE)
    # The same suite as the script of WP3 writes it: the record and the shortcuts in code
    SUITE_CODE_FIXTURE = r"""; self-test fixture of ci/check_contract.py: record and shortcuts in code
#define SuiteName "Empire Earth Community"
#define LauncherExe "Empire Earth Launcher.exe"
#define SuiteKey "Software\Empire Earth Community\Suite"
#define SuiteAppID ""
#define EE_AppID ""
#define ContractVersion 1

[Setup]
AppName={#SuiteName}
ArchitecturesInstallIn64BitMode=x64 arm64
SetupMutex=EmpireEarthCommunity_Suite
AppMutex=StainlessSteelStudiosPresentsEmpireEarth,MadDocSoftwarePresentsEmpireEarthExpansion,EmpireEarthCommunityLauncher

[Code]
procedure WriteSuiteRecord;
begin
  RegWriteDWordValue(HKLM, '{#SuiteKey}', 'ContractVersion', {#ContractVersion});
  RegWriteStringValue(HKLM, '{#SuiteKey}', 'SuiteVersion', '1.0.0');
  RegWriteStringValue(HKLM, '{#SuiteKey}', 'InstallPath', RemoveBackslash(ExpandConstant('{app}')));
  RegWriteStringValue(HKLM, '{#SuiteKey}', 'Products', 'EE');
  RegWriteStringValue(HKLM, '{#SuiteKey}', 'SourceDir', RemoveBackslash(ExpandConstant('{src}')));
  RegWriteStringValue(HKLM, '{#SuiteKey}', 'EEAppId', 'x');
  RegWriteStringValue(HKLM, '{#SuiteKey}', 'NeoEEAppId', 'y');
  RegWriteStringValue(HKLM, '{#SuiteKey}', 'Written', GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')); // the time
end;

procedure RemoveSuiteRecord;
begin
  RegDeleteKeyIncludingSubkeys(HKLM, '{#SuiteKey}');
  RegDeleteKeyIfEmpty(HKLM, 'Software\Empire Earth Community');
end;

procedure MarkSuiteUninstallKey;
begin
  if not RegKeyExists(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#SuiteAppID}}_is1') then
    Exit;
  RegWriteDWordValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#SuiteAppID}}_is1', 'Empire Earth Community: Suite', 1);
end;

// SuiteShortcut('{autodesktop}', 'Nothing', 'in a comment', '--product=EE', 'EE', '');
procedure ApplySuiteShortcuts(Remove: Boolean);
begin
  SuiteShortcut('{autodesktop}', 'Empire Earth', '{app}\{#LauncherExe}', '--product=EE', 'EE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Empire Earth', '{app}\{#LauncherExe}', '--product=EE', 'EE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autodesktop}', 'Neo Empire Earth', '{app}\{#LauncherExe}', '--product=NeoEE', 'NeoEE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Neo Empire Earth', '{app}\{#LauncherExe}', '--product=NeoEE', 'NeoEE', '\Empire Earth\Empire Earth.exe');
  SuiteShortcut('{autoprograms}\Empire Earth Community', 'Empire Earth Launcher', '{app}\{#LauncherExe}', '', '', '');
end;
"""
    code_fixture = write(suite, SUITE_CODE_FIXTURE)

    def code_case(old, new):
        return both(code_fixture, replace(suite, old, new))

    def suite_case(old, new):
        return both(fixture, replace(suite, old, new))

    crlf = "\r\n"
    contract, main_script, utils = CONTRACT, MAIN_SCRIPT, UTILS_SCRIPT
    LEGACY_ROW = ("| `compatibility_legacy` | `DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` "
                  "| 7 only (opt-in) | HKLM / HKCU / HKCU |")
    cases = [
        # header
        ("ContractVersion 1 -> 2 in setup_is6.iss",
         replace(main_script, "#define ContractVersion 1", "#define ContractVersion 2"),
         "contract version 1, but setup_is6.iss"),
        ("ContractVersion missing", replace(main_script, "#define ContractVersion 1" + crlf, ""),
         "expected exactly one '#define ContractVersion <number>'"),
        ("contract version 1 -> 2 in the header", replace(contract, "| Contract version | **1** |",
                                                          "| Contract version | **2** |"),
         "contract version 2, but"),
        # 0, Products: publishers
        ("publisher of NeoEE changed in config_neoee.iss",
         replace("config_neoee.iss", '#define MyAppPublisher "Empire Earth Community & NeoEE"',
                 '#define MyAppPublisher "NeoEE Community"'),
         "NeoEE: publisher 'Empire Earth Community & NeoEE' in the contract, 'NeoEE Community' in config_neoee.iss"),
        ("publisher of EE changed in utils.iss",
         replace(utils, "CommunityPublisherEE = 'Empire Earth Community';", "CommunityPublisherEE = 'Empire Earth community';"),
         "EE: publisher 'Empire Earth Community' in the contract, 'Empire Earth community' in utils.iss"),
        ("publisher of EE changed in the contract",
         replace(contract, "| `Publisher` in the uninstall key | `Empire Earth Community` |",
                 "| `Publisher` in the uninstall key | `EE Community` |"),
         "EE: publisher 'EE Community' in the contract, 'Empire Earth Community' in config_ee.iss"),
        ("CommunityPublisherNeoEE missing in utils.iss",
         replace(utils, "  CommunityPublisherNeoEE = 'Empire Earth Community & NeoEE';\r\n", ""),
         "expected exactly one constant 'CommunityPublisherNeoEE"),
        # 2.4
        ("extension m3d missing in CodeFileExtensions", replace(utils, "|flt|m3d|", "|flt|"),
         "lists m3d, which CodeFileExtensions"),
        ("extension reg missing in the contract (2.4)", replace(contract, " url scf reg inf ", " url scf inf "),
         "missing reg, which CodeFileExtensions"),
        ("extension listed twice in CodeFileExtensions", replace(utils, "|flt|m3d|", "|flt|m3d|dll|"),
         "extensions listed twice: dll"),
        # 3.2
        ("Music Volume $2C -> $2D in setup_is6.iss",
         replace(main_script, 'ValueName: "Music Volume"; ValueData: "$2C"', 'ValueName: "Music Volume"; ValueData: "$2D"'),
         "Music Volume: Empire Earth: data 44 (0x2C) in the contract, 45 (0x2D)"),
        ("Music Volume 44 -> 45 in the contract",
         replace(contract, "| `Music Volume` | REG_DWORD | `44` (0x2C) |", "| `Music Volume` | REG_DWORD | `45` (0x2D) |"),
         "Music Volume: Empire Earth: data 45 (0x2D) in the contract, 44 (0x2C)"),
        ("decimal and hex differ in the contract",
         replace(contract, "| `Music Volume` | REG_DWORD | `44` (0x2C) |", "| `Music Volume` | REG_DWORD | `44` (0x2D) |"),
         "data `44` and (0x2D) differ"),
        ("type of Map Type in the contract",
         replace(contract, "| `Game Options\\Map Type` | REG_SZ |", "| `Game Options\\Map Type` | REG_DWORD |"),
         "Game Options\\Map Type"),
        ("class P -> D: Sound Volume with deletevalue",
         replace(main_script, 'ValueName: "Sound Volume"; ValueData: "$3C"; Flags: createvalueifdoesntexist',
                 'ValueName: "Sound Volume"; ValueData: "$3C"; Flags: deletevalue'),
         "Sound Volume: class P in the contract, but setup_is6.iss"),
        ("class D -> P in the contract: Wait for VSync",
         replace(contract, "| `Wait for VSync` | REG_DWORD | `0` | D |", "| `Wait for VSync` | REG_DWORD | `0` | P |"),
         "Wait for VSync: class P in the contract"),
        ("ending epoch of AoC $E -> $F",
         replace(main_script, 'GameDir = AoCDir, GameEndingEpoch = "$E"', 'GameDir = AoCDir, GameEndingEpoch = "$F"'),
         "Ending Epoch: The Art of Conquest: data 14 (0xE) in the contract, 15 (0xF)"),
        ("value missing in the contract (Take JPG Screenshots)",
         replace(contract, "| `Take JPG Screenshots` | REG_DWORD | `1` | P |\n", ""),
         "Take JPG Screenshots is missing"),
        ("new value in the script",
         replace(main_script, '#endsub' + crlf + '; Empire Earth: Ending Epoch',
                 'Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Self Test"; '
                 'ValueData: "$1"; Flags: createvalueifdoesntexist; Components: {#GameComp}' + crlf
                 + '#endsub' + crlf + '; Empire Earth: Ending Epoch'),
         "Self Test is missing"),
        ("computed value written as a fixed value in the contract",
         replace(contract, "| `Rasterizer Name` | REG_SZ | see [3.3](#33-computed-values) | D |",
                 "| `Rasterizer Name` | REG_SZ | `Direct3D` | D |"),
         "Rasterizer Name: Empire Earth: data 'Direct3D' in the contract, computed (see 3.3)"),
        # 3.3
        ("MaxGameWindowWidth 1920 -> 2560 in utils.iss",
         replace(utils, "MaxGameWindowWidth = 1920;", "MaxGameWindowWidth = 2560;"),
         "Game Window Width: maximum 1920 in the contract, 2560 in utils.iss"),
        ("minimum height 768 -> 720 in the contract",
         replace(contract, "| `768` | `1080` |", "| `720` | `1080` |"),
         "Game Window Height: minimum 720 in the contract, 768 in utils.iss"),
        ("row Game Window Height missing in the table of 3.3",
         replace(contract, "| `Game Window Height` | height of the primary screen (`SM_CYSCREEN`) | `768` | `1080` |\n", ""),
         "no row Game Window Height in the table of the window size limits"),
        ("MinGameWindowWidth defined a second time (in setup_is6.iss)",
         replace(main_script, "const\r\n  // Setup background:", "const\r\n  MinGameWindowWidth = 1024;\r\n  // Setup background:"),
         "the constant MinGameWindowWidth must be defined exactly once"),
        # 3.4
        ("GpuPreference=2; -> GpuPreference=1; in setup_is6.iss",
         replace(main_script, 'ValueData: "GpuPreference=2;"', 'ValueData: "GpuPreference=1;"', count=2),
         "data `GpuPreference=2;` in the contract, `GpuPreference=1;`"),
        ("task of a 3.4 row in the contract",
         replace(contract, "| `GpuPreference=2;` | 10 and later | `compatibility_windows` |\n| `<root>\\Empire Earth - The Art",
                 "| `GpuPreference=2;` | 10 and later | `compatibility` |\n| `<root>\\Empire Earth - The Art"),
         "task `compatibility` in the contract, `compatibility_windows`"),
        ("GPU preference from Windows 8 on in setup_is6.iss",
         replace(main_script, 'Flags: uninsdeletevalue; MinVersion: {#Win10}; Tasks: compatibility_windows; Components: game',
                 'Flags: uninsdeletevalue; MinVersion: {#Win8}; Tasks: compatibility_windows; Components: game'),
         "windows versions `10 and later` in the contract, `8 and later`"),
        ("AoC row missing in the table of 3.4",
         replace(contract, "| `<root>\\Empire Earth - The Art of Conquest\\EE-AOC.exe` | `gameaoc` | `GpuPreference=2;` | 10 and later | `compatibility_windows` |\n", ""),
         "EE-AOC.exe is missing in the contract"),
        ("GPU preference without uninsdeletevalue",
         replace(main_script, 'ValueData: "GpuPreference=2;"; \\\r\n  Flags: uninsdeletevalue; MinVersion: {#Win10}; Tasks: compatibility_windows; Components: game',
                 'ValueData: "GpuPreference=2;"; \\\r\n  MinVersion: {#Win10}; Tasks: compatibility_windows; Components: game'),
         "a GPU preference without the flag uninsdeletevalue"),
        # 3.7
        ("WIN7RTM -> WIN8RTM in setup_is6.iss", replace(main_script, '" WIN7RTM"', '" WIN8RTM"'),
         "compatibility_windows: values `WIN7RTM` in the contract, `WIN8RTM`"),
        ("flags of the task compatibility changed in BuildCompatibilityFlags",
         replace(utils, "' DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation'",
                 "' DWM8And16BitMitigation HeapClearAllocation'"),
         "compatibility: values `DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` in the contract"),
        ("task compatibility offered on Windows 7",
         replace(main_script, 'Name: "compatibility"; Description: "{cm:TaskCompatibility}"; MinVersion: {#Win8}',
                 'Name: "compatibility"; Description: "{cm:TaskCompatibility}"; MinVersion: {#Win7}'),
         # with it, the entries of compatibility_legacy (GetCompatibilityFlags passes both tasks)
         # would give its flags on Windows 7 too
         "compatibility: Windows versions '8 and later' in the contract, 'all' in setup_is6.iss"),
        ("task compatibility_windows offered on Windows 7",
         replace(main_script, 'Name: "compatibility_windows"; Description: "{cm:TaskCompatibilityWindows}"; MinVersion: {#Win8}',
                 'Name: "compatibility_windows"; Description: "{cm:TaskCompatibilityWindows}"; MinVersion: {#Win7}'),
         "task compatibility_windows is offered on the Windows versions 'all', but its compatibility value applies only on '8 and later'"),
        ("Windows versions of compatibility in the contract",
         replace(contract, "| `compatibility` | `DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` | 8 and later |",
                 "| `compatibility` | `DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` | all |"),
         "compatibility: Windows versions 'all' in the contract, '8 and later'"),
        ("root of the user mode in the contract",
         replace(contract, "| 8 and later | HKLM / HKCU / HKCU |\n| `compatibility_legacy`",
                 "| 8 and later | HKLM / HKLM / HKCU |\n| `compatibility_legacy`"),
         "compatibility: root in the user mode HKLM in the contract, HKCU"),
        ("compatibility values of the administrative mode in HKCU",
         replace(main_script, '#expr CompatRoot = "HKLM", CompatCheck = "IsAdminInstallMode"',
                 '#expr CompatRoot = "HKCU", CompatCheck = "IsAdminInstallMode"'),
         "everyoneadminstart: root in the admin mode HKLM in the contract, HKCU"),
        ("no compatibility values in the portable variants",
         both(replace(main_script, '#expr CompatRoot = "HKCU", CompatCheck = "not IsAdminInstallMode"',
                      '#if InstallMode == "Regular"' + crlf
                      + '#expr CompatRoot = "HKCU", CompatCheck = "not IsAdminInstallMode"'),
              replace(main_script, '#call CompatibilityValuesWin7' + crlf + crlf + '; Game settings',
                      '#call CompatibilityValuesWin7' + crlf + '#endif' + crlf + crlf + '; Game settings')),
         "root in the portable mode HKCU in the contract, -"),
        ("rows of 3.7 in another order",
         replace(contract, LEGACY_ROW + "\n| `compatibility_windows` | `WIN7RTM` | 8 and later | HKLM / HKCU / HKCU |\n",
                 "| `compatibility_windows` | `WIN7RTM` | 8 and later | HKLM / HKCU / HKCU |\n" + LEGACY_ROW + "\n"),
         "rows in the order everyoneadminstart, compatibility, compatibility_windows, compatibility_legacy"),
        ("table of 3.7 without its Root column",
         replace(contract, "| Task | Values | Windows versions | Root (admin/user/portable) |",
                 "| Task | Values | Windows versions | Hive |"),
         "the table of 3.7 has no column Root"),
        # 3.7, the opt-in row compatibility_legacy (Windows 7 only, ADR 0010)
        ("row compatibility_legacy missing in the contract", replace(contract, LEGACY_ROW + "\n", ""),
         "no row for the task(s) compatibility_legacy"),
        ("WINXPSP3 in the row compatibility_legacy of the contract",
         replace(contract, LEGACY_ROW, LEGACY_ROW.replace("HeapClearAllocation`", "HeapClearAllocation WINXPSP3`")),
         "compatibility_legacy: values `DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3` in the contract"),
        ("the entries of compatibility_legacy append WINXPSP3 in setup_is6.iss",
         replace(main_script, '#expr CompatVersions = "OnlyBelowVersion: " + Win8 + "; ", CompatLayer = ""',
                 '#expr CompatVersions = "OnlyBelowVersion: " + Win8 + "; ", CompatLayer = " WINXPSP3"'),
         "task compatibility_legacy adds `DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` and `WINXPSP3`"),
        ("Windows versions of compatibility_legacy in the contract",
         replace(contract, LEGACY_ROW, LEGACY_ROW.replace("| 7 only (opt-in) |", "| 8 and later (opt-in) |")),
         "compatibility_legacy: Windows versions '8 and later' in the contract, '7 only'"),
        ("compatibility_legacy without (opt-in) in the contract",
         replace(contract, LEGACY_ROW, LEGACY_ROW.replace("| 7 only (opt-in) |", "| 7 only |")),
         "compatibility_legacy: selected by default in the contract"),
        ("task compatibility_legacy selected by default",
         replace(main_script, 'OnlyBelowVersion: {#Win8}; Flags: unchecked; Check: not IsWine',
                 'OnlyBelowVersion: {#Win8}; Check: not IsWine'),
         "compatibility_legacy: opt-in in the contract ('(opt-in)' after the Windows versions), but the task is selected by default"),
        ("task compatibility_legacy offered on every Windows",
         replace(main_script, 'Description: "{cm:TaskCompatibilityLegacy}"; OnlyBelowVersion: {#Win8}; ',
                 'Description: "{cm:TaskCompatibilityLegacy}"; '),
         # its flags would then also come with the entries of Windows 8 and later
         "compatibility_legacy: Windows versions '7 only' in the contract, 'all' in setup_is6.iss"),
        ("GetCompatibilityFlags does not pass compatibility_legacy",
         replace(main_script, "WizardIsTaskSelected('compatibility') or WizardIsTaskSelected('compatibility_legacy')",
                 "WizardIsTaskSelected('compatibility')"),
         "the task(s) compatibility_legacy add no compatibility value"),
        ("GetCompatibilityFlags joins the tasks with and",
         replace(main_script, "WizardIsTaskSelected('compatibility') or WizardIsTaskSelected('compatibility_legacy')",
                 "WizardIsTaskSelected('compatibility') and WizardIsTaskSelected('compatibility_legacy')"),
         "or several of them joined by 'or'"),
        ("RUNASADMIN only also with compatibility_legacy (two entries for one value)",
         replace(main_script, " and not compatibility and not compatibility_legacy\", CompatVersions",
                 " and not compatibility\", CompatVersions"),
         "both compatibility entries can write the value of the component game in HKLM in the same run"),
        # ISPP subset
        ("ISPP function in a compatibility entry",
         replace(main_script, 'ValueData: "{code:GetCompatibilityFlags}{#CompatLayer}"; \\\r\n  Flags: uninsdeletevalue; Check: {#CompatCheck}; {#CompatVersions}Tasks: {#CompatTasks}; Components: gameaoc',
                 'ValueData: "{code:GetCompatibilityFlags}{#Trim(CompatLayer)}"; \\\r\n  Flags: uninsdeletevalue; Check: {#CompatCheck}; {#CompatVersions}Tasks: {#CompatTasks}; Components: gameaoc'),
         "{#Trim(CompatLayer)} in valuedata cannot be evaluated by this check, but the entry matters for contract 3.7"),
        ("unsupported directive in [Registry]",
         replace(main_script, "; Administrative install mode: for all users (HKLM)",
                 '#include "selftest.iss"' + crlf + "; Administrative install mode: for all users (HKLM)"),
         "#include is not supported by this check"),
        # [Files]
        ("[Files] entry below {app} without ignoreversion (EE Base)",
         replace(main_script, '"data\\Empire Earth Base\\Empire Earth\\*"; DestDir: "{app}\\{#EEDir}"; Flags: ignoreversion recursesubdirs',
                 '"data\\Empire Earth Base\\Empire Earth\\*"; DestDir: "{app}\\{#EEDir}"; Flags: recursesubdirs'),
         "without the flag ignoreversion"),
        ("[Files] entry in a #sub with onlyifdoesntexist (Discord)",
         replace(main_script, 'Source: "data\\Add-on\\DLLs\\Discord\\*"; DestDir: "{app}\\{#AddOnDir}"; Flags: ignoreversion',
                 'Source: "data\\Add-on\\DLLs\\Discord\\*"; DestDir: "{app}\\{#AddOnDir}"; Flags: ignoreversion onlyifdoesntexist'),
         "with the flag onlyifdoesntexist"),
        ("[Files] entry on a continued line with promptifolder (AoC Base)",
         replace(main_script, '"{app}\\{#AoCDir}"; \\' + crlf + '  Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc;',
                 '"{app}\\{#AoCDir}"; \\' + crlf + '  Flags: ignoreversion promptifolder recursesubdirs createallsubdirs; Components: gameaoc;'),
         "with the flag promptifolder"),
        ("[Files] entry with confirmoverwrite (EEStats.dll)",
         replace(main_script, 'EEStats.dll"; DestDir: "{app}\\{#EEDir}"; Flags: ignoreversion',
                 'EEStats.dll"; DestDir: "{app}\\{#EEDir}"; Flags: ignoreversion confirmoverwrite'),
         "with the flag confirmoverwrite"),
        ("[Files] entry in a #sub without AfterInstall (Discord)",
         replace(main_script, 'Components: additional\\discord and {#AddOnComp}; AfterInstall: RecordInstalledFile',
                 'Components: additional\\discord and {#AddOnComp}'),
         "without AfterInstall: RecordInstalledFile"),
        ("[Files] entry on a continued line with another AfterInstall (AoC Base)",
         replace(main_script, 'Components: gameaoc; AfterInstall: RecordInstalledFile' + crlf + '; AoC Movies',
                 'Components: gameaoc; AfterInstall: OtherProcedure' + crlf + '; AoC Movies'),
         "it has AfterInstall: OtherProcedure"),
        ("[Files] external entry with AfterInstall (verified EE files)",
         replace(main_script, 'external skipifsourcedoesntexist; Components: game and language\\update;',
                 'external skipifsourcedoesntexist; Components: game and language\\update; AfterInstall: RecordInstalledFile'),
         "but it is an external entry"),
        ("[Files] deleteafterinstall entry with AfterInstall (_wonkver.pub)",
         replace(main_script, 'Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs; Components: game' + crlf,
                 'Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs; Components: game; AfterInstall: RecordInstalledFile' + crlf),
         "but it is a deleteafterinstall file"),
        ("[Files] setup data folder with AfterInstall (EEStatsSetup.dll)",
         replace(main_script, 'createallsubdirs; MinVersion: {#WinXP}' + crlf,
                 'createallsubdirs; MinVersion: {#WinXP}; AfterInstall: RecordInstalledFile' + crlf),
         "but it is the setup data folder"),
        # 2.3, verified online files: [Files] and RecordVerifiedOnlineFiles
        ("RecordVerifiedOnlineFiles records the learning campaign in the EE folder",
         replace("installstate.iss", "InstalledFiles.Add(ExpandConstant('{app}\\{#AoCDir}\\Data\\Campaigns\\EELearningCampaign.ssa'));",
                 "InstalledFiles.Add(ExpandConstant('{app}\\{#EEDir}\\Data\\Campaigns\\EELearningCampaign.ssa'));"),
         "DestDir {app}\\{#eedir}\\data\\campaigns, Components gameaoc and language\\update) to the manifest that no [Files] entry installs"),
        ("RecordVerifiedOnlineFiles without the AoC folder",
         replace("installstate.iss", "    CollectExternalFiles(ExpandConstant('{tmp}\\verified\\AoC'), ExpandConstant('{app}\\{#AoCDir}'), InstalledFiles);\n", ""),
         "Source {tmp}\\verified\\aoc\\*, DestDir {app}\\{#aocdir}, Components gameaoc and language\\update) that RecordVerifiedOnlineFiles does not add"),
        ("RecordVerifiedOnlineFiles records another file name",
         replace("installstate.iss", "InstalledFiles.Add(ExpandConstant('{app}\\{#AoCDir}\\Data\\Campaigns\\EELearningCampaign.ssa'));",
                 "InstalledFiles.Add(ExpandConstant('{app}\\{#AoCDir}\\Data\\Campaigns\\EETutorial.ssa'));"),
         "another file name"),
        ("[Files] verified EE entry without the component language\\update",
         replace(main_script, 'external skipifsourcedoesntexist; Components: game and language\\update;',
                 'external skipifsourcedoesntexist; Components: game;'),
         "Components game) that RecordVerifiedOnlineFiles does not add"),
        ("[Files] verified EE entry with 'or' in Components",
         replace(main_script, 'external skipifsourcedoesntexist; Components: game and language\\update;',
                 'external skipifsourcedoesntexist; Components: game or language\\update;'),
         "is not a list of component names joined by 'and'"),
        # suite (contract 0 "Suite and launcher", 1.6, 1.7): suite/suite.iss
        ("suite: AppMutex without the launcher mutex",
         suite_case(",EmpireEarthCommunityLauncher\n", "\n"),
         "does not name EmpireEarthCommunityLauncher"),
        ("suite: AppMutex without the game mutex of AoC",
         suite_case("MadDocSoftwarePresentsEmpireEarthExpansion,", ""),
         "does not name MadDocSoftwarePresentsEmpireEarthExpansion"),
        ("suite: SetupMutex of a product",
         suite_case("SetupMutex=EmpireEarthCommunity_Suite", "SetupMutex=EE_Setup"),
         "SetupMutex=EE_Setup does not name EmpireEarthCommunity_Suite"),
        ("suite: no SetupMutex",
         suite_case("SetupMutex=EmpireEarthCommunity_Suite\n", ""),
         "[Setup] has no SetupMutex"),
        ("suite: mutex from an unknown define",
         suite_case("SetupMutex=EmpireEarthCommunity_Suite", "SetupMutex={#SuiteMutex}"),
         "cannot read '{#SuiteMutex}'"),
        ("suite: no marker in the uninstall key of the suite",
         suite_case('Root: HKLM; Subkey: "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1"; '
                    'ValueType: dword; ValueName: "Empire Earth Community: Suite"; ValueData: "1"\n', ''),
         "the suite does not write the value Empire Earth Community: Suite into its uninstall key"),
        ("suite code: no marker in the uninstall key of the suite",
         code_case("  RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1', "
                   "'Empire Earth Community: Suite', 1);\n", ""),
         "the suite does not write the value Empire Earth Community: Suite into its uninstall key"),
        ("suite code: marker in the uninstall key of EE",
         code_case("  RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1', 'Empire",
                   "  RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#EE_AppID}}_is1', 'Empire"),
         "not to the uninstall key of the suite"),
        ("suite code: marker as a string",
         code_case("RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1', 'Empire Earth Community: Suite', 1);",
                   "RegWriteStringValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1', 'Empire Earth Community: Suite', '1');"),
         "Empire Earth Community: Suite is REG_SZ, contract 0 REG_DWORD"),
        ("suite code: marker with the data 0",
         code_case("'Empire Earth Community: Suite', 1);", "'Empire Earth Community: Suite', 0);"),
         "Empire Earth Community: Suite has the data 0, contract 0 1"),
        ("suite code: marker with another value name",
         code_case("'Empire Earth Community: Suite', 1);", "'Empire Earth Community: Suit', 1);"),
         "the suite does not write the value Empire Earth Community: Suite into its uninstall key"),
        ("suite code: marker in HKCU",
         code_case("RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1'",
                   "RegWriteDWordValue(HKCU, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1'"),
         "is written to Root HKCU"),
        ("suite code: marker written twice",
         code_case("  RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1', 'Empire Earth Community: Suite', 1);\n",
                   "  RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1', 'Empire Earth Community: Suite', 1);\n"
                   "  RegWriteDWordValue(HKLM, 'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{#SuiteAppID}}_is1', 'Empire Earth Community: Suite', 1);\n"),
         "is written more than once"),
        ("suite: row of the uninstall key marker missing in the contract",
         replace(contract, "| Suite uninstall key marker | `Empire Earth Community: Suite`, REG_DWORD `1` ([1.3](#13-uninstall-key-informative)) |\n", ""),
         "has no row 'Suite uninstall key marker'"),
        ("suite: record without the value Written",
         suite_case('ValueName: "Written"; ValueData: "{code:WrittenTime}"\n', 'ValueName: "Writen"; ValueData: "{code:WrittenTime}"\n'),
         "the suite record has no value Written"),
        ("suite: record with a value the contract does not have",
         suite_case('ValueName: "SourceDir"; ValueData: "{src}"\n',
                    'ValueName: "SourceDir"; ValueData: "{src}"\n'
                    'Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "Language"; ValueData: "de"\n'),
         "the suite record value Language is not in the table of contract 1.6"),
        ("suite: ContractVersion as a string",
         suite_case('ValueType: dword; ValueName: "ContractVersion"', 'ValueType: string; ValueName: "ContractVersion"'),
         "ContractVersion is REG_SZ, contract 1.6 REG_DWORD"),
        ("suite: ContractVersion 2",
         suite_case("#define ContractVersion 1", "#define ContractVersion 2"),
         "ContractVersion 2, but the contract version is 1"),
        ("suite: record in HKCU",
         suite_case('Root: HKLM; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "Products"',
                    'Root: HKCU; Subkey: "{#SuiteKey}"; ValueType: string; ValueName: "Products"'),
         "the suite record has Root HKCU"),
        ("suite: record in HKLM without 64-bit install mode",
         suite_case("ArchitecturesInstallIn64BitMode=x64 arm64\n", ""),
         "so it lands in the 32-bit view"),
        ("suite: record key without uninsdeletekey",
         suite_case('Subkey: "{#SuiteKey}"; Flags: uninsdeletekey\n', 'Subkey: "{#SuiteKey}"; Flags: uninsdeletekeyifempty\n'),
         "has the flag uninsdeletekey"),
        ("suite: EE desktop shortcut to the game program with --product=EE",
         suite_case('Name: "{autodesktop}\\Empire Earth"; Filename: "{app}\\{#LauncherExe}"; Parameters: "--product=EE"',
                    'Name: "{autodesktop}\\Empire Earth"; Filename: "{code:ProductRoot|EE}\\Empire Earth\\Empire Earth.exe"; Parameters: "--product=EE"'),
         "passes --product=EE but starts {code:ProductRoot|EE}\\Empire Earth\\Empire Earth.exe, not the launcher"),
        ("suite: Neo Empire Earth in the start menu starts EE",
         suite_case('Name: "{autoprograms}\\Empire Earth Community\\Neo Empire Earth"; Filename: "{app}\\{#LauncherExe}"; Parameters: "--product=NeoEE"',
                    'Name: "{autoprograms}\\Empire Earth Community\\Neo Empire Earth"; Filename: "{app}\\{#LauncherExe}"; Parameters: "--product=EE"'),
         "starts the launcher with '--product=EE' instead of --product=NeoEE"),
        ("suite: no Neo Empire Earth shortcut in the start menu",
         suite_case('Name: "{autoprograms}\\Empire Earth Community\\Neo Empire Earth"', 'Name: "{autoprograms}\\Empire Earth Community\\NeoEE"'),
         "no [Icons] entry {autoprograms}\\Empire Earth Community\\Neo Empire Earth that starts the launcher"),
        ("suite: game shortcut with the old name Play Empire Earth",
         suite_case('Name: "{autodesktop}\\Empire Earth"; Filename: "{app}', 'Name: "{autodesktop}\\Empire Earth spielen"; Filename: "{app}'),
         "Empire Earth spielen starts the launcher with --product=EE, but Empire Earth spielen is no game shortcut"),
        ("suite: fallback shortcut to another program",
         suite_case('"{code:ProductRoot|EE}\\Empire Earth\\Empire Earth.exe"', '"{code:ProductRoot|EE}\\Empire Earth\\EE-Diagnostic.exe"'),
         "contract 1.7 allows the launcher"),
        # the same rules for the record and the shortcuts written in code
        ("suite code: record without the value Written",
         code_case("'Written', GetDateTimeString", "'Writen', GetDateTimeString"),
         "the suite record has no value Written"),
        ("suite code: record with a value the contract does not have",
         code_case("'Products', 'EE');", "'Products', 'EE');\n  RegWriteStringValue(HKLM, '{#SuiteKey}', 'Language', 'de');"),
         "the suite record value Language is not in the table of contract 1.6"),
        ("suite code: ContractVersion as a string",
         code_case("RegWriteDWordValue(HKLM, '{#SuiteKey}', 'ContractVersion'", "RegWriteStringValue(HKLM, '{#SuiteKey}', 'ContractVersion'"),
         "ContractVersion is REG_SZ, contract 1.6 REG_DWORD"),
        ("suite code: ContractVersion 2",
         code_case("#define ContractVersion 1", "#define ContractVersion 2"),
         "ContractVersion 2, but the contract version is 1"),
        ("suite code: record in HKCU",
         code_case("RegWriteStringValue(HKLM, '{#SuiteKey}', 'Products'", "RegWriteStringValue(HKCU, '{#SuiteKey}', 'Products'"),
         "the suite record has Root HKCU"),
        ("suite code: record in HKLM without 64-bit install mode",
         code_case("ArchitecturesInstallIn64BitMode=x64 arm64\n", ""),
         "so it lands in the 32-bit view"),
        ("suite code: record not removed by the uninstaller",
         code_case("  RegDeleteKeyIncludingSubkeys(HKLM, '{#SuiteKey}');\n", ""),
         "has the flag uninsdeletekey and the code has no RegDeleteKeyIncludingSubkeys"),
        ("suite code: the key above the record is not removed",
         code_case("  RegDeleteKeyIfEmpty(HKLM, 'Software\\Empire Earth Community');\n", ""),
         "has no RegDeleteKeyIfEmpty(HKLM, 'Software\\Empire Earth Community')"),
        ("suite code: EE shortcut with --product=NeoEE",
         code_case("'{app}\\{#LauncherExe}', '--product=EE', 'EE', '\\Empire Earth\\Empire Earth.exe');\n  SuiteShortcut('{autoprograms}",
                   "'{app}\\{#LauncherExe}', '--product=NeoEE', 'EE', '\\Empire Earth\\Empire Earth.exe');\n  SuiteShortcut('{autoprograms}"),
         "passes --product=NeoEE but names the product 'EE'"),
        ("suite code: game shortcut without a fallback",
         code_case("'--product=NeoEE', 'NeoEE', '\\Empire Earth\\Empire Earth.exe');\n  SuiteShortcut('{autoprograms}\\Empire Earth Community', 'Neo",
                   "'--product=NeoEE', 'NeoEE', '');\n  SuiteShortcut('{autoprograms}\\Empire Earth Community', 'Neo"),
         "has no fallback to the game program"),
        ("suite code: fallback to another program",
         code_case("'{autodesktop}', 'Empire Earth', '{app}\\{#LauncherExe}', '--product=EE', 'EE', '\\Empire Earth\\Empire Earth.exe'",
                   "'{autodesktop}', 'Empire Earth', '{app}\\{#LauncherExe}', '--product=EE', 'EE', '\\Empire Earth\\EE-Diagnostic.exe'"),
         "contract 1.7 allows the launcher"),
        ("suite code: game shortcut to the Mod Creator",
         code_case("'{autodesktop}', 'Empire Earth', '{app}\\{#LauncherExe}'", "'{autodesktop}', 'Empire Earth', '{app}\\Mod Creator\\Mod Creator.exe'"),
         "passes --product=EE but starts {app}\\Mod Creator\\Mod Creator.exe, not the launcher"),
        ("suite code: no Neo Empire Earth shortcut in the start menu",
         code_case("'{autoprograms}\\Empire Earth Community', 'Neo Empire Earth'", "'{autoprograms}\\Empire Earth Community', 'NeoEE'"),
         "no [Icons] entry {autoprograms}\\Empire Earth Community\\Neo Empire Earth that starts the launcher"),
        ("suite code: shortcut with six arguments missing",
         code_case("'{app}\\{#LauncherExe}', '', '', '');", "'{app}\\{#LauncherExe}', '');"),
         "SuiteShortcut has 4 arguments, this check reads six"),
        ("suite code: shortcut name from a variable",
         code_case("'{autodesktop}', 'Empire Earth', '{app}", "'{autodesktop}', SuiteName, '{app}"),
         "this check reads only string literals there"),
        ("suite code: the protected key of the CD keys in code",
         code_case("  RegDeleteKeyIfEmpty(HKLM, 'Software\\Empire Earth Community');",
                   "  RegDeleteKeyIfEmpty(HKLM, 'Software\\Empire Earth Community');\n  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\\Sierra\\CDKeys');"),
         "names a protected key or the CD key registration"),
        ("suite code: authtools in code",
         code_case("  RegDeleteKeyIfEmpty(HKLM, 'Software\\Empire Earth Community');",
                   "  RegDeleteKeyIfEmpty(HKLM, 'Software\\Empire Earth Community');\n  LoadDLL('authtools.dll');"),
         "names a protected key or the CD key registration"),
    ]
    passing = [
        ("ISPP function in an unrelated [Registry] entry",
         replace(main_script, "; Windows 10+: run the games on the high-performance graphics card",
                 'Root: "HKCU"; Subkey: "Software\\Self Test"; ValueType: String; ValueName: "Version"; '
                 'ValueData: "{#Str(ContractVersion) + "; x"}"\r\n'
                 "; Windows 10+: run the games on the high-performance graphics card")),
        ("[Files] entry to {tmp} without ignoreversion",
         replace(main_script, "[Dirs]" + crlf, 'Source: "selftest.txt"; DestDir: "{tmp}"; Flags: deleteafterinstall' + crlf + crlf + "[Dirs]" + crlf)),
        ("#if InstallMode around the GPU preference in [Registry]",
         both(replace(main_script, "; Windows 10+: run the games on the high-performance graphics card",
                      '#if InstallMode == "Regular" || InstallMode == "Portable"' + crlf
                      + "; Windows 10+: run the games on the high-performance graphics card"),
              replace(main_script, "Components:  gameaoc" + crlf, "Components:  gameaoc" + crlf + "#endif" + crlf))),
        ("[Files] verified EE entry with its components in another order and case",
         replace(main_script, 'external skipifsourcedoesntexist; Components: game and language\\update;',
                 'external skipifsourcedoesntexist; Components: Language\\Update and game;')),
        ("suite: suite/suite.iss absent, suite rules skipped", remove(suite), SUITE_SKIPPED),
        ("suite: minimal suite/suite.iss as the contract describes it", fixture,
         "suite: SetupMutex and AppMutex (4 names), record with 8 values, 4 game shortcuts to the launcher"),
        ("suite code: record and shortcuts in code as the contract describes them", code_fixture,
         "record with 8 values, 4 game shortcuts to the launcher, the uninstall key marker, no protected key in"),
        ("suite code: a protected key named in a comment only",
         code_case("// SuiteShortcut('{autodesktop}'", "// never touches Software\\Sierra\\CDKeys or authtools.dll\n// SuiteShortcut('{autodesktop}'"),
         "no protected key in"),
        ("suite code: HKLM64, a statement after a trailing comment, a value name with a doubled apostrophe",
         both(code_fixture,
              replace(suite, "RegWriteStringValue(HKLM, '{#SuiteKey}', 'Products', 'EE');",
                      "RegWriteStringValue(HKLM64, '{#SuiteKey}', 'Products', 'EE'); // the products"),
              replace(suite, "RegDeleteKeyIncludingSubkeys(HKLM, '{#SuiteKey}');", "RegDeleteKeyIncludingSubkeys(HKLM64, '{#SuiteKey}');")),
         "record with 8 values"),
        ("suite: record in HKLM64 without 64-bit install mode, start menu folder written out, other order",
         both(fixture,
              replace(suite, "ArchitecturesInstallIn64BitMode=x64 arm64\n", ""),
              replace(suite, "Root: HKLM; Subkey: \"{#SuiteKey}\"", "Root: HKLM64; Subkey: \"{#SuiteKey}\"", count=9),
              replace(suite, 'Name: "{group}\\Empire Earth"; ', 'Name: "{autoprograms}\\Empire Earth Community\\Empire Earth"; '),
              replace(suite, "AppMutex=StainlessSteelStudiosPresentsEmpireEarth,MadDocSoftwarePresentsEmpireEarthExpansion,EmpireEarthCommunityLauncher",
                      "AppMutex=EmpireEarthCommunityLauncher, MadDocSoftwarePresentsEmpireEarthExpansion, StainlessSteelStudiosPresentsEmpireEarth")),
         "record with 8 values"),
    ]

    files = [CONTRACT, MAIN_SCRIPT, UTILS_SCRIPT, "config_ee.iss", "config_neoee.iss"]
    files += [rel.as_posix() for rel in own_include_closure(source_root)]
    files += [rel.as_posix() for rel in suite_include_closure(source_root)]
    failures = 0
    with tempfile.TemporaryDirectory(prefix="check_contract_selftest_") as temp:
        # (name, change, expected problem or None, expected text of the summary or None)
        all_cases = ([("unmodified copy", None, None, None)] + [(n, c, e, None) for n, c, e in cases]
                     + [(case[0], case[1], None, case[2] if len(case) > 2 else None) for case in passing])
        for number, (name, change, expected, expected_summary) in enumerate(all_cases):
            root = Path(temp) / f"case{number}"
            for rel in dict.fromkeys(files):
                (root / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source_root / rel, root / rel)
            summary = ""
            try:
                if change:
                    change(root)
                errors, summary = check(root)
            except AssertionError as error:
                ok, errors = False, [str(error)]
            else:
                ok = (not errors) if expected is None else any(expected in error for error in errors)
                if expected_summary is not None and expected_summary not in summary:
                    ok = False
                    errors = errors + [f"(summary without '{expected_summary}': {summary})"]
            print(f"{'PASS' if ok else 'FAIL'} {name}")
            if not ok:
                failures += 1
                want = "no problem" if expected is None else f"a problem containing '{expected}'"
                print(f"  expected {want}, got:")
                for error in errors or ["(no problem)"]:
                    print("    " + error)
            shutil.rmtree(root)
    total = 1 + len(cases) + len(passing)
    print(f"RESULT: {'PASS' if not failures else 'FAIL'} ({total - failures} of {total} cases)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
