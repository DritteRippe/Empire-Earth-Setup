[Code]
// Base helpers of the [Code] part: the URL constants, string split, language tag, compatibility
// flags, uninstall keys of EE and NeoEE, the HTTP requests, URL checks, the download policy of
// the online localized files, the states of their file servers and the WinHTTP requests for pinned
// files, the install state for the launcher (install mode, install.ini,
// writing a state file, the integrity manifest files.sha256), the environment checks before the
// installation (game window size, low screen, folders and uninstall entries of other
// installations) and the link check of the folders all users can write to (reparse points).
// Included first, before every other [Code] part.
// Requires: AppID, OtherAppID (ISPP, product configuration config_*.iss).
// The functions without wizard access are tested by ci/tests/unit_tests.iss.

// All requests use HTTPS and never fall back to HTTP: the answers decide what the (elevated) setup
// opens or installs. All of them validate the certificate, except the two WinHTTP requests for
// pinned online files (GetHttpStatusIgnoringCertificate, DownloadPinnedFileWinHttp in
// downloads.iss), whose answer only counts if the file matches its SHA-256 pin (ADR 0012).
const
  // Hosts: the EE community website and the mirror of its file server
  DomainMain = 'empireearth.eu';
  DomainMirror = 'ee.zocker-160.de';
  // One base URL per endpoint; the code only appends paths and parameters
  SetupURL = 'https://' + DomainMain + '/download/';                     // download page of both setups (contract 4.3)
  SetupURLEE = SetupURL + 'ee/';                                         // download page of the EE setup
  SetupURLNeoEE = SetupURL + 'neo/';                                     // download page of the NeoEE setup
  ApiURL = 'https://api.' + DomainMain;                                  // web API of the website
  UpdateApiURL = ApiURL + '/setup/?product={#AppID}';                    // update check, &type= only (QueryUpdateApi)
  TelemetryApiURL = ApiURL + '/eestats/setup/';                          // setup statistics (SendSetupTelemetry)
  OnlineFilesURL = 'https://files.' + DomainMain + '/localized';         // localized files (downloads.iss)
  OnlineFilesMirrorURL = 'https://storage.' + DomainMirror + '/localized';
  GogStoreURL = 'https://www.gog.com/game/empire_earth_gold_edition';    // legal question

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
  // Revision of the default components (install record value ComponentDefaults, contract 1.1, revision 6): 1 = the intro
  // movies (additional\movies) belong to the types full and compact (suite 1.1.0). Raise it with the next component that
  // becomes a default for existing installations, and select that one in SelectNewDefaultComponents (setup_is6.iss).
  ComponentDefaultsRevision = 1;

// Why an update selects no new default component; '' = it selects them (SelectNewDefaultComponents). HasPrevious: the
// uninstall key of a previous installation exists; Explicit: /TYPE=, /COMPONENTS= or /LOADINF= (an answer file may carry Components=) is on the command line; SetupType: the
// type Inno Setup took over from the previous installation (WizardSetupType(False)); Recorded: ComponentDefaults of the
// install record (0 if missing: product setups before suite 1.1.0 and 1.7.2); Selected: the component is selected already.
function NewDefaultComponentSkipReason(const HasPrevious, Explicit: Boolean; const SetupType: String;
  const Recorded: Integer; const Selected: Boolean): String;
begin
  if not HasPrevious then
    Result := 'no previous installation (the setup type decides)'
  else if Explicit then
    Result := '/TYPE, /COMPONENTS or /LOADINF on the command line'
  else if Recorded >= ComponentDefaultsRevision then
    Result := 'already done by an earlier run (ComponentDefaults ' + IntToStr(Recorded) + ')'
  else if CompareText(SetupType, 'raw') = 0 then
    Result := 'the setup type raw installs no additional content'
  else if CompareText(SetupType, 'custom') <> 0 then
    Result := 'the setup type ' + SetupType + ' selects them itself'
  else if Selected then
    Result := 'already selected'
  else
    Result := '';
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
  // WinHttpRequestOption_EnableRedirects (WinHttpRequest.Option): False makes WinHTTP return a
  // redirect to the caller instead of following it
  WinHttpRequestOptionEnableRedirects = 6;

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

// True for the HTTP status codes of a redirect that clients follow with the Location header: 301,
// 302, 303, 307, 308
function IsRedirectStatus(const Status: Integer): Boolean;
begin
  Result := (Status = 301) or (Status = 302) or (Status = 303) or (Status = 307) or (Status = 308);
end;

// The one HTTP implementation of the setup: a request (Method GET or HEAD) with WinHTTP that returns
// the HTTP status code, or HttpRequestFailed if no answer arrived (offline, timeout, invalid TLS
// certificate, ...). Response is the body if ReadBody is set, else ''. HideQuery logs the URL
// without its query (telemetry requests carry the anonymous user id there). FollowRedirects False
// switches WinHTTP's own redirects off: then a redirect is the result itself, and Location is its
// Location header ('' if there is none; always '' otherwise), see CheckOnlineFileRedirects
// (downloads.iss).
// The request is synchronous: Open(..., False) makes Send return only when the answer has arrived
// or a timeout has expired, so the wizard does not react meanwhile, at worst for
// ResolveTimeoutMs + 3 * HttpTimeoutMs. It is not made asynchronous on purpose: the request
// object would have to outlive this function, and the setup statistics are sent when the setup
// is about to exit, which would cancel the request.
// There is no fallback to HTTP: the callers decide what to open or install from the answer, so
// it must come over validated TLS. WinHTTP refuses redirects from https to http by default
// (WinHttpRequestOption_EnableHttpsToHttpRedirects is left off). On Windows older than 8.1 the
// request asks for TLS 1.0 to 1.2 explicitly (ApplyTlsProtocols).
function HttpRequest(const Method, URL: String; const ResolveTimeoutMs: Integer; const ReadBody, HideQuery, FollowRedirects: Boolean;
  var Response, Location: String): Integer;
var
  WinHttpRequest: Variant;
  LogURL, TlsNote, LocationNote: String;
  Version: TWindowsVersion;
begin
  Result := HttpRequestFailed;
  Response := '';
  Location := '';
  LogURL := URL;
  if HideQuery and (Pos('?', LogURL) > 0) then
    LogURL := Copy(LogURL, 1, Pos('?', LogURL)) + '...';
  Log('HTTP ' + Method + ' ' + LogURL);

  try
    WinHttpRequest := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    GetWindowsVersionEx(Version);
    TlsNote := ApplyTlsProtocols(WinHttpRequest, Version.Major, Version.Minor);
    if TlsNote <> '' then
      Log('HTTP ' + Method + ' ' + LogURL + ': ' + TlsNote);
    WinHttpRequest.SetTimeouts(ResolveTimeoutMs, HttpTimeoutMs, HttpTimeoutMs, HttpTimeoutMs);
    WinHttpRequest.Open(Method, URL, False);
    // Windows: WinHTTP returns a redirect instead of following it. Wine 9.0 ignores this option and
    // follows redirects itself, refusing one from https to http with an error (no answer).
    if not FollowRedirects then
      WinHttpRequest.Option[WinHttpRequestOptionEnableRedirects] := False;
    WinHttpRequest.Send;
    Result := WinHttpRequest.Status;
    if ReadBody then
      Response := WinHttpRequest.ResponseText;
    LocationNote := '';
    if not FollowRedirects and IsRedirectStatus(Result) then
    begin
      try
        Location := WinHttpRequest.GetResponseHeader('Location');
      except
        Location := '';
      end;
      LocationNote := ', Location "' + Location + '"';
    end;
    Log('HTTP ' + Method + ' ' + LogURL + ': status ' + IntToStr(Result) + ', ' + IntToStr(Length(Response)) + ' characters read' + LocationNote);
  except
    Log('HTTP ' + Method + ' ' + LogURL + ' failed: ' + GetExceptionMessage);
    Result := HttpRequestFailed;
    Response := '';
    Location := '';
  end;
end;

