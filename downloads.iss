[Code]
// Online localized files: download policy, SHA-256 pins, the downloads and their verification
//
// RegisterOnlineFiles (setup_is6.iss) registers the selected localized files of the community
// file servers, DownloadOnlineFiles downloads them with Inno Setup's built-in downloads (one
// download page, CreateOnlineFilesDownloadPage), one file at a time, from the server chosen by
// SelectOnlineFilesServer and, if that fails, once from the other one. Both servers are https
// URLs; Inno Setup's downloads never accept an invalid TLS certificate (no option to ignore one,
// no fallback to http; docs/adr, ADR 0003). Which files are accepted (GetOnlineFileCheck,
// utils.iss):
//  - A file that can contain code (Language.dll; the types are listed once, CodeFileExtensions in
//    utils.iss) only with its SHA-256 compiled into this setup ("pin"). Without a pin it is not
//    downloaded at all: whoever controls the server or its certificate must not be able to make
//    the elevated setup install code.
//  - A data file (voices, campaigns, movies, lobby texts) with a pin only if it matches the pin.
//    Without a pin it is accepted as the server sends it, but only over https with a validated
//    certificate, never from an http URL (main server and mirror alike); the log calls it
//    "TLS-verified, not pinned". Inno Setup's downloads follow a redirect from https to http
//    (docs/adr/0008-release-checksums-and-contract-check.md, point 6), so right before such a file
//    is downloaded, CheckOnlineFileRedirects asks its URL with HEAD requests that follow no
//    redirect themselves: a redirect to anything but https refuses the file on that server, like
//    no answer at all. Most of these files (data.ssa, the campaigns, the localized
//    intro movie) only exist on the servers, so a build can rarely pin them; requiring a pin made
//    the download component useless.
// AddOnlineFile registers a file only under these conditions. DownloadOnlineFiles checks the pin
// right after each download (a mismatch is deleted and the other server tried), and the pure
// helper NextDownloadAction (utils.iss) decides what happens after each attempt: keep the file,
// try the other server once (only if GetOnlineFileCheck gives the same result for its URL, so a
// file without pin never comes over http), give up on the file, or, after the stop button of the
// download page, stop all downloads (no further request at all). VerifyDownloadedFiles (ssInstall,
// before any file is installed) checks every downloaded file again and moves the accepted ones to
// {tmp}\verified\, the only folder [Files] installs them from. Every selected file that does not
// arrive there (code file without pin, download failed, skipped after a stop, pin mismatch) is
// logged and reported as a notice, and the setup installs the file it contains itself. Nothing of
// this stops the installation.
//
// The pins come from a list in sha256sum format ("<SHA-256 in hex>  <path>", one file per line,
// paths relative to data\localized-text, whose layout the "localized" folder of the file servers
// has too; the servers also have a lobby folder per language tag where data\localized-text has
// one for several languages, see RegisterGameOnlineFiles). ISPP 6.2 can only compute MD5 and
// SHA-1 (GetSHA256OfFile is missing until Inno Setup 6.3), so the list is created before
// compiling: ci\build.ps1 writes it from data\localized-text, see README.md "Online localized
// files". Without the list the setup compiles with a warning, and no Language.dll is downloaded.
//
// Requires: EEDir, AoCDir (ISPP, setup_is6.iss), OnlineFilesURL, OnlineFilesMirrorURL,
// GetHttpStatus, HttpRequest, IsRedirectStatus, ResolveRedirectUrl, RequestResolveTimeoutMs,
// HttpRequestFailed, GetOnlineFileCheck, IsHttpsUrl, NextDownloadAction and the DownloadOutcome*
// and DownloadAction* constants (utils.iss), SilentInstall, SuppressMsgBoxes (extension.iss), the
// Download* messages (messages.iss).

// DownloadHashFile: the hash list, relative to setup_is6.iss unless absolute (ISCC /DDownloadHashFile=...)
#ifndef DownloadHashFile
  #define DownloadHashFile "data\localized-text.sha256"
