; Unit tests of the [Code] helpers without wizard access (utils.iss), including the download
; policy of the online localized files, the install state for the launcher and its integrity
; manifest.
;
; A tiny setup that includes utils.iss, runs every test in InitializeSetup, writes the results to
; a text file and exits without installing anything (InitializeSetup returns False). It sends no
; request and needs no network: only functions that compute something are tested, plus one run-time
; test that sets the TLS protocol option on a WinHttpRequest object without sending anything, and
; file-level tests that write state files (install.ini, files.sha256) for files they create in a
; folder of their own temporary folder ({tmp}).
;
; Build and run (ci/run_unit_tests.ps1 does both and checks the result):
;   ISCC ci\tests\unit_tests.iss
;   ci\tests\out\unit_tests.exe /VERYSILENT /SUPPRESSMSGBOXES /RESULTS=<file>
; The last line of <file> is "RESULT: PASS (<n> tests)" or "RESULT: FAIL (<k> of <n> tests)".

; utils.iss needs these from the product configuration (config_*.iss); any GUIDs will do
#define AppID "11111111-2222-3333-4444-555555555555"
#define OtherAppID "66666666-7777-8888-9999-000000000000"

[Setup]
AppName=Empire Earth Setup unit tests
AppVersion=1
DefaultDirName={tmp}\unit_tests
OutputDir=out
OutputBaseFilename=unit_tests
Uninstallable=no
PrivilegesRequired=lowest
CreateAppDir=no

#include "..\..\utils.iss"

[Code]
// For the file-level test of the state files: a read-only file (FILE_ATTRIBUTE_* are constants of
// Inno Setup's Pascal Script)
function SetFileAttributes(lpFileName: String; dwFileAttributes: Cardinal): BOOL;
  external 'SetFileAttributesW@kernel32.dll stdcall';
// For the file-level test of the manifest: a file held open without sharing, as a virus scanner may
// hold a file it checks
function CreateFile(lpFileName: String; dwDesiredAccess, dwShareMode, lpSecurityAttributes,
  dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile: Cardinal): Cardinal;
  external 'CreateFileW@kernel32.dll stdcall';
function CloseHandle(hObject: Cardinal): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';

const
  GENERIC_READ = $80000000;
  OPEN_EXISTING = 3;
  INVALID_HANDLE_VALUE = $FFFFFFFF;

var
  Results: TStringList;
  Failures: Integer;

procedure Check(const Name: String; const Actual, Expected: String);
begin
  if Actual = Expected then
    Results.Add('PASS ' + Name)
  else
  begin
    Failures := Failures + 1;
    Results.Add('FAIL ' + Name + ': got "' + Actual + '", expected "' + Expected + '"');
  end;
end;

procedure CheckBool(const Name: String; const Actual, Expected: Boolean);
var
  A, E: String;
begin
  A := 'False';
  if Actual then
    A := 'True';
  E := 'False';
  if Expected then
    E := 'True';
  Check(Name, A, E);
end;

function Joined(const Items: TArrayOfString): String;
var
  I: Integer;
begin
  Result := IntToStr(GetArrayLength(Items)) + ':';
  for I := 0 to GetArrayLength(Items) - 1 do
    Result := Result + '[' + Items[I] + ']';
end;

procedure TestStrSplit;
begin
  Check('StrSplit three items', Joined(StrSplit('a,b,c', ',')), '3:[a][b][c]');
  Check('StrSplit no separator', Joined(StrSplit('abc', ',')), '1:[abc]');
  Check('StrSplit empty item', Joined(StrSplit('a,,b', ',')), '3:[a][][b]');
  Check('StrSplit trailing separator', Joined(StrSplit('a,', ',')), '1:[a]');
  Check('StrSplit empty text', Joined(StrSplit('', ',')), '1:[]');
  Check('StrSplit long separator', Joined(StrSplit('x, y, z', ', ')), '3:[x][y][z]');
end;

procedure TestLanguageTag;
begin
  Check('GetLanguageTag pt_BR', GetLanguageTag('pt_BR'), 'pt-BR');
  Check('GetLanguageTag zh_TW', GetLanguageTag('zh_TW'), 'zh-TW');
  Check('GetLanguageTag de', GetLanguageTag('de'), 'de');
end;

procedure TestCompatibilityFlags;
begin
  Check('BuildCompatibilityFlags none', BuildCompatibilityFlags(False, False), '~');
  Check('BuildCompatibilityFlags admin', BuildCompatibilityFlags(True, False), '~ RUNASADMIN');
  Check('BuildCompatibilityFlags compatibility', BuildCompatibilityFlags(False, True),
    '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation');
  Check('BuildCompatibilityFlags both', BuildCompatibilityFlags(True, True),
    '~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation');
end;

procedure TestIsBelowWindows8;
begin
  CheckBool('IsBelowWindows8 XP 5.1', IsBelowWindows8(5, 1), True);
  CheckBool('IsBelowWindows8 Vista 6.0', IsBelowWindows8(6, 0), True);
  CheckBool('IsBelowWindows8 Windows 7 6.1', IsBelowWindows8(6, 1), True);
  CheckBool('IsBelowWindows8 Windows 8 6.2', IsBelowWindows8(6, 2), False);
  CheckBool('IsBelowWindows8 Windows 8.1 6.3', IsBelowWindows8(6, 3), False);
  CheckBool('IsBelowWindows8 Windows 10/11 10.0', IsBelowWindows8(10, 0), False);
end;

procedure CheckLegacyVista(const Kind, Value: String; const Expected: Boolean);
begin
  CheckBool('IsLegacyVistaCompatValue ' + Kind + ' "' + Value + '"', IsLegacyVistaCompatValue(Value), Expected);
end;

// The values setups up to 1.7.2 and the refactor branch wrote on Windows Vista/7 that the cleanup
// removes, and values it must never remove (contract 3.7, ADR 0005)
procedure TestIsLegacyVistaCompatValue;
var
  I: Integer;
  RunAsAdmin, Compatibility: Boolean;
  Flags: String;
begin
  // Every combination of the tasks, built like the old [Registry] entries: with the Windows XP SP3
  // mode always, without it only if the flags of the task compatibility are in the value
  for I := 0 to 3 do
  begin
    RunAsAdmin := (I and 1) <> 0;
    Compatibility := (I and 2) <> 0;
    Flags := BuildCompatibilityFlags(RunAsAdmin, Compatibility);
    CheckLegacyVista('combination', Flags + ' WINXPSP3', True);
    CheckLegacyVista('combination', Flags, Compatibility);
  end;
  // The same six values written out, so that a change of BuildCompatibilityFlags shows here
  CheckLegacyVista('old value', '~ WINXPSP3', True);
  CheckLegacyVista('old value', '~ RUNASADMIN WINXPSP3', True);
  CheckLegacyVista('old value', '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation', True);
  CheckLegacyVista('old value', '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3', True);
  CheckLegacyVista('old value', '~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation', True);
  CheckLegacyVista('old value', '~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3', True);
  // Never removed: no flags (the opt-in RUNASADMIN of this setup), values of the player, of
  // Windows 8 and later, empty, other case, order or spacing
  CheckLegacyVista('kept', '~', False);
  CheckLegacyVista('kept', '~ RUNASADMIN', False);
  CheckLegacyVista('kept', '~ WINXPSP3 DISABLEDWM', False);
  CheckLegacyVista('kept', '', False);
  CheckLegacyVista('kept', '~ winxpsp3', False);
  CheckLegacyVista('kept', '~ WinXPSP3', False);
  CheckLegacyVista('kept', '~ dwm8and16bitmitigation highdpiaware heapclearallocation', False);
  CheckLegacyVista('kept', '~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation winxpsp3', False);
  CheckLegacyVista('kept', '~ HIGHDPIAWARE DWM8And16BitMitigation HeapClearAllocation WINXPSP3', False);
  CheckLegacyVista('kept', '~ WINXPSP3 RUNASADMIN', False);
  CheckLegacyVista('kept', '~  WINXPSP3', False);
  CheckLegacyVista('kept', '~ WINXPSP3 ', False);
  CheckLegacyVista('kept', 'WINXPSP3', False);
  CheckLegacyVista('kept', '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WIN7RTM', False);
  CheckLegacyVista('kept', '~ WIN7RTM', False);
end;

procedure CheckRemoveLegacy(const Value: String; const LegacyOptIn, ProgramSelected, Expected: Boolean);
var
  Task, Component: String;
begin
  Task := 'task not selected';
  if LegacyOptIn then
    Task := 'task selected';
  Component := 'component not selected';
  if ProgramSelected then
    Component := 'component selected';
  CheckBool('ShouldRemoveLegacyVistaCompatValue ' + Task + ', ' + Component + ' "' + Value + '"',
    ShouldRemoveLegacyVistaCompatValue(Value, LegacyOptIn, ProgramSelected), Expected);
end;

// Old values: removed unless this run wrote the value of the program (task and component selected)
procedure CheckRemoveLegacyOld(const Values: array of String);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(Values) - 1 do
  begin
    CheckRemoveLegacy(Values[I], True, True, False);
    // Task selected, but not the component of this program: the old value of that program goes
    CheckRemoveLegacy(Values[I], True, False, True);
    // Task not selected: removed whether the program is installed or not
    CheckRemoveLegacy(Values[I], False, True, True);
    CheckRemoveLegacy(Values[I], False, False, True);
  end;
end;

// Values that are not old values: never removed
procedure CheckRemoveLegacyKept(const Values: array of String);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(Values) - 1 do
  begin
    CheckRemoveLegacy(Values[I], True, True, False);
    CheckRemoveLegacy(Values[I], True, False, False);
    CheckRemoveLegacy(Values[I], False, True, False);
    CheckRemoveLegacy(Values[I], False, False, False);
  end;
end;

