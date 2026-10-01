[Code]
// Online localized files: SHA-256 pins and verification
//
// RegisterOnlineFiles (setup_is6.iss) downloads localized files from the community file servers
// with IDP. A download is only accepted when its SHA-256 matches a hash compiled into this setup:
//  - AddOnlineFile registers a file only if a hash is known for its server path,
//  - VerifyDownloadedFiles (ssInstall, before any file is installed) checks every downloaded file
//    and moves the matching ones to {tmp}\verified\, the only folder [Files] installs them from.
//    A mismatching file is deleted. Every registered file that does not arrive there (download
//    failed or skipped, checksum mismatch) is logged and reported; for it the setup installs the
//    file it contains itself.
//
// The hashes come from a list in sha256sum format ("<SHA-256 in hex>  <path>", one file per line,
// paths relative to the "localized" folder of the file servers, which has the same layout as
// data\localized-text). ISPP 6.2 can only compute MD5 and SHA-1 (GetSHA256OfFile is missing until
// Inno Setup 6.3), so the list is created before compiling: ci\build.ps1 writes it from
// data\localized-text, see README.md "Online localized files". Without the list the setup compiles
// with a warning and never downloads anything.

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
    RelPath: String;  // path below the "localized" folder of the file servers
    SHA256: String;   // lowercase hex
  end;

  TOnlineFile = record
    Url: String;
    RelPath: String;
    RelDest: String;  // download target relative to {tmp}, e.g. EE\Language.dll
    SHA256: String;
    CopyOf: Integer;  // -1, or the entry with the same URL: its verified file is copied to RelDest
  end;

var
  DownloadPins: array of TDownloadPin;
  OnlineFiles: array of TOnlineFile;
  // Server tried first and mirror, see SelectOnlineFilesServer
  OnlineFilesPrimaryURL, OnlineFilesSecondaryURL: String;

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
  #pragma warning "No SHA-256 hashes in " + DownloadHashPath + ": this setup will never download localized files (see README.md, Online localized files)"
#endif

// SHA-256 known for a server path (exact match), '' if none
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

function HasDownloadPins: Boolean;
begin
  Result := GetArrayLength(DownloadPins) > 0;
end;

// Chooses the server the files are downloaded from (OnlineFilesURL and OnlineFilesMirrorURL,
// setup_is6.iss): the main server, or the mirror if only the mirror answers (the other one stays
// registered as IDP mirror). With realistic timeouts, an unreachable main server would otherwise
// delay every single file. False if neither answers.
function SelectOnlineFilesServer: Boolean;
begin
  Result := True;
  if SendRequest(OnlineFilesURL, False) <> -1 then
  begin
    OnlineFilesPrimaryURL := OnlineFilesURL;
    OnlineFilesSecondaryURL := OnlineFilesMirrorURL;
  end
  else if SendRequest(OnlineFilesMirrorURL, False) <> -1 then
  begin
    Log('Main online files server unreachable, downloading from the mirror first');
    OnlineFilesPrimaryURL := OnlineFilesMirrorURL;
    OnlineFilesSecondaryURL := OnlineFilesURL;
  end
  else
    Result := False;
end;

procedure ClearOnlineFiles;
begin
  idpClearFiles();
  SetArrayLength(OnlineFiles, 0);
end;

// Registers the download of <server>/RelPath to {tmp}\RelDest, but only if its SHA-256 is known
// and no other file is registered for RelDest yet. The caller registers only what is selected
// (IDP would download a file if any one of its components is selected). Call
// SelectOnlineFilesServer first. True if the file is registered.
function AddOnlineFile(const RelPath, RelDest: String): Boolean;
var
  I, N, CopyOf: Integer;
  Hash, Url: String;
