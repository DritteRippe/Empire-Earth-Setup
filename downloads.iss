[Code]
// Online localized files: download policy, SHA-256 pins, the downloads and their verification
//
// RegisterOnlineFiles (setup_is6.iss) registers the selected localized files of the community
// file servers, DownloadOnlineFiles downloads them (one download page,
// CreateOnlineFilesDownloadPage), one file at a time, from the server chosen by
// SelectOnlineFilesServer and, if that fails, once from the other one. Both servers are https
// URLs; there is no fallback to http. SelectOnlineFilesServer finds the state of each server
// (ADR 0012): it answers over TLS with a validated certificate, only without certificate
// validation, or not at all. From a server with a validated certificate every file comes with
// Inno Setup's built-in downloads, which never accept an invalid certificate (ADR 0003). From a
// server that only answers without certificate validation (files.empireearth.eu serves the
// certificate of its hosting provider) only pinned files come, with WinHTTP and certificate errors
// ignored (DownloadPinnedFileWinHttp): the SHA-256 decides whether the file is installed, not the
// certificate (GetOnlineFileTransport, utils.iss). Which files are accepted (GetOnlineFileCheck,
// utils.iss):
//  - A file that can contain code (Language.dll; the types are listed once, CodeFileExtensions in
//    utils.iss) only with its SHA-256 compiled into this setup ("pin"). Without a pin it is not
//    downloaded at all: whoever controls the server or its certificate must not be able to make
//    the elevated setup install code.
//  - A data file (voices, campaigns, movies, lobby texts) with a pin only if it matches the pin.
//    Every online file is pinned in pins\online-files.txt (ADR 0012). A file without pin (only if
//    that list misses one, e.g. in a test build) is accepted as the server sends it, but only over
//    https with a validated certificate, never from an http URL or a server whose certificate is
//    invalid (main server and mirror alike); the log calls it "TLS-verified, not pinned". Inno
//    Setup's downloads follow a redirect from https to http
//    (docs/adr/0008-release-checksums-and-contract-check.md, point 6), so right before such a file
//    is downloaded, CheckOnlineFileRedirects asks its URL with HEAD requests that follow no
//    redirect themselves: a redirect to anything but https refuses the file on that server, like
//    no answer at all. A pinned file may come over any transport and redirect: its pin decides.
// AddOnlineFile registers a file only under these conditions. DownloadOnlineFiles checks the pin
// (and the pinned size) of each download (a mismatch is deleted and the other server tried), and
// the pure helper NextDownloadAction (utils.iss) decides what happens after each attempt: keep the
// file, try the other server once (only if it has a transport for the file, so a file without pin
// never comes over http or from a server without a valid certificate), give up on the file, or,
// after the stop button of the download page, stop all downloads (no further request at all).
// VerifyDownloadedFiles (ssInstall,
// before any file is installed) checks every downloaded file again and moves the accepted ones to
// {tmp}\verified\, the only folder [Files] installs them from. Every selected file that does not
// arrive there (code file without pin, download failed, skipped after a stop, pin mismatch) is
// logged and reported as a notice, and the setup installs the file it contains itself. Nothing of
// this stops the installation.
//
// The pins come from two lists, both compiled into the setup (GetOnlineFilePin):
//  - pins\online-files.txt, checked in (ADR 0012): SHA-256 and size of every file a setup can
//    download, by its server path ("<SHA-256> <size> <server path>"). Every online file of both
//    products is pinned there; ci\online_pins.ps1 and ci\build.ps1 check that.
//  - the hash list of the build in sha256sum format ("<SHA-256 in hex>  <path>", one file per
//    line, paths relative to data\localized-text, whose layout the "localized" folder of the file
//    servers has too; the servers also have a lobby folder per language tag where
//    data\localized-text has one for several languages, see RegisterGameOnlineFiles). ISPP 6.2 can
//    only compute MD5 and SHA-1 (GetSHA256OfFile is missing until Inno Setup 6.3), so the list is
//    created before compiling: ci\build.ps1 writes it from data\localized-text, see README.md
//    "Online localized files". It applies first, so that a test build can pin a file differently;
//    a release build stops if the two lists pin different files.
//
// Requires: EEDir, AoCDir (ISPP, setup_is6.iss), OnlineFilesURL, OnlineFilesMirrorURL,
// GetHttpStatus, HttpRequest, IsRedirectStatus, ResolveRedirectUrl, RequestResolveTimeoutMs,
// HttpRequestFailed, GetOnlineFileCheck, IsHttpsUrl, NextDownloadAction, ParsePinnedSize, the
// server states and transports (ClassifyOnlineFilesServer, ChooseOnlineFilesServerOrder,
// GetOnlineFileTransport, IsDownloadSizeAcceptable), the WinHTTP helpers (OpenWinHttpRequest,
// SendWinHttpRequest, CloseWinHttpRequest, GetHttpStatusIgnoringCertificate, WinHttpQueryHeaders,
// WinHttpReadData, WriteFile, DescribeWinHttpError), GetTickCount, TicksSince and the
// DownloadOutcome*, DownloadAction*, OnlineServer*, OnlineFilesOrder* and DownloadTransport*
// constants (utils.iss), SilentInstall, SuppressMsgBoxes (extension.iss), the Download* messages
// (messages.iss).

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

