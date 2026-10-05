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
  Check('SuiteListedSize second', IntToStr(SuiteListedSize('10,20,30', 2)), '20');
  Check('SuiteListedSize with blank', IntToStr(SuiteListedSize('10, 20 ,30', 2)), '20');
  Check('SuiteListedSize last', IntToStr(SuiteListedSize('10,20,30', 3)), '30');
  Check('SuiteListedSize past the end', IntToStr(SuiteListedSize('10,20,30', 4)), '-1');
  Check('SuiteListedSize index 0', IntToStr(SuiteListedSize('10,20,30', 0)), '-1');
  Check('SuiteListedSize empty list', IntToStr(SuiteListedSize('', 1)), '-1');
  Check('SuiteListedSize no number', IntToStr(SuiteListedSize('10,x,30', 2)), '-1');
  Check('SuiteListedSize negative', IntToStr(SuiteListedSize('-5', 1)), '-1');
  Check('SuiteListedSize above 4 GB', IntToStr(SuiteListedSize('1,5000000000', 2)), '5000000000');
end;

procedure TestSuiteSliceState;
begin
  Check('SuiteSliceState fine', IntToStr(SuiteSliceState(True, 5, 5)), '0');
  Check('SuiteSliceState missing', IntToStr(SuiteSliceState(False, 0, 5)), '1');
  Check('SuiteSliceState smaller', IntToStr(SuiteSliceState(True, 4, 5)), '2');
  Check('SuiteSliceState larger', IntToStr(SuiteSliceState(True, 6, 5)), '2');
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
  Check('SuiteFindSliceProblems all fine', SuiteFindSliceProblems(Dir, 'Pkg', '3,5,4', 3, 6), '');
  Check('SuiteFindSliceProblems folder with backslash', SuiteFindSliceProblems(AddBackslash(Dir), 'Pkg', '3,5,4', 3, 6), '');
  Check('SuiteFindSliceProblems no slices recorded', SuiteFindSliceProblems(Dir, 'Pkg', '', 0, 6), '');
  Check('SuiteFindSliceProblems wrong size', SuiteFindSliceProblems(Dir, 'Pkg', '3,6,4', 3, 6), 'Pkg-2.bin (5 bytes, expected 6)');
  Check('SuiteFindSliceProblems missing last', SuiteFindSliceProblems(Dir, 'Pkg', '3,5,4,7', 4, 6), 'Pkg-4.bin (missing)');
  Check('SuiteFindSliceProblems two problems', SuiteFindSliceProblems(Dir, 'Pkg', '2,5,4,7', 4, 6),
    'Pkg-1.bin (3 bytes, expected 2)' + Crlf + 'Pkg-4.bin (missing)');
  Check('SuiteFindSliceProblems line limit', SuiteFindSliceProblems(Dir, 'Pkg', '1,1,1,1,1', 5, 2),
    'Pkg-1.bin (3 bytes, expected 1)' + Crlf + 'Pkg-2.bin (5 bytes, expected 1)' + Crlf + '... and 3 more');
  Check('SuiteFindSliceProblems other base name', SuiteFindSliceProblems(Dir, 'Other', '3', 1, 6), 'Other-1.bin (missing)');
  CheckBool('SuiteFindSliceProblems list shorter than the count', Pos('3 slices but 2 sizes (build error)', SuiteFindSliceProblems(Dir, 'Pkg', '3,5', 3, 6)) > 0, True);
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
