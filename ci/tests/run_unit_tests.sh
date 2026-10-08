#!/bin/sh
# Compiles and runs ci/tests/unit_tests.iss with Inno Setup under Wine (Linux), like
# ci/run_unit_tests.ps1 does on Windows. Needs wine and, without a display, xvfb-run.
#   ISCC='C:\Program Files (x86)\Inno Setup 6\ISCC.exe' sh ci/tests/run_unit_tests.sh
# (ISCC is the Windows path of ISCC.exe inside the Wine prefix; WINEPREFIX is passed through.)
set -u
cd "$(dirname "$0")" || exit 2
ISCC="${ISCC:-C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe}"
RUN=""
[ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1 && RUN="xvfb-run -a"
rm -f out/unit_tests_result.txt
wine "$ISCC" /Q unit_tests.iss || { echo "FAIL: the unit test setup does not compile"; exit 1; }
$RUN wine out/unit_tests.exe /VERYSILENT /SUPPRESSMSGBOXES "/RESULTS=$(winepath -w out/unit_tests_result.txt)" \
  "/SAMPLES=$(winepath -w ../../docs/contract-samples)" 2>/dev/null
[ -f out/unit_tests_result.txt ] || { echo "FAIL: no results written"; exit 1; }
# the results file is UTF-8 with BOM
sed '1s/^\xEF\xBB\xBF//' out/unit_tests_result.txt | grep -v '^PASS '
tail -n 1 out/unit_tests_result.txt | grep -q '^RESULT: PASS'