// GET request with WinHTTP's own redirects (HttpRequest)
function HttpGet(const URL: String; const ResolveTimeoutMs: Integer; const ReadBody, HideQuery: Boolean; var Response: String): Integer;
var
  Ignored: String;
begin
  Result := HttpRequest('GET', URL, ResolveTimeoutMs, ReadBody, HideQuery, True, Response, Ignored);
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

// The download page of the setup of InstallType (contract 4.3): EE and NeoEE their own page, anything else the page of
// both. No request: the website redirects the browser to the current setup.
function ProductDownloadPage(const InstallType: String): String;
begin
  if CompareText(InstallType, 'EE') = 0 then
    Result := SetupURLEE
  else if CompareText(InstallType, 'NeoEE') = 0 then
    Result := SetupURLNeoEE
  else
    Result := SetupURL;
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

// The URL that a redirect from Url (an absolute URL) with the Location header Location leads to, as
// far as its scheme and server matter (RFC 3986 section 5.2; dot segments are kept, they cannot
// change either): Location itself if it has a scheme (a ':' before any '/', '?', '#' or '\': http:,
// https:, file:, ...), the scheme of Url before a network-path reference ('//server/path'), the
// scheme and server of Url before an absolute path ('/path'), Url without its query and fragment
// before a query ('?q') or fragment, else the folder of Url before a relative path. '' if Location is
// empty or Url has no '://'. Leading and trailing spaces of Location are ignored.
function ResolveRedirectUrl(const Url, Location: String): String;
var
  L, Base: String;
  I, SchemeEnd, PathStart: Integer;
