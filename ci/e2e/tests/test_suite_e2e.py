#!/usr/bin/env python3
"""Rules of the end-to-end scenarios of the suite installer (job suite-e2e of .github/workflows/build.yml,
ci/e2e/run_e2e_suite.ps1) that their text must keep, read as text (the runner has no YAML library), and the
proof that no code of the suite touches the CD key registry. Each rule is a function that returns problems and
is tested against the real files (no problem) and against modified copies (the problem must be found), so the
check itself is checked.

  python -m unittest discover -s ci/e2e/tests -p "test_*.py"
"""
import os
import re
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
E2E = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(E2E))
WORKFLOW = os.path.join(REPO, ".github", "workflows", "build.yml")
SCENARIO_IDS = ["S%d" % n for n in range(1, 11)]


def read(*parts):
    with open(os.path.join(REPO, *parts), "rb") as handle:
        return handle.read().decode("utf-8-sig").replace("\r\n", "\n")


def job_block(workflow, name):
    """The text of a job of the workflow (from its header to the next job or the end), '' if there is none."""
    match = re.search(r"^  %s:\n(.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)" % re.escape(name), workflow, re.S | re.M)
    return match.group(0) if match else ""


def step_timeout(block, step_name):
    """timeout-minutes of the step with this name, None if it has none."""
    match = re.search(r"- name: %s\n(.*?)(?=^      - |\Z)" % re.escape(step_name), block, re.S | re.M)
    if not match:
        return None
    found = re.search(r"timeout-minutes: (\d+)", match.group(1))
    return int(found.group(1)) if found else None


def workflow_problems(workflow):
    """What the workflow must keep: the job, its independence of every download, the scenarios, the summary, the
    time limits and the artifacts that carry the placeholders from the job compile to the job suite-e2e."""
    problems = []
    job = job_block(workflow, "suite-e2e")
    if not job:
        return ["the job suite-e2e is missing"]
    if not re.search(r"^    needs: compile$", job, re.M):
        problems.append("suite-e2e must need compile (it takes the placeholder builds from there)")
    if not re.search(r"^    runs-on: windows-latest$", job, re.M):
        problems.append("suite-e2e must run on windows-latest")
    # no official download (r2.empireearth.eu blocks GitHub runners), no network access of the job itself
    for forbidden in ("r2.empireearth", "empireearth.eu", "curl", "Invoke-WebRequest", "Invoke-RestMethod", "E2E_OFFICIAL", "E2E_BUILD"):
        if forbidden in job:
            problems.append("suite-e2e must not use %s (no download, no official setup)" % forbidden)
    if "run_e2e_suite.ps1 -Scenario All" not in job:
        problems.append("suite-e2e must run run_e2e_suite.ps1 -Scenario All")
    report = re.search(r"- name: Job summary\n(.*?)(?=^      - |\Z)", job, re.S | re.M)
    if not report or "if: always()" not in report.group(1) or "-Scenario Report" not in report.group(1):
        problems.append("the step Job summary must run -Scenario Report and always")
    upload = re.search(r"- name: Upload the logs\n(.*?)(?=^      - |\Z)", job, re.S | re.M)
    if not upload or "if: always()" not in upload.group(1):
        problems.append("the step Upload the logs must always run")
    # the time limits: budget < step < job
    budget = re.search(r"-BudgetMinutes (\d+)", job)
    step = step_timeout(job, "Scenarios S1 to S10")
    total = re.search(r"^    timeout-minutes: (\d+)$", job, re.M)
    if not budget or step is None or not total:
        problems.append("suite-e2e needs -BudgetMinutes, a timeout of the scenario step and a timeout of the job")
    elif not int(budget.group(1)) < step < int(total.group(1)):
        problems.append("the limits must be budget < step < job, found %s, %s, %s" % (budget.group(1), step, total.group(1)))
    # the artifact of the inputs: uploaded by compile, downloaded by suite-e2e, under one name
    compile_job = job_block(workflow, "compile")
    uploaded = re.findall(r"upload-artifact@v4\n\s+with:\n\s+name: (\S+)", compile_job)
    downloaded = re.findall(r"download-artifact@v4\n\s+with:\n\s+name: (\S+)", job)
    if not downloaded:
        problems.append("suite-e2e must download the inputs from compile")
    for name in downloaded:
        if name not in uploaded:
            problems.append("suite-e2e downloads the artifact %s that compile does not upload" % name)
    if "-TestWrongEEPin" not in compile_job:
        problems.append("compile must build the suite with -TestWrongEEPin (scenario S5)")
    # the placeholder setups load EEStatsSetup.dll when they start: the stand-in must be in data\ before they are built
    stub = compile_job.find("build_eestats_stub.ps1")
    build = compile_job.find("- name: Build\n")
    if stub < 0 or build < 0 or stub > build:
        problems.append("compile must build the stand-in of EEStatsSetup.dll (build_eestats_stub.ps1) before the step Build")
    # the folders must lie below the temporary folder of the runner, not of the user (a package below %TEMP% is a ZIP view)
    if "RUNNER_TEMP" not in job:
        problems.append("the folders of the test must be below RUNNER_TEMP")
    return problems


