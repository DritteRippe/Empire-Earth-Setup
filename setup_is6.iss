; ---------------------------------------
;        By EnergyCube 2020-2023
;      Empire Earth Community Setup
;     GNU General Public License v3.0
; ---------------------------------------
;   Reborn : discord.com/invite/BjUXbFB
; ---------------------------------------
; Don't change the UTF-8 BOM encoding!
; Without the BOM Inno Setup reads the file as ANSI and breaks non-ASCII characters
; ---------------------------------------
;                 Credit
; ---------------------------------------
; Translations :
;  German   : xXxJannik#0001, AmbozZ_Ger#3847
;  French   : EnergyCube
;  Polish   : Dr.MonaLisa#9523, jorrr1#1558
;  Italian  : Âgræl#9008
;  Spanish  : IvaN#9233, Kurt Z#8222
;  Russian  : FC_Fan#8831
;  Others   : DeepL / DuckDuckGo Translator
; ---------------------------------------
; External Dep.
;   BASS (audio module); downloads use Inno Setup's built-in support (downloads.iss)
; Additional Content
;   Omega (Patch & Neo Content Patch), yukon aka. drex (dreXmod.dll)
;   Dege (DX Wrapper: dgVoodoo), GOG (DX Wrapper), zocker_160 & EnergyCube (Reborn.dll)
; Other Help
;   CyrentiX#1219 (Compatibility), xq_happy#7140 (Compatibility & Chinese files) jorrr1#1558 (Polish files)
;   giord#4697 (Content, Compatibility), IvaN#9233 (Spanish files), FC_Fan#8831 (Russian files)
;   Every members of EE:Reborn team and and all others I may have forgotten :>
; ---------------------------------------
;  Notes  | Empire Earth is very sensitive to version change (which leads to multiplayer incompatibility),
;   for   | some modders might be interested in using this setup to deliver their mods. Please do not do
; Modders | this unless you have created a really popular and functional modpack. We must avoid creating
;         | multiple versions of the game to avoid fracturing the community.
; ---------------------------------------
;  Notes  | Since the script is licensed under the GNU GPL v3 you have every right to modify the setup script
;   for   | to generate your own versions, but you must also publish the source code of the script.
;   Dev   | So I invite you to fork this project if you want and I pray you don't forget that we have to do
;         | everything to unite the community around the world, if you have ideas of modifications to do don't
;         | hesitate to make suggestions, I also invite you to make pull requests if you think you have done
;         | something that deserves to be in this script. The version of the script I'm distributing should
;         | become the standard to facilitate future installations. I hope you understand the objective and
;         | how necessary and helpful it is for everyone.
;         | If you think something is wrong, don't hesitate to tell me!
; ---------------------------------------
;              Release Note
; ---------------------------------------
; Moved to CHANGELOG.md (release notes 1.0.0.0 - 1.7.2 and later).
; ---------------------------------------

; SETUP SETTINGS

#define MySetupVersion "1.7.2"
#define MyAppGroupName "Empire Earth"
; Version of the setup and launcher contract (docs/CONTRACT.md, section 5) that this script
; implements. ci/check_contract.py compares it with the header of the contract; change both together.
; The install record and the defaults marker ([Registry]), install.ini and the value in the
; uninstall key (installstate.iss) carry it (contract 1.1 to 1.3, 3.5).
#define ContractVersion 1

; Build switches
; Each switch below has a default here and can be overridden on the command line instead of
; editing this file:  ISCC /D<Switch>=<Value> setup_is6.iss
;   InstallMode   Regular | Portable                           (default: Regular)
;   InstallType   EE | NeoEE                                   (default: EE)
;   SignSetup     0 | 1 (or false | true), needs the SignTool  (default: 0)
;                 named in [Setup] to be configured (ISCC /S)
;   CertFileName  certificate file in internal\misc            (only used when SignSetup = 1)
;   CertHashSHA1  SHA-1 thumbprint of that certificate         (only used when SignSetup = 1)
;   CertDerFile   DER copy of the certificate to ship, if       (only used when SignSetup = 1,
;                 CertFileName is PEM (ci\build.ps1 sets it)    default: internal\misc\CertFileName)
;   TestID        0 = release build, > 0 = test build          (default: 0)
;   SetupBuild    build identifier for install.ini and the     (default: empty = none)
;                 install record: A-Z a-z 0-9 . _ -, at most 64
;                 characters (ci\build.ps1: test<TestID>-<commit>
;                 for a test build, the short commit in CI)
;   EE_AppID      AppId GUID of the EE setup, without braces   (required, see AppId notes below)
;   NeoEE_AppID   AppId GUID of the NeoEE setup, w/o braces    (required, see AppId notes below)
; Example: ISCC /DInstallType=NeoEE /DInstallMode=Portable /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID> setup_is6.iss
; ci/build.ps1 builds all four InstallType x InstallMode variants, see README.md "Building".

; InstallMode : Regular / Portable
#ifndef InstallMode
  #define InstallMode "Regular"
#endif
#if InstallMode != "Regular" && InstallMode != "Portable"
  #pragma error "Unsupported InstallMode '" + InstallMode + "' (use Regular or Portable)"
#endif

; InstallType : EE / NeoEE
#ifndef InstallType
  #define InstallType "EE"
#endif
#if InstallType != "EE" && InstallType != "NeoEE"
  #pragma error "Unsupported InstallType '" + InstallType + "' (use EE or NeoEE)"
#endif

; Sign Setup/Uninstall

; Note: Signing the setup allows you to avoid the warning messages of Windows (saying that it would be
;       a virus...). A code signing certificate has to be bought.
;       A signed setup also offers to install the joint certificate on the computer (CertInclude,
;       opt-in task certinclude, unchecked by default). It is added to the trusted publishers only,
;       never to the trusted root certification authorities: a root CA could issue certificates
;       for any website or program. So it only helps with a certificate that chains to a trusted
;       root (e.g. one bought from a public CA). If you want to use
;       the community certificate, contact me on discord, I will sign your setup after a verification.
#ifndef SignSetup
  #define SignSetup false
#endif
; ISCC /D passes a string (where even "0" would count as true), a bare /DSignSetup passes no
; value at all: normalize both to false/true
#if TypeOf(SignSetup) == TYPE_NULL
  #define SignSetup true
#endif
#if TypeOf(SignSetup) == TYPE_STRING
  #define SignSetupArg LowerCase(SignSetup)
  #undef SignSetup
  #if SignSetupArg == "1" || SignSetupArg == "true"
    #define SignSetup true
  #endif
  #if SignSetupArg == "0" || SignSetupArg == "false"
    #define SignSetup false
  #endif
  #ifndef SignSetup
    #pragma error "Unsupported SignSetup '" + SignSetupArg + "' (use 0 or 1)"
  #endif
  #undef SignSetupArg
#endif

#if SignSetup
  ; Install Cert
  #define CertInclude true
  ; Cert File Name (needs to be in internal\misc)
  #ifndef CertFileName
    #define CertFileName "cert_name.crt"
  #endif
  ; Cert Hash SHA1 (very important, needed to uninstall the cert)
  #ifndef CertHashSHA1
    #define CertHashSHA1 ""
  #endif
#else
  #define CertInclude false
#endif

#if CertInclude
  ; The thumbprint identifies the certificate before it is added (IsCertificateFileGenuine) and
  ; when it is removed on uninstall, so it has to be the one of the certificate file the setup
  ; ships. That file must be DER encoded: then its SHA-1 is the thumbprint. The community
  ; certificate in internal\misc is PEM (base64 text), which ISPP cannot decode (no base64
  ; decoding, no binary strings) and whose file SHA-1 is not the thumbprint, so ci\build.ps1
  ; writes a DER copy and passes it as CertDerFile (relative to this file, or absolute). The setup
  ; extracts it as {tmp}\<CertFileName>; certutil reads DER and PEM alike.
  #ifndef CertDerFile
    #define CertDerFile "internal\misc\" + CertFileName
  #endif
  #if Copy(CertDerFile, 2, 1) == ":" || Copy(CertDerFile, 1, 2) == "\\"
    #define CertDerPath CertDerFile
  #else
    #define CertDerPath AddBackslash(SourcePath) + CertDerFile
  #endif
  #define CertThumbprint LowerCase(StringChange(CertHashSHA1, " ", ""))
  #if Len(CertThumbprint) != 40
    #error CertHashSHA1 must be the SHA-1 thumbprint (40 hex digits) of the certificate when SignSetup is enabled
  #endif
  ; (A missing file is reported by its [Files] entry; the first pass of a placeholder build runs
  ; before the placeholder exists and skips the comparison.)
  #if FileExists(CertDerPath)
    #if GetSHA1OfFile(CertDerPath) != CertThumbprint
      ; Tell a PEM file apart, the usual mistake
      #define CertFileFirstLine ""
      #define CertFileHandle FileOpen(CertDerPath)
      #if CertFileHandle
        #if !FileEof(CertFileHandle)
          #expr CertFileFirstLine = Trim(FileRead(CertFileHandle))
        #endif
        #expr FileClose(CertFileHandle)
      #endif
      #if Pos("-----BEGIN", CertFileFirstLine) > 0
        #pragma error CertDerFile + " is PEM encoded: build with ci\build.ps1 -SignSetup, which ships a DER copy, or convert it and pass the copy with /DCertDerFile=<file> (see README.md, Signed builds)"
      #else
        #pragma error "CertHashSHA1 is not the SHA-1 thumbprint of " + CertDerFile + " (the certificate file must be DER encoded)"
      #endif
    #endif
  #endif
#endif

; Regedit (the game settings keys BaseRegEE and BaseRegAoC are in the product configuration)
#define BaseRegCompatibility = "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
; Install record and defaults marker of the setup and launcher contract (docs/CONTRACT.md 1.1, 3.5)
#define BaseRegCommunity = "Software\Empire Earth Community"

; Windows versions for the MinVersion and OnlyBelowVersion parameters. Inno Setup 6 ignores the
; part before the comma (Windows 95/98/Me) and reads a single value as the Windows NT version:
; "0.0,6.2", "0,6.2" and "6.2" all mean NT 6.2 (= Windows 8), while "0.6.2" would be version 0.6
; build 2, which no Windows is below. Setups made with Inno Setup 6 only start on Windows 7 SP1
; and later, so a minimum of Windows Vista or older always holds.
#define Win2000 "0.0,5.0"
#define WinXP "0.0,5.1"
#define WinVista "0.0,6.0"
#define Win7 "0.0,6.1"
#define Win8 "0.0,6.2"
#define Win10 "0.0,10"

; TestID (0 if Release)
#ifndef TestID
  #define TestID = 0
#endif
; ISCC /D passes a string: convert it (invalid values become -1 and are rejected)
#if TypeOf(TestID) != TYPE_INTEGER
  #define TestID Int(TestID, -1)
#endif
#if TestID < 0
  #error TestID must be a non-negative integer (0 = release build)
#endif

; SetupBuild: identifier of this build. install.ini and the install record carry it (contract 1.1,
; 1.2, docs/adr/0004-install-record-and-integrity-manifest.md point 10), so that builds of the same
; MySetupVersion can be told apart, e.g. test builds (MySetupVersion stays until a release).
; ci\build.ps1 passes test<TestID>-<commit> for a test build and the short Git commit in CI; empty
; (the default) writes no SetupBuild value. Only A-Z a-z 0-9 . _ - (it is written into the registry
; and into install.ini, which is ASCII), at most 64 characters.
#ifndef SetupBuild
  #define SetupBuild ""
#endif
; A bare /DSetupBuild or /DSetupBuild= passes no value: none as well
#if TypeOf(SetupBuild) == TYPE_NULL
  #undef SetupBuild
  #define SetupBuild ""
#endif
; S without the characters of Chars (case-sensitive)
#define StripChars(str S, str Chars) Chars == "" ? S : StripChars(StringChange(S, Copy(Chars, 1, 1), ""), Copy(Chars, 2))
#if Len(SetupBuild) > 64 || StripChars(LowerCase(SetupBuild), "0123456789abcdefghijklmnopqrstuvwxyz._-") != ""
  #pragma error "SetupBuild '" + SetupBuild + "' is not a build identifier (A-Z a-z 0-9 . _ -, at most 64 characters)"
#endif

; END SETUP SETTINGS

; Reminder
; Update MyAppVersion if the update is a game update
; Update MySetupVersion if the update is a setup update
; Update MySetupVersion if updating MyAppVersion only if the setup is really updated
; When releasing a new MySetupVersion, it should be distributed for both EE & Neo
; MySetupVersion is a good way to know the features of the setup, meaning that EE & Neo should share the same version !
; When releasing, turn the "Unreleased" section of CHANGELOG.md into the new MySetupVersion

#ifndef EE_AppID
  #define EE_AppID ""
#endif
#ifndef NeoEE_AppID
  #define NeoEE_AppID ""
#endif

; Both AppIds are empty in the repository, so every build has to provide them (see AppId notes below).
; Both are needed in every variant: each setup also checks the uninstall key of the other product.
; Never build without them: an empty AppId turns "{app}\{#AppID}" into "{app}\" and lets EE and
; NeoEE share one uninstall key.
; A plain GUID is 32 hex digits with dashes at positions 9, 14, 19 and 24: removing every hex digit
; must leave exactly the four dashes. This also keeps "\", "/", "." and ":" out of the AppId, which
; [InstallDelete] uses in a path that it deletes recursively.
#define GuidStripDigits(str S) StringChange(StringChange(StringChange(StringChange(StringChange(StringChange(StringChange(StringChange(StringChange(StringChange(S, "0", ""), "1", ""), "2", ""), "3", ""), "4", ""), "5", ""), "6", ""), "7", ""), "8", ""), "9", "")
#define GuidStripHex(str S) StringChange(StringChange(StringChange(StringChange(StringChange(StringChange(GuidStripDigits(LowerCase(S)), "a", ""), "b", ""), "c", ""), "d", ""), "e", ""), "f", "")
#define IsPlainGuid(str S) Len(S) == 36 && Copy(S, 9, 1) == "-" && Copy(S, 14, 1) == "-" && Copy(S, 19, 1) == "-" && Copy(S, 24, 1) == "-" && GuidStripHex(S) == "----"
#if EE_AppID == "" || NeoEE_AppID == ""
  #error EE_AppID and NeoEE_AppID must be set: pass ISCC /DEE_AppID=<GUID> /DNeoEE_AppID=<GUID> or edit their defines (see AppId notes)
#endif
#if !IsPlainGuid(EE_AppID)
  #pragma error "EE_AppID '" + EE_AppID + "' is not a GUID without braces (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)"
