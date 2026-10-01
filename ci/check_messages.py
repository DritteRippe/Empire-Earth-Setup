#!/usr/bin/env python3
"""Checks messages.iss for mistakes Inno Setup compiles without a warning.

  python ci/check_messages.py [--coverage] [--sort] [repo_dir]

  --coverage  also prints, per game language, the custom messages that have no translation (they
              are shown in English) and the zh_TW texts that are copies of the zh_CN ones. This is
              a report for translators (see TRANSLATING.md), not an error.
  --sort      rewrites messages.iss with the translations of every message in the standard order
              (see below) and exits; the content of the messages does not change.

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
    languages). Inno Setup does not care about the order; it keeps the file easy to compare.
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
OWN_SCRIPTS = ["setup_is6.iss", "config_ee.iss", "config_neoee.iss", "utils.iss", "extension.iss", "pages.iss",
               "downloads.iss", "randommaps.iss", "eestats.iss", "telemetry.iss", "messages.iss"]
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


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    options = {a for a in sys.argv[1:] if a.startswith("--")}
    unknown = options - {"--coverage", "--sort"}
    if unknown:
        print(f"unknown option(s): {', '.join(sorted(unknown))}")
        return 2
    root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
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

    messages_path = root / "messages.iss"
    raw = messages_path.read_bytes()
    newline = "\r\n" if b"\r\n" in raw else "\n"
    text_lines = raw.decode("utf-8-sig").split(newline)
    runs = entry_runs(text_lines)
    if "--sort" in options:
        for run in runs:
            start = run[0][3] - 1
            block = [line for entry in sorted_run(run, lang_rank) for line in entry[2]]
            text_lines[start:start + len(block)] = block
        bom = b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b""
        messages_path.write_bytes(bom + newline.join(text_lines).encode("utf-8"))
        print("messages.iss: translations sorted")
        return 0
    for run in runs:
        if [e[3] for e in run] != [e[3] for e in sorted_run(run, lang_rank)]:
            errors.append(f"messages.iss:{run[0][3]}: translations not in the standard order "
                          "(python ci/check_messages.py --sort fixes it)")

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
    if not game_langs:
        errors.append("setup_is6.iss: no '#dim GameLangs[...] {...}' list found")
    else:
        for lang in game_lang_names:
            if "LIQP_" + lang not in custom:
                errors.append(f"setup_is6.iss: game language {lang} has no custom message LIQP_{lang}")

    for script in OWN_SCRIPTS:
        text = (root / script).read_text(encoding="utf-8-sig")
        for name in sorted(set(re.findall(r"\{cm:(\w+)[,}]", text)) | set(re.findall(r"CustomMessage\('(\w+)'\)", text))):
            if name not in custom and name not in INNO_CUSTOM_MESSAGES:
                errors.append(f"{script}: custom message {name} is used but not defined")

    if "--coverage" in options:
        print_coverage(runs, custom, game_lang_names)

    for error in errors:
        print(error)
    print(f"{len(errors)} problem(s) found" if errors else "messages.iss: OK")
    return 1 if errors else 0


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
