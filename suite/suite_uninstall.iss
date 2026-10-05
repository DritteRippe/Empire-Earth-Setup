[Code]
// The uninstaller of the suite (ADR 0013 decision 11, contract 0 "Suite and launcher"). It removes exactly
// what the suite installed and nothing else:
//   InitializeUninstall   stops while a game or the launcher runs or another suite setup runs, holds the
//                         suite mutex, and asks ONE question that lists what is removed
//   usUninstall           runs the uninstaller of each product the suite record lists and that is still
//                         installed (NeoEE, then EE), one after the other, and waits for each one
//   usPostUninstall       the shortcuts and the record of the suite (suite_shortcuts.iss, suite_record.iss),
//                         the launcher's settings and log of the account that uninstalls, then, only after
//                         the answer "Delete", the exact folders with user data; Inno Setup removes the files
//                         of the launcher, the Mod Creator and {app}\Logs ([UninstallDelete]) itself
// A silent uninstallation (/SILENT, /VERYSILENT) asks nothing, shows nothing and keeps every user data
// folder. Nothing here touches the registry keys of the games (the product uninstallers do their own
// cleanup, setup_is6.iss) or the keys of the CD key registration; the only registry deletion of the suite is
// RemoveSuiteRecord. ci/check_suite.py reads this file for the rules that keep it that way.
// Limitation: with a standard user who confirms the elevation prompt with the credentials of an
// administrator ("over the shoulder"), {localappdata} is the profile of that administrator, so the settings
// and the backups of the launcher of the standard user stay (README, docs/TEST-PLAN.de.md).
// Requires: SuiteMutexes (suite.iss), SuiteProductAppIdOf, SuiteProductTitle (suite_run.iss), SuiteProductRoot
// (suite_shortcuts.iss), the helpers of suite_common.iss, the define SuiteRecordKey.

const
  // The setup mutex of the suite ([Setup] SetupMutex, contract 0): its uninstaller holds it too, so a launcher
  // sees that a setup is running (contract 4.2). ci/check_suite.py compares it with [Setup] SetupMutex.
  SuiteSetupMutexName = 'EmpireEarthCommunity_Suite';

var
  // Slot 1 is NeoEE, slot 2 is EE (SuiteUninstallProduct). Wanted: the suite record lists the product and it
  // is installed for all users; Root: its install root, read before its uninstall key is gone; Done: it is
  // gone after the removal, so its data folders may be offered for deletion.
  SuiteUninstallWanted, SuiteUninstallDone: array[1..2] of Boolean;
  SuiteUninstallRoot: array[1..2] of String;

// A message of the uninstaller; never in a silent run (the log tells)
procedure SuiteUninstallMessage(const Text: String);
begin
  if not UninstallSilent then
    SuppressibleMsgBox(Text, mbError, MB_OK, IDOK);
end;

// The uninstall entry of a product (HKLM, which is the 64-bit view like the one the suite wrote): its install
// root and the program file of its uninstaller. False if the product has no uninstall key (not installed for
// all users, or removed already).
function SuiteReadProductEntry(const Product: String; var Root, Exe: String): Boolean;
var
  Key, Value: String;
begin
  Result := False;
  Root := '';
  Exe := '';
  Key := SuiteUninstallKey(SuiteProductAppIdOf(Product));
  if not RegKeyExists(HKLM, Key) then
    Exit;
  Root := SuiteProductRoot(Product);
  Value := '';
  if RegQueryStringValue(HKLM, Key, 'UninstallString', Value) then
    Exe := SuiteUninstallExe(Value);
  Result := True;
end;

function InitializeUninstall(): Boolean;
var
  Recorded, Items, Root, Exe, Product: String;
  I: Integer;
