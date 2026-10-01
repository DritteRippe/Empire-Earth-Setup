[Code]
// Online localized files: SHA-256 pins and verification
//
// RegisterOnlineFiles (setup_is6.iss) downloads localized files from the community file servers
// with IDP. A download is only accepted when its SHA-256 matches a hash compiled into this setup:
//  - AddOnlineFile registers a file only if a hash is known for its server path,
//  - VerifyDownloadedFiles (ssInstall, before any file is installed) checks every downloaded file
//    and moves the matching ones to {tmp}\verified\, the only folder [Files] installs them from.
//    A mismatching file is deleted, logged and reported like a failed download; the setup then
//    keeps the files it contains itself.
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
  end;

var
  DownloadPins: array of TDownloadPin;
  OnlineFiles: array of TOnlineFile;

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

function OnlineFilesURL: String;
begin
  Result := 'https://files.' + DomainMain + '/localized';
end;

function OnlineFilesMirrorURL: String;
begin
  Result := 'https://storage.' + DomainMirror + '/localized';
end;

procedure ClearOnlineFiles;
begin
  idpClearFiles();
  SetArrayLength(OnlineFiles, 0);
end;

// Registers a download of OnlineFilesURL/RelPath (mirror: OnlineFilesMirrorURL/RelPath) to
// {tmp}\RelDest for the given components, but only if its SHA-256 is known
procedure AddOnlineFile(const RelPath, RelDest, Components: String);
var
  I, N: Integer;
  Hash, Url: String;
  KnownUrl: Boolean;
begin
  Hash := GetDownloadPin(RelPath);
  if Hash = '' then
  begin
    Log('Online file skipped, no SHA-256 known for ' + RelPath);
    Exit;
  end;

  Url := OnlineFilesURL + '/' + RelPath;
  KnownUrl := False;
  for I := 0 to GetArrayLength(OnlineFiles) - 1 do
    if OnlineFiles[I].Url = Url then
      KnownUrl := True;

  idpAddFileComp(Url, ExpandConstant('{tmp}\' + RelDest), Components);
  if not KnownUrl then
    idpAddMirror(Url, OnlineFilesMirrorURL + '/' + RelPath);

  N := GetArrayLength(OnlineFiles);
  SetArrayLength(OnlineFiles, N + 1);
  OnlineFiles[N].Url := Url;
  OnlineFiles[N].RelPath := RelPath;
  OnlineFiles[N].RelDest := RelDest;
  OnlineFiles[N].SHA256 := Hash;
end;

// Checks every downloaded file against the SHA-256 of the server path(s) it was downloaded from
// (EE and NeoEE files can share a target, e.g. EE\Language.dll) and moves the matching ones to
// {tmp}\verified\<RelDest>. Must run before [Files] is processed (ssInstall).
procedure VerifyDownloadedFiles;
var
  I, J, Rejected: Integer;
  Source, Target, Hash, RejectedList: String;
  Done: TStringList;
  Downloaded, Matches: Boolean;
begin
  // [Files] installs from these folders, so they have to exist even if nothing was downloaded
  ForceDirectories(ExpandConstant('{tmp}\verified\EE'));
  ForceDirectories(ExpandConstant('{tmp}\verified\AoC'));

  Rejected := 0;
  RejectedList := '';
  Done := TStringList.Create;
  try
    for I := 0 to GetArrayLength(OnlineFiles) - 1 do
    begin
      if Done.IndexOf(OnlineFiles[I].RelDest) >= 0 then
        Continue;
      Done.Add(OnlineFiles[I].RelDest);

      Source := ExpandConstant('{tmp}\' + OnlineFiles[I].RelDest);
      Target := ExpandConstant('{tmp}\verified\' + OnlineFiles[I].RelDest);
      if not FileExists(Source) then
        Continue;

      // Not downloaded (failed, skipped or not selected): IDP already reported failures
      Downloaded := False;
      for J := I to GetArrayLength(OnlineFiles) - 1 do
        if OnlineFiles[J].RelDest = OnlineFiles[I].RelDest then
          if idpFileDownloaded(OnlineFiles[J].Url) then
            Downloaded := True;
      if not Downloaded then
      begin
        Log('Online file not downloaded, ignored: ' + OnlineFiles[I].RelDest);
        DeleteFile(Source);
        Continue;
      end;

      try
        Hash := LowerCase(GetSHA256OfFile(Source));
      except
        Hash := '';
        Log('Unable to hash ' + Source + ': ' + GetExceptionMessage);
      end;

      Matches := False;
      if Hash <> '' then
        for J := I to GetArrayLength(OnlineFiles) - 1 do
          if (OnlineFiles[J].RelDest = OnlineFiles[I].RelDest) and (OnlineFiles[J].SHA256 = Hash) then
          begin
            Matches := True;
            Log('Online file verified: ' + OnlineFiles[J].RelPath + ' (SHA-256 ' + Hash + ')');
          end;

      // Nested on purpose: an unverified file must never reach the verified folder
      if Matches then
      begin
        if ForceDirectories(ExtractFileDir(Target)) then
          if RenameFile(Source, Target) then
            Continue;
        Log('Unable to move the verified file ' + Source + ' to ' + Target);
      end else
        Log('Online file rejected, SHA-256 mismatch: ' + OnlineFiles[I].RelDest + ' (got ' + Hash + ')');

      if not DeleteFile(Source) then
        Log('Unable to delete ' + Source + ' (it is not installed anyway)');
      Rejected := Rejected + 1;
      RejectedList := RejectedList + #13#10 + OnlineFiles[I].RelDest;
    end;
  finally
    Done.Free;
  end;

  if (Rejected > 0) and not SilentInstall and not SuppressMsgBoxes then
    MsgBox(FmtMessage(CustomMessage('DownloadVerificationFailed'), [IntToStr(Rejected), RejectedList]), mbError, MB_OK);
end;