// OnlinePinFile: the pins of every online file by its server path, with its size
// (pins\online-files.txt, checked in; docs/adr/0012-pinned-downloads-despite-invalid-certificates.md),
// relative to setup_is6.iss unless absolute (ISCC /DOnlinePinFile=...). Format:
// "<SHA-256, 64 lowercase hex digits> <size in bytes> <server path>", '#' starts a comment line;
// ci\online_pins.ps1 checks it more strictly (order, coverage of every online file).
#ifndef OnlinePinFile
  #define OnlinePinFile "pins\online-files.txt"
#endif
#if Copy(OnlinePinFile, 2, 1) == ":" || Copy(OnlinePinFile, 1, 2) == "\\"
  #define OnlinePinPath OnlinePinFile
#else
  #define OnlinePinPath AddBackslash(SourcePath) + OnlinePinFile
#endif
#if !FileExists(OnlinePinPath)
  #pragma error OnlinePinPath + " not found: the pins of the online files are part of the repository (ADR 0012)"
#endif

#define OnlinePinCount 0
#define OnlinePinHandle 0
#define OnlinePinLineNo 0
#define OnlinePinLine ""
#define OnlinePinRest ""
#define OnlinePinSize ""
#define OnlinePinSizeEnd 0
#define OnlinePinDigitIndex 0

#sub CheckOnlinePinSizeDigit
  #if Pos(Copy(OnlinePinSize, OnlinePinDigitIndex, 1), "0123456789") == 0
    #expr DownloadPinValid = 0
  #endif
#endsub