begin
  Result := True;
  Log('Suite uninstaller {#SuiteVersion} (contract {#ContractVersion})');
  // 1. A game or the launcher runs: stop before anything is removed
  if CheckForMutexes(SuiteMutexes) then
  begin
    Log('Uninstall stopped: a game or the launcher is running (mutex of ' + SuiteMutexes + ')');
    SuiteUninstallMessage(CustomMessage('SuiteUninstallRunning'));
    Result := False;
    Exit;
  end;
  // 2. One setup or uninstallation of the suite at a time; this one holds the mutex until its process ends
  if CheckForMutexes(SuiteSetupMutexName) then
  begin
    Log('Uninstall stopped: another setup or uninstallation of the suite runs (mutex ' + SuiteSetupMutexName + ')');
    SuiteUninstallMessage(CustomMessage('SuiteUninstallBusy'));
    Result := False;
    Exit;
  end;
  CreateMutex(SuiteSetupMutexName);

  // 3. The products to remove: those the suite record lists and that are still installed
  Recorded := '';
  RegQueryStringValue(HKLM, '{#SuiteRecordKey}', 'Products', Recorded);
  Log('Suite record lists the products "' + Recorded + '"');
  for I := 1 to 2 do
  begin
    Product := SuiteUninstallProduct(I);
    SuiteUninstallWanted[I] := False;
    SuiteUninstallDone[I] := False;
    SuiteUninstallRoot[I] := '';
    if SuiteListHasItem(Recorded, Product) then
    begin
      if SuiteReadProductEntry(Product, Root, Exe) then
      begin
        SuiteUninstallWanted[I] := True;
        SuiteUninstallRoot[I] := Root;
        Log('Product ' + Product + ' is installed in ' + Root + ' (uninstaller ' + Exe + '): it will be removed');
      end
      else
        Log('Product ' + Product + ' is listed but not installed any more (removed through its own entry in Apps): nothing to remove');
    end
    else
      Log('Product ' + Product + ' is not listed by the suite: it is not touched');
  end;

  // 4. The one confirmation, with the list of what is removed (a silent run does not ask)
  if not UninstallSilent then
  begin
    Items := '';
    if FileExists(ExpandConstant('{app}\{#LauncherExe}')) then
      Items := Items + '- ' + FmtMessage(CustomMessage('SuiteUninstallItemLauncher'), [RemoveBackslash(ExpandConstant('{app}'))]) + #13#10;
    for I := 2 downto 1 do
      if SuiteUninstallWanted[I] then
        Items := Items + '- ' + FmtMessage(CustomMessage('SuiteUninstallItemProduct'), [SuiteProductTitle(SuiteUninstallProduct(I)),
          SuiteUninstallRoot[I]]) + #13#10;
    Items := Items + '- ' + CustomMessage('SuiteUninstallItemShortcuts') + #13#10;
    if SuppressibleMsgBox(FmtMessage(CustomMessage('SuiteUninstallConfirm'), [Items]), mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDYES) <> IDYES then
    begin
      Log('Uninstall cancelled by the user at the confirmation');
      Result := False;
    end;
  end;
end;

// The status line and the progress bar of the uninstall window; nothing happens if there is none (/VERYSILENT)
procedure SuiteUninstallStatus(const Text: String; Marquee: Boolean);
begin
  if Text <> '' then
    Log(Text);
  try
    UninstallProgressForm.StatusLabel.Caption := Text;
    if Marquee then
      UninstallProgressForm.ProgressBar.Style := npbstMarquee
    else
      UninstallProgressForm.ProgressBar.Style := npbstNormal;
  except
  end;
end;

// A pause of about a second that keeps the window of the uninstaller alive: Exec with ewWaitUntilTerminated
// processes its messages (WP0 spike, ADR 0013 Evidence), Sleep does not. ping needs no network for the loopback
// address; if it cannot be run the pause is a Sleep.
procedure SuitePause;
var
  Code: Integer;
