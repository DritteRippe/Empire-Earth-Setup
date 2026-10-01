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
// versions); the player is told where they are. Without list and old folder (new installation,
// reinstallation after uninstalling) all files already in the folder count as the player's.
// Uses: SetupDataDir, AppID (setup_is6.iss), SilentInstall, SuppressMsgBoxes (extention.iss).

type
  TRmsFolder = record
    Id: String;             // EE or AoC, names the list file
    Game: String;           // game folder below {app}
    Before: TStringList;    // files in the folder before [Files], relative to it
    BackupDir: String;      // old folder moved aside, '' if none
  end;

var
  RmsFolders: array of TRmsFolder;

function RmsDir(const Game: String): String;
begin
  Result := ExpandConstant('{app}\') + Game + '\Data\Random Map Scripts';
end;

function RmsListFile(const Id: String): String;
begin
  Result := ExpandConstant('{app}\{#SetupDataDir}\rms-') + Id + '.txt';
end;

// Adds the files below Dir\RelDir to List, as paths relative to Dir (RelDir: '' or 'Sub\')
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
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          AddRmsFiles(Dir, RelDir + FindRec.Name + '\', List)
        else
          List.Add(RelDir + FindRec.Name);
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

// Removes the empty subfolders of Dir (deepest first), then Dir itself if it is empty
procedure RemoveEmptyRmsDirs(const Dir: String);
var
  FindRec: TFindRec;
begin
  if FindFirst(Dir + '\*', FindRec) then
  try
    repeat
      if (FindRec.Name <> '.') and (FindRec.Name <> '..') and
         ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) then
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

procedure PrepareRmsFolder(const Index: Integer);
var
  Dir, OldFile: String;
  Listed: TArrayOfString;
  I: Integer;
begin
  Dir := RmsDir(RmsFolders[Index].Game);
  RmsFolders[Index].Before := TStringList.Create;
  RmsFolders[Index].BackupDir := '';
  if not DirExists(Dir) then
    Exit;

  if LoadStringsFromFile(RmsListFile(RmsFolders[Index].Id), Listed) then
  begin
    // Files the previous setup installed: deleted, so maps this setup no longer ships disappear
    for I := 0 to GetArrayLength(Listed) - 1 do
    begin
      OldFile := Dir + '\' + Listed[I];
      if not IsRmsListEntrySafe(Listed[I]) then
        Log('RMS: ignored list entry ' + Listed[I])
      else if FileExists(OldFile) and not DeleteFile(OldFile) then
        Log('RMS: unable to delete ' + OldFile);
    end;
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
  Dir := RmsDir(RmsFolders[Index].Game);
  BackupDir := RmsFolders[Index].BackupDir;
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
    Files.Clear;
    AddRmsFiles(BackupDir, '', Files);
    for I := 0 to Files.Count - 1 do
      if FileExists(Dir + '\' + Files[I]) then
        DeleteFile(BackupDir + '\' + Files[I]);
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

// ssInstall, before [Files]
procedure PrepareRandomMapScripts;
var
  I: Integer;
begin
  SetArrayLength(RmsFolders, 1);
  RmsFolders[0].Id := 'EE';
  RmsFolders[0].Game := 'Empire Earth';
  // A folder of a game that is not (re)installed now is left alone, with its list
  if WizardIsComponentSelected('gameaoc') then
  begin
    SetArrayLength(RmsFolders, 2);
    RmsFolders[1].Id := 'AoC';
    RmsFolders[1].Game := 'Empire Earth - The Art of Conquest';
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