#endif
#if !IsPlainGuid(NeoEE_AppID)
  #pragma error "NeoEE_AppID '" + NeoEE_AppID + "' is not a GUID without braces (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)"
#endif
#if EE_AppID == NeoEE_AppID
  #error EE_AppID and NeoEE_AppID must differ, otherwise EE and NeoEE share one AppId and uninstall key
#endif

; Product configuration: the values that differ between the EE and the NeoEE setup (AppId, name,
; version, URL, registry keys, icons, sign tool, output file name), see config_ee.iss and
; config_neoee.iss. InstallType is checked above, so exactly one of them is included.
#include AddBackslash(SourcePath) + "config_" + LowerCase(InstallType) + ".iss"

; Hidden folder in {app} for the files the uninstaller needs (EEStatsSetup.dll) and the lists of
; randommaps.iss. It has a fixed name per product (InstallType is EE or NeoEE, checked above), so
; that no build setting can turn it into {app} itself, and EE and NeoEE installed into the same
; folder do not share it (uninstalling one would delete the files of the other). Setups up to
; v1.7.2 named it after the AppId ("{app}\<AppId>"); [InstallDelete] removes that old folder.
#define SetupDataDir "_setupdata_" + InstallType

; Game folders below {app} (Empire Earth and its add-on The Art of Conquest), the game programs
; relative to {app}, and the random map folder inside a game folder. The sections and the [Code]
; use these names, only the source folders below data\ name the game folders themselves.
#define EEDir "Empire Earth"
#define AoCDir "Empire Earth - The Art of Conquest"
#define EEExe EEDir + "\Empire Earth.exe"
#define AoCExe AoCDir + "\EE-AOC.exe"
#define RmsSubDir "Data\Random Map Scripts"

; dgVoodoo version of the DirectX 11/12 wrappers (data\Add-on\DirectX_Wrapper\dgVoodoo_bin), shown
; in the component descriptions
#define DgVoodooVersion "v2.82.1"

; Game languages, in the order of the language page. Each one is the component language\<name>,
; described by the custom message LIQP_<name> (messages.iss); a name that is also in [Languages]
; is preselected when the setup itself runs in that language. The files of a language are in
; data\localized-text\ and, for NeoEE, data\localized-text\Mods\NeoEE\:
;   Game\<name with "-" instead of "_">\<EE|AoC>\Language.dll   (see GetLanguageTag)
;   Lobby\<its GameLangLobbyDirs entry>\<EE|AoC|shared>\*        (one lobby folder can serve
;                                                                  several languages, e.g. zh)
; The language entries of [Components] and [Files] and the list of RegisterLangs are generated
; from these lists. To add a language: add it to both lists, raise GameLangCount, add its
; LIQP_<name> message and its files.
#define GameLangCount 11
#dim GameLangs[GameLangCount] {"de", "en", "es", "fr", "it", "ko", "pl", "pt_BR", "ru", "zh_CN", "zh_TW"}
#dim GameLangLobbyDirs[GameLangCount] {"de", "en", "es", "fr", "it", "ko", "pl", "pt-BR", "ru", "zh", "zh"}
#define LangIndex 0

; AppId: Tools > Generate GUID
; Be very careful with AppId, it's like the unique id of the setup, be sure to generate it with inno setup
; the first time you distribute your setup and to keep it forever for the setup !
; So since it's a unique setup id, EE & NeoEE must have different AppId !