begin
  if not Exec(ExpandConstant('{sys}\ping.exe'), '-n 2 127.0.0.1', '', SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then
    Sleep(SuiteUninstallPollMs);
end;

// Removes one product with its own uninstaller and waits until it is really done. The exit code of the first
// process decides nothing: it only starts a copy of itself in %TEMP% and ends, so the suite polls the uninstall
// key and the program file (WP0 spike) up to the timeout. Returns SuiteRemoveOk, SuiteRemoveGone (already
// removed: skipped silently), SuiteRemoveNotStarted or SuiteRemoveTimedOut.
function SuiteRemoveProduct(const Product: String): Integer;
var
  Root, Exe, Key: String;
  Started, KeyPresent: Boolean;
  Code, Elapsed, KeyGone, State: Integer;
begin
  Key := SuiteUninstallKey(SuiteProductAppIdOf(Product));
  if not SuiteReadProductEntry(Product, Root, Exe) then
  begin
    Log('Product ' + Product + ' is gone already (removed through its own entry in Apps): skipped');
    Result := SuiteRemoveGone;
    Exit;
  end;
  if not SuiteIsProductUninstaller(Exe, Root) or not FileExists(Exe) then
  begin
    Log('Product ' + Product + ' has no usable uninstaller: "' + Exe + '" (install root "' + Root + '")');
    Result := SuiteRemoveNotStarted;
    Exit;
  end;
  Started := Exec(Exe, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, Code);
  if not Started then
  begin
    Log('Product ' + Product + ': ' + Exe + ' could not be started: ' + SysErrorMessage(Code));
    Result := SuiteRemoveNotStarted;
    Exit;
  end;
  Log('Product ' + Product + ': the first uninstaller process ended with exit code ' + IntToStr(Code) + ', waiting for the real uninstallation');
  Elapsed := 0;
  KeyGone := 0;
  repeat
    KeyPresent := RegKeyExists(HKLM, Key);
    if KeyPresent then
      KeyGone := 0;
    State := SuiteUninstallWaitState(KeyPresent, FileExists(Exe), Elapsed, KeyGone);
    if State = SuiteWaitKeep then
    begin
      SuitePause;
      Elapsed := Elapsed + SuiteUninstallPollMs;
      if not KeyPresent then
        KeyGone := KeyGone + SuiteUninstallPollMs;
    end;
  until State <> SuiteWaitKeep;
  Result := SuiteUninstallOutcome(True, State);
  Log('Product ' + Product + ': wait state ' + IntToStr(State) + ' after ' + IntToStr(Elapsed div 1000) + ' s, outcome ' + IntToStr(Result));
end;

// The message for a product that was not removed: the reason and the way through Windows "Apps"
procedure SuiteReportNotRemoved(const Product: String; Outcome: Integer);
var
  Reason: String;
begin
  if Outcome = SuiteRemoveTimedOut then
    Reason := FmtMessage(CustomMessage('SuiteUninstallReasonTimeout'), [IntToStr(SuiteUninstallTimeoutMs div 60000)])
  else
    Reason := CustomMessage('SuiteUninstallReasonStart');
  SuiteUninstallMessage(FmtMessage(CustomMessage('SuiteUninstallFailed'), [SuiteProductTitle(Product), Reason]));
end;

// usUninstall: the uninstallers of the products, one at a time. A product that fails is reported and left
// as it is; the uninstallation of the suite goes on with the rest.
procedure SuiteRemoveProducts;
var
  I, Step, Total, Outcome: Integer;
  Product: String;
begin
  Total := 0;
  for I := 1 to 2 do
    if SuiteUninstallWanted[I] then
      Total := Total + 1;
  Step := 0;
  for I := 1 to 2 do
    if SuiteUninstallWanted[I] then
    begin
      Product := SuiteUninstallProduct(I);
      Step := Step + 1;
      SuiteUninstallStatus(FmtMessage(CustomMessage('SuiteUninstallStatus'), [IntToStr(Step), IntToStr(Total), SuiteProductTitle(Product)]), True);
      Outcome := SuiteRemoveProduct(Product);
      // removed, or removed meanwhile through its own entry: its folders are free to be offered for deletion
      SuiteUninstallDone[I] := (Outcome = SuiteRemoveOk) or (Outcome = SuiteRemoveGone);
      if not SuiteUninstallDone[I] then
        SuiteReportNotRemoved(Product, Outcome);
    end;
  SuiteUninstallStatus('', False);
end;

// The folders with user data that exist: the profiles and saved games below the roots of the products that
// are gone, the backups and the Mod Creator folder of the launcher. Only the folders of SuiteDataFolder and
// SuiteLauncherDataFolder, never more.
function SuiteExistingDataFolders(const LocalAppData: String): TArrayOfString;
var
  I, J, Count: Integer;
  Folder: String;
begin
  Count := 0;
  SetArrayLength(Result, 0);
  for I := 1 to 2 do
    if SuiteUninstallDone[I] then
      for J := 1 to SuiteDataFolderCount do
      begin
        Folder := SuiteDataFolder(SuiteUninstallRoot[I], J);
        if (Folder <> '') and DirExists(Folder) then
        begin
          Count := Count + 1;
          SetArrayLength(Result, Count);
          Result[Count - 1] := Folder;
        end;
      end;
  for J := 1 to SuiteLauncherFolderCount do
  begin
    Folder := SuiteLauncherDataFolder(LocalAppData, J);
    if (Folder <> '') and DirExists(Folder) then
    begin
      Count := Count + 1;
      SetArrayLength(Result, Count);
      Result[Count - 1] := Folder;
    end;
  end;
end;

// Deletes the folders of the list (from SuiteExistingDataFolders) with everything in them. DelTree does not
// follow a junction or a symbolic link inside a folder: it removes the link only.
procedure SuiteDeleteDataFolders(const Folders: TArrayOfString);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(Folders) - 1 do
    if DelTree(Folders[I], True, True, True) then
      Log('User data folder deleted: ' + Folders[I])
    else
      Log('User data folder not (completely) deleted: ' + Folders[I]);
end;

// usPostUninstall: what the suite left in the profile and below the roots of the products
procedure SuiteRemoveUserData;
var
  LocalAppData, Target, List: String;
  Folders, Buttons: TArrayOfString;
  I, J: Integer;
  DeleteData: Boolean;
begin
  LocalAppData := ExpandConstant('{localappdata}');
  // The settings and the log of the launcher of the account that uninstalls: always
  for I := 1 to SuiteLauncherFileCount do
  begin
    Target := SuiteLauncherDataFile(LocalAppData, I);
    if (Target <> '') and FileExists(Target) then
    begin
      if DeleteFile(Target) then
        Log('Launcher file deleted: ' + Target)
      else
        Log('Launcher file not deleted: ' + Target);
    end;
  end;
  // The user data: asked once, only if there is any, never in a silent run
  Folders := SuiteExistingDataFolders(LocalAppData);
  DeleteData := False;
  if GetArrayLength(Folders) > 0 then
  begin
    List := '';
    for I := 0 to GetArrayLength(Folders) - 1 do
      List := List + Folders[I] + #13#10;
    if UninstallSilent then
      Log('Silent uninstallation: the user data stays:'#13#10 + List)
    else
    begin
      // "Keep" is the first button (Yes) and the default; only the second button (No), "Delete", deletes
      SetArrayLength(Buttons, 2);
      Buttons[0] := CustomMessage('SuiteUninstallKeep');
      Buttons[1] := CustomMessage('SuiteUninstallDelete');
      DeleteData := SuppressibleTaskDialogMsgBox(CustomMessage('SuiteUninstallDataTitle'),
        FmtMessage(CustomMessage('SuiteUninstallDataQuestion'), [List]), mbConfirmation, MB_YESNO, Buttons, 0, IDYES) = IDNO;
      if not DeleteData then
        Log('The user data stays:'#13#10 + List);
    end;
  end;
  if DeleteData then
    SuiteDeleteDataFolders(Folders);
  // Folders that are empty now, from the inside out; RemoveDir never removes a folder with content
  for I := 1 to 2 do
    if SuiteUninstallDone[I] then
      for J := 1 to SuiteEmptyFolderCount do
      begin
        Target := SuiteEmptyFolder(SuiteUninstallRoot[I], J);
        if (Target <> '') and DirExists(Target) then
          if RemoveDir(Target) then
            Log('Empty folder removed: ' + Target);
      end;
  Target := SuiteLauncherDataDir(LocalAppData);
  if (Target <> '') and DirExists(Target) then
    if RemoveDir(Target) then
      Log('Empty folder removed: ' + Target);
end;
