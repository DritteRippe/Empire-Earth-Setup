[Code]
// Random Map Scripts (RMS)
//
// Setups up to v1.7.2 deleted the whole Data\Random Map Scripts folders on every installation,
// repair or update ([InstallDelete]) to get rid of maps a newer setup no longer ships. That also
// deleted the maps players made or downloaded themselves. Now only files a setup installed are
// removed:
//  - ssPostInstall (FinishRandomMapScripts) lists the files that are in the folder now but were
//    not there before [Files] ran, i.e. the ones this setup installed, in
//    {app}\{#SetupDataDir}\rms-<EE|AoC>.txt,
//  - the next installation (PrepareRandomMapScripts, ssInstall, before [Files]) deletes the files
//    of that list. Every other file in the folder is the player's and stays.
// An installation made by a setup up to v1.7.2 has no list (it is recognized by its old setup
// data folder {app}\<AppId>). There the folder is moved aside once, the setup installs a clean
// one, and only the files it does not install again stay in the backup (own maps, maps of older
// versions); the player is told where they are. If the installation is cancelled or fails after
// that, DeinitializeSetup (RestoreRandomMapScripts) puts the folder back. Without list and old
// folder (new installation, reinstallation after uninstalling) all files already in the folder
// count as the player's.
//
// The Data folders are writable for all users (see [Dirs]), but this code runs elevated. So it
// never follows a junction or symbolic link (reparse point): a random map folder that is one is
// left alone, reparse points inside it are neither listed nor entered, and a file is only deleted
// if no folder on its way is one. Otherwise a user could make the setup delete files or empty
// folders anywhere, or loop endlessly through a link to a parent folder.
// Requires: SetupDataDir, AppID, EEDir, AoCDir, RmsSubDir (ISPP, setup_is6.iss), SilentInstall,
// SuppressMsgBoxes (extension.iss), the messages RmsBackupKept, RmsBackupNotRestored
// (messages.iss).

type
  TRmsFolder = record
    Id: String;             // EE or AoC, names the list file
    Game: String;           // game folder below {app}
    Dir: String;            // the random map folder
    Skipped: Boolean;       // the folder is a reparse point: not touched at all
    Before: TStringList;    // files in the folder before [Files], relative to it
    BackupDir: String;      // old folder moved aside, '' if none
  end;

var
  // Prepared at ssInstall, emptied at ssPostInstall: entries left at DeinitializeSetup belong to
  // an installation that did not complete
  RmsFolders: array of TRmsFolder;

