[Code]
// The wizard pages of the suite (WP4): the product page (Empire Earth and Neo Empire Earth, both ticked, with
// their state on this computer and the box "Advanced"), the page with the EULA and the legal question, the
// page with the NeoEE rules (only when NeoEE is ticked), and the text of the last page with the result of
// every item. A silent run (/SILENT, /VERYSILENT) shows none of them: its products come from /PRODUCTS
// (InitializeSetup in suite.iss). The legal texts are the texts of the product setups, which skip them
// when they run silently (contract 1.7 point 4); ci/check_suite_texts.py checks the copies.
// The product runner (suite_run.iss) reads SuiteWantEE, SuiteWantNeoEE and SuiteAdvanced and sets SuiteProductsOk,
// SuiteCdKeyResult and the language lines of the products; this file only shows them. It never starts a product setup and
// never touches the CD key registration. The installation page also gets what the runner shows there (suite 1.1.0):
// the list of the finished steps and the line for what Cancel does now; the runner fills them.
// Requires: suite.iss (the globals, SuiteSilent, IsDotNet48, SuiteProductSucceeded, the constants of the
// installation sizes), suite_common.iss (the helpers), the messages of suite_messages.iss.

var
  SuiteSelectPage, SuiteLegalPage, SuiteRulesPage: TWizardPage;
  SuiteCheckEE, SuiteCheckNeoEE, SuiteCheckAdvanced, SuiteCheckLegal: TNewCheckBox;
  SuiteSelectHint, SuiteLegalHint: TNewStaticText;
  SuiteEulaViewer, SuiteRulesViewer: TRichEditViewer;
  // True if the legal question has to be answered (neither product installed)
  SuiteLegalRequired: Boolean;
  // The installation page: the list of the finished steps (a heading per game, then its steps), and the line below the
  // file name that says what Cancel does now
  SuiteStageList: TNewCheckListBox;
  SuiteCancelLabel: TNewStaticText;
  // One character per item of the list: '1' a ticked step, '0' a step that is not ticked, '-' a heading. A click on a box
  // puts it back: the list only shows.
  SuiteStageTicks: String;

// How a product is installed on this computer, from its uninstall entry (the AppId at run time, as
// the product setup was built with it): HKLM for all users, HKCU for one user only. The suite installs
// in the 64-bit mode, so both are the 64-bit views on a 64-bit Windows; HKLM64 and HKCU64 would raise
// "Cannot access 64-bit registry keys" on a 32-bit Windows, which the suite supports.
function SuiteInstallState(const AppId: String): Integer;
var
  Key: String;
begin
  Key := SuiteUninstallKey(AppId);
  Result := SuiteProductState(RegValueExists(HKLM, Key, 'UninstallString'),
    RegValueExists(HKCU, Key, 'UninstallString'));
end;

// The launcher was installed by this run or an earlier one (Check of the entry of [Run])
function SuiteLauncherInstalled: Boolean;
begin
  Result := IsDotNet48 and FileExists(ExpandConstant('{app}\{#LauncherExe}'));
end;

function SuiteTickedProducts: String;
begin
  Result := SuiteSelectedProducts(SuiteCheckEE.Checked, SuiteCheckNeoEE.Checked, SuiteStateEE, SuiteStateNeoEE);
end;

// The name of the button of the page that comes after the legal page: "Install" if NeoEE is not ticked
// (no rules page follows), else "Next"
function SuiteLegalNextButton: String;
begin
  if SuiteListHasItem(SuiteTickedProducts, SuiteProductNeoEE) then
    Result := SuiteButtonName(SetupMessage(msgButtonNext))
  else
    Result := SuiteButtonName(SetupMessage(msgButtonInstall));
end;

// Enables "Next" as far as the page allows it, and shows the hint that says why not
procedure SuiteRefreshButtons;
begin
  // OnClick also fires when InitializeWizard sets Checked, before the later pages exist (their ID on nil
  // stops the setup with "Could not call proc"); CurPageChanged refreshes the buttons when a page is shown
  if (SuiteSelectPage = nil) or (SuiteLegalPage = nil) or (SuiteRulesPage = nil) then
    Exit;
  if WizardForm.CurPageID = SuiteSelectPage.ID then
  begin
    WizardForm.NextButton.Enabled := SuiteTickedProducts <> '';
    SuiteSelectHint.Visible := not WizardForm.NextButton.Enabled;
  end
  else if WizardForm.CurPageID = SuiteLegalPage.ID then
  begin
    WizardForm.NextButton.Enabled := SuiteLegalPageDone(SuiteLegalRequired, SuiteCheckLegal.Checked);
    SuiteLegalHint.Caption := FmtMessage(CustomMessage('SuiteLegalNeedYes'), [SuiteLegalNextButton]);
    SuiteLegalHint.Visible := not WizardForm.NextButton.Enabled;
    // the button of the legal page is "Install" if no rules page follows
    if SuiteListHasItem(SuiteTickedProducts, SuiteProductNeoEE) then
      WizardForm.NextButton.Caption := SetupMessage(msgButtonNext)
    else
      WizardForm.NextButton.Caption := SetupMessage(msgButtonInstall);
  end;