// Emits one AddOnlinePin call per line of the pin list; a malformed line stops the build
#sub ParseOnlinePinLine
  #expr OnlinePinLineNo++
  #expr OnlinePinLine = Trim(FileRead(OnlinePinHandle))
  #if OnlinePinLine != "" && Copy(OnlinePinLine, 1, 1) != "#"
    #expr DownloadPinHash = Copy(OnlinePinLine, 1, 64)
    #expr OnlinePinRest = Copy(OnlinePinLine, 66, Len(OnlinePinLine))
    #expr OnlinePinSizeEnd = Pos(" ", OnlinePinRest)
    #expr OnlinePinSize = Copy(OnlinePinRest, 1, OnlinePinSizeEnd - 1)
    #expr DownloadPinPath = Copy(OnlinePinRest, OnlinePinSizeEnd + 1, Len(OnlinePinRest))
    #expr DownloadPinValid = Len(OnlinePinLine) > 67 && Copy(OnlinePinLine, 65, 1) == " " && OnlinePinSizeEnd > 1 && OnlinePinSizeEnd <= 16 && Copy(OnlinePinSize, 1, 1) != "0" && DownloadPinPath != ""
    #for {DownloadPinHexIndex = 1; DownloadPinHexIndex <= 64; DownloadPinHexIndex++} CheckDownloadPinHexDigit
    #for {OnlinePinDigitIndex = 1; OnlinePinDigitIndex < OnlinePinSizeEnd; OnlinePinDigitIndex++} CheckOnlinePinSizeDigit
    #if !DownloadPinValid
      #pragma error "Line " + Str(OnlinePinLineNo) + " of " + OnlinePinPath + " is not '<SHA-256, 64 lowercase hex digits> <size in bytes> <server path>' (see ci\online_pins.ps1)"
    #endif
  AddOnlinePin('{#StringChange(DownloadPinPath, "'", "''")}', '{#DownloadPinHash}', '{#OnlinePinSize}');
    #expr OnlinePinCount++
  #endif
#endsub

type
  TDownloadPin = record
    RelPath: String;  // path below data\localized-text
    SHA256: String;   // lowercase hex
  end;

  TOnlinePin = record
    RelPath: String;  // server path below "localized" (pins\online-files.txt)
    SHA256: String;   // lowercase hex
    Size: Int64;      // bytes (ParsePinnedSize; -1 if the list had an invalid size)
  end;

  TOnlineFile = record
    Url: String;           // on the server tried first (SelectOnlineFilesServer)
    SecondaryUrl: String;  // the same file on the other server, '' if the policy does not allow it there
    Transport: Integer;           // DownloadTransport* for Url (GetOnlineFileTransport, utils.iss)
    SecondaryTransport: Integer;  // and for SecondaryUrl
    RelPath: String;
    RelDest: String;  // download target relative to {tmp}, e.g. EE\Language.dll
    SHA256: String;   // the pin, '' for a data file accepted without one (TLS-verified only)
    Size: Int64;      // the pinned size (pins\online-files.txt), -1 if unknown
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
  OnlinePins: array of TOnlinePin;
  OnlineFiles: array of TOnlineFile;
  // Selected files that are not downloaded at all (GetOnlineFileCheck refused them)
  RefusedOnlineFiles: array of TRefusedOnlineFile;
  // Server tried first and mirror, and their states (OnlineServer*), see SelectOnlineFilesServer
  OnlineFilesPrimaryURL, OnlineFilesSecondaryURL: String;
  OnlineFilesPrimaryState, OnlineFilesSecondaryState: Integer;
  // The download page (CreateOnlineFilesDownloadPage, InitializeWizard)
  OnlineFilesDownloadPage: TDownloadWizardPage;
  // Set right after a Download call that the user stopped (TDownloadWizardPage.AbortedByUser is
  // reset by every Download call, so it is copied at once): then no further URL is requested
  DownloadsStoppedByUser, DownloadsStopLogged: Boolean;
  // Set by the progress callback if the server announced the size of the current download
  // (Content-Length); Inno Setup only checks the size of a download with such an announcement
  DownloadSizeAnnounced: Boolean;
  // The current built-in download for the progress callback: whether it has a pin, its pinned size
  // (-1 if unknown); set by the callback if it stopped the download because the size cannot match
  CurrentDownloadPinned, DownloadSizeRejected: Boolean;
  CurrentDownloadPinnedSize: Int64;
  DownloadSizeRejectedNote: String;
  // Files downloaded per transport, for the summary line of DownloadOnlineFiles
  OnlineFilesByBuiltIn, OnlineFilesByWinHttp: Integer;

procedure AddDownloadPin(const RelPath, SHA256: String);
var
  N: Integer;
begin
  N := GetArrayLength(DownloadPins);
  SetArrayLength(DownloadPins, N + 1);
  DownloadPins[N].RelPath := RelPath;
  DownloadPins[N].SHA256 := SHA256;
end;

procedure AddOnlinePin(const RelPath, SHA256, SizeText: String);
var
  N: Integer;
begin
  N := GetArrayLength(OnlinePins);
  SetArrayLength(OnlinePins, N + 1);
  OnlinePins[N].RelPath := RelPath;
  OnlinePins[N].SHA256 := SHA256;
  OnlinePins[N].Size := ParsePinnedSize(SizeText);
end;

// Hashes of {#DownloadHashPath} and the pins of {#OnlinePinPath}, generated at compile time
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
  SetArrayLength(OnlinePins, 0);
  #for {OnlinePinHandle = FileOpen(OnlinePinPath); OnlinePinHandle && !FileEof(OnlinePinHandle); ""} ParseOnlinePinLine
  #if OnlinePinHandle
    #expr FileClose(OnlinePinHandle)
  #endif
  Log('Online files: ' + IntToStr(GetArrayLength(OnlinePins)) + ' SHA-256 pins with sizes of {#OnlinePinFile}');
end;
#if DownloadPinCount == 0
  #pragma warning "No SHA-256 hashes in " + DownloadHashPath + ": only the pins of " + OnlinePinFile + " apply (see README.md, Online localized files)"
#endif
#if OnlinePinCount == 0
  #pragma warning "No pins in " + OnlinePinPath + ": this setup downloads no Language.dll, and only data files from servers with a valid certificate (ADR 0012)"
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

// The pin of the online file RelPath (server path) whose entry in the hash list of the build is
// PinPath: SHA256 (lowercase hex) and Size (bytes, -1 if unknown); False and '' if it has none.
// The hash list of the build (data\localized-text) applies first, so that a test build can pin a
// file differently (TEST-PLAN TP-13, TP-16); the size comes from pins\online-files.txt if both
// pin the same file. A release build stops if they differ (ci\build.ps1, Test-PinConsistency),
// the log notes it here. Without an entry in the hash list the pin of pins\online-files.txt
// applies.
function GetOnlineFilePin(const RelPath, PinPath: String; var SHA256: String; var Size: Int64): Boolean;
var
  I: Integer;
  Local: String;
begin
  Local := GetDownloadPin(PinPath);
  SHA256 := Local;
  Size := -1;
  for I := 0 to GetArrayLength(OnlinePins) - 1 do
    if CompareStr(OnlinePins[I].RelPath, RelPath) = 0 then
    begin
      if (Local = '') or (Local = OnlinePins[I].SHA256) then
      begin
        SHA256 := OnlinePins[I].SHA256;
        Size := OnlinePins[I].Size;
      end else
        Log('Online file ' + RelPath + ': the hash list of this build pins another file at ' + PinPath + ' than {#OnlinePinFile}; the hash list applies, the size is not known');
      Break;
    end;
  Result := SHA256 <> '';
end;

// Can any localized file be downloaded? Files with a pin, and data files without one from an https
// server (GetOnlineFileCheck). Also the Check of the component language\update, so only
// compile-time values and constants (component checks may run before InitializeWizard, where
// RegisterDownloadPins runs).
function CanDownloadOnlineFiles: Boolean;
begin
  Result := ({#DownloadPinCount} > 0) or ({#OnlinePinCount} > 0) or IsHttpsUrl(OnlineFilesURL) or IsHttpsUrl(OnlineFilesMirrorURL);
end;

// A state of a file server (OnlineServer*, utils.iss) for the log
function OnlineServerStateText(const State: Integer): String;
begin
  case State of
    OnlineServerVerified: Result := 'valid certificate';
    OnlineServerCertificateInvalid: Result := 'invalid certificate: pinned files only, without certificate validation';
    OnlineServerNotChecked: Result := 'not checked: downloads with certificate validation only';
  else
    Result := 'no answer: not used';
  end;
end;

// The state of the file server Url (ClassifyOnlineFilesServer, utils.iss): the probe with a
// validated certificate first (GetHttpStatus, utils.iss; its log line names the cause of a
// failure, e.g. an invalid certificate), and only if it gets no answer and WithPins (the setup has
// pins), the probe without certificate validation (GetHttpStatusIgnoringCertificate, which reads
// no answer). Any HTTP status counts as an answer. Logs what it found.
function ProbeOnlineFilesServer(const Url: String; const WithPins: Boolean): Integer;
var
  Strict, Lenient: Integer;
begin
  Strict := GetHttpStatus(Url);
  Lenient := HttpRequestFailed;
  if (Strict = HttpRequestFailed) and WithPins then
    Lenient := GetHttpStatusIgnoringCertificate(Url);
  Result := ClassifyOnlineFilesServer(Strict, Lenient);
  if Result = OnlineServerCertificateInvalid then
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('Online files server ' + Url + ': answers only without certificate validation (HTTP ' + IntToStr(Lenient) + '); ' +
      'pinned files are downloaded from it with WinHTTP, certificate errors ignored, the SHA-256 decides; files without SHA-256 are not')
  else if (Result = OnlineServerUnreachable) and WithPins then
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('Online files server ' + Url + ': no answer, neither with nor without certificate validation')
  else if Result = OnlineServerUnreachable then
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('Online files server ' + Url + ': no answer over validated TLS (not asked without certificate validation: this setup has no pins)');
end;

// Chooses the server the files are downloaded from (OnlineFilesURL and OnlineFilesMirrorURL,
// utils.iss) and notes the state of both (ADR 0012): the main server if it answers with a valid
// certificate (the mirror is then not asked; it may still be tried for a file that fails, with the
// built-in downloads, which validate its certificate); else the server in the better state
// (ChooseOnlineFilesServerOrder, utils.iss: valid certificate before invalid certificate before no
// answer, the main server on a tie). With realistic timeouts, an unreachable main server would
// otherwise delay every single file. False if neither server answers (with pins: with or without
// certificate validation; without pins: with a valid certificate).
function SelectOnlineFilesServer: Boolean;
var
  MainState, MirrorState, Order: Integer;
  WithPins: Boolean;
begin
  WithPins := (GetArrayLength(DownloadPins) > 0) or (GetArrayLength(OnlinePins) > 0);
  MainState := ProbeOnlineFilesServer(OnlineFilesURL, WithPins);
  if MainState = OnlineServerVerified then
    MirrorState := OnlineServerNotChecked
  else
    MirrorState := ProbeOnlineFilesServer(OnlineFilesMirrorURL, WithPins);
  Order := ChooseOnlineFilesServerOrder(MainState, MirrorState);
  if Order = OnlineFilesOrderMirrorFirst then
  begin
    Log('Main online files server unreachable or without a valid certificate (see the HTTP GET line above), downloading from the mirror first');
    OnlineFilesPrimaryURL := OnlineFilesMirrorURL;
    OnlineFilesPrimaryState := MirrorState;
    OnlineFilesSecondaryURL := OnlineFilesURL;
    OnlineFilesSecondaryState := MainState;
  end else
  begin
    OnlineFilesPrimaryURL := OnlineFilesURL;
    OnlineFilesPrimaryState := MainState;
    OnlineFilesSecondaryURL := OnlineFilesMirrorURL;
    OnlineFilesSecondaryState := MirrorState;
  end;
  Result := Order <> OnlineFilesOrderNone;
  if Result then
    Log('Online files: ' + OnlineFilesPrimaryURL + ' first (' + OnlineServerStateText(OnlineFilesPrimaryState) + '), then ' +
      OnlineFilesSecondaryURL + ' (' + OnlineServerStateText(OnlineFilesSecondaryState) + ')');
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
// accepts it with its pin (GetOnlineFilePin: by RelPath in pins\online-files.txt, by PinPath, the
// path in the hash list of the build, usually RelPath) and the server tried first has a transport
// for it (GetOnlineFileTransport, utils.iss); otherwise the file is noted for the report
// (NoteRefusedOnlineFile). Only one file per RelDest. The caller registers only what is selected.
// Call SelectOnlineFilesServer first; the file is downloaded by DownloadOnlineFiles.
procedure AddOnlineFile(const RelPath, PinPath, RelDest: String);
var
  I, N, CopyOf, Check, Transport, SecondaryTransport: Integer;
  Hash, Url, MirrorUrl: String;
  Size: Int64;
begin
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
    if CompareText(OnlineFiles[I].RelDest, RelDest) = 0 then
    begin
      Log('Online file skipped, ' + RelDest + ' is already downloaded from ' + OnlineFiles[I].RelPath);
      Exit;
    end;

  GetOnlineFilePin(RelPath, PinPath, Hash, Size);
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
  // The server tried first is in the better state (SelectOnlineFilesServer), so if it has no
  // transport for the file, the other one has none either: a file without pin from a server whose
  // certificate is invalid
  Transport := GetOnlineFileTransport(Check, OnlineFilesPrimaryState);
  if Transport = DownloadTransportNone then
  begin
    Log('Online file not downloaded, no SHA-256 is known for ' + PinPath + ' and ' + OnlineFilesPrimaryURL +
      ' has no valid certificate (without one only pinned files are downloaded)');
    NoteRefusedOnlineFile(RelDest, 'DownloadFileServerCertificate');
    Exit;
  end;
  // The other server only with a transport of its own: a file without pin never comes over http
  // or from a server whose certificate is invalid, and nothing from a server without an answer
  SecondaryTransport := GetOnlineFileTransport(GetOnlineFileCheck(RelDest, Hash, MirrorUrl), OnlineFilesSecondaryState);
  if SecondaryTransport = DownloadTransportNone then
  begin
    if not IsHttpsUrl(MirrorUrl) then
      Log('Other server not used for ' + RelPath + ': ' + MirrorUrl + ' is not https')
    else
      Log('Other server not used for ' + RelPath + ': ' + MirrorUrl + ' (' + OnlineServerStateText(OnlineFilesSecondaryState) + ')');
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
    Transport := OnlineFiles[CopyOf].Transport;
    SecondaryTransport := OnlineFiles[CopyOf].SecondaryTransport;
  end;

  N := GetArrayLength(OnlineFiles);
  SetArrayLength(OnlineFiles, N + 1);
  OnlineFiles[N].Url := Url;
  OnlineFiles[N].SecondaryUrl := MirrorUrl;
  OnlineFiles[N].Transport := Transport;
  OnlineFiles[N].SecondaryTransport := SecondaryTransport;
  OnlineFiles[N].RelPath := RelPath;
  OnlineFiles[N].RelDest := RelDest;
  OnlineFiles[N].SHA256 := Hash;
  OnlineFiles[N].Size := Size;
  OnlineFiles[N].CopyOf := CopyOf;
  OnlineFiles[N].DownloadProblem := 'DownloadFileMissing';
  if Hash <> '' then
    Log('Online file registered, SHA-256 pinned: ' + RelPath)
  else
    Log('Online file registered, TLS-verified, not pinned: ' + RelPath);
end;

// Progress callback of the download page: notes whether the server announced the size of the
// current download (Content-Length), and stops the download of a pinned file as soon as its size
// cannot match the pin (IsDownloadSizeAcceptable, utils.iss: another announced size, more bytes
// than pinned). The page itself logs the progress and processes the stop button. True: go on.
function OnOnlineFileDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax > 0 then
    DownloadSizeAnnounced := True;
  Result := True;
  if CurrentDownloadPinned and not IsDownloadSizeAcceptable(Progress, ProgressMax, CurrentDownloadPinnedSize) then
  begin
    DownloadSizeRejected := True;
    DownloadSizeRejectedNote := 'announced ' + IntToStr(ProgressMax) + ', received ' + IntToStr(Progress) + ' bytes, pinned ' +
      IntToStr(CurrentDownloadPinnedSize);
    Result := False;
  end;
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

// Receives the body of the answered WinHTTP request Request into the open file Dest
// (DownloadPinnedFileWinHttp) in reads of WinHttpReadChunkBytes: DownloadOutcomeSuccess when the
// body is complete, DownloadOutcomeFailure on a read or write error and after the stop button of the
// download page (then DownloadsStoppedByUser is set and nothing more is read),
// DownloadOutcomePinMismatch as soon as more bytes arrive than the pinned size allows
// (IsDownloadSizeAcceptable, utils.iss; Announced is the Content-Length, -1 if none). Before each
// read the page shows the progress; that processes its messages, so the stop button works between
// two reads (a read waits at most WinHttpReceiveTimeoutMs). Received: the bytes written. The
// bytes go to the file unchanged: WinHttpReadData fills an AnsiString, WriteFile writes it.
function ReceivePinnedFile(const Request: Cardinal; const Dest: TFileStream; const Url: String; const Announced, PinnedSize: Int64;
  var Received: Int64): Integer;
var
  Buffer: AnsiString;
  Got, Written: Cardinal;
  Total: Int64;
  Position, Max, NextLogPercent: Integer;
  Done, Ok: Boolean;
begin
  Result := DownloadOutcomeFailure;
  Received := 0;
  Total := PinnedSize;
  if Total <= 0 then
    Total := Announced;
  NextLogPercent := 10;
  Done := False;
  while not Done do
  begin
    // In KiB: TOutputProgressWizardPage.SetProgress takes 32-bit numbers
    Position := 0;
    Max := 0;
    if Total > 0 then
    begin
      Position := Received div 1024;
      Max := Total div 1024 + 1;
    end;
    OnlineFilesDownloadPage.SetProgress(Position, Max);
    if OnlineFilesDownloadPage.AbortedByUser then
    begin
      DownloadsStoppedByUser := True;
      Log('Online file download stopped by the user: ' + Url + ' (' + IntToStr(Received) + ' bytes received)');
      Exit;
    end;
    Buffer := StringOfChar(#0, WinHttpReadChunkBytes);
    Got := 0;
    if not WinHttpReadData(Request, Buffer, WinHttpReadChunkBytes, Got) then
    begin
      Log('Online file download failed from ' + Url + ': ' + DescribeWinHttpError(DLLGetLastError) + ' after ' + IntToStr(Received) + ' bytes');
      Exit;
    end;
    if Got = 0 then
      Done := True
    else
    begin
      Written := 0;
      // BOOL results of DLL functions are assigned to a Boolean before they are combined
      Ok := WriteFile(Dest.Handle, Buffer, Got, Written, 0);
      if not Ok or (Written <> Got) then
      begin
        Log('Online file download failed from ' + Url + ': unable to write the file after ' + IntToStr(Received) + ' bytes (error ' + IntToStr(DLLGetLastError) + ')');
        Exit;
      end;
      Received := Received + Got;
      if not IsDownloadSizeAcceptable(Received, Announced, PinnedSize) then
      begin
        Log('Online file rejected, more than its pinned size of ' + IntToStr(PinnedSize) + ' bytes arrived: ' + Url);
        Result := DownloadOutcomePinMismatch;
        Exit;
      end;
      if (Total > 0) and (NextLogPercent <= 100) and (Received * 100 >= Total * NextLogPercent) then
      begin
        // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
        Log('  ' + IntToStr(Received) + ' of ' + IntToStr(Total) + ' bytes done.');
        while (NextLogPercent <= 100) and (Received * 100 >= Total * NextLogPercent) do
          NextLogPercent := NextLogPercent + 10;
      end;
    end;
  end;
  Result := DownloadOutcomeSuccess;
end;

// The download of a pinned file from a server whose certificate is invalid (ADR 0012): one GET
// request of Url with WinHTTP and the certificate errors of ApplyCertificateErrorIgnoreFlags
// ignored (OpenWinHttpRequest, utils.iss), into {tmp}\<RelDest>.part, kept as {tmp}\<RelDest>
// only if the status is 200, the size is the pinned size (also the announced one, before the body
// is read) and the SHA-256 matches the pin; anything else is deleted. WinHTTP follows redirects
// itself (never from https to http); the pin decides whatever the path. Returns
// DownloadOutcomeSuccess, DownloadOutcomeFailure (network, status, stop button: then
// DownloadsStoppedByUser is set) or DownloadOutcomePinMismatch (size or SHA-256). Raises an
// exception for a file without pin: certificate errors are never ignored for one. No other
// exception escapes.
function DownloadPinnedFileWinHttp(const Index: Integer; const Url: String): Integer;
var
  Session, Connection, Request, AnnouncedSize, SizeLength: Cardinal;
  Target, PartFile, Error, Hash: String;
  Status: Integer;
  Announced, PinnedSize, Received: Int64;
  Dest: TFileStream;
  Started: DWORD;
  HasLength: Boolean;
begin
  if OnlineFiles[Index].SHA256 = '' then
    RaiseException('DownloadPinnedFileWinHttp: ' + OnlineFiles[Index].RelPath + ' has no SHA-256 pin; certificate errors are only ignored for pinned files');
  Result := DownloadOutcomeFailure;
  PinnedSize := OnlineFiles[Index].Size;
  Target := ExpandConstant('{tmp}\' + OnlineFiles[Index].RelDest);
  PartFile := Target + '.part';
  // Like the built-in downloads: no older file stays at the target
  if FileExists(Target) then
    DeleteFile(Target);
  if FileExists(PartFile) then
    DeleteFile(PartFile);
  ForceDirectories(ExtractFileDir(Target));
  // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
  Log('Downloading pinned online file without certificate validation (WinHTTP) from ' + Url + ': ' + Target);
  OnlineFilesDownloadPage.SetText(OnlineFilesDownloadPage.Msg1Label.Caption, Url);
  OnlineFilesDownloadPage.Msg2Label.Visible := True;
  OnlineFilesDownloadPage.ProgressBar.Visible := True;
  OnlineFilesDownloadPage.AbortButton.Visible := True;
  Started := GetTickCount;
  if not OpenWinHttpRequest('GET', Url, True, Session, Connection, Request, Error) then
  begin
    Log('Online file download failed from ' + Url + ': ' + Error);
    Exit;
  end;

  Dest := nil;
  Received := 0;
  try
    try
      Status := SendWinHttpRequest(Request, Error);
      Announced := -1;
      AnnouncedSize := 0;
      SizeLength := 4;
      if Status = 200 then
      begin
        HasLength := WinHttpQueryHeaders(Request, WinHttpQueryContentLength or WinHttpQueryFlagNumber, 0, AnnouncedSize, SizeLength, 0);
        if HasLength then
          Announced := AnnouncedSize;
      end;
      if Status = HttpRequestFailed then
        Log('Online file download failed from ' + Url + ': ' + Error)
      else if Status <> 200 then
        Log('Online file download failed from ' + Url + ': HTTP status ' + IntToStr(Status))
      else if not IsDownloadSizeAcceptable(0, Announced, PinnedSize) then
      begin
        Log('Online file rejected, the server announces ' + IntToStr(Announced) + ' bytes, its pinned size is ' + IntToStr(PinnedSize) + ': ' + Url);
        Result := DownloadOutcomePinMismatch;
      end
      else
      begin
        Dest := TFileStream.Create(PartFile, fmCreate);
        Result := ReceivePinnedFile(Request, Dest, Url, Announced, PinnedSize, Received);
      end;
    except
      Log('Online file download failed from ' + Url + ': ' + GetExceptionMessage);
      Result := DownloadOutcomeFailure;
    end;
  finally
    if Dest <> nil then
      Dest.Free;
    CloseWinHttpRequest(Session, Connection, Request);
  end;

  if Result = DownloadOutcomeSuccess then
  begin
    // The stop came too late to cancel this file: it is complete and kept, but nothing follows
    if OnlineFilesDownloadPage.AbortedByUser then
      DownloadsStoppedByUser := True;
    try
      Hash := LowerCase(GetSHA256OfFile(PartFile));
    except
      Hash := '';
      Log('Unable to hash ' + PartFile + ': ' + GetExceptionMessage);
    end;
    if (PinnedSize >= 0) and (Received <> PinnedSize) then
    begin
      Log('Online file rejected, ' + IntToStr(Received) + ' bytes instead of its pinned size of ' + IntToStr(PinnedSize) + ': ' + Url);
      Result := DownloadOutcomePinMismatch;
    end
    else if Hash <> OnlineFiles[Index].SHA256 then
    begin
      Log('Online file rejected, SHA-256 mismatch: ' + Url + ' (got ' + Hash + ')');
      Result := DownloadOutcomePinMismatch;
    end
    else if RenameFile(PartFile, Target) then
      // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
      Log('Online file downloaded, SHA-256 pinned, transport WinHTTP without certificate validation: ' + Url + ' (' +
        IntToStr(Received) + ' bytes, ' + IntToStr(TicksSince(Started)) + ' ms)')
    else
    begin
      Log('Unable to rename ' + PartFile + ' to ' + Target);
      Result := DownloadOutcomeFailure;
    end;
  end;
  // Only a complete file that matches its pin is left, as {tmp}\<RelDest>
  if FileExists(PartFile) and not DeleteFile(PartFile) then
    Log('Unable to delete ' + PartFile + ' (it is not installed anyway)');
end;

// One download attempt of OnlineFiles[Index] from Url to {tmp}\<RelDest> with the transport
// Transport (DownloadTransport*, from AddOnlineFile): DownloadOutcomeSuccess,
// DownloadOutcomeFailure or DownloadOutcomePinMismatch. DownloadTransportPinnedWinHttp goes to
// DownloadPinnedFileWinHttp; the built-in download requests a file without pin only if
// CheckOnlineFileRedirects allows it (else DownloadOutcomeFailure, so the other server may be
// tried), and stops a pinned file whose size cannot match (OnOnlineFileDownloadProgress, then
// DownloadOutcomePinMismatch). Sets DownloadsStoppedByUser if the user stopped it. No exception
// escapes.
function DownloadOnlineFileFrom(const Index: Integer; const Url: String; const Transport: Integer): Integer;
var
  Target, Hash: String;
begin
  if Transport = DownloadTransportPinnedWinHttp then
  begin
    try
      Result := DownloadPinnedFileWinHttp(Index, Url);
    except
      Result := DownloadOutcomeFailure;
      Log('Online file not downloaded from ' + Url + ': ' + GetExceptionMessage);
    end;
    if Result = DownloadOutcomeSuccess then
      OnlineFilesByWinHttp := OnlineFilesByWinHttp + 1;
    Exit;
  end;
  if Transport <> DownloadTransportBuiltIn then
  begin
    // AddOnlineFile registers no URL without a transport; only a safety net
    Log('Online file not requested from ' + Url + ': no transport allowed for it on that server');
    Result := DownloadOutcomeFailure;
    Exit;
  end;
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
  CurrentDownloadPinned := OnlineFiles[Index].SHA256 <> '';
  CurrentDownloadPinnedSize := OnlineFiles[Index].Size;
  DownloadSizeRejected := False;
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
    else if DownloadSizeRejected then
    begin
      Log('Online file rejected, its size cannot match the pin (' + DownloadSizeRejectedNote + '): ' + Url);
      Result := DownloadOutcomePinMismatch;
    end
    else
      Log('Online file download failed from ' + Url + ': ' + GetExceptionMessage);
  end;
  CurrentDownloadPinned := False;
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
    begin
      // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
      Log('Online file downloaded, SHA-256 pinned: ' + Url);
      OnlineFilesByBuiltIn := OnlineFilesByBuiltIn + 1;
    end
    else
    begin
      Log('Online file rejected, SHA-256 mismatch: ' + Url + ' (got ' + Hash + ')');
      if not DeleteFile(Target) then
        Log('Unable to delete ' + Target + ' (it is not installed anyway)');
      Result := DownloadOutcomePinMismatch;
    end;
  end
  else
  begin
    OnlineFilesByBuiltIn := OnlineFilesByBuiltIn + 1;
    if DownloadSizeAnnounced then
      // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
      Log('Online file downloaded, TLS-verified, size checked: ' + Url)
    else
      // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
      Log('Online file downloaded, TLS-verified, accepted without size check (the server sent no Content-Length): ' + Url);
  end;
end;

// Downloads OnlineFiles[Index]: from its server, then, if NextDownloadAction (utils.iss) says so,
// once from the other server; sets its DownloadProblem
procedure DownloadOnlineFile(const Index: Integer);
var
  Url: String;
  Outcome, Action, Transport: Integer;
  OtherTried, Rejected: Boolean;
begin
  Url := OnlineFiles[Index].Url;
  Transport := OnlineFiles[Index].Transport;
  OtherTried := False;
  Rejected := False;
  repeat
    Outcome := DownloadOnlineFileFrom(Index, Url, Transport);
    if Outcome = DownloadOutcomePinMismatch then
      Rejected := True;
    Action := NextDownloadAction(Outcome, OnlineFiles[Index].SecondaryUrl <> '', OtherTried, DownloadsStoppedByUser);
    case Action of
      DownloadActionAccept:
        OnlineFiles[Index].DownloadProblem := '';
      DownloadActionTryMirror:
        begin
          Url := OnlineFiles[Index].SecondaryUrl;
          Transport := OnlineFiles[Index].SecondaryTransport;
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
          // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
          Log('Online file not downloaded, it failed on both servers: ' + OnlineFiles[Index].RelPath)
        else
          // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
          Log('Online file not downloaded, not retried: the other server is not used for it (see "Other server not used for" above): ' + OnlineFiles[Index].RelPath);
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
  OnlineFilesByBuiltIn := 0;
  OnlineFilesByWinHttp := 0;
  Count := 0;
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
    if OnlineFiles[I].CopyOf < 0 then
      Count := Count + 1;
  if Count = 0 then
    Exit;

  // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
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
          // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
          Log('Online file skipped, downloads stopped by the user: ' + OnlineFiles[I].RelPath);
        end
        else
          try
            DownloadOnlineFile(I);
          except
            OnlineFiles[I].DownloadProblem := 'DownloadFileMissing';
            // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
            Log('Online file not downloaded, unexpected error: ' + GetExceptionMessage);
          end;
      end;
  finally
    OnlineFilesDownloadPage.Hide;
  end;
  // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
  Log('Online files: ' + IntToStr(OnlineFilesByBuiltIn) + ' downloaded with validated TLS (Inno Setup), ' + IntToStr(OnlineFilesByWinHttp) +
    ' pinned ones with WinHTTP without certificate validation, of ' + IntToStr(Count));
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
      // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
      Log('All ' + IntToStr(GetArrayLength(OnlineFiles)) + ' online files accepted');
    Exit;
  end;

  // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
  Log(IntToStr(Missing) + ' of ' + IntToStr(GetArrayLength(OnlineFiles) + GetArrayLength(RefusedOnlineFiles)) + ' selected online files are missing, the setup installs its own files instead:' + Report);
  // A pin mismatch (a file updated on the server after this setup was built, or a damaged or
  // tampered download) is reported like the other cases: the file was discarded, nothing of it is
  // installed
  if not SilentInstall and not SuppressMsgBoxes then
    MsgBox(FmtMessage(CustomMessage('DownloadIncomplete'), [Report]), mbInformation, MB_OK);
end;