def script_problems(helpers, runner, scenarios, titles_source):
    """The scripts: the ten scenarios everywhere, the default arguments of the product setups."""
    problems = []
    listed = re.search(r"Scenarios = @\(([^)]*)\)", helpers)
    if not listed or re.findall(r"'(S\d+)'", listed.group(1)) != SCENARIO_IDS:
        problems.append("e2e_suite_helpers.ps1: Scenarios must list S1 to S10 in order")
    for sid in SCENARIO_IDS:
        if not re.search(r"^  %s\s+= '" % sid, helpers, re.M):
            problems.append("e2e_suite_helpers.ps1: no title for %s" % sid)
        if "function Invoke-E2EScenario%s {" % sid not in scenarios:
            problems.append("e2e_suite_scenarios.ps1: no function for %s" % sid)
        if "'%s'" % sid not in runner:
            problems.append("run_e2e_suite.ps1: %s is not a valid scenario" % sid)
    for name in ("EEArgs", "NeoEEArgs"):
        value = re.search(r"^  %s\s+= '([^']*)'" % name, helpers, re.M)
        if not value:
            problems.append("e2e_suite_helpers.ps1: %s missing" % name)
            continue
        text = value.group(1)
        tasks = re.search(r"/TASKS=(\S+)", text)
        if not tasks:
            problems.append("%s: an exact /TASKS list is required" % name)
        else:
            for task in tasks.group(1).split(","):
                if task in ("neoee_cdkeys", "certinclude", "directplay", "dxwebsetup"):
                    problems.append("%s selects the task %s" % (name, task))
        merge = re.search(r"/MERGETASKS=(\S+)", text)
        merged = merge.group(1).split(",") if merge else []
        for task in merged:
            if task in ("neoee_cdkeys", "certinclude", "directplay", "dxwebsetup"):
                problems.append("%s merges the task %s without '!'" % (name, task))
        if name == "NeoEEArgs" and "!neoee_cdkeys" not in merged:
            problems.append("NeoEEArgs must name !neoee_cdkeys (the suite needs the decision in a silent run)")
        if "telemetry" in text.lower():
            problems.append("%s names the telemetry component" % name)
    if "Software\\Sierra" in scenarios.replace("Software\\\\Sierra", "") and "Remove-E2ERegTree" in scenarios:
        # only the snapshot reads the key; no scenario function deletes or writes below it
        for line in scenarios.splitlines():
            if "Sierra" in line and re.search(r"Remove-E2ERegTree|Remove-E2ERegValue|Set-E2ERegValue", line):
                problems.append("a scenario changes Software\\Sierra: %s" % line.strip())
    return problems


def sierra_problems():
    """Software\\Sierra (the CD keys) is never named in the code of the suite or of its build."""
    problems = []
    suite = os.path.join(REPO, "suite")
    for name in sorted(os.listdir(suite)):
        if name.endswith((".iss", ".ps1")):
            with open(os.path.join(suite, name), "rb") as handle:
                text = handle.read().decode("utf-8-sig")
            if re.search(r"Sierra", text, re.I):
                problems.append("suite/%s names Sierra" % name)
    return problems