end;

procedure SuiteTickChanged(Sender: TObject);
begin
  SuiteRefreshButtons;
end;

function SuiteAddLabel(Page: TWizardPage; const Text: String; Left, Top, Width: Integer): TNewStaticText;
begin
  Result := TNewStaticText.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := Left;
  Result.Top := Top;
  Result.Width := Width;
  Result.AutoSize := True;
  Result.WordWrap := True;
  Result.Caption := Text;
end;

function SuiteAddCheck(Page: TWizardPage; const Text: String; Top: Integer): TNewCheckBox;
begin
  Result := TNewCheckBox.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := 0;
  Result.Top := Top;
  Result.Width := Page.SurfaceWidth;
  Result.Height := ScaleY(17);
  Result.Caption := Text;
  Result.OnClick := @SuiteTickChanged;
end;

function SuiteAddViewer(Page: TWizardPage; Top, Height: Integer): TRichEditViewer;
begin
  Result := TRichEditViewer.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := 0;
  Result.Top := Top;
  Result.Width := Page.SurfaceWidth;
  Result.Height := Height;
  Result.ScrollBars := ssVertical;
  Result.ReadOnly := True;
  Result.UseRichEdit := True;
end;

// Shows a file of the package, which the caller has extracted to {tmp} (never installed), in a viewer.
// A text that cannot be read stops the setup with an error: the legal texts are never skipped.
procedure SuiteShowFile(Viewer: TRichEditViewer; const Name: String; Rtf: Boolean);
var
  Text: AnsiString;