function RmsDir(const Game: String): String;
begin
  Result := ExpandConstant('{app}\') + Game + '\{#RmsSubDir}';
end;

function RmsListFile(const Id: String): String;
begin
  Result := ExpandConstant('{app}\{#SetupDataDir}\rms-') + Id + '.txt';
end;

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

// True if neither Dir nor a folder between Dir and the file Dir\RelPath is a reparse point
function IsRmsPathSafe(const Dir, RelPath: String): Boolean;
var
  I: Integer;
begin
  Result := not IsReparsePoint(Dir);
  for I := 1 to Length(RelPath) do
    if Result and (RelPath[I] = '\') then
      Result := not IsReparsePoint(Dir + '\' + Copy(RelPath, 1, I - 1));
end;

// Adds the files below Dir\RelDir to List, as paths relative to Dir (RelDir: '' or 'Sub\').
// Reparse points are skipped (not listed, not entered).
procedure AddRmsFiles(const Dir, RelDir: String; List: TStringList);
var
  FindRec: TFindRec;
begin
  if not FindFirst(Dir + '\' + RelDir + '*', FindRec) then
    Exit;
  try
    repeat
      if (FindRec.Name <> '.') and (FindRec.Name <> '..') then
      begin
        if (FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
          Log('RMS: reparse point skipped: ' + Dir + '\' + RelDir + FindRec.Name)
        else if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          AddRmsFiles(Dir, RelDir + FindRec.Name + '\', List)
        else
          List.Add(RelDir + FindRec.Name);
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

// Removes the empty subfolders of Dir (deepest first), then Dir itself if it is empty. Reparse
// points are neither entered nor removed. Call it only for a Dir that is no reparse point.
procedure RemoveEmptyRmsDirs(const Dir: String);
var
  FindRec: TFindRec;
begin
  if FindFirst(Dir + '\*', FindRec) then
  try
    repeat
      if (FindRec.Name <> '.') and (FindRec.Name <> '..') and
         ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
         ((FindRec.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0) then
        RemoveEmptyRmsDirs(Dir + '\' + FindRec.Name);
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
  RemoveDir(Dir);
end;

// A list entry may only name a file inside the folder
function IsRmsListEntrySafe(const RelPath: String): Boolean;
begin
  Result := (RelPath <> '') and (Pos('..', RelPath) = 0) and (Pos(':', RelPath) = 0) and
    (Pos('/', RelPath) = 0) and (Copy(RelPath, 1, 1) <> '\');
end;

// Deletes Dir\RelPath unless a folder on its way is a reparse point
procedure DeleteRmsFile(const Dir, RelPath: String);
var
  FileName: String;
begin
  FileName := Dir + '\' + RelPath;
  if not IsRmsPathSafe(Dir, RelPath) then
    Log('RMS: not deleted, reparse point on the way to ' + FileName)
  else if FileExists(FileName) and not DeleteFile(FileName) then
    Log('RMS: unable to delete ' + FileName);
end;

procedure PrepareRmsFolder(const Index: Integer);
var
  Dir: String;
  Listed: TArrayOfString;
  I: Integer;
begin
  Dir := RmsDir(RmsFolders[Index].Game);
  RmsFolders[Index].Dir := Dir;
  RmsFolders[Index].Before := TStringList.Create;
  RmsFolders[Index].BackupDir := '';
  RmsFolders[Index].Skipped := IsReparsePoint(Dir);
  if RmsFolders[Index].Skipped then
  begin
    Log('RMS: ' + Dir + ' is a junction or link, left as it is');
    Exit;
  end;
  if not DirExists(Dir) then
    Exit;

  if LoadStringsFromFile(RmsListFile(RmsFolders[Index].Id), Listed) then
  begin
    // Files the previous setup installed: deleted, so maps this setup no longer ships disappear
    for I := 0 to GetArrayLength(Listed) - 1 do
      if IsRmsListEntrySafe(Listed[I]) then
        DeleteRmsFile(Dir, Listed[I])
      else
        Log('RMS: ignored list entry ' + Listed[I]);
  end
  else if DirExists(ExpandConstant('{app}\{#AppID}')) then
  begin
    // Installed by a setup up to v1.7.2: which files are the player's is unknown
    RmsFolders[Index].BackupDir := Dir + ' (backup ' + GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', '-') + ')';
    if RenameFile(Dir, RmsFolders[Index].BackupDir) then
    begin
      Log('RMS: folder of an older setup moved to ' + RmsFolders[Index].BackupDir);
      Exit;
    end;
    Log('RMS: unable to move ' + Dir + ' aside, its files are kept as they are');
    RmsFolders[Index].BackupDir := '';
  end;

  AddRmsFiles(Dir, '', RmsFolders[Index].Before);
  Log('RMS: ' + IntToStr(RmsFolders[Index].Before.Count) + ' file(s) of the player kept in ' + Dir);
end;

procedure FinishRmsFolder(const Index: Integer);
var
  Dir, BackupDir: String;
  Files, Installed: TStringList;
  Lines: TArrayOfString;
  I: Integer;
begin
  Dir := RmsFolders[Index].Dir;
  BackupDir := RmsFolders[Index].BackupDir;
  if RmsFolders[Index].Skipped or IsReparsePoint(Dir) then
  begin
    Log('RMS: ' + Dir + ' is a junction or link, no list written');
    Exit;
  end;
  Files := TStringList.Create;
  Installed := TStringList.Create;
  try
    // The files this setup installed: in the folder now, but not before [Files]
    AddRmsFiles(Dir, '', Files);
    for I := 0 to Files.Count - 1 do
      if RmsFolders[Index].Before.IndexOf(Files[I]) < 0 then
        Installed.Add(Files[I]);
    SetArrayLength(Lines, Installed.Count);
    for I := 0 to Installed.Count - 1 do
      Lines[I] := Installed[I];
    if ForceDirectories(ExtractFileDir(RmsListFile(RmsFolders[Index].Id))) and
       SaveStringsToUTF8File(RmsListFile(RmsFolders[Index].Id), Lines, False) then
      Log('RMS: ' + IntToStr(Installed.Count) + ' installed file(s) listed for the next update')
    else
      Log('RMS: unable to write ' + RmsListFile(RmsFolders[Index].Id));

    if BackupDir = '' then
      Exit;
    // Backup of an older setup's folder: keep only what this setup did not install again
    if IsReparsePoint(BackupDir) then
    begin
      Log('RMS: ' + BackupDir + ' is a junction or link now, left as it is');
      Exit;
    end;
    Files.Clear;
    AddRmsFiles(BackupDir, '', Files);
    for I := 0 to Files.Count - 1 do
      if FileExists(Dir + '\' + Files[I]) then
        DeleteRmsFile(BackupDir, Files[I]);
    RemoveEmptyRmsDirs(BackupDir);
    if not DirExists(BackupDir) then
    begin
      Log('RMS: the backup held no other files, removed');
      Exit;
    end;
    Log('RMS: files not installed by this setup kept in ' + BackupDir);
    if not SilentInstall and not SuppressMsgBoxes then
      MsgBox(FmtMessage(CustomMessage('RmsBackupKept'), [BackupDir, Dir]), mbInformation, MB_OK);
  finally
    Files.Free;
    Installed.Free;
  end;
end;

// The installation did not complete (cancelled or failed after ssInstall, the files of [Files]
// are rolled back): a folder moved aside goes back to its place, so the player's maps are where
// they were. Only if the folder is gone or empty (rollback removes installed files and the
// folders it created); else the player is told where the maps are.
procedure RestoreRmsFolder(const Index: Integer);
var
  Dir, BackupDir: String;
begin
  Dir := RmsFolders[Index].Dir;
  BackupDir := RmsFolders[Index].BackupDir;
  if BackupDir = '' then
    Exit;
  if DirExists(Dir) and not IsReparsePoint(Dir) then
    RemoveEmptyRmsDirs(Dir);
  if not DirExists(Dir) and not IsReparsePoint(Dir) and RenameFile(BackupDir, Dir) then
  begin
    Log('RMS: installation not completed, ' + BackupDir + ' moved back to ' + Dir);
    Exit;
  end;
  Log('RMS: installation not completed, unable to move ' + BackupDir + ' back to ' + Dir);
  if not SilentInstall and not SuppressMsgBoxes then
    MsgBox(FmtMessage(CustomMessage('RmsBackupNotRestored'), [BackupDir, Dir]), mbInformation, MB_OK);
end;

// ssInstall, before [Files]
procedure PrepareRandomMapScripts;
var
  I: Integer;
begin
  SetArrayLength(RmsFolders, 1);
  RmsFolders[0].Id := 'EE';
  RmsFolders[0].Game := '{#EEDir}';
  // A folder of a game that is not (re)installed now is left alone, with its list
  if WizardIsComponentSelected('gameaoc') then
  begin
    SetArrayLength(RmsFolders, 2);
    RmsFolders[1].Id := 'AoC';
    RmsFolders[1].Game := '{#AoCDir}';
  end;
  for I := 0 to GetArrayLength(RmsFolders) - 1 do
    PrepareRmsFolder(I);
end;

// ssPostInstall
procedure FinishRandomMapScripts;
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(RmsFolders) - 1 do
  begin
    FinishRmsFolder(I);
    RmsFolders[I].Before.Free;
  end;
  SetArrayLength(RmsFolders, 0);
end;

// DeinitializeSetup: only does something if ssInstall was reached but not ssPostInstall
procedure RestoreRandomMapScripts;
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(RmsFolders) - 1 do
  begin
    RestoreRmsFolder(I);
    RmsFolders[I].Before.Free;
  end;
  SetArrayLength(RmsFolders, 0);
end;