[Setup]
; SignTool: We need to use InnoSetup SignTool feature to sign install/uninstall etc...
AppId={{{#AppID}}
SetupIconFile={#MySetupIconFile}
WizardSmallImageFile={#MyWizardSmallImageFile}
#if SignSetup
  SignTool={#MySignTool} $f
#endif
SetupMutex={#InstallType}_Setup
AppMutex=StainlessSteelStudiosPresentsEmpireEarth,MadDocSoftwarePresentsEmpireEarthExpansion
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoVersion={#MySetupVersion}
VersionInfoCopyright={#MyAppPublisher}
AppVerName={#MyAppName} v{#MyAppVersion} - Setup v{#MySetupVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultGroupName={#MyAppGroupName}
AllowNoIcons=yes
LicenseFile=data\Empire Earth Base\Empire Earth\EULA_DSML.txt
#if MyInfoBeforeFile != ""
  InfoBeforeFile={#MyInfoBeforeFile}
#endif
InfoAfterFile=data\Empire Earth Base\Empire Earth\help.rtf
OutputDir=out
; lzma2/max = 32 MB of RAM (noticed 42 MB on W10 & XP)
; Since EE needs 64 MB (including Windows), lzma2/max is the maximum compression
#if TestID == 0
  Compression=lzma2/max
#else
  Compression=zip/1
#endif
SolidCompression=no
LZMAUseSeparateProcess=yes
WizardImageFile=internal\media\SetupBanner.bmp
WindowVisible=True
WindowResizable=False
WindowShowCaption=False
UninstallDisplayIcon={uninstallexe}
DirExistsWarning=no
ShowLanguageDialog=auto
; Every run writes a log, "Setup Log <yyyy-mm-dd> #<nnn>.txt" in the temporary folder (%TEMP%) of
; the account that runs the setup (with over-the-shoulder elevation: the administrator account
; that elevated it), so that players can send it without knowing /LOG; /LOG=<file> still writes
; to <file> instead. The uninstaller writes a log only with /LOG. ADR 0008 point 5, README "Support".
SetupLogging=yes


#if Ver >= EncodeVer(6, 0, 0)
  WizardStyle=modern
#else
  WizardStyle=classic
#endif

; Windows 10/11 ARM
; EE working on ARM thanks to the Windows x86 to ARM translation
; By not defining ArchitecturesAllowed IS will allow the setup to run
; on any machine supporting x86 (so ARM emulation will work)
; So never uncomment that line unless we want to restrict the install to some arch
; ArchitecturesAllowed=x86 x64 arm64

; The game is 32-bit: the 64-bit install mode is only used so that the registry entries (e.g. the
; compatibility flags in HKLM) are written to the 64-bit view instead of being redirected to
; WOW6432Node on 64-bit Windows. It also makes {sys} the 64-bit System32 folder and puts the
; uninstall key into the 64-bit view.
; TODO: install in 32-bit mode and choose the registry view per entry instead (HKLM64/HKCU64 with
; Check: IsWin64, HKLM/HKCU otherwise). That changes the view of the uninstall key and of every
; [Registry] entry and the meaning of {sys}, so updates over existing installations must be tested
; on 32-bit and 64-bit Windows before.
ArchitecturesInstallIn64BitMode=x64 arm64 ia64

; Warning for MinVersion < 6.1sp1
; From IS 6, Windows < 6.1sp1 has been disabled for security reasons.
; We can force it to support from Windows 6.0 (Vista) but that's *insecure*
; Keeping that security is okay I think, creating a legacy setup with IS 5
; would be the real solution for that problem since it's clearly 'legacy'
; MinVersion=6.0

; If for any reason, Setup is reported to be a virus uncomment this to crypt files...
; The setup will display the password when asked to the user :)
; Also the setup should work, remember that any resources used before the password
; validation need the 'noencryption' flag in Inno Setup !
; Encryption=yes
; Password={#MySetupPassword}

#if InstallMode == "Regular"
  PrivilegesRequiredOverridesAllowed=commandline dialog
  UsePreviousAppDir=yes
  Uninstallable=yes
  CreateUninstallRegKey=yes
  PrivilegesRequired=admin
  DefaultDirName={autopf32}\{#MyInstallDirName}
  OutputBaseFilename={#InstallType}{#MyOutputVersionPart}_Setup_v{#MySetupVersion}
#elif InstallMode == "Portable"
  UsePreviousAppDir=no
  Uninstallable=no
  CreateUninstallRegKey=no
  PrivilegesRequired=lowest
  DefaultDirName={src}\{#MyInstallDirName} Portable
  OutputBaseFilename={#InstallType}_Portable{#MyOutputVersionPart}_Setup_v{#MySetupVersion}
#else
  #error Unsupported Install Mode
#endif

; Includes
; The own .iss files are parts of this script, not independent units: they use the defines above
; and each other, and Pascal Script only knows what is declared before it is used. So the order
; of the includes here and in [Code] matters. Every own file lists what it requires in its header.
;   config_ee.iss / config_neoee.iss  product configuration, included further up after the
;                   AppId checks (needs EE_AppID, NeoEE_AppID)
;   utils.iss       [Code] base helpers: URL constants, string and language helpers, uninstall
;                   keys, HTTP requests, URL checks (needs AppID, OtherAppID; first, every other
;                   [Code] part may use it)
;   messages.iss    [CustomMessages] and [Messages] (needs InstallType, MyAppVersion,
;                   MySetupVersion, MySetupPassword)
;   bass.iss        third-party: setup music (needs BassLoopSound)
; The other own files are included in [Code], see there. Defines that included files use must be
; defined above the first #sub ([Components]), see the ISPP note there.
#include "utils.iss"
#include "messages.iss"
#define BassLoopSound "internal\misc\Loop.flac"
#include "internal\lib\bass\bass.iss"

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\german.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "es"; MessagesFile: "compiler:Languages\spanish.isl"
Name: "fr"; MessagesFile: "compiler:Languages\french.isl"
Name: "it"; MessagesFile: "compiler:Languages\italian.isl"
Name: "ko"; MessagesFile: "internal\unofficial_isl\IS6\korean.isl"
Name: "pl"; MessagesFile: "compiler:Languages\Polish.isl"
Name: "pt_BR"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "zh_CN"; MessagesFile: "internal\unofficial_isl\IS6\ChineseSimplified.isl"
Name: "zh_TW"; MessagesFile: "internal\unofficial_isl\IS6\ChineseTraditional.isl"

; Additional for Setup
Name: "hy"; MessagesFile: "compiler:Languages\Armenian.isl"
Name: "bg"; MessagesFile: "compiler:Languages\Bulgarian.isl"
Name: "ca"; MessagesFile: "compiler:Languages\Catalan.isl"
Name: "cs"; MessagesFile: "compiler:Languages\Czech.isl"
Name: "da"; MessagesFile: "compiler:Languages\Danish.isl"
Name: "nl"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "fi"; MessagesFile: "compiler:Languages\Finnish.isl"
Name: "he"; MessagesFile: "compiler:Languages\Hebrew.isl"
Name: "is"; MessagesFile: "compiler:Languages\Icelandic.isl"
Name: "ja"; MessagesFile: "compiler:Languages\Japanese.isl"
Name: "nb"; MessagesFile: "compiler:Languages\Norwegian.isl"
Name: "pt_PT"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "sk"; MessagesFile: "compiler:Languages\Slovak.isl"
Name: "sl"; MessagesFile: "compiler:Languages\Slovenian.isl"
Name: "tr"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "uk"; MessagesFile: "compiler:Languages\Ukrainian.isl"

[Types]
Name: "full"; Description: "{cm:TypeFull}";
Name: "compact"; Description: "{cm:TypeCompact}";
Name: "custom"; Description: "{cm:TypeCustom}"; Flags: iscustom
Name: "raw"; Description: "{cm:TypeRaw}";

[Tasks]
; Compatibility values (see [Registry]): Windows 8 and later by default. On Windows Vista/7 the
; setup writes none by default, like the official 1.7.2 setups for Empire Earth.exe, and an update
; removes those of earlier setups (RemoveLegacyVistaCompatValues);
; docs/adr/0005-compatibility-and-wrapper-defaults.md
Name: "compatibility"; Description: "{cm:TaskCompatibility}"; MinVersion: {#Win8}; Check: not IsWine
Name: "compatibility_windows"; Description: "{cm:TaskCompatibilityWindows}"; MinVersion: {#Win8}; Check: not IsWine
; Opt-in on Windows 7 only: the flags of the task compatibility, never a Windows compatibility mode
; (official 1.7.2 wrote them with the Windows XP SP3 mode for EE-AOC.exe);
; docs/adr/0010-opt-in-compatibility-on-windows-7.md
Name: "compatibility_legacy"; Description: "{cm:TaskCompatibilityLegacy}"; OnlyBelowVersion: {#Win8}; Flags: unchecked; Check: not IsWine
Name: "firewallexception"; Description: "{cm:TaskFirewall}"; MinVersion: {#Win2000}; Check: IsAdminInstallMode and not IsWine
; DirectPlay: Windows feature used by old DirectX games, the GOG setup enables it too (see [Run])
Name: "directplay"; Description: "{cm:TaskDirectPlay}"; MinVersion: {#Win8}; Check: IsAdminInstallMode
Name: "dxwebsetup"; Description: "{cm:TaskDxWebSetup}"; MinVersion: {#Win2000}; Check: IsAdminInstallMode and not IsWine; Components: additional\directx_wrapper\dx9 or not additional\directx_wrapper
#if InstallType == "NeoEE"
  ; Since 1.0.1.0 NeoEE CDKeys support HKLM & HKCU
  Name: "neoee_cdkeys"; Description: "{cm:TaskNeoEECDKeys}"; MinVersion: {#Win2000};
#endif

#if CertInclude
  ; Opt-in, also for administrators: adds the community certificate to the trusted publishers
  ; (all users in administrative install mode, else the current user), never to the root CAs
  Name: "certinclude"; Description: "{cm:TaskCertInclude}"; MinVersion: {#WinVista}; Flags: unchecked; Check: not IsWine
#endif

; Opt-in: the game (online lobby, maps and scenarios from other players) should not run elevated.
; Selected, it sets RUNASADMIN for all users (HKLM) and skips the write permissions below.
Name: "everyoneadminstart"; Description: "{cm:TaskAdminStart}"; MinVersion: {#WinXP}; Flags: unchecked; Check: IsAdminInstallMode and not IsWine

#if InstallMode != "Portable"
  Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
#endif

[Components]
; The descriptions are custom messages (messages.iss), only names of games, mods and content packs
; are not translated
Name: "game"; Description: "{#MyAppName}"; Types: full compact custom raw; Flags: fixed
; ------------------
Name: "gameaoc"; Description: "{#MyAppName} : The Art of Conquest"; Types: full
; ------------------

Name: "additional"; Description: "{cm:CompAdditional}"

Name: "additional\movies"; Description: "{cm:CompMovies}"; Flags: disablenouninstallwarning;

Name: "additional\hd"; Description: "{cm:CompHD}"; Flags: disablenouninstallwarning; Types: full
Name: "additional\hd\terrain"; Description: "{cm:CompByAuthor,HD Terrain v1.0,Sleeper & Yukon}"; Types: full
Name: "additional\hd\music"; Description: "{cm:CompByAuthor,HQ Musics WIP,Fortuking}"; Types: full
Name: "additional\hd\buildings"; Description: "{cm:CompByAuthor,HD Buildings Icons v3.0,Fortuking}"; Types: full;
Name: "additional\hd\tech"; Description: "{cm:CompByAuthor,HD Tech Icons v3.0.1,Fortuking}"; Types: full;
Name: "additional\hd\effects"; Description: "{cm:CompByAuthor,HD Effects WIP,Fortuking}"; Types: full;

Name: "additional\drexmod"; Description: "{cm:CompDrexmod}"
; v3 is preselected (full and compact installation), v2 can be chosen instead
Name: "additional\drexmod\v3"; Description: "{cm:CompDrexmodV3}"; Flags: exclusive disablenouninstallwarning; Types: full compact; MinVersion: {#WinXP}
Name: "additional\drexmod\v2"; Description: "{cm:CompDrexmodV2}"; Flags: exclusive disablenouninstallwarning; MinVersion: {#WinXP}

#if InstallType == "EE"
  Name: "additional\rms"; Description: "{cm:CompRms}";
  Name: "additional\rms\omega"; Description: "Omega Pack";
  Name: "additional\rms\neoextra"; Description: "NeoEE Extra";
#endif

Name: "additional\directx_wrapper"; Description: "{cm:CompDxWrapper}"; Flags: disablenouninstallwarning; MinVersion: {#Win7}
Name: "additional\directx_wrapper\dx7"; Description: "DirectX 7 [{cm:CompTagLightest}]"; Flags: exclusive disablenouninstallwarning; MinVersion: {#Win7}
Name: "additional\directx_wrapper\dx9"; Description: "DirectX 9 [{cm:CompTagMostCompatible}]"; Flags: exclusive disablenouninstallwarning; MinVersion: {#Win7}
Name: "additional\directx_wrapper\dx11_lvl10"; Description: "{cm:CompDxWrapperLevel,11,10,{#DgVoodooVersion}}"; Flags: exclusive disablenouninstallwarning; MinVersion: {#Win7}
Name: "additional\directx_wrapper\dx11_lvl10_1"; Description: "{cm:CompDxWrapperLevel,11,10.1,{#DgVoodooVersion}}"; Flags: exclusive disablenouninstallwarning; MinVersion: {#Win7}
Name: "additional\directx_wrapper\dx11_lvl11"; Description: "{cm:CompDxWrapperLevel,11,11,{#DgVoodooVersion}} [{cm:CompTagRecommended}]"; Flags: exclusive disablenouninstallwarning; MinVersion: {#Win7}
Name: "additional\directx_wrapper\dx12_lvl11"; Description: "{cm:CompDxWrapperLevel,12,11,{#DgVoodooVersion}} [{cm:CompTagExperimental}]"; Flags: exclusive disablenouninstallwarning; MinVersion: {#Win10};
Name: "additional\directx_wrapper\dx12_lvl12"; Description: "{cm:CompDxWrapperLevel,12,12,{#DgVoodooVersion}} [{cm:CompTagExperimental}]"; Flags: exclusive disablenouninstallwarning; MinVersion: {#Win10};

Name: "additional\telemetry"; Description: "{cm:CompTelemetry}"; Flags: disablenouninstallwarning; MinVersion: {#Win7}
Name: "additional\discord"; Description: "{cm:CompDiscord}"; Flags: disablenouninstallwarning; Types: full compact; MinVersion: {#Win7}; Check: not IsWine
Name: "additional\tools"; Description: "{cm:CompTools}";
Name: "additional\tools\diagnostic"; Description: "Empire Earth Diagnostic"; Flags: disablenouninstallwarning; Types: full compact; MinVersion: {#Win7}; Check: not IsWine
Name: "additional\civs"; Description: "{cm:CompCivs}"
Name: "additional\civs\ec"; Description: "{cm:CompCivsEcStandard}"; Types: full compact
Name: "additional\civs\ec_full"; Description: "{cm:CompCivsEcFull}"; Types: full

Name: "language"; Description: "{cm:CompLanguage}"; Types: full compact custom raw; Flags: disablenouninstallwarning fixed;
; One exclusive component per game language (GameLangs).
; Note: this is the first #for of the script. After a #sub has run (#for or #call), ISPP 6.2 makes
; the plain #defines that follow in the same file invisible inside subs and in files included
; later. So #defines that included files use must stay above this point, and the variables of
; the subs below are declared with "#define public".
#sub GameLangComponent
  #if TypeOf2(GameLangs[LangIndex]) != TYPE_STRING || GameLangs[LangIndex] == "" || TypeOf2(GameLangLobbyDirs[LangIndex]) != TYPE_STRING || GameLangLobbyDirs[LangIndex] == ""
    #pragma error "Game language " + Str(LangIndex + 1) + " of " + Str(GameLangCount) + " is missing in GameLangs or GameLangLobbyDirs"
  #endif
Name: "language\{#GameLangs[LangIndex]}"; Description: "{cm:LIQP_{#GameLangs[LangIndex]}}"; Flags: exclusive;
#endsub
#for {LangIndex = 0; LangIndex < GameLangCount; LangIndex++} GameLangComponent
; Only offered if the setup can download any localized file (downloads.iss)
Name: "language\update"; Description: "{cm:CompLanguageUpdate}"; Types: full compact custom raw; Flags: disablenouninstallwarning; Check: CanDownloadOnlineFiles

; Localized text of one game in [Files]: for every game language (GameLangs) its Language.dll,
; then the lobby files of the game, then the lobby files shared by EE and AoC, each with the
; component of its language. Set the parameters with #expr, then #call LocalizedTextFiles:
;   LocTextBase  folder below data\localized-text\: "" or "Mods\NeoEE\" (NeoEE versions)
;   LocTextGame  EE or AoC: subfolder of the language folders
;   LocTextDir   game folder below {app}
;   LocTextComp  component of the game (game or gameaoc)
; (public: see the note at GameLangComponent)
#define public LocTextBase ""
#define public LocTextGame ""
#define public LocTextDir ""
#define public LocTextComp ""
#define public LocTextLobbySub ""
#define public LobbyLangIndex 0
#define public LobbyLangCond ""
#define public LobbyLangCount 0
#define public LobbyLangFirst 0
#sub LocalizedLanguageDll
Source: "data\localized-text\{#LocTextBase}Game\{#StringChange(GameLangs[LangIndex], "_", "-")}\{#LocTextGame}\Language.dll"; DestDir: "{app}\{#LocTextDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: {#LocTextComp} and language\{#GameLangs[LangIndex]}; AfterInstall: RecordInstalledFile
#endsub
; Adds the language LobbyLangIndex to LobbyLangCond if it uses the lobby folder of LangIndex
#sub CollectLobbyLang
  #if GameLangLobbyDirs[LobbyLangIndex] == GameLangLobbyDirs[LangIndex]
    #if LobbyLangIndex < LangIndex
      #expr LobbyLangFirst = 0
    #endif
    #expr LobbyLangCond = LobbyLangCond + (LobbyLangCount > 0 ? " or " : "") + "language\" + GameLangs[LobbyLangIndex]
    #expr LobbyLangCount++
  #endif
#endsub
; One entry per lobby folder (at its first language), for all languages that use it
#sub LocalizedLobbyFiles
  #expr LobbyLangCond = "", LobbyLangCount = 0, LobbyLangFirst = 1
  #for {LobbyLangIndex = 0; LobbyLangIndex < GameLangCount; LobbyLangIndex++} CollectLobbyLang
  #if LobbyLangFirst
    #if LobbyLangCount > 1
      #expr LobbyLangCond = "(" + LobbyLangCond + ")"
    #endif
Source: "data\localized-text\{#LocTextBase}Lobby\{#GameLangLobbyDirs[LangIndex]}\{#LocTextLobbySub}\*"; DestDir: "{app}\{#LocTextDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: {#LocTextComp} and {#LobbyLangCond}; AfterInstall: RecordInstalledFile
  #endif
#endsub
#sub LocalizedTextFiles
  #for {LangIndex = 0; LangIndex < GameLangCount; LangIndex++} LocalizedLanguageDll
  #expr LocTextLobbySub = LocTextGame
  #for {LangIndex = 0; LangIndex < GameLangCount; LangIndex++} LocalizedLobbyFiles
  #expr LocTextLobbySub = "shared"
  #for {LangIndex = 0; LangIndex < GameLangCount; LangIndex++} LocalizedLobbyFiles
#endsub

; Add-on files of one game (folder AddOnDir below {app}, component AddOnComp), in this order:
; dreXmod, random maps (EE setups; Omega has a version per game in its subfolder AddOnOmega),
; DirectX wrappers, civilizations, Discord presence. Set the parameters with #expr, then
; #call GameAddOnFiles.
#define public AddOnDir ""
#define public AddOnComp ""
#define public AddOnOmega ""
#sub GameAddOnFiles
; dreXmod 2 (+privacy patched dll, because nothing allows to disable it in config)
Source: "data\Add-on\DLLs\dreXmod\2\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DLLs\dreXmod\2_privacy\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and {#AddOnComp} and not additional\telemetry; AfterInstall: RecordInstalledFile
; dreXmod 3 (+privacy config)
Source: "data\Add-on\DLLs\dreXmod\3\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DLLs\dreXmod\3_privacy\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and {#AddOnComp} and not additional\telemetry; AfterInstall: RecordInstalledFile
  #if InstallType == "EE"
; Random maps (NeoEE setups install them with the NeoEE base files)
Source: "data\Add-on\RMS\Omega\{#AddOnOmega}\*"; DestDir: "{app}\{#AddOnDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\omega and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#AddOnDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\neoextra and {#AddOnComp}; AfterInstall: RecordInstalledFile
  #endif
; dgVoodoo binaries (DirectX 11/12 wrapper) or DDraw.dll (GOG for dx9, DDrawCompat for dx7)
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_bin\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper and {#AddOnComp} and not additional\directx_wrapper\dx9 and not additional\directx_wrapper\dx7; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DirectX_Wrapper\GOG\DDraw.dll"; DestDir: "{app}\{#AddOnDir}"; DestName: "DDraw.dll"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx9 and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DirectX_Wrapper\DDrawCompat\DDraw.dll"; DestDir: "{app}\{#AddOnDir}"; DestName: "DDraw.dll"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx7 and {#AddOnComp}; AfterInstall: RecordInstalledFile
; dgVoodoo configuration of the selected API level
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10 and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10_1.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10_1 and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL11.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl11 and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL11.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl11 and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL12.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl12 and {#AddOnComp}; AfterInstall: RecordInstalledFile
; Civilizations
Source: "data\Add-on\Civs\eC\*"; DestDir: "{app}\{#AddOnDir}\Users\default\Civilizations"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec and {#AddOnComp}; AfterInstall: RecordInstalledFile
Source: "data\Add-on\Civs\eC_full\*"; DestDir: "{app}\{#AddOnDir}\Users\default\Civilizations"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec_full and {#AddOnComp}; AfterInstall: RecordInstalledFile
; Discord presence
Source: "data\Add-on\DLLs\Discord\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\discord and {#AddOnComp}; AfterInstall: RecordInstalledFile
#endsub

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
; Integrity manifest (docs/CONTRACT.md 2.3, ADR 0004 point 3): every compiled entry below {app} has
; "AfterInstall: RecordInstalledFile" (installstate.iss), which records the destination of each
; file the entry installs or keeps for files.sha256. Not on the setup data folder, not on
; deleteafterinstall files and not on external entries: Inno Setup calls the AfterInstall of an
; external entry once for all its files, so installstate.iss adds the verified online files from
; {tmp}\verified itself. Every entry below {app} also has ignoreversion and none keeps an existing
; file (onlyifdoesntexist, promptifolder, confirmoverwrite). ci/check_contract.py checks all of it.
#if CertInclude
  ; DER encoded (CertDerFile), extracted under the name of the certificate (IsCertificateFileGenuine)
  Source: "{#CertDerFile}"; DestDir: "{tmp}"; DestName: "{#CertFileName}"; Flags: deleteafterinstall; Tasks: certinclude;
#endif

Source: "data\Add-on\DLLs\EEStats\EEStatsSetup.dll"; DestDir: "{app}\{#SetupDataDir}"; Flags: noencryption nocompression ignoreversion recursesubdirs createallsubdirs; MinVersion: {#WinXP}

#if InstallType == "EE"
  Source: "internal\media\SetupBackground-4-3.bmp"; DestDir: "{tmp}"; DestName: "SetupBackground-4-3.bmp"; Flags: deleteafterinstall dontcopy noencryption
  Source: "internal\media\SetupBackground-16-9.bmp"; DestDir: "{tmp}"; DestName: "SetupBackground-16-9.bmp"; Flags: deleteafterinstall dontcopy noencryption
#elif InstallType == "NeoEE"
  Source: "internal\media\SetupBackground-4-3-Neo.bmp"; DestDir: "{tmp}"; DestName: "SetupBackground-4-3.bmp"; Flags: deleteafterinstall dontcopy noencryption
  Source: "internal\media\SetupBackground-16-9-Neo.bmp"; DestDir: "{tmp}"; DestName: "SetupBackground-16-9.bmp"; Flags: deleteafterinstall dontcopy noencryption
#endif

Source: "internal\runtime\directx\dxwebsetup.exe"; DestDir: "{tmp}\directx"; Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs nocompression; Tasks: dxwebsetup

; ----------------

; EE Base
Source: "data\Empire Earth Base\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; AfterInstall: RecordInstalledFile
; EE Movies
Source: "data\Add-on\Movies\EE\*"; DestDir: "{app}\{#EEDir}\Data\Movies"; Flags: ignoreversion recursesubdirs createallsubdirs nocompression; Components: additional\movies and game; AfterInstall: RecordInstalledFile

#if InstallType == "NeoEE"
  Source: "data\NeoEE Base\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE Base\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; AfterInstall: RecordInstalledFile
  Source: "data\Add-on\RMS\Omega\EE\*"; DestDir: "{app}\{#EEDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; AfterInstall: RecordInstalledFile
  Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#EEDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE - Admin\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; Check: IsAdminInstallMode; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE - User\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; Check: not IsAdminInstallMode; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE - CDKeys\authtools.dll"; DestDir: "{tmp}"; DestName: "authtools.dll"; Flags: dontcopy noencryption nocompression; Components: game;
  Source: "data\NeoEE - CDKeys\_wonkver.pub"; DestDir: "{app}\{#EEDir}"; Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs; Components: game
  ; NeoEE - Wine Fix (GDI)
  Source: "data\NeoEE - Wine\NeoEE.cfg"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; Check: IsWine; AfterInstall: RecordInstalledFile
#endif

; EE localized text (Language.dll, lobby files) of the selected game language
#expr LocTextBase = "", LocTextGame = "EE", LocTextDir = EEDir, LocTextComp = "game"
#call LocalizedTextFiles
#if InstallType == "NeoEE"
  ; NeoEE versions, installed over the ones above
  #expr LocTextBase = "Mods\NeoEE\"
  #call LocalizedTextFiles
#endif

; EE Online Lang Any Based Content (only downloads that passed the checks of downloads.iss)
; RecordVerifiedOnlineFiles (installstate.iss) adds the files of the three {tmp}\verified entries to
; the manifest with the same folders and components; change both together (ci/check_contract.py
; compares both sides)
Source: "{tmp}\verified\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs external skipifsourcedoesntexist; Components: game and language\update;

; Add-on files (see GameAddOnFiles)
#expr AddOnDir = EEDir, AddOnComp = "game", AddOnOmega = "EE"
#call GameAddOnFiles

; EEStats
Source: "data\Add-on\DLLs\EEStats\EEStats.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\telemetry and game; MinVersion: {#Win7}; AfterInstall: RecordInstalledFile

; HD
Source: "data\Add-on\HD\terrain\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\terrain and game; AfterInstall: RecordInstalledFile

; Music
Source: "data\Add-on\HD\music\*"; DestDir: "{app}\{#EEDir}\Data\Sounds"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\music and game; AfterInstall: RecordInstalledFile

; Tech
Source: "data\Add-on\HD\tech\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\tech and game; AfterInstall: RecordInstalledFile

; Building
Source: "data\Add-on\HD\buildings\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\buildings and game; AfterInstall: RecordInstalledFile

; Effects
Source: "data\Add-on\HD\effects\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\effects and game; AfterInstall: RecordInstalledFile

; ----------------

; AoC Base
Source: "data\Empire Earth Base\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; AfterInstall: RecordInstalledFile
; AoC Movies
Source: "data\Add-on\Movies\AoC\*"; DestDir: "{app}\{#AoCDir}\Data\Movies"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\movies and gameaoc; AfterInstall: RecordInstalledFile

#if InstallType == "NeoEE"
  Source: "data\NeoEE Base\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE Base\shared\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; AfterInstall: RecordInstalledFile
  Source: "data\Add-on\RMS\Omega\AoC\*"; DestDir: "{app}\{#AoCDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; AfterInstall: RecordInstalledFile
  Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#AoCDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE - Admin\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; Check: IsAdminInstallMode; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE - User\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; Check: not IsAdminInstallMode; AfterInstall: RecordInstalledFile
  Source: "data\NeoEE - CDKeys\_wonkver.pub"; DestDir: "{app}\{#AoCDir}"; \
    Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs; Components: gameaoc
  ; NeoEE - Wine Fix (GDI)
  Source: "data\NeoEE - Wine\NeoEE.cfg"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; Check: IsWine; AfterInstall: RecordInstalledFile
#endif

; AoC localized text (Language.dll, lobby files) of the selected game language
#expr LocTextBase = "", LocTextGame = "AoC", LocTextDir = AoCDir, LocTextComp = "gameaoc"
#call LocalizedTextFiles
#if InstallType == "NeoEE"
  ; NeoEE versions, installed over the ones above
  #expr LocTextBase = "Mods\NeoEE\"
  #call LocalizedTextFiles
#endif

; skipifsourcedoesntexist: {tmp}\verified\AoC is empty when nothing was downloaded for AoC (English,
; download not selected or failed), which Setup would otherwise report as a missing source file
Source: "{tmp}\verified\AoC\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs external skipifsourcedoesntexist; Components: gameaoc and language\update
; AoC uses the learning campaign of EE (see RegisterOnlineFiles)
Source: "{tmp}\verified\EE\Data\Campaigns\EELearningCampaign.ssa"; DestDir: "{app}\{#AoCDir}\Data\Campaigns"; \
  Flags: ignoreversion recursesubdirs createallsubdirs external skipifsourcedoesntexist; Components: gameaoc and language\update

; Add-on files (see GameAddOnFiles)
#expr AddOnDir = AoCDir, AddOnComp = "gameaoc", AddOnOmega = "AoC"
#call GameAddOnFiles

; EEStats.dll is only installed for Empire Earth, it does not support AoC

; HD & Music & Tech & Building: AoC uses the files of Empire Earth

; -------------------
;  Write permissions for the config files: each file is copied onto itself (external) to set them
; -------------------
; The game runs unelevated and writes its configs (and Data, Users, see [Dirs]) inside {app}, so
; all authenticated users get modify rights there. Trade-off: on a shared PC every user can change
; these files for everyone, but only at the privilege level of the game itself (no admin rights).
; With the opt-in task everyoneadminstart the game runs elevated, needs no write permissions and
; must not read files that standard users can change: then nothing is granted. Never grant write
; access to code (exe/dll). Permissions granted by an earlier installation are not revoked.
Source: "{app}\{#EEDir}\*.cfg"; DestDir: "{app}\{#EEDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: game; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Source: "{app}\{#EEDir}\*.config"; DestDir: "{app}\{#EEDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: game; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Source: "{app}\{#EEDir}\*.conf"; DestDir: "{app}\{#EEDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: game; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Source: "{app}\{#EEDir}\*.ini"; DestDir: "{app}\{#EEDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: game; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
; ----------------
Source: "{app}\{#AoCDir}\*.cfg"; DestDir: "{app}\{#AoCDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: gameaoc; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Source: "{app}\{#AoCDir}\*.config"; DestDir: "{app}\{#AoCDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: gameaoc; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Source: "{app}\{#AoCDir}\*.conf"; DestDir: "{app}\{#AoCDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: gameaoc; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Source: "{app}\{#AoCDir}\*.ini"; DestDir: "{app}\{#AoCDir}"; Permissions: authusers-modify; Flags: ignoreversion recursesubdirs createallsubdirs external; Components: gameaoc; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode

; ---------------------
;         Tools
; ---------------------
Source: "data\Add-on\Tools\Diagnostic\*"; DestDir: "{app}\Tools\Diagnostic"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\tools\diagnostic; AfterInstall: RecordInstalledFile

[Dirs]
; ---------------------
;  Allow Data/Civ edit (see the permission notes in [Files])
; ---------------------
Name: "{app}\{#EEDir}\Data"; Permissions: authusers-modify; Components: game; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Name: "{app}\{#EEDir}\Users"; Permissions: authusers-modify; Components: game; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
; ----------------
Name: "{app}\{#AoCDir}\Data"; Permissions: authusers-modify; Components: gameaoc; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode
Name: "{app}\{#AoCDir}\Users"; Permissions: authusers-modify; Components: gameaoc; Tasks: not everyoneadminstart; Check: not IsWine and IsAdminInstallMode

; Additional setup related data
Name: "{app}\{#SetupDataDir}"; Attribs: hidden

[Registry]
; Compatibility
;   WIN7RTM    DWM8And16BitMitigation    for Windows 8+ (MinVersion: Win8)
;   nothing on Windows Vista/7 by default; opt-in RUNASADMIN and opt-in flags without a Windows
;   compatibility mode (task compatibility_legacy, OnlyBelowVersion: Win8)
; (version filters: see the Windows version defines at the top)
; Help
;   HeapClearAllocation: Clear memory on program crash
;   DWM8And16BitMitigation: (From Windows 8, DirectX) Convert 8bits to 16bits
;   HIGHDPIAWARE: [Need investigation] Will try to make the game coherent with the screen DPI
; Maybe for later ?
;   IgnoreAltTab DisableWindowsDefender DisableDWM Disable8And16BitModes Disable8And16BitD3D
;   DISABLETHEMES DISABLEDWM IgnoreFontQuality ForceLoadMirrorDrvMitigation DXGICompat
;   FontMigration: [Need investigation] Replaces a font with a better font, to avoid text truncation.
;   ForceInvalidateOnClose: Force program to close window in some cases
;   DISABLEDXMAXIMIZEDWINDOWEDMODE: (DirectX) Disable fullscreen optimization (maj is important...) (make game crash but sometime work)

; HKCU in administrative install mode is the hive of the account that elevated the setup: usually
; the installing user, but another admin account with over-the-shoulder elevation. So only per-user
; preferences without a machine-wide equivalent go there (GPU preference, game defaults and the
; "Installed From" values the game reads from HKCU); the compatibility flags, including the opt-in
; RUNASADMIN, use HKLM in that mode.

; Windows 10+: run the games on the high-performance graphics card (GpuPreference=2). Windows only
; has this setting per user (HKCU).
Root: "HKCU"; Subkey: "Software\Microsoft\DirectX\UserGpuPreferences"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "GpuPreference=2;"; \
  Flags: uninsdeletevalue; MinVersion: {#Win10}; Tasks: compatibility_windows; Components: game
Root: "HKCU"; Subkey: "Software\Microsoft\DirectX\UserGpuPreferences"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "GpuPreference=2;"; \
  Flags: uninsdeletevalue; MinVersion: {#Win10}; Tasks: compatibility_windows; Components:  gameaoc

; Compatibility values (AppCompatFlags\Layers) of both game programs. GetCompatibilityFlags gives
; "~" plus RUNASADMIN (task everyoneadminstart) and the flags of the task compatibility or of the
; opt-in task compatibility_legacy; the task compatibility_windows adds the Windows compatibility
; mode WIN7RTM. compatibility and compatibility_windows exist on Windows 8 and later only,
; compatibility_legacy on Windows 7 only, so on Windows Vista/7 only the opt-in values can be
; written there; RemoveLegacyVistaCompatValues ([Code]) removes the values earlier setups wrote on
; Vista/7, except the one this run writes with compatibility_legacy (contract 3.7, ADR 0010).
; CompatibilityValues writes the value of EE and of AoC for the current parameters:
;   CompatRoot, CompatCheck  registry root and the Check of the install mode
;   CompatTasks              Tasks condition
;   CompatVersions           version filter parameters, "" or "MinVersion: ...; " or
;                            "OnlyBelowVersion: ...; "
;   CompatLayer              "" or " <Windows compatibility mode>"
; CompatibilityValuesWin8 writes them for Windows 8 and later, with WIN7RTM if CompatWindowsMode
; is 1; CompatibilityValuesWin7 writes them below Windows 8, never with a Windows compatibility mode.
#define public CompatRoot ""
#define public CompatCheck ""
#define public CompatTasks ""
#define public CompatVersions ""
#define public CompatLayer ""
#define public CompatWindowsMode 0
#sub CompatibilityValues
Root: "{#CompatRoot}"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags}{#CompatLayer}"; \
  Flags: uninsdeletevalue; Check: {#CompatCheck}; {#CompatVersions}Tasks: {#CompatTasks}; Components: game
Root: "{#CompatRoot}"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags}{#CompatLayer}"; \
  Flags: uninsdeletevalue; Check: {#CompatCheck}; {#CompatVersions}Tasks: {#CompatTasks}; Components: gameaoc
#endsub
#sub CompatibilityValuesWin8
  #expr CompatVersions = "MinVersion: " + Win8 + "; ", CompatLayer = (CompatWindowsMode ? " WIN7RTM" : "")
  #call CompatibilityValues
#endsub
#sub CompatibilityValuesWin7
  #expr CompatVersions = "OnlyBelowVersion: " + Win8 + "; ", CompatLayer = ""
  #call CompatibilityValues
#endsub

; Administrative install mode: for all users (HKLM)
#expr CompatRoot = "HKLM", CompatCheck = "IsAdminInstallMode"
; Windows compatibility mode (here also without the task compatibility, unlike in HKCU below)
#expr CompatTasks = "compatibility_windows", CompatWindowsMode = 1
#call CompatibilityValuesWin8
; Compatibility flags without Windows compatibility mode
#expr CompatTasks = "not compatibility_windows and compatibility", CompatWindowsMode = 0
#call CompatibilityValuesWin8
; Windows 7, opt-in: the flags (with RUNASADMIN in front if everyoneadminstart is selected too)
#expr CompatTasks = "compatibility_legacy"
#call CompatibilityValuesWin7
; RUNASADMIN only (opt-in task everyoneadminstart without the compatibility tasks), any Windows.
; Setups up to v1.7.2 also set "~ RUNASADMIN" in HKCU for the installing account by default;
; CurStepChanged removes that old value (RemoveLegacyRunAsAdmin).
#expr CompatTasks = "everyoneadminstart and not compatibility_windows and not compatibility and not compatibility_legacy", CompatVersions = "", CompatLayer = ""
#call CompatibilityValues

; Non-administrative install mode: for the current user (HKCU); everyoneadminstart is admin only
#expr CompatRoot = "HKCU", CompatCheck = "not IsAdminInstallMode"
; Windows compatibility mode (needs both tasks here)
#expr CompatTasks = "compatibility_windows and compatibility", CompatWindowsMode = 1
#call CompatibilityValuesWin8
; Compatibility flags without Windows compatibility mode
#expr CompatTasks = "not compatibility_windows and compatibility", CompatWindowsMode = 0
#call CompatibilityValuesWin8
; Windows 7, opt-in: the flags
#expr CompatTasks = "compatibility_legacy"
#call CompatibilityValuesWin7

; Game settings of one game below HKCU\GameRegKey (component GameComp, game folder GameDir below
; {app}). Renderer, VSync, window size, bit depths and "Installed From" are set on every
; installation (deletevalue); the other defaults are only written where the player has no value
; yet (createvalueifdoesntexist). Dword values in hex: AutoSave $124F80 = 1200000 ms = 20 minutes,
; Game Unit Limit $4B0 = 1200, Music/Sound Volume $2C/$3C = 44/60, bit depths $20 = 32;
; GameEndingEpoch is the index of the last epoch of the game.
#define public GameRegKey ""
#define public GameComp ""
#define public GameDir ""
#define public GameEndingEpoch ""
#sub GameSettings
Root: "HKCU"; Subkey: "{#GameRegKey}"; Flags: uninsdeletekey; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D Hardware TnL"; Flags: deletevalue; Components: {#GameComp} and not additional\directx_wrapper; Check: not IsWine
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D"; Flags: deletevalue; Components: {#GameComp} and additional\directx_wrapper; Check: not IsWine
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D"; Flags: deletevalue; Components: {#GameComp}; Check: IsWine
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Wait for VSync"; ValueData: "$0"; Flags: deletevalue; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "AutoSave In Milliseconds"; ValueData: "$124F80"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: String; ValueName: "Map Type"; ValueData: "Continental"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Map Size"; ValueData: "$2"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Starting Resources"; ValueData: "$3"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Starting Epoch"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Ending Epoch"; ValueData: "{#GameEndingEpoch}"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Game Unit Limit"; ValueData: "$4B0"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Wonders For Victory"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Game Variant"; ValueData: "$2"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Difficulty Level"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Game Speed"; ValueData: "$3"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Reveal Map"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Allow Custom Civs"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Lock Teams"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Lock Speed"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}\Game Options"; ValueType: Dword; ValueName: "Cheat Codes"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Music Volume"; ValueData: "$2C"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Sound Volume"; ValueData: "$3C"; Flags: createvalueifdoesntexist; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Take JPG Screenshots"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: {#GameComp}
; Window size: the screen size, at least 1024x768 and at most 1920x1080; 32 bits. If Texture
; Bit Depth differs from Game Bit Depth, the main menu is just white and unreadable.
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Game Window Height"; ValueData: "{code:GetScreenResolutionHeight}"; Flags: deletevalue; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Game Window Width"; ValueData: "{code:GetScreenResolutionWidth}"; Flags: deletevalue; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Game Bit Depth"; ValueData: "$20"; Flags: deletevalue; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: Dword; ValueName: "Texture Bit Depth"; ValueData: "$20"; Flags: deletevalue; Components: {#GameComp}
; "Installed From" lets AoC start without starting EE first
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: string; ValueName: "Installed From Volume"; ValueData: "{code:GetInstallDriveLetter}"; Flags: deletevalue; Components: {#GameComp}
Root: "HKCU"; Subkey: "{#GameRegKey}"; ValueType: string; ValueName: "Installed From Directory"; ValueData: "{code:GetInstallWithoutDriveLetterBase}\{#GameDir}\"; Flags: deletevalue; Components: {#GameComp}
#endsub
; Empire Earth: Ending Epoch $D = 13, its last epoch (the first one, Starting Epoch, is 0)
#expr GameRegKey = BaseRegEE, GameComp = "game", GameDir = EEDir, GameEndingEpoch = "$D"
#call GameSettings
; The Art of Conquest: Ending Epoch $E = 14, its last epoch (AoC adds the Space Age)
#expr GameRegKey = BaseRegAoC, GameComp = "gameaoc", GameDir = AoCDir, GameEndingEpoch = "$E"
#call GameSettings

#if InstallMode == "Regular"
; Install record (contract 1.1, docs/adr/0004-install-record-and-integrity-manifest.md point 2):
; which product is installed where, in which install mode, by which setup; the launcher reads it.
; HKA is HKLM in administrative install mode (the 64-bit view on 64-bit Windows, see
; ArchitecturesInstallIn64BitMode) and HKCU in non-administrative install mode. deletekey: every run
; writes the record anew, so no value of an earlier run stays (e.g. SetupBuild of a test build). The
; uninstaller removes the record, and the parent keys if they are empty. Portable setups write none:
; they have no uninstaller that would remove it (contract 1.1).
Root: HKA; Subkey: "{#BaseRegCommunity}"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; Flags: deletekey uninsdeletekey
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; ValueType: dword; ValueName: "ContractVersion"; ValueData: "{#ContractVersion}"
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; ValueType: string; ValueName: "InstallMode"; ValueData: "{code:GetContractInstallMode}"
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; ValueType: string; ValueName: "AppId"; ValueData: "{#AppID}"
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; ValueType: string; ValueName: "GameVersion"; ValueData: "{#MyAppVersion}"
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; ValueType: string; ValueName: "SetupVersion"; ValueData: "{#MySetupVersion}"
  #if SetupBuild != ""
Root: HKA; Subkey: "{#BaseRegCommunity}\Installations\{#InstallType}"; ValueType: string; ValueName: "SetupBuild"; ValueData: "{#SetupBuild}"
  #endif
; Defaults marker (contract 3.5, ADR 0004 point 2): per game, the contract version whose default game
; settings (the GameSettings values above) were applied for this account. Like the game settings it
; goes to the account that runs the setup (with over-the-shoulder elevation: the administrator
; account that elevated it); the launcher applies the defaults for every other account and writes
; their marker. The uninstaller removes it for the account that uninstalls. Portable setups write
; none (no uninstaller; the launcher finds the values they wrote and does not ask, contract 3.5).
Root: HKCU; Subkey: "{#BaseRegCommunity}"; Flags: uninsdeletekeyifempty
Root: HKCU; Subkey: "{#BaseRegCommunity}\GameDefaults"; Flags: uninsdeletekeyifempty
Root: HKCU; Subkey: "{#BaseRegCommunity}\GameDefaults\{#InstallType}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "{#BaseRegCommunity}\GameDefaults\{#InstallType}"; ValueType: dword; ValueName: "EE"; ValueData: "{#ContractVersion}"; Components: game
Root: HKCU; Subkey: "{#BaseRegCommunity}\GameDefaults\{#InstallType}"; ValueType: dword; ValueName: "AoC"; ValueData: "{#ContractVersion}"; Components: gameaoc
#endif

[Icons]
#if InstallMode != "Portable"
  Name: "{group}\{#MyAppName}"; Filename: "{app}\{#EEExe}"; Components: game;
  Name: "{group}\{#MyAppName} - AoC"; Filename: "{app}\{#AoCExe}"; Components: gameaoc;
  Name: "{group}\{#MyAppName} Diagnostic"; Filename: "{app}\Tools\Diagnostic\EE-Diagnostic.exe"; Parameters: "{#SetupSetting("AppId")}_is1"; Components: additional\tools\diagnostic;
  ; Uncomment to add the Uninstall shortcut in the Start Menu
  ; Name: "{group}\{cm:UninstallProgram,Empire Earth}"; Filename: "{uninstallexe}";
  Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#EEExe}"; Components: game; Tasks: desktopicon;
  Name: "{autodesktop}\{#MyAppName} - AoC"; Filename: "{app}\{#AoCExe}"; Components: gameaoc; Tasks: desktopicon;
#endif

[InstallDelete]
; Supported Component modification : old GOG or Retail | dgVoodoo | dreXmod | Discord | Movies | Reborn | EEStats
; Other component are too hard to delete without maybe deleting user files (modding)
; Random Map Scripts: only the files installed by the previous setup are removed, see randommaps.iss
; dreXmod data (Data\dxm): only the folders this setup installs or dreXmod creates itself (the web pages and
; images of the lobby, the four mod presets dxm, energycube, template and yukon, the cache dbcache). Folders
; players make below Data\dxm\mods (the comment of dreXmod.config invites them to) are never deleted, not on
; an update, a repair or a change of the dreXmod version, nor on uninstallation. A list entry that dreXmod
; renames in a later version has to be added here with the data (README, "Notes for Modders").
Type: files; Name: "{app}\{#EEExe}"
Type: files; Name: "{app}\{#EEDir}\D3D8.dll"
Type: files; Name: "{app}\{#EEDir}\D3D9.dll"
Type: files; Name: "{app}\{#EEDir}\D3DImm.dll"
Type: files; Name: "{app}\{#EEDir}\DDraw.dll"
Type: files; Name: "{app}\{#EEDir}\DDrawCompat*.log"
Type: files; Name: "{app}\{#EEDir}\dgVoodooCpl.exe"
Type: files; Name: "{app}\{#EEDir}\dgVoodoo.conf"
Type: files; Name: "{app}\{#EEDir}\dreXmod.config"
Type: files; Name: "{app}\{#EEDir}\dreXmod.dll"
Type: files; Name: "{app}\{#EEDir}\Reborn.ini"
Type: files; Name: "{app}\{#EEDir}\Reborn.dll"
Type: files; Name: "{app}\{#EEDir}\EEStats.dll"
Type: files; Name: "{app}\{#EEDir}\EEStats.log"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\drexmod.com"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\images"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\dxm"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\energycube"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\template"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\yukon"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\dbcache"
Type: files; Name: "{app}\{#EEDir}\dxmdata"
Type: files; Name: "{app}\{#EEDir}\discord_game_sdk.dll"
Type: files; Name: "{app}\{#EEDir}\EEDiscordRichPresence.dll"
Type: files; Name: "{app}\{#EEDir}\EEDiscord.dll"
Type: files; Name: "{app}\{#EEDir}\Data\Scenarios\ScenDefault.scn"

Type: files; Name: "{app}\{#EEDir}\OOS *.log"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\Movies\";
; ----------------
Type: files; Name: "{app}\{#AoCExe}"
Type: files; Name: "{app}\{#AoCDir}\D3D8.dll"
Type: files; Name: "{app}\{#AoCDir}\D3D9.dll"
Type: files; Name: "{app}\{#AoCDir}\D3DImm.dll"
Type: files; Name: "{app}\{#AoCDir}\DDraw.dll"
Type: files; Name: "{app}\{#AoCDir}\dgVoodooCpl.exe"
Type: files; Name: "{app}\{#AoCDir}\dgVoodoo.conf"
Type: files; Name: "{app}\{#AoCDir}\dreXmod.config"
Type: files; Name: "{app}\{#AoCDir}\dreXmod.dll"
Type: files; Name: "{app}\{#AoCDir}\Reborn.ini"
Type: files; Name: "{app}\{#AoCDir}\Reborn.dll"
Type: files; Name: "{app}\{#AoCDir}\EEStats.dll"
Type: files; Name: "{app}\{#AoCDir}\EEStats.log"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\drexmod.com"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\images"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\dxm"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\energycube"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\template"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\yukon"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\dbcache"
Type: files; Name: "{app}\{#AoCDir}\dxmdata"
Type: files; Name: "{app}\{#AoCDir}\discord_game_sdk.dll"
Type: files; Name: "{app}\{#AoCDir}\EEDiscordRichPresence.dll"
Type: files; Name: "{app}\{#AoCDir}\EEDiscord.dll"
Type: files; Name: "{app}\{#AoCDir}\Data\Scenarios\ScenDefault.scn"

Type: files; Name: "{app}\{#AoCDir}\OOS *.log"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\Movies\"
; ----------------
; Setup data folder of setups up to v1.7.2 (now {#SetupDataDir}). Safe: AppID is checked to be a
; plain GUID (IsPlainGuid: hex digits and dashes only)
Type: filesandordirs; Name: "{app}\{#AppID}"

[UninstallDelete]
; A little extra cleaning of the installed files
; Convention : Never delete the entire program folder !
Type: files; Name: "{app}\{#EEDir}\0_Error.log"
Type: files; Name: "{app}\{#EEDir}\neoee.log"
Type: files; Name: "{app}\{#EEDir}\upnp_info.txt"
Type: files; Name: "{app}\{#EEDir}\Reborn.ini"
Type: files; Name: "{app}\{#EEDir}\EEStats.log"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\drexmod.com"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\images"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\dxm"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\energycube"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\template"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\mods\yukon"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm\dbcache"
Type: files; Name: "{app}\{#EEDir}\_won*"
Type: filesandordirs; Name: "{app}\{#EEDir}\_wonHTTPCache"
Type: files; Name: "{app}\{#EEDir}\Data\Scenarios\ScenDefault.scn"
Type: files; Name: "{app}\{#EEDir}\OOS *.log"
; pt_BR create that dir for some reasons (not used)
Type: filesandordirs; Name: "{app}\{#EEDir}\Users\default\Civilizações"
; ----------------
Type: files; Name: "{app}\{#AoCDir}\0_Error.log"
Type: files; Name: "{app}\{#AoCDir}\neoee.log"
Type: files; Name: "{app}\{#AoCDir}\upnp_info.txt"
Type: files; Name: "{app}\{#AoCDir}\Reborn.ini"
Type: files; Name: "{app}\{#AoCDir}\EEStats.log"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\drexmod.com"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\images"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\dxm"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\energycube"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\template"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\mods\yukon"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm\dbcache"
Type: files; Name: "{app}\{#AoCDir}\_won*"
Type: filesandordirs; Name: "{app}\{#AoCDir}\_wonHTTPCache"
Type: files; Name: "{app}\{#AoCDir}\Data\Scenarios\ScenDefault.scn"
Type: files; Name: "{app}\{#AoCDir}\OOS *.log"
; pt_BR create that dir for some reasons (not used)
Type: filesandordirs; Name: "{app}\{#AoCDir}\Users\default\Civilizações"
; ----------------
Type: filesandordirs; Name: "{app}\Tools\Diagnostic\log.txt"

Type: filesandordirs; Name: "{app}\{#SetupDataDir}"

[Run]
; Add Cert in Windows Trusted Publishers Store (only if the extracted file has the expected
; thumbprint). Setups up to v1.7.2 used the Trusted Root CA store, see RemoveLegacyRootCertificate.
#if CertInclude
  Filename: "{sys}\certutil.exe"; Parameters: "-addstore trustedpublisher ""{tmp}\{#CertFileName}"""; Flags: runhidden; Tasks: certinclude; \
    StatusMsg: "{cm:StatusCertificate}"; MinVersion: {#WinVista}; Components: game; Check: IsAdminInstallMode and IsCertificateFileGenuine
  Filename: "{sys}\certutil.exe"; Parameters: "-user -addstore trustedpublisher ""{tmp}\{#CertFileName}"""; Flags: runhidden; Tasks: certinclude; \
    StatusMsg: "{cm:StatusCertificate}"; MinVersion: {#WinVista}; Components: game; Check: not IsAdminInstallMode and IsCertificateFileGenuine
#endif

; Enable DirectPlay (task directplay, administrators, Windows 8 and later) with DISM. Not tested on
; 32-bit Windows. One entry: there used to be two with the same command that differed only in
; Check: Is64BitInstallMode / not Is64BitInstallMode, so exactly one of them always ran.
Filename: "{sys}\dism.exe"; Parameters: "/Online /Enable-Feature /FeatureName:""DirectPlay"" /all /NoRestart"; Flags: runhidden; StatusMsg: "{cm:StatusDirectPlay}"; \
  MinVersion: {#Win8}; Tasks: directplay; Check: IsAdminInstallMode

; Firewall (task firewallexception): the rules of an earlier installation are removed first, in case
; they were misconfigured (the same entries as in [UninstallRun]), then the rules are added.
; Allow rules scoped to the game programs (Empire Earth.exe, EE-AOC.exe): TCP and UDP, in and out,
; all local ports, all network profiles. profile=any is the netsh default and written out on
; purpose: hosting LAN and online games needs incoming connections on networks Windows classifies
; as "Public" too, so the rules are deliberately not limited to private networks. The rules only
; apply while the game runs, like the ones the Windows Firewall prompt offers; the task
; firewallexception can be unchecked.
#sub FirewallDeleteRules
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule program=""{app}\{#EEExe}"" name=all"; Flags: runhidden; \
  StatusMsg: "{cm:StatusFirewallRemove,{#MyAppName}}"; Tasks: firewallexception; MinVersion: {#WinVista}; Components: game; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule program=""{app}\{#AoCExe}"" name=all"; Flags: runhidden; \
  StatusMsg: "{cm:StatusFirewallRemove,{#MyAppName} : AoC}"; Tasks: firewallexception; MinVersion: {#WinVista}; Components: gameaoc; Check: IsAdminInstallMode
#endsub
; The four allow rules (TCP/UDP, out/in) of the program FwExe (below {app}, component FwComp),
; named "<FwRuleName> - <protocol> - <direction>", with the status text FwStatus
#define public FwExe ""
#define public FwComp ""
#define public FwRuleName ""
#define public FwStatus ""
#sub FirewallAllowRules
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#FwRuleName} - TCP - Out"" program=""{app}\{#FwExe}"" protocol=TCP dir=out action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "{#FwStatus}"; MinVersion: {#WinVista}; Components: {#FwComp}; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#FwRuleName} - TCP - In"" program=""{app}\{#FwExe}"" protocol=TCP dir=in action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "{#FwStatus}"; MinVersion: {#WinVista}; Components: {#FwComp}; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#FwRuleName} - UDP - Out"" program=""{app}\{#FwExe}"" protocol=UDP dir=out action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "{#FwStatus}"; MinVersion: {#WinVista}; Components: {#FwComp}; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#FwRuleName} - UDP - In"" program=""{app}\{#FwExe}"" protocol=UDP dir=in action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "{#FwStatus}"; MinVersion: {#WinVista}; Components: {#FwComp}; Check: IsAdminInstallMode
#endsub
#call FirewallDeleteRules
#expr FwExe = EEExe, FwComp = "game", FwRuleName = MyAppName, FwStatus = "{cm:StatusFirewallOpen,Empire Earth}"
#call FirewallAllowRules
#expr FwExe = AoCExe, FwComp = "gameaoc", FwRuleName = MyAppName + " - AoC", FwStatus = "{cm:StatusFirewallOpen,Empire Earth : AoC}"
#call FirewallAllowRules

; DX9/10/11 End-User Runtime Setup
Filename: "{tmp}\directx\dxwebsetup.exe"; Parameters: "/Q"; Flags: runhidden; Tasks: dxwebsetup; \
    StatusMsg: "{cm:StatusDxWebSetup}"; MinVersion: {#Win2000}; Check: IsAdminInstallMode and not IsWine

; NeoEE CD keys (task neoee_cdkeys) are registered by CurStepChanged(ssPostInstall), which runs after
; all [Run] entries

[UninstallRun]
; DirectPlay is not disabled on uninstall: other games may still use it.

; Firewall: the delete rules of [Run]
#call FirewallDeleteRules

[Code]
// The URL constants of the web endpoints and the URL checks are in utils.iss.

// Own [Code] files, in this order (each header lists what it requires):
//   eestats.iss     EEStatsSetup.dll: IsWine, GetWineVersion, GetGpuVendorId, statistics values
//   extension.iss   command line switches, previous installation, Windows version (needs utils.iss)
//   pages.iss       the custom wizard pages (needs Langs below, extension.iss, eestats.iss)
//   downloads.iss   online localized files: policy, download page, downloads, verification
//                   (needs utils.iss, extension.iss)
//   randommaps.iss  random map scripts of the previous setup (needs utils.iss, extension.iss)
//   environment.iss read-only checks before the installation: screen size, DPI and the notice for
//                   a low screen; foreign or old installations, their folders and the folder of the
//                   other product, when the folder page is left; links in Data and Users before an
//                   elevated installation (needs utils.iss, extension.iss)
//   installstate.iss  install.ini, the integrity manifest files.sha256 and the contract version in
//                   the uninstall key for the launcher; RecordInstalledFile, the AfterInstall of
//                   [Files] (needs utils.iss, extension.iss)
//   telemetry.iss   setup statistics, included further down after the language functions it uses
#include "eestats.iss"

#if InstallType == "NeoEE"
  // Closed-source NeoEE tool, see RegisterCDKeys. delayload: the DLL is only loaded when the keys
  // are registered, so a DLL removed by an anti-virus no longer stops the setup from starting.
  function generate_cdkeys(args: PAnsiChar; admin: BOOL): DWORD;
    external 'generate_cdkeys@files:authtools.dll cdecl setuponly delayload';
#endif

var
  // The game languages (GameLangs), filled by RegisterLangs; used by pages.iss
  Langs: TStringList;
  // Lobby folder of each of them (GameLangLobbyDirs), same order
  LobbyDirs: TStringList;

#include "extension.iss"
#include "pages.iss"
#include "downloads.iss"
#include "randommaps.iss"
#include "environment.iss"
#include "installstate.iss"

// [Registry] value of the compatibility entries, from the selected tasks (BuildCompatibilityFlags,
// utils.iss). The flags come from the task compatibility (Windows 8 and later) or from the opt-in
// task compatibility_legacy (Windows 7 only, ADR 0010); no Windows has both tasks.
function GetCompatibilityFlags(Param: String): String;
begin
  Result := BuildCompatibilityFlags(WizardIsTaskSelected('everyoneadminstart'),
    WizardIsTaskSelected('compatibility') or WizardIsTaskSelected('compatibility_legacy'));
end;

function GetInstallDriveLetter(Param: String): String;
begin
  Result := copy(ExpandConstant('{app}'), 1, 2);
end;

function GetInstallWithoutDriveLetter(Param: String): String;
var
  S : String;
begin
  S := ExpandConstant('{app}');
  delete(S, 1, 2);
  Result := S;
end;

function GetInstallWithoutDriveLetterBase(Param: String): String;
begin
  Result := UpperCase(GetInstallWithoutDriveLetter(Param));
end;

// [Registry] Game Window Height and Game Window Width: the size of the primary screen
// (GetSystemMetrics, environment.iss) within the limits of contract 3.3 (ClampGameWindowHeight/Width
// and MinGameWindowWidth ... MaxGameWindowHeight in utils.iss)
function GetScreenResolutionHeight(Param: String): String;
begin
  Result := IntToStr(ClampGameWindowHeight(GetSystemMetrics(SM_CYSCREEN)));
end;

function GetScreenResolutionWidth(Param: String): String;
begin
  Result := IntToStr(ClampGameWindowWidth(GetSystemMetrics(SM_CXSCREEN)));
end;

// Update API of the community website, answers with HTTP 200 and
//   &type=<game|setup>&version=<v>  'false' if <v> is outdated
//   &type=<game|setup>               the latest version
//   (no parameter)                   the download URL of the latest setup
// True only for HTTP 200; Response is the trimmed answer ('' otherwise)
function QueryUpdateApi(const Params: String; var Response: String): Boolean;
begin
  Result := DownloadString(UpdateApiURL + Params, Response) = 200;
  if Result then
    Response := Trim(Response)
  else
    Response := '';
end;

const
  // Longest answer of the update API that is shown as the latest version
  MaxVersionTextLength = 32;

// Latest version for the update question, '?' if the answer does not look like a version
function GetLatestVersionText(const Params: String): String;
var
  I: Integer;
begin
  if not QueryUpdateApi(Params, Result) or (Result = '') or (Length(Result) > MaxVersionTextLength) then
  begin
    Result := '?';
    Exit;
  end;
  for I := 1 to Length(Result) do
    if Pos(Result[I], '0123456789.-_ abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ') = 0 then
    begin
      Result := '?';
      Exit;
    end;
end;

// Opens the download of the latest setup, or the fixed download page if the API gives no
// acceptable URL. The browser runs as the original user, not with the setup's admin rights.
procedure OpenUpdateDownloadPage;
var
  Url: String;
  ErrorCode: Integer;
begin
  if not QueryUpdateApi('', Url) then
    Url := SetupURL
  else if not IsAllowedUpdateUrl(Url) then
  begin
    Log('Update URL rejected (not an https URL of the project): ' + Url);
    Url := SetupURL;
  end;
  Log('Opening ' + Url);
  if not ShellExecAsOriginalUser('open', Url, '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode) then
    Log('Unable to open ' + Url + ': ' + SysErrorMessage(ErrorCode));
end;

// True if the update API reports Version of TypeName (game or setup) as outdated
function IsUpdateAvailable(const TypeName, Version: String): Boolean;
var
  Answer: String;
begin
  Result := QueryUpdateApi('&type=' + TypeName + '&version=' + Version, Answer) and (Answer = 'false');
end;

// Asks whether to download the update of TypeName (game or setup), UpdateMessage with [LAST]
// replaced by the latest version; True (= exit setup) if the user wants it
function AskForUpdate(const UpdateMessage, TypeName: String): Boolean;
var
  Msg: String;
begin
  Msg := UpdateMessage;
  StringChangeEx(Msg, '[LAST]', GetLatestVersionText('&type=' + TypeName), True);
  Result := MsgBox(Msg, mbConfirmation, MB_YESNO) = IDYES;
  if Result then
    OpenUpdateDownloadPage();
end;

// Return True when update dialog return yes (= exit setup & open web page). The game is checked
// first; the setup only if the game is up to date.
function CheckUpdate: Boolean;
begin
  Result := False;
  if IsUpdateAvailable('game', '{#MyAppVersion}') then
    Result := AskForUpdate(ExpandConstant('{cm:GameUpdate}'), 'game')
  else if IsUpdateAvailable('setup', '{#MySetupVersion}') then
    Result := AskForUpdate(ExpandConstant('{cm:SetupUpdate}'), 'setup');
end;

// Game language of the selected components ('en' if none), '' in the uninstaller
function GetSelectedLanguageFromComponents(): String;
var
  i: Integer;
begin
  if (IsUninstaller) then
  begin
    Result := '';
    Exit;
  end;
  Result := 'en';
  for i := 0 to Langs.Count - 1 do
  begin
    if (WizardIsComponentSelected('language\' + Langs[i])) then
    begin
      Result := Langs[i];
      Break;
    end;
  end;
end;

procedure RegisterLangs();
begin
  Langs := TStringList.Create;
  LobbyDirs := TStringList.Create;
  // The game languages of [Components] (GameLangs) and their lobby folders, in the same order
#sub AddGameLang
  Langs.Add('{#GameLangs[LangIndex]}');
  LobbyDirs.Add('{#GameLangLobbyDirs[LangIndex]}');
#endsub
#for {LangIndex = 0; LangIndex < GameLangCount; LangIndex++} AddGameLang
  Log('Registered languages: ' + Langs.CommaText);
end;

// Lobby folder of the game language Lang (GameLangLobbyDirs: zh for zh_CN and zh_TW), Lang itself
// as language tag if it is not a game language
function GetLobbyDir(const Lang: String): String;
var
  I: Integer;
begin
  I := Langs.IndexOf(Lang);
  if I >= 0 then
    Result := LobbyDirs[I]
  else
    Result := GetLanguageTag(Lang);
end;

// Update check (not in silent mode): True if the user wants to download the update, the setup
// exits then
function UpdateRequested: Boolean;
begin
  Result := False;
  if (SuppressMsgBoxes or SilentInstall) then
  begin
    Log('Update check skipped because using silent mode');
    Exit;
  end;
  Result := CheckUpdate();
  if (Result) then
    Log('Update found and user want to download it! Exiting setup...');
end;

// Legal question on a first installation (not in silent mode): without the original game or a
// digital purchase the GOG store page opens and the setup exits (False)
function ConfirmLegalCopy: Boolean;
var
  ErrorCode: Integer;
begin
  Result := True;
  if (IsGameInstalled or SilentInstall or SuppressMsgBoxes) then
    Exit;
  if MsgBox(ExpandConstant('{cm:LegalQuestion}'), mbConfirmation, MB_YESNO) = IDNO then
  begin
    ShellExecAsOriginalUser('open', GogStoreURL, '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
    Result := False;
  end;
end;

#if TestID != 0
// Test builds only, shown even in silent mode; /SUPPRESSMSGBOXES suppresses it (the log still
// names it), so that silent test runs need no click (docs/TEST-PLAN.de.md, 6.4). MsgBox would
// ignore /SUPPRESSMSGBOXES.
procedure ShowTestSetupWarning;
begin
  SuppressibleMsgBox(FmtMessage(CustomMessage('TestSetupWarning'), ['{#TestID}', '{#MySetupVersion}', '{#MyAppVersion}']), mbInformation, MB_OK, IDOK);
end;
#endif

// Explains the install mode (not in silent mode): the portable setup asks whether to continue
// (False = exit), a non-administrative installation explains its limits
function ConfirmInstallMode: Boolean;
begin
  Result := True;
  if (SilentInstall or SuppressMsgBoxes) then
    Exit;
#if InstallMode == "Portable"
  if MsgBox(ExpandConstant('{cm:PortableQuestion}'), mbConfirmation, MB_YESNO) = IDNO then
    Result := False;
#else
  if (not IsAdminInstallMode) then
    MsgBox(ExpandConstant('{cm:UserInstallMode}'), mbInformation, MB_OK);
#endif
end;

#if InstallType == "NeoEE"
// Under Wine the NeoEE connection GUI crashes the game (it uses GDI/GDI+): the NeoEE.cfg of
// "NeoEE - Wine" ([Files]) disables it, this tells the user
procedure ShowWineNeoEEGuiNotice;
begin
  if (IsWine() and not SilentInstall and not SuppressMsgBoxes) then
    MsgBox(CustomMessage('WineNeoEEGuiDisabled'), mbInformation, MB_OK);
end;
#endif

// Before the wizard: setup music, update check and the questions that can end the setup, the screen
// in the log and the notice for a low screen
function InitializeSetup: Boolean;
begin
  Result := False;
  Log('{#MyAppName} {#MyAppVersion}, setup {#MySetupVersion} ({#InstallType}, {#InstallMode}), SetupBuild "{#SetupBuild}", ' +
    'TestID {#TestID}, contract version {#ContractVersion}');

  if (not SilentInstall and not IsWine) then
    bassInit();
  if (IsWine()) then
    Log('Wine detected v' + GetWineVersion());
  // Always, also if the setup ends below (contract O4, ADR 0007 point 1)
  LogScreenMetrics();

  if (UpdateRequested()) then
    Exit;
  if (not ConfirmLegalCopy()) then
    Exit;
#if TestID != 0
  ShowTestSetupWarning();
#endif
  if (not ConfirmInstallMode()) then
    Exit;
  ShowLowScreenResolutionNotice();
#if InstallType == "NeoEE"
  ShowWineNeoEEGuiNotice();
#endif

  Result := True;
end;

// Setup statistics (SendSetupTelemetry, RecordInstallStateForTelemetry). Needs the language
// functions above.
#include "telemetry.iss"

#if CertInclude
var
  // Read in InitializeUninstall: the uninstall key is already gone at usPostUninstall
  CertAddedBySetup: Boolean;
  // Read at ssInstall, before the installation rewrites the uninstall key
  CertAddedByPreviousSetup: Boolean;

// [Run] Check: the extracted certificate still has the thumbprint checked at compile time, which
// is also the one RemoveCertificate removes
function IsCertificateFileGenuine: Boolean;
begin
  try
    Result := LowerCase(GetSHA1OfFile(ExpandConstant('{tmp}\{#CertFileName}'))) = '{#CertThumbprint}';
  except
    Result := False;
  end;
  if not Result then
    Log('Certificate file does not have the thumbprint {#CertThumbprint}, not added');
end;

// Exact (not substring) search in the "Inno Setup: Selected Tasks" list of an uninstall key
function UninstallKeyHasTask(const UninstallKey, Task: String): Boolean;
begin
  Result := UninstallKeyListContains(UninstallKey, 'Inno Setup: Selected Tasks', Task);
end;

// Removes the certificate from the certificate store Store (trustedpublisher or root) of the
// machine or the current user, like [Run] added it
procedure RemoveCertificate(const Store: String);
var
  Params: String;
  ResultCode: Integer;
begin
  Params := '-delstore ' + Store + ' ' + AddQuotes('{#CertThumbprint}');
  if not IsAdminInstallMode then
    Params := '-user ' + Params;
  Log('Removing certificate from store: certutil ' + Params);
  if not Exec(ExpandConstant('{sys}\certutil.exe'), Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Log('Unable to run certutil: ' + SysErrorMessage(ResultCode))
  else if ResultCode <> 0 then
    Log('certutil failed with exit code ' + IntToStr(ResultCode));
end;

// Is the certificate still used by the other product (EE <-> NeoEE)? Same install mode (HKA), so
// same certificate store
function IsCertificateUsedByOtherProduct: Boolean;
begin
  Result := UninstallKeyHasTask(GetOtherProductUninstallRegPath(), 'certinclude');
  if Result then
    Log('Certificate still used by the other setup, not removed');
end;

// ssInstall: did the installation this one replaces add the certificate?
procedure RecordPreviousCertificate;
begin
  CertAddedByPreviousSetup := UninstallKeyHasTask(GetUninstallRegPath(), 'certinclude');
end;

// ssPostInstall: setups up to v1.7.2 added the certificate to the trusted root certification
// authorities. This setup only uses the trusted publishers (task certinclude), so the root entry
// of the previous installation is removed, unless the other product still uses the certificate.
procedure RemoveLegacyRootCertificate;
begin
  if CertAddedByPreviousSetup and not IsCertificateUsedByOtherProduct() then
    RemoveCertificate('root');
end;
#endif

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usUninstall) then begin
    UnloadDLL(ExpandConstant('{app}\{#SetupDataDir}\EEStatsSetup.dll'));
  end else if (CurUninstallStep = usPostUninstall) then
  begin
#if CertInclude
    // Only remove the certificate if this product added it, and keep it while the other product
    // (EE <-> NeoEE) still uses it. Also from the root store, where setups up to v1.7.2 added it.
    if not CertAddedBySetup then
      Log('Certificate not added by this setup, not removed')
    else if not IsCertificateUsedByOtherProduct() then
    begin
      RemoveCertificate('trustedpublisher');
      RemoveCertificate('root');
    end;
#endif
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  // Components and tasks pages only with custom settings, the GPU page only with the
  // recommended settings (and not under Wine)
  if ((PageID = wpSelectComponents) or (PageID = wpSelectTasks)) and not ManualInstallQuestionPage.Values[MiqpCustom] then
    Result := True
  else if (PageID = GPUInstallQuestionPage.ID) and (not ManualInstallQuestionPage.Values[MiqpRecommended] or IsWine()) then
    Result := True;
end;

#if InstallType == "NeoEE"
const
  CDKeysAuthServer = 'neoee.net';
  CDKeysAuthPort = '10003';
  // Results of generate_cdkeys (see RegisterCDKeys for the messages)
  CDKeysResultOK = 0;
  CDKeysResultVM = 1;
  CDKeysResultGeneral = 2;
  CDKeysResultNetwork = 3;
  CDKeysResultRegistry = 4;
  CDKeysResultSyntax = 5;
  CDKeysResultProtection = 6;

// Arguments of generate_cdkeys, exactly in the format authtools.dll has always received:
// '-eec=<EE folder>[, -aoc=<AoC folder>], -authserv=neoee.net, -port=10003'
function GetCDKeysArgs(const EEDir, AoCDir: String): String;
begin
  Result := '-eec=' + EEDir;
  if (AoCDir <> '') then
    Result := Result + ', -aoc=' + AoCDir;
  Result := Result + ', -authserv=' + CDKeysAuthServer + ', -port=' + CDKeysAuthPort;
end;

// authtools.dll is closed source and takes the folders in one comma separated ANSI string
// (PAnsiChar). Its parser is unknown, so quoting cannot be added without changing what it
// receives; folders it would get wrong are refused instead: a comma would split the argument,
// and characters outside the ANSI code page would be replaced by '?'.
function IsCDKeysPathSupported(const Dir: String): Boolean;
begin
  Result := (Pos(',', Dir) = 0) and (String(AnsiString(Dir)) = Dir);
end;

procedure ShowCDKeysError(const Msg: String);
begin
  Log('CD Keys: ' + Msg);
  if (not SilentInstall and not SuppressMsgBoxes) then
    MsgBox(Msg, mbError, MB_OK);
end;

// Registers the NeoEE CD keys with the NeoEE auth server (generate_cdkeys of authtools.dll):
// HKLM in administrative install mode, HKCU otherwise
// authtools.dll writes the keys below Sierra\CDKeys; in HKLM that is one of
//   HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Sierra\CDKeys
//   HKEY_LOCAL_MACHINE\Software\Sierra\CDKeys
procedure RegisterCDKeys();
var
  AuthExitCode: Integer;
  EEDir, AoCDir: String;
begin
  if (IsWine()) then
  begin
    ShowCDKeysError(CustomMessage('CDKeysWine'));
    Exit;
  end;

  if (not WizardIsComponentSelected('game')) then
    Exit;
  EEDir := ExpandConstant('{app}\{#EEDir}');
  AoCDir := '';
  if (WizardIsComponentSelected('gameaoc')) then
    AoCDir := ExpandConstant('{app}\{#AoCDir}');

  if (not IsCDKeysPathSupported(EEDir) or not IsCDKeysPathSupported(AoCDir)) then
  begin
    ShowCDKeysError(FmtMessage(CustomMessage('CDKeysPathUnsupported'), [ExpandConstant('{app}')]));
    Exit;
  end;

  if (AoCDir = '') then
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('Register NeoEE CD Keys for EE')
  else
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('Register NeoEE CD Keys for EE and AoC');

  try
    AuthExitCode := generate_cdkeys(GetCDKeysArgs(EEDir, AoCDir), IsAdminInstallMode);
  except
    // authtools.dll is loaded here (delayload): missing or blocked, e.g. by an anti-virus
    Log('Unable to call authtools.dll: ' + GetExceptionMessage);
    ShowCDKeysError(CustomMessage('CDKeysToolMissing'));
    Exit;
  end;

  // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
  Log('CD Keys generation result: ' + IntToStr(AuthExitCode));
  case AuthExitCode of
    CDKeysResultOK: Log('CD Keys registered');
    CDKeysResultVM: ShowCDKeysError(CustomMessage('CDKeysErrorVM'));
    CDKeysResultGeneral: ShowCDKeysError(CustomMessage('CDKeysErrorGeneral'));
    CDKeysResultNetwork: ShowCDKeysError(CustomMessage('CDKeysErrorNetwork'));
    CDKeysResultRegistry: ShowCDKeysError(CustomMessage('CDKeysErrorRegistry'));
    CDKeysResultSyntax: ShowCDKeysError(CustomMessage('CDKeysErrorSyntax'));
    CDKeysResultProtection: ShowCDKeysError(CustomMessage('CDKeysErrorProtection'));
  else
    ShowCDKeysError(FmtMessage(CustomMessage('CDKeysErrorUnknown'), [IntToStr(AuthExitCode)]));
  end;
end;
#endif

procedure SelectLanguageFromIndex(LangIndex: Integer);
var
  Lang: String;
begin
  if (LangIndex < 0) or (LangIndex >= Langs.Count) then
    Lang := 'en'
  else
    Lang := Langs[LangIndex];
  WizardSelectComponents('!language\*');
  WizardSelectComponents('language\' + Lang);
end;

// Download target of the file FilePath (with '/') for the game folder GameKey (EE or AoC):
// <GameKey>\<FilePath> below {tmp}. The server folders have the layout of the game folders.
function GameOnlineFileDest(const GameKey, FilePath: String): String;
begin
  Result := FilePath;
  StringChangeEx(Result, '/', '\', True);
  Result := GameKey + '\' + Result;
end;

// Registers the file FilePath of the server folder ServerDir (path below the "localized" folder
// of the servers, ending with '/') for the game folder GameKey, see AddOnlineFile. PinDir is the
// folder of data\localized-text whose SHA-256 list entry applies (see RegisterGameOnlineFiles).
procedure AddGameOnlineFile(const ServerDir, PinDir, GameKey, FilePath: String);
begin
  AddOnlineFile(ServerDir + FilePath, PinDir + FilePath, GameOnlineFileDest(GameKey, FilePath));
end;

// NeoEE setups download the NeoEE version of a localized file that has one (Mods/NeoEE/, every
// language has them), like [Files] installs the local NeoEE versions over the EE ones; EE setups
// the EE version. NeoEE setups never fall back to the EE version: installed last, it would
// replace the NeoEE file of the setup with the wrong one.
procedure AddLocalizedGameOnlineFile(const ServerDir, PinDir, GameKey, FilePath: String);
begin
#if InstallType == "NeoEE"
  AddGameOnlineFile('Mods/NeoEE/' + ServerDir, 'Mods/NeoEE/' + PinDir, GameKey, FilePath);
#else
  AddGameOnlineFile(ServerDir, PinDir, GameKey, FilePath);
#endif
end;

// Registers the localized files of one game for the language tag LangCode: GameKey (EE or AoC)
// is the game subfolder of the language folders, Campaigns are its campaign files and WithMovie
// adds the intro movie. The lobby resources are shared by EE and AoC on the servers (downloaded
// once and copied, see AddOnlineFile).
// The lobby files are requested from Lobby/<LangCode>/ as by the setups up to 1.7.2. Languages
// that share a lobby folder (zh-CN and zh-TW: LobbyDir zh, GameLangLobbyDirs) have it once in
// data\localized-text (Lobby\zh\), while the servers also have a copy per language tag (checked:
// Lobby/zh-CN/ and Lobby/zh-TW/ hold the files of Lobby/zh/), so their SHA-256 list entries are
// those of Lobby/<LobbyDir>/.
procedure RegisterGameOnlineFiles(const LangCode, LobbyDir, GameKey: String; const Campaigns: array of String; WithMovie: Boolean);
var
  Game, Lobby, LobbyPin: String;
  I: Integer;
begin
  Game := 'Game/' + LangCode + '/' + GameKey + '/';
  Lobby := 'Lobby/' + LangCode + '/';
  LobbyPin := 'Lobby/' + LobbyDir + '/';

  AddLocalizedGameOnlineFile(Game, Game, GameKey, 'Language.dll');
  AddGameOnlineFile(Game, Game, GameKey, 'Data/data.ssa');
  for I := 0 to GetArrayLength(Campaigns) - 1 do
    AddGameOnlineFile(Game, Game, GameKey, 'Data/Campaigns/' + Campaigns[I]);
  if WithMovie then
    AddGameOnlineFile(Game, Game, GameKey, 'Data/Movies/Empire Earth.bik');
  AddGameOnlineFile(Lobby + 'shared/', LobbyPin + 'shared/', GameKey, 'Data/WONLobby Resources/_WONStatus.cfg');
  AddGameOnlineFile(Lobby + 'shared/', LobbyPin + 'shared/', GameKey, 'Data/WONLobby Resources/_GameResource.cfg');
  AddGameOnlineFile(Lobby + 'shared/', LobbyPin + 'shared/', GameKey, 'Data/WONLobby Resources/_LobbyResource.cfg');
  AddLocalizedGameOnlineFile(Lobby + GameKey + '/', LobbyPin + GameKey + '/', GameKey, 'WONLobby.cfg');
#if InstallType == "NeoEE"
  AddGameOnlineFile('Mods/NeoEE/' + Lobby + 'shared/', 'Mods/NeoEE/' + LobbyPin + 'shared/', GameKey, 'Data/WONLobby Resources/_NeoEEResource.cfg');
#endif
end;

procedure RegisterOnlineFiles();
var
  Lang, LangCode, LobbyDir: String;
begin
  // Register Online Files (the game files are English, the online files replace them with the
  // localized ones if asked)
  // Mirror Order
  // EE Community (Energy) => Zocker (SelectOnlineFilesServer starts with the mirror if it is in a
  // better state: a valid certificate, or an answer at all)
  // Storage Localized structure : {base_url}/localized/{scope}/{language}/{GameType}/
  // Note: EELearningCampaign.ssa is the same for AoC, [Files] installs the one of EE for both
  // AddOnlineFile (downloads.iss) registers the file on both servers (same path on the mirror),
  // if the download policy allows it: files with code only with a known SHA-256, data files
  // without one only over https with a valid certificate; a pinned file also from a server whose
  // certificate is invalid (ADR 0012); every download is checked before it is installed.
  // Only selected content is registered (setups up to 1.7.2 gave the download plug-in the
  // condition 'game or ...', and 'game' is always selected, so every file was downloaded).
  // DownloadOnlineFiles (downloads.iss) downloads what is registered here.

  // Clears files if the user have the bad idea of going back to component to change them
  Log('Clear download file list');
  ClearOnlineFiles();

  if (not WizardIsComponentSelected('language\update')) then
  begin
    Log('Download of localized files not selected, the setup will only use local files.');
    Exit;
  end;

  Lang := GetSelectedLanguageFromComponents();
  LangCode := GetLanguageTag(Lang);
  LobbyDir := GetLobbyDir(Lang);
  if (LangCode = 'en') then
  begin
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('English language selected, no need to download online files.');
    Exit;
  end;

  if (not CanDownloadOnlineFiles()) then
  begin
    Log('This setup cannot download any localized file (no SHA-256 known, no https server), it will only use local files.');
    Exit;
  end;

  if (not SelectOnlineFilesServer()) then
  begin
    Log('Unable to reach the online files server! The setup will only use local files...');
    if (not SilentInstall and not SuppressMsgBoxes) then
      MsgBox(CustomMessage('OnlineFilesUnreachable'), mbInformation, MB_OK);
    Exit;
  end;

  Log('Adding file list to download');
  // Empire Earth (always installed), then AoC
  RegisterGameOnlineFiles(LangCode, LobbyDir, 'EE', ['EELearningCampaign.ssa', 'EETheBritish.ssa', 'EETheFuture.ssa',
    'EETheGermans.ssa', 'EETheGreeks.ssa'], WizardIsComponentSelected('additional\movies'));
  if (WizardIsComponentSelected('gameaoc')) then
    RegisterGameOnlineFiles(LangCode, LobbyDir, 'AoC', ['AOCAsian.ssa', 'AOCPacific.ssa', 'AOCRoman.ssa'], False);
end;

// Setups up to v1.7.2 set "~ RUNASADMIN" for the installing account (HKCU, administrative install
// mode) by default. Running the game elevated is opt-in now (task everyoneadminstart, HKLM), so
// that old default value is removed; any other value (e.g. set by the user) is left alone.
procedure RemoveLegacyRunAsAdmin(const ExePath: String);
var
  Value: String;
begin
  if RegQueryStringValue(HKCU, '{#BaseRegCompatibility}', ExePath, Value) and (Value = '~ RUNASADMIN') then
  begin
    if RegDeleteValue(HKCU, '{#BaseRegCompatibility}', ExePath) then
      Log('Removed the old per-user RUNASADMIN flag of ' + ExePath)
    else
      Log('Unable to remove the old per-user RUNASADMIN flag of ' + ExePath);
  end;
end;

// Setups up to 1.7.2 and the refactor branch wrote compatibility values on Windows Vista/7
// (official 1.7.2: the Windows XP SP3 mode and the flags of the task compatibility for EE-AOC.exe).
// This setup writes none there by default (the tasks compatibility and compatibility_windows need
// Windows 8), so it removes such a value, but only if it is exactly one those setups wrote
// (IsLegacyVistaCompatValue, utils.iss): any other value, e.g. one the player set, and the
// '~ RUNASADMIN' of the opt-in task everyoneadminstart, which [Registry] may have written in this
// run, stay. The value of the opt-in task compatibility_legacy is one of the old values: it stays
// for a program whose component is selected, because [Registry] wrote it in this run
// (ShouldRemoveLegacyVistaCompatValue, utils.iss; ProgramSelected = that component).
// docs/adr/0005-compatibility-and-wrapper-defaults.md, docs/adr/0010-opt-in-compatibility-on-windows-7.md,
// contract 3.7
procedure RemoveLegacyVistaCompatValue(const RootKey: Integer; const RootName, ExePath: String; const ProgramSelected: Boolean);
var
  Value: String;
  LegacyOptIn: Boolean;
begin
  LegacyOptIn := WizardIsTaskSelected('compatibility_legacy');
  if not RegQueryStringValue(RootKey, '{#BaseRegCompatibility}', ExePath, Value) then
    Log('No compatibility value of ' + ExePath + ' (' + RootName + ')')
  else if not IsLegacyVistaCompatValue(Value) then
    Log('Kept the compatibility value "' + Value + '" of ' + ExePath + ' (' + RootName + '): not a value of an earlier setup')
  else if not ShouldRemoveLegacyVistaCompatValue(Value, LegacyOptIn, ProgramSelected) then
    Log('Kept the compatibility value "' + Value + '" of ' + ExePath + ' (' + RootName + '): written by this run (task compatibility_legacy)')
  else if RegDeleteValue(RootKey, '{#BaseRegCompatibility}', ExePath) then
    Log('Removed the old Windows Vista/7 compatibility value "' + Value + '" of ' + ExePath + ' (' + RootName + ')')
  else
    Log('Unable to remove the old Windows Vista/7 compatibility value "' + Value + '" of ' + ExePath + ' (' + RootName + ')');
end;

// ssPostInstall, after [Registry]: on Windows Vista/7 the old compatibility values of both game
// programs, in the root the [Registry] entries use in this install mode (HKLM in administrative
// install mode, HKCU in user and portable mode), on every run as contract 3.7 says. Under Wine
// (which may report Windows 7) earlier setups never wrote such values, so it finds none there.
procedure RemoveLegacyVistaCompatValues;
var
  Version: TWindowsVersion;
  RootKey: Integer;
  RootName, OptIn: String;
begin
  GetWindowsVersionEx(Version);
  if not IsBelowWindows8(Version.Major, Version.Minor) then
    Exit;
  if IsAdminInstallMode then
  begin
    RootKey := HKLM;
    RootName := 'HKLM';
  end else
  begin
    RootKey := HKCU;
    RootName := 'HKCU';
  end;
  if WizardIsTaskSelected('compatibility_legacy') then
    OptIn := ' (opt-in task compatibility_legacy selected)'
  else
    OptIn := '';
  Log('Windows ' + IntToStr(Version.Major) + '.' + IntToStr(Version.Minor) + ': this setup writes no compatibility values on ' +
    'Windows Vista/7 by default, checking ' + RootName + ' for values of earlier setups' + OptIn);
  RemoveLegacyVistaCompatValue(RootKey, RootName, ExpandConstant('{app}\{#EEExe}'), WizardIsComponentSelected('game'));
  RemoveLegacyVistaCompatValue(RootKey, RootName, ExpandConstant('{app}\{#AoCExe}'), WizardIsComponentSelected('gameaoc'));
end;

// After the Ready page and the downloads into {tmp}, before anything is changed: in administrative
// install mode no installation through links in the folders all users can write to (Data, Users;
// CheckGameFoldersForLinks, environment.iss, ADR 0009). A message stops the setup on the "Preparing
// to install" page; a silent installation ends with exit code 7. The user and portable modes do not
// elevate the setup and are not checked.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if IsAdminInstallMode then
    Result := CheckGameFoldersForLinks()
  else
    Log('Link check skipped: not the administrative install mode');
end;

// Installation steps
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssInstall) then
  begin
    // The very first statement of this step, before anything below changes the game folder (the install state
    // goes, the downloads are moved, the shipped random maps are deleted or moved aside): from this line on the
    // suite no longer offers Cancel, because a killed setup would leave a game without install state or without
    // its random maps. Inno Setup's own "Starting the installation process." comes later (after this procedure
    // returned), too late for that.
    // The suite parses this line (contract 1.7 point 5): change it only together with suite/suite_common.iss
    Log('Install step: the game folder is changed from here on');
    // First, before [Files]: install.ini and files.sha256 of the previous run go, so that an aborted
    // installation leaves none that claims a valid state; a failed deletion is remembered
    // (WriteInstallState)
    DeleteInstallState();
    // Runs before [Files]: only downloads matching their SHA-256 are moved to {tmp}\verified
    VerifyDownloadedFiles();
    // Before [Files]: removes the maps the previous setup installed, remembers the player's own
    PrepareRandomMapScripts();
#if CertInclude
    RecordPreviousCertificate();
#endif
  end
  else if (CurStep = ssPostInstall) then
  begin
    FinishRandomMapScripts();
#if CertInclude
    RemoveLegacyRootCertificate();
#endif
    if (IsAdminInstallMode and not IsWine()) then
    begin
      RemoveLegacyRunAsAdmin(ExpandConstant('{app}\{#EEExe}'));
      RemoveLegacyRunAsAdmin(ExpandConstant('{app}\{#AoCExe}'));
    end;
    // Windows Vista/7: no compatibility values by default, those of earlier setups are removed
    // (except the value of the opt-in task compatibility_legacy of this run)
    RemoveLegacyVistaCompatValues();
#if InstallType == "NeoEE"
    // After all [Run] entries (it used to be the AfterInstall of a dummy "cmd.exe /C" entry)
    if (WizardIsTaskSelected('neoee_cdkeys')) then
    begin
      if (WizardIsComponentSelected('gameaoc')) then
        WizardForm.StatusLabel.Caption := CustomMessage('CDKeysStatusEEAoC')
      else
        WizardForm.StatusLabel.Caption := CustomMessage('CDKeysStatusEE');
      RegisterCDKeys();
    end;
#endif
    // Last, after every other step (contract 1.2, 1.3, 2.1): files.sha256 and install.ini of the
    // files this run processed (progress page, notice if files are gone), then the contract version
    // in the uninstall key of the Regular variants if the install state of this run is complete
    WriteInstallState();
  end;
end;

// Installation mode page: the games of the recommended settings and the telemetry consent
procedure OnManualInstallPageNext;
begin
  if (ManualInstallQuestionPage.Values[MiqpRecommended]) then
  begin
    if (ManualInstallQuestionPage.Values[MiqpRecommendedEE]) then
    begin
      WizardSelectComponents('game');
      WizardSelectComponents('!gameaoc');
    end else if (ManualInstallQuestionPage.Values[MiqpRecommendedEEAoC]) then
    begin
      WizardSelectComponents('game');
      WizardSelectComponents('gameaoc');
    end;
  end
  else if (IsGameInstalled()) then
  begin
    // Repair/update or custom settings: AoC as in the previous installation, also when a choice
    // of the recommended settings changed it before the user came back to this page
    if (WizardIsComponentInstalled('gameaoc')) then
      WizardSelectComponents('gameaoc')
    else
      WizardSelectComponents('!gameaoc');
  end;

  if (ManualInstallQuestionPage.Values[MiqpTelemetry]) then
    WizardSelectComponents('additional\telemetry')
  else
    WizardSelectComponents('!additional\telemetry');
end;

// Language page: the language component of the checked language
procedure OnLanguagePageNext;
var
  I: Integer;
begin
  for I := 0 to Langs.Count - 1 do
    if (LanguageInstallQuestionPage.Values[I]) then
    begin
      SelectLanguageFromIndex(I);
      Break;
    end;
end;

#if InstallMode == "Regular"
// The recommended settings select the components by code, so the uninstall key records the
// setup type 'custom' instead of the type Inno Setup derived. Not in portable setups: they have
// no uninstall key (CreateUninstallRegKey=no), writing the value would create one that is never
// removed.
procedure RecordCustomSetupType;
begin
  if (not ManualInstallQuestionPage.Values[MiqpRecommended]) then
    Exit;
  Log('Forcing custom install type, because we used the manual install question page.');
  if not RegKeyExists(HKA, GetUninstallRegPath()) then
    Log('Uninstall key not found, install type not changed')
  else if not RegWriteStringValue(HKA, GetUninstallRegPath(), 'Inno Setup: Setup Type', 'custom') then
    Log('Unable to write the install type to the uninstall key');
end;
#endif

// Finished page (the user clicked Finish): statistics and the setup type
procedure OnFinishedPageNext;
begin
  SendSetupTelemetry();
#if InstallMode == "Regular"
  RecordCustomSetupType();
#endif
end;

// Dispatches to the handler of the page. Only the folder page can keep the wizard: when the user
// answers a question of CheckSelectedFolder (environment.iss) with Yes; in silent mode it never does.
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = ManualInstallQuestionPage.ID) then
  begin
    if (not SilentInstall) then
      OnManualInstallPageNext();
  end
  else if (CurPageID = GPUInstallQuestionPage.ID) then
    ApplyGpuOption()
  else if (CurPageID = LanguageInstallQuestionPage.ID) then
    OnLanguagePageNext()
  else if (CurPageID = wpSelectDir) then
    // Read-only: foreign or old installations, their folders, the folder of the other product
    Result := CheckSelectedFolder()
  else if (CurPageID = wpReady) then
  begin
    // The components are final now: register the localized files and download them on the
    // download page; a failed or stopped download never keeps the wizard on this page
    RegisterOnlineFiles();
    DownloadOnlineFiles();
  end
  else if (CurPageID = wpFinished) then
    OnFinishedPageNext();
end;

function InitializeUninstall(): Boolean;
begin
#if CertInclude
  CertAddedBySetup := UninstallKeyHasTask(GetUninstallRegPath(), 'certinclude');
#endif
  Result := True;
end;

const
  // Setup background: the 16:9 image if the window is wider than this (width / height), else the
  // 4:3 one (16:9 = 1.78, 4:3 = 1.33)
  WideBackgroundMinRatio = 1.55;

// Setup background behind the wizard: the 16:9 or the 4:3 image, whichever fits the window
procedure CreateSetupBackground;
var
  BackgroundImage: TBitmapImage;
  Ratio: Double;
  ScrWidth: Double;
  ScrHeight: Double;
begin
  Log('Init setup background');
  BackgroundImage := TBitmapImage.Create(MainForm);
  BackgroundImage.Parent := MainForm;
  BackgroundImage.SetBounds(0, 0, MainForm.ClientWidth, MainForm.ClientHeight);
  BackgroundImage.Stretch := True;

  // Width / height as a fraction (Double), compared with WideBackgroundMinRatio
  ScrWidth := MainForm.ClientWidth;
  ScrHeight := MainForm.ClientHeight;
  Ratio := ScrWidth / ScrHeight;

  Log('Extracting and defining image banner');
  if (Ratio > WideBackgroundMinRatio) then
  begin
    ExtractTemporaryFile('SetupBackground-16-9.bmp');
    BackgroundImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\SetupBackground-16-9.bmp'));
  end
  else
  begin
    ExtractTemporaryFile('SetupBackground-4-3.bmp');
    BackgroundImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\SetupBackground-4-3.bmp'));
  end;
end;

procedure InitializeWizard;
begin
  if (not SilentInstall and not IsWine) then
    bassCreateButton();

  RegisterLangs();
  RegisterDownloadPins();
  RecordInstallStateForTelemetry();

  Log('Init custom setup pages');
  SetupLanguagePage();
  SetupManualCustomInstallPage();
  SetupGPUInstallPage();

  CreateSetupBackground();

  if (not SilentInstall and not IsWine) then
    bassPlay();

  // The download page of the online localized files (shown by DownloadOnlineFiles)
  CreateOnlineFilesDownloadPage();
  // The progress page of the integrity manifest (shown by WriteInstallState)
  CreateManifestProgressPage();
end;

procedure DeinitializeSetup;
begin
  // Puts a random map folder moved aside back if the installation did not complete
  RestoreRandomMapScripts();
  if (not SilentInstall and not IsWine) then
  begin
    bassFree;
  end;
end;
