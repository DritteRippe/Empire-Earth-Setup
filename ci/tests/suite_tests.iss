[Code]
// Tests of the helpers of the suite installer (suite/suite_common.iss), included by unit_tests.iss
// after its own helpers (Check, CheckBool) and run by its InitializeSetup. The helpers compute
// something from their arguments; SuiteFindSliceProblems reads file sizes, so its tests write small
// files into a folder of their own below {tmp}. Nothing here sends a request; TestSuiteProcess starts cmd.exe and
// cscript.exe of Windows (never a setup).
// Requires: Check, CheckBool, Skip, Results (unit_tests.iss), suite/suite_common.iss; the log tail tests also CreateFile, WriteFile,
// CloseHandle and FILE_SHARE_READ of utils.iss.

procedure TestSuiteSliceFileName;
begin
  Check('SuiteSliceFileName 1', SuiteSliceFileName('Empire Earth Community Setup', 1), 'Empire Earth Community Setup-1.bin');
  Check('SuiteSliceFileName 26', SuiteSliceFileName('Setup', 26), 'Setup-26.bin');
end;

procedure TestSuiteListedSizes;
begin
  Check('SuiteListedCount empty', IntToStr(SuiteListedCount('')), '0');
  Check('SuiteListedCount blank', IntToStr(SuiteListedCount('  ')), '0');
  Check('SuiteListedCount one', IntToStr(SuiteListedCount('5')), '1');
  Check('SuiteListedCount three', IntToStr(SuiteListedCount('1,2,3')), '3');
end;

procedure TestSuiteSliceState;
begin
  Check('SuiteSliceState fine', IntToStr(SuiteSliceState(True, 5, 5)), '0');
  Check('SuiteSliceState smaller than the maximum', IntToStr(SuiteSliceState(True, 1, 5)), '0');
  Check('SuiteSliceState missing', IntToStr(SuiteSliceState(False, 0, 5)), '1');
  Check('SuiteSliceState larger than a slice may be', IntToStr(SuiteSliceState(True, 6, 5)), '2');
  Check('SuiteSliceState empty file', IntToStr(SuiteSliceState(True, 0, 5)), '2');
end;

// Writes a file of Size bytes (ASCII) into Dir
procedure WriteSuiteSlice(const Dir, Name: String; Size: Integer);
var
  Text: String;
begin
  Text := '';
  while Length(Text) < Size do
    Text := Text + 'x';
  if not SaveStringToFile(AddBackslash(Dir) + Name, Text, False) then
    Results.Add('FAIL cannot write ' + Name);
end;

procedure TestSuiteFindSliceProblems;
var
  Dir, Crlf: String;
begin
  Crlf := #13#10;
  Dir := ExpandConstant('{tmp}\suite_slices');
  ForceDirectories(Dir);
  WriteSuiteSlice(Dir, 'Pkg-1.bin', 3);
  WriteSuiteSlice(Dir, 'Pkg-2.bin', 5);
  WriteSuiteSlice(Dir, 'Pkg-3.bin', 4);
  // slices of 3, 5 and 4 bytes, at most 6 each, together 12
  Check('SuiteFindSliceProblems all fine', SuiteFindSliceProblems(Dir, 'Pkg', 3, 6, 12, 6), '');
  Check('SuiteFindSliceProblems folder with backslash', SuiteFindSliceProblems(AddBackslash(Dir), 'Pkg', 3, 6, 12, 6), '');
  Check('SuiteFindSliceProblems no slices recorded', SuiteFindSliceProblems(Dir, 'Pkg', 0, 6, 0, 6), '');
  Check('SuiteFindSliceProblems slice at the maximum', SuiteFindSliceProblems(Dir, 'Pkg', 3, 5, 12, 6), '');
  Check('SuiteFindSliceProblems total too small', SuiteFindSliceProblems(Dir, 'Pkg', 3, 6, 13, 6),
    'Pkg-1.bin to Pkg-3.bin together have 12 bytes, expected 13 (a slice is damaged or from another build)');
  Check('SuiteFindSliceProblems total too large', SuiteFindSliceProblems(Dir, 'Pkg', 3, 6, 11, 6),
    'Pkg-1.bin to Pkg-3.bin together have 12 bytes, expected 11 (a slice is damaged or from another build)');
  Check('SuiteFindSliceProblems slice above the maximum', SuiteFindSliceProblems(Dir, 'Pkg', 3, 4, 12, 6),
    'Pkg-2.bin (5 bytes, at most 4 and not empty expected)');
  Check('SuiteFindSliceProblems missing last', SuiteFindSliceProblems(Dir, 'Pkg', 4, 6, 19, 6), 'Pkg-4.bin (missing)');
  Check('SuiteFindSliceProblems two problems', SuiteFindSliceProblems(Dir, 'Pkg', 4, 4, 19, 6),
    'Pkg-2.bin (5 bytes, at most 4 and not empty expected)' + Crlf + 'Pkg-4.bin (missing)');
  Check('SuiteFindSliceProblems line limit', SuiteFindSliceProblems(Dir, 'Pkg', 5, 2, 5, 2),
    'Pkg-1.bin (3 bytes, at most 2 and not empty expected)' + Crlf + 'Pkg-2.bin (5 bytes, at most 2 and not empty expected)' + Crlf + '... and 3 more');
  Check('SuiteFindSliceProblems other base name', SuiteFindSliceProblems(Dir, 'Other', 1, 6, 3, 6), 'Other-1.bin (missing)');
  WriteSuiteSlice(Dir, 'Pkg-4.bin', 7);
  Check('SuiteFindSliceProblems an extra slice after the last is not read', SuiteFindSliceProblems(Dir, 'Pkg', 3, 6, 12, 6), '');
  DeleteFile(Dir + '\Pkg-4.bin');
  DeleteFile(Dir + '\Pkg-1.bin');
  DeleteFile(Dir + '\Pkg-2.bin');
  DeleteFile(Dir + '\Pkg-3.bin');
  RemoveDir(Dir);
end;

