[Code]
// Base helpers of the [Code] part: the URL constants, string split, language tag, compatibility
// flags, uninstall keys of EE and NeoEE, the HTTP requests, URL checks and the download policy of
// the online localized files. Included first, before every other [Code] part.
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
// it must come over validated TLS.
function HttpGet(const URL: String; const ResolveTimeoutMs: Integer; const ReadBody, HideQuery: Boolean; var Response: String): Integer;
var
  WinHttpRequest: Variant;
  LogURL: String;
begin
  Result := HttpRequestFailed;
  Response := '';
  LogURL := URL;
  if HideQuery and (Pos('?', LogURL) > 0) then
    LogURL := Copy(LogURL, 1, Pos('?', LogURL)) + '...';
  Log('HTTP GET ' + LogURL);

  try
    WinHttpRequest := CreateOleObject('WinHttp.WinHttpRequest.5.1');
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

// True if Url uses the https scheme (IDP validates the certificate then, see InvalidCert)
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
