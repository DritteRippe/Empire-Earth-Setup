/* Stand-in of EEStatsSetup.dll for the placeholder builds of CI (built by ci/e2e/build_eestats_stub.ps1 in the
   job compile of .github/workflows/build.yml). The real DLL is not in the repository, and the setups load it
   when they start (eestats.iss, no delayload): the dummy file of the placeholder generator stops them with
   "Cannot Import dll" (error 193) before they do anything, and the scenarios of the job suite-e2e run them.
   It has the six functions of eestats.iss with fixed answers: no virtual machine, no Wine, no known graphics
   card, a fixed id. The setups use them for their own decisions (Wine, the GPU option) and for the statistics
   values only. Test builds only: never in a release build, never shipped. */
#include <windows.h>

BOOL __cdecl EEStats_runInVM(void) { return FALSE; }
const char *__cdecl EEStats_getUID(void) { return "ci-placeholder"; }
BOOL __cdecl EEStats_isWine(void) { return FALSE; }
const char *__cdecl EEStats_getWineVersion(void) { return ""; }
const char *__cdecl EEStats_getProcessorArch(void) { return "x86"; }
const char *__cdecl EEStats_getGpuVendorId(void) { return ""; }
