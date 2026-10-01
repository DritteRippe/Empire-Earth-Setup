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
;   InnoSetup Downloader Plugin (download files + support mirrors), BASS (audio module)
; Additinal Content
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

; Build switches
; Each switch below has a default here and can be overridden on the command line instead of
; editing this file:  ISCC /D<Switch>=<Value> setup_is6.iss
;   InstallMode   Regular | Portable                           (default: Regular)
;   InstallType   EE | NeoEE                                   (default: EE)
;   SignSetup     0 | 1 (or false | true), needs the SignTool  (default: 0)
;                 named in [Setup] to be configured (ISCC /S)
;   CertFileName  certificate file (DER) in internal\misc      (only used when SignSetup = 1)
;   CertHashSHA1  SHA-1 thumbprint of that certificate         (only used when SignSetup = 1)
;   TestID        0 = release build, > 0 = test build          (default: 0)
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
;       opt-in task certinclude, unchecked by default). If you want to use
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
  ; when it is removed on uninstall, so it has to be the one of CertFileName. The certificate file
  ; must be DER encoded: then its SHA-1 is the thumbprint. (The file only exists in the final
  ; compile, the first pass of ci\build.ps1 -Placeholders skips that comparison.)
  #define CertThumbprint LowerCase(StringChange(CertHashSHA1, " ", ""))
  #if Len(CertThumbprint) != 40
    #error CertHashSHA1 must be the SHA-1 thumbprint (40 hex digits) of the certificate when SignSetup is enabled
  #endif
  #if FileExists(AddBackslash(SourcePath) + "internal\misc\" + CertFileName)
    #if GetSHA1OfFile(AddBackslash(SourcePath) + "internal\misc\" + CertFileName) != CertThumbprint
      #pragma error "CertHashSHA1 is not the SHA-1 thumbprint of internal\misc\" + CertFileName + " (the certificate file must be DER encoded)"
    #endif
  #endif
#endif

; Regedit
#if InstallType == "EE"
  #define BaseRegEE = "Software\SSSI\Empire Earth"
  #define BaseRegAoC = "Software\Mad Doc Software\EE-AOC"
#elif InstallType == "NeoEE"
  #define BaseRegEE = "Software\Neo\Empire Earth"
  #define BaseRegAoC = "Software\Neo\Art of Conquest"
#else
  #error Unsupported Install Type
#endif
#define BaseRegCompatibility = "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"

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
#define IsPlainGuid(str S) Len(S) == 36 && Copy(S, 9, 1) == "-" && Copy(S, 14, 1) == "-" && Copy(S, 19, 1) == "-" && Copy(S, 24, 1) == "-"
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

; Hidden folder in {app} for the files the uninstaller needs (EEStatsSetup.dll). It has a fixed name
; so that no build setting can turn it into {app} itself. Setups up to v1.7.2 named it after the
; AppId ("{app}\<AppId>"); [InstallDelete] removes that old folder.
#define SetupDataDir "_setupdata"

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

#if InstallType == "EE"
  #define AppID EE_AppID
  #define MyAppVersion "2.0.0.0"
  #define MyAppName "Empire Earth"
  #define MyAppPublisher "Empire Earth Community"
  #define MyAppURL "https://empireearth.eu/"
  #define MyInstallDirName "Empire Earth"
  #define MySetupPassword "ee"
#elif InstallType == "NeoEE"
  #define AppID NeoEE_AppID
  #define MyAppVersion "2.0.0.5"
  #define MyAppName "NeoEE"
  #define MyAppPublisher "Empire Earth Community & NeoEE"
  #define MyAppURL "https://www.neoee.net/"
  #define MyInstallDirName "Neo Empire Earth"
  #define MySetupPassword "neo"
#else
  #error Unsupported Install Type
#endif

; AppId: Tools > Generate GUID
; Be very careful with AppId, it's like the unique id of the setup, be sure to generate it with inno setup
; the first time you distribute your setup and to keep it forever for the setup !
; So since it's a unique setup id, EE & NeoEE must have different AppId !