begin
  Result := '';
  L := Trim(Location);
  SchemeEnd := Pos('://', Url);
  if (L = '') or (SchemeEnd = 0) then
    Exit;
  for I := 1 to Length(L) do
  begin
    if L[I] = ':' then
    begin
      Result := L;
      Exit;
    end;
    if (L[I] = '/') or (L[I] = '?') or (L[I] = '#') or (L[I] = '\') then
      Break;
  end;
  if Copy(L, 1, 2) = '//' then
  begin
    Result := Copy(Url, 1, SchemeEnd) + L;
    Exit;
  end;
  // Url without query and fragment, and where its path starts (after the server)
  Base := Url;
  for I := SchemeEnd + 3 to Length(Base) do
    if (Base[I] = '?') or (Base[I] = '#') then
    begin
      Base := Copy(Base, 1, I - 1);
      Break;
    end;
  PathStart := Length(Base) + 1;
  for I := SchemeEnd + 3 to Length(Base) do
    if Base[I] = '/' then
    begin
      PathStart := I;
      Break;
    end;
  if Copy(L, 1, 1) = '/' then
    Result := Copy(Base, 1, PathStart - 1) + L
  else if (Copy(L, 1, 1) = '?') or (Copy(L, 1, 1) = '#') then
    Result := Base + L
  else
  begin
    if PathStart > Length(Base) then
      Base := Base + '/';
    I := Length(Base);
    while Base[I] <> '/' do
      I := I - 1;
    Result := Copy(Base, 1, I) + L;
  end;
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

// The file servers of the online localized files without a valid certificate (downloads.iss,
// docs/adr/0012-pinned-downloads-despite-invalid-certificates.md): the state of each server, which
// transport a file gets from it, the size limit of a pinned download, and WinHTTP itself for the
// one transport that ignores certificate errors. That transport is only ever used for a file with a
// SHA-256 pin: the file is only kept if it matches the pin, so the certificate does not decide
// what is installed. A file without pin still needs a validated certificate (ADR 0003, ADR 0006).

const
  // State of a file server, as SelectOnlineFilesServer (downloads.iss) finds it before the first
  // download (ClassifyOnlineFilesServer)
  OnlineServerUnreachable = 0;         // no HTTP answer, neither with nor without certificate validation
  OnlineServerVerified = 1;            // an HTTP answer over TLS with a validated certificate
  OnlineServerCertificateInvalid = 2;  // an HTTP answer only without certificate validation
  OnlineServerNotChecked = 3;          // not asked because the other server is verified: only the
                                       // built-in downloads, which validate the certificate themselves
  // Which server SelectOnlineFilesServer uses first (ChooseOnlineFilesServerOrder)
  OnlineFilesOrderNone = 0;            // neither server can be used
  OnlineFilesOrderMainFirst = 1;
  OnlineFilesOrderMirrorFirst = 2;
  // How an online file is downloaded from one server (GetOnlineFileTransport)
  DownloadTransportNone = 0;           // not from this server
  DownloadTransportBuiltIn = 1;        // Inno Setup's built-in download, the certificate is validated
  DownloadTransportPinnedWinHttp = 2;  // WinHTTP with certificate errors ignored: pinned files only,
                                       // the SHA-256 decides (DownloadPinnedFileWinHttp, downloads.iss)
  // Largest pinned download whose size the setup does not know (a pin of the build's own hash list
  // without an entry in pins\online-files.txt); the largest online file has 172 MB
  UnsizedPinnedDownloadMaxBytes = 1073741824;

// State of a file server from its two probes (SelectOnlineFilesServer): StrictStatus is the HTTP
// status of the request with a validated certificate (GetHttpStatus), LenientStatus that of the
// request without certificate validation (GetHttpStatusIgnoringCertificate; HttpRequestFailed if it
// was not sent, e.g. because the setup has no pins), both HttpRequestFailed without an answer. Any
// HTTP status counts as an answer.
function ClassifyOnlineFilesServer(const StrictStatus, LenientStatus: Integer): Integer;
begin
  if StrictStatus <> HttpRequestFailed then
    Result := OnlineServerVerified
  else if LenientStatus <> HttpRequestFailed then
    Result := OnlineServerCertificateInvalid
  else
    Result := OnlineServerUnreachable;
end;

// Order of the server states for ChooseOnlineFilesServerOrder: verified (or not checked, i.e. only
// the validating built-in downloads) before an invalid certificate before no answer
function OnlineServerRank(const State: Integer): Integer;
begin
  if (State = OnlineServerVerified) or (State = OnlineServerNotChecked) then
    Result := 2
  else if State = OnlineServerCertificateInvalid then
    Result := 1
  else
    Result := 0;
end;

// Which file server SelectOnlineFilesServer uses first (OnlineFilesOrder*): the one in the better
// state (OnlineServerRank), the main server if both are in the same state, none if neither answers
function ChooseOnlineFilesServerOrder(const MainState, MirrorState: Integer): Integer;
begin
  if (OnlineServerRank(MainState) = 0) and (OnlineServerRank(MirrorState) = 0) then
    Result := OnlineFilesOrderNone
  else if OnlineServerRank(MirrorState) > OnlineServerRank(MainState) then
    Result := OnlineFilesOrderMirrorFirst
  else
    Result := OnlineFilesOrderMainFirst;
end;

// How a file with the GetOnlineFileCheck result Check is downloaded from a server in the state
// ServerState (DownloadTransport*): a server with a validated certificate (or one that was not
// checked) gets the built-in download for every file the policy accepts; a server that only
// answers without certificate validation only gets pinned files, with WinHTTP and certificate
// errors ignored (the SHA-256 decides); a file without pin never comes from it, and nothing comes
// from a server without an answer. Refused files (code without pin, http URL) get no transport.
function GetOnlineFileTransport(const Check, ServerState: Integer): Integer;
begin
  Result := DownloadTransportNone;
  if (Check <> OnlineFilePinned) and (Check <> OnlineFileTlsOnly) then
    Exit;
  if (ServerState = OnlineServerVerified) or (ServerState = OnlineServerNotChecked) then
    Result := DownloadTransportBuiltIn
  else if (ServerState = OnlineServerCertificateInvalid) and (Check = OnlineFilePinned) then
    Result := DownloadTransportPinnedWinHttp;
end;

// True while a download of a pinned file stays within its pinned size: Progress bytes received so
// far, ProgressMax the size the server announced (Content-Length; 0 or less if it sent none),
// PinnedSize the size of the pin (pins\online-files.txt), -1 if unknown. A different announced
// size or more bytes than pinned end the download early: it could never match the pin, and the
// limit keeps a server from filling the disk. Without a known size only UnsizedPinnedDownloadMaxBytes
// applies.
function IsDownloadSizeAcceptable(const Progress, ProgressMax, PinnedSize: Int64): Boolean;
begin
  if PinnedSize >= 0 then
    Result := (Progress >= 0) and (Progress <= PinnedSize) and ((ProgressMax <= 0) or (ProgressMax = PinnedSize))
  else
    Result := (Progress >= 0) and (Progress <= UnsizedPinnedDownloadMaxBytes) and (ProgressMax <= UnsizedPinnedDownloadMaxBytes);
end;

// True if a download has passed the next progress line that is not logged yet: Received of Total bytes, NextPercent the
// next step (10, 20, ... 100; 110 once the last one is logged). Then NextPercent moves past every step that is reached,
// so each step is logged once and a jump over several steps logs one line. False without a known total size. Both
// transports of the online files use it (the line "<X> of <Y> bytes done." is read by the suite, contract 1.7 point 5).
function IsProgressLogDue(const Received, Total: Int64; var NextPercent: Integer): Boolean;
begin
  Result := (Total > 0) and (NextPercent <= 100) and (Received * 100 >= Total * NextPercent);
  if Result then
    while (NextPercent <= 100) and (Received * 100 >= Total * NextPercent) do
      NextPercent := NextPercent + 10;
end;

// The size of a pin as pins\online-files.txt writes it: a positive decimal number of at most 15
// digits without sign, spaces or leading zero; -1 for anything else
function ParsePinnedSize(const Text: String): Int64;
var
  I: Integer;
  Value: Int64;
begin
  Result := -1;
  if (Length(Text) = 0) or (Length(Text) > 15) or (Text[1] = '0') then
    Exit;
  Value := 0;
  for I := 1 to Length(Text) do
  begin
    if (Text[I] < '0') or (Text[I] > '9') then
      Exit;
    Value := Value * 10 + (Ord(Text[I]) - Ord('0'));
  end;
  Result := Value;
end;

// Splits the https URL of an online file into what WinHTTP needs: the host (lowercase; letters,
// digits, '.' and '-' only), the port (443 unless given, 1 to 65535) and the object name, the path
// with every segment percent-encoded (UrlEncode: a space becomes %20, non-ASCII its UTF-8 bytes,
// '/' stays), '/' if empty. The path is taken as it is written, unencoded, like the server paths of
// RegisterOnlineFiles. False for anything else: another scheme, user info ('@'), a query or
// fragment ('?', '#'), backslashes, control characters, an empty host or a bad port.
function SplitDownloadUrl(const Url: String; var Host: String; var Port: Integer; var ObjectName: String): Boolean;
var
  I, P: Integer;
  Rest, Authority, Path, PortText, Segment: String;
  C: Char;
begin
  Result := False;
  Host := '';
  Port := 443;
  ObjectName := '';
  if CompareText(Copy(Url, 1, 8), 'https://') <> 0 then
    Exit;
  for I := 1 to Length(Url) do
    if (Ord(Url[I]) < 32) or (Ord(Url[I]) = 127) or (Url[I] = '\') or (Url[I] = '@') or (Url[I] = '?') or (Url[I] = '#') then
      Exit;

  Rest := Copy(Url, 9, Length(Url));
  P := Pos('/', Rest);
  if P > 0 then
  begin
    Authority := Copy(Rest, 1, P - 1);
    Path := Copy(Rest, P, Length(Rest));
  end else
  begin
    Authority := Rest;
    Path := '/';
  end;

  P := Pos(':', Authority);
  if P > 0 then
  begin
    PortText := Copy(Authority, P + 1, Length(Authority));
    Authority := Copy(Authority, 1, P - 1);
    if (Length(PortText) = 0) or (Length(PortText) > 5) then
      Exit;
    Port := 0;
    for I := 1 to Length(PortText) do
    begin
      if (PortText[I] < '0') or (PortText[I] > '9') then
        Exit;
      Port := Port * 10 + (Ord(PortText[I]) - Ord('0'));
    end;
    if (Port < 1) or (Port > 65535) then
      Exit;
  end;
  if Authority = '' then
    Exit;
  for I := 1 to Length(Authority) do
  begin
    C := Authority[I];
    if not (((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or (C = '.') or (C = '-')) then
      Exit;
  end;
  Host := LowerCase(Authority);

  Segment := '';
  for I := 1 to Length(Path) do
    if Path[I] = '/' then
    begin
      ObjectName := ObjectName + UrlEncode(Segment) + '/';
      Segment := '';
    end else
      Segment := Segment + Path[I];
  ObjectName := ObjectName + UrlEncode(Segment);
  Result := True;
end;

// Text of a WinHTTP error code (GetLastError after a WinHTTP function) for the log, e.g.
// 'WinHTTP error 12038 (the certificate is for another host name)'
function DescribeWinHttpError(const Code: Integer): String;
var
  Text: String;
begin
  case Code of
    12002: Text := 'timeout';
    12005: Text := 'invalid URL';
    12007: Text := 'the server name cannot be resolved';
    12017: Text := 'the operation was cancelled';
    12029: Text := 'cannot connect to the server';
    12030: Text := 'the connection was closed or reset';
    12037: Text := 'the certificate has expired or is not yet valid';
    12038: Text := 'the certificate is for another host name';
    12044: Text := 'the server asks for a client certificate';
    12045: Text := 'the certificate authority is not trusted';
    12152: Text := 'invalid answer of the server';
    12156: Text := 'redirect refused: to http, or too many';
    12157: Text := 'secure channel error (TLS handshake or certificate)';
    12169: Text := 'invalid certificate';
    12175: Text := 'secure connection failure (TLS or certificate)';
    12179: Text := 'the certificate is not valid for server authentication';
    10060: Text := 'timeout of the connection (Windows Sockets)';
  else
    Text := '';
  end;
  Result := 'WinHTTP error ' + IntToStr(Code);
  if Text <> '' then
    Result := Result + ' (' + Text + ')';
end;

const
  // WinHttpOpen: the proxy settings WinHTTP finds itself (WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
  // Windows 8.1 and later), else the WinHTTP proxy configuration (WINHTTP_ACCESS_TYPE_DEFAULT_PROXY)
  WinHttpAccessTypeDefaultProxy = 0;
  WinHttpAccessTypeAutomaticProxy = 4;
  // WinHttpOpenRequest: TLS (WINHTTP_FLAG_SECURE)
  WinHttpFlagSecure = $00800000;
  // WinHttpSetOption on the session: the TLS protocols (WINHTTP_OPTION_SECURE_PROTOCOLS), asked for
  // explicitly on Windows older than 8.1 like HttpRequest does (WinHttpSecureProtocolsTls10To12)
  WinHttpOptionSecureProtocols = 84;
  // WinHttpQueryHeaders: status code and Content-Length as numbers
  WinHttpQueryStatusCode = 19;
  WinHttpQueryContentLength = 5;
  WinHttpQueryFlagNumber = $20000000;
  // Timeouts of these requests (name resolution: DownloadResolveTimeoutMs); the receive timeout
  // applies to every single read, as the 30 s of the download plug-in of setups up to 1.7.2
  WinHttpConnectTimeoutMs = 15000;
  WinHttpSendTimeoutMs = 15000;
  WinHttpReceiveTimeoutMs = 30000;
  // Bytes read at once by DownloadPinnedFileWinHttp (downloads.iss)
  WinHttpReadChunkBytes = 65536;
  WinHttpUserAgent = 'Empire Earth Community Setup';

// WinHTTP (winhttp.dll) for the two requests without certificate validation: the probe of a file
// server (GetHttpStatusIgnoringCertificate) and the download of a pinned file
// (DownloadPinnedFileWinHttp, downloads.iss). The handles are Cardinal because setups of Inno Setup
// 6.2.2 are always 32-bit processes (a 64-bit setup would need pointer-sized handles here). Delay
// loaded: a function that cannot be called raises an exception in the request that calls it, which
// fails that request, instead of stopping the setup at its start.
function WinHttpOpen(Agent: String; AccessType: Cardinal; ProxyName, ProxyBypass: Cardinal; Flags: Cardinal): Cardinal;
  external 'WinHttpOpen@winhttp.dll stdcall delayload';
function WinHttpSetTimeouts(Handle: Cardinal; ResolveTimeout, ConnectTimeout, SendTimeout, ReceiveTimeout: Integer): BOOL;
  external 'WinHttpSetTimeouts@winhttp.dll stdcall delayload';
function WinHttpConnect(Session: Cardinal; ServerName: String; ServerPort: Cardinal; Reserved: Cardinal): Cardinal;
  external 'WinHttpConnect@winhttp.dll stdcall delayload';
function WinHttpOpenRequest(Connection: Cardinal; Verb, ObjectName: String; Version, Referrer, AcceptTypes: Cardinal; Flags: Cardinal): Cardinal;
  external 'WinHttpOpenRequest@winhttp.dll stdcall delayload';
function WinHttpSetOption(Handle: Cardinal; Option: Cardinal; var Value: Cardinal; ValueLength: Cardinal): BOOL;
  external 'WinHttpSetOption@winhttp.dll stdcall delayload';
function WinHttpSendRequest(Request: Cardinal; Headers: String; HeadersLength: Cardinal; Optional: Cardinal; OptionalLength, TotalLength, Context: Cardinal): BOOL;
  external 'WinHttpSendRequest@winhttp.dll stdcall delayload';
function WinHttpReceiveResponse(Request: Cardinal; Reserved: Cardinal): BOOL;
  external 'WinHttpReceiveResponse@winhttp.dll stdcall delayload';
function WinHttpQueryHeaders(Request: Cardinal; InfoLevel: Cardinal; Name: Cardinal; var Value: Cardinal; var ValueLength: Cardinal; Index: Cardinal): BOOL;
  external 'WinHttpQueryHeaders@winhttp.dll stdcall delayload';
function WinHttpReadData(Request: Cardinal; Buffer: AnsiString; BytesToRead: Cardinal; var BytesRead: Cardinal): BOOL;
  external 'WinHttpReadData@winhttp.dll stdcall delayload';
function WinHttpCloseHandle(Handle: Cardinal): BOOL;
  external 'WinHttpCloseHandle@winhttp.dll stdcall delayload';
// Writes the bytes WinHttpReadData put into an AnsiString buffer to TFileStream.Handle unchanged
// (TStream.WriteBuffer takes a String and would convert them)
function WriteFile(FileHandle: Integer; Buffer: AnsiString; BytesToWrite: Cardinal; var BytesWritten: Cardinal; Overlapped: Cardinal): BOOL;
  external 'WriteFile@kernel32.dll stdcall';

// WinHttpOpen access type for the Windows version WindowsMajor.WindowsMinor: the automatic proxy
// detection from Windows 8.1 (6.3) on, where WinHTTP offers it, else the default proxy
// configuration
function GetWinHttpAccessType(const WindowsMajor, WindowsMinor: Cardinal): Cardinal;
begin
  if (WindowsMajor > 6) or ((WindowsMajor = 6) and (WindowsMinor >= 3)) then
    Result := WinHttpAccessTypeAutomaticProxy
  else
    Result := WinHttpAccessTypeDefaultProxy;
end;

// THE place that switches the certificate validation of a WinHTTP request off: sets
// WINHTTP_OPTION_SECURITY_FLAGS (31) of Request to ignore an unknown certification authority
// (SECURITY_FLAG_IGNORE_UNKNOWN_CA, $100), a wrong certificate usage ($200), a certificate for
// another host name (SECURITY_FLAG_IGNORE_CERT_CN_INVALID, $1000) and an expired one
// (SECURITY_FLAG_IGNORE_CERT_DATE_INVALID, $2000). Only OpenWinHttpRequest calls it, and only for
// the two callers that may ignore certificate errors (ci/check_tls_policy.py checks both). True if
// WinHTTP accepted the option.
function ApplyCertificateErrorIgnoreFlags(const Request: Cardinal): Boolean;
var
  Flags: Cardinal;
begin
  Flags := $3300;
  Result := WinHttpSetOption(Request, 31, Flags, 4);
end;

// Closes the handles of OpenWinHttpRequest (request, connection, session; 0 is skipped) and sets
// them to 0
procedure CloseWinHttpRequest(var Session, Connection, Request: Cardinal);
begin
  if Request <> 0 then
    WinHttpCloseHandle(Request);
  if Connection <> 0 then
    WinHttpCloseHandle(Connection);
  if Session <> 0 then
    WinHttpCloseHandle(Session);
  Request := 0;
  Connection := 0;
  Session := 0;
end;

// Opens a WinHTTP request (Method GET or HEAD) to the https URL Url without sending it: session
// (proxy as GetWinHttpAccessType, TLS 1.0 to 1.2 asked for explicitly on Windows older than 8.1,
// the timeouts above), connection and request over TLS (SplitDownloadUrl). With
// IgnoreCertificateErrors the certificate errors of ApplyCertificateErrorIgnoreFlags are ignored;
// only GetHttpStatusIgnoringCertificate and DownloadPinnedFileWinHttp pass True. WinHTTP follows
// redirects itself, but never from https to http (its default redirect policy); the options of the
// request apply to the redirect too. False with the cause in Error and no open handle if anything
// fails; else the caller closes the handles with CloseWinHttpRequest. No exception escapes.
function OpenWinHttpRequest(const Method, Url: String; const IgnoreCertificateErrors: Boolean;
  var Session, Connection, Request: Cardinal; var Error: String): Boolean;
var
  Host, ObjectName: String;
  Port: Integer;
  Version: TWindowsVersion;
  Protocols: Cardinal;
begin
  Result := False;
  Session := 0;
  Connection := 0;
  Request := 0;
  Error := '';
  if not SplitDownloadUrl(Url, Host, Port, ObjectName) then
  begin
    Error := 'not an https URL that WinHTTP is given';
    Exit;
  end;
  try
    GetWindowsVersionEx(Version);
    Session := WinHttpOpen(WinHttpUserAgent, GetWinHttpAccessType(Version.Major, Version.Minor), 0, 0, 0);
    if Session = 0 then
      Error := 'WinHttpOpen: ' + DescribeWinHttpError(DLLGetLastError)
    else
    begin
      if NeedsExplicitTlsProtocols(Version.Major, Version.Minor) then
      begin
        Protocols := WinHttpSecureProtocolsTls10To12;
        if not WinHttpSetOption(Session, WinHttpOptionSecureProtocols, Protocols, 4) then
          Log('WinHTTP: unable to request TLS 1.0, 1.1 and 1.2 explicitly (Windows ' + IntToStr(Version.Major) + '.' +
            IntToStr(Version.Minor) + '), the request uses the protocols of the system: ' + DescribeWinHttpError(DLLGetLastError));
      end;
      if not WinHttpSetTimeouts(Session, DownloadResolveTimeoutMs, WinHttpConnectTimeoutMs, WinHttpSendTimeoutMs, WinHttpReceiveTimeoutMs) then
        Log('WinHTTP: unable to set the timeouts: ' + DescribeWinHttpError(DLLGetLastError));
      Connection := WinHttpConnect(Session, Host, Port, 0);
      if Connection = 0 then
        Error := 'WinHttpConnect: ' + DescribeWinHttpError(DLLGetLastError)
      else
      begin
        Request := WinHttpOpenRequest(Connection, Method, ObjectName, 0, 0, 0, WinHttpFlagSecure);
        if Request = 0 then
          Error := 'WinHttpOpenRequest: ' + DescribeWinHttpError(DLLGetLastError)
        else if IgnoreCertificateErrors and not ApplyCertificateErrorIgnoreFlags(Request) then
          Error := 'unable to ignore certificate errors: ' + DescribeWinHttpError(DLLGetLastError)
        else
          Result := True;
      end;
    end;
  except
    Error := GetExceptionMessage;
  end;
  if not Result then
    CloseWinHttpRequest(Session, Connection, Request);
end;

// Sends the request of OpenWinHttpRequest and waits for the headers of the answer: its HTTP status,
// or HttpRequestFailed with the cause in Error. The body is not read. No exception escapes.
function SendWinHttpRequest(const Request: Cardinal; var Error: String): Integer;
var
  Status, Size: Cardinal;
begin
  Result := HttpRequestFailed;
  Error := '';
  try
    if not WinHttpSendRequest(Request, '', 0, 0, 0, 0, 0) then
      Error := DescribeWinHttpError(DLLGetLastError)
    else if not WinHttpReceiveResponse(Request, 0) then
      Error := DescribeWinHttpError(DLLGetLastError)
    else
    begin
      Status := 0;
      Size := 4;
      if WinHttpQueryHeaders(Request, WinHttpQueryStatusCode or WinHttpQueryFlagNumber, 0, Status, Size, 0) then
        Result := Status
      else
        Error := 'no status code: ' + DescribeWinHttpError(DLLGetLastError);
    end;
  except
    Error := GetExceptionMessage;
  end;
end;

// The probe of a file server without certificate validation (SelectOnlineFilesServer, only after
// the probe with validation got no answer, and only if the setup has pins): the HTTP status of a GET
// request to Url with the certificate errors of ApplyCertificateErrorIgnoreFlags ignored, or
// HttpRequestFailed. The answer is never read: a status only tells that the server answers, so that
// pinned files may be downloaded from it with DownloadPinnedFileWinHttp. Synchronous like
// GetHttpStatus.
function GetHttpStatusIgnoringCertificate(const Url: String): Integer;
var
  Session, Connection, Request: Cardinal;
  Error: String;
begin
  Result := HttpRequestFailed;
  Log('HTTP GET ' + Url + ' without certificate validation (WinHTTP)');
  if not OpenWinHttpRequest('GET', Url, True, Session, Connection, Request, Error) then
  begin
    Log('HTTP GET ' + Url + ' without certificate validation failed: ' + Error);
    Exit;
  end;
  Result := SendWinHttpRequest(Request, Error);
  CloseWinHttpRequest(Session, Connection, Request);
  if Result = HttpRequestFailed then
    Log('HTTP GET ' + Url + ' without certificate validation failed: ' + Error)
  else
    Log('HTTP GET ' + Url + ' without certificate validation: status ' + IntToStr(Result) + ', answer not read');
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

// True if every character of Text is ASCII (code 0 to 127). install.ini and the manifest
// files.sha256 are written with SaveStringToFile, which converts the text to the ANSI code page: only
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
// (StateWritten: install.ini and files.sha256). Inno Setup recreates the uninstall key
// on every run, so without the value the launcher reports the state Unknown instead of trusting
// files of an earlier run, also of a setup up to 1.7.2 that ran later.
function ShouldWriteContractVersionValue(const HasUninstallKey, StateDeleted, StateWritten: Boolean): Boolean;
begin
  Result := HasUninstallKey and StateDeleted and StateWritten;
end;

const
  // The state files in the setup data folder (contract 1.2, 2.1)
  InstallIniFileName = 'install.ini';
  ManifestFileName = 'files.sha256';
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
  // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
  Result := 'Manifest: ' + IntToStr(FileCount) + ' files, ' + TenthsToStr((Bytes * 10 + 524288) div 1048576) + ' MB, ' +
    IntToStr(ElapsedMs) + ' ms, ' + TenthsToStr((Bytes * 10000 + Ms * 524288) div (Ms * 1048576)) + ' MB/s';
end;

// Milliseconds since system start (wraps after 49.7 days, see TicksSince)
function GetTickCount: DWORD;
  external 'GetTickCount@kernel32.dll stdcall';

// Milliseconds since Started (a GetTickCount value), also across a wrap of GetTickCount
function TicksSince(const Started: DWORD): Int64;
var
  Wrap: Int64;
begin
  Result := Int64(GetTickCount) - Int64(Started);
  if Result < 0 then
  begin
    Wrap := 65536;
    Result := Result + Wrap * 65536;
  end;
end;

const
  // Attempts to hash one file (HashFileWithRetries) and the pause before each further attempt: a
  // virus scanner may hold a file it has just checked for a moment (ADR 0004 point 4)
  ManifestHashAttempts = 3;
  ManifestHashRetryDelayMs = 300;

// SHA-256 of the file FileName in lowercase hex. GetSHA256OfFile raises an exception on every read
// error (no access, a program holds the file open without sharing it for reading), so it is called
// in try/except up to ManifestHashAttempts times, ManifestHashRetryDelayMs apart; every failed
// attempt is logged with the exception. True and Hash if an attempt worked, else False with the
// exception of the last attempt in Error. No exception escapes.
function HashFileWithRetries(const FileName: String; var Hash, Error: String): Boolean;
var
  Attempt: Integer;
begin
  Result := False;
  Hash := '';
  Error := '';
  Attempt := 0;
  while (not Result) and (Attempt < ManifestHashAttempts) do
  begin
    Attempt := Attempt + 1;
    if Attempt > 1 then
      Sleep(ManifestHashRetryDelayMs);
    try
      Hash := LowerCase(GetSHA256OfFile(FileName));
      Result := True;
    except
      Error := GetExceptionMessage;
      Log('Unable to hash ' + FileName + ' (attempt ' + IntToStr(Attempt) + ' of ' + IntToStr(ManifestHashAttempts) + '): ' + Error);
    end;
  end;
end;

// Adds to Files the destination of every file that an external [Files] entry with the source
// "<SourceDir>\*", DestDir DestDir and recursesubdirs installs, as Inno Setup's
// RecurseExternalCopyFiles picks them (Install.pas): every file that is not hidden, in SourceDir and
// in its subfolders that are not hidden, as DestDir + its path below SourceDir. Nothing if SourceDir
// does not exist. Used for the verified online files in {tmp}\verified (ADR 0004 point 3).
procedure CollectExternalFiles(const SourceDir, DestDir: String; const Files: TStringList);
var
  FindRec: TFindRec;
begin
  if FindFirst(SourceDir + '\*', FindRec) then
  try
    repeat
      if (FindRec.Attributes and FILE_ATTRIBUTE_HIDDEN) = 0 then
      begin
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
          Files.Add(DestDir + '\' + FindRec.Name)
        else if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
          CollectExternalFiles(SourceDir + '\' + FindRec.Name, DestDir + '\' + FindRec.Name, Files);
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

// The manifest paths of the recorded destinations Recorded (full paths in any order, duplicates
// allowed): GetManifestPath below InstallRoot, without the paths IsManifestExcludedPath leaves out
// (setup data folder SetupDataDir, uninstaller), sorted by MergeSortManifestPaths and without
// duplicates (RemoveDuplicateManifestPaths). A path GetManifestPath refuses (outside the root, ':',
// '..') is logged and left out.
function GetManifestPaths(const InstallRoot, SetupDataDir: String; const Recorded: TStringList): TArrayOfString;
var
  I, Count: Integer;
  RelPath: String;
begin
  SetArrayLength(Result, Recorded.Count);
  Count := 0;
  for I := 0 to Recorded.Count - 1 do
  begin
    if not GetManifestPath(InstallRoot, Recorded[I], RelPath) then
      Log('Not in the manifest: ' + Recorded[I] + ' (not a valid path below ' + InstallRoot + ')')
    else if not IsManifestExcludedPath(RelPath, SetupDataDir) then
    begin
      Result[Count] := RelPath;
      Count := Count + 1;
    end;
  end;
  SetArrayLength(Result, Count);
  MergeSortManifestPaths(Result);
  RemoveDuplicateManifestPaths(Result);
end;

// Hashes the files of Paths (manifest paths below InstallRoot, sorted and unique) for files.sha256
// (contract 2.2): Text gets a ManifestLine for every file that exists, Missing the paths of the
// files that do not exist (any more, e.g. deleted by a virus scanner; each one logged), FileCount
// and Bytes the number and size of the hashed files. Returns False if the manifest must not be
// written: HashFiles is False (the caller already knows that), a path is not ASCII (contract 2.2,
// logged), or a file could not be hashed after its retries (HashFileWithRetries; the file and the
// exception are logged). From then on the files are only checked for existence. ProgressPage, if
// not nil, shows Status, the file and the progress per file (its SetProgress processes window
// messages, so Windows does not mark the wizard as not responding while several hundred MB are read).
function HashManifestFiles(const InstallRoot: String; const Paths: TArrayOfString; const HashFiles: Boolean;
  const ProgressPage: TOutputProgressWizardPage; const Status: String;
  var Text: String; var Missing: TArrayOfString; var FileCount: Integer; var Bytes: Int64): Boolean;
var
  I, MissingCount: Integer;
  FullPath, Hash, Error: String;
  Size: Int64;
begin
  Result := HashFiles;
  Text := '';
  FileCount := 0;
  Bytes := 0;
  MissingCount := 0;
  SetArrayLength(Missing, GetArrayLength(Paths));
  for I := 0 to GetArrayLength(Paths) - 1 do
  begin
    FullPath := AddBackslash(InstallRoot) + Paths[I];
    StringChangeEx(FullPath, '/', '\', True);
    if ProgressPage <> nil then
    begin
      ProgressPage.SetText(Status, FullPath);
      ProgressPage.SetProgress(I, GetArrayLength(Paths));
    end;
    if Result and not IsAsciiText(Paths[I]) then
    begin
      Result := False;
      Log('No manifest in this run: the path is not ASCII (contract 2.2): ' + FullPath);
    end;
    if not FileExists(FullPath) then
    begin
      Missing[MissingCount] := Paths[I];
      MissingCount := MissingCount + 1;
      Log('Installed file missing after the installation (deleted or moved, e.g. by an antivirus program): ' + FullPath);
    end
    else if Result then
    begin
      if HashFileWithRetries(FullPath, Hash, Error) then
      begin
        Text := Text + ManifestLine(Hash, Paths[I]);
        FileCount := FileCount + 1;
        if FileSize64(FullPath, Size) then
          Bytes := Bytes + Size;
      end
      else
      begin
        Result := False;
        Log('No manifest in this run: unable to hash ' + FullPath + ' after ' + IntToStr(ManifestHashAttempts) + ' attempts: ' + Error);
      end;
    end;
  end;
  SetArrayLength(Missing, MissingCount);
  if (ProgressPage <> nil) and (GetArrayLength(Paths) > 0) then
    ProgressPage.SetProgress(GetArrayLength(Paths), GetArrayLength(Paths));
end;

// Writes the state files of this run into the setup data folder InstallRoot\SetupDataDir
// (contract 1.2, 2.1, 2.2; ADR 0004 point 4): hashes the files of Recorded (full paths of the
// processed destinations, GetManifestPaths, HashManifestFiles) and logs FormatManifestSummary; then
// files.sha256, if the manifest is complete, and install.ini with the text IniText (BuildInstallIniText)
// and [MissingAfterInstall] for the files that are gone, both with ReplaceStateFile (ASCII check,
// temporary file, the target deleted and gone before the rename). RecordingComplete False (a
// destination could not be recorded) gives no manifest; the files are still checked for existence.
// Returns True if install.ini was written; ManifestWritten tells the same of files.sha256, Missing
// gives the manifest paths of the files that are gone (also those that are not ASCII, for the
// notice). If the manifest is not complete, no files.sha256 is written at all: the one of the
// previous run was deleted at ssInstall (DeleteStateFile; if that failed, the uninstall key gets no
// contract version). Every outcome is logged; nothing is shown.
function WriteInstallStateFiles(const InstallRoot, SetupDataDir: String; const Recorded: TStringList;
  const RecordingComplete: Boolean; const IniText: String; const ProgressPage: TOutputProgressWizardPage;
  const Status: String; var ManifestWritten: Boolean; var Missing: TArrayOfString): Boolean;
var
  StateDir, Text: String;
  Paths: TArrayOfString;
  Complete: Boolean;
  FileCount: Integer;
  Bytes: Int64;
  Started: DWORD;
begin
  ManifestWritten := False;
  StateDir := AddBackslash(InstallRoot) + SetupDataDir + '\';
  Paths := GetManifestPaths(InstallRoot, SetupDataDir, Recorded);
  Started := GetTickCount;
  if not RecordingComplete then
    Log('No manifest in this run: not every installed file could be recorded');
  Complete := HashManifestFiles(InstallRoot, Paths, RecordingComplete, ProgressPage, Status, Text, Missing, FileCount, Bytes);
  Log(FormatManifestSummary(FileCount, Bytes, TicksSince(Started)));
  if not Complete then
    Log('Not writing ' + StateDir + ManifestFileName + ': the manifest of this run is not complete (see above)')
  else if ReplaceStateFile(StateDir + ManifestFileName, Text) then
  begin
    ManifestWritten := True;
    Log('Wrote ' + StateDir + ManifestFileName + ' (' + IntToStr(FileCount) + ' files, ' + IntToStr(GetArrayLength(Missing)) + ' missing)');
  end;
  Result := ReplaceStateFile(StateDir + InstallIniFileName, IniText + BuildMissingAfterInstallText(Missing));
end;

// Environment checks before the installation (environment.iss) and the default game window:
// docs/adr/0007-environment-warnings.md, docs/CONTRACT.md 3.3

const
  // The default game window ([Registry] Game Window Width and Game Window Height,
  // GetScreenResolutionWidth/Height in setup_is6.iss) is the size of the primary screen within
  // these limits, each dimension on its own (contract 3.3, whose tables ci/check_contract.py checks
  // against these constants)
  MinGameWindowWidth = 1024;
  MaxGameWindowWidth = 1920;
  MinGameWindowHeight = 768;
  MaxGameWindowHeight = 1200;
  // A screen wider than MaxGameWindowWidth keeps its shape: its game window is at most the larger of this height and
  // the screen height scaled to MaxGameWindowWidth (contract 3.3, revision 6), so 16:9 screens of any size keep 1920 x 1080
  WideScreenGameWindowHeight = 1080;
  // Pixels per inch (LOGPIXELSX) at a display scaling of 100 %
  DefaultScreenDpi = 96;

// Value, but at least Lowest and at most Highest
function ClampToRange(const Value, Lowest, Highest: Integer): Integer;
begin
  Result := Value;
  if Result < Lowest then
    Result := Lowest;
  if Result > Highest then
    Result := Highest;
end;

// Game Window Width (contract 3.3) for a primary screen ScreenWidth pixels wide
// (GetSystemMetrics(SM_CXSCREEN)): the width, at least MinGameWindowWidth and at most
// MaxGameWindowWidth. 0 (GetSystemMetrics failed) gives the minimum.
function ClampGameWindowWidth(const ScreenWidth: Integer): Integer;
begin
  Result := ClampToRange(ScreenWidth, MinGameWindowWidth, MaxGameWindowWidth);
end;

// Game Window Height (contract 3.3) for a primary screen of ScreenWidth x ScreenHeight pixels
// (GetSystemMetrics(SM_CXSCREEN/SM_CYSCREEN)): the height, at least MinGameWindowHeight and at most
// MaxGameWindowHeight; on a screen wider than MaxGameWindowWidth also at most the larger of
// WideScreenGameWindowHeight and the height scaled to MaxGameWindowWidth (2560 x 1600 gives 1200,
// 2560 x 1440 gives 1080). 0 (GetSystemMetrics failed) gives the minimum.
function GameWindowHeight(const ScreenWidth, ScreenHeight: Integer): Integer;
var
  Scaled: Integer;
begin
  Result := ClampToRange(ScreenHeight, MinGameWindowHeight, MaxGameWindowHeight);
  if ScreenWidth > MaxGameWindowWidth then
  begin
    Scaled := ScreenHeight * MaxGameWindowWidth div ScreenWidth;
    if Scaled < WideScreenGameWindowHeight then
      Scaled := WideScreenGameWindowHeight;
    if Result > Scaled then
      Result := Scaled;
  end;
end;

// True if the primary screen is lower than the menus of the game need (MinGameWindowHeight, the
// height of the window the setup sets then): the setup warns (R13; t=3863 p=26167: a netbook with
// 1024 x 600 crashes after the intro). A height of 0 or less is unknown (GetSystemMetrics returns 0
// if it fails) and gives no warning.
function IsScreenTooLow(const ScreenHeight: Integer): Boolean;
begin
  Result := (ScreenHeight > 0) and (ScreenHeight < MinGameWindowHeight);
end;

// The log line of the screen (ADR 0007 point 1, contract O4): size of the primary screen, its DPI
// and the display scaling it means (Dpi 0 or less: unknown), and the game window the setup writes:
// 'Screen: <w> x <h> pixels (primary screen, SM_CXSCREEN x SM_CYSCREEN), <dpi> DPI (LOGPIXELSX,
// <p> % scaling), game window <w> x <h>'
function FormatScreenMetrics(const ScreenWidth, ScreenHeight, Dpi: Integer): String;
begin
  Result := 'Screen: ' + IntToStr(ScreenWidth) + ' x ' + IntToStr(ScreenHeight) + ' pixels (primary screen, SM_CXSCREEN x SM_CYSCREEN), ';
  if Dpi > 0 then
    Result := Result + IntToStr(Dpi) + ' DPI (LOGPIXELSX, ' + IntToStr((Dpi * 100 + DefaultScreenDpi div 2) div DefaultScreenDpi) + ' % scaling)'
  else
    Result := Result + 'DPI unknown';
  Result := Result + ', game window ' + IntToStr(ClampGameWindowWidth(ScreenWidth)) + ' x ' + IntToStr(GameWindowHeight(ScreenWidth, ScreenHeight));
end;

// A folder path as the environment checks compare it: spaces around it removed, '/' as '\', no
// doubled '\' (except the two at the start of a UNC path) and no '\' at the end ('C:\' gives 'C:').
// Letters are not changed; '' stays ''.
function NormalizeFolderPath(const Path: String): String;
var
  Prefix: String;
begin
  Result := Trim(Path);
  StringChangeEx(Result, '/', '\', True);
  Prefix := '';
  if Copy(Result, 1, 2) = '\\' then
  begin
    Prefix := '\\';
    Result := Copy(Result, 3, Length(Result));
  end;
  while Pos('\\', Result) > 0 do
    StringChangeEx(Result, '\\', '\', True);
  // Copy, not Result[...]: the check must also work on ''
  while Copy(Result, Length(Result), 1) = '\' do
    Result := Copy(Result, 1, Length(Result) - 1);
  if Result <> '' then
    Result := Prefix + Result;
end;

// True if Candidate is the folder Root or a folder below it (ADR 0007 point 4). Both are normalized
// (NormalizeFolderPath) and compared ignoring case (AnsiUppercase: also letters such as U with
// umlaut, as Windows compares names); a folder that only starts with the same letters is not below
// it (C:\Sierra2 is not inside C:\Sierra). False if one of them is empty.
function IsSameOrInside(const Root, Candidate: String): Boolean;
var
  RootKey, CandidateKey: String;
begin
  Result := False;
  RootKey := AnsiUppercase(NormalizeFolderPath(Root));
  CandidateKey := AnsiUppercase(NormalizeFolderPath(Candidate));
  if (RootKey = '') or (CandidateKey = '') then
    Exit;
  if CandidateKey = RootKey then
    Result := True
  else if Length(CandidateKey) > Length(RootKey) then
    Result := (Copy(CandidateKey, 1, Length(RootKey)) = RootKey) and (CandidateKey[Length(RootKey) + 1] = '\');
end;

// True if A and B name the same folder (IsSameOrInside in both directions: normalized, ignoring case)
function IsSameFolder(const A, B: String): Boolean;
begin
  Result := IsSameOrInside(A, B) and IsSameOrInside(B, A);
end;

// True if Path is no folder the checks of another installation's folder can use: empty, '\' or the
// root of a drive ('C:', 'C:\'). Such a value from the registry would contain every folder of the
// drive.
function IsDriveRootOrEmpty(const Path: String): Boolean;
var
  Folder: String;
begin
  Folder := NormalizeFolderPath(Path);
  Result := (Folder = '') or ((Length(Folder) = 2) and (Copy(Folder, 2, 1) = ':'));
end;

// The folder that the "Installed From" values of a game settings key name (contract 3.3): the drive
// Volume ('C:') followed by Directory ('\SIERRA\EMPIRE EARTH\'), normalized (NormalizeFolderPath);
// '' if Volume is not a drive letter with ':' or Directory is empty
function InstalledFromFolder(const Volume, Directory: String): String;
var
  Drive, Folder: String;
begin
  Result := '';
  Drive := Trim(Volume);
  Folder := Trim(Directory);
  if (Length(Drive) <> 2) or (Copy(Drive, 2, 1) <> ':') or (Pos(Uppercase(Copy(Drive, 1, 1)), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') = 0) or (Folder = '') then
    Exit;
  if (Copy(Folder, 1, 1) <> '\') and (Copy(Folder, 1, 1) <> '/') then
    Folder := '\' + Folder;
  Result := NormalizeFolderPath(Drive + Folder);
end;

// How regedit shows the key SubKey ('Software\...') of HKLM: in the 32-bit view (View32) of 64-bit
// Windows (Win64) below Software\WOW6432Node, otherwise as it is (32-bit Windows has one view)
function FormatHklmKeyName(const SubKey: String; const View32, Win64: Boolean): String;
begin
  if View32 and Win64 and (CompareText(Copy(SubKey, 1, 9), 'Software\') = 0) then
    Result := 'HKLM\Software\WOW6432Node\' + Copy(SubKey, 10, Length(SubKey))
  else
    Result := 'HKLM\' + SubKey;
end;

const
  // Publisher of the two community setups in their uninstall keys (contract 0, Products; the same as
  // MyAppPublisher of config_ee.iss and config_neoee.iss, ci/check_contract.py checks all of them)
  CommunityPublisherEE = 'Empire Earth Community';
  CommunityPublisherNeoEE = 'Empire Earth Community & NeoEE';
  // The uninstall entries (one subkey each) that environment.iss reads in both views of HKLM
  UninstallKeysPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall';
  // The notice ForeignInstallFound names at most this many findings (FormatFindingList)
  FindingsShownMax = 12;

// True if the uppercase DisplayName Name names Empire Earth (1) or NeoEE: it contains 'NEOEE', or
// 'EMPIRE EARTH' not followed by ' II' (Empire Earth II and III are other games, with their own
// folders and keys)
function NamesEmpireEarthOrNeoEE(const Name: String): Boolean;
var
  Rest: String;
  P: Integer;
begin
  Result := Pos('NEOEE', Name) > 0;
  Rest := Name;
  P := Pos('EMPIRE EARTH', Rest);
  while (not Result) and (P > 0) do
  begin
    Rest := Copy(Rest, P + Length('EMPIRE EARTH'), Length(Rest));
    if Copy(Rest, 1, 3) <> ' II' then
      Result := True
    else
      P := Pos('EMPIRE EARTH', Rest);
  end;
end;

// True if the uninstall entry with the key name KeyName (below UninstallKeysPath), DisplayName and
// Publisher belongs to a foreign or old installation of Empire Earth or NeoEE that the setup
// reports (ADR 0007 point 2: retail CD, GOG, old NeoEE installers; report 4.7 and 4.8): the
// DisplayName names Empire Earth or NeoEE (NamesEmpireEarthOrNeoEE, ignoring case), the key is not
// '{<AppId>}_is1' of one of the two community products (AppID, OtherAppID; ignoring case) and the
// Publisher is not one of the two community publishers (ignoring case and spaces around it), so
// community installations with other AppIds (test builds, official builds) are not reported either
function IsForeignUninstallEntry(const KeyName, DisplayName, Publisher: String): Boolean;
begin
  Result := NamesEmpireEarthOrNeoEE(Uppercase(DisplayName)) and
    (CompareText(KeyName, '{{#AppID}}_is1') <> 0) and (CompareText(KeyName, '{{#OtherAppID}}_is1') <> 0) and
    (CompareText(Trim(Publisher), CommunityPublisherEE) <> 0) and (CompareText(Trim(Publisher), CommunityPublisherNeoEE) <> 0);
end;

// The list of the notice ForeignInstallFound (%1): a line break and two spaces before each of
// Findings, at most MaxShown of them, then '  ... (+<n>)' for the n others (no words, so it needs
// no translation)
function FormatFindingList(const Findings: TStringList; const MaxShown: Integer): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Findings.Count - 1 do
    if I < MaxShown then
      Result := Result + #13#10 + '  ' + Findings[I];
  if Findings.Count > MaxShown then
    Result := Result + #13#10 + '  ... (+' + IntToStr(Findings.Count - MaxShown) + ')';
end;

// Links in the folders all users can write to: docs/adr/0009-no-installation-through-links.md. The
// link check before an elevated installation (environment.iss) and the random map scripts
// (randommaps.iss) use these.

const
  // The message LinkInGameFolder names at most this many folders (FormatFindingList): it is shown on
  // the "Preparing to install" page, which has no scroll bar and less room than a message box
  LinkFindingsShownMax = 3;

// True if Path is a junction, symbolic link or other reparse point
function IsReparsePoint(const Path: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(Path, FindRec) then
  try
    Result := (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0;
  finally
    FindClose(FindRec);
  end;
end;

// For GetFileLinkCount: BY_HANDLE_FILE_INFORMATION of kernel32 (every FILETIME as its two DWORDs)
type
  TByHandleFileInformation = record
    dwFileAttributes: DWORD;
    ftCreationTimeLow, ftCreationTimeHigh: DWORD;
    ftLastAccessTimeLow, ftLastAccessTimeHigh: DWORD;
    ftLastWriteTimeLow, ftLastWriteTimeHigh: DWORD;
    dwVolumeSerialNumber: DWORD;
    nFileSizeHigh, nFileSizeLow: DWORD;
    nNumberOfLinks: DWORD;
    nFileIndexHigh, nFileIndexLow: DWORD;
  end;

const
  FILE_READ_ATTRIBUTES = $80;
  FILE_SHARE_READ = 1;
  FILE_SHARE_WRITE = 2;
  FILE_SHARE_DELETE = 4;
  OPEN_EXISTING = 3;
  FILE_FLAG_OPEN_REPARSE_POINT = $200000;
  INVALID_HANDLE_VALUE = $FFFFFFFF;

function CreateFile(lpFileName: String; dwDesiredAccess, dwShareMode, lpSecurityAttributes,
  dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile: Cardinal): Cardinal;
  external 'CreateFileW@kernel32.dll stdcall';
function CloseHandle(hObject: Cardinal): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';
function GetFileInformationByHandle(hFile: Cardinal; var lpFileInformation: TByHandleFileInformation): BOOL;
  external 'GetFileInformationByHandle@kernel32.dll stdcall';

// Number of names of the file Path (more than 1: it is a hard link, another name of the same data
// somewhere on the same volume), or -1 if the file cannot be opened or its information cannot be
// read. The file is opened only to read its attributes, which no sharing mode of another program
// prevents, and a symbolic link is opened itself, not followed (FILE_FLAG_OPEN_REPARSE_POINT).
function GetFileLinkCount(const Path: String): Integer;
var
  Handle: Cardinal;
  Info: TByHandleFileInformation;
begin
  Result := -1;
  Handle := CreateFile(Path, FILE_READ_ATTRIBUTES, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, 0,
    OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, 0);
  if Handle = INVALID_HANDLE_VALUE then
    Exit;
  try
    if GetFileInformationByHandle(Handle, Info) then
      Result := Info.nNumberOfLinks;
  finally
    CloseHandle(Handle);
  end;
end;

// True if the folder RelPath below a game folder is one the link check examines: Data, Users and
// every folder below them (ADR 0009, revised). In administrative install mode [Dirs] gives every
// user modify rights on Data and Users, and the elevated setup writes below them: [Files] (Data,
// Users\default), [InstallDelete] (Data), the random map scripts (Data), and the external [Files]
// entries that set the permissions of *.cfg, *.config, *.conf and *.ini, which copy every such file
// in every folder that is not hidden onto itself, links and the folders of the players below Users
// included (Inno Setup 6.2.2: RecurseExternalCopyFiles, IsRecurseableDirectory). RelPath is relative
// to the game folder: '\' or '/' as separators, any case, doubled and trailing separators allowed.
// The game folder itself (''), its other folders and a path that is absolute or has a '.' or '..'
// part are not examined.
function IsLinkGuardedFolder(const RelPath: String): Boolean;
var
  Path: String;
  Parts: TArrayOfString;
  I: Integer;
begin
  Result := False;
  Path := NormalizeFolderPath(RelPath);
  if (Path = '') or (Copy(Path, 1, 1) = '\') or (Pos(':', Path) > 0) then
    Exit;
  Parts := StrSplit(Path, '\');
  for I := 0 to GetArrayLength(Parts) - 1 do
    if (Parts[I] = '.') or (Parts[I] = '..') then
      Exit;
  Result := (CompareText(Parts[0], 'Data') = 0) or (CompareText(Parts[0], 'Users') = 0);
end;

// File level, for the link check (environment.iss): examines the folders below the game folder
// GameDir that IsLinkGuardedFolder names, starting in RelDir ('' for the game folder itself, which
// is not examined, else '<folder>\'). A folder with a reparse point (FILE_ATTRIBUTE_REPARSE_POINT of
// FindFirst: a junction, a symbolic link to a folder, a mount point) is a finding and is not
// entered, so the walk never leaves the game folder and cannot loop. A folder that exists but cannot
// be listed is a finding as well: what is in it cannot be checked. A file with more than one name
// (a hard link, GetFileLinkCount) is a finding, and so is a file whose number of names cannot be
// read: the external [Files] entries that set the permissions of *.cfg, *.config, *.conf and *.ini
// read such a file and write what they read into a new file every user can read and change, and a
// standard user can make a hard link to a file he cannot read himself (Windows 7 and 8.1: without
// any privilege). Every finding is added to Findings as a full path and logged with its reason.
// Folders counts the folders examined, Files the files in them, ReparseFiles those with a reparse
// point (a file compressed by Windows or a symbolic link to a file: no finding, ADR 0009). Hidden
// folders and files are examined as well.
procedure FindLinksInGameFolder(const GameDir, RelDir: String; const Findings: TStringList; var Folders, Files, ReparseFiles: Integer);
var
  FindRec: TFindRec;
  Folder, RelPath: String;
  Links: Integer;
begin
  Folder := RemoveBackslashUnlessRoot(GameDir + '\' + RelDir);
  if not FindFirst(GameDir + '\' + RelDir + '*', FindRec) then
  begin
    if DirExists(Folder) then
    begin
      Log('Link check: ' + Folder + ' cannot be listed, so the folders in it cannot be checked');
      Findings.Add(Folder);
    end;
    Exit;
  end;
  try
    repeat
      if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
      begin
        RelPath := RelDir + FindRec.Name;
        if IsLinkGuardedFolder(RelPath) then
        begin
          if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
          begin
            Files := Files + 1;
            if (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
              ReparseFiles := ReparseFiles + 1;
            Links := GetFileLinkCount(GameDir + '\' + RelPath);
            if Links > 1 then
            begin
              Log('Link check: ' + GameDir + '\' + RelPath + ' is a hard link (the file has ' + IntToStr(Links) + ' names)');
              Findings.Add(GameDir + '\' + RelPath);
            end
            else if Links < 1 then
            begin
              Log('Link check: the number of names of ' + GameDir + '\' + RelPath + ' cannot be read, so it cannot be checked for a hard link');
              Findings.Add(GameDir + '\' + RelPath);
            end;
          end
          else
          begin
            Folders := Folders + 1;
            if (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
            begin
              Log('Link check: ' + GameDir + '\' + RelPath + ' is a junction or symbolic link (reparse point)');
              Findings.Add(GameDir + '\' + RelPath);
            end
            else
              FindLinksInGameFolder(GameDir, RelPath + '\', Findings, Folders, Files, ReparseFiles);
          end;
        end;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;