begin
  if not LoadStringFromFile(ExpandConstant('{tmp}\') + Name, Text) then
    RaiseException('Cannot read ' + Name);
  if Rtf then
    Viewer.RTFText := Text
  else
    Viewer.Lines.Text := String(Text);
end;

// One line of the last page: the name of an item and what became of it (SuiteResult*)
function SuiteItemLine(const Name: String; Code: Integer): String;
begin
  case Code of
    SuiteResultOk: Result := CustomMessage('SuiteStatusOk');
    SuiteResultFailed: Result := CustomMessage('SuiteStatusFailed');
    SuiteResultSkippedUser: Result := CustomMessage('SuiteStatusSkippedUser');
    SuiteResultCancelled: Result := CustomMessage('SuiteStatusCancelled');
  else
    Result := CustomMessage('SuiteStatusNotSelected');
  end;
  Result := Name + ': ' + Result;
end;

function SuiteStateText(State: Integer): String;
begin
  if State = SuiteStateMachine then
    Result := CustomMessage('SuiteStateInstalled')
  else if State = SuiteStateUserOnly then
    Result := CustomMessage('SuiteStateUserOnly')
  else
    Result := CustomMessage('SuiteStateNew');
end;

// Page 1: the products. Both ticked; one installed for one user only is shown, not ticked, and skipped.
procedure SuiteBuildSelectPage;
var
  Top, Indent, W: Integer;
  L: TNewStaticText;
begin
  SuiteSelectPage := CreateCustomPage(wpWelcome, CustomMessage('SuiteSelectTitle'), CustomMessage('SuiteSelectSubtitle'));
  W := SuiteSelectPage.SurfaceWidth;
  Indent := ScaleX(20);
  Top := 0;

  SuiteCheckEE := SuiteAddCheck(SuiteSelectPage, CustomMessage('SuiteProductEE'), Top);
  SuiteCheckEE.Checked := SuiteCanInstall(SuiteStateEE);
  SuiteCheckEE.Enabled := SuiteCanInstall(SuiteStateEE);
  L := SuiteAddLabel(SuiteSelectPage, SuiteStateText(SuiteStateEE), Indent, Top + ScaleY(20), W - Indent);
  Top := L.Top + L.Height + ScaleY(12);

  SuiteCheckNeoEE := SuiteAddCheck(SuiteSelectPage, CustomMessage('SuiteProductNeoEE'), Top);
  SuiteCheckNeoEE.Checked := SuiteCanInstall(SuiteStateNeoEE);
  SuiteCheckNeoEE.Enabled := SuiteCanInstall(SuiteStateNeoEE);
  L := SuiteAddLabel(SuiteSelectPage, SuiteStateText(SuiteStateNeoEE), Indent, Top + ScaleY(20), W - Indent);
  Top := L.Top + L.Height + ScaleY(12);

  if IsDotNet48 then
    L := SuiteAddLabel(SuiteSelectPage, CustomMessage('SuiteLauncherInfo'), 0, Top, W)
  else
    L := SuiteAddLabel(SuiteSelectPage, CustomMessage('SuiteLauncherNoDotNet'), 0, Top, W);
  Top := L.Top + L.Height + ScaleY(16);

  SuiteCheckAdvanced := SuiteAddCheck(SuiteSelectPage, CustomMessage('SuiteAdvanced'), Top);
  L := SuiteAddLabel(SuiteSelectPage, CustomMessage('SuiteAdvancedHint'), Indent, Top + ScaleY(20), W - Indent);
  Top := L.Top + L.Height + ScaleY(16);

  SuiteSelectHint := SuiteAddLabel(SuiteSelectPage,
    FmtMessage(CustomMessage('SuiteSelectNone'), [SuiteButtonName(SetupMessage(msgButtonNext))]), 0, Top, W);
  SuiteSelectHint.Font.Style := [fsBold];
  SuiteSelectHint.Visible := False;
end;

// Page 2: the EULA, and the legal question when neither product is installed (a "Yes" box that has to be ticked)
procedure SuiteBuildLegalPage;
var
  Top, W, Reserved: Integer;
  L: TNewStaticText;
begin
  SuiteLegalPage := CreateCustomPage(SuiteSelectPage.ID, CustomMessage('SuiteLegalTitle'), CustomMessage('SuiteLegalSubtitle'));
  SuiteLegalRequired := SuiteLegalAnswerRequired(SuiteStateEE, SuiteStateNeoEE);
  W := SuiteLegalPage.SurfaceWidth;
  L := SuiteAddLabel(SuiteLegalPage, CustomMessage('SuiteLegalEulaCaption'), 0, 0, W);
  Top := L.Top + L.Height + ScaleY(4);
  if SuiteLegalRequired then
    Reserved := ScaleY(130)
  else
    Reserved := ScaleY(40);
  SuiteEulaViewer := SuiteAddViewer(SuiteLegalPage, Top, SuiteLegalPage.SurfaceHeight - Top - Reserved);
  Top := SuiteEulaViewer.Top + SuiteEulaViewer.Height + ScaleY(10);
  if SuiteLegalRequired then
  begin
    L := SuiteAddLabel(SuiteLegalPage, CustomMessage('SuiteLegalQuestion'), 0, Top, W);
    Top := L.Top + L.Height + ScaleY(6);
    SuiteCheckLegal := SuiteAddCheck(SuiteLegalPage, CustomMessage('SuiteLegalYes'), Top);
    Top := Top + ScaleY(24);
    SuiteLegalHint := SuiteAddLabel(SuiteLegalPage, '', 0, Top, W);
    SuiteLegalHint.Font.Style := [fsBold];
    SuiteLegalHint.Visible := False;
  end
  else
  begin
    SuiteAddLabel(SuiteLegalPage, CustomMessage('SuiteLegalKnown'), 0, Top, W);
    // no question: a box that is ticked and hidden keeps the page logic the same
    SuiteCheckLegal := SuiteAddCheck(SuiteLegalPage, '', Top);
    SuiteCheckLegal.Checked := True;
    SuiteCheckLegal.Visible := False;
    SuiteLegalHint := SuiteAddLabel(SuiteLegalPage, '', 0, Top, W);
    SuiteLegalHint.Visible := False;
  end;
  if not SuiteSilent then
  begin
    // the EULA of the product setups (ci/check_suite_texts.py: this is the file the check compared)
    ExtractTemporaryFile('EULA_DSML.txt');
    SuiteShowFile(SuiteEulaViewer, 'EULA_DSML.txt', False);
  end;
end;

// Page 3: the rules of NeoEE (ShouldSkipPage hides the page unless NeoEE is ticked)
procedure SuiteBuildRulesPage;
begin
  SuiteRulesPage := CreateCustomPage(SuiteLegalPage.ID, CustomMessage('SuiteRulesTitle'), CustomMessage('SuiteRulesSubtitle'));
  SuiteRulesViewer := SuiteAddViewer(SuiteRulesPage, 0, SuiteRulesPage.SurfaceHeight);
  if not SuiteSilent then
  begin
    ExtractTemporaryFile('neoee_rules.rtf');
    SuiteShowFile(SuiteRulesViewer, 'neoee_rules.rtf', True);
  end;
end;

// A click or the space bar on a box of the list of the finished steps: the box goes back to what it shows
procedure SuiteStageClickCheck(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to SuiteStageList.Items.Count - 1 do
    if (I < Length(SuiteStageTicks)) and (SuiteStageTicks[I + 1] <> '-') and
      (SuiteStageList.Checked[I] <> (SuiteStageTicks[I + 1] = '1')) then
      SuiteStageList.Checked[I] := SuiteStageTicks[I + 1] = '1';
end;

// The place of the line for Cancel and of the list on the installation page of Setup. The page of Setup has the status
// line on top, the file line below it and then the bar; the line for Cancel goes below the bar and the list takes the rest of
// the page. The line wraps: its German and French texts are wider than the page of the modern wizard at 100 percent, and
// the text of a long status line may be as well, so it takes the height its text needs at that width and font
// (AdjustHeight, at least one line; none without a text) and the list starts below its real height. Called again when the text changes and when the list is shown: the
// bar has its final size only then.
procedure SuiteLayoutProgressControls;
var
  Page: TWinControl;
begin
  Page := WizardForm.ProgressGauge.Parent;
  SuiteCancelLabel.Left := WizardForm.ProgressGauge.Left;
  SuiteCancelLabel.Top := WizardForm.ProgressGauge.Top + WizardForm.ProgressGauge.Height + ScaleY(6);
  SuiteCancelLabel.Width := WizardForm.ProgressGauge.Width;
  if SuiteCancelLabel.Caption = '' then
    SuiteCancelLabel.Height := 0
  else
  begin
    // the height of one line first, so that the label has a size if AdjustHeight cannot measure; then what the text needs
    SuiteCancelLabel.Height := ScaleY(SuiteCancelLineHeight);
    SuiteCancelLabel.AdjustHeight;
  end;
  SuiteCancelLabel.Visible := SuiteCancelLabel.Caption <> '';
  SuiteStageList.Left := WizardForm.ProgressGauge.Left;
  SuiteStageList.Top := SuiteCancelLabel.Top + SuiteCancelLabel.Height + ScaleY(8);
  SuiteStageList.Width := WizardForm.ProgressGauge.Width;
  SuiteStageList.Height := Page.ClientHeight - SuiteStageList.Top;
end;

// The line for Cancel and the list of the finished steps on the installation page; the list is shown from the first
// product setup on (SuiteRunProducts)
procedure SuiteBuildProgressControls;
begin
  SuiteCancelLabel := TNewStaticText.Create(WizardForm);
  SuiteCancelLabel.Parent := WizardForm.ProgressGauge.Parent;
  SuiteCancelLabel.AutoSize := False;
  SuiteCancelLabel.WordWrap := True;
  SuiteCancelLabel.Caption := '';
  SuiteStageList := TNewCheckListBox.Create(WizardForm);
  SuiteStageList.Parent := WizardForm.ProgressGauge.Parent;
  SuiteStageList.OnClickCheck := @SuiteStageClickCheck;
  SuiteStageList.Visible := False;
  SuiteStageTicks := '';
  SuiteLayoutProgressControls;
end;

// The list is empty again
procedure SuiteStageClear;
begin
  SuiteStageList.Items.Clear;
  SuiteStageTicks := '';
end;

// The heading of a game: the first line of its block
procedure SuiteStageHeading(const Text: String);
begin
  SuiteStageList.AddGroup(Text, '', 0, nil);
  SuiteStageTicks := SuiteStageTicks + '-';
end;

// A step of the game: ticked if it was done, not ticked if it failed; the list scrolls to the new line
procedure SuiteStageAdd(const Text: String; Ticked: Boolean);
begin
  SuiteStageList.AddCheckBox(Text, '', 1, Ticked, True, False, False, nil);
  if Ticked then
    SuiteStageTicks := SuiteStageTicks + '1'
  else
    SuiteStageTicks := SuiteStageTicks + '0';
  // LB_SETTOPINDEX: the last line at the top, as far as the list can scroll
  SendMessage(SuiteStageList.Handle, $0197, SuiteStageList.Items.Count - 1, 0);
end;

procedure InitializeWizard;
begin
  SuiteBuildSelectPage;
  SuiteBuildLegalPage;
  SuiteBuildRulesPage;
  SuiteBuildProgressControls;
end;

// A silent run skips the pages of the suite: Setup would "click" Next on them, the product page would take
// its boxes (both ticked) over /PRODUCTS and the legal page would stop the run (its box is not ticked); the
// products of a silent run come from InitializeSetup. Otherwise only the rules page is skipped, and only if
// NeoEE is not ticked.
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  if SuiteSilent then
    Result := (PageID = SuiteSelectPage.ID) or (PageID = SuiteLegalPage.ID) or (PageID = SuiteRulesPage.ID)
  else
    Result := (PageID = SuiteRulesPage.ID) and not SuiteWantNeoEE;
end;

// The free space for the products ticked on the page (the same measure as the prechecks, with the
// selection of the user): '' if it is enough, else the text of the message
function SuiteSelectionSpaceProblem: String;
var
  TempRoot, Target: String;
  TempFree, TargetFree, Total, TempNeeded, TargetNeeded: Int64;
  Problem: Integer;
begin
  Result := '';
  TempRoot := ExtractFileDir(ExpandConstant('{tmp}'));
  Target := ExpandConstant('{autopf32}');
  TempNeeded := SuiteRequiredTempBytes(SuiteEESize, SuiteNeoEESize, SuiteWantEE, SuiteWantNeoEE);
  TargetNeeded := SuiteRequiredTargetBytes(SuiteEEInstallBytes, SuiteNeoEEInstallBytes, SuiteLauncherBytes,
    SuiteNeedsInstallSpace(SuiteWantEE, SuiteStateEE), SuiteNeedsInstallSpace(SuiteWantNeoEE, SuiteStateNeoEE));
  if not (GetSpaceOnDisk64(TempRoot, TempFree, Total) and GetSpaceOnDisk64(Target, TargetFree, Total)) then
    Exit;
  Problem := SuiteSpaceProblem(TempFree, TempNeeded, TargetFree, TargetNeeded, SuiteDriveOf(TempRoot) = SuiteDriveOf(Target));
  if Problem = 1 then
    Result := FmtMessage(CustomMessage('SuiteNotEnoughSpace'), [SuiteDriveOf(TempRoot), SuiteFormatMegabytes(TempNeeded), SuiteFormatMegabytes(TempFree)])
  else if Problem = 2 then
  begin
    if SuiteDriveOf(TempRoot) = SuiteDriveOf(Target) then
      TargetNeeded := TargetNeeded + TempNeeded;
    Result := FmtMessage(CustomMessage('SuiteNotEnoughSpace'), [SuiteDriveOf(Target), SuiteFormatMegabytes(TargetNeeded), SuiteFormatMegabytes(TargetFree)]);
  end;
end;

// Leaving the product page takes over the ticks and checks the space for them (the prechecks of
// InitializeSetup assumed both products)
function NextButtonClick(CurPageID: Integer): Boolean;
var
  Problem: String;
begin
  Result := True;
  if CurPageID = SuiteSelectPage.ID then
  begin
    SuiteWantEE := SuiteListHasItem(SuiteTickedProducts, SuiteProductEE);
    SuiteWantNeoEE := SuiteListHasItem(SuiteTickedProducts, SuiteProductNeoEE);
    SuiteAdvanced := SuiteCheckAdvanced.Checked;
    Log('Selection: EE ' + IntToStr(Ord(SuiteWantEE)) + ', NeoEE ' + IntToStr(Ord(SuiteWantNeoEE)) +
      ', advanced ' + IntToStr(Ord(SuiteAdvanced)));
    Problem := SuiteSelectionSpaceProblem;
    if Problem <> '' then
    begin
      Log('Not enough free space for the selection');
      SuppressibleMsgBox(Problem, mbError, MB_OK, IDOK);
      Result := False;
    end;
  end
  else if CurPageID = SuiteLegalPage.ID then
  begin
    if not SuiteLegalPageDone(SuiteLegalRequired, SuiteCheckLegal.Checked) then
      Result := False
    else if SuiteLegalRequired then
      Log('Legal question answered with yes');
  end;
end;

// What became of a game in this run for its line on the last page: SuiteItemResult, but "cancelled" instead of "failed"
// for the game whose setup the user cancelled
function SuiteProductResult(const Product: String; Selected: Boolean; State: Integer): Integer;
begin
  Result := SuiteCancelledResult(SuiteItemResult(SuiteProductSucceeded(Product), Selected, State), SuiteCancelledProduct, Product);
end;

// The text of the last page: what became of the games and the launcher, the CD key line of NeoEE, the logs
procedure SuiteShowFinish;
var
  NL, Text: String;
  ResultEE, ResultNeoEE, Delta: Integer;
begin
  NL := #13#10;
  ResultEE := SuiteProductResult(SuiteProductEE, SuiteWantEE, SuiteStateEE);
  ResultNeoEE := SuiteProductResult(SuiteProductNeoEE, SuiteWantNeoEE, SuiteStateNeoEE);
  Text := CustomMessage('SuiteFinishIntro') + NL + NL + SuiteItemLine(CustomMessage('SuiteProductEE'), ResultEE) + NL;
  // what the run found out about the language files of a game that was installed (the runner sets the line)
  if (ResultEE = SuiteResultOk) and (SuiteLangLineEE <> '') then
    Text := Text + '    ' + SuiteLangLineEE + NL;
  Text := Text + SuiteItemLine(CustomMessage('SuiteProductNeoEE'), ResultNeoEE) + NL;
  if (ResultNeoEE = SuiteResultOk) and (SuiteLangLineNeoEE <> '') then
    Text := Text + '    ' + SuiteLangLineNeoEE + NL;
  if IsDotNet48 then
    Text := Text + CustomMessage('SuiteNameLauncher') + ': ' + CustomMessage('SuiteStatusOk') + NL
  else
    Text := Text + CustomMessage('SuiteNameLauncher') + ': ' + CustomMessage('SuiteStatusNoDotNet') + NL;
  if ResultNeoEE = SuiteResultOk then
  begin
    Text := Text + NL;
    if SuiteCdKeyNotChosenFlag then
      Text := Text + CustomMessage('SuiteCdKeyNotChosen')
    else
      case SuiteCdKeyKind(SuiteCdKeyResult) of
        SuiteCdKeyRegistered: Text := Text + CustomMessage('SuiteCdKeyOk');
        SuiteCdKeyNotRegistered: Text := Text + FmtMessage(CustomMessage('SuiteCdKeyFailed'), [Trim(SuiteCdKeyResult)]);
      else
        Text := Text + CustomMessage('SuiteCdKeyUnknown');
      end;
    Text := Text + NL;
  end;
  Text := Text + NL + FmtMessage(CustomMessage('SuiteFinishLogs'), [ExpandConstant('{app}\Logs')]) + NL + NL +
    FmtMessage(CustomMessage('SuiteFinishClose'), [SuiteButtonName(SetupMessage(msgButtonFinish))]);
  if (ResultEE = SuiteResultFailed) or (ResultNeoEE = SuiteResultFailed) or (ResultEE = SuiteResultCancelled) or
    (ResultNeoEE = SuiteResultCancelled) then
    WizardForm.FinishedHeadingLabel.Caption := CustomMessage('SuiteFinishHeadingProblems');
  Delta := WizardForm.FinishedLabel.Height;
  WizardForm.FinishedLabel.Caption := Text;
  WizardForm.FinishedLabel.AdjustHeight;
  // the list with "Start the launcher" lies below the text, which is longer than Setup's one line
  Delta := WizardForm.FinishedLabel.Height - Delta;
  if Delta > 0 then
  begin
    WizardForm.RunList.Top := WizardForm.RunList.Top + Delta;
    if WizardForm.RunList.Height - Delta > ScaleY(30) then
      WizardForm.RunList.Height := WizardForm.RunList.Height - Delta;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
    SuiteShowFinish
  else if CurPageID = SuiteSelectPage.ID then
  begin
    WizardForm.NextButton.Caption := SetupMessage(msgButtonNext);
    SuiteRefreshButtons;
  end
  else if CurPageID = SuiteLegalPage.ID then
    SuiteRefreshButtons
  else if CurPageID = SuiteRulesPage.ID then
  begin
    // the last page before the installation
    WizardForm.NextButton.Enabled := True;
    WizardForm.NextButton.Caption := SetupMessage(msgButtonInstall);
  end
  else
    WizardForm.NextButton.Enabled := True;
end;
