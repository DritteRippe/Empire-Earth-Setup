[Code]
// Read-only checks before the installation (docs/adr/0007-environment-warnings.md). They never
// write, delete or move anything, and they never block a silent installation: in silent mode and
// with /SUPPRESSMSGBOXES they only log.
//
//  - InitializeSetup, always (LogScreenMetrics): the size of the primary screen, its DPI with the
//    display scaling it means, and the game window the setup writes ([Registry] Game Window Width
//    and Height, contract 3.3) go into the log, so that a support case and contract O4 can be
//    decided from the setup log.
//  - InitializeSetup, after the install-mode question (ShowLowScreenResolutionNotice): a notice if
//    the primary screen is lower than 768 pixels (R13; t=3863 p=26167: netbooks with 1024 x 600
//    crash after the intro). The clamp of the window size stays.
//
// Requires: utils.iss (ClampGameWindowWidth/Height, MinGameWindowHeight, IsScreenTooLow,
// FormatScreenMetrics), extension.iss (SilentInstall, SuppressMsgBoxes), the message
// LowScreenResolution (messages.iss).

// Size of the primary screen and DPI of the screen. Inno Setup 6.2.2 declares itself
// system-DPI-aware (manifest of Setup.e32), so both are physical values at the display scaling of
// the sign-in; a scaling changed without signing out again is the known exception (contract O4).
function GetSystemMetrics(nIndex: Integer): Integer;
  external 'GetSystemMetrics@user32.dll stdcall';
function GetDC(hWnd: HWND): LongWord;
  external 'GetDC@user32.dll stdcall';
function GetDeviceCaps(hDC: LongWord; nIndex: Integer): Integer;
  external 'GetDeviceCaps@gdi32.dll stdcall';
function ReleaseDC(hWnd: HWND; hDC: LongWord): Integer;
  external 'ReleaseDC@user32.dll stdcall';

const
  // GetSystemMetrics indexes (Win32 API): width and height of the primary screen
  SM_CXSCREEN = 0;
  SM_CYSCREEN = 1;
  // GetDeviceCaps index (Win32 API): pixels per logical inch along the width of the screen
  LOGPIXELSX = 88;

// DPI of the screen (GetDeviceCaps(LOGPIXELSX) of the device context of the whole screen), 0 if it
// cannot be read
function GetScreenDpi: Integer;
var
  ScreenDC: LongWord;
begin
  Result := 0;
  ScreenDC := GetDC(0);
  if ScreenDC = 0 then
    Exit;
  try
    Result := GetDeviceCaps(ScreenDC, LOGPIXELSX);
  finally
    ReleaseDC(0, ScreenDC);
  end;
end;

// InitializeSetup, on every run: screen size, DPI and the clamped game window into the log
// (FormatScreenMetrics). Nothing escapes: the log line is a diagnosis, not a step of the setup.
procedure LogScreenMetrics;
begin
  try
    Log(FormatScreenMetrics(GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), GetScreenDpi()));
  except
    Log('Unable to read the screen size or the DPI: ' + GetExceptionMessage);
  end;
end;

// InitializeSetup, after the install-mode question: a notice if the primary screen is lower than
// the menus of the game need (IsScreenTooLow). Only the log in silent mode and with
// /SUPPRESSMSGBOXES; the installation always continues.
procedure ShowLowScreenResolutionNotice;
var
  Width, Height: Integer;
begin
  Width := GetSystemMetrics(SM_CXSCREEN);
  Height := GetSystemMetrics(SM_CYSCREEN);
  if not IsScreenTooLow(Height) then
    Exit;
  Log('The screen is lower than ' + IntToStr(MinGameWindowHeight) + ' pixels (' + IntToStr(Width) + ' x ' + IntToStr(Height) +
    '): the game window is set to ' + IntToStr(ClampGameWindowWidth(Width)) + ' x ' + IntToStr(ClampGameWindowHeight(Height)) +
    ', the menus may not fit (notice LowScreenResolution)');
  if SilentInstall or SuppressMsgBoxes then
  begin
    Log('Notice LowScreenResolution not shown (silent installation or /SUPPRESSMSGBOXES)');
    Exit;
  end;
  MsgBox(FmtMessage(CustomMessage('LowScreenResolution'), [IntToStr(Width), IntToStr(Height),
    IntToStr(ClampGameWindowWidth(Width)), IntToStr(ClampGameWindowHeight(Height))]), mbInformation, MB_OK);
end;
