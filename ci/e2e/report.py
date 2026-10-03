#!/usr/bin/env python3
"""Turns the results of the real-data end-to-end test (results.jsonl, one JSON object per line:
scenario, check, status, details; written by ci/e2e/run_e2e.ps1) into a German/English Markdown
report for the job summary ($GITHUB_STEP_SUMMARY) and the uploaded report folder, and decides the
verdict.

Statuses: PASS, FAIL, WARN (a note that does not fail the job), SERVER (a community server did not
answer; the setup behaved correctly), SKIP, INFO. The job is red if any result is FAIL, a phase did
not finish (no DONE line) or the result file is missing.

Usage:
  report.py --results results.jsonl [--summary FILE] [--out report.md] [--context KEY=VALUE ...]
            [--phases Prepare A B E D C] [--verdict]
Exit code: 0; with --verdict 1 if the run failed.
"""
import argparse
import json
import os
import sys

PHASES = ["Prepare", "A", "B", "E", "D", "C"]

SCENARIOS = {
    "Prepare": ("Vorbereitung: Netzsperre, CD-Key-Attrappe, sauberer Runner",
                "Preparation: network block, CD key dummy, clean runner"),
    "A": ("EE für alle Benutzer, Deutsch, Downloads vom Spiegel",
          "EE for all users, German, downloads from the mirror"),
    "B": ("NeoEE nur für mich, Englisch, ohne CD-Key-Aufgabe",
          "NeoEE for the current user, English, without the CD key task"),
    "E": ("EE in eigenem Ordner neben einer fremden Installation",
          "EE in a custom folder next to a foreign installation"),
    "D": ("Link-Schutz (Exitcode 7) und Update ohne Wrapper",
          "Link guard (exit code 7) and update without the wrapper"),
    "C": ("Offizielles 1.7.2, v2 darüber, zurück, Schaden und Reparatur",
          "Official 1.7.2, v2 over it, back, damage and repair"),
}

BLOCKS = {
    "RUN": ("Setup-Lauf (Exitcode, Ende, Log)", "Setup run (exit code, end, log)"),
    "GPU": ("Grafikkarte und gewählter Wrapper", "Graphics card and the chosen wrapper"),
    "K1": ("Installationseintrag (Vertrag 1.1)", "Install record (contract 1.1)"),
    "K2": ("install.ini, Komponenten, Aufgaben (1.2)", "install.ini, components, tasks (1.2)"),
    "K3": ("Uninstall-Schlüssel (1.3)", "Uninstall key (1.3)"),
    "K4": ("Integritätsmanifest, neu gehasht (2.x)", "Integrity manifest, hashed again (2.x)"),
    "K4-rest": ("Dateien außerhalb des Manifests", "Files outside the manifest"),
    "K5": ("Spieleinstellungen (3.1-3.3)", "Game settings (3.1-3.3)"),
    "K6": ("GPU-Präferenz (3.4)", "GPU preference (3.4)"),
    "K7": ("Defaults-Marker (3.5)", "Defaults marker (3.5)"),
    "K8": ("Kompatibilitätswerte (3.7)", "Compatibility values (3.7)"),
    "K9": ("CD-Key-Attrappe unverändert (3.8)", "CD key dummy unchanged (3.8)"),
    "K10": ("Dateien und Datenschutz", "Files and privacy"),
    "K11": ("Firewall-Regeln", "Firewall rules"),
    "K12": ("Verknüpfungen", "Shortcuts"),
    "K13": ("Schreibrechte", "Write permissions"),
    "K14": ("Setup-Log", "Setup log"),
    "K14-stats": ("Statistik-Zeile", "Statistics line"),
    "K15": ("Kein Netz ohne Downloads", "No network without downloads"),
    "DL": ("Downloads vom Spiegel, Pins, Manifest", "Downloads from the mirror, pins, manifest"),
    "TP-00": ("Server-Vorabprüfung", "Server pre-check"),
    "NET": ("Netzsperre wirksam", "Network block holds"),
    "L": ("Launcher-Kern gegen die echte Installation", "Launcher core against the real installation"),
    "L-K9": ("CD-Key-Attrappe nach dem Launcher", "CD key dummy after the launcher"),
    "U": ("Deinstallation und Reste", "Uninstallation and leftovers"),
    "CLEAN": ("Sauberer Ausgangszustand", "Clean starting state"),
    "FOREIGN": ("Hinweis auf fremde Installation", "Notice of a foreign installation"),
    "SEEDS": ("Testeinträge unverändert", "Test entries unchanged"),
    "LINK": ("Link-Schutz", "Link guard"),
    "LEGACY": ("Zustand des offiziellen 1.7.2", "State of the official 1.7.2"),
    "COMP": ("Komponenten von 1.7.2 übernommen", "Components of 1.7.2 kept"),
    "COMPAT": ("Alte RUNASADMIN-Werte entfernt", "Old RUNASADMIN values removed"),
    "RMS": ("Zufallskarten von 1.7.2", "Random maps of 1.7.2"),
    "RMS-backup": ("Sicherung der Zufallskarten", "Backup of the random maps"),
    "CERT": ("Kein Zertifikat vertraut", "No certificate trusted"),
    "E": ("Installation aus Szenario E", "Installation of scenario E"),
    "state": ("Zustand vor dem Update", "State before the update"),
    "targets": ("Gewählte Dateien", "Chosen files"),
    "inputs": ("Eingaben vorhanden", "Inputs present"),
    "firewall-service": ("Firewall-Dienst", "Firewall service"),
    "runner": ("Runner", "Runner"),
    "aborted": ("Abgebrochen", "Aborted"),
    "damage": ("Schadensfälle", "Damage steps"),
    "DONE": ("Phase beendet", "Phase finished"),
}

