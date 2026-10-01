#!/usr/bin/env python3
"""Checks messages.iss for mistakes Inno Setup compiles without a warning.

  python ci/check_messages.py [repo_dir]

Errors (exit code 1):
  - a message defined twice for the same language (the later one silently wins), unless the two
    definitions are in different branches of the same #if/#elif/#else,
  - a value starting with "=" (a "key==value" typo),
  - "''" in a value: messages are not Pascal strings, the two apostrophes are shown as they are,
  - a language prefix that is not in [Languages] of setup_is6.iss,
  - a custom message with translations but without the default (English) entry,
  - a custom message used in the own scripts ({cm:Name}, CustomMessage('Name')) that is not
    defined. Names built at run time (e.g. 'LIQP_' + Langs[i]) cannot be checked, except for the
    language names LIQP_<name>: one for every game language in GameLangs of setup_is6.iss.
"""
import re
import sys
from pathlib import Path

# Custom messages of Inno Setup's own Default.isl, available without a definition in messages.iss
INNO_CUSTOM_MESSAGES = {
    "NameAndVersion", "AdditionalIcons", "CreateDesktopIcon", "CreateQuickLaunchIcon",
    "ProgramOnTheWeb", "UninstallProgram", "LaunchProgram", "AssocFileExtension",
    "AssocingFileExtension", "AutoStartProgramGroupDescription", "AutoStartProgram",
    "AddonHostProgramNotFound",
}
OWN_SCRIPTS = ["setup_is6.iss", "utils.iss", "extension.iss", "pages.iss", "downloads.iss", "randommaps.iss",
               "eestats.iss", "telemetry.iss", "messages.iss"]


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


def exclusive(path_a, path_b):
    """True if two #if branch paths can never be active together."""
    branches_b = dict(path_b)
    return any(if_id in branches_b and branches_b[if_id] != branch for if_id, branch in path_a)


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    errors = []

    languages = set(re.findall(r'^Name:\s*"([^"]+)";\s*MessagesFile:',
                               (root / "setup_is6.iss").read_text(encoding="utf-8-sig"), re.M))
    if not languages:
        errors.append("setup_is6.iss: no [Languages] entries found")

    section, stack, if_count = "", [], 0
    defined = {}  # (section, name, lang) -> [(line, branch path)]
    for no, line in read_lines(root / "messages.iss"):
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
        where = f"messages.iss:{no}: {key}"
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
            errors.append(f"messages.iss: custom message {name} has translations but no default entry")

    # Game languages: the language page and [Components] (generated) use LIQP_<name>
    game_langs = re.search(r'^#dim\s+GameLangs\s*\[[^\]]*\]\s*\{([^}]*)\}',
                           (root / "setup_is6.iss").read_text(encoding="utf-8-sig"), re.M)
    if not game_langs:
        errors.append("setup_is6.iss: no '#dim GameLangs[...] {...}' list found")
    else:
        for lang in re.findall(r'"([^"]+)"', game_langs.group(1)):
            if "LIQP_" + lang not in custom:
                errors.append(f"setup_is6.iss: game language {lang} has no custom message LIQP_{lang}")

    for script in OWN_SCRIPTS:
        text = (root / script).read_text(encoding="utf-8-sig")
        for name in sorted(set(re.findall(r"\{cm:(\w+)[,}]", text)) | set(re.findall(r"CustomMessage\('(\w+)'\)", text))):
            if name not in custom and name not in INNO_CUSTOM_MESSAGES:
                errors.append(f"{script}: custom message {name} is used but not defined")

    for error in errors:
        print(error)
    print(f"{len(errors)} problem(s) found" if errors else "messages.iss: OK")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
