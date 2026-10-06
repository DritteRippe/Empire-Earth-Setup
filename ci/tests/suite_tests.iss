[Code]
// Tests of the helpers of the suite installer (suite/suite_common.iss), included by unit_tests.iss
// after its own helpers (Check, CheckBool) and run by its InitializeSetup. The helpers compute
// something from their arguments; SuiteFindSliceProblems reads file sizes, so its tests write small
// files into a folder of their own below {tmp}. Nothing here sends a request or starts a program.
// Requires: Check, CheckBool, Results (unit_tests.iss), suite/suite_common.iss; the log tail tests also CreateFile, WriteFile,
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

  // the exact folders of the user data of a product (5 values, nothing else)
  Check('SuiteDataFolderCount', IntToStr(SuiteDataFolderCount), '4');
  Check('SuiteDataFolder 1', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 1), 'C:\Program Files (x86)\Empire Earth\Empire Earth\Users');
  Check('SuiteDataFolder 2', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 2), 'C:\Program Files (x86)\Empire Earth\Empire Earth\Data\Saved Games');
  Check('SuiteDataFolder 3', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 3),
    'C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\Users');
  Check('SuiteDataFolder 4', SuiteDataFolder('C:\Program Files (x86)\Empire Earth', 4),
    'C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\Data\Saved Games');
  Check('SuiteDataFolder trailing backslash', SuiteDataFolder('D:\EE\', 1), 'D:\EE\Empire Earth\Users');
  Check('SuiteDataFolder index 0', SuiteDataFolder('D:\EE', 0), '');
  Check('SuiteDataFolder index 5', SuiteDataFolder('D:\EE', SuiteDataFolderCount + 1), '');
  Check('SuiteDataFolder drive root', SuiteDataFolder('D:\', 1), '');
  Check('SuiteDataFolder empty root', SuiteDataFolder('', 2), '');
  Check('SuiteDataFolder parent folder', SuiteDataFolder('D:\EE\..\..', 1), '');
  Seen := '';
  for I := 1 to SuiteDataFolderCount do
    Seen := Seen + SuiteDataFolder('D:\EE', I) + '|';
  Check('SuiteDataFolder all different', IntToStr(Pos('D:\EE\Empire Earth\Users|D:\EE\Empire Earth\Data\Saved Games|D:\EE\Empire Earth - The Art of Conquest\Users|D:\EE\Empire Earth - The Art of Conquest\Data\Saved Games|', Seen)), '1');

  // the folders removed only if empty, from the inside out, the root last
  Check('SuiteEmptyFolderCount', IntToStr(SuiteEmptyFolderCount), '5');
  Check('SuiteEmptyFolder 1', SuiteEmptyFolder('D:\EE', 1), 'D:\EE\Empire Earth\Data');
  Check('SuiteEmptyFolder 2', SuiteEmptyFolder('D:\EE', 2), 'D:\EE\Empire Earth');
  Check('SuiteEmptyFolder 3', SuiteEmptyFolder('D:\EE', 3), 'D:\EE\Empire Earth - The Art of Conquest\Data');
  Check('SuiteEmptyFolder 4', SuiteEmptyFolder('D:\EE', 4), 'D:\EE\Empire Earth - The Art of Conquest');
  Check('SuiteEmptyFolder 5', SuiteEmptyFolder('D:\EE\', 5), 'D:\EE');
  Check('SuiteEmptyFolder index 6', SuiteEmptyFolder('D:\EE', SuiteEmptyFolderCount + 1), '');
  Check('SuiteEmptyFolder drive root', SuiteEmptyFolder('D:\', 5), '');
  Check('SuiteEmptyFolder empty root', SuiteEmptyFolder('', 5), '');

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
  Crlf, Bom, Blanks: String;
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
  Check('marker install', IntToStr(SuiteTestPhaseAfter('Starting the installation process.')), IntToStr(SuitePhaseInstall));
  Check('marker post install', IntToStr(SuiteTestPhaseAfter('Installation process succeeded.')), IntToStr(SuitePhasePost));
  Check('marker CD keys, EE only', IntToStr(SuiteTestPhaseAfter('Register NeoEE CD Keys for EE')), IntToStr(SuitePhaseCdKeys));
  Check('marker CD keys, EE and AoC', IntToStr(SuiteTestPhaseAfter('Register NeoEE CD Keys for EE and AoC')), IntToStr(SuitePhaseCdKeys));
  Check('marker CD keys result', IntToStr(SuiteTestPhaseAfter('CD Keys generation result: 0')), IntToStr(SuitePhaseCdKeys));
  Check('marker manifest, checking', IntToStr(SuiteTestPhaseAfter('Checking 1966 recorded destinations of installed files for C:\G\_setupdata_EE\files.sha256')),
    IntToStr(SuitePhaseManifest));
  Check('marker manifest, written', IntToStr(SuiteTestPhaseAfter('Manifest: 1905 files, 683.4 MB, 10500 ms, 65.1 MB/s')), IntToStr(SuitePhaseManifest));
  Check('marker done', IntToStr(SuiteTestPhaseAfter('Log closed.')), IntToStr(SuitePhaseDone));

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
