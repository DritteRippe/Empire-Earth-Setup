[Code]
// Base helpers of the [Code] part: the URL constants, string split, language tag, compatibility
// flags, uninstall keys of EE and NeoEE, the HTTP requests, URL checks, the download policy of
// the online localized files and the install state for the launcher (install mode, install.ini,
// writing a state file, the integrity manifest files.sha256). Included first, before every other
// [Code] part.
// Requires: AppID, OtherAppID (ISPP, product configuration config_*.iss).
// The functions without wizard access are tested by ci/tests/unit_tests.iss.

// All requests use HTTPS with validated certificates and never fall back to HTTP: the answers
// decide what the (elevated) setup opens or installs.
const
  // Hosts: the EE community website and the mirror of its file server
  DomainMain = 'empireearth.eu';
  DomainMirror = 'ee.zocker-160.de';
  // One base URL per endpoint; the code only appends paths and parameters
  SetupURL = 'https://' + DomainMain + '/download';                      // download page of the setup
  ApiURL = 'https://api.' + DomainMain;                                  // web API of the website
  UpdateApiURL = ApiURL + '/setup/?product={#AppID}';                    // update check (QueryUpdateApi)
  TelemetryApiURL = ApiURL + '/eestats/setup/';                          // setup statistics (SendSetupTelemetry)
  OnlineFilesURL = 'https://files.' + DomainMain + '/localized';         // localized files (downloads.iss)
  OnlineFilesMirrorURL = 'https://storage.' + DomainMirror + '/localized';
  GogStoreURL = 'https://www.gog.com/game/empire_earth_gold_edition';    // legal question
  // Besides DomainMain, the hosts a download URL of the update API may point to (IsAllowedUpdateUrl)
  DomainNeoEE = 'neoee.net';
  GitHubHost = 'github.com';
  GitHubProjectPath = '/EE-modders/';

// Splits Text at every Separator (Pascal Script of Inno Setup 6.2 has no split function)
function StrSplit(Text: String; Separator: String): TArrayOfString;
var
  i, p: Integer;
  Dest: TArrayOfString;
begin
  i := 0;
  repeat
    SetArrayLength(Dest, i+1);
    p := Pos(Separator,Text);
    if p > 0 then begin
      Dest[i] := Copy(Text, 1, p-1);
      Text := Copy(Text, p + Length(Separator), Length(Text));
      i := i + 1;
    end else begin
      Dest[i] := Text;
      Text := '';
    end;
  until Length(Text)=0;
  Result := Dest;
end;

// Language tag of a game language: the component name with '-' instead of '_' (pt_BR -> pt-BR),
// as the language folders of data\localized-text and of the file servers are named
function GetLanguageTag(Lang: String): String;
begin
  if (Pos('_', Lang) > 0) then
    Lang[Pos('_', Lang)] := '-';
  Result := Lang;
end;

// Value of the compatibility entries ([Registry], AppCompatFlags\Layers) without the Windows
// version layer: RunAsAdmin for the task everyoneadminstart, Compatibility for the task
// compatibility. GetCompatibilityFlags (setup_is6.iss) passes the selected tasks.
function BuildCompatibilityFlags(const RunAsAdmin, Compatibility: Boolean): String;
begin
  Result := '~';
  if RunAsAdmin then
    Result := Result + ' RUNASADMIN';
  if Compatibility then
    Result := Result + ' DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation';
end;

const
  // Windows compatibility mode (Windows XP SP3) that setups up to 1.7.2 and the refactor branch
  // added on Windows Vista/7 with the task compatibility_windows. This setup no longer writes it;
  // only the cleanup of those old values (IsLegacyVistaCompatValue) still knows it.
  LegacyVistaCompatLayer = 'WINXPSP3';

// True on Windows older than 8 (NT 6.2), i.e. Windows Vista and 7 for the setup (Inno Setup 6
// setups do not start on older Windows): there the tasks compatibility and compatibility_windows
// do not exist (MinVersion Win8), and an update removes the values earlier setups wrote
// (IsLegacyVistaCompatValue). docs/adr/0005-compatibility-and-wrapper-defaults.md
function IsBelowWindows8(const WindowsMajor, WindowsMinor: Cardinal): Boolean;
begin
  Result := (WindowsMajor < 6) or ((WindowsMajor = 6) and (WindowsMinor < 2));
end;

// True if Value (AppCompatFlags\Layers) is exactly a value that setups up to 1.7.2 and the
// refactor branch wrote on Windows Vista/7 and that holds compatibility flags or the old Windows
// compatibility mode: BuildCompatibilityFlags(RunAsAdmin, Compatibility) followed by
// ' ' + LegacyVistaCompatLayer (task compatibility_windows), or without it if the flags of the
// task compatibility are in it. Six values in all; the plain '~' and '~ RUNASADMIN' are not among
// them ('~ RUNASADMIN' is what the opt-in task everyoneadminstart still writes on Windows Vista/7).
// The comparison is exact and case-sensitive: a value the player set or changed (other flags,
// another order, another case, extra spaces) is never one of them. Contract 3.7.
function IsLegacyVistaCompatValue(const Value: String): Boolean;
var
  I: Integer;
  RunAsAdmin, Compatibility: Boolean;
  Flags: String;
