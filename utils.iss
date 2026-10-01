[Code]
// Yeah... Too much complex to be by default in IS Pascal I guess...
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
  Result := Dest
end;

function GetUninstallRegPath(Reverse: Boolean): String;
begin
  if not Reverse then
  begin
#if InstallType == "EE"
    Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#EE_AppID}}_is1';
#elif InstallType == "NeoEE" 
    Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#NeoEE_AppID}}_is1';
#else
  #error "Unknown Install Type"
#endif
  end else begin 
#if InstallType == "EE"
    Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#NeoEE_AppID}}_is1';
#elif InstallType == "NeoEE" 
    Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{#EE_AppID}}_is1';
#else
  #error "Unknown Install Type"
#endif
  end;
end;

function IsAnotherGameInstalled(): Boolean;
begin
  Result := False;
  if RegValueExists(HKA, GetUninstallRegPath(True), 'UninstallString')
  then begin
    Result := True;
  end;
end;

function IsGameInstalled(): Boolean;
begin
  Result := False;
  if RegValueExists(HKA, GetUninstallRegPath(False), 'UninstallString')
  then begin
    Result := True;
  end;
end;

// Return HTTP code or -1 if error
function SendRequest(const URL: String; const HttpFallback: Boolean; const Asynchronous: Boolean): Integer;
var
  WinHttpRequest: Variant;
  Https: Boolean;
begin
  Result := -1;
  Https := False;

  if (Pos('https://',  URL) <> 0) then
    Https := True;

  // if (Https and not IsWindowsXPOrNewer()) // Force HTTP usage for < XP
  //  StringChangeEx(URL, 'https', 'http', True)

  Log('Sending request: ' + URL + ' (HTTPS: ' + IntToStr(Integer(Https)) + ')');

  try
    WinHttpRequest := CreateOleObject('WinHttp.WinHttpRequest.5.1'); // 5.0 for < Win2000 SP3 / WinXP SP1 ?
    WinHttpRequest.SetTimeouts(6000, 4000, 4000, 4000);
    WinHttpRequest.Open('GET', URL, False);
    WinHttpRequest.Send;
    if (Asynchronous) then
    begin
      Result := -2
    end else begin
      WinHttpRequest.WaitForResponse()
      Result := WinHttpRequest.Status;
    end;
    Log('Status: ' + IntToStr(Result));
  except
    Log('Failed request: ' + URL);
    Log(GetExceptionMessage);
    Result := -1;
    if (Https and HttpFallback) then
    begin
      Log('URL was using HTTPS, trying HTTP as fallback...');
      StringChangeEx(URL, 'https', 'http', True);
      Result := SendRequest(URL, False, Asynchronous);
    end;
  end;
end;

// Returns the HTTP status code, or -1 if the request failed. There is no fallback to HTTP: the
// callers decide what to open or install from the answer, so it must come over validated TLS.
function DownloadString(const URL: string; var Response: string): Integer;
var
  WinHttpRequest: Variant;
begin
  Result := -1;
  Log('Downloading string: ' + URL);

  try
    Response := '';
    WinHttpRequest := CreateOleObject('WinHttp.WinHttpRequest.5.1'); // 5.0 for < Win2000 SP3 / WinXP SP1 ?
    WinHttpRequest.SetTimeouts(8000, 4000, 4000, 4000);
    WinHttpRequest.Open('GET', URL, False);
    WinHttpRequest.Send;
    WinHttpRequest.WaitForResponse(); 
    Result := WinHttpRequest.Status;
    Response := WinHttpRequest.ResponseText;
    Log('Downloaded string: ' + URL + ' [Code: ' + IntToStr(Result) + ', Length: ' + IntToStr(Length(Response)) + ']');
  except
    Log('Failed to download: ' + URL);
    Log(GetExceptionMessage);
    Result := -1;
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