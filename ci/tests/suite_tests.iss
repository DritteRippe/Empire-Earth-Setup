[Code]
// Tests of the helpers of the suite installer (suite/suite_common.iss), included by unit_tests.iss
// after its own helpers (Check, CheckBool) and run by its InitializeSetup. The helpers compute
// something from their arguments; SuiteFindSliceProblems reads file sizes, so its tests write small
// files into a folder of their own below {tmp}. Nothing here sends a request or starts a program.
// Requires: Check, CheckBool, Results (unit_tests.iss), suite/suite_common.iss.

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
  CheckBool('SuiteArgumentsNameTask empty', SuiteArgumentsNameTask('', 'neoee_cdkeys'), False);
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
    '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=de /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /TYPE=full');
  Check('SuiteProductArguments repair has no /TYPE',
    SuiteProductArguments(False, False, 'en', Log1, ''),
    '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments advanced first install',
    SuiteProductArguments(True, True, 'fr', Log1, ''),
    '/LANG=fr /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments advanced repair',
    SuiteProductArguments(False, True, 'fr', Log1, ''),
    '/LANG=fr /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');
  Args := SuiteProductArguments(False, False, 'de', Log1, '');
  CheckBool('SuiteProductArguments repair has no /DIR', Pos('/DIR', Args) > 0, False);
  Args := SuiteProductArguments(True, False, 'de', Log1, '');
  CheckBool('SuiteProductArguments first install has no /DIR', Pos('/DIR', Args) > 0, False);
  CheckBool('SuiteProductArguments never /VERYSILENT', Pos('/VERYSILENT', Args) > 0, False);
  Check('SuiteProductArguments language is checked',
    SuiteProductArguments(False, True, 'de /DIR=C:\x', Log1, ''), '/LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '"');

  // the CI pass-through is appended last
  Check('SuiteProductArguments pass-through appended',
    SuiteProductArguments(True, False, 'en', Log1, '/TASKS=full,!certinclude'),
    '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 +
      '" /TYPE=full /TASKS=full,!certinclude');
  Check('SuiteProductArguments pass-through with blanks around',
    SuiteProductArguments(False, False, 'en', Log1, '  /X=1  '),
    '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /X=1');
  Check('SuiteProductArguments pass-through in the advanced mode too',
    SuiteProductArguments(False, True, 'en', Log1, '/X=1'), '/LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /X=1');
  // a /MERGETASKS of the pass-through is merged: one switch only, and the decision on the CD keys survives
  Check('SuiteProductArguments merges /MERGETASKS',
    SuiteProductArguments(False, False, 'en', Log1, '/MERGETASKS=!neoee_cdkeys'),
    '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon,!neoee_cdkeys" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments merges a quoted /MERGETASKS and keeps the rest',
    SuiteProductArguments(True, False, 'en', Log1, '/TASKS=full /MERGETASKS="!neoee_cdkeys,!certinclude" /X=1'),
    '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon,!neoee_cdkeys,!certinclude" /LOG="' + Log1 +
      '" /TYPE=full /TASKS=full /X=1');
  Check('SuiteProductArguments merges two /MERGETASKS',
    SuiteProductArguments(False, True, 'en', Log1, '/MERGETASKS=a /MERGETASKS=b'),
    '/LANG=en /NOICONS /MERGETASKS="!desktopicon,a,b" /LOG="' + Log1 + '"');
  Check('SuiteProductArguments /TYPE of the pass-through replaces /TYPE=full',
    SuiteProductArguments(True, False, 'en', Log1, '/TYPE=compact'),
    '/SILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS /LANG=en /NOICONS /MERGETASKS="!desktopicon" /LOG="' + Log1 + '" /TYPE=compact');

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
