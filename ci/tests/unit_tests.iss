; Unit tests of the [Code] helpers without wizard access (utils.iss), including the download
; policy of the online localized files.
;
; A tiny setup that includes utils.iss, runs every test in InitializeSetup, writes the results to
; a text file and exits without installing anything (InitializeSetup returns False). It sends no
; request and needs no network: only functions that compute something are tested.
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