procedure TestSuitePaths;
begin
  CheckBool('SuiteIsSameOrInside same', SuiteIsSameOrInside('C:\Temp', 'C:\Temp'), True);
  CheckBool('SuiteIsSameOrInside trailing backslash', SuiteIsSameOrInside('C:\Temp\', 'C:\Temp'), True);
  CheckBool('SuiteIsSameOrInside below', SuiteIsSameOrInside('c:\temp\a\b', 'C:\Temp\'), True);
  CheckBool('SuiteIsSameOrInside name starts like the folder', SuiteIsSameOrInside('C:\Temp2\a', 'C:\Temp'), False);
  CheckBool('SuiteIsSameOrInside above', SuiteIsSameOrInside('C:\', 'C:\Temp'), False);
  CheckBool('SuiteIsSameOrInside empty folder', SuiteIsSameOrInside('C:\Temp', ''), False);
  CheckBool('SuiteIsZipViewPath Explorer ZIP view', SuiteIsZipViewPath('C:\Users\Anna\AppData\Local\Temp\Temp1_Empire Earth Community.zip',
    'C:\Users\Anna\AppData\Local\Temp'), True);
  CheckBool('SuiteIsZipViewPath temporary folder', SuiteIsZipViewPath('C:\Users\Anna\AppData\Local\Temp', 'C:\Users\Anna\AppData\Local\Temp\'), True);
  CheckBool('SuiteIsZipViewPath .zip folder elsewhere', SuiteIsZipViewPath('D:\Daten\Paket.ZIP\inside', 'C:\Users\Anna\AppData\Local\Temp'), True);
  CheckBool('SuiteIsZipViewPath Downloads', SuiteIsZipViewPath('C:\Users\Anna\Downloads\Empire Earth Community', 'C:\Users\Anna\AppData\Local\Temp'), False);
  CheckBool('SuiteIsZipViewPath folder named like zip', SuiteIsZipViewPath('C:\Users\Anna\Downloads\my.zipped files', 'C:\Users\Anna\AppData\Local\Temp'), False);
  CheckBool('SuiteIsZipViewPath temp name prefix', SuiteIsZipViewPath('C:\Users\Anna\AppData\Local\Temp2\x', 'C:\Users\Anna\AppData\Local\Temp'), False);
  Check('SuiteDriveOf local', SuiteDriveOf('c:\Program Files (x86)'), 'C:');
  Check('SuiteDriveOf relative', SuiteDriveOf('data\x'), '');
end;

procedure TestSuiteSpace;
var
  Margin, MB: Int64;
begin
  Margin := SuiteSpaceMargin;
  MB := 1048576;
  Check('SuiteRequiredTempBytes largest', IntToStr(SuiteRequiredTempBytes(100, 200, True, True)), IntToStr(200 + Margin));
  Check('SuiteRequiredTempBytes EE only', IntToStr(SuiteRequiredTempBytes(100, 200, True, False)), IntToStr(100 + Margin));
  Check('SuiteRequiredTempBytes NeoEE only', IntToStr(SuiteRequiredTempBytes(300, 200, False, True)), IntToStr(200 + Margin));
  Check('SuiteRequiredTempBytes none', IntToStr(SuiteRequiredTempBytes(100, 200, False, False)), IntToStr(Margin));
  Check('SuiteRequiredTargetBytes both', IntToStr(SuiteRequiredTargetBytes(1000, 2000, 50, True, True)), IntToStr(3050 + Margin));
  Check('SuiteRequiredTargetBytes EE only', IntToStr(SuiteRequiredTargetBytes(1000, 2000, 50, True, False)), IntToStr(1050 + Margin));
  CheckBool('SuiteNeedsInstallSpace new product', SuiteNeedsInstallSpace(True, SuiteStateNone), True);
  CheckBool('SuiteNeedsInstallSpace installed product (repair)', SuiteNeedsInstallSpace(True, SuiteStateMachine), False);
  CheckBool('SuiteNeedsInstallSpace not selected', SuiteNeedsInstallSpace(False, SuiteStateNone), False);
  CheckBool('SuiteNeedsInstallSpace not selected and installed', SuiteNeedsInstallSpace(False, SuiteStateMachine), False);
  Check('SuiteRequiredTargetBytes repair of both', IntToStr(SuiteRequiredTargetBytes(1000, 2000, 50,
    SuiteNeedsInstallSpace(True, SuiteStateMachine), SuiteNeedsInstallSpace(True, SuiteStateMachine))), IntToStr(50 + Margin));
  Check('SuiteRequiredTargetBytes repair of one, new other', IntToStr(SuiteRequiredTargetBytes(1000, 2000, 50,
    SuiteNeedsInstallSpace(True, SuiteStateMachine), SuiteNeedsInstallSpace(True, SuiteStateNone))), IntToStr(2050 + Margin));
  Check('SuiteRequiredTargetBytes none', IntToStr(SuiteRequiredTargetBytes(1000, 2000, 50, False, False)), IntToStr(50 + Margin));
  Check('SuiteSpaceProblem enough', IntToStr(SuiteSpaceProblem(100, 100, 500, 500, False)), '0');
  Check('SuiteSpaceProblem temp too small', IntToStr(SuiteSpaceProblem(99, 100, 500, 500, False)), '1');
  Check('SuiteSpaceProblem target too small', IntToStr(SuiteSpaceProblem(100, 100, 499, 500, False)), '2');
  Check('SuiteSpaceProblem both too small names the temp drive', IntToStr(SuiteSpaceProblem(1, 100, 1, 500, False)), '1');
  Check('SuiteSpaceProblem one drive, enough for the sum', IntToStr(SuiteSpaceProblem(600, 100, 600, 500, True)), '0');
  Check('SuiteSpaceProblem one drive, enough for each but not for the sum', IntToStr(SuiteSpaceProblem(599, 100, 599, 500, True)), '2');
  Check('SuiteFormatMegabytes zero', SuiteFormatMegabytes(0), '0 MB');
  Check('SuiteFormatMegabytes one byte', SuiteFormatMegabytes(1), '1 MB');
  Check('SuiteFormatMegabytes exact', SuiteFormatMegabytes(MB), '1 MB');
  Check('SuiteFormatMegabytes rounded up', SuiteFormatMegabytes(MB + 1), '2 MB');
  // above 2 GiB: the sizes of the products are, and the sum of both installations is
  Check('SuiteFormatMegabytes 2300 MB', SuiteFormatMegabytes(StrToInt64('2411724800')), '2300 MB');
  Check('SuiteFormatMegabytes above 4 GiB', SuiteFormatMegabytes(StrToInt64('4294967297')), '4097 MB');
  Check('SuiteRequiredTempBytes above 2 GiB', IntToStr(SuiteRequiredTempBytes(StrToInt64('2147483648'), 200, True, True)), '2415919104');
  Check('SuiteRequiredTargetBytes above 2 GiB', IntToStr(SuiteRequiredTargetBytes(StrToInt64('1900000000'), StrToInt64('1900000000'), 33554432, True, True)),
    '4101989888');
  Check('SuiteSpaceProblem above 2 GiB, enough', IntToStr(SuiteSpaceProblem(StrToInt64('3000000000'), StrToInt64('2500000000'), StrToInt64('6000000000'),
    StrToInt64('3500000000'), False)), '0');
  Check('SuiteSpaceProblem above 2 GiB, one drive too small for the sum', IntToStr(SuiteSpaceProblem(StrToInt64('5900000000'), StrToInt64('2500000000'),
    StrToInt64('5900000000'), StrToInt64('3500000000'), True)), '2');
end;

procedure TestSuiteDotNet;
begin
  CheckBool('SuiteIsDotNet48Release not there', SuiteIsDotNet48Release(0), False);
  CheckBool('SuiteIsDotNet48Release 4.7.2 (461808)', SuiteIsDotNet48Release(461808), False);
  CheckBool('SuiteIsDotNet48Release just below 4.8', SuiteIsDotNet48Release(528039), False);
  CheckBool('SuiteIsDotNet48Release 4.8 on Windows 10 May 2019 (528040)', SuiteIsDotNet48Release(528040), True);
  CheckBool('SuiteIsDotNet48Release 4.8 on other Windows (528049)', SuiteIsDotNet48Release(528049), True);
  CheckBool('SuiteIsDotNet48Release 4.8.1 (533320)', SuiteIsDotNet48Release(533320), True);
end;

procedure TestSuiteProducts;
begin
  CheckBool('SuiteListHasItem found', SuiteListHasItem('EE,NeoEE', 'NeoEE'), True);
  CheckBool('SuiteListHasItem case and blanks', SuiteListHasItem('EE, neoee', 'NeoEE'), True);
  CheckBool('SuiteListHasItem part of an item', SuiteListHasItem('EE', 'E'), False);
  CheckBool('SuiteListHasItem empty list', SuiteListHasItem('', 'EE'), False);
  CheckBool('SuiteListHasItem empty item', SuiteListHasItem('EE', ''), False);
  Check('SuiteMergeProducts none', SuiteMergeProducts('', ''), '');
  Check('SuiteMergeProducts EE', SuiteMergeProducts('EE', ''), 'EE');
  Check('SuiteMergeProducts NeoEE of the second', SuiteMergeProducts('', 'NeoEE'), 'NeoEE');
  Check('SuiteMergeProducts order', SuiteMergeProducts('NeoEE', 'EE'), 'EE,NeoEE');
  Check('SuiteMergeProducts no duplicates', SuiteMergeProducts('EE, NeoEE', 'ee'), 'EE,NeoEE');
  Check('SuiteMergeProducts drops unknown ids', SuiteMergeProducts('Foo,EE', 'Bar'), 'EE');
  CheckBool('SuiteIsValidProductList EE', SuiteIsValidProductList('EE'), True);
  CheckBool('SuiteIsValidProductList NeoEE', SuiteIsValidProductList('NeoEE'), True);
  CheckBool('SuiteIsValidProductList both', SuiteIsValidProductList('EE,NeoEE'), True);
  CheckBool('SuiteIsValidProductList other order with blank and case', SuiteIsValidProductList('neoee, EE'), True);
  CheckBool('SuiteIsValidProductList empty', SuiteIsValidProductList(''), False);
  CheckBool('SuiteIsValidProductList twice', SuiteIsValidProductList('EE,EE'), False);
  CheckBool('SuiteIsValidProductList unknown', SuiteIsValidProductList('EE,AoC'), False);
  CheckBool('SuiteIsValidProductList all', SuiteIsValidProductList('all'), False);
  CheckBool('SuiteIsValidProductList trailing comma', SuiteIsValidProductList('EE,'), False);
  CheckBool('SuiteIsValidProductList three', SuiteIsValidProductList('EE,NeoEE,EE'), False);
  Check('SuiteUninstallKey', SuiteUninstallKey('00000000-0000-0000-0000-0000000000EE'),
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{00000000-0000-0000-0000-0000000000EE}_is1');
end;

procedure TestSuiteSilentArguments;
begin
  CheckBool('SuiteArgumentsNameTask in /TASKS', SuiteArgumentsNameTask('/TASKS=full,neoee_cdkeys', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask first in /TASKS', SuiteArgumentsNameTask('/TASKS=neoee_cdkeys,full /NOICONS', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask not selected in /MERGETASKS', SuiteArgumentsNameTask('/MERGETASKS=!neoee_cdkeys', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask quoted', SuiteArgumentsNameTask('/TASKS="full,neoee_cdkeys"', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask case', SuiteArgumentsNameTask('/TASKS=NeoEE_CDKeys', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask longer name after', SuiteArgumentsNameTask('/TASKS=neoee_cdkeys2', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask longer name before', SuiteArgumentsNameTask('/TASKS=xneoee_cdkeys', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask in a folder name', SuiteArgumentsNameTask('/DIR=C:\neoee_cdkeys', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask other tasks', SuiteArgumentsNameTask('/TASKS=full,desktopicon', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask in /MERGETASKS', SuiteArgumentsNameTask('/MERGETASKS=!desktopicon,neoee_cdkeys', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask in the second /MERGETASKS', SuiteArgumentsNameTask('/MERGETASKS=a /MERGETASKS=neoee_cdkeys', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask /TASKS after other switches', SuiteArgumentsNameTask('/NOICONS /TASKS=!neoee_cdkeys /X=1', 'neoee_cdkeys'), True);
  CheckBool('SuiteArgumentsNameTask in /COMPONENTS', SuiteArgumentsNameTask('/COMPONENTS=neoee_cdkeys', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask in /LOG', SuiteArgumentsNameTask('/LOG=x,neoee_cdkeys', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask in a quoted /LOG', SuiteArgumentsNameTask('/LOG="C:\a,neoee_cdkeys"', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask in /GROUP', SuiteArgumentsNameTask('/GROUP=neoee_cdkeys', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask switch without a blank before', SuiteArgumentsNameTask('/X=1/TASKS=neoee_cdkeys', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask second item of another switch and /TASKS without it', SuiteArgumentsNameTask('/LOG=a,neoee_cdkeys /TASKS=full', 'neoee_cdkeys'), False);
  CheckBool('SuiteArgumentsNameTask empty', SuiteArgumentsNameTask('', 'neoee_cdkeys'), False);
  Check('SuiteSilentArgumentsProblem NeoEE with the name in /LOG only', IntToStr(SuiteSilentArgumentsProblem('NeoEE', '/LOG=x,neoee_cdkeys')), '2');
  Check('SuiteSilentArgumentsProblem NeoEE with /COMPONENTS only', IntToStr(SuiteSilentArgumentsProblem('NeoEE', '/COMPONENTS=neoee_cdkeys')), '2');
  CheckBool('SuiteCdKeyNotChosen task missing, no result', SuiteCdKeyNotChosen('', True, 'full,desktopicon'), True);
  CheckBool('SuiteCdKeyNotChosen task there', SuiteCdKeyNotChosen('', True, 'full,neoee_cdkeys'), False);
  CheckBool('SuiteCdKeyNotChosen a result is there', SuiteCdKeyNotChosen('0', True, 'full'), False);
  CheckBool('SuiteCdKeyNotChosen tasks unknown', SuiteCdKeyNotChosen('', False, ''), False);
  CheckBool('SuiteCdKeyNotChosen a blank result', SuiteCdKeyNotChosen('  ', True, ''), True);
  Check('SuiteSilentArgumentsProblem nothing', IntToStr(SuiteSilentArgumentsProblem('', '')), '1');
  Check('SuiteSilentArgumentsProblem unknown product', IntToStr(SuiteSilentArgumentsProblem('Foo', '/TASKS=neoee_cdkeys')), '1');
  Check('SuiteSilentArgumentsProblem EE', IntToStr(SuiteSilentArgumentsProblem('EE', '')), '0');
  Check('SuiteSilentArgumentsProblem NeoEE without decision', IntToStr(SuiteSilentArgumentsProblem('NeoEE', '')), '2');
  Check('SuiteSilentArgumentsProblem NeoEE with other tasks', IntToStr(SuiteSilentArgumentsProblem('NeoEE', '/TASKS=full')), '2');
  Check('SuiteSilentArgumentsProblem NeoEE registering', IntToStr(SuiteSilentArgumentsProblem('NeoEE', '/TASKS=full,neoee_cdkeys')), '0');
  Check('SuiteSilentArgumentsProblem both, not registering', IntToStr(SuiteSilentArgumentsProblem('EE,NeoEE', '/MERGETASKS=!neoee_cdkeys')), '0');
  Check('SuiteSilentArgumentsProblem both without decision', IntToStr(SuiteSilentArgumentsProblem('EE,NeoEE', '')), '2');
end;

procedure TestSuitePages;
begin
  Check('SuiteProductState none', IntToStr(SuiteProductState(False, False)), '0');
  Check('SuiteProductState machine', IntToStr(SuiteProductState(True, False)), '1');
  Check('SuiteProductState user only', IntToStr(SuiteProductState(False, True)), '2');
  Check('SuiteProductState machine wins', IntToStr(SuiteProductState(True, True)), '1');
  CheckBool('SuiteCanInstall none', SuiteCanInstall(SuiteStateNone), True);
  CheckBool('SuiteCanInstall machine', SuiteCanInstall(SuiteStateMachine), True);
  CheckBool('SuiteCanInstall user only', SuiteCanInstall(SuiteStateUserOnly), False);

  Check('SuiteSelectedProducts both', SuiteSelectedProducts(True, True, 0, 0), 'EE,NeoEE');
  Check('SuiteSelectedProducts EE', SuiteSelectedProducts(True, False, 0, 0), 'EE');
  Check('SuiteSelectedProducts NeoEE', SuiteSelectedProducts(False, True, 0, 0), 'NeoEE');
  Check('SuiteSelectedProducts nothing ticked', SuiteSelectedProducts(False, False, 0, 0), '');
  Check('SuiteSelectedProducts EE user only', SuiteSelectedProducts(True, True, 2, 0), 'NeoEE');
  Check('SuiteSelectedProducts both user only', SuiteSelectedProducts(True, True, 2, 2), '');
  Check('SuiteSelectedProducts installed counts', SuiteSelectedProducts(True, True, 1, 1), 'EE,NeoEE');

  CheckBool('SuiteLegalAnswerRequired neither', SuiteLegalAnswerRequired(0, 0), True);
  CheckBool('SuiteLegalAnswerRequired EE installed', SuiteLegalAnswerRequired(1, 0), False);
  CheckBool('SuiteLegalAnswerRequired NeoEE installed', SuiteLegalAnswerRequired(0, 1), False);
  CheckBool('SuiteLegalAnswerRequired user only', SuiteLegalAnswerRequired(2, 0), False);
  CheckBool('SuiteLegalPageDone required, no', SuiteLegalPageDone(True, False), False);
  CheckBool('SuiteLegalPageDone required, yes', SuiteLegalPageDone(True, True), True);
  CheckBool('SuiteLegalPageDone not required', SuiteLegalPageDone(False, False), True);

  Check('SuiteButtonName Next', SuiteButtonName('&Next >'), 'Next');
  Check('SuiteButtonName Weiter', SuiteButtonName('&Weiter >'), 'Weiter');
  Check('SuiteButtonName Installieren', SuiteButtonName('&Installieren'), 'Installieren');
  Check('SuiteButtonName Suivant', SuiteButtonName('&Suivant >'), 'Suivant');
  Check('SuiteButtonName plain', SuiteButtonName('Fertigstellen'), 'Fertigstellen');

  Check('SuiteItemResult ok', IntToStr(SuiteItemResult(True, True, 0)), '1');
  Check('SuiteItemResult ok of a repair', IntToStr(SuiteItemResult(True, True, 1)), '1');
  Check('SuiteItemResult failed', IntToStr(SuiteItemResult(False, True, 0)), '2');
  Check('SuiteItemResult not selected', IntToStr(SuiteItemResult(False, False, 0)), '0');
  Check('SuiteItemResult user only', IntToStr(SuiteItemResult(False, False, 2)), '3');
  Check('SuiteItemResult user only though ticked', IntToStr(SuiteItemResult(False, True, 2)), '3');

  Check('SuiteCdKeyKind 0', IntToStr(SuiteCdKeyKind('0')), '0');
  Check('SuiteCdKeyKind 0 with blanks', IntToStr(SuiteCdKeyKind(' 0 ')), '0');
  Check('SuiteCdKeyKind 3', IntToStr(SuiteCdKeyKind('3')), '1');
  Check('SuiteCdKeyKind empty', IntToStr(SuiteCdKeyKind('')), '2');
  Check('SuiteCdKeyKind no number', IntToStr(SuiteCdKeyKind('x')), '2');
end;

procedure TestSuiteRunner;
var
  Log1, Args, Rest: String;
begin
  Log1 := 'C:\Program Files\Empire Earth Community\Logs\EE-20261005-1804.log';

  // the command line: first installation, repair, advanced mode (contract 1.7 point 3)
  Check('SuiteProductArguments first install',
    SuiteProductArguments(True, False, 'de', Log1, ''),
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=de /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /TYPE=full');
  Check('SuiteProductArguments repair has no /TYPE',
    SuiteProductArguments(False, False, 'en', Log1, ''),
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments advanced first install',
    SuiteProductArguments(True, True, 'fr', Log1, ''),
    '/ALLUSERS /LANG=fr /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments advanced repair',
    SuiteProductArguments(False, True, 'fr', Log1, ''),
    '/ALLUSERS /LANG=fr /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');
  Args := SuiteProductArguments(False, False, 'de', Log1, '');
  CheckBool('SuiteProductArguments repair has no /DIR', Pos('/DIR', Args) > 0, False);
  Args := SuiteProductArguments(True, False, 'de', Log1, '');
  CheckBool('SuiteProductArguments first install has no /DIR', Pos('/DIR', Args) > 0, False);
  // /VERYSILENT, never /SILENT as a token of its own: /SILENT would show a progress window per product (the
  // test looks for the token, "/VERYSILENT" contains "SILENT" but not " /SILENT")
  CheckBool('SuiteProductArguments has /VERYSILENT', Pos('/VERYSILENT ', Args) = 1, True);
  CheckBool('SuiteProductArguments never /SILENT', Pos(' /SILENT ', ' ' + Args + ' ') > 0, False);
  Args := SuiteProductArguments(True, True, 'de', Log1, '');
  CheckBool('SuiteProductArguments advanced has no silent switch', (Pos('SILENT', Args) > 0), False);
  Check('SuiteProductArguments language is checked',
    SuiteProductArguments(False, True, 'de /DIR=C:\x', Log1, ''), '/ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');

  // the CI pass-through is appended last
  Check('SuiteProductArguments pass-through appended',
    SuiteProductArguments(True, False, 'en', Log1, '/TASKS=full,!certinclude'),
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 +
      '" /TYPE=full /TASKS=full,!certinclude');
  Check('SuiteProductArguments pass-through with blanks around',
    SuiteProductArguments(False, False, 'en', Log1, '  /X=1  '),
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /X=1');
  Check('SuiteProductArguments pass-through in the advanced mode too',
    SuiteProductArguments(False, True, 'en', Log1, '/X=1'), '/ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /X=1');
  // a /MERGETASKS of the pass-through is merged: one switch only, and the decision on the CD keys survives
  Check('SuiteProductArguments merges /MERGETASKS',
    SuiteProductArguments(False, False, 'en', Log1, '/MERGETASKS=!neoee_cdkeys'),
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon,!neoee_cdkeys" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments merges a quoted /MERGETASKS and keeps the rest',
    SuiteProductArguments(True, False, 'en', Log1, '/TASKS=full /MERGETASKS="!neoee_cdkeys,!certinclude" /X=1'),
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon,!neoee_cdkeys,!certinclude" /LOG="' + Log1 +
      '" /TYPE=full /TASKS=full /X=1');
  Check('SuiteProductArguments merges two /MERGETASKS',
    SuiteProductArguments(False, True, 'en', Log1, '/MERGETASKS=a /MERGETASKS=b'),
    '/ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon,a,b" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments /TYPE of the pass-through replaces /TYPE=full',
    SuiteProductArguments(True, False, 'en', Log1, '/TYPE=compact'),
    '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /TYPE=compact');

  // the quoting of a value
  Check('SuiteQuoteArgument path with blanks', SuiteQuoteArgument('C:\Program Files\x.log'), '"C:\Program Files\x.log"');
  Check('SuiteQuoteArgument quote removed', SuiteQuoteArgument('C:\a"b'), '"C:\ab"');
  Check('SuiteQuoteArgument trailing backslash doubled', SuiteQuoteArgument('C:\Logs\'), '"C:\Logs\\"');
  Check('SuiteQuoteArgument empty', SuiteQuoteArgument(''), '""');
  Check('SuiteLanguageArgument de', SuiteLanguageArgument('de'), 'de');
  Check('SuiteLanguageArgument pt_BR', SuiteLanguageArgument('pt_BR'), 'pt_BR');
  Check('SuiteLanguageArgument empty', SuiteLanguageArgument(''), 'en');
  Check('SuiteLanguageArgument with a blank', SuiteLanguageArgument('de fr'), 'en');
  Check('SuiteLanguageArgument with a slash', SuiteLanguageArgument('de/DIR'), 'en');

  // taking switches out of an argument string
  Args := '/A=1 /MERGETASKS=x /B=2';
  Check('SuiteTakeSwitchValues value', SuiteTakeSwitchValues(Args, '/MERGETASKS='), 'x');
  Check('SuiteTakeSwitchValues rest', Args, '/A=1 /B=2');
  Args := '/DIR=C:\x/MERGETASKS=y';
  Check('SuiteTakeSwitchValues inside another value', SuiteTakeSwitchValues(Args, '/MERGETASKS='), '');
  Check('SuiteTakeSwitchValues inside another value, untouched', Args, '/DIR=C:\x/MERGETASKS=y');
  Args := '/mergetasks=a';
  Check('SuiteTakeSwitchValues case', SuiteTakeSwitchValues(Args, '/MERGETASKS='), 'a');
  Check('SuiteTakeSwitchValues case, rest', Args, '');
  Args := '/MERGETASKS=';
  Check('SuiteTakeSwitchValues empty value', SuiteTakeSwitchValues(Args, '/MERGETASKS='), '');
  Check('SuiteTakeSwitchValues empty value, rest', Args, '');
  Args := '/MERGETASKS=a /B=2 /MERGETASKS=b';
  Check('SuiteTakeSwitchValues first and last', SuiteTakeSwitchValues(Args, '/MERGETASKS='), 'a,b');
  Check('SuiteTakeSwitchValues first and last, rest', Args, '/B=2');
  Args := '/MERGETASKS="a b"';
  Check('SuiteTakeSwitchValues quoted blank', SuiteTakeSwitchValues(Args, '/MERGETASKS='), 'a b');
  Rest := '/MERGETASKS="open';
  Check('SuiteTakeSwitchValues unclosed quote', SuiteTakeSwitchValues(Rest, '/MERGETASKS='), 'open');
  Check('SuiteTakeSwitchValues unclosed quote, rest', Rest, '');

  CheckBool('SuiteIsFirstInstall none', SuiteIsFirstInstall(SuiteStateNone), True);
  CheckBool('SuiteIsFirstInstall machine', SuiteIsFirstInstall(SuiteStateMachine), False);
  Check('SuiteChildLogName', SuiteChildLogName('NeoEE', '20261005-1804'), 'NeoEE-20261005-1804.log');

  // exit codes and success
  Check('SuiteChildExitKind 0', IntToStr(SuiteChildExitKind(0)), '0');
  Check('SuiteChildExitKind 1 (a game runs)', IntToStr(SuiteChildExitKind(1)), '1');
  Check('SuiteChildExitKind 2', IntToStr(SuiteChildExitKind(2)), '2');
  Check('SuiteChildExitKind 3', IntToStr(SuiteChildExitKind(3)), '3');
  Check('SuiteChildExitKind 4', IntToStr(SuiteChildExitKind(4)), '3');
  Check('SuiteChildExitKind 5', IntToStr(SuiteChildExitKind(5)), '2');
  Check('SuiteChildExitKind 6', IntToStr(SuiteChildExitKind(6)), '3');
  Check('SuiteChildExitKind 7', IntToStr(SuiteChildExitKind(7)), '4');
  Check('SuiteChildExitKind 8', IntToStr(SuiteChildExitKind(8)), '4');
  Check('SuiteChildExitKind 9', IntToStr(SuiteChildExitKind(9)), '5');
  Check('SuiteChildExitKind negative', IntToStr(SuiteChildExitKind(-1073741819)), '5');
  CheckBool('SuiteRunSucceeded 0 and entry', SuiteRunSucceeded(True, 0, True), True);
  CheckBool('SuiteRunSucceeded 0 without entry', SuiteRunSucceeded(True, 0, False), False);
  CheckBool('SuiteRunSucceeded entry of an earlier run, exit 1', SuiteRunSucceeded(True, 1, True), False);
  CheckBool('SuiteRunSucceeded exit 3 with entry', SuiteRunSucceeded(True, 3, True), False);
  CheckBool('SuiteRunSucceeded not started', SuiteRunSucceeded(False, 0, True), False);

  // the pins of the embedded setups
  CheckBool('SuitePinMatches equal', SuitePinMatches('ABCDEF0123', 'abcdef0123', 100, 100), True);
  CheckBool('SuitePinMatches blanks around', SuitePinMatches(' abcdef0123 ', 'abcdef0123', 100, 100), True);
  CheckBool('SuitePinMatches other hash', SuitePinMatches('abcdef0124', 'abcdef0123', 100, 100), False);
  CheckBool('SuitePinMatches other size', SuitePinMatches('abcdef0123', 'abcdef0123', 101, 100), False);
  CheckBool('SuitePinMatches empty pin', SuitePinMatches('', '', 100, 100), False);
  CheckBool('SuitePinMatches above 4 GB', SuitePinMatches('a', 'a', StrToInt64('5000000000'), StrToInt64('5000000000')), True);

  // the CD key line of the log of the NeoEE setup
  Check('SuiteParseCdKeyResult registered',
    SuiteParseCdKeyResult('2026-10-05 18:04:31.123   CD Keys generation result: 0' + #13#10 + '2026-10-05 18:04:31.200   CD Keys registered'), '0');
  Check('SuiteParseCdKeyResult network', SuiteParseCdKeyResult('x' + #13#10 + 'CD Keys generation result: 3' + #13#10 + 'y'), '3');
  Check('SuiteParseCdKeyResult only LF', SuiteParseCdKeyResult('a' + #10 + 'CD Keys generation result: 1' + #10 + 'b'), '1');
  Check('SuiteParseCdKeyResult no line', SuiteParseCdKeyResult('Setup started' + #13#10 + 'CD Keys registered'), '');
  Check('SuiteParseCdKeyResult empty log', SuiteParseCdKeyResult(''), '');
  Check('SuiteParseCdKeyResult line without a number', SuiteParseCdKeyResult('CD Keys generation result:'), '');
  Check('SuiteParseCdKeyResult text instead of a number', SuiteParseCdKeyResult('CD Keys generation result: ok'), '');
  Check('SuiteParseCdKeyResult last valid line wins',
    SuiteParseCdKeyResult('CD Keys generation result: 3' + #13#10 + 'CD Keys generation result: 0'), '0');
  Check('SuiteParseCdKeyResult a broken last line is ignored',
    SuiteParseCdKeyResult('CD Keys generation result: 2' + #13#10 + 'CD Keys generation result: x'), '2');
  Check('SuiteParseCdKeyResult case', SuiteParseCdKeyResult('cd keys GENERATION result: 4'), '4');
  Check('SuiteParseCdKeyResult blanks and tab', SuiteParseCdKeyResult('CD Keys generation result:' + #9 + '  5  (more)'), '5');
  Check('SuiteParseCdKeyResult negative', SuiteParseCdKeyResult('CD Keys generation result: -1'), '-1');
  Check('SuiteParseCdKeyResult minus only', SuiteParseCdKeyResult('CD Keys generation result: -'), '');
  Check('SuiteParseCdKeyResult long number is cut', SuiteParseCdKeyResult('CD Keys generation result: 12345678901234'), '123456789');
  Check('SuiteCdKeyKind of a parsed negative', IntToStr(SuiteCdKeyKind(SuiteParseCdKeyResult('CD Keys generation result: -1'))), '2');
  Check('SuiteCdKeyKind of the parsed 0', IntToStr(SuiteCdKeyKind(SuiteParseCdKeyResult('CD Keys generation result: 0'))), '0');

  // the old shortcuts of a standalone setup: exactly these paths (contract 1.7 point 7)
  Check('SuiteProductAppName EE', SuiteProductAppName('EE'), 'Empire Earth');
  Check('SuiteProductAppName NeoEE', SuiteProductAppName('NeoEE'), 'NeoEE');
  Check('SuiteProductAppName unknown', SuiteProductAppName('AoC'), '');
  Check('SuiteLegacyShortcutPath EE 1', SuiteLegacyShortcutPath('EE', 1, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Programs\Empire Earth'),
    'C:\Users\Public\Desktop\Empire Earth.lnk');
  Check('SuiteLegacyShortcutPath EE 2', SuiteLegacyShortcutPath('EE', 2, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Programs\Empire Earth'),
    'C:\Users\Public\Desktop\Empire Earth - AoC.lnk');
  Check('SuiteLegacyShortcutPath EE 3', SuiteLegacyShortcutPath('EE', 3, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Programs\Empire Earth'),
    'C:\ProgramData\Start\Programs\Empire Earth\Empire Earth.lnk');
  Check('SuiteLegacyShortcutPath EE 4', SuiteLegacyShortcutPath('EE', 4, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Programs\Empire Earth'),
    'C:\ProgramData\Start\Programs\Empire Earth\Empire Earth - AoC.lnk');
  Check('SuiteLegacyShortcutPath EE 5', SuiteLegacyShortcutPath('EE', 5, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Programs\Empire Earth'),
    'C:\ProgramData\Start\Programs\Empire Earth\Empire Earth Diagnostic.lnk');
  Check('SuiteLegacyShortcutPath NeoEE 1', SuiteLegacyShortcutPath('NeoEE', 1, 'D:\Desk\', 'D:\Start\Empire Earth\'), 'D:\Desk\NeoEE.lnk');
  Check('SuiteLegacyShortcutPath NeoEE 2', SuiteLegacyShortcutPath('NeoEE', 2, 'D:\Desk\', 'D:\Start\Empire Earth\'), 'D:\Desk\NeoEE - AoC.lnk');
  Check('SuiteLegacyShortcutPath NeoEE 3', SuiteLegacyShortcutPath('NeoEE', 3, 'D:\Desk\', 'D:\Start\Empire Earth\'), 'D:\Start\Empire Earth\NeoEE.lnk');
  Check('SuiteLegacyShortcutPath NeoEE 4', SuiteLegacyShortcutPath('NeoEE', 4, 'D:\Desk\', 'D:\Start\Empire Earth\'), 'D:\Start\Empire Earth\NeoEE - AoC.lnk');
  Check('SuiteLegacyShortcutPath NeoEE 5', SuiteLegacyShortcutPath('NeoEE', 5, 'D:\Desk\', 'D:\Start\Empire Earth\'), 'D:\Start\Empire Earth\NeoEE Diagnostic.lnk');
  Check('SuiteLegacyShortcutPath index 0', SuiteLegacyShortcutPath('EE', 0, 'D:\Desk', 'D:\Start'), '');
  Check('SuiteLegacyShortcutPath index 6', SuiteLegacyShortcutPath('EE', SuiteLegacyShortcutCount + 1, 'D:\Desk', 'D:\Start'), '');
  Check('SuiteLegacyShortcutPath unknown product', SuiteLegacyShortcutPath('AoC', 1, 'D:\Desk', 'D:\Start'), '');
  Check('SuiteLegacyShortcutCount', IntToStr(SuiteLegacyShortcutCount), '5');

  // the shortcuts of suite 1.0.0 that suite 1.1.0 deletes: exactly these paths (contract 1.7 point 8)
  Check('SuiteOldSuiteShortcutPath 1', SuiteOldSuiteShortcutPath(1, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Empire Earth Community'),
    'C:\Users\Public\Desktop\Empire Earth.lnk');
  Check('SuiteOldSuiteShortcutPath 2', SuiteOldSuiteShortcutPath(2, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Empire Earth Community'),
    'C:\Users\Public\Desktop\Neo Empire Earth.lnk');
  Check('SuiteOldSuiteShortcutPath 3', SuiteOldSuiteShortcutPath(3, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Empire Earth Community'),
    'C:\ProgramData\Start\Empire Earth Community\Empire Earth.lnk');
  Check('SuiteOldSuiteShortcutPath 4', SuiteOldSuiteShortcutPath(4, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Empire Earth Community'),
    'C:\ProgramData\Start\Empire Earth Community\Neo Empire Earth.lnk');
  Check('SuiteOldSuiteShortcutPath 5', SuiteOldSuiteShortcutPath(5, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Empire Earth Community'),
    'C:\ProgramData\Start\Empire Earth Community\Empire Earth Diagnostic.lnk');
  Check('SuiteOldSuiteShortcutPath 6', SuiteOldSuiteShortcutPath(6, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Empire Earth Community'),
    'C:\ProgramData\Start\Empire Earth Community\Neo Empire Earth Diagnostic.lnk');
  Check('SuiteOldSuiteShortcutPath 7', SuiteOldSuiteShortcutPath(7, 'C:\Users\Public\Desktop', 'C:\ProgramData\Start\Empire Earth Community'),
    'C:\ProgramData\Start\Empire Earth Community\Empire Earth Launcher.lnk');
  Check('SuiteOldSuiteShortcutPath folders with a backslash', SuiteOldSuiteShortcutPath(4, 'D:\Desk\', 'D:\Start\Empire Earth Community\'),
    'D:\Start\Empire Earth Community\Neo Empire Earth.lnk');
  Check('SuiteOldSuiteShortcutPath index 0', SuiteOldSuiteShortcutPath(0, 'D:\Desk', 'D:\Start'), '');
  Check('SuiteOldSuiteShortcutPath index 8', SuiteOldSuiteShortcutPath(SuiteOldSuiteShortcutCount + 1, 'D:\Desk', 'D:\Start'), '');
  Check('SuiteOldSuiteShortcutCount', IntToStr(SuiteOldSuiteShortcutCount), '7');
  CheckBool('SuiteOldSuiteShortcutRemovable 1 that starts the launcher', SuiteOldSuiteShortcutRemovable(1, True), True);
  CheckBool('SuiteOldSuiteShortcutRemovable 1 that starts a game program', SuiteOldSuiteShortcutRemovable(1, False), False);
  CheckBool('SuiteOldSuiteShortcutRemovable 2 with the launcher', SuiteOldSuiteShortcutRemovable(2, True), True);
  CheckBool('SuiteOldSuiteShortcutRemovable 2 without it', SuiteOldSuiteShortcutRemovable(2, False), True);
  CheckBool('SuiteOldSuiteShortcutRemovable 7 without it', SuiteOldSuiteShortcutRemovable(7, False), True);
  CheckBool('SuiteOldSuiteShortcutRemovable 0', SuiteOldSuiteShortcutRemovable(0, True), False);
  CheckBool('SuiteOldSuiteShortcutRemovable 8', SuiteOldSuiteShortcutRemovable(SuiteOldSuiteShortcutCount + 1, True), False);

  // the product the one shortcut starts without .NET Framework 4.8
  Check('SuiteFirstInstalledProduct both, NeoEE first', SuiteFirstInstalledProduct('NeoEE,EE', True, True), 'NeoEE');
  Check('SuiteFirstInstalledProduct only EE', SuiteFirstInstalledProduct('NeoEE,EE', True, False), 'EE');
  Check('SuiteFirstInstalledProduct only NeoEE', SuiteFirstInstalledProduct('NeoEE,EE', False, True), 'NeoEE');
  Check('SuiteFirstInstalledProduct none', SuiteFirstInstalledProduct('NeoEE,EE', False, False), '');
  Check('SuiteFirstInstalledProduct the order of the list', SuiteFirstInstalledProduct('EE,NeoEE', True, True), 'EE');
  Check('SuiteFirstInstalledProduct one id', SuiteFirstInstalledProduct('EE', True, True), 'EE');
  Check('SuiteFirstInstalledProduct one id that is not installed', SuiteFirstInstalledProduct('EE', False, True), '');
  Check('SuiteFirstInstalledProduct unknown id is skipped', SuiteFirstInstalledProduct('AoC,NeoEE', True, True), 'NeoEE');
  Check('SuiteFirstInstalledProduct only unknown ids', SuiteFirstInstalledProduct('AoC,GOG', True, True), '');
  Check('SuiteFirstInstalledProduct lower case and blanks', SuiteFirstInstalledProduct(' neoee , ee', False, True), 'NeoEE');
  Check('SuiteFirstInstalledProduct empty list', SuiteFirstInstalledProduct('', True, True), '');
end;

procedure CheckWait(const Name: String; KeyPresent, ExeExists: Boolean; ElapsedMs, Expected: Integer);
begin
  Check('SuiteUninstallWaitState ' + Name, IntToStr(SuiteUninstallWaitState(KeyPresent, ExeExists, ElapsedMs)), IntToStr(Expected));
end;

// The link check on folders without a link (Wine cannot make junctions, see the skipped test of
// FindLinksInGameFolder): a folder, a folder below another, a file's folder that does not exist
procedure TestSuiteLinks;
var
  Root, Sub: String;
begin
  Root := ExpandConstant('{tmp}\suite_links');
  Sub := Root + '\Empire Earth\Users';
  ForceDirectories(Sub);
  CheckBool('SuiteIsReparsePoint plain folder', SuiteIsReparsePoint(Sub), False);
  CheckBool('SuiteIsReparsePoint folder with backslash', SuiteIsReparsePoint(Sub + '\'), False);
  CheckBool('SuiteIsReparsePoint missing folder', SuiteIsReparsePoint(Root + '\none'), False);
  CheckBool('SuiteIsBehindLink plain folders up to the root', SuiteIsBehindLink(Sub, Root), False);
  CheckBool('SuiteIsBehindLink the root itself', SuiteIsBehindLink(Root, Root), False);
  CheckBool('SuiteIsBehindLink missing folder', SuiteIsBehindLink(Root + '\none\x', Root), False);
  CheckBool('SuiteIsBehindLink drive only', SuiteIsBehindLink('C:\', 'C:\'), False);
  CheckBool('SuiteIsBehindLink empty', SuiteIsBehindLink('', Root), False);
  RemoveDir(Sub);
  RemoveDir(Root + '\Empire Earth');
  RemoveDir(Root);
  CheckBool('SuiteLinkTextNamesFile ANSI path', SuiteLinkTextNamesFile('xx C:\Program Files\Empire Earth Community\Empire Earth Launcher.exe' + #0 + 'yy', 'Empire Earth Launcher.exe'), True);
  CheckBool('SuiteLinkTextNamesFile Unicode path', SuiteLinkTextNamesFile('E'#0'm'#0'p'#0'i'#0'r'#0'e'#0' '#0'E'#0'a'#0'r'#0't'#0'h'#0' '#0'L'#0'a'#0'u'#0'n'#0'c'#0'h'#0'e'#0'r'#0'.'#0'e'#0'x'#0'e'#0, 'Empire Earth Launcher.exe'), True);
  CheckBool('SuiteLinkTextNamesFile other case', SuiteLinkTextNamesFile('c:\x\EMPIRE EARTH LAUNCHER.EXE', 'Empire Earth Launcher.exe'), True);
  CheckBool('SuiteLinkTextNamesFile the game program', SuiteLinkTextNamesFile('C:\Games\EE\Empire Earth\Empire Earth.exe', 'Empire Earth Launcher.exe'), False);
  CheckBool('SuiteLinkTextNamesFile empty content', SuiteLinkTextNamesFile('', 'Empire Earth Launcher.exe'), False);
  CheckBool('SuiteLinkTextNamesFile empty name', SuiteLinkTextNamesFile('abc', ''), False);
end;

procedure TestSuiteUninstaller;
var
  I: Integer;
  Seen: String;
begin
  // the wait for a product uninstaller: the key and the program file decide, the exit code never does
  CheckWait('key there, in time', True, True, 1000, SuiteWaitKeep);
  CheckWait('key there, no program file, in time', True, False, 1000, SuiteWaitKeep);
  CheckWait('key there, just before the timeout', True, True, SuiteUninstallTimeoutMs - 1, SuiteWaitKeep);
  CheckWait('key there, at the timeout', True, True, SuiteUninstallTimeoutMs, SuiteWaitTimedOut);
  CheckWait('key there, program file gone, at the timeout', True, False, SuiteUninstallTimeoutMs + 5000, SuiteWaitTimedOut);
  CheckWait('key gone, program file gone', False, False, 2000, SuiteWaitDone);
  CheckWait('key gone at once', False, False, 0, SuiteWaitDone);
  CheckWait('key gone, program file there, 40 seconds', False, True, 40000, SuiteWaitKeep);
  CheckWait('key gone, program file there, several minutes (a large game, a slow disk)', False, True, 300000, SuiteWaitKeep);
  CheckWait('key gone, program file there, just before the timeout', False, True, SuiteUninstallTimeoutMs - 1, SuiteWaitKeep);
  CheckWait('key gone, program file there, at the timeout', False, True, SuiteUninstallTimeoutMs, SuiteWaitDoneExeLeft);
  CheckWait('key gone, program file gone after the timeout', False, False, SuiteUninstallTimeoutMs + 1000, SuiteWaitDone);
  Check('SuiteUninstallTimeoutMs is 10 minutes', IntToStr(SuiteUninstallTimeoutMs), '600000');
  Check('SuiteUninstallPollMs divides the timeout', IntToStr(SuiteUninstallTimeoutMs mod SuiteUninstallPollMs), '0');

  Check('SuiteUninstallOutcome done', IntToStr(SuiteUninstallOutcome(True, SuiteWaitDone)), IntToStr(SuiteRemoveOk));
  Check('SuiteUninstallOutcome program file left', IntToStr(SuiteUninstallOutcome(True, SuiteWaitDoneExeLeft)), IntToStr(SuiteRemoveOk));
  Check('SuiteUninstallOutcome timeout', IntToStr(SuiteUninstallOutcome(True, SuiteWaitTimedOut)), IntToStr(SuiteRemoveTimedOut));
  Check('SuiteUninstallOutcome still waiting', IntToStr(SuiteUninstallOutcome(True, SuiteWaitKeep)), IntToStr(SuiteRemoveTimedOut));
  Check('SuiteUninstallOutcome not started', IntToStr(SuiteUninstallOutcome(False, SuiteWaitDone)), IntToStr(SuiteRemoveNotStarted));

  Check('SuiteUninstallProduct 1', SuiteUninstallProduct(1), 'NeoEE');
  Check('SuiteUninstallProduct 2', SuiteUninstallProduct(2), 'EE');
  Check('SuiteUninstallProduct 0', SuiteUninstallProduct(0), '');
  Check('SuiteUninstallProduct 3', SuiteUninstallProduct(3), '');

  // the program file of an uninstall entry
  Check('SuiteUninstallExe quoted', SuiteUninstallExe('"C:\Program Files (x86)\Empire Earth\unins000.exe"'), 'C:\Program Files (x86)\Empire Earth\unins000.exe');
  Check('SuiteUninstallExe quoted with blanks around', SuiteUninstallExe('  "D:\Games\EE\unins001.exe"  '), 'D:\Games\EE\unins001.exe');
  Check('SuiteUninstallExe unquoted', SuiteUninstallExe('D:\Games\EE\unins000.exe'), 'D:\Games\EE\unins000.exe');
  Check('SuiteUninstallExe unterminated quote', SuiteUninstallExe('"D:\Games\EE\unins000.exe'), 'D:\Games\EE\unins000.exe');
  Check('SuiteUninstallExe with arguments after the quotes', SuiteUninstallExe('"D:\Games\EE\unins000.exe" /SILENT'), 'D:\Games\EE\unins000.exe');
  Check('SuiteUninstallExe empty', SuiteUninstallExe(''), '');
  Check('SuiteUninstallExe blank', SuiteUninstallExe('   '), '');
  Check('SuiteUninstallExe two quotes', SuiteUninstallExe('""'), '');

  // only an Inno Setup uninstaller inside the root is run
  CheckBool('SuiteIsProductUninstaller with ..', SuiteIsProductUninstaller('C:\Games\EE\..\..\x\unins000.exe', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller with .. inside the root', SuiteIsProductUninstaller('C:\Games\EE\a\..\unins000.exe', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller default', SuiteIsProductUninstaller('C:\Games\EE\unins000.exe', 'C:\Games\EE'), True);
  CheckBool('SuiteIsProductUninstaller second', SuiteIsProductUninstaller('C:\Games\EE\unins001.exe', 'C:\Games\EE'), True);
  CheckBool('SuiteIsProductUninstaller case and trailing backslash', SuiteIsProductUninstaller('c:\games\ee\UNINS000.EXE', 'C:\Games\EE\'), True);
  CheckBool('SuiteIsProductUninstaller below the root', SuiteIsProductUninstaller('C:\Games\EE\_setupdata_EE\unins000.exe', 'C:\Games\EE'), True);
  CheckBool('SuiteIsProductUninstaller outside the root', SuiteIsProductUninstaller('C:\Windows\System32\unins000.exe', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller sibling folder', SuiteIsProductUninstaller('C:\Games\EE2\unins000.exe', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller other program', SuiteIsProductUninstaller('C:\Games\EE\cmd.exe', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller not an exe', SuiteIsProductUninstaller('C:\Games\EE\unins000.dat', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller the game', SuiteIsProductUninstaller('C:\Games\EE\Empire Earth\Empire Earth.exe', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller the root itself', SuiteIsProductUninstaller('C:\Games\EE', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller empty root', SuiteIsProductUninstaller('C:\Games\EE\unins000.exe', ''), False);
  CheckBool('SuiteIsProductUninstaller empty file', SuiteIsProductUninstaller('', 'C:\Games\EE'), False);
  CheckBool('SuiteIsProductUninstaller with arguments', SuiteIsProductUninstaller('C:\Games\EE\unins000.exe /x', 'C:\Games\EE'), False);

  // roots the uninstaller works below
  CheckBool('SuiteIsUsableRoot program files', SuiteIsUsableRoot('C:\Program Files (x86)\Empire Earth'), True);
  CheckBool('SuiteIsUsableRoot one level', SuiteIsUsableRoot('D:\Games'), True);
  CheckBool('SuiteIsUsableRoot trailing backslash', SuiteIsUsableRoot('D:\Games\'), True);
  CheckBool('SuiteIsUsableRoot drive', SuiteIsUsableRoot('C:\'), False);
  CheckBool('SuiteIsUsableRoot drive without backslash', SuiteIsUsableRoot('C:'), False);
  CheckBool('SuiteIsUsableRoot empty', SuiteIsUsableRoot(''), False);
  CheckBool('SuiteIsUsableRoot relative', SuiteIsUsableRoot('Games\EE'), False);
  CheckBool('SuiteIsUsableRoot parent folder', SuiteIsUsableRoot('C:\Games\..\Windows'), False);
  CheckBool('SuiteIsUsableRoot network path', SuiteIsUsableRoot('\\server\share\EE'), False);

  // the exact folders of the user data of a product (6 values, nothing else)
  Check('SuiteDataFolderCount', IntToStr(SuiteDataFolderCount), '6');
  Check('SuiteDataFolder 1', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 1), 'C:\Program Files (x86)\Empire Earth\Empire Earth\Users');
  Check('SuiteDataFolder 2', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 2), 'C:\Program Files (x86)\Empire Earth\Empire Earth\Data\Saved Games');
  Check('SuiteDataFolder 3', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 3),
    'C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\Users');
  Check('SuiteDataFolder 4', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 4),
    'C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\Data\Saved Games');
  Check('SuiteDataFolder 5', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 5), 'C:\Program Files (x86)\Empire Earth\Empire Earth\Data\dxm\mods');
  Check('SuiteDataFolder 6', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 6),
    'C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\Data\dxm\mods');
  Check('SuiteDataFolder trailing backslash', SuiteDataFolder('D:\EE\', 1), 'D:\EE\Empire Earth\Users');
  Check('SuiteDataFolder index 0', SuiteDataFolder('D:\EE', 0), '');
  Check('SuiteDataFolder index 7', SuiteDataFolder('D:\EE', SuiteDataFolderCount + 1), '');
  Check('SuiteDataFolder drive root', SuiteDataFolder('D:\', 1), '');
  Check('SuiteDataFolder empty root', SuiteDataFolder('', 2), '');
  Check('SuiteDataFolder parent folder', SuiteDataFolder('D:\EE\..\..', 1), '');
  Seen := '';
  for I := 1 to SuiteDataFolderCount do
    Seen := Seen + SuiteDataFolder('D:\EE', I) + '|';
  Check('SuiteDataFolder all different', IntToStr(Pos('D:\EE\Empire Earth\Users|D:\EE\Empire Earth\Data\Saved Games|D:\EE\Empire Earth - The Art of Conquest\Users|D:\EE\Empire Earth - The Art of Conquest\Data\Saved Games|D:\EE\Empire Earth\Data\dxm\mods|D:\EE\Empire Earth - The Art of Conquest\Data\dxm\mods|', Seen)), '1');

  // the folders removed only if empty, from the inside out, the root last
  Check('SuiteEmptyFolderCount', IntToStr(SuiteEmptyFolderCount), '7');
  Check('SuiteEmptyFolder 1', SuiteEmptyFolder('D:\EE', 1), 'D:\EE\Empire Earth\Data\dxm');
  Check('SuiteEmptyFolder 2', SuiteEmptyFolder('D:\EE', 2), 'D:\EE\Empire Earth\Data');
  Check('SuiteEmptyFolder 3', SuiteEmptyFolder('D:\EE', 3), 'D:\EE\Empire Earth');
  Check('SuiteEmptyFolder 4', SuiteEmptyFolder('D:\EE', 4), 'D:\EE\Empire Earth - The Art of Conquest\Data\dxm');
  Check('SuiteEmptyFolder 5', SuiteEmptyFolder('D:\EE', 5), 'D:\EE\Empire Earth - The Art of Conquest\Data');
  Check('SuiteEmptyFolder 6', SuiteEmptyFolder('D:\EE', 6), 'D:\EE\Empire Earth - The Art of Conquest');
  Check('SuiteEmptyFolder 7', SuiteEmptyFolder('D:\EE\', 7), 'D:\EE');
  Check('SuiteEmptyFolder index 8', SuiteEmptyFolder('D:\EE', SuiteEmptyFolderCount + 1), '');
  Check('SuiteEmptyFolder drive root', SuiteEmptyFolder('D:\', 7), '');
  Check('SuiteEmptyFolder empty root', SuiteEmptyFolder('', 7), '');

  // the data folder of the launcher
  Check('SuiteLauncherDataDir', SuiteLauncherDataDir('C:\Users\Anna\AppData\Local'), 'C:\Users\Anna\AppData\Local\Empire Earth Launcher');
  Check('SuiteLauncherDataDir trailing backslash', SuiteLauncherDataDir('C:\Users\Anna\AppData\Local\'), 'C:\Users\Anna\AppData\Local\Empire Earth Launcher');
  Check('SuiteLauncherDataDir empty', SuiteLauncherDataDir(''), '');
  Check('SuiteLauncherDataDir relative', SuiteLauncherDataDir('Local'), '');
  Check('SuiteLauncherFileCount', IntToStr(SuiteLauncherFileCount), '2');
  Check('SuiteLauncherDataFile 1', SuiteLauncherDataFile('C:\U\Local', 1), 'C:\U\Local\Empire Earth Launcher\settings.json');
  Check('SuiteLauncherDataFile 2', SuiteLauncherDataFile('C:\U\Local', 2), 'C:\U\Local\Empire Earth Launcher\log.txt');
  Check('SuiteLauncherDataFile 0', SuiteLauncherDataFile('C:\U\Local', 0), '');
  Check('SuiteLauncherDataFile 3', SuiteLauncherDataFile('C:\U\Local', SuiteLauncherFileCount + 1), '');
  Check('SuiteLauncherDataFile empty folder', SuiteLauncherDataFile('', 1), '');
  Check('SuiteLauncherFolderCount', IntToStr(SuiteLauncherFolderCount), '2');
  Check('SuiteLauncherDataFolder 1', SuiteLauncherDataFolder('C:\U\Local', 1), 'C:\U\Local\Empire Earth Launcher\Backups');
  Check('SuiteLauncherDataFolder 2', SuiteLauncherDataFolder('C:\U\Local', 2), 'C:\U\Local\Empire Earth Launcher\Mod Creator');
  Check('SuiteLauncherDataFolder 0', SuiteLauncherDataFolder('C:\U\Local', 0), '');
  Check('SuiteLauncherDataFolder 3', SuiteLauncherDataFolder('C:\U\Local', SuiteLauncherFolderCount + 1), '');
  Check('SuiteLauncherDataFolder empty folder', SuiteLauncherDataFolder('', 1), '');
end;

// ---- the progress of a product setup, read from its log (S3) -----------------------------------------

// A line of a product log as Inno Setup writes it: 23 characters of time stamp, three blanks, the text. The
// time stamps of the excerpts below are those of the laptop test 2026-10-06 (their paths are made neutral).
function SuiteTestLine(const Text: String): String;
begin
  Result := '2026-10-06 21:31:58.478   ' + Text;
end;

// Feeds the lines (the text of each without time stamp) like a tail that read them whole
procedure SuiteTestFeed(var P: TSuiteProgress; const Texts: array of String);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(Texts) - 1 do
    SuiteFeedLogChunk(P, SuiteTestLine(Texts[I]) + #13#10);
end;

// The phase after the single line Text of a log that has just been opened
function SuiteTestPhaseAfter(const Text: String): Integer;
var
  P: TSuiteProgress;
begin
  SuiteProgressInit(P, 'EE');
  SuiteFeedLogLine(P, SuiteTestLine(Text));
  Result := P.Phase;
end;

procedure TestSuiteProgress;
var
  P, Q: TSuiteProgress;
  Crlf, Bom, Blanks, DoneText, TotalText: String;
  I, Sum: Integer;
begin
  Crlf := #13#10;

  // the start
  SuiteProgressInit(P, 'EE');
  Check('SuiteProgressInit phase', IntToStr(P.Phase), IntToStr(SuitePhaseStart));
  Check('SuiteProgressInit estimate EE', IntToStr(P.InstallEstimate), '2260');
  Check('SuiteProgressPermille at the start', IntToStr(SuiteProgressPermille(P)), '0');
  CheckBool('SuiteProgressInstalling at the start', SuiteProgressInstalling(P), False);
  SuiteProgressInit(Q, 'NeoEE');
  Check('SuiteProgressInit estimate NeoEE', IntToStr(Q.InstallEstimate), '2697');
  SuiteProgressInit(Q, 'AoC');
  Check('SuiteProgressInit estimate of another product', IntToStr(Q.InstallEstimate), IntToStr(SuiteInstallEstimateOther));
  Check('SuiteInstallEstimate lower case', IntToStr(SuiteInstallEstimate('neoee')), '2697');

  // the weights add up to 100 (percent)
  Sum := SuiteWeightPrepare + SuiteWeightDownload + SuiteWeightVerify + SuiteWeightInstall + SuiteWeightPost;
  Check('the weights of the blocks add up to 100', IntToStr(Sum), '100');

  // every marker sets its phase (each line is the text of the real log line)
  Check('marker probe', IntToStr(SuiteTestPhaseAfter('Online files server https://files.empireearth.eu/localized: answers only without certificate validation (HTTP 200); pinned files are downloaded from it with WinHTTP')),
    IntToStr(SuitePhaseProbe));
  Check('marker probe, no answer', IntToStr(SuiteTestPhaseAfter('Online files server https://storage.ee.zocker-160.de/localized: no answer, neither with nor without certificate validation')),
    IntToStr(SuitePhaseProbe));
  Check('marker download count', IntToStr(SuiteTestPhaseAfter('Downloading 17 online files, one at a time')), IntToStr(SuitePhaseDownload));
  Check('marker download of a file',
    IntToStr(SuiteTestPhaseAfter('Downloading pinned online file without certificate validation (WinHTTP) from https://files.empireearth.eu/localized/Game/de/EE/Language.dll: C:\T\is-AAAAA.tmp\EE\Language.dll')),
    IntToStr(SuitePhaseDownload));
  Check('marker verify, the end of the downloads',
    IntToStr(SuiteTestPhaseAfter('Online files: 0 downloaded with validated TLS (Inno Setup), 17 pinned ones with WinHTTP without certificate validation, of 17')),
    IntToStr(SuitePhaseVerify));
  Check('marker verify, all accepted', IntToStr(SuiteTestPhaseAfter('All 20 online files accepted')), IntToStr(SuitePhaseVerify));
  Check('marker verify, some missing',
    IntToStr(SuiteTestPhaseAfter('2 of 20 selected online files are missing, the setup installs its own files instead:')), IntToStr(SuitePhaseVerify));
  Check('marker install, the line of the product script', IntToStr(SuiteTestPhaseAfter('Install step: the game folder is changed from here on')), IntToStr(SuitePhaseInstall));
  Check('marker install, the line of Inno Setup as the fallback', IntToStr(SuiteTestPhaseAfter('Starting the installation process.')), IntToStr(SuitePhaseInstall));
  Check('the marker text is the line of setup_is6.iss', SuiteLogInstallPhase, 'Install step: the game folder is changed from here on');
  Check('marker post install', IntToStr(SuiteTestPhaseAfter('Installation process succeeded.')), IntToStr(SuitePhasePost));
  Check('marker CD keys, EE only', IntToStr(SuiteTestPhaseAfter('Register NeoEE CD Keys for EE')), IntToStr(SuitePhaseCdKeys));
  Check('marker CD keys, EE and AoC', IntToStr(SuiteTestPhaseAfter('Register NeoEE CD Keys for EE and AoC')), IntToStr(SuitePhaseCdKeys));
  Check('marker CD keys result', IntToStr(SuiteTestPhaseAfter('CD Keys generation result: 0')), IntToStr(SuitePhaseCdKeys));
  Check('marker manifest, checking', IntToStr(SuiteTestPhaseAfter('Checking 1966 recorded destinations of installed files for C:\G\_setupdata_EE\files.sha256')),
    IntToStr(SuitePhaseManifest));
  Check('marker manifest, written', IntToStr(SuiteTestPhaseAfter('Manifest: 1905 files, 683.4 MB, 10500 ms, 65.1 MB/s')), IntToStr(SuitePhaseManifest));
  Check('marker done', IntToStr(SuiteTestPhaseAfter('Log closed.')), IntToStr(SuitePhaseDone));

  // The point of no return is the line of the product script, not Inno Setup's later line: CurStepChanged(ssInstall) of the
  // product setup runs before "Starting the installation process." and already deletes install.ini and files.sha256, moves
  // the downloads and the shipped random maps (review of 2026-10-07, finding 1). The order of a real log.
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['Downloading 17 online files, one at a time',
    'Online files: 0 downloaded with validated TLS (Inno Setup), 17 pinned ones with WinHTTP without certificate validation, of 17']);
  CheckBool('before the install step line: Cancel is still possible', SuiteProgressInstalling(P), False);
  SuiteTestFeed(P, ['Install step: the game folder is changed from here on']);
  CheckBool('from the install step line on: no way back', SuiteProgressInstalling(P), True);
  Check('cancel mode from the install step line on', IntToStr(SuiteCancelMode(False, True, SuiteProgressInstalling(P))), IntToStr(SuiteCancelInstalling));
  SuiteTestFeed(P, ['Online file verified, SHA-256 pinned: Game/de/EE/Language.dll (SHA-256 00)', 'All 17 online files accepted']);
  Check('the lines of the verification after it do not take the phase back', IntToStr(P.Phase), IntToStr(SuitePhaseInstall));
  Check('the verification after it still sets the number of language files', IntToStr(P.OnlineTotal), '17');
  CheckBool('the stage "language files" is done after the verification in the install step', SuiteStageReached(P, SuiteStageDownload), True);
  SuiteTestFeed(P, ['Starting the installation process.', 'Dest filename: C:\G\Data\x.ssm']);
  Check('the files are counted from the install step line on', IntToStr(P.InstallFiles), '1');
  // a run without downloads has none from the line on
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['Install step: the game folder is changed from here on']);
  CheckBool('no download logged before the install step line: no download weight', P.NoDownload, True);
  // a line that only contains the text is none
  Check('no marker: the text inside another line', IntToStr(SuiteTestPhaseAfter('Log: Install step: the game folder is changed from here on')), '0');

  // lines that look alike but are no markers
  Check('no marker: online files counted', IntToStr(SuiteTestPhaseAfter('Online files: 124 SHA-256 hashes known')), '0');
  Check('no marker: online files pins', IntToStr(SuiteTestPhaseAfter('Online files: 230 SHA-256 pins with sizes of pins\online-files.txt')), '0');
  Check('no marker: online files order', IntToStr(SuiteTestPhaseAfter('Online files: https://files.empireearth.eu/localized first (invalid certificate), then https://x (no answer: not used)')), '0');
  Check('no marker: stopped by the user', IntToStr(SuiteTestPhaseAfter('Online files: downloads stopped by the user, no further request')), '0');
  Check('no marker: a file not downloaded in the preparation',
    IntToStr(SuiteTestPhaseAfter('Online file not downloaded, no SHA-256 is known for Game/x.dll and http://x is not https')), '0');
  Check('no marker: Downloading without a count', IntToStr(SuiteTestPhaseAfter('Downloading something else')), '0');
  Check('no marker: Checking without a count', IntToStr(SuiteTestPhaseAfter('Checking the installation')), '0');
  Check('no marker: the manifest page', IntToStr(SuiteTestPhaseAfter('Manifest page shown')), '0');
  Check('no marker: other lines', IntToStr(SuiteTestPhaseAfter('Deinitializing Setup.')), '0');
  SuiteProgressInit(P, 'EE');
  SuiteFeedLogLine(P, 'Starting the installation process.');
  Check('a line without a time stamp is ignored', IntToStr(P.Phase), '0');
  SuiteFeedLogLine(P, '');
  Check('an empty line is ignored', IntToStr(P.Phase), '0');
  SuiteFeedLogLine(P, '2026-10-06 21:31:58.478   ');
  Check('an entry without text is ignored', IntToStr(P.Phase), '0');

  // the phases never go back
  SuiteProgressInit(P, 'NeoEE');
  SuiteTestFeed(P, ['Starting the installation process.', 'Online files server https://x/localized: no answer', 'Downloading 5 online files, one at a time',
    'Online files: 0 downloaded with validated TLS (Inno Setup), 5 pinned ones with WinHTTP without certificate validation, of 5']);
  Check('the phases never go back', IntToStr(P.Phase), IntToStr(SuitePhaseInstall));
  CheckBool('SuiteProgressInstalling after "Starting the installation process."', SuiteProgressInstalling(P), True);
  SuiteTestFeed(P, ['Installation process succeeded.', 'Register NeoEE CD Keys for EE', 'Starting the installation process.']);
  Check('the phases never go back after the installation', IntToStr(P.Phase), IntToStr(SuitePhaseCdKeys));
  CheckBool('SuiteProgressInstalling stays True', SuiteProgressInstalling(P), True);
  SuiteTestFeed(P, ['Log closed.', 'Starting the installation process.']);
  Check('nothing follows "Log closed."', IntToStr(P.Phase), IntToStr(SuitePhaseDone));
  Check('SuiteProgressPermille at the end of the log', IntToStr(SuiteProgressPermille(P)), '1000');

  // the download: counters, the file being downloaded, bytes
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['Downloading 17 online files, one at a time']);
  Check('download count', IntToStr(P.DownloadFiles), '17');
  Check('download done at the start', IntToStr(P.DownloadDone), '0');
  SuiteTestFeed(P, ['Downloading pinned online file without certificate validation (WinHTTP) from https://files.empireearth.eu/localized/Game/de/EE/Data/data.ssa: C:\T\is-AAAAA.tmp\EE\Data\data.ssa',
    '  17170432 of 171671814 bytes done.']);
  Check('current file', P.CurrentFile, 'data.ssa');
  Check('current bytes', IntToStr(P.CurrentBytes), '17170432');
  Check('current total', IntToStr(P.CurrentTotal), '171671814');
  Check('SuiteDownloadPermille of a tenth of the file', IntToStr(SuiteDownloadPermille(P)), '5');
  SuiteTestFeed(P, ['  171671814 of 171671814 bytes done.']);
  Check('SuiteDownloadPermille never completes a file before its line', IntToStr(SuiteDownloadPermille(P)), '58');
  SuiteTestFeed(P, ['Online file downloaded, SHA-256 pinned, transport WinHTTP without certificate validation: https://files.empireearth.eu/localized/Game/de/EE/Data/data.ssa (171671814 bytes, 75735 ms)']);
  Check('download done after one file', IntToStr(P.DownloadDone), '1');
  Check('current bytes after the file', IntToStr(P.CurrentBytes), '0');
  Check('current total after the file', IntToStr(P.CurrentTotal), '0');
  Check('the file name stays until the next file', P.CurrentFile, 'data.ssa');
  Check('SuiteDownloadPermille after one file of 17', IntToStr(SuiteDownloadPermille(P)), '58');
  SuiteTestFeed(P, ['Online file downloaded, TLS-verified, size checked: https://x/localized/a.dll',
    'Online file downloaded, TLS-verified, accepted without size check (the server sent no Content-Length): https://x/localized/b.dll',
    'Online file downloaded, SHA-256 pinned: https://x/localized/c.dll']);
  Check('download done after the other transports', IntToStr(P.DownloadDone), '4');
  SuiteTestFeed(P, ['Online file not downloaded, it failed on both servers: Game/de/EE/d.dll',
    'Online file not downloaded, not retried: the other server is not used for it (see "Other server not used for" above): Game/de/EE/e.dll',
    'Online file not downloaded, unexpected error: out of memory', 'Online file skipped, downloads stopped by the user: Game/de/EE/f.dll']);
  Check('download done counts the files that failed or were skipped', IntToStr(P.DownloadDone), '8');
  Check('a line of a retry on the other server is not a finished file', IntToStr(SuiteTestPhaseAfter('Online file: trying the other server, https://x/localized/y.dll')), '0');
  SuiteTestFeed(P, ['Online file not downloaded from https://x/localized/g.dll: no answer', 'Online file download failed from https://x/localized/g.dll: timeout after 5 bytes']);
  Check('the lines of one attempt are not a finished file', IntToStr(P.DownloadDone), '8');
  // the validated TLS transport logs only Inno Setup's line at the start of a file, and the progress lines of the callback
  // (finding 6 of the review of 2026-10-07): the file name and the bytes work with it as with the WinHTTP transport
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['Downloading 17 online files, one at a time',
    'Downloading temporary file from https://files.empireearth.eu/localized/Game/de/EE/Data/data.ssa: C:\T\is-AAAAA.tmp\EE\Data\data.ssa',
    '  17167181 of 171671814 bytes done.']);
  Check('the file of Inno Setup line: phase', IntToStr(Q.Phase), IntToStr(SuitePhaseDownload));
  Check('the file of Inno Setup line: file name', Q.CurrentFile, 'data.ssa');
  Check('the file of Inno Setup line: bytes', IntToStr(Q.CurrentBytes), '17167181');
  Check('the file of Inno Setup line: total', IntToStr(Q.CurrentTotal), '171671814');
  SuiteBytesTexts(Q.CurrentBytes, Q.CurrentTotal, 'de', DoneText, TotalText);
  Check('the file of Inno Setup line: the line below the status line, done', DoneText, '16,4');
  Check('the file of Inno Setup line: the line below the status line, total', TotalText, '163,7 MB');
  SuiteTestFeed(Q, ['Downloading temporary file from https://files.empireearth.eu/localized/Game/de/EE/Language.dll: C:\T\is-AAAAA.tmp\EE\Language.dll']);
  Check('the next file of Inno Setup line: file name', Q.CurrentFile, 'Language.dll');
  Check('the next file of Inno Setup line: no bytes yet', IntToStr(Q.CurrentTotal), '0');
  Check('an English log with that line only is a download', IntToStr(SuiteTestPhaseAfter('Downloading temporary file from https://x/localized/a.dll: C:\T\a.dll')), IntToStr(SuitePhaseDownload));
  Check('the line of Inno Setup does not count a file', IntToStr(Q.DownloadDone), '0');
  // more finished files than announced: stays at the count
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['Downloading 2 online files, one at a time', 'Online file downloaded, SHA-256 pinned: https://x/localized/a.dll',
    'Online file downloaded, SHA-256 pinned: https://x/localized/b.dll', 'Online file downloaded, SHA-256 pinned: https://x/localized/c.dll']);
  Check('download done stays at the count', IntToStr(Q.DownloadDone), '2');
  Check('SuiteDownloadPermille of all files', IntToStr(SuiteDownloadPermille(Q)), '1000');
  // a file that finishes before the count line is no download of the phase
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['Online file downloaded, SHA-256 pinned: https://x/localized/a.dll']);
  Check('a downloaded file before the download phase is not counted', IntToStr(Q.DownloadDone), '0');
  // after the download phase nothing counts any more
  SuiteTestFeed(Q, ['Downloading 2 online files, one at a time', 'Online files: 0 downloaded with validated TLS (Inno Setup), 2 pinned ones, of 2',
    'Online file downloaded, SHA-256 pinned: https://x/localized/a.dll', '  5 of 10 bytes done.']);
  Check('a downloaded file after the verify marker is not counted', IntToStr(Q.DownloadDone), '0');
  Check('bytes after the download phase are not taken', IntToStr(Q.CurrentTotal), '0');
  // the missing files
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['2 of 20 selected online files are missing, the setup installs its own files instead:', '  Language.dll is missing']);
  Check('online files missing', IntToStr(Q.OnlineMissing), '2');
  // bytes lines are tolerant about the blanks
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['Downloading 1 online files, one at a time', '65536 of 249856 bytes done.']);
  Check('bytes without the two blanks', IntToStr(Q.CurrentBytes), '65536');
  SuiteTestFeed(Q, ['0 of 0 bytes done.']);
  Check('a total of 0 is not taken', IntToStr(Q.CurrentTotal), '249856');
  SuiteTestFeed(Q, ['x of y bytes done.', '12 of 99']);
  Check('bytes line without numbers or end is not taken', IntToStr(Q.CurrentBytes), '65536');
  // the name of a file with a path and spaces and without any URL
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['Downloading pinned online file without certificate validation (WinHTTP) from https://files.empireearth.eu/localized/Mods/NeoEE/Game/de/EE/Language.dll: C:\T\x']);
  Check('current file below folders', Q.CurrentFile, 'Language.dll');
  SuiteTestFeed(Q, ['Downloading pinned online file somewhere']);
  Check('current file without a URL', Q.CurrentFile, '');

  // a run without download: English
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['English language selected, no need to download online files.']);
  CheckBool('English run: no download', P.NoDownload, True);
  Check('English run: the phase does not move', IntToStr(P.Phase), IntToStr(SuitePhaseStart));
  Check('English run: permille at the start (the download weight drops out)', IntToStr(SuiteProgressPermille(P)), '0');
  SuiteTestFeed(P, ['Starting the installation process.']);
  Check('English run: install start, 5 of 35', IntToStr(SuiteProgressPermille(P)), '142');
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['Starting the installation process.']);
  CheckBool('a run with no download line at all has no download either', Q.NoDownload, True);
  Check('same permille', IntToStr(SuiteProgressPermille(Q)), '142');
  SuiteProgressInit(Q, 'EE');
  SuiteTestFeed(Q, ['Downloading 3 online files, one at a time', 'Starting the installation process.']);
  CheckBool('a run with downloads keeps the download weight', Q.NoDownload, False);
  Check('permille at the install start with downloads', IntToStr(SuiteProgressPermille(Q)), '700');
  // the English line after the downloads started changes nothing
  SuiteTestFeed(Q, ['English language selected, no need to download online files.']);
  CheckBool('the English line after the download phase is ignored', Q.NoDownload, False);

  // the install estimate: counted from the start of the installation, clamped, never 100 %
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['Dest filename: C:\G\a.dll']);
  Check('entries before the installation are not counted', IntToStr(P.InstallFiles), '0');
  SuiteTestFeed(P, ['Downloading 1 online files, one at a time', 'Online files: 0 downloaded with validated TLS (Inno Setup), 1 pinned ones, of 1',
    'Starting the installation process.']);
  Check('permille at the install start', IntToStr(SuiteProgressPermille(P)), '700');
  P.InstallEstimate := 1000;
  for I := 1 to 500 do
    SuiteFeedLogLine(P, SuiteTestLine('Dest filename: C:\G\f' + IntToStr(I) + '.dll'));
  Check('install entries counted', IntToStr(P.InstallFiles), '500');
  Check('permille at half of the estimate', IntToStr(SuiteProgressPermille(P)), '800');
  for I := 501 to 2000 do
    SuiteFeedLogLine(P, SuiteTestLine('Dest filename: C:\G\f' + IntToStr(I) + '.dll'));
  Check('install entries beyond the estimate are counted', IntToStr(P.InstallFiles), '2000');
  Check('permille beyond the estimate is clamped at 99 % of the install block', IntToStr(SuiteProgressPermille(P)), '898');
  CheckBool('permille before the end of the log stays below 100 %', SuiteProgressPermille(P) <= 990, True);
  SuiteTestFeed(P, ['Installation process succeeded.', 'Dest filename: C:\G\later.dll']);
  Check('entries after the installation are not counted', IntToStr(P.InstallFiles), '2000');
  Check('permille after the installation', IntToStr(SuiteProgressPermille(P)), '900');
  P.InstallEstimate := 0;
  P.Phase := SuitePhaseInstall;
  Check('no estimate: the install block stays below its end', IntToStr(SuiteProgressPermille(P)), '898');

  // the file the installation works on: the file name of the last entry "Dest filename:"
  SuiteProgressInit(P, 'EE');
  Check('no install file at the start', P.InstallFile, '');
  SuiteTestFeed(P, ['Starting the installation process.', 'Dest filename: C:\G\Data\Models\unit.ssm']);
  Check('install file: the file name of the entry', P.InstallFile, 'unit.ssm');
  SuiteTestFeed(P, ['Dest filename: C:\Program Files (x86)\Empire Earth\Empire Earth.exe', 'Dest file exists.']);
  Check('install file: the last entry, a path with blanks', P.InstallFile, 'Empire Earth.exe');
  SuiteTestFeed(P, ['Installation process succeeded.', 'Dest filename: C:\G\later.dll']);
  Check('install file: no entry after the installation', P.InstallFile, 'Empire Earth.exe');
  Check('SuiteFileNameOf a path', SuiteFileNameOf('C:\a\b\c.txt'), 'c.txt');
  Check('SuiteFileNameOf a URL', SuiteFileNameOf('https://x/y/z.dll'), 'z.dll');
  Check('SuiteFileNameOf a name', SuiteFileNameOf('c.txt'), 'c.txt');
  Check('SuiteFileNameOf nothing after the last backslash', SuiteFileNameOf('C:\a\'), '');

  // the online files that are accepted or missing: how many there are
  SuiteProgressInit(P, 'EE');
  Check('no online total at the start', IntToStr(P.OnlineTotal), '0');
  SuiteTestFeed(P, ['All 17 online files accepted']);
  Check('online total of the accepted files', IntToStr(P.OnlineTotal), '17');
  Check('no online file missing after "All accepted"', IntToStr(P.OnlineMissing), '0');
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['2 of 20 selected online files are missing, the setup installs its own files instead:']);
  Check('online total of the line with missing files', IntToStr(P.OnlineTotal), '20');
  Check('online files missing of it', IntToStr(P.OnlineMissing), '2');
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['Online files: 0 downloaded with validated TLS (Inno Setup), 17 pinned ones with WinHTTP without certificate validation, of 17']);
  Check('the end of the downloads gives no online total', IntToStr(P.OnlineTotal), '0');

  // post install, CD keys, manifest, end
  SuiteProgressInit(P, 'NeoEE');
  SuiteTestFeed(P, ['Downloading 1 online files, one at a time', 'Starting the installation process.', 'Installation process succeeded.']);
  Check('CD key result before the line', P.CdKeyResult, '');
  SuiteTestFeed(P, ['Register NeoEE CD Keys for EE and AoC']);
  Check('permille in the CD key step', IntToStr(SuiteProgressPermille(P)), '940');
  SuiteTestFeed(P, ['CD Keys generation result: 0', 'CD Keys registered']);
  Check('CD key result is read as text', P.CdKeyResult, '0');
  Check('the CD key line is the same as the one SuiteParseCdKeyResult reads', SuiteParseCdKeyResult(SuiteTestLine('CD Keys generation result: 0')), '0');
  SuiteTestFeed(P, ['Checking 2351 recorded destinations of installed files for C:\G\_setupdata_NeoEE\files.sha256']);
  Check('permille in the manifest step', IntToStr(SuiteProgressPermille(P)), '970');
  CheckBool('manifest not done yet', P.ManifestDone, False);
  SuiteTestFeed(P, ['Manifest: 2253 files, 714.6 MB, 15328 ms, 46.6 MB/s']);
  CheckBool('manifest done', P.ManifestDone, True);
  Check('permille after the manifest, below 100 % until the log ends', IntToStr(SuiteProgressPermille(P)), '990');
  SuiteTestFeed(P, ['Deinitializing Setup.', 'Log closed.']);
  Check('permille at "Log closed."', IntToStr(SuiteProgressPermille(P)), '1000');
  // a run without the CD key lines (the task not chosen): nothing in the result
  SuiteProgressInit(Q, 'NeoEE');
  SuiteTestFeed(Q, ['Starting the installation process.', 'Installation process succeeded.', 'Checking 5 recorded destinations of installed files for C:\G\files.sha256']);
  Check('no CD key line: no result', Q.CdKeyResult, '');
  Check('no CD key line: the manifest step follows the installation', IntToStr(Q.Phase), IntToStr(SuitePhaseManifest));

  // the permille grows from phase to phase of a normal run (every step at least as far as the one before)
  SuiteProgressInit(P, 'EE');
  Sum := SuiteProgressPermille(P);
  Check('permille 0 at the start', IntToStr(Sum), '0');
  SuiteTestFeed(P, ['Online files server https://x/localized: no answer']);
  Check('permille at the probe', IntToStr(SuiteProgressPermille(P)), '15');
  SuiteTestFeed(P, ['Downloading 17 online files, one at a time']);
  Check('permille at the start of the downloads', IntToStr(SuiteProgressPermille(P)), '30');
  SuiteTestFeed(P, ['Online file downloaded, SHA-256 pinned: https://x/localized/a.dll']);
  Check('permille after one of 17 files', IntToStr(SuiteProgressPermille(P)), '67');
  for I := 2 to 17 do
    SuiteTestFeed(P, ['Online file downloaded, SHA-256 pinned: https://x/localized/a.dll']);
  Check('permille after all 17 files', IntToStr(SuiteProgressPermille(P)), '680');
  SuiteTestFeed(P, ['Online files: 0 downloaded with validated TLS (Inno Setup), 17 pinned ones, of 17']);
  Check('permille at the verify step', IntToStr(SuiteProgressPermille(P)), '690');
  SuiteTestFeed(P, ['All 20 online files accepted', 'Starting the installation process.']);
  Check('permille at the install start of a run with downloads', IntToStr(SuiteProgressPermille(P)), '700');
  SuiteTestFeed(P, ['Installation process succeeded.']);
  Check('permille after the installation', IntToStr(SuiteProgressPermille(P)), '900');

  // the first line starts with the byte order mark (3 characters in an ANSI code page, 1 in the UTF-8 one);
  // continuation lines (26 blanks, no time stamp) and lines without a time stamp are no entries
  Bom := Chr(239) + Chr(187) + Chr(191);
  SuiteProgressInit(P, 'EE');
  SuiteFeedLogChunk(P, Bom + SuiteTestLine('Online files server https://x/localized: no answer') + Crlf);
  Check('the byte order mark (3 characters) of the first line is skipped', IntToStr(P.Phase), IntToStr(SuitePhaseProbe));
  SuiteProgressInit(P, 'EE');
  SuiteFeedLogChunk(P, #$FEFF + SuiteTestLine('Online files server https://x/localized: no answer') + Crlf);
  Check('the byte order mark (1 character) of the first line is skipped', IntToStr(P.Phase), IntToStr(SuitePhaseProbe));
  SuiteProgressInit(P, 'EE');
  SuiteFeedLogChunk(P, Bom + SuiteTestLine('Log opened. (Time zone: UTC+02:00)') + Crlf + SuiteTestLine('Downloading 2 online files, one at a time') + Crlf);
  Check('the lines after the first one are read with the byte order mark', IntToStr(P.DownloadFiles), '2');
  SuiteProgressInit(P, 'EE');
  SuiteFeedLogChunk(P, StringOfChar(' ', 26) + 'Starting the installation process.' + Crlf + 'Starting the installation process.' + Crlf + 'xx' + SuiteTestLine('Starting the installation process.') + Crlf);
  Check('continuation lines, lines without a time stamp and junk before it are ignored', IntToStr(P.Phase), '0');

  // pieces of the log: a line split across two reads, line ends CRLF and LF, the last line without a line end
  SuiteProgressInit(P, 'EE');
  SuiteFeedLogChunk(P, SuiteTestLine('Starting the installa'));
  Check('a line without a line end is not parsed', IntToStr(P.Phase), '0');
  Check('the unfinished line waits', P.TailCarry, SuiteTestLine('Starting the installa'));
  SuiteFeedLogChunk(P, 'tion process.' + #13);
  Check('a line split across two reads: the CR alone is no line end', IntToStr(P.Phase), '0');
  SuiteFeedLogChunk(P, #10 + SuiteTestLine('Dest filename: C:\G\a.dll') + #10 + SuiteTestLine('Dest filename: C:\G\b.dll') + #10 + SuiteTestLine('Dest file'));
  Check('a line split across two reads is joined', IntToStr(P.Phase), IntToStr(SuitePhaseInstall));
  Check('LF alone ends a line', IntToStr(P.InstallFiles), '2');
  Check('the last line waits', P.TailCarry, SuiteTestLine('Dest file'));
  SuiteFeedLogChunk(P, 'name: C:\G\c.dll' + Crlf);
  Check('the line is complete with the next read', IntToStr(P.InstallFiles), '3');
  Check('nothing is left over', P.TailCarry, '');
  SuiteFeedLogChunk(P, '');
  Check('an empty read changes nothing', IntToStr(P.InstallFiles), '3');
  // one character at a time
  SuiteProgressInit(P, 'EE');
  Blanks := SuiteTestLine('Starting the installation process.') + Crlf;
  for I := 1 to Length(Blanks) do
    SuiteFeedLogChunk(P, Copy(Blanks, I, 1));
  Check('a log read one character at a time', IntToStr(P.Phase), IntToStr(SuitePhaseInstall));
  // a line with no end that grows too long is dropped
  SuiteProgressInit(P, 'EE');
  Blanks := 'xxxxxxxxxx';
  for I := 1 to 13 do
    Blanks := Blanks + Blanks;
  SuiteFeedLogChunk(P, Blanks);
  Check('a line without an end that is too long is dropped', P.TailCarry, '');
  SuiteFeedLogChunk(P, SuiteTestLine('Starting the installation process.') + Crlf);
  Check('the log goes on after a dropped piece', IntToStr(P.Phase), IntToStr(SuitePhaseInstall));
end;

// ---- what the window shows of the progress (S4) ------------------------------------------------------

procedure TestSuiteDisplay;
var
  P: TSuiteProgress;
  Done, Total: String;
  Got, All, I: Integer;
begin
  // the kind of the status line follows the phase
  SuiteProgressInit(P, 'EE');
  Check('status kind at the start', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusStart));
  SuiteTestFeed(P, ['Online files server https://x/localized: no answer']);
  Check('status kind at the probe', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusProbe));
  SuiteTestFeed(P, ['Downloading 17 online files, one at a time']);
  Check('status kind at the downloads', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusDownload));
  SuiteTestFeed(P, ['Online files: 0 downloaded with validated TLS (Inno Setup), 17 pinned ones, of 17']);
  Check('status kind at the check of the files', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusVerify));
  SuiteTestFeed(P, ['Starting the installation process.']);
  Check('status kind at the installation', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusInstall));
  SuiteTestFeed(P, ['Installation process succeeded.']);
  Check('status kind after the installation', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusFinish));
  SuiteTestFeed(P, ['Register NeoEE CD Keys for EE']);
  Check('status kind at the CD keys', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusCdKeys));
  SuiteTestFeed(P, ['CD Keys generation result: 0']);
  Check('status kind after the CD key result', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusFinish));
  SuiteTestFeed(P, ['Checking 5 recorded destinations of installed files for C:\G\files.sha256', 'Manifest: 5 files, 1.0 MB, 10 ms, 100 MB/s']);
  Check('status kind at the manifest', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusFinish));
  SuiteTestFeed(P, ['Log closed.']);
  Check('status kind at the end of the log', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusFinish));
  // a download line without the count before it says no more than the start
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['Downloading pinned online file without certificate validation (WinHTTP) from https://x/localized/a.dll: C:\T\a.dll']);
  Check('status kind of the download phase without a count', IntToStr(SuiteStatusKind(P)), IntToStr(SuiteStatusStart));

  // the number of the file the download is at
  SuiteProgressInit(P, 'EE');
  SuiteTestFeed(P, ['Downloading 3 online files, one at a time']);
  Check('download index of the first file', IntToStr(SuiteDownloadIndex(P)), '1');
  SuiteTestFeed(P, ['Online file downloaded, SHA-256 pinned: https://x/localized/a.dll', 'Online file downloaded, SHA-256 pinned: https://x/localized/b.dll']);
  Check('download index of the third file', IntToStr(SuiteDownloadIndex(P)), '3');
  SuiteTestFeed(P, ['Online file downloaded, SHA-256 pinned: https://x/localized/c.dll']);
  Check('download index stays at the count', IntToStr(SuiteDownloadIndex(P)), '3');

  // the bar: never 100 percent while the product setup runs, the steps of the run share the bar
  SuiteProgressInit(P, 'EE');
  P.Phase := SuitePhaseDone;
  Check('the permille of the log at its end', IntToStr(SuiteProgressPermille(P)), '1000');
  Check('SuiteRunningPermille stays below 100 percent', IntToStr(SuiteRunningPermille(P)), IntToStr(SuiteRunningPermilleMax));
  P.Phase := SuitePhaseInstall;
  Check('SuiteRunningPermille passes the permille on', IntToStr(SuiteRunningPermille(P)), IntToStr(SuiteProgressPermille(P)));
  Check('overall: the first of two steps at its start', IntToStr(SuiteOverallPermille(1, 2, 0)), '0');
  Check('overall: the first of two steps half done', IntToStr(SuiteOverallPermille(1, 2, 500)), '250');
  Check('overall: the first of two steps done', IntToStr(SuiteOverallPermille(1, 2, 1000)), '500');
  Check('overall: the second of two steps at its start', IntToStr(SuiteOverallPermille(2, 2, 0)), '500');
  Check('overall: the second of two steps at 990', IntToStr(SuiteOverallPermille(2, 2, SuiteRunningPermilleMax)), '995');
  Check('overall: the second of two steps done', IntToStr(SuiteOverallPermille(2, 2, 1000)), '1000');
  Check('overall: one step', IntToStr(SuiteOverallPermille(1, 1, 400)), '400');
  Check('overall: one step done', IntToStr(SuiteOverallPermille(1, 1, 1000)), '1000');
  Check('overall: no step counted', IntToStr(SuiteOverallPermille(0, 0, 500)), '500');
  Check('overall: a step beyond the number', IntToStr(SuiteOverallPermille(5, 2, 500)), '750');
  Check('overall: a permille out of range', IntToStr(SuiteOverallPermille(1, 2, 5000)), '500');
  Check('overall: a negative permille', IntToStr(SuiteOverallPermille(2, 2, -5)), '500');
  // the bar of the whole run never goes back: the permille of every step of a normal run fed line by line
  SuiteProgressInit(P, 'EE');
  Got := 0;
  All := 1;
  for I := 1 to 5 do
  begin
    case I of
      1: SuiteTestFeed(P, ['Online files server https://x/localized: no answer']);
      2: SuiteTestFeed(P, ['Downloading 4 online files, one at a time']);
      3: SuiteTestFeed(P, ['Online file downloaded, SHA-256 pinned: https://x/localized/a.dll']);
      4: SuiteTestFeed(P, ['All 4 online files accepted', 'Starting the installation process.']);
      5: SuiteTestFeed(P, ['Installation process succeeded.', 'Log closed.']);
    end;
    if SuiteOverallPermille(1, 2, SuiteRunningPermille(P)) < Got then
      All := 0;
    Got := SuiteOverallPermille(1, 2, SuiteRunningPermille(P));
  end;
  Check('the bar of a normal run never goes back', IntToStr(All), '1');
  Check('the bar of a normal run ends below the end of its step', IntToStr(Got), '495');

  // sizes: megabytes with one decimal from 1 MB, else kilobytes rounded up; the decimal separator and the unit by language
  SuiteBytesTexts(17170432, 171671814, 'en', Done, Total);
  Check('size in MB, English', Done + ' of ' + Total, '16.4 of 163.7 MB');
  SuiteBytesTexts(17170432, 171671814, 'de', Done, Total);
  Check('size in MB, German', Done + ' von ' + Total, '16,4 von 163,7 MB');
  SuiteBytesTexts(17170432, 171671814, 'fr', Done, Total);
  Check('size in MB, French', Done + ' sur ' + Total, '16,4 sur 163,7 Mo');
  SuiteBytesTexts(0, 1048576, 'en', Done, Total);
  Check('size: exactly 1 MB', Done + ' of ' + Total, '0.0 of 1.0 MB');
  SuiteBytesTexts(1048575, 1048576, 'en', Done, Total);
  Check('size: the part rounds to the nearest tenth', Done + ' of ' + Total, '1.0 of 1.0 MB');
  SuiteBytesTexts(50000, 249856, 'en', Done, Total);
  Check('size in KB, English', Done + ' of ' + Total, '49 of 244 KB');
  SuiteBytesTexts(50000, 249856, 'fr', Done, Total);
  Check('size in KB, French', Done + ' of ' + Total, '49 of 244 Ko');
  SuiteBytesTexts(1, 1, 'de', Done, Total);
  Check('size: one byte is one KB', Done + ' of ' + Total, '1 of 1 KB');
  SuiteBytesTexts(0, 0, 'en', Done, Total);
  Check('size: nothing', Done + ' of ' + Total, '0 of 0 KB');
  SuiteBytesTexts(-5, 2097152, 'en', Done, Total);
  Check('size: a negative part is nothing', Done + ' of ' + Total, '0.0 of 2.0 MB');
  SuiteBytesTexts(5368709120, 5368709120, 'en', Done, Total);
  Check('size: gigabytes stay in MB', Done + ' of ' + Total, '5120.0 of 5120.0 MB');
  Check('SuiteTenthsText, language in capitals', SuiteTenthsText(25, 'DE'), '2,5');
  Check('SuiteTenthsText, another language', SuiteTenthsText(25, 'es'), '2.5');

  // how many online files arrived
  SuiteProgressInit(P, 'EE');
  CheckBool('no online files known at the start', SuiteOnlineCounts(P, Got, All), False);
  SuiteTestFeed(P, ['Downloading 17 online files, one at a time']);
  CheckBool('online files from the count of the downloads', SuiteOnlineCounts(P, Got, All), True);
  Check('got of the count', IntToStr(Got) + ' of ' + IntToStr(All), '17 of 17');
  SuiteTestFeed(P, ['3 of 20 selected online files are missing, the setup installs its own files instead:']);
  CheckBool('online files with missing ones', SuiteOnlineCounts(P, Got, All), True);
  Check('got of the total of the missing line', IntToStr(Got) + ' of ' + IntToStr(All), '17 of 20');
  SuiteProgressInit(P, 'EE');
  P.OnlineMissing := 5;
  P.OnlineTotal := 3;
  SuiteOnlineCounts(P, Got, All);
  Check('got never below zero', IntToStr(Got), '0');

  // the steps that are done: each when its result is known
  SuiteProgressInit(P, 'NeoEE');
  CheckBool('stage download at the start', SuiteStageReached(P, SuiteStageDownload), False);
  SuiteTestFeed(P, ['Downloading 17 online files, one at a time', 'Online files: 0 downloaded with validated TLS (Inno Setup), 17 pinned ones, of 17']);
  CheckBool('stage download before the counts are accepted', SuiteStageReached(P, SuiteStageDownload), False);
  SuiteTestFeed(P, ['All 17 online files accepted']);
  CheckBool('stage download after "All accepted"', SuiteStageReached(P, SuiteStageDownload), True);
  CheckBool('stage install not yet', SuiteStageReached(P, SuiteStageInstall), False);
  SuiteProgressInit(P, 'NeoEE');
  SuiteTestFeed(P, ['English language selected, no need to download online files.', 'Starting the installation process.']);
  CheckBool('stage download of a run without downloads, at the start of the installation', SuiteStageReached(P, SuiteStageDownload), True);
  CheckBool('stage install while it runs', SuiteStageReached(P, SuiteStageInstall), False);
  SuiteTestFeed(P, ['Installation process succeeded.']);
  CheckBool('stage install after it', SuiteStageReached(P, SuiteStageInstall), True);
  CheckBool('stage CD keys without the line', SuiteStageReached(P, SuiteStageCdKeys), False);
  SuiteTestFeed(P, ['Register NeoEE CD Keys for EE']);
  CheckBool('stage CD keys while they are registered', SuiteStageReached(P, SuiteStageCdKeys), False);
  SuiteTestFeed(P, ['CD Keys generation result: 0']);
  CheckBool('stage CD keys with the result', SuiteStageReached(P, SuiteStageCdKeys), True);
  CheckBool('stage manifest not yet', SuiteStageReached(P, SuiteStageManifest), False);
  SuiteTestFeed(P, ['Manifest: 5 files, 1.0 MB, 10 ms, 100 MB/s']);
  CheckBool('stage manifest after its line', SuiteStageReached(P, SuiteStageManifest), True);
  CheckBool('an unknown stage is never reached', SuiteStageReached(P, 99), False);
end;

// Writes Text (ASCII) to a file handle of CreateFile, as the product setup writes its log
procedure SuiteTestWrite(Handle: Cardinal; const Text: AnsiString);
var
  Written: Cardinal;
  Count: Integer;
begin
  Count := Length(Text);
  Written := 0;
  if not WriteFile(Handle, Text, Count, Written, 0) then
    Results.Add('FAIL cannot write the test log')
  else if Integer(Written) <> Count then
    Results.Add('FAIL the test log was written in part');
end;

const
  SuiteTestGenericWrite = $40000000;
  SuiteTestCreateAlways = 2;

procedure TestSuiteTailLog;
var
  Dir, LogFile, Text: String;
  P: TSuiteProgress;
  Handle: Cardinal;
  I, Reads: Integer;
  Size: Int64;
  Whole: AnsiString;
begin
  Dir := ExpandConstant('{tmp}\suite_tail');
  ForceDirectories(Dir);
  LogFile := Dir + '\EE-test.log';
  DeleteFile(LogFile);
  SuiteProgressInit(P, 'EE');

  // no log yet (the product setup creates it when it starts)
  CheckBool('SuiteTailLog without a file', SuiteTailLog(LogFile, P), False);
  Check('SuiteTailLog without a file: phase', IntToStr(P.Phase), '0');
  Check('SuiteTailLog without a file: offset', IntToStr(P.TailOffset), '0');

  // the product setup holds its log open for writing and allows only reading (its Logging unit: faWrite, fsRead);
  // LoadStringFromFile would fail on such a file
  Handle := CreateFile(LogFile, SuiteTestGenericWrite, FILE_SHARE_READ, 0, SuiteTestCreateAlways, 0, 0);
  CheckBool('the test log is held open for writing', Handle <> INVALID_HANDLE_VALUE, True);
  CheckBool('LoadStringFromFile cannot read a log that is held open like this', LoadStringFromFile(LogFile, Whole), False);
  CheckBool('SuiteTailLog of an empty log', SuiteTailLog(LogFile, P), False);
  SuiteTestWrite(Handle, SuiteTestLine('Online files server https://x/localized: no answer') + #13#10 + SuiteTestLine('Downloading 3 online fi'));
  CheckBool('SuiteTailLog reads a log the product setup holds open', SuiteTailLog(LogFile, P), True);
  Check('SuiteTailLog: the complete line was read', IntToStr(P.Phase), IntToStr(SuitePhaseProbe));
  CheckBool('SuiteTailLog: the unfinished line waits', Length(P.TailCarry) > 0, True);
  CheckBool('SuiteTailLog without news', SuiteTailLog(LogFile, P), False);
  SuiteTestWrite(Handle, 'les, one at a time' + #13#10);
  CheckBool('SuiteTailLog reads the rest of the line', SuiteTailLog(LogFile, P), True);
  Check('SuiteTailLog: the line was joined', IntToStr(P.DownloadFiles), '3');
  Check('SuiteTailLog: nothing is left over', P.TailCarry, '');
  CheckBool('SuiteTailLog without news again', SuiteTailLog(LogFile, P), False);
  Size := 0;
  CheckBool('FileSize64 of the log', FileSize64(LogFile, Size), True);
  Check('SuiteTailLog: the offset is the size of the log', IntToStr(P.TailOffset), IntToStr(Size));
  CloseHandle(Handle);

  // a smaller log than what was read is a new log: read from the start, the phase stays
  Handle := CreateFile(LogFile, SuiteTestGenericWrite, FILE_SHARE_READ, 0, SuiteTestCreateAlways, 0, 0);
  SuiteTestWrite(Handle, SuiteTestLine('Starting the installation process.') + #13#10);
  CheckBool('SuiteTailLog reads a log that was recreated', SuiteTailLog(LogFile, P), True);
  Check('SuiteTailLog: the new log was read', IntToStr(P.Phase), IntToStr(SuitePhaseInstall));
  CloseHandle(Handle);
  CheckBool('SuiteTailLog: the new log was read from its start', P.TailOffset < Size, True);
  DeleteFile(LogFile);
  CheckBool('SuiteTailLog after the file is gone', SuiteTailLog(LogFile, P), False);

  // more than one read: SuiteTailChunkMax bytes at most per call, lines cut at the limit are joined
  SuiteProgressInit(P, 'EE');
  Text := SuiteTestLine('Starting the installation process.') + #13#10;
  for I := 1 to 6000 do
    Text := Text + SuiteTestLine('Dest filename: C:\Program Files (x86)\Empire Earth\Data\f' + IntToStr(I) + '.ssa') + #13#10;
  CheckBool('the long test log is written', SaveStringToFile(LogFile, Text, False), True);
  CheckBool('the long test log is longer than one read', Length(Text) > SuiteTailChunkMax, True);
  CheckBool('SuiteTailLog: first read of a long log', SuiteTailLog(LogFile, P), True);
  Check('SuiteTailLog: the first read is SuiteTailChunkMax bytes', IntToStr(P.TailOffset), IntToStr(SuiteTailChunkMax));
  Reads := 1;
  while (Reads < 10) and SuiteTailLog(LogFile, P) do
    Reads := Reads + 1;
  Check('SuiteTailLog: the long log takes one read per SuiteTailChunkMax bytes', IntToStr(Reads), IntToStr((Length(Text) + SuiteTailChunkMax - 1) div SuiteTailChunkMax));
  Check('SuiteTailLog: every entry of the long log was counted', IntToStr(P.InstallFiles), '6000');
  Check('SuiteTailLog: the long log was read completely', IntToStr(P.TailOffset), IntToStr(Length(Text)));
  DeleteFile(LogFile);
  RemoveDir(Dir);
end;

// The limits and the choices of the product runner (S2): what they do with the time, the exit code and the
// Cancel button. Pure.
procedure TestSuiteRunLimits;
var
  Near, Wrapped: DWORD;
begin
  // how a product setup ended: the kind of an exit code, or SuiteChildTimeout if the suite stopped it
  Check('SuiteChildKind exit 0', IntToStr(SuiteChildKind(False, 0)), IntToStr(SuiteChildOk));
  Check('SuiteChildKind exit 1', IntToStr(SuiteChildKind(False, 1)), IntToStr(SuiteChildNotStarted));
  Check('SuiteChildKind exit 3', IntToStr(SuiteChildKind(False, 3)), IntToStr(SuiteChildFatal));
  Check('SuiteChildKind exit 7', IntToStr(SuiteChildKind(False, 7)), IntToStr(SuiteChildPrecondition));
  Check('SuiteChildKind stopped by the suite', IntToStr(SuiteChildKind(True, SuiteKillCode)), IntToStr(SuiteChildTimeout));
  Check('SuiteChildKind stopped, whatever the exit code says', IntToStr(SuiteChildKind(True, 0)), IntToStr(SuiteChildTimeout));
  Check('SuiteChildTimeout is none of the kinds of an exit code', IntToStr(SuiteChildTimeout), '6');
  // 259 is STILL_ACTIVE: no result of a setup, another failure
  Check('SuiteChildKind 259', IntToStr(SuiteChildKind(False, 259)), IntToStr(SuiteChildOther));
  CheckBool('SuiteRunSucceeded 259 with an entry', SuiteRunSucceeded(True, 259, True), False);
  CheckBool('SuiteRunSucceeded exit code of a kill', SuiteRunSucceeded(True, SuiteKillCode, True), False);

  // the time limits: no log growth for 10 minutes (asked once), 90 minutes at most, none in the advanced mode
  Check('SuiteStallMs', IntToStr(SuiteStallMs), '600000');
  Check('SuiteProductCapMs', IntToStr(SuiteProductCapMs), '5400000');
  Check('SuiteTimeoutCheck at the start', IntToStr(SuiteTimeoutCheck(0, 0, False, False, False, False)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck a minute before the stall', IntToStr(SuiteTimeoutCheck(900000, SuiteStallMs - 1, False, False, False, False)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck stall', IntToStr(SuiteTimeoutCheck(900000, SuiteStallMs, False, False, False, False)), IntToStr(SuiteTimeoutStall));
  Check('SuiteTimeoutCheck stall asked once', IntToStr(SuiteTimeoutCheck(900000, SuiteStallMs, False, False, True, False)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck a log that grows is no stall', IntToStr(SuiteTimeoutCheck(3600000, 1000, False, False, False, False)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck just below the cap', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs - 1, 1000, False, False, False, False)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck cap', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs, 1000, False, False, False, False)), IntToStr(SuiteTimeoutCap));
  Check('SuiteTimeoutCheck cap before stall', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs, SuiteStallMs, False, False, False, False)), IntToStr(SuiteTimeoutCap));
  Check('SuiteTimeoutCheck cap handled once', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs, 1000, False, False, True, True)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck advanced mode: no stall', IntToStr(SuiteTimeoutCheck(900000, SuiteStallMs, True, False, False, False)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck advanced mode: no cap', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs * 2, 1000, True, False, False, False)), IntToStr(SuiteTimeoutNone));
  // the cap stops only a product setup that has changed nothing in the game folder; one that installs is never stopped for
  // its time (a kill leaves a half installed game), the cap is only logged, once
  Check('SuiteTimeoutCheck cap while installing: only logged', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs, 1000, False, True, False, False)), IntToStr(SuiteTimeoutCapInstalling));
  Check('SuiteTimeoutCheck cap while installing, long after', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs * 3, 1000, False, True, False, False)), IntToStr(SuiteTimeoutCapInstalling));
  Check('SuiteTimeoutCheck cap while installing logged once', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs, 1000, False, True, False, True)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck cap while installing before the stall', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs, SuiteStallMs, False, True, False, False)), IntToStr(SuiteTimeoutCapInstalling));
  Check('SuiteTimeoutCheck stall while installing is still asked', IntToStr(SuiteTimeoutCheck(900000, SuiteStallMs, False, True, False, False)), IntToStr(SuiteTimeoutStall));
  Check('SuiteTimeoutCheck just below the cap while installing', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs - 1, 1000, False, True, False, False)), IntToStr(SuiteTimeoutNone));
  Check('SuiteTimeoutCheck advanced mode while installing: nothing', IntToStr(SuiteTimeoutCheck(SuiteProductCapMs * 2, SuiteStallMs, True, True, False, False)), IntToStr(SuiteTimeoutNone));

  // what the Cancel button does: asks before the product setup installed anything (and a job can stop it), else off
  Check('SuiteCancelMode before it installs', IntToStr(SuiteCancelMode(False, True, False)), IntToStr(SuiteCancelAsk));
  Check('SuiteCancelMode installing', IntToStr(SuiteCancelMode(False, True, True)), IntToStr(SuiteCancelInstalling));
  Check('SuiteCancelMode installing without a job', IntToStr(SuiteCancelMode(False, False, True)), IntToStr(SuiteCancelInstalling));
  Check('SuiteCancelMode before it installs, without a job', IntToStr(SuiteCancelMode(False, False, False)), IntToStr(SuiteCancelNoJob));
  Check('SuiteCancelMode advanced mode', IntToStr(SuiteCancelMode(True, True, False)), IntToStr(SuiteCancelOwnWizard));
  Check('SuiteCancelMode advanced mode, installing', IntToStr(SuiteCancelMode(True, True, True)), IntToStr(SuiteCancelOwnWizard));

  // which of the four texts of the question of Cancel is asked: what stays decides (a repaired game stays as it is, a game this run
  // finished stays installed)
  Check('SuiteCancelQuestionMessage first installation', SuiteCancelQuestionMessage('', False), 'SuiteCancelQuestion');
  Check('SuiteCancelQuestionMessage first installation, EE finished before', SuiteCancelQuestionMessage('EE', False), 'SuiteCancelQuestionKept');
  Check('SuiteCancelQuestionMessage repair', SuiteCancelQuestionMessage('', True), 'SuiteCancelQuestionInstalled');
  Check('SuiteCancelQuestionMessage repair, a game finished before', SuiteCancelQuestionMessage('EE', True), 'SuiteCancelQuestionInstalledKept');

  // the last page says "cancelled" only for a failed game that the user cancelled (SuiteProductResult)
  Check('SuiteCancelledResult the cancelled game', IntToStr(SuiteCancelledResult(SuiteResultFailed, 'NeoEE', 'NeoEE')), IntToStr(SuiteResultCancelled));
  Check('SuiteCancelledResult the id has any case', IntToStr(SuiteCancelledResult(SuiteResultFailed, 'neoee', 'NeoEE')), IntToStr(SuiteResultCancelled));
  Check('SuiteCancelledResult another game stays failed', IntToStr(SuiteCancelledResult(SuiteResultFailed, 'NeoEE', 'EE')), IntToStr(SuiteResultFailed));
  Check('SuiteCancelledResult nobody cancelled', IntToStr(SuiteCancelledResult(SuiteResultFailed, '', 'EE')), IntToStr(SuiteResultFailed));
  Check('SuiteCancelledResult a game that succeeded stays ok', IntToStr(SuiteCancelledResult(SuiteResultOk, 'EE', 'EE')), IntToStr(SuiteResultOk));
  Check('SuiteCancelledResult a game that was not selected stays', IntToStr(SuiteCancelledResult(SuiteResultNotSelected, 'EE', 'EE')), IntToStr(SuiteResultNotSelected));

  // the tick counter of Windows wraps after 49.7 days
  Check('SuiteTicksBetween', IntToStr(SuiteTicksBetween(100, 350)), '250');
  Check('SuiteTicksBetween no time', IntToStr(SuiteTicksBetween(7, 7)), '0');
  Near := $FFFFFF00;
  Wrapped := 100;
  Check('SuiteTicksBetween across the wrap', IntToStr(SuiteTicksBetween(Near, Wrapped)), '356');

  Check('SuitePhaseName start', SuitePhaseName(SuitePhaseStart), 'start');
  Check('SuitePhaseName install', SuitePhaseName(SuitePhaseInstall), 'install');
  Check('SuitePhaseName done', SuitePhaseName(SuitePhaseDone), 'done');
  Check('SuitePhaseName unknown', SuitePhaseName(99), 'unknown');

  // no WM_QUIT is waiting in the queue of this process
  CheckBool('SuitePumpMessages', SuitePumpMessages, True);
end;

// The process runner on real programs: SuiteStartProduct starts them like Exec does and keeps the handle, the exit
// code comes from GetExitCodeProcess (259 is no result), and the job stops a program and what it started. The
// programs are cmd.exe of Windows and this test setup itself with /ProcSleepDir (InitializeSetup of unit_tests.iss):
// like a product setup it is a loader that starts the real setup, a .tmp file in %TEMP%, and waits for it. Nothing
// here starts a setup of the suite.
procedure TestSuiteProcess;
var
  Dir, Cmd: String;
  Proc, Job: THandle;
  Err, Code, I: Integer;
  Alive, Ended: Boolean;
  Msg: TSuiteMsg;
  Started: DWORD;
  Elapsed: Int64;
begin
  Dir := ExpandConstant('{tmp}\suite_proc');
  ForceDirectories(Dir);
  Cmd := ExpandConstant('{sys}\cmd.exe');

  // a program that ends at once: the handle, the wait and the exit code
  Proc := 1;
  Job := 1;
  Err := -1;
  CheckBool('SuiteStartProduct starts a program', SuiteStartProduct(Cmd, '/c exit 7', Dir, Proc, Job, Err), True);
  CheckBool('SuiteStartProduct gives a process handle', Proc <> 0, True);
  CheckBool('SuiteWaitEnd sees the program end', SuiteWaitEnd(Proc, 30000), True);
  Code := -1;
  CheckBool('SuiteProcessExitCode of an ended program', SuiteProcessExitCode(Proc, Code), True);
  Check('SuiteProcessExitCode is the exit code', IntToStr(Code), '7');
  SuiteCloseHandle(Proc);
  if Job <> 0 then
    SuiteCloseHandle(Job);

  // 259 is what GetExitCodeProcess says for a program that has not ended: no result
  CheckBool('SuiteStartProduct starts a program that ends with 259', SuiteStartProduct(Cmd, '/c exit 259', Dir, Proc, Job, Err), True);
  CheckBool('SuiteWaitEnd sees it end', SuiteWaitEnd(Proc, 30000), True);
  Code := -1;
  CheckBool('SuiteProcessExitCode 259 is no result', SuiteProcessExitCode(Proc, Code), False);
  Check('SuiteProcessExitCode 259 leaves the code alone', IntToStr(Code), '-1');
  SuiteCloseHandle(Proc);
  if Job <> 0 then
    SuiteCloseHandle(Job);

  // a program that is not there: no handle, an error code
  Proc := 1;
  Job := 1;
  Err := 0;
  CheckBool('SuiteStartProduct of a missing program', SuiteStartProduct(Dir + '\nothing.exe', '', Dir, Proc, Job, Err), False);
  Check('SuiteStartProduct of a missing program: no process', IntToStr(Proc), '0');
  Check('SuiteStartProduct of a missing program: no job', IntToStr(Job), '0');
  CheckBool('SuiteStartProduct of a missing program: an error code', Err <> 0, True);

  // a program that runs: not ended, no exit code; the job stops it and what it started (the loader and the real
  // setup of this test setup: the second one would write survived.txt after 6 seconds)
  DeleteFile(Dir + '\started.txt');
  DeleteFile(Dir + '\survived.txt');
  CheckBool('SuiteStartProduct starts a setup that starts its real setup', SuiteStartProduct(ExpandConstant('{srcexe}'),
    '/VERYSILENT /SUPPRESSMSGBOXES /ProcSleepDir="' + Dir + '"', Dir, Proc, Job, Err), True);
  if Job = 0 then
    Skip('SuiteKillProduct stops the whole tree', 'the process could not be put in a job object')
  else
  begin
    I := 0;
    while (I < 300) and not FileExists(Dir + '\started.txt') do
    begin
      SuiteWaitEnd(Proc, 100);
      I := I + 1;
    end;
    CheckBool('the real setup it starts is running', FileExists(Dir + '\started.txt'), True);
    Code := -1;
    CheckBool('SuiteProcessExitCode of a running program', SuiteProcessExitCode(Proc, Code), False);
    SuiteKillProduct(Proc, Job);
    CheckBool('SuiteWaitEnd sees the stopped program end', SuiteWaitEnd(Proc, SuiteKillWaitMs), True);
    Code := -1;
    CheckBool('SuiteProcessExitCode of the stopped program', SuiteProcessExitCode(Proc, Code), True);
    Check('the stopped program got SuiteKillCode', IntToStr(Code), IntToStr(SuiteKillCode));
    // the real setup would write survived.txt 6 seconds after it started if the job had not stopped it too
    Sleep(7000);
    CheckBool('the real setup the stopped loader started did not survive', FileExists(Dir + '\survived.txt'), False);
  end;
  SuiteCloseHandle(Proc);
  if Job <> 0 then
    SuiteCloseHandle(Job);
  DeleteFile(Dir + '\started.txt');
  DeleteFile(Dir + '\survived.txt');

  // a WM_QUIT (Setup is closing) ends the wait at once: SuitePumpMessages puts it back for Setup, and a wait that pumped
  // again would find it again and spin for the rest of its time (review of 2026-10-07, finding 10)
  CheckBool('SuiteStartProduct starts a program for the WM_QUIT test', SuiteStartProduct(ExpandConstant('{srcexe}'),
    '/VERYSILENT /SUPPRESSMSGBOXES /ProcSleepDir="' + Dir + '"', Dir, Proc, Job, Err), True);
  SuitePostQuitMessage(0);
  Started := SuiteTickCount;
  Ended := SuiteWaitEnd(Proc, 4000);
  Elapsed := SuiteTicksBetween(Started, SuiteTickCount);
  // take the WM_QUIT out of the queue of the test setup, which would end it otherwise
  while SuitePeekMessage(Msg, 0, SuiteWmQuit, SuiteWmQuit, SuitePmRemove) do
    I := I + 1;
  CheckBool('SuiteWaitEnd gives up when Setup is closing: the program is still running', Ended, False);
  CheckBool('SuiteWaitEnd gives up when Setup is closing: at once, not after the 4 seconds', Elapsed < 2000, True);
  CheckBool('SuitePumpMessages after the WM_QUIT was taken out of the queue', SuitePumpMessages, True);
  SuiteKillProduct(Proc, Job);
  SuiteWaitEnd(Proc, SuiteKillWaitMs);
  SuiteCloseHandle(Proc);
  if Job <> 0 then
    SuiteCloseHandle(Job);
  Sleep(500);
  DeleteFile(Dir + '\started.txt');
  DeleteFile(Dir + '\survived.txt');
  RemoveDir(Dir);
end;