#endif
#if Copy(DownloadHashFile, 2, 1) == ":" || Copy(DownloadHashFile, 1, 2) == "\\"
  #define DownloadHashPath DownloadHashFile
#else
  #define DownloadHashPath AddBackslash(SourcePath) + DownloadHashFile
#endif

// State of the parser below (#sub can only assign existing variables, hence #expr)
#define DownloadPinCount 0
#define DownloadHashHandle 0
#define DownloadHashLineNo 0
#define DownloadHashLine ""
#define DownloadPinHash ""
#define DownloadPinPath ""
#define DownloadPinHexIndex 0
#define DownloadPinValid 0

#sub CheckDownloadPinHexDigit
  #if Pos(Copy(DownloadPinHash, DownloadPinHexIndex, 1), "0123456789abcdef") == 0
    #expr DownloadPinValid = 0
  #endif
#endsub

// Emits one AddDownloadPin call per line of the hash list; a malformed line stops the build
#sub ParseDownloadHashLine
  #expr DownloadHashLineNo++
  #expr DownloadHashLine = Trim(FileRead(DownloadHashHandle))
  #if DownloadHashLine != "" && Copy(DownloadHashLine, 1, 1) != "#"
    #expr DownloadPinHash = LowerCase(Copy(DownloadHashLine, 1, 64))
    #expr DownloadPinPath = Copy(DownloadHashLine, 67, Len(DownloadHashLine))
    #expr DownloadPinValid = Len(DownloadHashLine) > 66 && Copy(DownloadHashLine, 65, 1) == " " && (Copy(DownloadHashLine, 66, 1) == " " || Copy(DownloadHashLine, 66, 1) == "*")
    #for {DownloadPinHexIndex = 1; DownloadPinHexIndex <= 64; DownloadPinHexIndex++} CheckDownloadPinHexDigit
    #if !DownloadPinValid
      #pragma error "Line " + Str(DownloadHashLineNo) + " of " + DownloadHashPath + " is not '<SHA-256 in hex>  <path>' (sha256sum format, ASCII or UTF-8 without BOM)"
    #endif
    #expr DownloadPinPath = StringChange(DownloadPinPath, "\", "/")
    #if Copy(DownloadPinPath, 1, 2) == "./"
      #expr DownloadPinPath = Copy(DownloadPinPath, 3, Len(DownloadPinPath))
    #endif
  AddDownloadPin('{#StringChange(DownloadPinPath, "'", "''")}', '{#DownloadPinHash}');
    #expr DownloadPinCount++
  #endif
#endsub

type
  TDownloadPin = record
    RelPath: String;  // path below data\localized-text
    SHA256: String;   // lowercase hex
  end;

  TOnlineFile = record
    Url: String;           // on the server tried first (SelectOnlineFilesServer)
    SecondaryUrl: String;  // the same file on the other server, '' if the policy does not allow it there
    RelPath: String;
    RelDest: String;  // download target relative to {tmp}, e.g. EE\Language.dll
    SHA256: String;   // the pin, '' for a data file accepted without one (TLS-verified only)
    CopyOf: Integer;  // -1, or the entry with the same URL: its verified file is copied to RelDest
    // Result of DownloadOnlineFiles: '' if downloaded (and matching its pin), else the custom
    // message that describes the problem (DownloadFileMissing, DownloadFileRejected,
    // DownloadFileSkipped)
    DownloadProblem: String;
  end;

  TRefusedOnlineFile = record
    RelDest: String;
    Problem: String;  // custom message describing why it is not downloaded
  end;

var
  DownloadPins: array of TDownloadPin;
  OnlineFiles: array of TOnlineFile;
  // Selected files that are not downloaded at all (GetOnlineFileCheck refused them)
  RefusedOnlineFiles: array of TRefusedOnlineFile;
  // Server tried first and mirror, see SelectOnlineFilesServer
  OnlineFilesPrimaryURL, OnlineFilesSecondaryURL: String;
  // The download page (CreateOnlineFilesDownloadPage, InitializeWizard)
  OnlineFilesDownloadPage: TDownloadWizardPage;
  // Set right after a Download call that the user stopped (TDownloadWizardPage.AbortedByUser is
  // reset by every Download call, so it is copied at once): then no further URL is requested
  DownloadsStoppedByUser, DownloadsStopLogged: Boolean;
  // Set by the progress callback if the server announced the size of the current download
  // (Content-Length); Inno Setup only checks the size of a download with such an announcement
  DownloadSizeAnnounced: Boolean;

procedure AddDownloadPin(const RelPath, SHA256: String);
var
  N: Integer;
begin
  N := GetArrayLength(DownloadPins);
  SetArrayLength(DownloadPins, N + 1);
  DownloadPins[N].RelPath := RelPath;
  DownloadPins[N].SHA256 := SHA256;
end;

// Hashes of {#DownloadHashPath}, generated at compile time
procedure RegisterDownloadPins;
begin
  SetArrayLength(DownloadPins, 0);
#if FileExists(DownloadHashPath)
  #for {DownloadHashHandle = FileOpen(DownloadHashPath); DownloadHashHandle && !FileEof(DownloadHashHandle); ""} ParseDownloadHashLine
  #if DownloadHashHandle
    #expr FileClose(DownloadHashHandle)
  #endif
#endif
  Log('Online files: ' + IntToStr(GetArrayLength(DownloadPins)) + ' SHA-256 hashes known');
end;
#if DownloadPinCount == 0
  #pragma warning "No SHA-256 hashes in " + DownloadHashPath + ": this setup will not download any Language.dll, only data files over HTTPS (see README.md, Online localized files)"
#endif

// SHA-256 pin of a path of the hash list (exact match), '' if none
function GetDownloadPin(const RelPath: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to GetArrayLength(DownloadPins) - 1 do
    if CompareStr(DownloadPins[I].RelPath, RelPath) = 0 then
    begin
      Result := DownloadPins[I].SHA256;
      Exit;
    end;
end;

// Can any localized file be downloaded? Files with a pin, and data files without one from an https
// server (GetOnlineFileCheck). Also the Check of the component language\update, so only
// compile-time values and constants (component checks may run before InitializeWizard, where
// RegisterDownloadPins runs).
function CanDownloadOnlineFiles: Boolean;
begin
  Result := ({#DownloadPinCount} > 0) or IsHttpsUrl(OnlineFilesURL) or IsHttpsUrl(OnlineFilesMirrorURL);
end;

// Chooses the server the files are downloaded from (OnlineFilesURL and OnlineFilesMirrorURL,
// utils.iss): the main server, or the mirror if only the mirror answers (the other one is still
// tried for a file that fails). With realistic timeouts, an unreachable main server would
// otherwise delay every single file. Any HTTP answer over validated TLS counts (GetHttpStatus,
// utils.iss; its log line names the cause of a failure, e.g. an invalid certificate). False if
// neither answers.
function SelectOnlineFilesServer: Boolean;
begin
  Result := True;
  if GetHttpStatus(OnlineFilesURL) <> HttpRequestFailed then
  begin
    OnlineFilesPrimaryURL := OnlineFilesURL;
    OnlineFilesSecondaryURL := OnlineFilesMirrorURL;
  end
  else if GetHttpStatus(OnlineFilesMirrorURL) <> HttpRequestFailed then
  begin
    Log('Main online files server unreachable or without a valid certificate (see the HTTP GET line above), downloading from the mirror first');
    OnlineFilesPrimaryURL := OnlineFilesMirrorURL;
    OnlineFilesSecondaryURL := OnlineFilesURL;
  end
  else
    Result := False;
end;

procedure ClearOnlineFiles;
begin
  SetArrayLength(OnlineFiles, 0);
  SetArrayLength(RefusedOnlineFiles, 0);
end;

// Selected file that is not downloaded at all, for the report of VerifyDownloadedFiles: RelDest is
// its download target, Problem the custom message that describes why (once per target)
procedure NoteRefusedOnlineFile(const RelDest, Problem: String);
var
  I, N: Integer;
begin
  N := GetArrayLength(RefusedOnlineFiles);
  for I := 0 to N - 1 do
    if CompareText(RefusedOnlineFiles[I].RelDest, RelDest) = 0 then
      Exit;
  SetArrayLength(RefusedOnlineFiles, N + 1);
  RefusedOnlineFiles[N].RelDest := RelDest;
  RefusedOnlineFiles[N].Problem := Problem;
end;

// Registers the download of <server>/RelPath to {tmp}\RelDest if GetOnlineFileCheck (utils.iss)
// accepts it with the pin of PinPath (the path of the file in the hash list, usually RelPath);
// otherwise the file is noted for the report (NoteRefusedOnlineFile). Only one file per RelDest.
// The caller registers only what is selected. Call SelectOnlineFilesServer first; the file is
// downloaded by DownloadOnlineFiles.
procedure AddOnlineFile(const RelPath, PinPath, RelDest: String);
var
  I, N, CopyOf, Check: Integer;
  Hash, Url, MirrorUrl: String;
begin
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
    if CompareText(OnlineFiles[I].RelDest, RelDest) = 0 then
    begin
      Log('Online file skipped, ' + RelDest + ' is already downloaded from ' + OnlineFiles[I].RelPath);
      Exit;
    end;

  Hash := GetDownloadPin(PinPath);
  Url := OnlineFilesPrimaryURL + '/' + RelPath;
  MirrorUrl := OnlineFilesSecondaryURL + '/' + RelPath;
  Check := GetOnlineFileCheck(RelDest, Hash, Url);
  if Check = OnlineFileRefusedCode then
  begin
    Log('Online file not downloaded, it may contain code and no SHA-256 is known for ' + PinPath);
    NoteRefusedOnlineFile(RelDest, 'DownloadFileUnverifiable');
    Exit;
  end;
  if Check = OnlineFileRefusedInsecure then
  begin
    Log('Online file not downloaded, no SHA-256 is known for ' + PinPath + ' and ' + Url + ' is not https');
    NoteRefusedOnlineFile(RelDest, 'DownloadFileMissing');
    Exit;
  end;
  // The mirror only under the same condition: a file without pin never comes over http
  if GetOnlineFileCheck(RelDest, Hash, MirrorUrl) <> Check then
  begin
    Log('Mirror not used for ' + RelPath + ', ' + MirrorUrl + ' is not https');
    MirrorUrl := '';
  end;

  // A file needed in both game folders (the lobby files shared by EE and AoC) is downloaded once,
  // VerifyDownloadedFiles copies it
  CopyOf := -1;
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
    if (OnlineFiles[I].RelPath = RelPath) and (OnlineFiles[I].CopyOf < 0) then
      CopyOf := I;
  if CopyOf >= 0 then
  begin
    Url := OnlineFiles[CopyOf].Url;
    MirrorUrl := OnlineFiles[CopyOf].SecondaryUrl;
  end;

  N := GetArrayLength(OnlineFiles);
  SetArrayLength(OnlineFiles, N + 1);
  OnlineFiles[N].Url := Url;
  OnlineFiles[N].SecondaryUrl := MirrorUrl;
  OnlineFiles[N].RelPath := RelPath;
  OnlineFiles[N].RelDest := RelDest;
  OnlineFiles[N].SHA256 := Hash;
  OnlineFiles[N].CopyOf := CopyOf;
  OnlineFiles[N].DownloadProblem := 'DownloadFileMissing';
  if Hash <> '' then
    Log('Online file registered, SHA-256 pinned: ' + RelPath)
  else
    Log('Online file registered, TLS-verified, not pinned: ' + RelPath);
end;

// Progress callback of the download page: notes whether the server announced the size of the
// current download (Content-Length). The page itself logs the progress and processes the stop
// button. True: go on.
function OnOnlineFileDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax > 0 then
    DownloadSizeAnnounced := True;
  Result := True;
end;

// The one download page of the setup (InitializeWizard). Its labels, its stop button and the
// question after the stop button are Inno Setup's own messages (DownloadingLabel,
// ButtonStopDownload, StopDownload).
procedure CreateOnlineFilesDownloadPage;
begin
  OnlineFilesDownloadPage := CreateDownloadPage(CustomMessage('DownloadPageCaption'), CustomMessage('DownloadPageDescription'), @OnOnlineFileDownloadProgress);
end;

// Logged once when the user has stopped the downloads
procedure NoteDownloadsStopped;
begin
  if DownloadsStopLogged then
    Exit;
  DownloadsStopLogged := True;
  Log('Online files: downloads stopped by the user, no further request (neither the other server nor the remaining files)');
end;

const
  // Redirects CheckOnlineFileRedirects follows, as many as the client of Inno Setup's downloads
  OnlineFileMaxRedirects = 5;

// The check before an online file without pin is downloaded from Url: True if Url answers a HEAD
// request over https with anything but a redirect (any other status, e.g. 200, 404 or 405, which
// the download itself then handles), after at most OnlineFileMaxRedirects redirects that all lead
// to https URLs (ResolveRedirectUrl, utils.iss), each asked again with HEAD. False, logged, for a
// redirect to http:// or any other scheme, a redirect without Location, more redirects, or no
// answer. The requests follow no redirect themselves (HttpRequest with FollowRedirects False), so
// unlike the download they see every redirect; each one validates the certificate. What it cannot
// see: a server that answers HEAD and GET differently, or changes its answer between the check and
// the download (ADR 0008, point 6).
function CheckOnlineFileRedirects(const Url: String): Boolean;
var
  Current, Next, Location, Ignored: String;
  Status, Redirects: Integer;
begin
  Result := False;
  Current := Url;
  for Redirects := 0 to OnlineFileMaxRedirects do
  begin
    Status := HttpRequest('HEAD', Current, RequestResolveTimeoutMs, False, False, False, Ignored, Location);
    if Status = HttpRequestFailed then
    begin
      Log('Online file not downloaded from ' + Url + ': no answer to the check of its redirects (HEAD ' + Current + ')');
      Exit;
    end;
    if not IsRedirectStatus(Status) then
    begin
      Log('Online file redirect check: ' + Url + ' answers HTTP ' + IntToStr(Status) + ' over https after ' + IntToStr(Redirects) +
        ' redirects, none to http');
      Result := True;
      Exit;
    end;
    Next := ResolveRedirectUrl(Current, Location);
    if not IsHttpsUrl(Next) then
    begin
      Log('Online file refused, it has no SHA-256 and ' + Current + ' redirects to "' + Next + '", not to https: ' + Url);
      Exit;
    end;
    Current := Next;
  end;
  Log('Online file refused, more than ' + IntToStr(OnlineFileMaxRedirects) + ' redirects: ' + Url);
end;

// One download attempt of OnlineFiles[Index] from Url to {tmp}\<RelDest>: DownloadOutcomeSuccess,
// DownloadOutcomeFailure or DownloadOutcomePinMismatch. A file without pin is only requested if
// CheckOnlineFileRedirects allows it (else DownloadOutcomeFailure, so the other server may be tried).
// Sets DownloadsStoppedByUser if the user stopped it. No exception escapes.
function DownloadOnlineFileFrom(const Index: Integer; const Url: String): Integer;
var
  Target, Hash: String;
begin
  if (OnlineFiles[Index].SHA256 = '') and not CheckOnlineFileRedirects(Url) then
  begin
    Result := DownloadOutcomeFailure;
    Exit;
  end;
  Target := ExpandConstant('{tmp}\' + OnlineFiles[Index].RelDest);
  OnlineFilesDownloadPage.Clear;
  // No SHA-256 for Inno Setup: the pin is checked below, so that a mismatch is told apart from a
  // network error. Without one Inno Setup compares the received size with Content-Length, if the
  // server sent it. Download writes to a temporary name, renames it to Target only when complete
  // and deletes an older Target first, so after a failure there is no Target.
  OnlineFilesDownloadPage.Add(Url, OnlineFiles[Index].RelDest, '');
  DownloadSizeAnnounced := False;
  try
    OnlineFilesDownloadPage.Download;
    Result := DownloadOutcomeSuccess;
  except
    // Download resets AbortedByUser at its start and reports a stop like any other error
    if OnlineFilesDownloadPage.AbortedByUser then
      DownloadsStoppedByUser := True;
    Result := DownloadOutcomeFailure;
    if DownloadsStoppedByUser then
      Log('Online file download stopped by the user: ' + Url)
    else
      Log('Online file download failed from ' + Url + ': ' + GetExceptionMessage);
  end;
  if Result <> DownloadOutcomeSuccess then
    Exit;
  // The stop came too late to cancel this file: it is complete and kept, but nothing follows
  if OnlineFilesDownloadPage.AbortedByUser then
    DownloadsStoppedByUser := True;

  if OnlineFiles[Index].SHA256 <> '' then
  begin
    try
      Hash := LowerCase(GetSHA256OfFile(Target));
    except
      Hash := '';
      Log('Unable to hash ' + Target + ': ' + GetExceptionMessage);
    end;
    if Hash = OnlineFiles[Index].SHA256 then
      Log('Online file downloaded, SHA-256 pinned: ' + Url)
    else
    begin
      Log('Online file rejected, SHA-256 mismatch: ' + Url + ' (got ' + Hash + ')');
      if not DeleteFile(Target) then
        Log('Unable to delete ' + Target + ' (it is not installed anyway)');
      Result := DownloadOutcomePinMismatch;
    end;
  end
  else if DownloadSizeAnnounced then
    Log('Online file downloaded, TLS-verified, size checked: ' + Url)
  else
    Log('Online file downloaded, TLS-verified, accepted without size check (the server sent no Content-Length): ' + Url);
end;

// Downloads OnlineFiles[Index]: from its server, then, if NextDownloadAction (utils.iss) says so,
// once from the other server; sets its DownloadProblem
procedure DownloadOnlineFile(const Index: Integer);
var
  Url: String;
  Outcome, Action: Integer;
  OtherTried, Rejected: Boolean;
begin
  Url := OnlineFiles[Index].Url;
  OtherTried := False;
  Rejected := False;
  repeat
    Outcome := DownloadOnlineFileFrom(Index, Url);
    if Outcome = DownloadOutcomePinMismatch then
      Rejected := True;
    Action := NextDownloadAction(Outcome, OnlineFiles[Index].SecondaryUrl <> '', OtherTried, DownloadsStoppedByUser);
    case Action of
      DownloadActionAccept:
        OnlineFiles[Index].DownloadProblem := '';
      DownloadActionTryMirror:
        begin
          Url := OnlineFiles[Index].SecondaryUrl;
          OtherTried := True;
          Log('Online file: trying the other server, ' + Url);
        end;
      DownloadActionStopAll:
        begin
          OnlineFiles[Index].DownloadProblem := 'DownloadFileSkipped';
          NoteDownloadsStopped;
        end;
    else
      begin
        if Rejected then
          OnlineFiles[Index].DownloadProblem := 'DownloadFileRejected'
        else
          OnlineFiles[Index].DownloadProblem := 'DownloadFileMissing';
        if OtherTried then
          Log('Online file not downloaded, it failed on both servers: ' + OnlineFiles[Index].RelPath)
        else
          Log('Online file not downloaded, not retried: the other server is not https and the file has no SHA-256 (' + OnlineFiles[Index].RelPath + ')');
      end;
    end;
  until Action <> DownloadActionTryMirror;
end;

// Downloads every registered file (RegisterOnlineFiles) on the download page, one at a time; a
// file needed in both game folders only once (CopyOf). After a stop every remaining file is
// skipped without a request. The installation goes on in every case: VerifyDownloadedFiles reports
// what is missing and the setup installs its own files instead. Called by NextButtonClick(wpReady).
procedure DownloadOnlineFiles;
var
  I, Count: Integer;
begin
  DownloadsStoppedByUser := False;
  DownloadsStopLogged := False;
  Count := 0;
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
    if OnlineFiles[I].CopyOf < 0 then
      Count := Count + 1;
  if Count = 0 then
    Exit;

  Log('Downloading ' + IntToStr(Count) + ' online files, one at a time');
  OnlineFilesDownloadPage.Show;
  try
    for I := 0 to GetArrayLength(OnlineFiles) - 1 do
      if OnlineFiles[I].CopyOf < 0 then
      begin
        if DownloadsStoppedByUser then
        begin
          NoteDownloadsStopped;
          OnlineFiles[I].DownloadProblem := 'DownloadFileSkipped';
          Log('Online file skipped, downloads stopped by the user: ' + OnlineFiles[I].RelPath);
        end
        else
          try
            DownloadOnlineFile(I);
          except
            OnlineFiles[I].DownloadProblem := 'DownloadFileMissing';
            Log('Online file not downloaded, unexpected error: ' + GetExceptionMessage);
          end;
      end;
  finally
    OnlineFilesDownloadPage.Hide;
  end;
end;

// RelDest as the player sees it: the game folder instead of EE/AoC
function OnlineFileDisplayName(const RelDest: String): String;
begin
  Result := RelDest;
  if CompareText(Copy(Result, 1, 3), 'EE\') = 0 then
    Result := '{#EEDir}\' + Copy(Result, 4, Length(Result))
  else if CompareText(Copy(Result, 1, 4), 'AoC\') = 0 then
    Result := '{#AoCDir}\' + Copy(Result, 5, Length(Result));
end;

// Result of VerifyDownloadedFiles for one file: '' if it is in {tmp}\verified, else the name of
// the custom message that describes the problem. A file with a pin must match it; a data file
// without one is accepted as downloaded over https (its SHA-256 is only logged).
function VerifyOnlineFile(const OnlineFile: TOnlineFile): String;
var
  Source, Target, Hash: String;
begin
  Source := ExpandConstant('{tmp}\' + OnlineFile.RelDest);
  Target := ExpandConstant('{tmp}\verified\' + OnlineFile.RelDest);

  if (OnlineFile.DownloadProblem <> '') or not FileExists(Source) then
  begin
    Log('Online file not downloaded: ' + OnlineFile.RelPath);
    Result := OnlineFile.DownloadProblem;
    if Result = '' then
      Result := 'DownloadFileMissing';
    // A partial download must not stay next to the verified files
    DeleteFile(Source);
    Exit;
  end;

  try
    Hash := LowerCase(GetSHA256OfFile(Source));
  except
    Hash := '';
    Log('Unable to hash ' + Source + ': ' + GetExceptionMessage);
  end;

  // Only a file with the expected SHA-256 (or a data file without pin) is moved to the verified
  // folder
  Result := 'DownloadFileRejected';
  if (OnlineFile.SHA256 <> '') and (Hash <> OnlineFile.SHA256) then
    Log('Online file rejected, SHA-256 mismatch: ' + OnlineFile.RelPath + ' (got ' + Hash + ')')
  else if ForceDirectories(ExtractFileDir(Target)) and RenameFile(Source, Target) then
  begin
    if OnlineFile.SHA256 <> '' then
      Log('Online file verified, SHA-256 pinned: ' + OnlineFile.RelPath + ' (SHA-256 ' + Hash + ')')
    else
      Log('Online file accepted, TLS-verified, not pinned: ' + OnlineFile.RelPath + ' (SHA-256 ' + Hash + ')');
    Result := '';
  end
  else
  begin
    Log('Unable to move the verified file ' + Source + ' to ' + Target);
    Result := 'DownloadFileUnsaved';
  end;

  if (Result <> '') and FileExists(Source) and not DeleteFile(Source) then
    Log('Unable to delete ' + Source + ' (it is not installed anyway)');
end;

// Checks every downloaded file (VerifyOnlineFile) and moves the accepted ones to
// {tmp}\verified\<RelDest>, copies files needed in both game folders, then reports every
// registered file that is not there and every selected file that was not downloaded at all
// (RefusedOnlineFiles), so the player knows which localized content stays as the setup installs
// it itself (some of it in English). Nothing harmful was installed in any of these cases, so the
// report is a notice. Must run before [Files] is processed (ssInstall).
procedure VerifyDownloadedFiles;
var
  I, Missing: Integer;
  Problem: array of String;
  Target, Report: String;
begin
  // [Files] installs from these folders, so they have to exist even if nothing was downloaded
  ForceDirectories(ExpandConstant('{tmp}\verified\EE'));
  ForceDirectories(ExpandConstant('{tmp}\verified\AoC'));

  SetArrayLength(Problem, GetArrayLength(OnlineFiles));
  Missing := 0;
  Report := '';
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
  begin
    if OnlineFiles[I].CopyOf < 0 then
      Problem[I] := VerifyOnlineFile(OnlineFiles[I])
    else
    begin
      // The original entry comes first, so it has already been verified
      Problem[I] := Problem[OnlineFiles[I].CopyOf];
      Target := ExpandConstant('{tmp}\verified\' + OnlineFiles[I].RelDest);
      if Problem[I] = '' then
        if not ForceDirectories(ExtractFileDir(Target)) or
           not FileCopy(ExpandConstant('{tmp}\verified\' + OnlineFiles[OnlineFiles[I].CopyOf].RelDest), Target, False) then
        begin
          Log('Unable to copy the verified file to ' + Target);
          Problem[I] := 'DownloadFileUnsaved';
        end;
    end;

    if Problem[I] <> '' then
    begin
      Missing := Missing + 1;
      Report := Report + #13#10 + '  ' + FmtMessage(CustomMessage(Problem[I]), [OnlineFileDisplayName(OnlineFiles[I].RelDest)]);
    end;
  end;

  for I := 0 to GetArrayLength(RefusedOnlineFiles) - 1 do
  begin
    Missing := Missing + 1;
    Report := Report + #13#10 + '  ' + FmtMessage(CustomMessage(RefusedOnlineFiles[I].Problem), [OnlineFileDisplayName(RefusedOnlineFiles[I].RelDest)]);
  end;

  if Missing = 0 then
  begin
    if GetArrayLength(OnlineFiles) > 0 then
      Log('All ' + IntToStr(GetArrayLength(OnlineFiles)) + ' online files accepted');
    Exit;
  end;

  Log(IntToStr(Missing) + ' of ' + IntToStr(GetArrayLength(OnlineFiles) + GetArrayLength(RefusedOnlineFiles)) + ' selected online files are missing, the setup installs its own files instead:' + Report);
  // A pin mismatch (a file updated on the server after this setup was built, or a damaged or
  // tampered download) is reported like the other cases: the file was discarded, nothing of it is
  // installed
  if not SilentInstall and not SuppressMsgBoxes then
    MsgBox(FmtMessage(CustomMessage('DownloadIncomplete'), [Report]), mbInformation, MB_OK);
end;