STATUS = {
    "PASS": "PASS",
    "FAIL": "**FAIL**",
    "WARN": "**WARN**",
    "SERVER": "*SERVER*",
    "SKIP": "SKIP",
    "INFO": "INFO",
}


def title(check):
    """German / English title of a check id '<step>/<block>' or '<block>'."""
    block = check.split("/")[-1]
    de, en = BLOCKS.get(block, (block, block))
    return de if de == en else f"{de} / {en}"


def cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ").replace("<", "&lt;").replace(">", "&gt;")


def load(path):
    results, problems = [], []
    if not os.path.isfile(path):
        return results, [f"result file missing: {path}"]
    with open(path, encoding="utf-8") as fh:
        for no, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
                results.append({"scenario": str(item["scenario"]), "check": str(item["check"]),
                                "status": str(item["status"]), "details": [str(d) for d in item.get("details") or []]})
            except (ValueError, KeyError, TypeError) as ex:
                problems.append(f"line {no} of the result file is not valid: {ex}")
    return results, problems


def verdict(results, problems, phases):
    """(passed, reasons) of the run."""
    reasons = list(problems)
    failed = [r for r in results if r["status"] == "FAIL"]
    if failed:
        reasons.append(f"{len(failed)} check(s) failed")
    done = {r["scenario"] for r in results if r["check"] == "DONE"}
    for phase in phases:
        if phase not in done:
            reasons.append(f"phase {phase} did not run to its end")
    return not reasons, reasons


def render(results, problems, phases, context):
    passed, reasons = verdict(results, problems, phases)
    counts = {}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    out = ["# Ende-zu-Ende-Test mit echten Daten / Real-data end-to-end test", ""]
    if passed:
        out.append("**Ergebnis / Result: ✅ BESTANDEN / PASSED**")
    else:
        out.append("**Ergebnis / Result: ❌ FEHLGESCHLAGEN / FAILED**: " + "; ".join(cell(r) for r in reasons))
    out.append("")
    out.append(" · ".join(f"{STATUS.get(s, s)}: {counts[s]}" for s in STATUS if s in counts) or "keine Ergebnisse / no results")
    out.append("")
    if context:
        out += ["| Angabe / Item | Wert / Value |", "|---|---|"]
        out += [f"| {cell(k)} | {cell(v)} |" for k, v in context]
        out.append("")
    out += ["Keine Spieldaten verlassen den Runner: hochgeladen werden nur Logs und dieser Bericht. "
            "/ No game data leaves the runner: only logs and this report are uploaded.", ""]
    order = phases + sorted({r["scenario"] for r in results} - set(phases))
    for phase in order:
        rows = [r for r in results if r["scenario"] == phase and r["check"] != "DONE"]
        de, en = SCENARIOS.get(phase, (phase, phase))
        out.append(f"## {phase}: {de} / {en}")
        out.append("")
        if not any(r["scenario"] == phase and r["check"] == "DONE" for r in results):
            out.append("❌ **Nicht vollständig gelaufen / did not run to its end**")
            out.append("")
        if not rows:
            continue
        out += ["| Schritt / Step | Prüfung / Check | Ergebnis / Result | Details |", "|---|---|---|---|"]
        for r in rows:
            step = r["check"].rsplit("/", 1)[0] if "/" in r["check"] else ""
            details = "<br>".join(cell(d) for d in r["details"][:6])
            if len(r["details"]) > 6:
                details += f"<br>… (+{len(r['details']) - 6})"
            out.append(f"| {cell(step)} | {cell(title(r['check']))} | {STATUS.get(r['status'], cell(r['status']))} | {details} |")
        out.append("")
    return "\n".join(out) + "\n", passed


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results", required=True)
    ap.add_argument("--summary", help="append the report here (GITHUB_STEP_SUMMARY)")
    ap.add_argument("--out", help="write the report to this file")
    ap.add_argument("--context", nargs="*", default=[], help="KEY=VALUE rows of the head table")
    ap.add_argument("--phases", nargs="*", default=PHASES)
    ap.add_argument("--verdict", action="store_true", help="exit code 1 if the run failed")
    a = ap.parse_args(argv)
    results, problems = load(a.results)
    context = [tuple(item.split("=", 1)) for item in a.context if "=" in item]
    text, passed = render(results, problems, a.phases, context)
    if a.out:
        with open(a.out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
    if a.summary:
        with open(a.summary, "a", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
    if a.verdict:
        _, reasons = verdict(results, problems, a.phases)
        for reason in reasons:
            print("FAILED:", reason)
        if passed:
            print(f"PASSED: {len(results)} results, no failure")
        return 0 if passed else 1
    print(f"report: {len(results)} results, {'passed' if passed else 'failed'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