begin
  Result := False;
  for I := 0 to 3 do
  begin
    RunAsAdmin := (I and 1) <> 0;
    Compatibility := (I and 2) <> 0;
    Flags := BuildCompatibilityFlags(RunAsAdmin, Compatibility);
    if (Value = Flags + ' ' + LegacyVistaCompatLayer) or (Compatibility and (Value = Flags)) then
      Result := True;
  end;
end;

// True if the cleanup of the old Windows Vista/7 values (RemoveLegacyVistaCompatValues) removes
// Value, the compatibility value of one game program: a value of an earlier setup
// (IsLegacyVistaCompatValue), unless this run writes the value of that program itself with the
// opt-in task compatibility_legacy. LegacyOptInSelected: the task is selected; ProgramSelected: the
// component of the program is selected (game: Empire Earth.exe, gameaoc: EE-AOC.exe). The value of
// the task, BuildCompatibilityFlags(RunAsAdmin, True), is one of the old values, and [Registry] has
// written it before the cleanup runs, so without this exception the cleanup would delete it again.
// docs/adr/0010-opt-in-compatibility-on-windows-7.md, contract 3.7
function ShouldRemoveLegacyVistaCompatValue(const Value: String; const LegacyOptInSelected, ProgramSelected: Boolean): Boolean;
begin
  Result := IsLegacyVistaCompatValue(Value) and not (LegacyOptInSelected and ProgramSelected);
end;

// Uninstall key (below HKA) of this product
function GetUninstallRegPath(): String;
begin
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#AppID}}_is1';
end;

// Uninstall key (below HKA) of the other product: NeoEE in EE setups, EE in NeoEE setups
function GetOtherProductUninstallRegPath(): String;
begin
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#OtherAppID}}_is1';
end;

function IsGameInstalled(): Boolean;
begin
  Result := False;
  if RegValueExists(HKA, GetUninstallRegPath(), 'UninstallString')
  then begin
    Result := True;
  end;
end;

const
  // WinHTTP timeouts in milliseconds (WinHttpRequest.SetTimeouts): name resolution of
  // GetHttpStatus and of DownloadString, then connect, send and receive of both
  RequestResolveTimeoutMs = 6000;
  DownloadResolveTimeoutMs = 8000;
  HttpTimeoutMs = 4000;
  // Result of HttpGet when no HTTP answer arrived
  HttpRequestFailed = -1;
  // WinHttpRequestOption_SecureProtocols (WinHttpRequest.Option) and the protocols HttpGet asks
  // for on old Windows: TLS 1.0 ($80), TLS 1.1 ($200) and TLS 1.2 ($800), the set Inno Setup
  // 6.2.2 uses for its own downloads
  WinHttpRequestOptionSecureProtocols = 9;
  WinHttpSecureProtocolsTls10To12 = $A80;

// True on Windows older than 8.1 (NT 6.3): there WinHTTP does not offer TLS 1.1 and 1.2 to an
// application that relies on the default protocols (Windows 7 SP1 and 8 without KB3140245 and
// its registry value), so HttpGet asks for them explicitly (ApplyTlsProtocols). Windows 8.1 and
// later keep their defaults, which include TLS 1.2 and, on Windows 11, TLS 1.3. That the explicit
// protocols are enough on Windows 7 SP1 without KB3140245 is a hypothesis that the test plan
// checks (docs/adr/0006-strict-tls-and-server-certificates.md).
function NeedsExplicitTlsProtocols(const WindowsMajor, WindowsMinor: Cardinal): Boolean;
begin
  Result := (WindowsMajor < 6) or ((WindowsMajor = 6) and (WindowsMinor < 3));
end;

// Asks WinHttpRequest (a WinHttp.WinHttpRequest.5.1 object) for TLS 1.0 to 1.2 if
// NeedsExplicitTlsProtocols says so for the Windows version WindowsMajor.WindowsMinor. Returns
// what happened, for the log, or '' if nothing had to be done. No exception escapes: if the
// option cannot be set, the request continues with the protocols of the system.
// The setup only sets this option of its own request object; it never changes the SChannel or
// WinHTTP settings of the system (registry values such as DisabledByDefault or
// DefaultSecureProtocols).
function ApplyTlsProtocols(WinHttpRequest: Variant; const WindowsMajor, WindowsMinor: Cardinal): String;
begin
  Result := '';
  if not NeedsExplicitTlsProtocols(WindowsMajor, WindowsMinor) then
    Exit;
  try
    WinHttpRequest.Option[WinHttpRequestOptionSecureProtocols] := WinHttpSecureProtocolsTls10To12;
    Result := 'TLS 1.0, 1.1 and 1.2 requested explicitly (Windows ' + IntToStr(WindowsMajor) + '.' + IntToStr(WindowsMinor) + ')';
  except
    Result := 'unable to request TLS 1.0, 1.1 and 1.2 explicitly (Windows ' + IntToStr(WindowsMajor) + '.' + IntToStr(WindowsMinor) +
      '), the request uses the protocols of the system: ' + GetExceptionMessage;
  end;