[Setup]
; SignTool: We need to use InnoSetup SignTool feature to sign install/uninstall etc...
AppId={{{#AppID}}
#if InstallType == "EE"
  SetupIconFile=data\Empire Earth Base\Empire Earth\game.ico
  WizardSmallImageFile=internal\media\WizardSmallImageFileEE.bmp
  #if SignSetup
    SignTool=NameInInnoSetupEE $f
  #endif
#elif InstallType == "NeoEE"
  SetupIconFile=data\NeoEE Base\shared\neoee.ico
  WizardSmallImageFile=internal\media\WizardSmallImageFileNeo.bmp
  #if SignSetup
    SignTool=NameInInnoSetupNeo $f
  #endif
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
#if InstallType == "NeoEE"
  InfoBeforeFile=data\NeoEE Base\shared\neoee_rules.rtf
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
  #if InstallType == "EE"
    OutputBaseFilename={#InstallType}_Setup_v{#MySetupVersion}
  #elif InstallType == "NeoEE"
    OutputBaseFilename={#InstallType}_v{#MyAppVersion}_Setup_v{#MySetupVersion}
  #endif
#elif InstallMode == "Portable"
  UsePreviousAppDir=no
  Uninstallable=no
  CreateUninstallRegKey=no
  PrivilegesRequired=lowest
  DefaultDirName={src}\{#MyInstallDirName} Portable
  #if InstallType == "EE"
    OutputBaseFilename={#InstallType}_Portable_Setup_v{#MySetupVersion}
  #elif InstallType == "NeoEE"
    OutputBaseFilename={#InstallType}_Portable_v{#MyAppVersion}_Setup_v{#MySetupVersion}
  #endif
#else
  #error Unsupported Install Mode
#endif

; Includes
#include "utils.iss"
#include "messages.iss"
#include "internal\lib\idp\idp.iss"
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
Name: "compatibility"; Description: "{cm:TaskCompatibility}"; MinVersion: {#WinXP}; Check: not IsWine
Name: "compatibility_windows"; Description: "{cm:TaskCompatibilityWindows}"; MinVersion: {#WinXP}; Check: not IsWine
Name: "firewallexception"; Description: "{cm:TaskFirewall}"; MinVersion: {#Win2000}; Check: IsAdminInstallMode and not IsWine
; DirectPlay: Windows feature used by old DirectX games, the GOG setup enables it too (see [Run])
Name: "directplay"; Description: "{cm:TaskDirectPlay}"; MinVersion: {#Win8}; Check: IsAdminInstallMode
Name: "dxwebsetup"; Description: "{cm:TaskDxWebSetup}"; MinVersion: {#Win2000}; Check: IsAdminInstallMode and not IsWine; Components: additional\directx_wrapper\dx9 or not additional\directx_wrapper
#if InstallType == "NeoEE"
  ; Since 1.0.1.0 NeoEE CDKeys support HKLM & HKCU
  Name: "neoee_cdkeys"; Description: "{cm:TaskNeoEECDKeys}"; MinVersion: {#Win2000};
#endif

#if CertInclude
  ; Opt-in, also for administrators: adds the community certificate to the trusted root
  ; certification authorities (all users in administrative install mode, else the current user)
  Name: "certinclude"; Description: "{cm:TaskCertInclude}"; MinVersion: {#WinVista}; Flags: unchecked; Check: not IsWine
#endif

; Opt-in: the game (online lobby, maps and scenarios from other players) should not run elevated.
; Selected, it sets RUNASADMIN for all users (HKLM) and skips the write permissions below.
Name: "everyoneadminstart"; Description: "{cm:TaskAdminStart}"; MinVersion: {#WinXP}; Flags: unchecked; Check: IsAdminInstallMode and not IsWine

#if InstallMode != "Portable"
  Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
  Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: {#Win7}
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
Name: "language\update"; Description: "{cm:CompLanguageUpdate}"; Types: full compact custom raw; Flags: disablenouninstallwarning;

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
Source: "data\localized-text\{#LocTextBase}Game\{#StringChange(GameLangs[LangIndex], "_", "-")}\{#LocTextGame}\Language.dll"; DestDir: "{app}\{#LocTextDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: {#LocTextComp} and language\{#GameLangs[LangIndex]}
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
Source: "data\localized-text\{#LocTextBase}Lobby\{#GameLangLobbyDirs[LangIndex]}\{#LocTextLobbySub}\*"; DestDir: "{app}\{#LocTextDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: {#LocTextComp} and {#LobbyLangCond}
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
Source: "data\Add-on\DLLs\dreXmod\2\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and {#AddOnComp}
Source: "data\Add-on\DLLs\dreXmod\2_privacy\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and {#AddOnComp} and not additional\telemetry
; dreXmod 3 (+privacy config)
Source: "data\Add-on\DLLs\dreXmod\3\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and {#AddOnComp}
Source: "data\Add-on\DLLs\dreXmod\3_privacy\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and {#AddOnComp} and not additional\telemetry
  #if InstallType == "EE"
; Random maps (NeoEE setups install them with the NeoEE base files)
Source: "data\Add-on\RMS\Omega\{#AddOnOmega}\*"; DestDir: "{app}\{#AddOnDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\omega and {#AddOnComp}
Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#AddOnDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\neoextra and {#AddOnComp}
  #endif
; dgVoodoo binaries (DirectX 11/12 wrapper) or DDraw.dll (GOG for dx9, DDrawCompat for dx7)
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_bin\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper and {#AddOnComp} and not additional\directx_wrapper\dx9 and not additional\directx_wrapper\dx7
Source: "data\Add-on\DirectX_Wrapper\GOG\DDraw.dll"; DestDir: "{app}\{#AddOnDir}"; DestName: "DDraw.dll"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx9 and {#AddOnComp}
Source: "data\Add-on\DirectX_Wrapper\DDrawCompat\DDraw.dll"; DestDir: "{app}\{#AddOnDir}"; DestName: "DDraw.dll"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx7 and {#AddOnComp}
; dgVoodoo configuration of the selected API level
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10 and {#AddOnComp}
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10_1.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10_1 and {#AddOnComp}
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL11.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl11 and {#AddOnComp}
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL11.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl11 and {#AddOnComp}
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL12.conf"; DestDir: "{app}\{#AddOnDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl12 and {#AddOnComp}
; Civilizations
Source: "data\Add-on\Civs\eC\*"; DestDir: "{app}\{#AddOnDir}\Users\default\Civilizations"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec and {#AddOnComp}
Source: "data\Add-on\Civs\eC_full\*"; DestDir: "{app}\{#AddOnDir}\Users\default\Civilizations"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec_full and {#AddOnComp}
; Discord presence
Source: "data\Add-on\DLLs\Discord\*"; DestDir: "{app}\{#AddOnDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\discord and {#AddOnComp}
#endsub

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
#if CertInclude
  Source: "internal\misc\{#CertFileName}"; DestDir: "{tmp}"; DestName: "{#CertFileName}"; Flags: deleteafterinstall; Tasks: certinclude;
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
Source: "data\Empire Earth Base\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game;
; EE Movies
Source: "data\Add-on\Movies\EE\*"; DestDir: "{app}\{#EEDir}\Data\Movies"; Flags: ignoreversion recursesubdirs createallsubdirs nocompression; Components: additional\movies and game;

#if InstallType == "NeoEE"
  Source: "data\NeoEE Base\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game
  Source: "data\NeoEE Base\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game
  Source: "data\Add-on\RMS\Omega\EE\*"; DestDir: "{app}\{#EEDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game
  Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#EEDir}\{#RmsSubDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game
  Source: "data\NeoEE - Admin\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; Check: IsAdminInstallMode
  Source: "data\NeoEE - User\Empire Earth\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; Check: not IsAdminInstallMode
  Source: "data\NeoEE - CDKeys\authtools.dll"; DestDir: "{tmp}"; DestName: "authtools.dll"; Flags: dontcopy noencryption nocompression; Components: game;
  Source: "data\NeoEE - CDKeys\_wonkver.pub"; DestDir: "{app}\{#EEDir}"; Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs; Components: game
  ; NeoEE - Wine Fix (GDI)
  Source: "data\NeoEE - Wine\NeoEE.cfg"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game; Check: IsWine
#endif

; EE localized text (Language.dll, lobby files) of the selected game language
#expr LocTextBase = "", LocTextGame = "EE", LocTextDir = EEDir, LocTextComp = "game"
#call LocalizedTextFiles
#if InstallType == "NeoEE"
  ; NeoEE versions, installed over the ones above
  #expr LocTextBase = "Mods\NeoEE\"
  #call LocalizedTextFiles
#endif

; EE Online Lang Any Based Content (only downloads that passed the SHA-256 check, see downloads.iss)
Source: "{tmp}\verified\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs external skipifsourcedoesntexist; Components: game and language\update;

; Add-on files (see GameAddOnFiles)
#expr AddOnDir = EEDir, AddOnComp = "game", AddOnOmega = "EE"
#call GameAddOnFiles

; EEStats
Source: "data\Add-on\DLLs\EEStats\EEStats.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\telemetry and game; MinVersion: {#Win7}

; HD
Source: "data\Add-on\HD\terrain\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\terrain and game

; Music
Source: "data\Add-on\HD\music\*"; DestDir: "{app}\{#EEDir}\Data\Sounds"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\music and game

; Tech
Source: "data\Add-on\HD\tech\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\tech and game

; Building
Source: "data\Add-on\HD\buildings\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\buildings and game

; Effects
Source: "data\Add-on\HD\effects\*"; DestDir: "{app}\{#EEDir}\Data\Textures"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\hd\effects and game

; ----------------

; AoC Base
Source: "data\Empire Earth Base\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc;
; AoC Movies
Source: "data\Add-on\Movies\AoC\*"; DestDir: "{app}\{#AoCDir}\Data\Movies"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\movies and gameaoc;

#if InstallType == "NeoEE"
  Source: "data\NeoEE Base\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc
  Source: "data\NeoEE Base\shared\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc
  Source: "data\Add-on\RMS\Omega\AoC\*"; DestDir: "{app}\{#AoCDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc
  Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#AoCDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc
  Source: "data\NeoEE - Admin\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; Check: IsAdminInstallMode
  Source: "data\NeoEE - User\Empire Earth - The Art of Conquest\*"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; Check: not IsAdminInstallMode
  Source: "data\NeoEE - CDKeys\_wonkver.pub"; DestDir: "{app}\{#AoCDir}"; \
    Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs; Components: gameaoc
  ; NeoEE - Wine Fix (GDI)
  Source: "data\NeoEE - Wine\NeoEE.cfg"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; Check: IsWine
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
Source: "data\Add-on\Tools\Diagnostic\*"; DestDir: "{app}\Tools\Diagnostic"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\tools\diagnostic;

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
;   WINXPSP3   DWM8And16BitMitigation    for Windows Vista/7 (OnlyBelowVersion: Win8)
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
; "~" plus RUNASADMIN (task everyoneadminstart) and the flags of the task compatibility; the task
; compatibility_windows adds a Windows compatibility mode: WIN7RTM on Windows 8 and later, WINXPSP3
; on Vista/7. CompatibilityValues writes the value of EE and of AoC for the current parameters:
;   CompatRoot, CompatCheck  registry root and the Check of the install mode
;   CompatTasks              Tasks condition
;   CompatVersions           version filter parameters, "" or "MinVersion: ...; [OnlyBelowVersion: ...; ]"
;   CompatLayer              "" or " <Windows compatibility mode>"
; CompatibilityValuesByWindows writes them for Windows 8 and later and for Vista/7, with the
; Windows compatibility mode of each if CompatWindowsMode is 1.
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
#sub CompatibilityValuesByWindows
  #expr CompatVersions = "MinVersion: " + Win8 + "; ", CompatLayer = (CompatWindowsMode ? " WIN7RTM" : "")
  #call CompatibilityValues
  #expr CompatVersions = "MinVersion: " + WinVista + "; OnlyBelowVersion: " + Win8 + "; ", CompatLayer = (CompatWindowsMode ? " WINXPSP3" : "")
  #call CompatibilityValues
#endsub

; Administrative install mode: for all users (HKLM)
#expr CompatRoot = "HKLM", CompatCheck = "IsAdminInstallMode"
; Windows compatibility mode (here also without the task compatibility, unlike in HKCU below)
#expr CompatTasks = "compatibility_windows", CompatWindowsMode = 1
#call CompatibilityValuesByWindows
; Compatibility flags without Windows compatibility mode
#expr CompatTasks = "not compatibility_windows and compatibility", CompatWindowsMode = 0
#call CompatibilityValuesByWindows
; RUNASADMIN only (opt-in task everyoneadminstart without the compatibility tasks), any Windows.
; Setups up to v1.7.2 also set "~ RUNASADMIN" in HKCU for the installing account by default;
; CurStepChanged removes that old value (RemoveLegacyRunAsAdmin).
#expr CompatTasks = "everyoneadminstart and not compatibility_windows and not compatibility", CompatVersions = "", CompatLayer = ""
#call CompatibilityValues

; Non-administrative install mode: for the current user (HKCU); everyoneadminstart is admin only
#expr CompatRoot = "HKCU", CompatCheck = "not IsAdminInstallMode"
; Windows compatibility mode (needs both tasks here)
#expr CompatTasks = "compatibility_windows and compatibility", CompatWindowsMode = 1
#call CompatibilityValuesByWindows
; Compatibility flags without Windows compatibility mode
#expr CompatTasks = "not compatibility_windows and compatibility", CompatWindowsMode = 0
#call CompatibilityValuesByWindows

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

[Icons]
#if InstallMode != "Portable"
  Name: "{group}\{#MyAppName}"; Filename: "{app}\{#EEExe}"; Components: game;
  Name: "{group}\{#MyAppName} - AoC"; Filename: "{app}\{#AoCExe}"; Components: gameaoc;
  Name: "{group}\{#MyAppName} Diagnostic"; Filename: "{app}\Tools\Diagnostic\EE-Diagnostic.exe"; Parameters: "{#SetupSetting("AppId")}_is1"; Components: additional\tools\diagnostic;
  ; Uncomment to add the Uninstall shortcut in the Start Menu
  ; Name: "{group}\{cm:UninstallProgram,Empire Earth}"; Filename: "{uninstallexe}";
  Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#EEExe}"; Components: game; Tasks: desktopicon;
  Name: "{autodesktop}\{#MyAppName} - AoC"; Filename: "{app}\{#AoCExe}"; Components: gameaoc; Tasks: desktopicon;
  Name: "{autoappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#EEExe}"; Components: game; Tasks: quicklaunchicon;
  Name: "{autoappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName} - AoC"; Filename: "{app}\{#AoCExe}"; Components: gameaoc; Tasks: quicklaunchicon;
  Name: "{autoappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName} Diagnostic"; Filename: "{app}\Tools\Diagnostic\EE-Diagnostic.exe"; Parameters: "{#SetupSetting("AppId")}_is1"; Components: additional\tools\diagnostic; Tasks: quicklaunchicon;
#endif

[InstallDelete]
; Supported Component modification : old GOG or Retail | dgVoodoo | dreXmod | Discord | Movies | Reborn | EEStats
; Other component are too hard to delete without maybe deleting user files (modding)
; Random Map Scripts: only the files installed by the previous setup are removed, see randommaps.iss
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
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm"
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
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm"
Type: files; Name: "{app}\{#AoCDir}\dxmdata"
Type: files; Name: "{app}\{#AoCDir}\discord_game_sdk.dll"
Type: files; Name: "{app}\{#AoCDir}\EEDiscordRichPresence.dll"
Type: files; Name: "{app}\{#AoCDir}\EEDiscord.dll"
Type: files; Name: "{app}\{#AoCDir}\Data\Scenarios\ScenDefault.scn"

Type: files; Name: "{app}\{#AoCDir}\OOS *.log"
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\Movies\"
; ----------------
; Setup data folder of setups up to v1.7.2 (now {#SetupDataDir}). Safe: AppID is checked to be a GUID
Type: filesandordirs; Name: "{app}\{#AppID}"

[UninstallDelete]
; A little extra cleaning of the installed files
; Convention : Never delete the entire program folder !
Type: files; Name: "{app}\{#EEDir}\0_Error.log"
Type: files; Name: "{app}\{#EEDir}\neoee.log"
Type: files; Name: "{app}\{#EEDir}\upnp_info.txt"
Type: files; Name: "{app}\{#EEDir}\Reborn.ini"
Type: files; Name: "{app}\{#EEDir}\EEStats.log"
Type: filesandordirs; Name: "{app}\{#EEDir}\Data\dxm"
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
Type: filesandordirs; Name: "{app}\{#AoCDir}\Data\dxm"
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
; Add Cert in Windows Trusted Root CA Store (only if the extracted file has the expected thumbprint)
#if CertInclude
  Filename: "{sys}\certutil.exe"; Parameters: "-addstore root ""{tmp}\{#CertFileName}"""; Flags: runhidden; Tasks: certinclude; \
    StatusMsg: "{cm:StatusCertificate}"; MinVersion: {#WinVista}; Components: game; Check: IsAdminInstallMode and IsCertificateFileGenuine
  Filename: "{sys}\certutil.exe"; Parameters: "-user -addstore root ""{tmp}\{#CertFileName}"""; Flags: runhidden; Tasks: certinclude; \
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
// All requests use HTTPS with validated certificates and never fall back to HTTP: the answers
// decide what the (elevated) setup opens or installs.
const
  // Hosts: the EE community website and the mirror of its file server
  DomainMain = 'empireearth.eu';
  DomainMirror = 'ee.zocker-160.de';
  // One base URL per endpoint; the code only appends paths and parameters
  SetupURL = 'https://' + DomainMain + '/download';                      // download page of the setup
  ApiURL = 'https://api.' + DomainMain;                                  // web API of the website
  UpdateApiURL = ApiURL + '/setup/?product={#AppID}';                    // update check (QueryUpdateApi)
  TelemetryApiURL = ApiURL + '/eestats/setup/';                          // setup statistics (SendSetupTelemetry)
  OnlineFilesURL = 'https://files.' + DomainMain + '/localized';         // localized files (downloads.iss)
  OnlineFilesMirrorURL = 'https://storage.' + DomainMirror + '/localized';
  GogStoreURL = 'https://www.gog.com/game/empire_earth_gold_edition';    // legal question
  // Besides DomainMain, the hosts a download URL of the update API may point to (IsAllowedUpdateUrl)
  DomainNeoEE = 'neoee.net';
  GitHubHost = 'github.com';
  GitHubProjectPath = '/EE-modders/';

// EEStatsSetup.dll (IsWine, GetWineVersion, GetGpuVendorId and the statistics values)
#include "eestats.iss"

#if InstallType == "NeoEE"
  // Closed-source NeoEE tool, see RegisterCDKeys. delayload: the DLL is only loaded when the keys
  // are registered, so a DLL removed by an anti-virus no longer stops the setup from starting.
  function generate_cdkeys(args: PAnsiChar; admin: BOOL): DWORD;
    external 'generate_cdkeys@files:authtools.dll cdecl setuponly delayload';
#endif

// Screen size for the default game window (GetScreenResolutionWidth/Height)
function GetSystemMetrics(nIndex: Integer): Integer;
    external 'GetSystemMetrics@user32.dll stdcall';

var
  Langs: TStringList;

#include "extension.iss"
#include "pages.iss"
#include "downloads.iss"
#include "randommaps.iss"

function GetCompatibilityFlags(Param: String): String;
begin
  Result := '~';

  if WizardIsTaskSelected('everyoneadminstart') then
  begin
    Result := Result + ' RUNASADMIN';
  end;

  if WizardIsTaskSelected('compatibility') then
  begin
    Result := Result + ' DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation';
  end;
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

const
  // GetSystemMetrics indexes (Win32 API): width and height of the primary screen
  SM_CXSCREEN = 0;
  SM_CYSCREEN = 1;
  // The default game window ([Registry]) is the size of the screen, within these limits
  MinGameWindowWidth = 1024;
  MaxGameWindowWidth = 1920;
  MinGameWindowHeight = 768;
  MaxGameWindowHeight = 1080;

function GetScreenResolutionHeight(Param: String): String;
var
  Tmp: Integer;
begin
  Tmp := GetSystemMetrics(SM_CYSCREEN);
  if Tmp < MinGameWindowHeight then
    Tmp := MinGameWindowHeight;
  if Tmp > MaxGameWindowHeight then
    Tmp := MaxGameWindowHeight;
  Result := IntToStr(Tmp);
end;

function GetScreenResolutionWidth(Param: String): String;
var
  Tmp: Integer;
begin
  Tmp := GetSystemMetrics(SM_CXSCREEN);
  if Tmp < MinGameWindowWidth then
    Tmp := MinGameWindowWidth;
  if Tmp > MaxGameWindowWidth then
    Tmp := MaxGameWindowWidth;
  Result := IntToStr(Tmp);
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

// The download URL comes from the update API: only https URLs on the project's own hosts may be
// opened (EE community website, NeoEE website, EE-modders on GitHub)
function IsAllowedUpdateUrl(const Url: String): Boolean;
var
  Host, Path: String;
begin
  Result := False;
  if not SplitHttpsUrl(Url, Host, Path) then
    Exit;
  if IsDomainOrSubdomain(Host, DomainMain) or IsDomainOrSubdomain(Host, DomainNeoEE) then
    Result := True
  else if Host = GitHubHost then
    // Anyone can publish on github.com: only the EE-modders organization, no dot segments/escapes
    Result := (CompareText(Copy(Path, 1, Length(GitHubProjectPath)), GitHubProjectPath) = 0) and (Pos('..', Path) = 0) and (Pos('%', Path) = 0);
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

// Language tag of a game language: the component name with '-' instead of '_' (pt_BR -> pt-BR),
// as the language folders of data\localized-text and of the file servers are named
function GetLanguageTag(Lang: String): String;
begin
  if (Pos('_', Lang) > 0) then
    Lang[Pos('_', Lang)] := '-';
  Result := Lang;
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
  // The game languages of [Components] (GameLangs), in the same order
#sub AddGameLang
  Langs.Add('{#GameLangs[LangIndex]}');
#endsub
#for {LangIndex = 0; LangIndex < GameLangCount; LangIndex++} AddGameLang
  Log('Registered languages: ' + Langs.CommaText);
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
// Test builds only, shown even in silent mode
procedure ShowTestSetupWarning;
begin
  MsgBox(FmtMessage(CustomMessage('TestSetupWarning'), ['{#TestID}', '{#MySetupVersion}', '{#MyAppVersion}']), mbInformation, MB_OK);
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

// Before the wizard: setup music, update check and the questions that can end the setup
function InitializeSetup: Boolean;
begin
  Result := False;

  if (not SilentInstall and not IsWine) then
    bassInit();
  if (IsWine()) then
    Log('Wine detected v' + GetWineVersion());

  if (UpdateRequested()) then
    Exit;
  if (not ConfirmLegalCopy()) then
    Exit;
#if TestID != 0
  ShowTestSetupWarning();
#endif
  if (not ConfirmInstallMode()) then
    Exit;
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

// Removes the certificate from the store [Run] added it to (machine or current user)
procedure RemoveCertificate;
var
  Params: String;
  ResultCode: Integer;
begin
  Params := '-delstore root ' + AddQuotes('{#CertThumbprint}');
  if not IsAdminInstallMode then
    Params := '-user ' + Params;
  Log('Removing certificate from store: certutil ' + Params);
  if not Exec(ExpandConstant('{sys}\certutil.exe'), Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Log('Unable to run certutil: ' + SysErrorMessage(ResultCode))
  else if ResultCode <> 0 then
    Log('certutil failed with exit code ' + IntToStr(ResultCode));
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
    // (EE <-> NeoEE) still uses it: same install mode (HKA), so same certificate store
    if not CertAddedBySetup then
      Log('Certificate not added by this setup, not removed')
    else if UninstallKeyHasTask(GetOtherProductUninstallRegPath(), 'certinclude') then
      Log('Certificate still used by the other setup, not removed')
    else
      RemoveCertificate();
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
    Log('Register NeoEE CD Keys for EE')
  else
    Log('Register NeoEE CD Keys for EE and AoC');

  try
    AuthExitCode := generate_cdkeys(GetCDKeysArgs(EEDir, AoCDir), IsAdminInstallMode);
  except
    // authtools.dll is loaded here (delayload): missing or blocked, e.g. by an anti-virus
    Log('Unable to call authtools.dll: ' + GetExceptionMessage);
    ShowCDKeysError(CustomMessage('CDKeysToolMissing'));
    Exit;
  end;

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

// Registers the file FilePath (with '/') of the server folder ServerDir (path below the "localized"
// folder of the servers, ending with '/') for the game folder GameKey (EE or AoC): it is downloaded
// to {tmp}\<GameKey>\<FilePath>. The server folders have the layout of the game folders.
function AddGameOnlineFile(const ServerDir, GameKey, FilePath: String): Boolean;
var
  RelDest: String;
begin
  RelDest := FilePath;
  StringChangeEx(RelDest, '/', '\', True);
  Result := AddOnlineFile(ServerDir + FilePath, GameKey + '\' + RelDest);
end;

// NeoEE setups install the NeoEE version of a localized file where there is one, like [Files]
// does with the local files (the NeoEE entries come last and overwrite the EE ones); otherwise,
// and in EE setups, the EE version
procedure AddLocalizedGameOnlineFile(const ServerDir, NeoEEServerDir, GameKey, FilePath: String);
begin
#if InstallType == "NeoEE"
  if AddGameOnlineFile(NeoEEServerDir, GameKey, FilePath) then
    Exit;
#endif
  AddGameOnlineFile(ServerDir, GameKey, FilePath);
end;

// Registers the localized files of one game for the language folder LangCode: GameKey (EE or
// AoC) is the game subfolder of the language folders, Campaigns are its campaign files and
// WithMovie adds the intro movie. The lobby resources are shared by EE and AoC on the servers
// (downloaded once and copied, see AddOnlineFile).
procedure RegisterGameOnlineFiles(const LangCode, GameKey: String; const Campaigns: array of String; WithMovie: Boolean);
var
  Game, Lobby, NeoLobby: String;
  I: Integer;
begin
  Game := 'Game/' + LangCode + '/' + GameKey + '/';
  Lobby := 'Lobby/' + LangCode + '/';
  NeoLobby := 'Mods/NeoEE/Lobby/' + LangCode + '/';

  AddLocalizedGameOnlineFile(Game, 'Mods/NeoEE/' + Game, GameKey, 'Language.dll');
  AddGameOnlineFile(Game, GameKey, 'Data/data.ssa');
  for I := 0 to GetArrayLength(Campaigns) - 1 do
    AddGameOnlineFile(Game, GameKey, 'Data/Campaigns/' + Campaigns[I]);
  if WithMovie then
    AddGameOnlineFile(Game, GameKey, 'Data/Movies/Empire Earth.bik');
  AddGameOnlineFile(Lobby + 'shared/', GameKey, 'Data/WONLobby Resources/_WONStatus.cfg');
  AddGameOnlineFile(Lobby + 'shared/', GameKey, 'Data/WONLobby Resources/_GameResource.cfg');
  AddGameOnlineFile(Lobby + 'shared/', GameKey, 'Data/WONLobby Resources/_LobbyResource.cfg');
  AddLocalizedGameOnlineFile(Lobby + GameKey + '/', NeoLobby + GameKey + '/', GameKey, 'WONLobby.cfg');
#if InstallType == "NeoEE"
  AddGameOnlineFile(NeoLobby + 'shared/', GameKey, 'Data/WONLobby Resources/_NeoEEResource.cfg');
#endif
end;

procedure RegisterOnlineFiles();
var
  LangCode: String;
begin
  // Register Online Files (the game files are English, the online files replace them with the
  // localized ones if asked)
  // Mirror Order
  // EE Community (Energy) => Zocker (SelectOnlineFilesServer starts with the mirror if only it answers)
  // Storage Localized structure : {base_url}/localized/{scope}/{language}/{GameType}/
  // Note: EELearningCampaign.ssa is the same for AoC, [Files] installs the one of EE for both
  // AddOnlineFile (downloads.iss) registers the file on both servers (same path on the mirror),
  // but only if its SHA-256 is known: every download is verified before it is installed.
  // Only selected content is registered: IDP downloads a file if any one of the components given
  // to it is selected, so 'game' (always selected) used to make every file download.

  // Clears files if the user have the bad idea of going back to component to change them
  Log('Clear download file list');
  ClearOnlineFiles();

  if (not WizardIsComponentSelected('language\update')) then
  begin
    Log('Download of localized files not selected, the setup will only use local files.');
    Exit;
  end;

  LangCode := GetLanguageTag(GetSelectedLanguageFromComponents());
  if (LangCode = 'en') then
  begin
    Log('English language selected, no need to download online files.');
    Exit;
  end;

  if (not HasDownloadPins()) then
  begin
    Log('This setup knows no SHA-256 of online files, it will only use local files.');
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
  RegisterGameOnlineFiles(LangCode, 'EE', ['EELearningCampaign.ssa', 'EETheBritish.ssa', 'EETheFuture.ssa',
    'EETheGermans.ssa', 'EETheGreeks.ssa'], WizardIsComponentSelected('additional\movies'));
  if (WizardIsComponentSelected('gameaoc')) then
    RegisterGameOnlineFiles(LangCode, 'AoC', ['AOCAsian.ssa', 'AOCPacific.ssa', 'AOCRoman.ssa'], False);
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

// Installation steps
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssInstall) then
  begin
    // Runs before [Files]: only downloads matching their SHA-256 are moved to {tmp}\verified
    VerifyDownloadedFiles();
    // Before [Files]: removes the maps the previous setup installed, remembers the player's own
    PrepareRandomMapScripts();
  end
  else if (CurStep = ssPostInstall) then
  begin
    FinishRandomMapScripts();
    if (IsAdminInstallMode and not IsWine()) then
    begin
      RemoveLegacyRunAsAdmin(ExpandConstant('{app}\{#EEExe}'));
      RemoveLegacyRunAsAdmin(ExpandConstant('{app}\{#AoCExe}'));
    end;
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

// Dispatches to the handler of the page; no page blocks the Next button
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  if (CurPageID = ManualInstallQuestionPage.ID) then
  begin
    if (not SilentInstall) then
      OnManualInstallPageNext();
  end
  else if (CurPageID = GPUInstallQuestionPage.ID) then
    ApplyGpuOption()
  else if (CurPageID = LanguageInstallQuestionPage.ID) then
    OnLanguagePageNext()
  else if (CurPageID = wpReady) then
    // The components are final now: register the downloads (IDP downloads after wpReady)
    RegisterOnlineFiles()
  else if (CurPageID = wpFinished) then
    OnFinishedPageNext();
  Result := True;
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
  // IDP download timeouts in milliseconds, per connection attempt and per network operation
  IdpConnectTimeoutMs = 15000;
  IdpTransferTimeoutMs = 30000;

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

// Download folders in {tmp} and IDP options of the online localized files (RegisterOnlineFiles)
procedure InitOnlineFilesDownload;
begin
  CreateDir(ExpandConstant('{tmp}\EE'));
  CreateDir(ExpandConstant('{tmp}\EE\Data'));
  CreateDir(ExpandConstant('{tmp}\EE\Data\Campaigns'));
  CreateDir(ExpandConstant('{tmp}\EE\Data\Movies'));
  CreateDir(ExpandConstant('{tmp}\EE\Data\WONLobby Resources'));
  CreateDir(ExpandConstant('{tmp}\AoC'));
  CreateDir(ExpandConstant('{tmp}\AoC\Data'));
  CreateDir(ExpandConstant('{tmp}\AoC\Data\Campaigns'));
  CreateDir(ExpandConstant('{tmp}\AoC\Data\WONLobby Resources'));

  idpSetOption('DetailedMode', '1');
  // Timeouts in milliseconds, per connection attempt and per network operation (not for a whole
  // file, so large files like the intro video are fine): 0.5 s used to make slow, mobile or VPN
  // connections fail. RegisterOnlineFiles only uses a server that answered.
  idpSetOption('ConnectTimeout', IntToStr(IdpConnectTimeoutMs));
  idpSetOption('SendTimeout', IntToStr(IdpTransferTimeoutMs));
  idpSetOption('ReceiveTimeout', IntToStr(IdpTransferTimeoutMs));
  idpSetOption('ErrorDialog', 'UrlList');
  // Never accept an invalid TLS certificate (the IDP default would let the user ignore it).
  // Downloads are also checked against their SHA-256 (downloads.iss).
  idpSetOption('InvalidCert', 'Stop');
  // Failed downloads can be skipped: VerifyDownloadedFiles reports every file that is missing then
  idpSetOption('AllowContinue', '1');

  idpDownloadAfter(wpReady);
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

  InitOnlineFilesDownload();
end;

procedure DeinitializeSetup;
begin
  if (not SilentInstall and not IsWine) then
  begin
    bassFree;
  end;
end;