// The cleanup on Windows Vista/7 keeps the value that the opt-in task compatibility_legacy writes
// in this run for a selected program, and removes the old values otherwise (ADR 0010)
procedure TestShouldRemoveLegacyVistaCompatValue;
begin
  // All six old values
  CheckRemoveLegacyOld(['~ WINXPSP3', '~ RUNASADMIN WINXPSP3',
    '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation',
    '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3',
    '~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation',
    '~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3']);
  // The two values the task itself writes (with and without everyoneadminstart) are among the
  // old ones: kept only with task and component
  CheckRemoveLegacy(BuildCompatibilityFlags(False, True), True, True, False);
  CheckRemoveLegacy(BuildCompatibilityFlags(True, True), True, True, False);
  CheckRemoveLegacy(BuildCompatibilityFlags(False, True), False, True, True);
  CheckRemoveLegacy(BuildCompatibilityFlags(True, True), True, False, True);
  // Values that are not old values stay in every case
  CheckRemoveLegacyKept(['~', '~ RUNASADMIN', '~ WINXPSP3 DISABLEDWM', '',
    '~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WIN7RTM']);
end;

procedure TestUninstallKeys;
begin
  Check('GetUninstallRegPath', GetUninstallRegPath(),
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{11111111-2222-3333-4444-555555555555}_is1');
  Check('GetOtherProductUninstallRegPath', GetOtherProductUninstallRegPath(),
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{66666666-7777-8888-9999-000000000000}_is1');
end;

procedure TestUrlEncode;
begin
  Check('UrlEncode unreserved', UrlEncode('AZaz09-_.~'), 'AZaz09-_.~');
  Check('UrlEncode reserved', UrlEncode('a b&c=d?e/f+g%'), 'a%20b%26c%3Dd%3Fe%2Ff%2Bg%25');
  Check('UrlEncode 2-byte UTF-8', UrlEncode(#$E9), '%C3%A9');
  Check('UrlEncode 3-byte UTF-8', UrlEncode(#$20AC), '%E2%82%AC');
  Check('UrlEncode surrogate pair', UrlEncode(#$D83D#$DE00), '%F0%9F%98%80');
  Check('UrlEncode lone surrogate', UrlEncode('a' + #$D800 + 'b'), 'a%EF%BF%BDb');
  Check('UrlEncode empty', UrlEncode(''), '');
end;

procedure CheckSplit(const Url: String; const ExpectedOk: Boolean; const ExpectedHost, ExpectedPath: String);
var
  Host, Path: String;
  Ok: Boolean;
begin
  Ok := SplitHttpsUrl(Url, Host, Path);
  CheckBool('SplitHttpsUrl ' + Url, Ok, ExpectedOk);
  if Ok and ExpectedOk then
    Check('SplitHttpsUrl parts ' + Url, Host + ' ' + Path, ExpectedHost + ' ' + ExpectedPath);
end;

procedure TestSplitHttpsUrl;
begin
  CheckSplit('https://empireearth.eu/download', True, 'empireearth.eu', '/download');
  CheckSplit('HTTPS://Files.EmpireEarth.EU', True, 'files.empireearth.eu', '/');
  CheckSplit('https://empireearth.eu?x=1', True, 'empireearth.eu', '?x=1');
  CheckSplit('https://empireearth.eu#top', True, 'empireearth.eu', '#top');
  CheckSplit('http://empireearth.eu/', False, '', '');
  CheckSplit('https://', False, '', '');
  CheckSplit('https://user@empireearth.eu/', False, '', '');
  CheckSplit('https://empireearth.eu:8443/', False, '', '');
  CheckSplit('https://empireearth.eu\@evil.example/', False, '', '');
  CheckSplit('https://empire earth.eu/', False, '', '');
  CheckSplit('https://empireearth.eu/a' + #9 + 'b', False, '', '');
  CheckSplit('https://empireearth.eu/' + #$E9, False, '', '');
end;

procedure TestIsDomainOrSubdomain;
begin
  CheckBool('IsDomainOrSubdomain same', IsDomainOrSubdomain('empireearth.eu', 'empireearth.eu'), True);
  CheckBool('IsDomainOrSubdomain subdomain', IsDomainOrSubdomain('files.empireearth.eu', 'empireearth.eu'), True);
  CheckBool('IsDomainOrSubdomain suffix only', IsDomainOrSubdomain('evilempireearth.eu', 'empireearth.eu'), False);
  CheckBool('IsDomainOrSubdomain prefix only', IsDomainOrSubdomain('empireearth.eu.evil.example', 'empireearth.eu'), False);
  CheckBool('IsDomainOrSubdomain dot only', IsDomainOrSubdomain('.empireearth.eu', 'empireearth.eu'), False);
end;

procedure TestIsAllowedUpdateUrl;
begin
  CheckBool('IsAllowedUpdateUrl website', IsAllowedUpdateUrl('https://empireearth.eu/download'), True);
  CheckBool('IsAllowedUpdateUrl website subdomain', IsAllowedUpdateUrl('https://files.empireearth.eu/setup.exe'), True);
  CheckBool('IsAllowedUpdateUrl NeoEE', IsAllowedUpdateUrl('https://www.neoee.net/download'), True);
  CheckBool('IsAllowedUpdateUrl GitHub project', IsAllowedUpdateUrl('https://github.com/EE-modders/Empire-Earth-Setup/releases'), True);
  CheckBool('IsAllowedUpdateUrl GitHub other', IsAllowedUpdateUrl('https://github.com/someone/Empire-Earth-Setup/releases'), False);
  CheckBool('IsAllowedUpdateUrl GitHub dot segment', IsAllowedUpdateUrl('https://github.com/EE-modders/../someone/x'), False);
  CheckBool('IsAllowedUpdateUrl GitHub escape', IsAllowedUpdateUrl('https://github.com/EE-modders/%2e%2e/someone/x'), False);
  CheckBool('IsAllowedUpdateUrl GitHub root', IsAllowedUpdateUrl('https://github.com/'), False);
  CheckBool('IsAllowedUpdateUrl mirror', IsAllowedUpdateUrl('https://storage.ee.zocker-160.de/setup.exe'), False);
  CheckBool('IsAllowedUpdateUrl http', IsAllowedUpdateUrl('http://empireearth.eu/download'), False);
  CheckBool('IsAllowedUpdateUrl look-alike', IsAllowedUpdateUrl('https://empireearth.eu.evil.example/'), False);
  CheckBool('IsAllowedUpdateUrl user info', IsAllowedUpdateUrl('https://empireearth.eu@evil.example/'), False);
  CheckBool('IsAllowedUpdateUrl empty', IsAllowedUpdateUrl(''), False);
end;

procedure TestFileNameExtension;
begin
  Check('GetFileNameExtension name', GetFileNameExtension('Language.dll'), 'dll');
  Check('GetFileNameExtension server path', GetFileNameExtension('Game/de/EE/Language.DLL'), 'dll');
  Check('GetFileNameExtension target path', GetFileNameExtension('EE\Data\WONLobby Resources\_WONStatus.cfg'), 'cfg');
  Check('GetFileNameExtension space in name', GetFileNameExtension('EE\Data\Movies\Empire Earth.bik'), 'bik');
  Check('GetFileNameExtension double', GetFileNameExtension('a/data.ssa.exe'), 'exe');
  Check('GetFileNameExtension trailing dot', GetFileNameExtension('Language.dll.'), 'dll');
  Check('GetFileNameExtension trailing dots and spaces', GetFileNameExtension('Language.dll . '), 'dll');
  Check('GetFileNameExtension dot only in folder', GetFileNameExtension('Data.v2/readme'), '');
  Check('GetFileNameExtension none', GetFileNameExtension('Data/README'), '');
  Check('GetFileNameExtension empty', GetFileNameExtension(''), '');
end;

procedure TestIsCodeFileName;
begin
  CheckBool('IsCodeFileName Language.dll', IsCodeFileName('Game/de/EE/Language.dll'), True);
  CheckBool('IsCodeFileName upper case', IsCodeFileName('EE\LANGUAGE.DLL'), True);
  CheckBool('IsCodeFileName trailing dot', IsCodeFileName('EE\Language.dll.'), True);
  CheckBool('IsCodeFileName exe', IsCodeFileName('Empire Earth.exe'), True);
  CheckBool('IsCodeFileName asi', IsCodeFileName('mod.asi'), True);
  CheckBool('IsCodeFileName ocx', IsCodeFileName('x.ocx'), True);
  CheckBool('IsCodeFileName sys', IsCodeFileName('x.sys'), True);
  CheckBool('IsCodeFileName scr', IsCodeFileName('x.scr'), True);
  CheckBool('IsCodeFileName bat', IsCodeFileName('x.bat'), True);
  CheckBool('IsCodeFileName cmd', IsCodeFileName('x.cmd'), True);
  CheckBool('IsCodeFileName com', IsCodeFileName('x.com'), True);
  CheckBool('IsCodeFileName ps1', IsCodeFileName('x.ps1'), True);
  CheckBool('IsCodeFileName vbs', IsCodeFileName('x.vbs'), True);
  CheckBool('IsCodeFileName js', IsCodeFileName('x.js'), True);
  CheckBool('IsCodeFileName msi', IsCodeFileName('x.msi'), True);
  CheckBool('IsCodeFileName cpl', IsCodeFileName('x.cpl'), True);
  CheckBool('IsCodeFileName lnk', IsCodeFileName('x.lnk'), True);
  CheckBool('IsCodeFileName reg', IsCodeFileName('x.reg'), True);
  CheckBool('IsCodeFileName Miles filter', IsCodeFileName('redist\win32\Parmeq.flt'), True);
  CheckBool('IsCodeFileName Miles 3D provider', IsCodeFileName('redist\win32\Mssds3d.M3D'), True);
  CheckBool('IsCodeFileName alternate data stream', IsCodeFileName('EE\WONLobby.cfg:x.exe'), True);
  CheckBool('IsCodeFileName separator in extension', IsCodeFileName('x.exe|dll'), True);
  CheckBool('IsCodeFileName data.ssa', IsCodeFileName('Game/de/EE/Data/data.ssa'), False);
  CheckBool('IsCodeFileName campaign', IsCodeFileName('EE\Data\Campaigns\EETheBritish.ssa'), False);
  CheckBool('IsCodeFileName movie', IsCodeFileName('EE\Data\Movies\Empire Earth.bik'), False);
  CheckBool('IsCodeFileName lobby cfg', IsCodeFileName('Lobby/de/EE/WONLobby.cfg'), False);
  CheckBool('IsCodeFileName prefix of an extension', IsCodeFileName('x.ex'), False);
  CheckBool('IsCodeFileName extension inside a longer one', IsCodeFileName('x.dlls'), False);
  CheckBool('IsCodeFileName no extension', IsCodeFileName('Data/README'), False);
end;

procedure TestIsHttpsUrl;
begin
  CheckBool('IsHttpsUrl https', IsHttpsUrl('https://files.empireearth.eu/localized/Game/de/EE/Data/data.ssa'), True);
  CheckBool('IsHttpsUrl upper case', IsHttpsUrl('HTTPS://files.empireearth.eu/x'), True);
  CheckBool('IsHttpsUrl space in path', IsHttpsUrl('https://files.empireearth.eu/localized/Game/de/EE/Data/Movies/Empire Earth.bik'), True);
  CheckBool('IsHttpsUrl http', IsHttpsUrl('http://files.empireearth.eu/x'), False);
  CheckBool('IsHttpsUrl ftp', IsHttpsUrl('ftp://files.empireearth.eu/x'), False);
  CheckBool('IsHttpsUrl scheme only', IsHttpsUrl('https://'), False);
  CheckBool('IsHttpsUrl no scheme', IsHttpsUrl('files.empireearth.eu/x'), False);
  CheckBool('IsHttpsUrl leading space', IsHttpsUrl(' https://files.empireearth.eu/x'), False);
  CheckBool('IsHttpsUrl empty', IsHttpsUrl(''), False);
end;

// The servers of the online files must be https: data files without SHA-256 are only accepted
// from https URLs
procedure TestOnlineFilesServers;
var
  Host, Path: String;
begin
  CheckBool('OnlineFilesURL is https', IsHttpsUrl(OnlineFilesURL) and SplitHttpsUrl(OnlineFilesURL, Host, Path), True);
  CheckBool('OnlineFilesMirrorURL is https', IsHttpsUrl(OnlineFilesMirrorURL) and SplitHttpsUrl(OnlineFilesMirrorURL, Host, Path), True);
end;

procedure TestOnlineFileCheck;
var
  Pin: String;
begin
  Pin := '899f5196c68a6d9529d662ef6728539ec9935581eff6a5c3db32d339f81cd34e';
  Check('GetOnlineFileCheck code with pin', IntToStr(GetOnlineFileCheck('EE\Language.dll', Pin, 'https://h/Game/de/EE/Language.dll')), IntToStr(OnlineFilePinned));
  Check('GetOnlineFileCheck code without pin', IntToStr(GetOnlineFileCheck('EE\Language.dll', '', 'https://h/Game/de/EE/Language.dll')), IntToStr(OnlineFileRefusedCode));
  Check('GetOnlineFileCheck code without pin over http', IntToStr(GetOnlineFileCheck('EE\Language.dll', '', 'http://h/Game/de/EE/Language.dll')), IntToStr(OnlineFileRefusedCode));
  Check('GetOnlineFileCheck data with pin', IntToStr(GetOnlineFileCheck('EE\WONLobby.cfg', Pin, 'https://h/Lobby/de/EE/WONLobby.cfg')), IntToStr(OnlineFilePinned));
  Check('GetOnlineFileCheck data without pin over https', IntToStr(GetOnlineFileCheck('EE\Data\data.ssa', '', 'https://h/Game/de/EE/Data/data.ssa')), IntToStr(OnlineFileTlsOnly));
  Check('GetOnlineFileCheck data without pin over http', IntToStr(GetOnlineFileCheck('EE\Data\data.ssa', '', 'http://h/Game/de/EE/Data/data.ssa')), IntToStr(OnlineFileRefusedInsecure));
  Check('GetOnlineFileCheck data without pin, no URL', IntToStr(GetOnlineFileCheck('EE\Data\data.ssa', '', '')), IntToStr(OnlineFileRefusedInsecure));
end;

procedure CheckAction(const Name: String; const Outcome: Integer; const MirrorAllowed, MirrorTried, StoppedByUser: Boolean; const Expected: Integer);
begin
  Check('NextDownloadAction ' + Name, IntToStr(NextDownloadAction(Outcome, MirrorAllowed, MirrorTried, StoppedByUser)), IntToStr(Expected));
end;

// The decision after each download attempt (ADR 0003): Outcome, MirrorAllowed, MirrorTried,
// StoppedByUser
procedure TestNextDownloadAction;
begin
  CheckAction('success at the main server', DownloadOutcomeSuccess, True, False, False, DownloadActionAccept);
  CheckAction('success at the mirror', DownloadOutcomeSuccess, True, True, False, DownloadActionAccept);
  CheckAction('success without mirror', DownloadOutcomeSuccess, False, False, False, DownloadActionAccept);
  CheckAction('success, stop came too late to cancel it', DownloadOutcomeSuccess, True, False, True, DownloadActionAccept);
  CheckAction('network error, mirror allowed', DownloadOutcomeFailure, True, False, False, DownloadActionTryMirror);
  CheckAction('network error, mirror not allowed', DownloadOutcomeFailure, False, False, False, DownloadActionGiveUp);
  CheckAction('network error at the mirror', DownloadOutcomeFailure, True, True, False, DownloadActionGiveUp);
  CheckAction('pin mismatch, mirror allowed', DownloadOutcomePinMismatch, True, False, False, DownloadActionTryMirror);
  CheckAction('pin mismatch, mirror not allowed', DownloadOutcomePinMismatch, False, False, False, DownloadActionGiveUp);
  CheckAction('pin mismatch at the mirror', DownloadOutcomePinMismatch, True, True, False, DownloadActionGiveUp);
  CheckAction('stop at the main server', DownloadOutcomeFailure, True, False, True, DownloadActionStopAll);
  CheckAction('stop at the main server, mirror not allowed', DownloadOutcomeFailure, False, False, True, DownloadActionStopAll);
  CheckAction('stop at the mirror', DownloadOutcomeFailure, True, True, True, DownloadActionStopAll);
  CheckAction('stop with a pin mismatch', DownloadOutcomePinMismatch, True, False, True, DownloadActionStopAll);
  CheckAction('unknown outcome counts as failure', 99, True, False, False, DownloadActionTryMirror);
end;

procedure TestNeedsExplicitTlsProtocols;
begin
  CheckBool('NeedsExplicitTlsProtocols Vista 6.0', NeedsExplicitTlsProtocols(6, 0), True);
  CheckBool('NeedsExplicitTlsProtocols Windows 7 6.1', NeedsExplicitTlsProtocols(6, 1), True);
  CheckBool('NeedsExplicitTlsProtocols Windows 8 6.2', NeedsExplicitTlsProtocols(6, 2), True);
  CheckBool('NeedsExplicitTlsProtocols Windows 8.1 6.3', NeedsExplicitTlsProtocols(6, 3), False);
  CheckBool('NeedsExplicitTlsProtocols Windows 10/11 10.0', NeedsExplicitTlsProtocols(10, 0), False);
end;

// Windows 8.1 and later: the request object is not touched (an unassigned Variant would raise)
procedure TestApplyTlsProtocolsNotNeeded;
var
  NoRequest: Variant;
  Outcome: String;
begin
  try
    Outcome := ApplyTlsProtocols(NoRequest, 10, 0);
  except
    Outcome := 'exception: ' + GetExceptionMessage;
  end;
  Check('ApplyTlsProtocols Windows 10 leaves the request alone', Outcome, '');
end;

// Run time, not only compilation: the same function HttpGet calls sets the option on a real
// WinHttpRequest object as on Windows 7 (6.1). Nothing is sent. Whether the option is accepted
// depends on the system (Wine answers "Not implemented"), so the test only requires that no
// exception escapes and that something was attempted; the outcome goes into the setup log and the
// name of the result line.
procedure TestApplyTlsProtocolsRunTime;
var
  Request: Variant;
  Outcome: String;
  Escaped: Boolean;
begin
  try
    Request := CreateOleObject('WinHttp.WinHttpRequest.5.1');
  except
    Failures := Failures + 1;
    Results.Add('FAIL ApplyTlsProtocols run time: no WinHttpRequest object: ' + GetExceptionMessage);
    Exit;
  end;
  Escaped := False;
  try
    Outcome := ApplyTlsProtocols(Request, 6, 1);
  except
    Escaped := True;
    Outcome := GetExceptionMessage;
  end;
  Log('ApplyTlsProtocols on a WinHttpRequest object as on Windows 6.1: ' + Outcome);
  CheckBool('ApplyTlsProtocols run time, no exception escapes (' + Outcome + ')', Escaped, False);
  CheckBool('ApplyTlsProtocols run time, the option was attempted', Outcome <> '', True);
end;

procedure TestInstallModeName;
begin
  Check('InstallModeName Regular, administrative', InstallModeName(False, True), 'admin');
  Check('InstallModeName Regular, non-administrative', InstallModeName(False, False), 'user');
  Check('InstallModeName Portable', InstallModeName(True, False), 'portable');
  Check('InstallModeName Portable started as administrator', InstallModeName(True, True), 'portable');
end;

procedure TestIsAsciiText;
begin
  CheckBool('IsAsciiText empty', IsAsciiText(''), True);
  CheckBool('IsAsciiText letters, digits, punctuation', IsAsciiText('Components=game,language\pt_BR' + #13#10), True);
  CheckBool('IsAsciiText control characters and DEL', IsAsciiText(#0 + #9 + #10 + #13 + #127), True);
  // Chr(128) is U+0080, the first character after ASCII (a literal #128 would go through the ANSI
  // code page of the compiler)
  CheckBool('IsAsciiText U+0080 (Chr(128) = ' + IntToStr(Ord(Chr(128))) + ')', IsAsciiText('a' + Chr(128)), False);
  CheckBool('IsAsciiText U+007F', IsAsciiText('a' + Chr(127)), True);
  CheckBool('IsAsciiText e acute', IsAsciiText('Civilisations ' + #$E9), False);
  CheckBool('IsAsciiText euro sign', IsAsciiText(#$20AC), False);
  CheckBool('IsAsciiText Chinese character', IsAsciiText('Lobby ' + #$4E2D), False);
  CheckBool('IsAsciiText surrogate pair', IsAsciiText(#$D83D#$DE00), False);
  CheckBool('IsAsciiText non-ASCII at the start', IsAsciiText(#$FC + 'ber'), False);
end;

// install.ini of contract 1.2: keys in the order of the contract, SetupBuild only if set, CRLF
procedure TestBuildInstallIniText;
var
  Text: String;
  I, Crs, Lfs: Integer;
begin
  Check('BuildInstallIniText admin with SetupBuild (example of contract 1.2)',
    BuildInstallIniText(1, 'NeoEE', '00000000-0000-0000-0000-000000000AEE', 'admin', '2.0.0.5', '2.0.0', 'a1b2c3d',
      'game,gameaoc,additional,additional\directx_wrapper,additional\directx_wrapper\dx11_lvl11,language,language\de',
      'compatibility,compatibility_windows,firewallexception,neoee_cdkeys', '2026-10-02 18:04:31'),
    '[Install]' + #13#10 +
    'ContractVersion=1' + #13#10 +
    'Product=NeoEE' + #13#10 +
    'AppId=00000000-0000-0000-0000-000000000AEE' + #13#10 +
    'InstallMode=admin' + #13#10 +
    'GameVersion=2.0.0.5' + #13#10 +
    'SetupVersion=2.0.0' + #13#10 +
    'SetupBuild=a1b2c3d' + #13#10 +
    'Components=game,gameaoc,additional,additional\directx_wrapper,additional\directx_wrapper\dx11_lvl11,language,language\de' + #13#10 +
    'Tasks=compatibility,compatibility_windows,firewallexception,neoee_cdkeys' + #13#10 +
    'Written=2026-10-02 18:04:31' + #13#10);
  Check('BuildInstallIniText user without SetupBuild',
    BuildInstallIniText(1, 'EE', '00000000-0000-0000-0000-0000000000EE', 'user', '2.0.0.0', '1.7.2', '',
      'game,language,language\fr', 'compatibility,compatibility_windows', '2026-01-31 09:05:00'),
    '[Install]' + #13#10 + 'ContractVersion=1' + #13#10 + 'Product=EE' + #13#10 +
    'AppId=00000000-0000-0000-0000-0000000000EE' + #13#10 + 'InstallMode=user' + #13#10 +
    'GameVersion=2.0.0.0' + #13#10 + 'SetupVersion=1.7.2' + #13#10 +
    'Components=game,language,language\fr' + #13#10 + 'Tasks=compatibility,compatibility_windows' + #13#10 +
    'Written=2026-01-31 09:05:00' + #13#10);
  Check('BuildInstallIniText portable with SetupBuild, no tasks',
    BuildInstallIniText(2, 'EE', '00000000-0000-0000-0000-0000000000EE', 'portable', '2.0.0.0', '1.7.2', 'test1-ab12cd3',
      'game,language,language\en', '', '2026-12-24 23:59:59'),
    '[Install]' + #13#10 + 'ContractVersion=2' + #13#10 + 'Product=EE' + #13#10 +
    'AppId=00000000-0000-0000-0000-0000000000EE' + #13#10 + 'InstallMode=portable' + #13#10 +
    'GameVersion=2.0.0.0' + #13#10 + 'SetupVersion=1.7.2' + #13#10 + 'SetupBuild=test1-ab12cd3' + #13#10 +
    'Components=game,language,language\en' + #13#10 + 'Tasks=' + #13#10 +
    'Written=2026-12-24 23:59:59' + #13#10);
  // Every LF is part of a CRLF, and the text ends with one: 10 lines with SetupBuild, 9 without
  Text := BuildInstallIniText(1, 'EE', 'x', 'admin', '1', '2', 'b', 'c', 't', 'w');
  Crs := 0;
  Lfs := 0;
  for I := 1 to Length(Text) do
  begin
    if Text[I] = #13 then
    begin
      Crs := Crs + 1;
      CheckBool('BuildInstallIniText CR ' + IntToStr(Crs) + ' is followed by LF', (I < Length(Text)) and (Text[I + 1] = #10), True);
    end;
    if Text[I] = #10 then
      Lfs := Lfs + 1;
  end;
  Check('BuildInstallIniText lines with SetupBuild (CR, LF)', IntToStr(Crs) + ', ' + IntToStr(Lfs), '11, 11');
  Check('BuildInstallIniText ends with CRLF', Copy(Text, Length(Text) - 1, 2), #13#10);
  Text := BuildInstallIniText(1, 'EE', 'x', 'admin', '1', '2', '', 'c', 't', 'w');
  Check('BuildInstallIniText without SetupBuild has no SetupBuild key', IntToStr(Pos('SetupBuild', Text)), '0');
  CheckBool('BuildInstallIniText is ASCII for ASCII values', IsAsciiText(Text), True);
end;

// The value 'Empire Earth Community: ContractVersion': only with an uninstall key, a deletion that
// worked at ssInstall and every state file written (ADR 0004 point 9); all 8 combinations
procedure TestShouldWriteContractVersionValue;
var
  I: Integer;
  HasKey, Deleted, Written: Boolean;
begin
  for I := 0 to 7 do
  begin
    HasKey := (I and 1) <> 0;
    Deleted := (I and 2) <> 0;
    Written := (I and 4) <> 0;
    CheckBool('ShouldWriteContractVersionValue uninstall key ' + IntToStr(Ord(HasKey)) + ', deleted ' + IntToStr(Ord(Deleted)) +
      ', written ' + IntToStr(Ord(Written)), ShouldWriteContractVersionValue(HasKey, Deleted, Written), I = 7);
  end;
end;

// Content of a file as text ('<missing>' if it cannot be read)
function FileText(const FileName: String): String;
var
  Bytes: AnsiString;
begin
  if LoadStringFromFile(FileName, Bytes) then
    Result := String(Bytes)
  else
    Result := '<missing>';
end;

// The bytes of a state file as contract 1.2 asks: no BOM, only ASCII, every LF after a CR, CRLF at
// the end
procedure CheckStateFileBytes(const Name, FileName: String);
var
  Bytes: AnsiString;
  I: Integer;
  Ascii, CrLf: Boolean;
begin
  if not LoadStringFromFile(FileName, Bytes) then
  begin
    CheckBool(Name + ': file readable', False, True);
    Exit;
  end;
  CheckBool(Name + ': no UTF-8 BOM', Copy(Bytes, 1, 3) = #$EF#$BB#$BF, False);
  Ascii := True;
  CrLf := (Length(Bytes) >= 2) and (Copy(Bytes, Length(Bytes) - 1, 2) = #13#10);
  for I := 1 to Length(Bytes) do
  begin
    if Ord(Bytes[I]) > 127 then
      Ascii := False;
    if (Bytes[I] = #10) and ((I = 1) or (Bytes[I - 1] <> #13)) then
      CrLf := False;
    if (Bytes[I] = #13) and ((I = Length(Bytes)) or (Bytes[I + 1] <> #10)) then
      CrLf := False;
  end;
  CheckBool(Name + ': only ASCII bytes', Ascii, True);
  CheckBool(Name + ': CRLF line ends only, CRLF at the end', CrLf, True);
end;

// File level, in a folder of {tmp}: RenameFile never overwrites (so ReplaceStateFile deletes the
// target first), the bytes ReplaceStateFile writes, and what it leaves after a failure
procedure TestStateFiles;
var
  Folder, Target, Temp, Text: String;
begin
  Folder := ExpandConstant('{tmp}\state_files');
  if not ForceDirectories(Folder) then
  begin
    CheckBool('state files: test folder created', False, True);
    Exit;
  end;
  Target := Folder + '\install.ini';
  Temp := Target + StateFileTempSuffix;
  Check('state files: temporary file name', ExtractFileName(Temp), 'install.ini.tmp');
  Text := BuildInstallIniText(1, 'NeoEE', '00000000-0000-0000-0000-000000000AEE', 'admin', '2.0.0.5', '1.7.2',
    'test1-ab12cd3', 'game,gameaoc,language,language\de', 'compatibility,compatibility_windows', '2026-10-02 18:04:31');

  // RenameFile of Inno Setup 6.2.2 (MoveFile without MOVEFILE_REPLACE_EXISTING): over an existing
  // file it fails and keeps both files; after deleting the target it works
  SaveStringToFile(Target, 'old', False);
  SaveStringToFile(Temp, 'new', False);
  CheckBool('RenameFile over an existing file fails', RenameFile(Temp, Target), False);
  Check('RenameFile over an existing file keeps the target', FileText(Target), 'old');
  Check('RenameFile over an existing file keeps the source', FileText(Temp), 'new');
  CheckBool('RenameFile works after the target was deleted',
    DeleteFile(Target) and not FileExists(Target) and RenameFile(Temp, Target), True);
  Check('RenameFile after deleting: the new content', FileText(Target), 'new');
  CheckBool('RenameFile after deleting: no source left', FileExists(Temp), False);

  // ReplaceStateFile over an existing file and a temporary file left by an aborted run
  SaveStringToFile(Temp, 'left by an aborted run', False);
  CheckBool('ReplaceStateFile over an existing file', ReplaceStateFile(Target, Text), True);
  Check('ReplaceStateFile over an existing file: exactly the text', FileText(Target), Text);
  CheckStateFileBytes('ReplaceStateFile over an existing file', Target);
  CheckBool('ReplaceStateFile over an existing file: no temporary file left', FileExists(Temp), False);

  // Without a target
  CheckBool('ReplaceStateFile without a target: target deleted first', DeleteFile(Target), True);
  CheckBool('ReplaceStateFile without a target', ReplaceStateFile(Target, Text), True);
  Check('ReplaceStateFile without a target: exactly the text', FileText(Target), Text);
  CheckStateFileBytes('ReplaceStateFile without a target', Target);

  // Text that is not ASCII: nothing written, the old file stays, no temporary file
  CheckBool('ReplaceStateFile refuses text that is not ASCII', ReplaceStateFile(Target, 'Path=C:\Jeux\' + #$E9 + #13#10), False);
  Check('ReplaceStateFile refuses text that is not ASCII: old file kept', FileText(Target), Text);
  CheckBool('ReplaceStateFile refuses text that is not ASCII: no temporary file', FileExists(Temp), False);

  // A read-only target cannot be deleted: False, the old file stays, no temporary file left
  CheckBool('read-only target set', SetFileAttributes(Target, FILE_ATTRIBUTE_READONLY), True);
  CheckBool('DeleteStateFile of a read-only file', DeleteStateFile(Target), False);
  CheckBool('ReplaceStateFile over a read-only file fails', ReplaceStateFile(Target, 'new' + #13#10), False);
  Check('ReplaceStateFile over a read-only file: old file kept', FileText(Target), Text);
  CheckBool('ReplaceStateFile over a read-only file: no temporary file left', FileExists(Temp), False);
  SetFileAttributes(Target, FILE_ATTRIBUTE_NORMAL);
  CheckBool('DeleteStateFile', DeleteStateFile(Target), True);
  CheckBool('DeleteStateFile: file gone', FileExists(Target), False);
  CheckBool('DeleteStateFile of a missing file', DeleteStateFile(Target), True);

  // A folder with the name of the target: the rename fails, no temporary file left
  CheckBool('folder with the name of the target created', CreateDir(Target), True);
  CheckBool('ReplaceStateFile onto a folder fails', ReplaceStateFile(Target, Text), False);
  CheckBool('ReplaceStateFile onto a folder: no temporary file left', FileExists(Temp), False);
  RemoveDir(Target);
  DelTree(Folder, True, True, True);
end;

procedure CheckManifestPath(const Name, Root, FullPath: String; const ExpectedOk: Boolean; const ExpectedPath: String);
var
  RelPath: String;
  Ok: Boolean;
begin
  RelPath := '<unchanged>';
  Ok := GetManifestPath(Root, FullPath, RelPath);
  CheckBool('GetManifestPath ' + Name, Ok, ExpectedOk);
  Check('GetManifestPath ' + Name + ': path', RelPath, ExpectedPath);
end;

// Contract 2.2: relative to the root, '/', never outside the root, no ':' and no '..'
procedure TestGetManifestPath;
begin
  CheckManifestPath('file in a game folder', 'C:\Games\EE', 'C:\Games\EE\Empire Earth\Empire Earth.exe', True, 'Empire Earth/Empire Earth.exe');
  CheckManifestPath('root with a trailing backslash', 'C:\Games\EE\', 'C:\Games\EE\Empire Earth\Empire Earth.exe', True, 'Empire Earth/Empire Earth.exe');
  CheckManifestPath('root compared ignoring case, the rest keeps its case', 'c:\games\ee',
    'C:\Games\EE\Empire Earth - The Art of Conquest\Data\WONLobby Resources\_LobbyResource.cfg', True,
    'Empire Earth - The Art of Conquest/Data/WONLobby Resources/_LobbyResource.cfg');
  CheckManifestPath('file in the root', 'C:\Games\EE', 'C:\Games\EE\readme.txt', True, 'readme.txt');
  CheckManifestPath('root with non-ASCII characters', 'C:\Jeux ' + #$E9 + ' ' + #$FC, 'C:\Jeux ' + #$E9 + ' ' + #$FC + '\Tools\Diagnostic\EE-Diagnostic.exe',
    True, 'Tools/Diagnostic/EE-Diagnostic.exe');
  CheckManifestPath('two dots inside a name', 'C:\Games\EE', 'C:\Games\EE\Data\a..b.ssa', True, 'Data/a..b.ssa');
  CheckManifestPath('folder that only starts like the root', 'C:\Games\EE', 'C:\Games\EE2\Empire Earth.exe', False, '');
  CheckManifestPath('other drive', 'C:\Games\EE', 'D:\Games\EE\Empire Earth.exe', False, '');
  CheckManifestPath('shorter than the root', 'C:\Games\EE', 'C:\Games', False, '');
  CheckManifestPath('the root itself', 'C:\Games\EE', 'C:\Games\EE', False, '');
  CheckManifestPath('the root with a backslash', 'C:\Games\EE', 'C:\Games\EE\', False, '');
  CheckManifestPath('.. segment', 'C:\Games\EE', 'C:\Games\EE\..\Windows\System32\x.dll', False, '');
  CheckManifestPath('.. segment inside', 'C:\Games\EE', 'C:\Games\EE\Empire Earth\..\..\x.dll', False, '');
  CheckManifestPath('. segment', 'C:\Games\EE', 'C:\Games\EE\.\x.dll', False, '');
  CheckManifestPath('colon of an alternate data stream', 'C:\Games\EE', 'C:\Games\EE\Data\data.ssa:stream', False, '');
  CheckManifestPath('drive after the root', 'C:\Games\EE', 'C:\Games\EE\C:\x.dll', False, '');
  CheckManifestPath('empty segment', 'C:\Games\EE', 'C:\Games\EE\Data\\x.dll', False, '');
  CheckManifestPath('trailing backslash', 'C:\Games\EE', 'C:\Games\EE\Data\', False, '');
  CheckManifestPath('slash in the rest', 'C:\Games\EE', 'C:\Games\EE\Data/x.dll', False, '');
  CheckManifestPath('empty root', '', 'C:\Games\EE\x.dll', False, '');
end;

// Contract 2.3: the setup data folder and the uninstaller are never in the manifest
procedure TestIsManifestExcludedPath;
begin
  CheckBool('IsManifestExcludedPath setup data folder', IsManifestExcludedPath('_setupdata_EE/EEStatsSetup.dll', '_setupdata_EE'), True);
  CheckBool('IsManifestExcludedPath setup data folder, other case', IsManifestExcludedPath('_SetupData_ee/install.ini', '_setupdata_EE'), True);
  CheckBool('IsManifestExcludedPath setup data folder of the other product', IsManifestExcludedPath('_setupdata_NeoEE/install.ini', '_setupdata_EE'), False);
  CheckBool('IsManifestExcludedPath a file named like the setup data folder', IsManifestExcludedPath('_setupdata_EE', '_setupdata_EE'), False);
  CheckBool('IsManifestExcludedPath unins000.exe', IsManifestExcludedPath('unins000.exe', '_setupdata_EE'), True);
  CheckBool('IsManifestExcludedPath unins000.dat', IsManifestExcludedPath('unins000.dat', '_setupdata_EE'), True);
  CheckBool('IsManifestExcludedPath UNINS001.EXE', IsManifestExcludedPath('UNINS001.EXE', '_setupdata_EE'), True);
  CheckBool('IsManifestExcludedPath unins000.exe in a game folder', IsManifestExcludedPath('Empire Earth/unins000.exe', '_setupdata_EE'), False);
  CheckBool('IsManifestExcludedPath uninstall.txt', IsManifestExcludedPath('uninstall.txt', '_setupdata_EE'), False);
  CheckBool('IsManifestExcludedPath game program', IsManifestExcludedPath('Empire Earth/Empire Earth.exe', '_setupdata_EE'), False);
  CheckBool('IsManifestExcludedPath tool', IsManifestExcludedPath('Tools/Diagnostic/EE-Diagnostic.exe', '_setupdata_EE'), False);
end;

procedure TestManifestLine;
begin
  Check('ManifestLine lowercase hex, two spaces, LF',
    ManifestLine('27A84712E4B22C415FC544D55CDEE82327A829F96D03329457F76EBF9AF4DCAA', 'Empire Earth/Empire Earth.exe'),
    '27a84712e4b22c415fc544d55cdee82327a829f96d03329457f76ebf9af4dcaa  Empire Earth/Empire Earth.exe' + #10);
  Check('ManifestLine path with spaces and a dash',
    ManifestLine('be3f1b44776624b9c37b661e9711ac1d8f51628b80c33e3b60b6a56fea088c9b', 'Empire Earth - The Art of Conquest/Data/WONLobby Resources/_LobbyResource.cfg'),
    'be3f1b44776624b9c37b661e9711ac1d8f51628b80c33e3b60b6a56fea088c9b  Empire Earth - The Art of Conquest/Data/WONLobby Resources/_LobbyResource.cfg' + #10);
end;

procedure CheckOrder(const A, B: String; const Expected: Integer);
var
  Actual: Integer;
begin
  Actual := CompareManifestPaths(A, B);
  if Actual < 0 then
    Actual := -1
  else if Actual > 0 then
    Actual := 1;
  Check('CompareManifestPaths "' + A + '" "' + B + '"', IntToStr(Actual), IntToStr(Expected));
end;

// Ordinal ignoring case (uppercase), contract 2.2
procedure TestCompareManifestPaths;
begin
  CheckOrder('Data/Campaigns/EELearningCampaign.ssa', 'data/campaigns/eelearningcampaign.SSA', 0);
  CheckOrder('a.dll', 'B.dll', -1);
  CheckOrder('B.dll', 'a.dll', 1);
  CheckOrder('Data', 'Data/x.ssa', -1);
  CheckOrder('Data/_WONStatus.cfg', 'Data/Zebra.cfg', 1);
  CheckOrder('Data/_WONStatus.cfg', 'Data/zebra.cfg', 1);
  CheckOrder('Empire Earth - The Art of Conquest/EE-AOC.exe', 'Empire Earth/Empire Earth.exe', -1);
  CheckOrder('Empire Earth/Data/data.ssa', 'Empire Earth/Data/Data.ssa', 0);
  CheckOrder('Tools/Diagnostic/EE-Diagnostic.exe', 'Empire Earth/Empire Earth.exe', 1);
end;

function JoinedPaths(const Paths: TArrayOfString): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to GetArrayLength(Paths) - 1 do
  begin
    if I > 0 then
      Result := Result + '|';
    Result := Result + Paths[I];
  end;
end;

// Number of neighbours in Paths that are not in strictly increasing order of CompareManifestPaths
function UnorderedNeighbours(const Paths: TArrayOfString): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to GetArrayLength(Paths) - 2 do
    if CompareManifestPaths(Paths[I], Paths[I + 1]) >= 0 then
      Result := Result + 1;
end;

// One of three spellings of Path: as it is, uppercase, lowercase
function MixedCase(const Path: String; const Index: Integer): String;
begin
  case Index mod 3 of
    0: Result := Path;
    1: Result := UpperCase(Path);
  else
    Result := LowerCase(Path);
  end;
end;

// Merge sort (n log n, stable) and the removal of paths that differ only in case: 2000 entries
procedure TestSortManifestPaths;
var
  Paths: TArrayOfString;
  I, V, Comparisons, Removed: Integer;
  AllUpper: Boolean;
begin
  SetArrayLength(Paths, 0);
  Check('MergeSortManifestPaths empty: comparisons', IntToStr(MergeSortManifestPaths(Paths)), '0');
  Check('RemoveDuplicateManifestPaths empty', IntToStr(RemoveDuplicateManifestPaths(Paths)) + ':' + JoinedPaths(Paths), '0:');
  SetArrayLength(Paths, 1);
  Paths[0] := 'Empire Earth/Empire Earth.exe';
  Check('MergeSortManifestPaths one path: comparisons', IntToStr(MergeSortManifestPaths(Paths)), '0');
  Check('MergeSortManifestPaths one path', JoinedPaths(Paths), 'Empire Earth/Empire Earth.exe');

  // Stable: of two paths equal ignoring case, the one recorded first stays first; the removal keeps
  // the last one
  SetArrayLength(Paths, 6);
  Paths[0] := 'b.ssa';
  Paths[1] := 'Data/A.ssa';
  Paths[2] := '_x.cfg';
  Paths[3] := 'data/a.ssa';
  Paths[4] := 'C.ssa';
  Paths[5] := 'DATA/A.SSA';
  MergeSortManifestPaths(Paths);
  Check('MergeSortManifestPaths six paths, stable', JoinedPaths(Paths), 'b.ssa|C.ssa|Data/A.ssa|data/a.ssa|DATA/A.SSA|_x.cfg');
  Check('RemoveDuplicateManifestPaths six paths: removed', IntToStr(RemoveDuplicateManifestPaths(Paths)), '2');
  Check('RemoveDuplicateManifestPaths six paths: the spelling recorded last', JoinedPaths(Paths), 'b.ssa|C.ssa|DATA/A.SSA|_x.cfg');

  // 2000 different paths in mixed case, in a scrambled order (1237 is coprime to 2000, so V runs
  // through 0 to 1999 once)
  SetArrayLength(Paths, 2000);
  for I := 0 to 1999 do
  begin
    V := (I * 1237) mod 2000;
    Paths[I] := MixedCase('Empire Earth/Data/Folder' + IntToStr(V mod 7) + '/File' + IntToStr(V) + '.ssa', I);
  end;
  Comparisons := MergeSortManifestPaths(Paths);
  Check('MergeSortManifestPaths 2000 paths: still 2000', IntToStr(GetArrayLength(Paths)), '2000');
  Check('MergeSortManifestPaths 2000 paths: strictly increasing', IntToStr(UnorderedNeighbours(Paths)), '0');
  CheckBool('MergeSortManifestPaths 2000 paths: at most 2000 * 11 comparisons (' + IntToStr(Comparisons) + ')',
    (Comparisons > 0) and (Comparisons <= 2000 * 11), True);
  Check('RemoveDuplicateManifestPaths 2000 different paths: none removed', IntToStr(RemoveDuplicateManifestPaths(Paths)), '0');

  // 1000 paths recorded twice: first in lowercase, then (a later entry overwrites the file) in
  // uppercase; one entry per file is left, in the spelling of the later entry
  for I := 0 to 1999 do
  begin
    V := ((I mod 1000) * 1237) mod 1000;
    Paths[I] := 'Empire Earth - The Art of Conquest/Data/Textures/Texture' + IntToStr(V) + '.tga';
    if I < 1000 then
      Paths[I] := LowerCase(Paths[I])
    else
      Paths[I] := UpperCase(Paths[I]);
  end;
  Comparisons := MergeSortManifestPaths(Paths);
  CheckBool('MergeSortManifestPaths 2000 paths with duplicates: at most 2000 * 11 comparisons (' + IntToStr(Comparisons) + ')',
    Comparisons <= 2000 * 11, True);
  Removed := RemoveDuplicateManifestPaths(Paths);
  Check('RemoveDuplicateManifestPaths 2000 paths with duplicates: removed', IntToStr(Removed), '1000');
  Check('RemoveDuplicateManifestPaths 2000 paths with duplicates: left', IntToStr(GetArrayLength(Paths)), '1000');
  Check('RemoveDuplicateManifestPaths 2000 paths with duplicates: strictly increasing', IntToStr(UnorderedNeighbours(Paths)), '0');
  AllUpper := True;
  for I := 0 to GetArrayLength(Paths) - 1 do
    if Paths[I] <> UpperCase(Paths[I]) then
      AllUpper := False;
  CheckBool('RemoveDuplicateManifestPaths 2000 paths with duplicates: the spelling recorded last', AllUpper, True);
end;

// install.ini [MissingAfterInstall], contract 1.2
procedure TestBuildMissingAfterInstallText;
var
  Missing: TArrayOfString;
begin
  SetArrayLength(Missing, 0);
  Check('BuildMissingAfterInstallText nothing missing', BuildMissingAfterInstallText(Missing), '');
  SetArrayLength(Missing, 1);
  Missing[0] := 'Empire Earth/DDraw.dll';
  Check('BuildMissingAfterInstallText example of contract 1.2',
    BuildInstallIniText(1, 'NeoEE', '00000000-0000-0000-0000-000000000AEE', 'admin', '2.0.0.5', '2.0.0', 'a1b2c3d',
      'game,gameaoc,additional,additional\directx_wrapper,additional\directx_wrapper\dx11_lvl11,language,language\de',
      'compatibility,compatibility_windows,firewallexception,neoee_cdkeys', '2026-10-02 18:04:31') + BuildMissingAfterInstallText(Missing),
    '[Install]' + #13#10 + 'ContractVersion=1' + #13#10 + 'Product=NeoEE' + #13#10 +
    'AppId=00000000-0000-0000-0000-000000000AEE' + #13#10 + 'InstallMode=admin' + #13#10 + 'GameVersion=2.0.0.5' + #13#10 +
    'SetupVersion=2.0.0' + #13#10 + 'SetupBuild=a1b2c3d' + #13#10 +
    'Components=game,gameaoc,additional,additional\directx_wrapper,additional\directx_wrapper\dx11_lvl11,language,language\de' + #13#10 +
    'Tasks=compatibility,compatibility_windows,firewallexception,neoee_cdkeys' + #13#10 + 'Written=2026-10-02 18:04:31' + #13#10 + #13#10 +
    '[MissingAfterInstall]' + #13#10 + '1=Empire Earth/DDraw.dll' + #13#10);
  SetArrayLength(Missing, 3);
  Missing[0] := 'Empire Earth - The Art of Conquest/EE-AOC.exe';
  Missing[1] := 'Empire Earth/Data/Campagne ' + #$E9 + '.ssa';
  Missing[2] := 'Empire Earth/Empire Earth.exe';
  Check('BuildMissingAfterInstallText leaves out a path that is not ASCII, consecutive keys', BuildMissingAfterInstallText(Missing),
    '' + #13#10 + '[MissingAfterInstall]' + #13#10 + '1=Empire Earth - The Art of Conquest/EE-AOC.exe' + #13#10 +
    '2=Empire Earth/Empire Earth.exe' + #13#10);
  SetArrayLength(Missing, 1);
  Missing[0] := 'Empire Earth/Data/Campagne ' + #$E9 + '.ssa';
  Check('BuildMissingAfterInstallText only a path that is not ASCII', BuildMissingAfterInstallText(Missing), '');
end;

procedure SetMissing(var Missing: TArrayOfString; const Count: Integer);
var
  I: Integer;
begin
  SetArrayLength(Missing, Count);
  for I := 0 to Count - 1 do
    Missing[I] := 'Empire Earth/Data/Sounds/Sound' + IntToStr(I + 1) + '.wav';
end;

// The list of the notice FilesMissingAfterInstall: at most ten names, then "and %1 more"
procedure TestFormatMissingFileList;
var
  Missing: TArrayOfString;
  Expected: String;
  I: Integer;
begin
  SetMissing(Missing, 0);
  Check('FormatMissingFileList nothing', FormatMissingFileList(Missing, MissingFilesShownMax, 'and %1 more'), '');
  SetArrayLength(Missing, 2);
  Missing[0] := 'Empire Earth/DDraw.dll';
  Missing[1] := 'Empire Earth - The Art of Conquest/Data/WONLobby Resources/_LobbyResource.cfg';
  Check('FormatMissingFileList two files, backslashes',
    FormatMissingFileList(Missing, MissingFilesShownMax, 'and %1 more'),
    '' + #13#10 + '  Empire Earth\DDraw.dll' + #13#10 + '  Empire Earth - The Art of Conquest\Data\WONLobby Resources\_LobbyResource.cfg');
  Expected := '';
  for I := 1 to 10 do
    Expected := Expected + #13#10 + '  Empire Earth\Data\Sounds\Sound' + IntToStr(I) + '.wav';
  SetMissing(Missing, 10);
  Check('FormatMissingFileList ten files: all, no "more"', FormatMissingFileList(Missing, MissingFilesShownMax, 'and %1 more'), Expected);
  SetMissing(Missing, 11);
  Check('FormatMissingFileList eleven files: ten and "and 1 more"', FormatMissingFileList(Missing, MissingFilesShownMax, 'and %1 more'),
    Expected + #13#10 + '  and 1 more');
  SetMissing(Missing, 25);
  Check('FormatMissingFileList 25 files, German', FormatMissingFileList(Missing, MissingFilesShownMax, 'und %1 weitere'),
    Expected + #13#10 + '  und 15 weitere');
  Check('FormatMissingFileList at most 2', FormatMissingFileList(Missing, 2, 'et %1 autres'),
    '' + #13#10 + '  Empire Earth\Data\Sounds\Sound1.wav' + #13#10 + '  Empire Earth\Data\Sounds\Sound2.wav' + #13#10 + '  et 23 autres');
end;

// The log line 'Manifest: <n> files, <MB> MB, <ms> ms, <MB/s> MB/s'
procedure TestFormatManifestSummary;
var
  Bytes: Int64;
begin
  Bytes := 1048576;
  Bytes := Bytes * 1500;
  Check('FormatManifestSummary 1500 MB in 12 s', FormatManifestSummary(1791, Bytes, 12000),
    'Manifest: 1791 files, 1500.0 MB, 12000 ms, 125.0 MB/s');
  Bytes := 1073741824;
  Bytes := Bytes * 3;
  Check('FormatManifestSummary 3 GB in 7 s (beyond 32 bits)', FormatManifestSummary(2000, Bytes, 7000),
    'Manifest: 2000 files, 3072.0 MB, 7000 ms, 438.9 MB/s');
  Check('FormatManifestSummary nothing', FormatManifestSummary(0, 0, 0), 'Manifest: 0 files, 0.0 MB, 0 ms, 0.0 MB/s');
  Check('FormatManifestSummary rounded to one decimal', FormatManifestSummary(2, 1310720, 1000),
    'Manifest: 2 files, 1.3 MB, 1000 ms, 1.3 MB/s');
  Check('FormatManifestSummary 0 ms counts as 1 ms', FormatManifestSummary(1, 1048576, 0),
    'Manifest: 1 files, 1.0 MB, 0 ms, 1000.0 MB/s');
end;

// The bytes of files.sha256 as contract 2.2 asks: no BOM, only ASCII, no CR, LF at the end (if not
// empty)
procedure CheckManifestBytes(const Name, FileName: String);
var
  Bytes: AnsiString;
  I: Integer;
  Ascii: Boolean;
begin
  if not LoadStringFromFile(FileName, Bytes) then
  begin
    CheckBool(Name + ': file readable', False, True);
    Exit;
  end;
  CheckBool(Name + ': no UTF-8 BOM', Copy(Bytes, 1, 3) = #$EF#$BB#$BF, False);
  Ascii := True;
  for I := 1 to Length(Bytes) do
    if Ord(Bytes[I]) > 127 then
      Ascii := False;
  CheckBool(Name + ': only ASCII bytes', Ascii, True);
  Check(Name + ': no CR', IntToStr(Pos(#13, Bytes)), '0');
  if Length(Bytes) > 0 then
    Check(Name + ': LF at the end', IntToStr(Ord(Bytes[Length(Bytes)])), '10');
end;

// Creates the file Root\RelPath (Windows path) with Content
procedure CreateTestFile(const Root, RelPath, Content: String);
begin
  ForceDirectories(ExtractFileDir(Root + '\' + RelPath));
  if not SaveStringToFile(Root + '\' + RelPath, Content, False) then
    CheckBool('test file ' + RelPath + ' created', False, True);
end;

// The expected manifest line of the file Root\<RelPath>, with GetSHA256OfFile as the reference
function ExpectedLine(const Root, RelPath: String): String;
var
  FullPath: String;
begin
  FullPath := Root + '\' + RelPath;
  StringChangeEx(FullPath, '/', '\', True);
  Result := LowerCase(GetSHA256OfFile(FullPath)) + '  ' + RelPath + #10;
end;

// File level, in a folder of {tmp}: an installation of a few files, one of them deleted before the
// manifest is written, others recorded twice, outside the root or in excluded places; the verified
// online files of an external entry; a file that cannot be hashed; a path that is not ASCII
procedure TestManifestFiles;
var
  Root, Verified, StateDir, Manifest, Ini, IniText, Expected, Hash, Error: String;
  Recorded: TStringList;
  Missing: TArrayOfString;
  ManifestWritten, IniWritten: Boolean;
  Handle: Cardinal;
  Started: DWORD;
  Elapsed: Int64;
begin
  Root := ExpandConstant('{tmp}\manifest_root');
  Verified := ExpandConstant('{tmp}\manifest_verified');
  StateDir := Root + '\_setupdata_EE';
  Manifest := StateDir + '\files.sha256';
  Ini := StateDir + '\install.ini';
  Check('manifest: file name', ExtractFileName(Manifest), ManifestFileName);
  CheckBool('manifest: setup data folder created', ForceDirectories(StateDir), True);
  CreateTestFile(Root, 'Empire Earth\Empire Earth.exe', 'program');
  CreateTestFile(Root, 'Empire Earth\DDraw.dll', 'wrapper');
  CreateTestFile(Root, 'Empire Earth\Data\data.ssa', 'game data');
  CreateTestFile(Root, 'Empire Earth\Data\empty.cfg', '');
  CreateTestFile(Root, 'Empire Earth - The Art of Conquest\EE-AOC.exe', 'expansion');
  CreateTestFile(Root, 'Tools\Diagnostic\EE-Diagnostic.exe', 'tool');
  CreateTestFile(Root, '_setupdata_EE\EEStatsSetup.dll', 'setup data');
  CreateTestFile(Root, 'unins000.exe', 'uninstaller');
  // An online file verified into {tmp}\verified\EE and installed by the external entry, and a
  // hidden file there that the entry does not pick
  CreateTestFile(Verified, 'EE\Data\Campaigns\EELearningCampaign.ssa', 'campaign');
  CreateTestFile(Root, 'Empire Earth\Data\Campaigns\EELearningCampaign.ssa', 'campaign');
  CreateTestFile(Verified, 'EE\Data\hidden.ssa', 'hidden');
  SetFileAttributes(Verified + '\EE\Data\hidden.ssa', FILE_ATTRIBUTE_HIDDEN);
  IniText := BuildInstallIniText(1, 'EE', '00000000-0000-0000-0000-0000000000EE', 'admin', '2.0.0.0', '1.7.2', '',
    'game,gameaoc,language,language\de,language\update', '', '2026-10-02 18:04:31');

  Recorded := TStringList.Create;
  try
    // In the order of [Files], with a later entry that installs a file again in another case
    Recorded.Add(Root + '\EMPIRE EARTH\EMPIRE EARTH.EXE');
    Recorded.Add(Root + '\_setupdata_EE\EEStatsSetup.dll');
    Recorded.Add(Root + '\Empire Earth\Data\data.ssa');
    Recorded.Add(Root + '\Empire Earth\DDraw.dll');
    Recorded.Add(Root + '\Empire Earth\Data\empty.cfg');
    Recorded.Add(Root + '\Empire Earth - The Art of Conquest\EE-AOC.exe');
    Recorded.Add(Root + '\Tools\Diagnostic\EE-Diagnostic.exe');
    Recorded.Add(Root + '\Empire Earth\Empire Earth.exe');
    Recorded.Add(Root + '\unins000.exe');
    Recorded.Add(ExpandConstant('{tmp}') + '\outside.dll');
    CollectExternalFiles(Verified + '\EE', Root + '\Empire Earth', Recorded);
    CollectExternalFiles(Verified + '\AoC', Root + '\Empire Earth - The Art of Conquest', Recorded);
    Check('CollectExternalFiles: the file that is not hidden', IntToStr(Recorded.Count) + ' ' + Recorded[Recorded.Count - 1],
      '11 ' + Root + '\Empire Earth\Data\Campaigns\EELearningCampaign.ssa');

    // The antivirus deletes one file during the installation
    CheckBool('manifest: one installed file deleted', DeleteFile(Root + '\Empire Earth\DDraw.dll'), True);
    SaveStringToFile(Manifest + StateFileTempSuffix, 'left by an aborted run', False);
    IniWritten := WriteInstallStateFiles(Root, '_setupdata_EE', Recorded, True, IniText, nil, '', ManifestWritten, Missing);
    CheckBool('WriteInstallStateFiles: install.ini written', IniWritten, True);
    CheckBool('WriteInstallStateFiles: files.sha256 written', ManifestWritten, True);
    Expected := ExpectedLine(Root, 'Empire Earth - The Art of Conquest/EE-AOC.exe') +
      ExpectedLine(Root, 'Empire Earth/Data/Campaigns/EELearningCampaign.ssa') +
      ExpectedLine(Root, 'Empire Earth/Data/data.ssa') +
      ExpectedLine(Root, 'Empire Earth/Data/empty.cfg') +
      ExpectedLine(Root, 'Empire Earth/Empire Earth.exe') +
      ExpectedLine(Root, 'Tools/Diagnostic/EE-Diagnostic.exe');
    Check('WriteInstallStateFiles: files.sha256 in order, hashes of GetSHA256OfFile, each file once, without the deleted, excluded and outside files',
      FileText(Manifest), Expected);
    Check('WriteInstallStateFiles: SHA-256 of the empty file',
      Copy(ExpectedLine(Root, 'Empire Earth/Data/empty.cfg'), 1, 64), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    CheckManifestBytes('WriteInstallStateFiles: files.sha256', Manifest);
    CheckBool('WriteInstallStateFiles: no files.sha256.tmp left', FileExists(Manifest + StateFileTempSuffix), False);
    CheckBool('WriteInstallStateFiles: no install.ini.tmp left', FileExists(Ini + StateFileTempSuffix), False);
    Check('WriteInstallStateFiles: missing files', JoinedPaths(Missing), 'Empire Earth/DDraw.dll');
    Check('WriteInstallStateFiles: install.ini with [MissingAfterInstall]', FileText(Ini),
      IniText + #13#10 + '[MissingAfterInstall]' + #13#10 + '1=Empire Earth/DDraw.dll' + #13#10);
    CheckStateFileBytes('WriteInstallStateFiles: install.ini', Ini);

    // Everything there again: no [MissingAfterInstall]; an existing manifest is replaced
    CreateTestFile(Root, 'Empire Earth\DDraw.dll', 'wrapper');
    IniWritten := WriteInstallStateFiles(Root, '_setupdata_EE', Recorded, True, IniText, nil, '', ManifestWritten, Missing);
    CheckBool('WriteInstallStateFiles over the old files: both written', IniWritten and ManifestWritten, True);
    Check('WriteInstallStateFiles over the old files: nothing missing', IntToStr(GetArrayLength(Missing)), '0');
    Check('WriteInstallStateFiles over the old files: install.ini without [MissingAfterInstall]', FileText(Ini), IniText);
    Check('WriteInstallStateFiles over the old files: the file that is back is listed in its place', FileText(Manifest),
      ExpectedLine(Root, 'Empire Earth - The Art of Conquest/EE-AOC.exe') +
      ExpectedLine(Root, 'Empire Earth/Data/Campaigns/EELearningCampaign.ssa') +
      ExpectedLine(Root, 'Empire Earth/Data/data.ssa') +
      ExpectedLine(Root, 'Empire Earth/Data/empty.cfg') +
      ExpectedLine(Root, 'Empire Earth/DDraw.dll') +
      ExpectedLine(Root, 'Empire Earth/Empire Earth.exe') +
      ExpectedLine(Root, 'Tools/Diagnostic/EE-Diagnostic.exe'));

    // A destination that could not be recorded: no manifest, the old one stays deleted, missing
    // files are still found
    CheckBool('incomplete recording: old manifest deleted (ssInstall)', DeleteStateFile(Manifest), True);
    CheckBool('incomplete recording: one installed file deleted', DeleteFile(Root + '\Empire Earth\DDraw.dll'), True);
    IniWritten := WriteInstallStateFiles(Root, '_setupdata_EE', Recorded, False, IniText, nil, '', ManifestWritten, Missing);
    CheckBool('WriteInstallStateFiles with an incomplete recording: no manifest', ManifestWritten or FileExists(Manifest), False);
    CheckBool('WriteInstallStateFiles with an incomplete recording: install.ini written', IniWritten, True);
    Check('WriteInstallStateFiles with an incomplete recording: missing files', JoinedPaths(Missing), 'Empire Earth/DDraw.dll');
    CreateTestFile(Root, 'Empire Earth\DDraw.dll', 'wrapper');

    // A file held open without sharing: retries, then no manifest (the old one was deleted at
    // ssInstall), install.ini is still written
    Handle := CreateFile(Root + '\Empire Earth\Data\data.ssa', GENERIC_READ, 0, 0, OPEN_EXISTING, 0, 0);
    CheckBool('locked file: held open without sharing', Handle <> INVALID_HANDLE_VALUE, True);
    Started := GetTickCount;
    CheckBool('HashFileWithRetries of a locked file fails', HashFileWithRetries(Root + '\Empire Earth\Data\data.ssa', Hash, Error), False);
    Elapsed := TicksSince(Started);
    CheckBool('HashFileWithRetries of a locked file: the exception (' + Error + ')', Error <> '', True);
    CheckBool('HashFileWithRetries of a locked file: two pauses of 300 ms (' + IntToStr(Elapsed) + ' ms)', Elapsed >= 550, True);
    CheckBool('locked file: no manifest yet', FileExists(Manifest), False);
    IniWritten := WriteInstallStateFiles(Root, '_setupdata_EE', Recorded, True, IniText, nil, '', ManifestWritten, Missing);
    CheckBool('WriteInstallStateFiles with a locked file: no manifest', ManifestWritten, False);
    CheckBool('WriteInstallStateFiles with a locked file: no files.sha256', FileExists(Manifest), False);
    CheckBool('WriteInstallStateFiles with a locked file: no files.sha256.tmp', FileExists(Manifest + StateFileTempSuffix), False);
    CheckBool('WriteInstallStateFiles with a locked file: install.ini written', IniWritten, True);
    CloseHandle(Handle);
    CheckBool('HashFileWithRetries after the file was closed', HashFileWithRetries(Root + '\Empire Earth\Data\data.ssa', Hash, Error), True);
    Check('HashFileWithRetries after the file was closed: the hash', Hash, Copy(ExpectedLine(Root, 'Empire Earth/Data/data.ssa'), 1, 64));

    // A path that is not ASCII (of a file that is gone; Wine here cannot create such a name): no
    // manifest, the path is left out of install.ini but named in the notice
    Recorded.Add(Root + '\Empire Earth\Data\Gone ' + #$FC + '.ssa');
    IniWritten := WriteInstallStateFiles(Root, '_setupdata_EE', Recorded, True, IniText, nil, '', ManifestWritten, Missing);
    CheckBool('WriteInstallStateFiles with a path that is not ASCII: no manifest', ManifestWritten or FileExists(Manifest), False);
    CheckBool('WriteInstallStateFiles with a path that is not ASCII: install.ini written', IniWritten, True);
    Check('WriteInstallStateFiles with a path that is not ASCII: missing for the notice', JoinedPaths(Missing), 'Empire Earth/Data/Gone ' + #$FC + '.ssa');
    Check('WriteInstallStateFiles with a path that is not ASCII: install.ini without it', FileText(Ini), IniText);

    // Nothing recorded: an empty manifest is valid
    Recorded.Clear;
    IniWritten := WriteInstallStateFiles(Root, '_setupdata_EE', Recorded, True, IniText, nil, '', ManifestWritten, Missing);
    CheckBool('WriteInstallStateFiles with nothing recorded: both written', IniWritten and ManifestWritten, True);
    Check('WriteInstallStateFiles with nothing recorded: empty manifest', FileText(Manifest), '');
  finally
    Recorded.Free;
  end;
  DelTree(Root, True, True, True);
  DelTree(Verified, True, True, True);
end;

function InitializeSetup: Boolean;
var
  Lines: TArrayOfString;
  I: Integer;
  ResultFile: String;
begin
  Results := TStringList.Create;
  Failures := 0;
  try
    TestStrSplit;
    TestLanguageTag;
    TestCompatibilityFlags;
    TestIsBelowWindows8;
    TestIsLegacyVistaCompatValue;
    TestShouldRemoveLegacyVistaCompatValue;
    TestUninstallKeys;
    TestUrlEncode;
    TestSplitHttpsUrl;
    TestIsDomainOrSubdomain;
    TestIsAllowedUpdateUrl;
    TestFileNameExtension;
    TestIsCodeFileName;
    TestIsHttpsUrl;
    TestOnlineFilesServers;
    TestOnlineFileCheck;
    TestNextDownloadAction;
    TestNeedsExplicitTlsProtocols;
    TestApplyTlsProtocolsNotNeeded;
    TestApplyTlsProtocolsRunTime;
    TestInstallModeName;
    TestIsAsciiText;
    TestBuildInstallIniText;
    TestShouldWriteContractVersionValue;
    TestStateFiles;
    TestGetManifestPath;
    TestIsManifestExcludedPath;
    TestManifestLine;
    TestCompareManifestPaths;
    TestSortManifestPaths;
    TestBuildMissingAfterInstallText;
    TestFormatMissingFileList;
    TestFormatManifestSummary;
    TestManifestFiles;
  except
    Failures := Failures + 1;
    Results.Add('FAIL exception: ' + GetExceptionMessage);
  end;
  if Failures = 0 then
    Results.Add('RESULT: PASS (' + IntToStr(Results.Count) + ' tests)')
  else
    Results.Add('RESULT: FAIL (' + IntToStr(Failures) + ' of ' + IntToStr(Results.Count) + ' tests)');

  SetArrayLength(Lines, Results.Count);
  for I := 0 to Results.Count - 1 do
  begin
    Lines[I] := Results[I];
    Log(Results[I]);
  end;
  ResultFile := ExpandConstant('{param:RESULTS|{src}\unit_tests_result.txt}');
  if not SaveStringsToUTF8File(ResultFile, Lines, False) then
    Log('Unable to write ' + ResultFile);
  Results.Free;
  // Nothing to install
  Result := False;
end;