end;

// The one HTTP implementation of the setup: a GET request with WinHTTP that returns the HTTP
// status code, or HttpRequestFailed if no answer arrived (offline, timeout, invalid TLS
// certificate, ...). Response is the body if ReadBody is set, else ''. HideQuery logs the URL
// without its query (telemetry requests carry the anonymous user id there).
// The request is synchronous: Open(..., False) makes Send return only when the answer has arrived
// or a timeout has expired, so the wizard does not react meanwhile, at worst for
// ResolveTimeoutMs + 3 * HttpTimeoutMs. It is not made asynchronous on purpose: the request
// object would have to outlive this function, and the setup statistics are sent when the setup
// is about to exit, which would cancel the request.
// There is no fallback to HTTP: the callers decide what to open or install from the answer, so
// it must come over validated TLS. WinHTTP refuses redirects from https to http by default
// (WinHttpRequestOption_EnableHttpsToHttpRedirects is left off). On Windows older than 8.1 the
// request asks for TLS 1.0 to 1.2 explicitly (ApplyTlsProtocols).
function HttpGet(const URL: String; const ResolveTimeoutMs: Integer; const ReadBody, HideQuery: Boolean; var Response: String): Integer;
var
  WinHttpRequest: Variant;
  LogURL, TlsNote: String;
  Version: TWindowsVersion;
begin
  Result := HttpRequestFailed;
  Response := '';
  LogURL := URL;
  if HideQuery and (Pos('?', LogURL) > 0) then
    LogURL := Copy(LogURL, 1, Pos('?', LogURL)) + '...';
  Log('HTTP GET ' + LogURL);

  try
    WinHttpRequest := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    GetWindowsVersionEx(Version);
    TlsNote := ApplyTlsProtocols(WinHttpRequest, Version.Major, Version.Minor);
    if TlsNote <> '' then
      Log('HTTP GET ' + LogURL + ': ' + TlsNote);
    WinHttpRequest.SetTimeouts(ResolveTimeoutMs, HttpTimeoutMs, HttpTimeoutMs, HttpTimeoutMs);
    WinHttpRequest.Open('GET', URL, False);
    WinHttpRequest.Send;
    Result := WinHttpRequest.Status;
    if ReadBody then
      Response := WinHttpRequest.ResponseText;
    Log('HTTP GET ' + LogURL + ': status ' + IntToStr(Result) + ', ' + IntToStr(Length(Response)) + ' characters read');
  except
    Log('HTTP GET ' + LogURL + ' failed: ' + GetExceptionMessage);
    Result := HttpRequestFailed;
    Response := '';
  end;
end;

// HTTP status of URL, or HttpRequestFailed (reachability check of the file servers, setup
// statistics): the answer is not read and the query is not logged. Synchronous, see HttpGet.
function GetHttpStatus(const URL: String): Integer;
var
  Ignored: String;
begin
  Result := HttpGet(URL, RequestResolveTimeoutMs, False, True, Ignored);
end;

// HTTP status of URL, or HttpRequestFailed, and its answer in Response (update API).
// Synchronous, see HttpGet.
function DownloadString(const URL: String; var Response: String): Integer;
begin
  Result := HttpGet(URL, DownloadResolveTimeoutMs, True, False, Response);
end;

// Percent-encodes S for a URL query value (RFC 3986): everything except A-Z a-z 0-9 - _ . ~ is
// sent as %XX of its UTF-8 bytes
function UrlEncode(const S: String): String;
var
  I, C, Next: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    C := Ord(S[I]);
    if (C >= $D800) and (C <= $DFFF) then
    begin
      // UTF-16 surrogate pair -> code point, a lone surrogate becomes U+FFFD
      Next := 0;
      if (C <= $DBFF) and (I < Length(S)) then
        Next := Ord(S[I + 1]);
      if (Next >= $DC00) and (Next <= $DFFF) then
      begin
        C := $10000 + ((C - $D800) shl 10) + (Next - $DC00);
        I := I + 1;
      end else
        C := $FFFD;
    end;

    if ((C >= Ord('A')) and (C <= Ord('Z'))) or ((C >= Ord('a')) and (C <= Ord('z'))) or
       ((C >= Ord('0')) and (C <= Ord('9'))) or (C = Ord('-')) or (C = Ord('_')) or (C = Ord('.')) or (C = Ord('~')) then
      Result := Result + Chr(C)
    else if C < $80 then
      Result := Result + Format('%%%.2X', [C])
    else if C < $800 then
      Result := Result + Format('%%%.2X%%%.2X', [$C0 or (C shr 6), $80 or (C and $3F)])
    else if C < $10000 then
      Result := Result + Format('%%%.2X%%%.2X%%%.2X', [$E0 or (C shr 12), $80 or ((C shr 6) and $3F), $80 or (C and $3F)])
    else
      Result := Result + Format('%%%.2X%%%.2X%%%.2X%%%.2X', [$F0 or (C shr 18), $80 or ((C shr 12) and $3F), $80 or ((C shr 6) and $3F), $80 or (C and $3F)]);
    I := I + 1;
  end;
