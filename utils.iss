[Code]
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

// Uninstall key (below HKA) of this product
function GetUninstallRegPath(): String;
begin
#if InstallType == "EE"
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#EE_AppID}}_is1';
#elif InstallType == "NeoEE"
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#NeoEE_AppID}}_is1';
#else
  #error "Unknown Install Type"
#endif
end;

// Uninstall key (below HKA) of the other product: NeoEE in EE setups, EE in NeoEE setups
function GetOtherProductUninstallRegPath(): String;
begin
#if InstallType == "EE"
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#NeoEE_AppID}}_is1';
#elif InstallType == "NeoEE"
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#EE_AppID}}_is1';
#else
  #error "Unknown Install Type"
#endif
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