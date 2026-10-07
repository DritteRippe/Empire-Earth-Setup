#!/usr/bin/env python3
"""Checks the form of the German test plan docs/TEST-PLAN.de.md and the test case ids used in the
documentation.

  python ci/check_test_plan.py [repo_dir]
  python ci/check_test_plan.py --self-test

Errors (exit code 1):
  - the test plan is missing or not valid UTF-8,
  - a test case heading ("#### TP-xy: title", outside code blocks) is malformed, or an id is
    defined twice,
  - a test case has no valid status ("ausgearbeitet", "geplant: S-WP<n>" or "entfällt: <reason>"),
    an unknown or repeated field, or misses a field: a worked-out case ("ausgearbeitet") needs every
    field of the template (section 4 of the plan), a planned or dropped one at least "Priorität",
    "Bezug" and "Ziel",
  - a test case has no valid priority: "Priorität" is "P1", "P2" or "P3", optionally followed by a
    remark in parentheses ("P2 (P1 mit Weg B)"),
  - the table of the P1 short run (section "Kurzdurchlauf") does not name exactly the cases with the
    priority P1 in its column "Fälle", a step has no whole number in "Minuten", or the row "Summe"
    is not the sum of the steps or more than 180 minutes (three hours),
  - the table of the forum test cases (section "Forum-Testfälle", report section 8) does not list
    the numbers 1 to 22 exactly once each; a row names neither a test case id nor "Launcher:" or
    "entfällt:" with a reason; or its column "Stand" does not match the status of the cases it
    names (every package of a planned case, "ausgearbeitet" if one of them is worked out),
  - an id "TP-<digits>" without exactly two digits, or an id that is named in the test plan or in
    any other Markdown file of the repository (README.md, CHANGELOG.md, docs/ARCHITECTURE.md, the
    ADRs, ...) but not defined in the test plan.

--self-test runs the check against modified temporary copies of the documents (a duplicate id, a
missing forum number, an undefined id in the README, ...) that must fail, and against an
unmodified copy that must pass. Exit code 0 if all cases behave.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TEST_PLAN = "docs/TEST-PLAN.de.md"
FORUM_NUMBERS = range(1, 23)
FIELDS = ["Status", "Priorität", "Bezug", "Ziel", "Build-Art", "Ausgangszustand", "Snapshot",
          "Varianten", "Schritte", "Erwartetes Ergebnis", "Log-Hinweis"]
REQUIRED_PLANNED = ["Status", "Priorität", "Bezug", "Ziel"]
# P1: short run before every release, P2: important, outside the short run, P3: optional (section 4)
PRIORITIES = ("P1", "P2", "P3")
PRIORITY = re.compile(r"(P\d+)(?:\s+\(.+\))?")
# The P1 short run (section 7) takes at most three hours
MAX_SHORT_RUN_MINUTES = 180
CASE_HEADING = re.compile(r"^(#{2,6})\s+(TP-\S*?):?\s+(.*)$")
VALID_ID = re.compile(r"^TP-\d\d$")
FIELD_LINE = re.compile(r"^- \*\*([^*:]+):\*\*(.*)$")
# "TP-1x" (all ids of block 1) is not a reference
ID_REFERENCE = re.compile(r"(?<![\w-])TP-(\d+)(?!x)")
# In the column "Zuordnung", "Launcher: <reason>" or "entfällt: <reason>" ends the list of ids;
# ids in the reason are only mentioned, not assigned
EXCLUSION = re.compile(r"(Launcher|entfällt):\s*(.*)$")
# Markdown files outside these folders are searched for ids (assets and build output excluded)
SKIPPED_FOLDERS = {".git", ".github", "data", "internal", "out", "tools", "ci"}


def outside_code(lines):
    """(number, line) of the lines outside fenced code blocks."""
    fenced = False
    for no, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            yield no, line


def parse_cases(lines, errors):
    """{id: {"line": n, "fields": {name: text}}} of the test case sections."""
    cases = {}
    current = None
    current_level = 0
    last_field = None
    for no, line in outside_code(lines):
        heading = re.match(r"^(#{1,6})\s", line)
        if heading:
            level = len(heading.group(1))
            if current and level <= current_level:
                current = None
            match = CASE_HEADING.match(line)
            if match:
                case_id = match.group(2)
                if not VALID_ID.match(case_id):
                    errors.append(f"{TEST_PLAN}:{no}: malformed test case heading '{line.strip()}' "
                                  "(expected '#### TP-xy: title' with two digits)")
                    continue
                if case_id in cases:
                    errors.append(f"{TEST_PLAN}:{no}: {case_id} is defined twice "
                                  f"(first in line {cases[case_id]['line']})")
                    continue
                current = cases[case_id] = {"line": no, "fields": {}}
                current_level = level
                last_field = None
            continue
        if current is None:
            continue
        field = FIELD_LINE.match(line)
        if field:
            name, text = field.group(1).strip(), field.group(2).strip()
            where = f"{TEST_PLAN}:{no}"
            if name not in FIELDS:
                errors.append(f"{where}: unknown field '{name}' (fields: {', '.join(FIELDS)})")
            elif name in current["fields"]:
                errors.append(f"{where}: field '{name}' appears twice")
            current["fields"][name] = text
            last_field = name
        elif last_field and line.startswith("  ") and line.strip():
            # continuation of the field above (indented lines, sub-lists, steps)
            current["fields"][last_field] = (current["fields"][last_field] + " " + line.strip()).strip()
    return cases


def status_of(case):
    """("ausgearbeitet" | "geplant" | "entfällt" | None, package number or None)."""
    status = case["fields"].get("Status", "")
    if status == "ausgearbeitet":
        return "ausgearbeitet", None
    match = re.fullmatch(r"geplant: S-WP(\d+)", status)
    if match:
        return "geplant", int(match.group(1))
    if re.fullmatch(r"entfällt: .{3,}", status):
        return "entfällt", None
    return None, None


def priority_of(case):
    """"P1" | "P2" | "P3", or None if the field is missing or not valid."""
    match = PRIORITY.fullmatch(case["fields"].get("Priorität", ""))
    return match.group(1) if match and match.group(1) in PRIORITIES else None


def check_cases(cases, errors):
    for case_id, case in sorted(cases.items()):
        where = f"{TEST_PLAN}:{case['line']}: {case_id}"
        kind, _ = status_of(case)
        if kind is None:
            errors.append(f"{where}: status '{case['fields'].get('Status', '')}' is not "
                          "'ausgearbeitet', 'geplant: S-WP<n>' or 'entfällt: <reason>'")
            continue
        required = FIELDS if kind == "ausgearbeitet" else REQUIRED_PLANNED
        for name in required:
            if not case["fields"].get(name):
                errors.append(f"{where}: field '{name}' is missing or empty "
                              f"(required for status '{kind}')")
        priority = case["fields"].get("Priorität")
        if priority and priority_of(case) is None:
            errors.append(f"{where}: priority '{priority}' is not P1, P2 or P3 (optionally "
                          "followed by a remark in parentheses)")


def section_table(lines, heading, errors):
    """(heading line, header, rows) of the first table after the first heading (outside code blocks)
    that contains `heading`, up to the next heading; rows are [(line, {column: text})]. Reports a
    missing heading and returns (None, None, [])."""
    start = None
    for no, line in outside_code(lines):
        if re.match(r"^#{2,6}\s.*" + re.escape(heading), line):
            start = no
            break
    if start is None:
        errors.append(f"{TEST_PLAN}: no section '{heading}' found")
        return None, None, []
    header, rows = None, []
    for no, line in enumerate(lines[start:], start + 1):
        if line.startswith("#"):
            break
        if not line.startswith("|"):
            if header is not None:
                break
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if header is None:
            header = cells
            continue
        if all(re.fullmatch(r":?-+:?", cell) for cell in cells):
            continue
        rows.append((no, dict(zip(header, cells))))
    return start, header, rows


def forum_table(lines, errors):
    """Rows of the first table after the heading "Forum-Testfälle": [(line, {column: text})]."""
    start, header, rows = section_table(lines, "Forum-Testfälle", errors)
    if start is None:
        return []
    if header is None or not {"Nr.", "Zuordnung", "Stand"} <= set(header):
        errors.append(f"{TEST_PLAN}:{start}: the forum table needs the columns 'Nr.', 'Zuordnung' "
                      "and 'Stand'")
        return []
    return rows


def short_run_table(lines, errors):
    """Rows of the first table after the heading "Kurzdurchlauf" (the P1 short run, section 7):
    [(line, {column: text})]."""
    start, header, rows = section_table(lines, "Kurzdurchlauf", errors)
    if start is None:
        return []
    if header is None or not {"Schritt", "Fälle", "Minuten"} <= set(header) or not rows:
        errors.append(f"{TEST_PLAN}:{start}: the short run needs a table with the columns "
                      "'Schritt', 'Fälle' and 'Minuten' and at least one step")
        return []
    return rows


def check_short_run(rows, cases, errors):
    """The short run names exactly the P1 cases, and its minutes add up to the row "Summe", which
    is at most MAX_SHORT_RUN_MINUTES. Returns the total (None if the table could not be read)."""
    if not rows:
        return None
    named = {}
    total = 0
    summe = None
    for no, row in rows:
        where = f"{TEST_PLAN}:{no}"
        step, minutes = row.get("Schritt", ""), row.get("Minuten", "")
        if not re.fullmatch(r"\d+", minutes):
            errors.append(f"{where}: short run step '{step}': 'Minuten' '{minutes}' is not a whole "
                          "number")
            continue
        if step == "Summe":
            if summe is not None:
                errors.append(f"{where}: the short run table has a second row 'Summe'")
            summe = (no, int(minutes))
            continue
        total += int(minutes)
        for digits in ID_REFERENCE.findall(row.get("Fälle", "")):
            named.setdefault("TP-" + digits, no)
    p1 = {case_id for case_id, case in cases.items() if priority_of(case) == "P1"}
    for case_id in sorted(p1 - set(named)):
        errors.append(f"{TEST_PLAN}:{cases[case_id]['line']}: {case_id} has the priority P1 but is "
                      "not in the short run table (section 'Kurzdurchlauf')")
    for case_id in sorted(set(named) - p1):
        if case_id in cases:
            errors.append(f"{TEST_PLAN}:{named[case_id]}: {case_id} is in the short run table but "
                          "its priority is not P1")
    if summe is None:
        errors.append(f"{TEST_PLAN}: the short run table has no row 'Summe'")
    else:
        if summe[1] != total:
            errors.append(f"{TEST_PLAN}:{summe[0]}: the row 'Summe' of the short run says "
                          f"{summe[1]} minutes, its steps add up to {total}")
        if total > MAX_SHORT_RUN_MINUTES:
            errors.append(f"{TEST_PLAN}:{summe[0]}: the short run takes {total} minutes, more than "
                          f"{MAX_SHORT_RUN_MINUTES} (three hours)")
    return total


def check_forum_table(rows, cases, errors):
    seen = {}
    for no, row in rows:
        where = f"{TEST_PLAN}:{no}"
        number_text = row.get("Nr.", "")
        if not number_text.isdigit():
            errors.append(f"{where}: forum test case number '{number_text}' is not a number")
            continue
        number = int(number_text)
        if number not in FORUM_NUMBERS:
            errors.append(f"{where}: forum test case {number} is not in 1 to 22")
        if number in seen:
            errors.append(f"{where}: forum test case {number} is listed twice (also line {seen[number]})")
            continue
        seen[number] = no
        assignment, stand = row.get("Zuordnung", ""), row.get("Stand", "")
        exclusion = EXCLUSION.search(assignment)
        assigned = assignment[:exclusion.start()] if exclusion else assignment
        ids = sorted(set("TP-" + digits for digits in ID_REFERENCE.findall(assigned)))
        if not ids:
            match = EXCLUSION.match(assignment)
            if not match or len(match.group(2)) < 10:
                errors.append(f"{where}: forum test case {number} has no test case id and no "
                              "'Launcher: <reason>' or 'entfällt: <reason>'")
            elif stand != match.group(1):
                errors.append(f"{where}: forum test case {number}: 'Stand' must be "
                              f"'{match.group(1)}', not '{stand}'")
            continue
        statuses = [status_of(cases[i]) for i in ids if i in cases]
        planned = {package for kind, package in statuses if kind == "geplant"}
        stand_packages = {int(n) for n in re.findall(r"S-WP(\d+)", stand)}
        expected = []
        if planned != stand_packages or (("geplant" in stand) != bool(planned)):
            expected.append("geplant: " + ", ".join(f"S-WP{n}" for n in sorted(planned)) if planned
                            else "no 'geplant'")
        for kind in ("ausgearbeitet", "entfällt"):
            if (kind in stand) != any(k == kind for k, _ in statuses):
                expected.append(f"'{kind}'" if any(k == kind for k, _ in statuses) else f"no '{kind}'")
        if expected:
            errors.append(f"{where}: forum test case {number}: 'Stand' '{stand}' does not match "
                          f"the status of {', '.join(ids)} (expected {'; '.join(expected)})")
    for number in FORUM_NUMBERS:
        if number not in seen:
            errors.append(f"{TEST_PLAN}: forum test case {number} is missing in the forum table")


def markdown_files(root):
    """Every Markdown file of the repository outside the asset, build and CI folders, sorted.
    Linked folders are not followed."""
    found = []
    for folder, subfolders, files in os.walk(root):
        if Path(folder) == root:
            subfolders[:] = [name for name in subfolders if name not in SKIPPED_FOLDERS]
        for name in files:
            if name.lower().endswith(".md"):
                path = Path(folder) / name
                found.append((path.relative_to(root).as_posix(), path))
    return sorted(found)


def check_references(root, cases, errors):
    count = 0
    files = 0
    for rel, path in markdown_files(root):
        try:
            text = path.read_text(encoding="utf-8-sig")
        except UnicodeDecodeError:
            errors.append(f"{rel}: not valid UTF-8")
            continue
        found = False
        for no, line in enumerate(text.splitlines(), 1):
            for match in ID_REFERENCE.finditer(line):
                found = True
                count += 1
                case_id = "TP-" + match.group(1)
                if len(match.group(1)) != 2:
                    errors.append(f"{rel}:{no}: malformed test case id '{case_id}' (two digits)")
                elif case_id not in cases:
                    errors.append(f"{rel}:{no}: {case_id} is not defined in {TEST_PLAN}")
        files += found
    return count, files


def check(root):
    errors = []
    path = root / TEST_PLAN
    if not path.is_file():
        return [f"{TEST_PLAN}: not found"], None
    try:
        lines = path.read_bytes().decode("utf-8").splitlines()
    except UnicodeDecodeError as error:
        return [f"{TEST_PLAN}: not valid UTF-8 (byte {error.start})"], None
    cases = parse_cases(lines, errors)
    check_cases(cases, errors)
    check_forum_table(forum_table(lines, errors), cases, errors)
    minutes = check_short_run(short_run_table(lines, errors), cases, errors)
    references, files = check_references(root, cases, errors)
    kinds = [status_of(case)[0] for case in cases.values()]
    priorities = [priority_of(case) for case in cases.values()]
    summary = (f"{TEST_PLAN}: OK ({len(cases)} test cases: {kinds.count('ausgearbeitet')} worked out, "
               f"{kinds.count('geplant')} planned, {kinds.count('entfällt')} dropped; "
               + ", ".join(f"{priorities.count(p)} {p}" for p in PRIORITIES)
               + f"; short run: the {priorities.count('P1')} P1 cases in {minutes} minutes"
               + f"; forum test cases 1 to 22 assigned; {references} id references in {files} "
               "Markdown files)")
    return errors, summary


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    options = {a for a in sys.argv[1:] if a.startswith("--")}
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


def self_test(source_root):
    """Runs this script against temporary copies of the Markdown files of the repository: the
    unmodified copy must pass, every modified copy must fail with the expected problem."""

    def edit(rel, old, new, count=1):
        def apply(root):
            path = root / rel
            text = path.read_text(encoding="utf-8")
            if text.count(old) < 1:
                raise AssertionError(f"self-test: '{old}' not found in {rel}")
            path.write_text(text.replace(old, new, count), encoding="utf-8")
        return apply

    def append(rel, text):
        def apply(root):
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            previous = path.read_text(encoding="utf-8") if path.exists() else ""
            path.write_text(previous + text, encoding="utf-8")
        return apply

    def forum_row(number):
        return re.compile(r"(?m)^\| " + str(number) + r" \|.*\n")

    def drop_row(number):
        def apply(root):
            path = root / TEST_PLAN
            text, n = forum_row(number).subn("", path.read_text(encoding="utf-8"))
            if n != 1:
                raise AssertionError(f"self-test: forum row {number} not found")
            path.write_text(text, encoding="utf-8")
        return apply

    def replace_row(number, row):
        def apply(root):
            path = root / TEST_PLAN
            text, n = forum_row(number).subn(row + "\n", path.read_text(encoding="utf-8"))
            if n != 1:
                raise AssertionError(f"self-test: forum row {number} not found")
            path.write_text(text, encoding="utf-8")
        return apply

    def duplicate_row(number):
        def apply(root):
            path = root / TEST_PLAN
            text = path.read_text(encoding="utf-8")
            row = forum_row(number).search(text).group(0)
            path.write_text(text.replace(row, row + row, 1), encoding="utf-8")
        return apply

    def short_run_row(step, change):
        """Replaces the cells of the row `step` of the short run table by change(cells)."""
        def apply(root):
            path = root / TEST_PLAN
            text = path.read_text(encoding="utf-8")
            match = re.search(r"(?m)^\| " + re.escape(step) + r" \|.*$", text)
            if not match:
                raise AssertionError(f"self-test: short run row {step} not found")
            cells = [cell.strip() for cell in match.group(0).strip().strip("|").split("|")]
            row = "| " + " | ".join(change(cells)) + " |"
            path.write_text(text[:match.start()] + row + text[match.end():], encoding="utf-8")
        return apply

    def add_minutes(cells, minutes):
        return cells[:-1] + [str(int(cells[-1]) + minutes)]

    def both(*changes):
        def apply(root):
            for change in changes:
                change(root)
        return apply

    # Ids that no document names (taken from the repository, so that a work package that adds a test case
    # does not collide with the synthetic ones): s[0] to s[2] are named without a definition, s[3] to s[8] are
    # defined by appended cases, s[9] is named by a forum row
    named = set()
    for _, path in markdown_files(source_root):
        named.update(re.findall(r"TP-(\d\d)(?!\d)", path.read_text(encoding="utf-8")))
    s = [f"TP-{number:02d}" for number in range(98, 9, -1) if f"{number:02d}" not in named][:10]
    adr = "docs/adr/0006-strict-tls-and-server-certificates.md"
    cases = [
        ("unmodified copy", None, None),
        ("test case id defined twice", append(TEST_PLAN, "\n#### TP-00: copy\n\n- **Status:** geplant: S-WP9\n- **Priorität:** P2\n"),
         "TP-00 is defined twice"),
        ("malformed test case heading", append(TEST_PLAN, "\n#### TP-7: one digit\n"),
         "malformed test case heading"),
        ("forum test case 22 missing", drop_row(22), "forum test case 22 is missing"),
        ("forum test case 5 listed twice", duplicate_row(5), "forum test case 5 is listed twice"),
        ("forum test case without assignment", replace_row(7, "| 7 | AoC | | geplant: S-WP9 |"),
         "forum test case 7 has no test case id"),
        ("forum test case 'Launcher' without reason", replace_row(12, "| 12 | Adapter | Launcher: | Launcher |"),
         "forum test case 12 has no test case id"),
        ("forum test case with a wrong package in 'Stand'",
         replace_row(3, "| 3 | Grafikmatrix | TP-21 | geplant: S-WP5 |"), "forum test case 3: 'Stand'"),
        ("forum test case naming an undefined id", replace_row(10, f"| 10 | Firewall | {s[9]} | geplant: S-WP3 |"),
         f"{s[9]} is not defined"),
        ("undefined id in the README", append("README.md", f"\nSee {s[0]}.\n"), "README.md:"),
        ("undefined id in ARCHITECTURE", append("docs/ARCHITECTURE.md", f"\nSee {s[1]}.\n"),
         "docs/ARCHITECTURE.md:"),
        ("undefined id in an ADR", append(adr, f"\nSee {s[2]}.\n"), f"{s[2]} is not defined"),
        ("malformed id in the CHANGELOG", append("CHANGELOG.md", "\nSee TP-100.\n"),
         "malformed test case id 'TP-100'"),
        ("worked-out case without 'Log-Hinweis'", edit(TEST_PLAN, "- **Log-Hinweis:** kein Setup-Log.", "Kein Setup-Log."),
         "TP-00: field 'Log-Hinweis' is missing"),
        # Appended cases, so that these two do not depend on which cases are still planned
        ("invalid status",
         append(TEST_PLAN, f"\n#### {s[3]}: x\n\n- **Status:** später\n- **Priorität:** P2\n- **Bezug:** x\n- **Ziel:** y\n"),
         f"{s[3]}: status 'später' is not 'ausgearbeitet'"),
        ("planned case with a misspelled field instead of 'Ziel'",
         append(TEST_PLAN, f"\n#### {s[4]}: x\n\n- **Status:** geplant: S-WP9\n- **Priorität:** P2\n- **Bezug:** x\n- **Zweck:** y\n"),
         f"{s[4]}: field 'Ziel' is missing"),
        # Priority (section 4): required for every case, P1 to P3 only
        ("worked-out case without 'Priorität'", edit(TEST_PLAN, "- **Status:** ausgearbeitet\n- **Priorität:** P1\n- **Bezug:** R16",
                                                    "- **Status:** ausgearbeitet\n- **Bezug:** R16"),
         "TP-00: field 'Priorität' is missing"),
        ("worked-out case with priority 'P4'", edit(TEST_PLAN, "- **Status:** ausgearbeitet\n- **Priorität:** P1\n- **Bezug:** R16",
                                                   "- **Status:** ausgearbeitet\n- **Priorität:** P4\n- **Bezug:** R16"),
         "TP-00: priority 'P4' is not P1, P2 or P3"),
        ("priority with text instead of a remark in parentheses",
         append(TEST_PLAN, f"\n#### {s[5]}: x\n\n- **Status:** geplant: S-WP9\n- **Priorität:** P1 wichtig\n- **Bezug:** x\n- **Ziel:** y\n"),
         f"{s[5]}: priority 'P1 wichtig' is not P1, P2 or P3"),
        ("planned case without 'Priorität'",
         append(TEST_PLAN, f"\n#### {s[6]}: x\n\n- **Status:** geplant: S-WP9\n- **Bezug:** x\n- **Ziel:** y\n"),
         f"{s[6]}: field 'Priorität' is missing"),
        ("priority with a remark in parentheses passes",
         append(TEST_PLAN, f"\n#### {s[7]}: x\n\n- **Status:** geplant: S-WP9\n- **Priorität:** P2 (P1 mit Weg B)\n- **Bezug:** x\n- **Ziel:** y\n"),
         None),
        # P1 short run (section 7): exactly the P1 cases, minutes that add up, at most three hours
        ("P1 case missing in the short run",
         append(TEST_PLAN, f"\n#### {s[8]}: x\n\n- **Status:** geplant: S-WP9\n- **Priorität:** P1\n- **Bezug:** x\n- **Ziel:** y\n"),
         f"{s[8]} has the priority P1 but is not in the short run table"),
        ("P2 case in the short run", short_run_row("K1", lambda cells: cells[:3] + [cells[3] + ", TP-12"] + cells[4:]),
         "TP-12 is in the short run table but its priority is not P1"),
        ("short run sum does not match", short_run_row("Summe", lambda cells: add_minutes(cells, -1)),
         "the row 'Summe' of the short run says"),
        ("short run longer than three hours",
         both(short_run_row("K1", lambda cells: add_minutes(cells, 200)),
              short_run_row("Summe", lambda cells: add_minutes(cells, 200))),
         "more than 180 (three hours)"),
        ("short run minutes not a number", short_run_row("K1", lambda cells: cells[:-1] + ["5-10"]),
         "is not a whole number"),
        ("short run section missing", edit(TEST_PLAN, "## 7. Kurzdurchlauf", "## 7. Ablauf"),
         "no section 'Kurzdurchlauf' found"),
        ("test plan missing", lambda root: (root / TEST_PLAN).unlink(), "not found"),
    ]
    failures = 0
    with tempfile.TemporaryDirectory(prefix="check_test_plan_selftest_") as temp:
        for number, (name, change, expected) in enumerate(cases):
            root = Path(temp) / f"case{number}"
            for rel, path in markdown_files(source_root):
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
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
    print(f"RESULT: {'PASS' if not failures else 'FAIL'} ({len(cases) - failures} of {len(cases)} cases)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