end;

// Splits an absolute https URL into its host (lowercase) and the rest ('/' if empty). False for
// anything else and for URLs a check of the host could be fooled with: user info ('@'), ports,
// backslashes, spaces, control and non-ASCII characters.
function SplitHttpsUrl(const Url: String; var Host, Path: String): Boolean;
var
  I, P: Integer;
begin
  Result := False;
  Host := '';
  Path := '';
  if CompareText(Copy(Url, 1, 8), 'https://') <> 0 then
    Exit;
  for I := 1 to Length(Url) do
    if (Ord(Url[I]) <= 32) or (Ord(Url[I]) >= 127) or (Url[I] = '\') then
      Exit;

  Host := Copy(Url, 9, Length(Url));
  P := 0;
  for I := Length(Host) downto 1 do
    if (Host[I] = '/') or (Host[I] = '?') or (Host[I] = '#') then
      P := I;
  if P > 0 then
  begin
    Path := Copy(Host, P, Length(Host));
    Host := Copy(Host, 1, P - 1);
  end else
    Path := '/';
  Host := LowerCase(Host);
  Result := (Host <> '') and (Pos('@', Host) = 0) and (Pos(':', Host) = 0);
end;

// True if Host is Domain itself or one of its subdomains (both lowercase)
function IsDomainOrSubdomain(const Host, Domain: String): Boolean;
begin
  Result := (Host = Domain) or ((Length(Host) > Length(Domain) + 1) and
    (Copy(Host, Length(Host) - Length(Domain), Length(Domain) + 1) = '.' + Domain));
end;

// The download URL comes from the update API: only https URLs on the project's own hosts may be
// opened (EE community website, NeoEE website, EE-modders on GitHub)
function IsAllowedUpdateUrl(const Url: String): Boolean;
var
  Host, Path: String;
begin
  Result := False;
  if not SplitHttpsUrl(Url, Host, Path) then
    Exit;
  if IsDomainOrSubdomain(Host, DomainMain) or IsDomainOrSubdomain(Host, DomainNeoEE) then
    Result := True
  else if Host = GitHubHost then
    // Anyone can publish on github.com: only the EE-modders organization, no dot segments/escapes
    Result := (CompareText(Copy(Path, 1, Length(GitHubProjectPath)), GitHubProjectPath) = 0) and (Pos('..', Path) = 0) and (Pos('%', Path) = 0);
end;

// Download policy of the online localized files (downloads.iss)

const
  // Extensions (lowercase, each between '|') of files that can contain code which Windows, the game
  // or a mod loader runs: programs, libraries and plug-ins (Language.dll, ASI mods, the Miles Sound
  // System plug-ins .flt/.m3d that Mss32.dll loads), drivers,
  // scripts, installers and packages, shortcuts, registry and setup information files, compiled
  // help. A downloaded file of these types is only installed if its SHA-256 is compiled into the
  // setup (GetOnlineFileCheck).
  CodeFileExtensions = '|exe|dll|asi|ocx|sys|drv|scr|com|pif|cpl|efi|ax|acm|mui|flt|m3d|' +
    'bat|cmd|ps1|psm1|psd1|vbs|vbe|js|jse|wsf|wsh|wsc|sct|hta|' +
    'msi|msp|mst|msc|appx|msix|jar|' +
    'lnk|url|scf|reg|inf|chm|hlp|';

  // Results of GetOnlineFileCheck: how a downloaded file is accepted, or why it is not downloaded
  OnlineFilePinned = 1;           // only if it has the SHA-256 compiled into the setup
  OnlineFileTlsOnly = 2;          // data file, no SHA-256 known: accepted as the https server sends it
  OnlineFileRefusedCode = -1;     // may contain code and no SHA-256 is known
  OnlineFileRefusedInsecure = -2; // data file, no SHA-256 known and the URL is not https

// Extension of the last name of Path (after the last '\' or '/'), lowercase and without the dot,
// '' if it has none. Trailing dots and spaces do not count, as Windows drops them from file names
// ('Language.dll.' is Language.dll).
function GetFileNameExtension(const Path: String): String;
var
  I, Last: Integer;
  Name: String;
begin
  Name := Path;
  for I := Length(Name) downto 1 do
    if (Name[I] = '\') or (Name[I] = '/') then
    begin
      Name := Copy(Name, I + 1, Length(Name));
      Break;
    end;
  Last := Length(Name);
  while (Last > 0) and ((Name[Last] = '.') or (Name[Last] = ' ')) do
    Last := Last - 1;
  Name := Copy(Name, 1, Last);

  Result := '';
  for I := Length(Name) downto 1 do
    if Name[I] = '.' then
    begin
      Result := LowerCase(Copy(Name, I + 1, Length(Name)));
      Break;
    end;
end;

// True if the file (relative path or name) may contain code (CodeFileExtensions). A ':' (alternate
// data stream, drive) or a '|' in the extension also counts as code, so the list cannot be fooled.
function IsCodeFileName(const Path: String): Boolean;
var
  Ext: String;
begin
  Ext := GetFileNameExtension(Path);
  Result := (Pos(':', Path) > 0) or (Pos('|', Ext) > 0) or
    ((Ext <> '') and (Pos('|' + Ext + '|', CodeFileExtensions) > 0));
end;

// True if Url uses the https scheme (the downloads and HttpGet validate the certificate then)
function IsHttpsUrl(const Url: String): Boolean;
begin
  Result := (Length(Url) > 8) and (CompareText(Copy(Url, 1, 8), 'https://') = 0);
end;

// How the online file FileName (its download target) from Url is accepted, see the Online* results:
// with a known SHA-256 (SHA256 not empty) only if it matches, whatever the type. Without one, a file
// that may contain code is refused, a data file (voices, campaigns, movies, lobby texts) is accepted
// as the server sends it, but only over https with a validated certificate.
function GetOnlineFileCheck(const FileName, SHA256, Url: String): Integer;
begin
  if SHA256 <> '' then
    Result := OnlineFilePinned
  else if IsCodeFileName(FileName) then
    Result := OnlineFileRefusedCode
  else if not IsHttpsUrl(Url) then
    Result := OnlineFileRefusedInsecure
  else
    Result := OnlineFileTlsOnly;
end;

const
  // Outcome of one download attempt of an online file (DownloadOnlineFiles, downloads.iss)
  DownloadOutcomeSuccess = 0;      // complete, and it matches its pin if it has one
  DownloadOutcomeFailure = 1;      // network, TLS certificate, HTTP status, size, or stopped
  DownloadOutcomePinMismatch = 2;  // complete, but not the file of its pin (deleted)
  // What DownloadOnlineFiles does next (NextDownloadAction)
  DownloadActionAccept = 0;        // keep the file, go on with the next one
  DownloadActionTryMirror = 1;     // request the same file from the mirror
  DownloadActionGiveUp = 2;        // report the file as not downloaded, go on with the next one
  DownloadActionStopAll = 3;       // the user stopped the downloads: no further request at all

// Decides what happens after a download attempt with the result Outcome (DownloadOutcome*):
// MirrorAllowed if the file may be requested from the mirror (same GetOnlineFileCheck result
// there, so never over http without a pin), MirrorTried if this attempt or an earlier one of the
// same file was the mirror, StoppedByUser if the user stopped the downloads (the stop button of
// the download page, copied right after the attempt). A complete file is kept even if the stop
// came too late to cancel it; after a stop no further URL is requested, neither the mirror nor the
// next file. Any outcome other than success counts as a failed attempt.
function NextDownloadAction(const Outcome: Integer; const MirrorAllowed, MirrorTried, StoppedByUser: Boolean): Integer;
begin
  if Outcome = DownloadOutcomeSuccess then
    Result := DownloadActionAccept
  else if StoppedByUser then
    Result := DownloadActionStopAll
  else if MirrorAllowed and not MirrorTried then
    Result := DownloadActionTryMirror
  else
    Result := DownloadActionGiveUp;
end;

// Install state for the Empire Earth Launcher (installstate.iss): docs/CONTRACT.md 1.1 to 1.3,
// docs/adr/0004-install-record-and-integrity-manifest.md

// Install mode of the contract (1.1, 1.2): 'portable' in the portable variants, else 'admin' in
// the administrative install mode (HKA is HKLM) and 'user' in the non-administrative one (HKA is
// HKCU). GetContractInstallMode (installstate.iss) passes the variant and IsAdminInstallMode.
function InstallModeName(const PortableVariant, AdminInstallMode: Boolean): String;
begin
  if PortableVariant then
    Result := 'portable'
  else if AdminInstallMode then
    Result := 'admin'
  else
    Result := 'user';
end;

// True if every character of Text is ASCII (code 0 to 127). install.ini (and the manifest,
// S-WP7) are written with SaveStringToFile, which converts the text to the ANSI code page: only
// ASCII is the same in every code page and is valid UTF-8 without BOM, as contract 1.2 and 2.2
// ask. Inno Setup 6.2.2 has no UTF8Encode, so a text that is not ASCII is not written at all
// (ReplaceStateFile); its characters are never replaced (ADR 0004 point 5).
function IsAsciiText(const Text: String): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(Text) do
    if Ord(Text[I]) > 127 then
    begin
      Result := False;
      Exit;
    end;
end;

const
  // Line end of install.ini (contract 1.2)
  InstallIniLineEnd = #13#10;

// Text of install.ini (contract 1.2): the section [Install] with its keys in the order of the
// contract, ContractVersion, Product, AppId, InstallMode, GameVersion, SetupVersion, SetupBuild
// (only if it is not empty), Components, Tasks, Written, every line with CRLF. The values are
// taken as they are (AppId without braces, Components and Tasks as WizardSelectedComponents and
// WizardSelectedTasks return them, Written as yyyy-mm-dd hh:nn:ss); ReplaceStateFile checks that
// the complete text is ASCII before it writes it. The install root is not stored (it is the parent
// of the setup data folder), so the text holds no path. BuildMissingAfterInstallText gives the
// section [MissingAfterInstall] that follows it if installed files are gone.
function BuildInstallIniText(const ContractVersion: Integer; const Product, AppId, InstallMode,
  GameVersion, SetupVersion, SetupBuild, Components, Tasks, Written: String): String;
begin
  Result := '[Install]' + InstallIniLineEnd +
    'ContractVersion=' + IntToStr(ContractVersion) + InstallIniLineEnd +
    'Product=' + Product + InstallIniLineEnd +
    'AppId=' + AppId + InstallIniLineEnd +
    'InstallMode=' + InstallMode + InstallIniLineEnd +
    'GameVersion=' + GameVersion + InstallIniLineEnd +
    'SetupVersion=' + SetupVersion + InstallIniLineEnd;
  if SetupBuild <> '' then
    Result := Result + 'SetupBuild=' + SetupBuild + InstallIniLineEnd;
  Result := Result +
    'Components=' + Components + InstallIniLineEnd +
    'Tasks=' + Tasks + InstallIniLineEnd +
    'Written=' + Written + InstallIniLineEnd;
end;

// True if the value 'Empire Earth Community: ContractVersion' goes into the uninstall key at the
// end of ssPostInstall (contract 1.3, 2.1 and 2.5, ADR 0004 point 9): only in a variant with an
// uninstall key (HasUninstallKey: Regular, not Portable), only if ssInstall deleted the state
// files of the previous run (StateDeleted), and only if this run wrote and renamed every state file
// (StateWritten: install.ini; with S-WP7 also the manifest). Inno Setup recreates the uninstall key
// on every run, so without the value the launcher reports the state Unknown instead of trusting
// files of an earlier run, also of a setup up to 1.7.2 that ran later.
function ShouldWriteContractVersionValue(const HasUninstallKey, StateDeleted, StateWritten: Boolean): Boolean;
begin
  Result := HasUninstallKey and StateDeleted and StateWritten;
end;

const
  // Suffix of the temporary file that ReplaceStateFile writes first (install.ini.tmp)
  StateFileTempSuffix = '.tmp';

// Deletes the file FileName if it exists. True if it does not exist afterwards. Otherwise logs
// that it could not be deleted (read-only, or held open by another program without
// FILE_SHARE_DELETE, or no access) and returns False. A folder of that name does not count as the
// file (FileExists); RenameFile in ReplaceStateFile then fails on it.
function DeleteStateFile(const FileName: String): Boolean;
var
  FindRec: TFindRec;
  Cause: String;
begin
  if FileExists(FileName) and not DeleteFile(FileName) then
  begin
    Cause := 'it is held open by another program or access is denied';
    if FindFirst(FileName, FindRec) then
    try
      if (FindRec.Attributes and FILE_ATTRIBUTE_READONLY) <> 0 then
        Cause := 'it is read-only';
    finally
      FindClose(FindRec);
    end;
    Log('Unable to delete ' + FileName + ': ' + Cause);
  end;
  Result := not FileExists(FileName);
end;

// Writes Text to FileName through the temporary file FileName + StateFileTempSuffix (contract 1.2
// and 2.1, ADR 0004 point 4): the text must be ASCII (IsAsciiText); a temporary file left by an
// aborted run is deleted; the text is written with SaveStringToFile (no BOM, the characters as
// they are); FileName is deleted and must be gone, because RenameFile (MoveFile without
// MOVEFILE_REPLACE_EXISTING) never overwrites; then the temporary file is renamed. True if FileName
// holds Text now. On any failure the cause is logged, the temporary file is deleted and the result
// is False; FileName is then either gone or still the old file, never a partly written one.
function ReplaceStateFile(const FileName, Text: String): Boolean;
var
  TempName: String;
begin
  Result := False;
  TempName := FileName + StateFileTempSuffix;
  if not IsAsciiText(Text) then
  begin
    Log('Not writing ' + FileName + ': its text is not ASCII');
    Exit;
  end;
  try
    if not DeleteStateFile(TempName) then
      Log('Not writing ' + FileName + ': the old temporary file is still there')
    else if not SaveStringToFile(TempName, Text, False) then
      Log('Not writing ' + FileName + ': unable to write ' + TempName)
    else if not DeleteStateFile(FileName) then
      Log('Not writing ' + FileName + ': the old file is still there')
    else if not RenameFile(TempName, FileName) then
      Log('Not writing ' + FileName + ': unable to rename ' + TempName)
    else
      Result := True;
  except
    Log('Not writing ' + FileName + ': ' + GetExceptionMessage);
  end;
  if not Result then
    DeleteStateFile(TempName);
end;

// Integrity manifest files.sha256 for the Empire Earth Launcher (installstate.iss): docs/CONTRACT.md
// 1.2 and 2, docs/adr/0004-install-record-and-integrity-manifest.md points 3 to 8

const
  // Line end of files.sha256 (contract 2.2)
  ManifestLineEnd = #10;
  // First letters of the uninstaller files in the install root (unins000.exe, unins000.dat)
  UninstallerFilePrefix = 'unins';
  // The notice FilesMissingAfterInstall names at most this many files (FormatMissingFileList)
  MissingFilesShownMax = 10;

// Manifest path (contract 2.2) of the file FullPath below the install root InstallRoot (both full
// Windows paths, a trailing '\' of the root does not count): the part after the root and its '\',
// with '/' as separator. False (RelPath '') for a path that is not below the root (the root is
// compared ignoring case and must be followed by '\'), for the root itself, and for a rest that
// contains ':' (drive, alternate data stream) or '/', or an empty, '.' or '..' segment: the
// launcher treats such a manifest line as invalid, so the setup never writes one.
function GetManifestPath(const InstallRoot, FullPath: String; var RelPath: String): Boolean;
var
  Root, Rest: String;
  Segments: TArrayOfString;
  I: Integer;
begin
  Result := False;
  RelPath := '';
  Root := InstallRoot;
  while (Length(Root) > 0) and (Root[Length(Root)] = '\') do
    Root := Copy(Root, 1, Length(Root) - 1);
  if (Root = '') or (Length(FullPath) <= Length(Root) + 1) then
    Exit;
  if (CompareText(Copy(FullPath, 1, Length(Root)), Root) <> 0) or (FullPath[Length(Root) + 1] <> '\') then
    Exit;
  Rest := Copy(FullPath, Length(Root) + 2, Length(FullPath));
  // StrSplit drops a trailing separator, so a trailing '\' is checked here
  if (Pos(':', Rest) > 0) or (Pos('/', Rest) > 0) or (Rest[Length(Rest)] = '\') then
    Exit;
  Segments := StrSplit(Rest, '\');
  for I := 0 to GetArrayLength(Segments) - 1 do
    if (Segments[I] = '') or (Segments[I] = '.') or (Segments[I] = '..') then
      Exit;
  RelPath := Rest;
  StringChangeEx(RelPath, '\', '/', True);
  Result := True;
end;

// True if the manifest leaves out the manifest path RelPath even if a [Files] entry names it
// (contract 2.3): everything in the setup data folder SetupDataDir (its first segment, ignoring
// case) and the uninstaller unins*.exe, unins*.dat in the install root
function IsManifestExcludedPath(const RelPath, SetupDataDir: String): Boolean;
var
  Slash: Integer;
  Ext: String;
begin
  Slash := Pos('/', RelPath);
  if Slash > 0 then
    Result := CompareText(Copy(RelPath, 1, Slash - 1), SetupDataDir) = 0
  else
  begin
    Ext := GetFileNameExtension(RelPath);
    Result := (CompareText(Copy(RelPath, 1, Length(UninstallerFilePrefix)), UninstallerFilePrefix) = 0) and
      ((Ext = 'exe') or (Ext = 'dat'));
  end;
end;

// One line of files.sha256 (contract 2.2): the SHA-256 in lowercase hex, two spaces, the manifest
// path, LF
function ManifestLine(const SHA256, RelPath: String): String;
begin
  Result := LowerCase(SHA256) + '  ' + RelPath + ManifestLineEnd;
end;

// Order of the manifest paths (contract 2.2): ordinal, ignoring case. Both paths are compared in
// uppercase (UpperCase changes only a-z), as .NET's StringComparer.OrdinalIgnoreCase and
// 'LC_ALL=C sort -f' do for ASCII, so '_' (after 'Z') sorts after the letters. < 0, 0 or > 0.
function CompareManifestPaths(const A, B: String): Integer;
begin
  Result := CompareStr(UpperCase(A), UpperCase(B));
end;

// Sorts Paths in the order of CompareManifestPaths with a bottom-up merge sort and returns the
// number of comparisons: at most n * ceil(log2 n), about 20000 for the 1800 paths of an
// installation, where an insertion sort in interpreted Pascal Script could need 1.6 million. Stable:
// paths that differ only in case keep their order (RemoveDuplicateManifestPaths relies on it). The
// uppercase keys are computed once per path.
function MergeSortManifestPaths(var Paths: TArrayOfString): Integer;
var
  N, Width, Left, Mid, Right, I, J, K: Integer;
  Keys, NextKeys, NextPaths: TArrayOfString;
  TakeLeft: Boolean;
begin
  Result := 0;
  N := GetArrayLength(Paths);
  SetArrayLength(Keys, N);
  SetArrayLength(NextKeys, N);
  SetArrayLength(NextPaths, N);
  for I := 0 to N - 1 do
    Keys[I] := UpperCase(Paths[I]);
  Width := 1;
  while Width < N do
  begin
    // Merge the neighbouring runs [Left, Mid) and [Mid, Right) of length Width
    Left := 0;
    while Left < N do
    begin
      Mid := Left + Width;
      if Mid > N then
        Mid := N;
      Right := Mid + Width;
      if Right > N then
        Right := N;
      I := Left;
      J := Mid;
      for K := Left to Right - 1 do
      begin
        if (I < Mid) and (J < Right) then
        begin
          Result := Result + 1;
          // The right one only if it is smaller: equal keys keep their order
          TakeLeft := CompareStr(Keys[J], Keys[I]) >= 0;
        end
        else
          TakeLeft := I < Mid;
        if TakeLeft then
        begin
          NextKeys[K] := Keys[I];
          NextPaths[K] := Paths[I];
          I := I + 1;
        end
        else
        begin
          NextKeys[K] := Keys[J];
          NextPaths[K] := Paths[J];
          J := J + 1;
        end;
      end;
      Left := Right;
    end;
    for I := 0 to N - 1 do
    begin
      Keys[I] := NextKeys[I];
      Paths[I] := NextPaths[I];
    end;
    Width := Width * 2;
  end;
end;

// Removes from Paths, sorted by MergeSortManifestPaths, every path that the next one repeats
// ignoring case, so that each file is listed once, with the spelling of the entry recorded last
// (contract 2.3: a later [Files] entry that overwrites a file replaces the earlier one). Returns the
// number of removed paths.
function RemoveDuplicateManifestPaths(var Paths: TArrayOfString): Integer;
var
  I, Count: Integer;
  Keep: Boolean;
begin
  Count := 0;
  for I := 0 to GetArrayLength(Paths) - 1 do
  begin
    Keep := I = GetArrayLength(Paths) - 1;
    if not Keep then
      Keep := CompareManifestPaths(Paths[I], Paths[I + 1]) <> 0;
    if Keep then
    begin
      Paths[Count] := Paths[I];
      Count := Count + 1;
    end;
  end;
  Result := GetArrayLength(Paths) - Count;
  SetArrayLength(Paths, Count);
end;

// Section [MissingAfterInstall] of install.ini (contract 1.2), appended to BuildInstallIniText: an
// empty line, the section and the manifest paths of Missing under the keys 1, 2, ..., every line
// with CRLF; '' if Missing is empty. A path that is not ASCII is left out (contract 1.2: never
// written, not even with replaced characters; the caller logs it), the keys stay consecutive.
function BuildMissingAfterInstallText(const Missing: TArrayOfString): String;
var
  I, Key: Integer;
begin
  Result := '';
  Key := 0;
  for I := 0 to GetArrayLength(Missing) - 1 do
    if IsAsciiText(Missing[I]) then
    begin
      if Key = 0 then
        Result := InstallIniLineEnd + '[MissingAfterInstall]' + InstallIniLineEnd;
      Key := Key + 1;
      Result := Result + IntToStr(Key) + '=' + Missing[I] + InstallIniLineEnd;
    end;
end;

// The file list of the notice FilesMissingAfterInstall (%1): a line break and two spaces before
// each manifest path of Missing, with '\' instead of '/' as the player sees paths, at most MaxNames
// of them, then one more line MoreText with %1 = the number of paths not shown
// (FilesMissingAfterInstallMore, 'and %1 more')
function FormatMissingFileList(const Missing: TArrayOfString; const MaxNames: Integer; const MoreText: String): String;
var
  I: Integer;
  Name: String;
begin
  Result := '';
  for I := 0 to GetArrayLength(Missing) - 1 do
    if I < MaxNames then
    begin
      Name := Missing[I];
      StringChangeEx(Name, '/', '\', True);
      Result := Result + #13#10 + '  ' + Name;
    end;
  if GetArrayLength(Missing) > MaxNames then
    Result := Result + #13#10 + '  ' + FmtMessage(MoreText, [IntToStr(GetArrayLength(Missing) - MaxNames)]);
end;

// A number of tenths as text with one decimal: 15123 -> '1512.3'
function TenthsToStr(const Tenths: Int64): String;
begin
  Result := IntToStr(Tenths div 10) + '.' + IntToStr(Tenths mod 10);
end;

// The log line of the manifest (ADR 0004 point 4) for FileCount hashed files of Bytes bytes in
// ElapsedMs milliseconds: 'Manifest: <n> files, <MB> MB, <ms> ms, <MB/s> MB/s', MB = 1048576 bytes,
// rounded to one decimal; less than 1 ms counts as 1 ms for the throughput
function FormatManifestSummary(const FileCount: Integer; const Bytes, ElapsedMs: Int64): String;
var
  Ms: Int64;
begin
  Ms := ElapsedMs;
  if Ms < 1 then
    Ms := 1;
  Result := 'Manifest: ' + IntToStr(FileCount) + ' files, ' + TenthsToStr((Bytes * 10 + 524288) div 1048576) + ' MB, ' +
    IntToStr(ElapsedMs) + ' ms, ' + TenthsToStr((Bytes * 10000 + Ms * 524288) div (Ms * 1048576)) + ' MB/s';
end;