class WorkflowRules(unittest.TestCase):
    def test_the_workflow_keeps_its_rules(self):
        self.assertEqual(workflow_problems(read(".github", "workflows", "build.yml")), [])

    def test_job_block_is_found(self):
        self.assertIn("suite-e2e:", job_block(read(".github", "workflows", "build.yml"), "suite-e2e"))
        self.assertEqual(job_block("jobs:\n  a:\n    x: 1\n", "b"), "")

    def mutated(self, old, new):
        text = read(".github", "workflows", "build.yml")
        self.assertIn(old, text, "the test needs this text in the workflow")
        return workflow_problems(text.replace(old, new, 1))

    def test_a_missing_job_is_found(self):
        self.assertEqual(workflow_problems("jobs:\n  compile:\n    runs-on: x\n"), ["the job suite-e2e is missing"])

    def test_no_dependency_on_compile_is_found(self):
        self.assertTrue(any("must need compile" in p for p in self.mutated("    needs: compile\n", "")))

    def test_a_download_is_found(self):
        found = self.mutated("      - name: Download the inputs\n", "      - name: Official setups\n        run: curl -o x https://r2.empireearth.eu/x\n      - name: Download the inputs\n")
        self.assertTrue(any("r2.empireearth" in p for p in found), found)
        self.assertTrue(any("curl" in p for p in found), found)

    def test_the_official_setups_are_found(self):
        self.assertTrue(any("E2E_OFFICIAL" in p for p in self.mutated("E2E_WORK=$root", "E2E_OFFICIAL=$root\\official\", \"E2E_WORK=$root")))

    def test_a_missing_summary_is_found(self):
        self.assertTrue(any("Job summary" in p for p in self.mutated("      - name: Job summary\n        if: always()\n", "      - name: Job summary\n")))

    def test_a_scenario_run_without_all_is_found(self):
        self.assertTrue(any("-Scenario All" in p for p in self.mutated("-Scenario All", "-Scenario S1")))

    def test_the_limits_must_be_ordered(self):
        self.assertTrue(any("budget < step < job" in p for p in self.mutated("-BudgetMinutes 120", "-BudgetMinutes 140")))

    def test_an_artifact_that_is_not_uploaded_is_found(self):
        text = read(".github", "workflows", "build.yml")
        head, tail = text.split("  suite-e2e:\n", 1)
        tail = tail.replace("name: suite-e2e-inputs", "name: other-inputs", 1)
        self.assertTrue(any("does not upload" in p for p in workflow_problems(head + "  suite-e2e:\n" + tail)))

    def test_the_wrong_pin_build_is_required(self):
        self.assertTrue(any("-TestWrongEEPin" in p for p in self.mutated("-Placeholders -TestWrongEEPin", "-Placeholders")))

    def test_the_stand_in_dll_is_required_before_the_build(self):
        found = self.mutated("        run: ./ci/e2e/build_eestats_stub.ps1", "        run: echo no stand-in")
        self.assertTrue(any("EEStatsSetup.dll" in p for p in found), found)
        text = read(".github", "workflows", "build.yml")
        step = "      - name: Stand-in of EEStatsSetup.dll for the placeholder setups\n        shell: pwsh\n        run: ./ci/e2e/build_eestats_stub.ps1 -OutFile data/Add-on/DLLs/EEStats/EEStatsSetup.dll\n\n"
        self.assertIn(step, text, "the test needs this step in the workflow")
        moved = text.replace(step, "", 1).replace("      - name: Upload the placeholder suite\n", step + "      - name: Upload the placeholder suite\n", 1)
        self.assertTrue(any("before the step Build" in p for p in workflow_problems(moved)))

    def test_the_folders_below_the_runner_temp(self):
        text = read(".github", "workflows", "build.yml")
        head, tail = text.split("  suite-e2e:\n", 1)
        self.assertTrue(any("RUNNER_TEMP" in p for p in workflow_problems(head + "  suite-e2e:\n" + tail.replace("RUNNER_TEMP", "TEMP"))))


class ScriptRules(unittest.TestCase):
    def files(self):
        return (read("ci", "e2e", "e2e_suite_helpers.ps1"), read("ci", "e2e", "run_e2e_suite.ps1"), read("ci", "e2e", "e2e_suite_scenarios.ps1"))

    def test_the_scripts_keep_their_rules(self):
        helpers, runner, scenarios = self.files()
        self.assertEqual(script_problems(helpers, runner, scenarios, helpers), [])

    def check(self, which, old, new):
        helpers, runner, scenarios = self.files()
        texts = {"helpers": helpers, "runner": runner, "scenarios": scenarios}
        self.assertIn(old, texts[which])
        texts[which] = texts[which].replace(old, new, 1)
        return script_problems(texts["helpers"], texts["runner"], texts["scenarios"], texts["helpers"])

    def test_a_forbidden_task_in_the_exact_list(self):
        found = self.check("helpers", "/TASKS=compatibility,compatibility_windows'\n  NeoEEArgs", "/TASKS=compatibility,neoee_cdkeys'\n  NeoEEArgs")
        self.assertTrue(any("selects the task neoee_cdkeys" in p for p in found), found)

    def test_a_forbidden_task_merged_without_a_bang(self):
        found = self.check("helpers", "!certinclude", "certinclude")
        self.assertTrue(any("merges the task certinclude" in p for p in found), found)

    def test_neoee_without_the_decision(self):
        found = self.check("helpers", "/MERGETASKS=!neoee_cdkeys,", "/MERGETASKS=")
        self.assertTrue(any("must name !neoee_cdkeys" in p for p in found), found)

    def test_a_scenario_missing_in_the_runner(self):
        found = self.check("runner", "'S7', ", "")
        self.assertTrue(any("S7 is not a valid scenario" in p for p in found), found)

    def test_a_scenario_function_missing(self):
        found = self.check("scenarios", "function Invoke-E2EScenarioS9 {", "function Invoke-E2EScenarioS9x {")
        self.assertTrue(any("no function for S9" in p for p in found), found)

    def test_a_missing_title(self):
        found = self.check("helpers", "  S4  = '", "  S4x = '")
        self.assertTrue(any("no title for S4" in p for p in found), found)

    def test_the_scripts_are_ascii_with_crlf(self):
        for name in ("e2e_suite_helpers.ps1", "e2e_suite_scenarios.ps1", "run_e2e_suite.ps1"):
            with open(os.path.join(E2E, name), "rb") as handle:
                data = handle.read()
            self.assertTrue(all(b < 128 for b in data), name + " is not ASCII")
            self.assertEqual(data.count(b"\n"), data.count(b"\r\n"), name + " has a line end that is not CRLF")


class SierraRule(unittest.TestCase):
    def test_no_suite_code_names_sierra(self):
        self.assertEqual(sierra_problems(), [])

    def test_the_rule_finds_a_mention(self):
        self.assertTrue(re.search(r"Sierra", "RegDeleteKeyIncludingSubkeys(HKLM, 'Software\\Sierra\\CDKeys')", re.I))


if __name__ == "__main__":
    unittest.main()