begin
  Result := False;
  Hash := GetDownloadPin(RelPath);
  if Hash = '' then
  begin
    Log('Online file skipped, no SHA-256 known for ' + RelPath);
    Exit;
  end;

  CopyOf := -1;
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
  begin
    if CompareText(OnlineFiles[I].RelDest, RelDest) = 0 then
    begin
      Log('Online file skipped, ' + RelDest + ' is already downloaded from ' + OnlineFiles[I].RelPath);
      Exit;
    end;
    if (OnlineFiles[I].RelPath = RelPath) and (OnlineFiles[I].CopyOf < 0) then
      CopyOf := I;
  end;

  if CopyOf < 0 then
  begin
    Url := OnlineFilesPrimaryURL + '/' + RelPath;
    idpAddFile(Url, ExpandConstant('{tmp}\' + RelDest));
    idpAddMirror(Url, OnlineFilesSecondaryURL + '/' + RelPath);
  end
  else
    // IDP downloads a URL only once and ignores a second target for it (checked with idp.dll
    // 1.6.0), so a file needed in both game folders is downloaded once and copied
    Url := OnlineFiles[CopyOf].Url;

  N := GetArrayLength(OnlineFiles);
  SetArrayLength(OnlineFiles, N + 1);
  OnlineFiles[N].Url := Url;
  OnlineFiles[N].RelPath := RelPath;
  OnlineFiles[N].RelDest := RelDest;
  OnlineFiles[N].SHA256 := Hash;
  OnlineFiles[N].CopyOf := CopyOf;
  Result := True;
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
// the custom message that describes the problem
function VerifyOnlineFile(const OnlineFile: TOnlineFile): String;
var
  Source, Target, Hash: String;
begin
  Source := ExpandConstant('{tmp}\' + OnlineFile.RelDest);
  Target := ExpandConstant('{tmp}\verified\' + OnlineFile.RelDest);

  if not idpFileDownloaded(OnlineFile.Url) or not FileExists(Source) then
  begin
    Log('Online file not downloaded: ' + OnlineFile.RelPath);
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

  // Only a file with the expected SHA-256 is moved to the verified folder
  Result := 'DownloadFileRejected';
  if Hash <> OnlineFile.SHA256 then
    Log('Online file rejected, SHA-256 mismatch: ' + OnlineFile.RelPath + ' (got ' + Hash + ')')
  else if ForceDirectories(ExtractFileDir(Target)) and RenameFile(Source, Target) then
  begin
    Log('Online file verified: ' + OnlineFile.RelPath + ' (SHA-256 ' + Hash + ')');
    Result := '';
  end
  else
    Log('Unable to move the verified file ' + Source + ' to ' + Target);

  if (Result <> '') and FileExists(Source) and not DeleteFile(Source) then
    Log('Unable to delete ' + Source + ' (it is not installed anyway)');
end;

// Checks every downloaded file against its SHA-256 and moves the matching ones to
// {tmp}\verified\<RelDest>, copies files needed in both game folders, then reports every
// registered file that is not there, so the player knows which localized content stays as the
// setup installs it itself (some of it in English). Must run before [Files] is processed
// (ssInstall).
procedure VerifyDownloadedFiles;
var
  I, Missing: Integer;
  Problem: array of String;
  Target, Report: String;
  Rejected: Boolean;
begin
  // [Files] installs from these folders, so they have to exist even if nothing was downloaded
  ForceDirectories(ExpandConstant('{tmp}\verified\EE'));
  ForceDirectories(ExpandConstant('{tmp}\verified\AoC'));

  SetArrayLength(Problem, GetArrayLength(OnlineFiles));
  Missing := 0;
  Report := '';
  Rejected := False;
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
          Problem[I] := 'DownloadFileRejected';
        end;
    end;

    if Problem[I] <> '' then
    begin
      Missing := Missing + 1;
      if Problem[I] = 'DownloadFileRejected' then
        Rejected := True;
      Report := Report + #13#10 + '  ' + FmtMessage(CustomMessage(Problem[I]), [OnlineFileDisplayName(OnlineFiles[I].RelDest)]);
    end;
  end;

  if Missing = 0 then
  begin
    if GetArrayLength(OnlineFiles) > 0 then
      Log('All ' + IntToStr(GetArrayLength(OnlineFiles)) + ' online files verified');
    Exit;
  end;

  Log(IntToStr(Missing) + ' of ' + IntToStr(GetArrayLength(OnlineFiles)) + ' online files are missing, the setup installs its own files instead:' + Report);
  if SilentInstall or SuppressMsgBoxes then
    Exit;
  // An error if a file did not match its checksum (damaged or tampered with), else a notice
  if Rejected then
    MsgBox(FmtMessage(CustomMessage('DownloadIncomplete'), [Report]), mbError, MB_OK)
  else
    MsgBox(FmtMessage(CustomMessage('DownloadIncomplete'), [Report]), mbInformation, MB_OK);
end;
