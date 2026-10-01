; ---------------------------------------
;        By EnergyCube 2020-2023
;      Empire Earth Community Setup
;     GNU General Public License v3.0
; ---------------------------------------
;   Reborn : discord.com/invite/BjUXbFB
; ---------------------------------------
; Don't change the UTF-8 BOM encoding!
; UTF-8 doesn't preserve all characters
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
;       a virus...). This certificate is not free because everyone knows that trust can be bought...
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
; When releasing a new MySetupVersion, it should be distribued for both EE & Neo
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
; Be very carefull to AppId, it's like the unique id of the setup, be sure to generate it with inno setup
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
; lzma2/max = 32mo of ram (noticed 42mo on W10 & XP)
; Since EE need 64mo (including Windows), lzma2/max is the maximum compression
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

; I have condemned myself forever to use this option...
; I don't need it at all but I didn't understand how ArchitecturesAllowed works
; So I had to use it to avoid regedit redirection in WOW6432Node on x64
; I should have used IsWin64 and HK[...]64 or not IsWin64 and HK[...]32
ArchitecturesInstallIn64BitMode=x64 arm64 ia64

; Warning for MinVersion < 6.1sp1
; From IS 6, Windows < 6.1sp1 has been disabled for security reasons.
; We can force it to support from Windows 6.0 (Vista) but that's *insecure*
; Keeping that security is okay I think, creating a legacy setup with IS 5
; would be the real solution for that problem since it's clearly 'legacy'
; MinVersion=6.0

; If for any reason, Setup is reported to be a virus uncomment this to crypt files...
; The setup will display the password when asked to the user :)
; Also the setup should work, remember that any ressources used befoare the password
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
Name: "full"; Description: "Full game install";
Name: "compact"; Description: "Compact game install";
Name: "custom"; Description: "Custom game install"; Flags: iscustom
Name: "raw"; Description: "Raw game install";

[Tasks]
Name: "compatibility"; Description: "Enable compatibility flags"; MinVersion: 0.0,5.1; Check: not IsWine
Name: "compatibility_windows"; Description: "Enable earlier Windows compatibility mode"; MinVersion: 0.0,5.1; Check: not IsWine
Name: "firewallexception"; Description: "{cm:TaskFirewall}"; MinVersion: 0.0,5.0; Check: IsAdminInstallMode and not IsWine
; GOG Setup install DirectPlay but i don't think it's really important... some kind of default install for old DX game maybe
Name: "directplay"; Description: "Install DirectPlay"; MinVersion: 6.2; Check: IsAdminInstallMode
Name: "dxwebsetup"; Description: "Install DirectX End-User Runtime"; MinVersion: 0.0,5.0; Check: IsAdminInstallMode and not IsWine; Components: additional\directx_wrapper\dx9 or not additional\directx_wrapper 
#if InstallType == "NeoEE"
  ; Since 1.0.1.0 NeoEE CDKeys support HKLM & HKCU
  Name: "neoee_cdkeys"; Description: "Register NeoEE CDKeys (Required to use the online lobby)"; MinVersion: 0.0,5.0;
#endif

#if CertInclude
  ; Opt-in, also for administrators: adds the community certificate to the trusted root
  ; certification authorities (all users in administrative install mode, else the current user)
  Name: "certinclude"; Description: "{cm:TaskCertInclude}"; MinVersion: 0.0,6.0; Flags: unchecked; Check: not IsWine
#endif

; Opt-in: the game (online lobby, maps and scenarios from other players) should not run elevated.
; Selected, it sets RUNASADMIN for all users (HKLM) and skips the write permissions below.
Name: "everyoneadminstart"; Description: "{cm:TaskAdminStart}"; MinVersion: 0.0,5.1; Flags: unchecked; Check: IsAdminInstallMode and not IsWine

#if InstallMode != "Portable"
  Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
  Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0.0,6.1
#endif

[Components]
Name: "game"; Description: "{#MyAppName}"; Types: full compact custom raw; Flags: fixed
; ------------------
Name: "gameaoc"; Description: "{#MyAppName} : The Art of Conquest"; Types: full
; ------------------

Name: "additional"; Description: "Additional Recommended Content"

Name: "additional\movies"; Description: "Install intro videos"; Flags: disablenouninstallwarning;

Name: "additional\hd"; Description: "HD/HQ Content"; Flags: disablenouninstallwarning; Types: full
Name: "additional\hd\terrain"; Description: "HD Terrain v1.0 (by Sleeper & Yukon)"; Types: full
Name: "additional\hd\music"; Description: "HQ Musics WIP (by Fortuking)"; Types: full
Name: "additional\hd\buildings"; Description: "HD Buildings Icons v3.0 (by Fortuking)"; Types: full;
Name: "additional\hd\tech"; Description: "HD Tech Icons v3.0.1 (by Fortuking)"; Types: full;
Name: "additional\hd\effects"; Description: "HD Effects WIP (by Fortuking)"; Types: full;

Name: "additional\drexmod"; Description: "dreXmod to enhance/add features (by Yukon)"
//#if InstallType == "EE" ; Prefer dxm2
//  Name: "additional\drexmod\v2"; Description: "dreXmod v2 for better Camera/HUD/Lobby "; Flags: exclusive disablenouninstallwarning; Types: full compact; MinVersion: 0,5.1
//  Name: "additional\drexmod\v3"; Description: "dreXmod v3 for better Camera/HUD/Lobby/Ranking/AntiCheat"; Flags: exclusive disablenouninstallwarning; MinVersion: 0,5.1
//#elif InstallType == "NeoEE" ; Prefer dxm3
  Name: "additional\drexmod\v3"; Description: "dreXmod v3 for better Camera/HUD/Lobby/Ranking/AntiCheat"; Flags: exclusive disablenouninstallwarning; Types: full compact; MinVersion: 0,5.1
  Name: "additional\drexmod\v2"; Description: "dreXmod v2 for better Camera/HUD/Lobby"; Flags: exclusive disablenouninstallwarning; MinVersion: 0,5.1
//#endif

; Name: "additional\reborn"; Description: "Reborn.dll v0.1 for better Camera, Resolution and Solo Max Units"; Flags: disablenouninstallwarning; Types: full compact; MinVersion: 0,5.1 
#if InstallType == "EE"
  Name: "additional\rms"; Description: "Random Map Scripts";
  Name: "additional\rms\omega"; Description: "Omega Pack";
  Name: "additional\rms\neoextra"; Description: "NeoEE Extra";
#endif

Name: "additional\directx_wrapper"; Description: "DirectX Wrapper"; Flags: disablenouninstallwarning; MinVersion: 0.0,6.1
Name: "additional\directx_wrapper\dx7"; Description: "DirectX 7 [Lightest]"; Flags: exclusive disablenouninstallwarning; MinVersion: 0.0,6.1
Name: "additional\directx_wrapper\dx9"; Description: "DirectX 9 [Most Compatible]"; Flags: exclusive disablenouninstallwarning; MinVersion: 0.0,6.1
Name: "additional\directx_wrapper\dx11_lvl10"; Description: "DirectX 11 API lvl 10 v2.82.1"; Flags: exclusive disablenouninstallwarning; MinVersion: 0.0,6.1
Name: "additional\directx_wrapper\dx11_lvl10_1"; Description: "DirectX 11 API lvl 10.1 v2.82.1"; Flags: exclusive disablenouninstallwarning; MinVersion: 0.0,6.1
Name: "additional\directx_wrapper\dx11_lvl11"; Description: "DirectX 11 API lvl 11 v2.82.1 [Generally Recommended]"; Flags: exclusive disablenouninstallwarning; MinVersion: 0.0,6.1
Name: "additional\directx_wrapper\dx12_lvl11"; Description: "DirectX 12 API lvl 11 v2.82.1 [Experimental]"; Flags: exclusive disablenouninstallwarning; MinVersion: 0.0,10;
Name: "additional\directx_wrapper\dx12_lvl12"; Description: "DirectX 12 API lvl 12 v2.82.1 [Experimental]"; Flags: exclusive disablenouninstallwarning; MinVersion: 0.0,10;

Name: "additional\telemetry"; Description: "Telemetry (Compatibility and Stats)"; Flags: disablenouninstallwarning; MinVersion: 0.0,6.1
Name: "additional\discord"; Description: "Discord Presence"; Flags: disablenouninstallwarning; Types: full compact; MinVersion: 0.0,6.1; Check: not IsWine
Name: "additional\tools"; Description: "Tools";
Name: "additional\tools\diagnostic"; Description: "Empire Earth Diagnostic"; Flags: disablenouninstallwarning; Types: full compact; MinVersion: 0.0,6.1; Check: not IsWine
Name: "additional\civs"; Description: "Civilizations"
Name: "additional\civs\ec"; Description: "eC Standard Civilizations (25)"; Types: full compact
Name: "additional\civs\ec_full"; Description: "eC Full Civilizations (71)"; Types: full

Name: "language"; Description: "Game Language"; Types: full compact custom raw; Flags: disablenouninstallwarning fixed;
Name: "language\de"; Description: "{cm:LIQP_de}"; Flags: exclusive;
Name: "language\en"; Description: "{cm:LIQP_en}"; Flags: exclusive;
Name: "language\es"; Description: "{cm:LIQP_es}"; Flags: exclusive;
Name: "language\fr"; Description: "{cm:LIQP_fr}"; Flags: exclusive;
Name: "language\it"; Description: "{cm:LIQP_it}"; Flags: exclusive;
Name: "language\ko"; Description: "{cm:LIQP_ko}"; Flags: exclusive;
Name: "language\pl"; Description: "{cm:LIQP_pl}"; Flags: exclusive;
Name: "language\pt_BR"; Description: "{cm:LIQP_pt_BR}"; Flags: exclusive;
Name: "language\ru"; Description: "{cm:LIQP_ru}"; Flags: exclusive;
Name: "language\zh_CN"; Description: "{cm:LIQP_zh_CN}"; Flags: exclusive;
Name: "language\zh_TW"; Description: "{cm:LIQP_zh_TW}"; Flags: exclusive;
Name: "language\update"; Description: "Download localized voices and campaigns"; Types: full compact custom raw; Flags: disablenouninstallwarning;

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
; For future ? signonce/sign
#if CertInclude
  Source: "internal\misc\{#CertFileName}"; DestDir: "{tmp}"; DestName: "{#CertFileName}"; Flags: deleteafterinstall; Tasks: certinclude;
#endif

;Source: "data\Add-on\DLLs\EEStats\EEStats.dll"; Flags: dontcopy noencryption nocompression; MinVersion: 0.0,6.1
Source: "data\Add-on\DLLs\EEStats\EEStatsSetup.dll"; DestDir: "{app}\{#SetupDataDir}"; Flags: noencryption nocompression ignoreversion recursesubdirs createallsubdirs; MinVersion: 0.0,5.1

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
;Source: "data\Empire Earth Base\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game;
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

; EE Lang Game Based Content
Source: "data\localized-text\Game\de\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\de
Source: "data\localized-text\Game\en\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\en
Source: "data\localized-text\Game\es\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\es
Source: "data\localized-text\Game\fr\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\fr
Source: "data\localized-text\Game\it\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\it
Source: "data\localized-text\Game\ko\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ko
Source: "data\localized-text\Game\pl\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pl
Source: "data\localized-text\Game\pt-BR\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pt_BR
Source: "data\localized-text\Game\ru\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ru
Source: "data\localized-text\Game\zh-CN\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\zh_CN
Source: "data\localized-text\Game\zh-TW\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\zh_TW

; EE Lang Lobby Based Content
Source: "data\localized-text\Lobby\de\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\de
Source: "data\localized-text\Lobby\en\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\en
Source: "data\localized-text\Lobby\es\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\es
Source: "data\localized-text\Lobby\fr\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\fr
Source: "data\localized-text\Lobby\it\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\it
Source: "data\localized-text\Lobby\ko\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ko
Source: "data\localized-text\Lobby\pl\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pl
Source: "data\localized-text\Lobby\pt-BR\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pt_BR
Source: "data\localized-text\Lobby\ru\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ru
Source: "data\localized-text\Lobby\zh\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and (language\zh_CN or language\zh_TW)

Source: "data\localized-text\Lobby\de\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\de
Source: "data\localized-text\Lobby\en\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\en
Source: "data\localized-text\Lobby\es\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\es
Source: "data\localized-text\Lobby\fr\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\fr
Source: "data\localized-text\Lobby\it\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\it
Source: "data\localized-text\Lobby\ko\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ko
Source: "data\localized-text\Lobby\pl\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pl
Source: "data\localized-text\Lobby\pt-BR\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pt_BR
Source: "data\localized-text\Lobby\ru\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ru
Source: "data\localized-text\Lobby\zh\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and (language\zh_CN or language\zh_TW)


#if InstallType == "NeoEE"
  ; NeoEE Lang Lobby Based Content
  Source: "data\localized-text\Mods\NeoEE\Game\de\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\de
  Source: "data\localized-text\Mods\NeoEE\Game\en\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\en
  Source: "data\localized-text\Mods\NeoEE\Game\es\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\es
  Source: "data\localized-text\Mods\NeoEE\Game\fr\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\fr
  Source: "data\localized-text\Mods\NeoEE\Game\it\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\it
  Source: "data\localized-text\Mods\NeoEE\Game\ko\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ko
  Source: "data\localized-text\Mods\NeoEE\Game\pl\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pl
  Source: "data\localized-text\Mods\NeoEE\Game\pt-BR\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pt_BR
  Source: "data\localized-text\Mods\NeoEE\Game\ru\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ru
  Source: "data\localized-text\Mods\NeoEE\Game\zh-CN\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\zh_CN
  Source: "data\localized-text\Mods\NeoEE\Game\zh-TW\EE\Language.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\zh_TW

  Source: "data\localized-text\Mods\NeoEE\Lobby\de\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\de
  Source: "data\localized-text\Mods\NeoEE\Lobby\en\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\en
  Source: "data\localized-text\Mods\NeoEE\Lobby\es\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\es
  Source: "data\localized-text\Mods\NeoEE\Lobby\fr\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\fr
  Source: "data\localized-text\Mods\NeoEE\Lobby\it\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\it
  Source: "data\localized-text\Mods\NeoEE\Lobby\ko\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ko
  Source: "data\localized-text\Mods\NeoEE\Lobby\pl\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pl
  Source: "data\localized-text\Mods\NeoEE\Lobby\pt-BR\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pt_BR
  Source: "data\localized-text\Mods\NeoEE\Lobby\ru\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ru
  Source: "data\localized-text\Mods\NeoEE\Lobby\zh\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and (language\zh_CN or language\zh_TW)

  Source: "data\localized-text\Mods\NeoEE\Lobby\de\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\de
  Source: "data\localized-text\Mods\NeoEE\Lobby\en\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\en
  Source: "data\localized-text\Mods\NeoEE\Lobby\es\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\es
  Source: "data\localized-text\Mods\NeoEE\Lobby\fr\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\fr
  Source: "data\localized-text\Mods\NeoEE\Lobby\it\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\it
  Source: "data\localized-text\Mods\NeoEE\Lobby\ko\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ko
  Source: "data\localized-text\Mods\NeoEE\Lobby\pl\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pl
  Source: "data\localized-text\Mods\NeoEE\Lobby\pt-BR\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\pt_BR
  Source: "data\localized-text\Mods\NeoEE\Lobby\ru\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and language\ru
  Source: "data\localized-text\Mods\NeoEE\Lobby\zh\shared\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: game and (language\zh_CN or language\zh_TW)
#endif

; EE Online Lang Any Based Content (only downloads that passed the SHA-256 check, see downloads.iss)
Source: "{tmp}\verified\EE\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs external skipifsourcedoesntexist; Components: game and language\update;

; DreXmod 2 (+privacy patched dll, because nothing allow to disable it in config)
Source: "data\Add-on\DLLs\dreXmod\2\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and game;
Source: "data\Add-on\DLLs\dreXmod\2_privacy\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and game and not additional\telemetry;

; DreXmod 3 (+privacy config)
Source: "data\Add-on\DLLs\dreXmod\3\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and game;
Source: "data\Add-on\DLLs\dreXmod\3_privacy\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and game and not additional\telemetry;

; RMS
#if InstallType == "EE"
  ; Omega
  Source: "data\Add-on\RMS\Omega\EE\*"; DestDir: "{app}\{#EEDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\omega and game
  Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#EEDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\neoextra and game
#endif

; dgVoodoo  Bin
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_bin\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper and game and not additional\directx_wrapper\dx9 and not additional\directx_wrapper\dx7
Source: "data\\Add-on\DirectX_Wrapper\GOG\DDraw.dll"; DestDir: "{app}\{#EEDir}"; DestName: "DDraw.dll"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx9 and game;
Source: "data\\Add-on\DirectX_Wrapper\DDrawCompat\DDraw.dll"; DestDir: "{app}\{#EEDir}"; DestName: "DDraw.dll"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx7 and game;
; dgVoodoo Conf
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10.conf"; DestDir: "{app}\{#EEDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10 and game;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10_1.conf"; DestDir: "{app}\{#EEDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10_1 and game;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL11.conf"; DestDir: "{app}\{#EEDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl11 and game;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL11.conf"; DestDir: "{app}\{#EEDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl11 and game;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL12.conf"; DestDir: "{app}\{#EEDir}"; DestName: "dgVoodoo.conf"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl12 and game;

; Civs
Source: "data\Add-on\Civs\eC\*"; DestDir: "{app}\{#EEDir}\Users\default\Civilizations"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec and game
Source: "data\Add-on\Civs\eC_full\*"; DestDir: "{app}\{#EEDir}\Users\default\Civilizations"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec_full and game

; Discord
Source: "data\Add-on\DLLs\Discord\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\discord and game

; Reborn.dll
; Source: "data\Add-on\DLLs\Reborn\*"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\reborn and game


; EEStats
Source: "data\Add-on\DLLs\EEStats\EEStats.dll"; DestDir: "{app}\{#EEDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\telemetry and game; MinVersion: 0.0,6.1

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
;Source: "data\Empire Earth Base\shared\*"; DestDir: "{app}\{#AoCDir}"; \
;  Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc;
; EE Movies
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
  ; Already done in EE part Source: authtools.exe
  Source: "data\NeoEE - CDKeys\_wonkver.pub"; DestDir: "{app}\{#AoCDir}"; \
    Flags: deleteafterinstall ignoreversion recursesubdirs createallsubdirs; Components: gameaoc
  ; NeoEE - Wine Fix (GDI)
  Source: "data\NeoEE - Wine\NeoEE.cfg"; DestDir: "{app}\{#AoCDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc; Check: IsWine
#endif

; EE Lang Game Based Content
Source: "data\localized-text\Game\de\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\de
Source: "data\localized-text\Game\en\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\en
Source: "data\localized-text\Game\es\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\es
Source: "data\localized-text\Game\fr\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\fr
Source: "data\localized-text\Game\it\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\it
Source: "data\localized-text\Game\ko\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ko
Source: "data\localized-text\Game\pl\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pl
Source: "data\localized-text\Game\pt-BR\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pt_BR
Source: "data\localized-text\Game\ru\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ru
Source: "data\localized-text\Game\zh-CN\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\zh_CN
Source: "data\localized-text\Game\zh-TW\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\zh_TW

; EE Lang Lobby Based Content
Source: "data\localized-text\Lobby\de\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\de
Source: "data\localized-text\Lobby\en\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\en
Source: "data\localized-text\Lobby\es\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\es
Source: "data\localized-text\Lobby\fr\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\fr
Source: "data\localized-text\Lobby\it\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\it
Source: "data\localized-text\Lobby\ko\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ko
Source: "data\localized-text\Lobby\pl\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pl
Source: "data\localized-text\Lobby\pt-BR\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pt_BR
Source: "data\localized-text\Lobby\ru\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ru
Source: "data\localized-text\Lobby\zh\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and (language\zh_CN or language\zh_TW)

Source: "data\localized-text\Lobby\de\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\de
Source: "data\localized-text\Lobby\en\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\en
Source: "data\localized-text\Lobby\es\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\es
Source: "data\localized-text\Lobby\fr\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\fr
Source: "data\localized-text\Lobby\it\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\it
Source: "data\localized-text\Lobby\ko\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ko
Source: "data\localized-text\Lobby\pl\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pl
Source: "data\localized-text\Lobby\pt-BR\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pt_BR
Source: "data\localized-text\Lobby\ru\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ru
Source: "data\localized-text\Lobby\zh\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and (language\zh_CN or language\zh_TW)

#if InstallType == "NeoEE"
  ; NeoEE Lang Lobby Based Content
  Source: "data\localized-text\Mods\NeoEE\Game\de\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\de
  Source: "data\localized-text\Mods\NeoEE\Game\en\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\en
  Source: "data\localized-text\Mods\NeoEE\Game\es\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\es
  Source: "data\localized-text\Mods\NeoEE\Game\fr\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\fr
  Source: "data\localized-text\Mods\NeoEE\Game\it\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\it
  Source: "data\localized-text\Mods\NeoEE\Game\ko\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ko
  Source: "data\localized-text\Mods\NeoEE\Game\pl\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pl
  Source: "data\localized-text\Mods\NeoEE\Game\pt-BR\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pt_BR
  Source: "data\localized-text\Mods\NeoEE\Game\ru\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ru
  Source: "data\localized-text\Mods\NeoEE\Game\zh-CN\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\zh_CN
  Source: "data\localized-text\Mods\NeoEE\Game\zh-TW\AoC\Language.dll"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\zh_TW

  Source: "data\localized-text\Mods\NeoEE\Lobby\de\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\de
  Source: "data\localized-text\Mods\NeoEE\Lobby\en\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\en
  Source: "data\localized-text\Mods\NeoEE\Lobby\es\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\es
  Source: "data\localized-text\Mods\NeoEE\Lobby\fr\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\fr
  Source: "data\localized-text\Mods\NeoEE\Lobby\it\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\it
  Source: "data\localized-text\Mods\NeoEE\Lobby\ko\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ko
  Source: "data\localized-text\Mods\NeoEE\Lobby\pl\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pl
  Source: "data\localized-text\Mods\NeoEE\Lobby\pt-BR\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pt_BR
  Source: "data\localized-text\Mods\NeoEE\Lobby\ru\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ru
  Source: "data\localized-text\Mods\NeoEE\Lobby\zh\AoC\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and (language\zh_CN or language\zh_TW)

  Source: "data\localized-text\Mods\NeoEE\Lobby\de\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\de
  Source: "data\localized-text\Mods\NeoEE\Lobby\en\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\en
  Source: "data\localized-text\Mods\NeoEE\Lobby\es\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\es
  Source: "data\localized-text\Mods\NeoEE\Lobby\fr\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\fr
  Source: "data\localized-text\Mods\NeoEE\Lobby\it\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\it
  Source: "data\localized-text\Mods\NeoEE\Lobby\ko\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ko
  Source: "data\localized-text\Mods\NeoEE\Lobby\pl\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pl
  Source: "data\localized-text\Mods\NeoEE\Lobby\pt-BR\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\pt_BR
  Source: "data\localized-text\Mods\NeoEE\Lobby\ru\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and language\ru
  Source: "data\localized-text\Mods\NeoEE\Lobby\zh\shared\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: gameaoc and (language\zh_CN or language\zh_TW)
#endif

; skipifsourcedoesntexist: {tmp}\verified\AoC is empty when nothing was downloaded for AoC (English,
; download not selected or failed), which Setup would otherwise report as a missing source file
Source: "{tmp}\verified\AoC\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs external skipifsourcedoesntexist; Components: gameaoc and language\update
; AoC uses the learning campaign of EE (see RegisterOnlineFiles)
Source: "{tmp}\verified\EE\Data\Campaigns\EELearningCampaign.ssa"; DestDir: "{app}\{#AoCDir}\Data\Campaigns"; \
  Flags: ignoreversion recursesubdirs createallsubdirs external skipifsourcedoesntexist; Components: gameaoc and language\update

  ; DreXmod 2 (+privacy patched dll, because nothing allow to disable it in config)
Source: "data\Add-on\DLLs\dreXmod\2\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and gameaoc;
Source: "data\Add-on\DLLs\dreXmod\2_privacy\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v2 and gameaoc and not additional\telemetry;

; DreXmod 3 (+privacy config)
Source: "data\Add-on\DLLs\dreXmod\3\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and gameaoc;
Source: "data\Add-on\DLLs\dreXmod\3_privacy\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\drexmod\v3 and gameaoc and not additional\telemetry;

; RMS
#if InstallType == "EE"
  ; Omega
  Source: "data\Add-on\RMS\Omega\AoC\*"; DestDir: "{app}\{#AoCDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\omega and gameaoc
  Source: "data\Add-on\RMS\NeoExtra\*"; DestDir: "{app}\{#AoCDir}\{#RmsSubDir}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\rms\neoextra and gameaoc
#endif

; dgVoodoo  Bin
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_bin\*"; DestDir: "{app}\{#AoCDir}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper and gameaoc and not additional\directx_wrapper\dx9 and not additional\directx_wrapper\dx7
Source: "data\\Add-on\DirectX_Wrapper\GOG\DDraw.dll"; DestDir: "{app}\{#AoCDir}"; DestName: "DDraw.dll"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx9 and gameaoc;
Source: "data\\Add-on\DirectX_Wrapper\DDrawCompat\DDraw.dll"; DestDir: "{app}\{#AoCDir}"; DestName: "DDraw.dll"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx7 and gameaoc;
; dgVoodoo Conf
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10.conf"; DestDir: "{app}\{#AoCDir}"; DestName: "dgVoodoo.conf"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10 and gameaoc;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL10_1.conf"; DestDir: "{app}\{#AoCDir}"; DestName: "dgVoodoo.conf"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl10_1 and gameaoc;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX11_LVL11.conf"; DestDir: "{app}\{#AoCDir}"; DestName: "dgVoodoo.conf"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx11_lvl11 and gameaoc;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL11.conf"; DestDir: "{app}\{#AoCDir}"; DestName: "dgVoodoo.conf"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl11 and gameaoc;
Source: "data\Add-on\DirectX_Wrapper\dgVoodoo_conf\dgVoodoo_DX12_LVL12.conf"; DestDir: "{app}\{#AoCDir}"; DestName: "dgVoodoo.conf"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\directx_wrapper\dx12_lvl12 and gameaoc;

; Civs
Source: "data\Add-on\Civs\eC\*"; DestDir: "{app}\{#AoCDir}\Users\default\Civilizations"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec and gameaoc
Source: "data\Add-on\Civs\eC_full\*"; DestDir: "{app}\{#AoCDir}\Users\default\Civilizations"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\civs\ec_full and gameaoc

; Discord
Source: "data\Add-on\DLLs\Discord\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\discord and gameaoc

; Reborn.dll
; Not supported Source: "data\Add-on\DLLs\Reborn\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\reborn and gameaoc

; EEStats
; Not supported Source: "data\Add-on\DLLs\EEStats\*"; DestDir: "{app}\{#AoCDir}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: additional\telemetry and gameaoc; MinVersion: 0.0,6.1

; HD & Music & Tech & Building
; Herit from EE natively

; -------------------
;  Allow config edit, move the files to the exact same dir but with good perm :>
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
;   WIN7RTM    DWM8And16BitMitigation    for Windows 8+ (MinVersion: 0.0,6.2)
;   WINXPSP3   DWM8And16BitMitigation    for Windows Vista/7 (OnlyBelowVersion: 0.0,6.2)
; Version filters: in "0.0,6.2" Inno Setup 6 ignores the part before the comma, so it means
; Windows NT 6.2 (= Windows 8). A value without comma like "0.6.2" would mean version 0.6 build 2.
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

; Windows 10+ GPU auto selection (apparently no HKLM... ty ms...)
Root: "HKCU"; Subkey: "Software\Microsoft\DirectX\UserGpuPreferences"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "GpuPreference=2;"; \
  Flags: uninsdeletevalue; MinVersion: 0.0,10; Tasks: compatibility_windows; Components: game
Root: "HKCU"; Subkey: "Software\Microsoft\DirectX\UserGpuPreferences"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "GpuPreference=2;"; \
  Flags: uninsdeletevalue; MinVersion: 0.0,10; Tasks: compatibility_windows; Components:  gameaoc

; Admin + Windows compatibility
; Windows >=8
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags} WIN7RTM"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: compatibility_windows; Components: game
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags} WIN7RTM"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: compatibility_windows; Components: gameaoc
; Windows >=Vista & <= 7
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags} WINXPSP3"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: compatibility_windows; Components: game
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags} WINXPSP3"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: compatibility_windows; Components: gameaoc

; Admin - Windows compatibility
; Windows >=8
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: game
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: gameaoc
; Windows >=Vista & <= 7
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: game
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: gameaoc

; Admin, RUNASADMIN only (opt-in task everyoneadminstart without the compatibility tasks)
; Setups up to v1.7.2 also set "~ RUNASADMIN" in HKCU for the installing account by default;
; CurStepChanged removes that old value (RemoveLegacyRunAsAdmin).
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; Tasks: everyoneadminstart and not compatibility_windows and not compatibility; Components: game
Root: "HKLM"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: IsAdminInstallMode; Tasks: everyoneadminstart and not compatibility_windows and not compatibility; Components: gameaoc

; ---------

; User + Windows compatibility
; Windows >=8
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags} WIN7RTM"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: compatibility_windows and compatibility; Components: game
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags} WIN7RTM"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: compatibility_windows and compatibility; Components: gameaoc
; Windows >=Vista & <= 7
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags} WINXPSP3"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: compatibility_windows and compatibility; Components: game
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags} WINXPSP3"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: compatibility_windows and compatibility; Components: gameaoc

; User - Windows compatibility
; Windows >=8
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: game
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: gameaoc
; Windows >=Vista & <= 7
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#EEExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: game
Root: "HKCU"; Subkey: "{#BaseRegCompatibility}"; ValueType: String; ValueName: "{app}\{#AoCExe}"; ValueData: "{code:GetCompatibilityFlags}"; \
  Flags: uninsdeletevalue; Check: not IsAdminInstallMode; MinVersion: 0.0,6.0; OnlyBelowVersion: 0.0,6.2; Tasks: not compatibility_windows and compatibility; Components: gameaoc

; Game Settings
Root: "HKCU"; Subkey: "{#BaseRegEE}"; Flags: uninsdeletekey; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D Hardware TnL"; Flags: deletevalue; Components: game and not additional\directx_wrapper; Check: not IsWine
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D"; Flags: deletevalue; Components: game and additional\directx_wrapper; Check: not IsWine
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D"; Flags: deletevalue; Components: game; Check: IsWine
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Wait for VSync"; ValueData: "$0"; Flags: deletevalue; Components: game;
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "AutoSave In Milliseconds"; ValueData: "$124F80"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: String; ValueName: "Map Type"; ValueData: "Continental"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Map Size"; ValueData: "$2"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Starting Resources"; ValueData: "$3"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Starting Epoch"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Ending Epoch"; ValueData: "$D"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Game Unit Limit"; ValueData: "$4B0"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Wonders For Victory"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Game Variant"; ValueData: "$2"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Difficulty Level"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Game Speed"; ValueData: "$3"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Reveal Map"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Allow Custom Civs"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Lock Teams"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Lock Speed"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}\Game Options"; ValueType: Dword; ValueName: "Cheat Codes"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Music Volume"; ValueData: "$2C"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Sound Volume"; ValueData: "$3C"; Flags: createvalueifdoesntexist; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Take JPG Screenshots"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: game
; Set Default 1920x1080 32 bits
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Game Window Height"; ValueData: "{code:GetScreenResolutionHeight}"; Flags: deletevalue; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Game Window Width"; ValueData: "{code:GetScreenResolutionWidth}"; Flags: deletevalue; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Game Bit Depth"; ValueData: "$20"; Flags: deletevalue; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: Dword; ValueName: "Texture Bit Depth"; ValueData: "$20"; Flags: deletevalue; Components: game
; Adding Installed From to allow AoC to be started without having to start EE first.
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: string; ValueName: "Installed From Volume"; ValueData: "{code:GetInstallDriveLetter}"; Flags: deletevalue; Components: game
Root: "HKCU"; Subkey: "{#BaseRegEE}"; ValueType: string; ValueName: "Installed From Directory"; ValueData: "{code:GetInstallWithoutDriveLetterBase}\{#EEDir}\"; Flags: deletevalue; Components: game

; ----------------

Root: "HKCU"; Subkey: "{#BaseRegAoC}"; Flags: uninsdeletekey; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D Hardware TnL"; Flags: deletevalue; Components: gameaoc and not additional\directx_wrapper; Check: not IsWine
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D"; Flags: deletevalue; Components: gameaoc and additional\directx_wrapper; Check: not IsWine
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: String; ValueName: "Rasterizer Name"; ValueData: "Direct3D"; Flags: deletevalue; Components: gameaoc; Check: IsWine
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Wait for VSync"; ValueData: "$0"; Flags: deletevalue; Components: gameaoc;
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "AutoSave In Milliseconds"; ValueData: "$124F80"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: String; ValueName: "Map Type"; ValueData: "Continental"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Map Size"; ValueData: "$2"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Starting Resources"; ValueData: "$3"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Starting Epoch"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Ending Epoch"; ValueData: "$E"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Game Unit Limit"; ValueData: "$4B0"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Wonders For Victory"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Game Variant"; ValueData: "$2"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Difficulty Level"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Game Speed"; ValueData: "$3"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Reveal Map"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Allow Custom Civs"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Lock Teams"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Lock Speed"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}\Game Options"; ValueType: Dword; ValueName: "Cheat Codes"; ValueData: "$0"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Music Volume"; ValueData: "$2C"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Sound Volume"; ValueData: "$3C"; Flags: createvalueifdoesntexist; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Take JPG Screenshots"; ValueData: "$1"; Flags: createvalueifdoesntexist; Components: gameaoc
; Set Default 1920x1080 32 bits (Note : if Texture Bit Depth != Game Bit Depth, the main menu is just white and unreadable)
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Game Window Height"; ValueData: "{code:GetScreenResolutionHeight}"; Flags: deletevalue; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Game Window Width"; ValueData: "{code:GetScreenResolutionWidth}"; Flags: deletevalue; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Game Bit Depth"; ValueData: "$20"; Flags: deletevalue; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: Dword; ValueName: "Texture Bit Depth"; ValueData: "$20"; Flags: deletevalue; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: string; ValueName: "Installed From Volume"; ValueData: "{code:GetInstallDriveLetter}"; Flags: deletevalue; Components: gameaoc
Root: "HKCU"; Subkey: "{#BaseRegAoC}"; ValueType: string; ValueName: "Installed From Directory"; ValueData: "{code:GetInstallWithoutDriveLetterBase}\{#AoCDir}\"; Flags: deletevalue; Components: gameaoc

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
Type: files; Name: "{app}\{#EEDir}\upnp_info.txt"
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
Type: files; Name: "{app}\{#AoCDir}\upnp_info.txt"
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
    StatusMsg: "Adding Empire Earth Community Certificate Authority (issued by EnergyCube)"; MinVersion: 0,6.0; Components: game; Check: IsAdminInstallMode and IsCertificateFileGenuine
  Filename: "{sys}\certutil.exe"; Parameters: "-user -addstore root ""{tmp}\{#CertFileName}"""; Flags: runhidden; Tasks: certinclude; \
    StatusMsg: "Adding Empire Earth Community Certificate Authority (issued by EnergyCube)"; MinVersion: 0,6.0; Components: game; Check: not IsAdminInstallMode and IsCertificateFileGenuine
#endif

; Install DirectPlay (Never tested on x86) ({sys}\dism.exe should work)
; Disabled because seems useless
Filename: "{sys}\dism.exe"; Parameters: "/Online /Enable-Feature /FeatureName:""DirectPlay"" /all /NoRestart"; Flags: runhidden; StatusMsg: "Installing DirectPlay"; \
  MinVersion: 0,6.2; Tasks: directplay; Check: Is64BitInstallMode and IsAdminInstallMode
Filename: "{sys}\dism.exe"; Parameters: "/Online /Enable-Feature /FeatureName:""DirectPlay"" /all /NoRestart"; Flags: runhidden; StatusMsg: "Installing DirectPlay"; \
  MinVersion: 0,6.2; Tasks: directplay; Check: not Is64BitInstallMode and IsAdminInstallMode

; FireWall Remover (Copy from [UninstallRun] to remove previous entry in case it was missconfigured)
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule program=""{app}\{#EEExe}"" name=all"; Flags: runhidden; \
  StatusMsg: "Removing {#MyAppName} in Firewall"; Tasks: firewallexception; MinVersion: 0,6.0; Components: game; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule program=""{app}\{#AoCExe}"" name=all"; Flags: runhidden; \
  StatusMsg: "Removing {#MyAppName} : AoC in Firewall"; Tasks: firewallexception; MinVersion: 0,6.0; Components: gameaoc; Check: IsAdminInstallMode

; FireWall Register
; Allow rules scoped to the game programs (Empire Earth.exe, EE-AOC.exe): TCP and UDP, in and out,
; all local ports, all network profiles. profile=any is the netsh default and written out on
; purpose: hosting LAN and online games needs incoming connections on networks Windows classifies
; as "Public" too, so the rules are deliberately not limited to private networks. The rules only
; apply while the game runs, like the ones the Windows Firewall prompt offers; the task
; firewallexception can be unchecked.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - TCP - Out"" program=""{app}\{#EEExe}"" protocol=TCP dir=out action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception;StatusMsg: "Opening Empire Earth in Firewall"; MinVersion: 0,6.0; Components: game; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - TCP - In"" program=""{app}\{#EEExe}"" protocol=TCP dir=in action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "Opening Empire Earth in Firewall"; MinVersion: 0,6.0; Components: game; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - UDP - Out"" program=""{app}\{#EEExe}"" protocol=UDP dir=out action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "Opening Empire Earth in Firewall"; MinVersion: 0,6.0; Components: game; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - UDP - In"" program=""{app}\{#EEExe}"" protocol=UDP dir=in action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "Opening Empire Earth in Firewall"; MinVersion: 0,6.0; Components: game; Check: IsAdminInstallMode

Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - AoC - TCP - Out"" program=""{app}\{#AoCExe}"" protocol=TCP dir=out action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "Opening Empire Earth : AoC in Firewall"; MinVersion: 0,6.0; Components: gameaoc; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - AoC - TCP - In"" program=""{app}\{#AoCExe}"" protocol=TCP dir=in action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "Opening Empire Earth : AoC in Firewall"; MinVersion: 0,6.0; Components: gameaoc; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - AoC - UDP - Out"" program=""{app}\{#AoCExe}"" protocol=UDP dir=out action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "Opening Empire Earth : AoC in Firewall"; MinVersion: 0,6.0; Components: gameaoc; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} - AoC - UDP - In"" program=""{app}\{#AoCExe}"" protocol=UDP dir=in action=allow enable=yes profile=any localport=any"; \
  Flags: runhidden; Tasks: firewallexception; StatusMsg: "Opening Empire Earth : AoC in Firewall"; MinVersion: 0,6.0; Components: gameaoc; Check: IsAdminInstallMode

; DX9/10/11 End-User Runtime Setup
Filename: "{tmp}\directx\dxwebsetup.exe"; Parameters: "/Q"; Flags: runhidden; Tasks: dxwebsetup; \
    StatusMsg: "Installing legacy DirectX End-User Runtime..."; MinVersion: 0,5.0; Check: IsAdminInstallMode and not IsWine

; NeoEE CD keys (task neoee_cdkeys) are registered by CurStepChanged(ssPostInstall), which runs after
; all [Run] entries

[UninstallRun]
; Uninstall DirectPlay
; No DirectPlay uninstallation because it could possibly break some other games that still use it.
; Filename: "{sys}\dism.exe"; Parameters: "/Online /Disable-Feature /FeatureName:""DirectPlay"" /NoRestart"; Flags: runhidden; \
;  StatusMsg: "Uninstalling DirectPlay"; MinVersion: 0,6.2; Tasks: directplay; Check: Is64BitInstallMode and IsAdminInstallMode
;Filename: "{sys}\dism.exe"; Parameters: "/Online /Disable-Feature /FeatureName:""DirectPlay"" /NoRestart"; Flags: runhidden; \
;  StatusMsg: "Uninstalling DirectPlay"; MinVersion: 0,6.2; Tasks: directplay; Check: not Is64BitInstallMode and IsAdminInstallMode

; FireWall
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule program=""{app}\{#EEExe}"" name=all"; Flags: runhidden; \
  StatusMsg: "Removing {#MyAppName} in Firewall"; Tasks: firewallexception; MinVersion: 0,6.0; Components: game; Check: IsAdminInstallMode
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule program=""{app}\{#AoCExe}"" name=all"; Flags: runhidden; \
  StatusMsg: "Removing {#MyAppName} : AoC in Firewall"; Tasks: firewallexception; MinVersion: 0,6.0; Components: gameaoc; Check: IsAdminInstallMode

[Code]
// All requests use HTTPS with validated certificates and never fall back to HTTP: the answers
// decide what the (elevated) setup opens or installs.
const
  SetupURL = 'https://empireearth.eu/download';
  UpdateApiURL = 'https://api.empireearth.eu/setup/?product={#AppID}';
  DomainMain = 'empireearth.eu';
  DomainMirror = 'ee.zocker-160.de';

  function EEStats_runInVM: BOOL;
    external 'EEStats_runInVM@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getUID: PAnsiChar;
    external 'EEStats_getUID@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_isWine: BOOL;
    external 'EEStats_isWine@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getWineVersion: PAnsiChar;
    external 'EEStats_getWineVersion@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getProcessorArch: PAnsiChar;
    external 'EEStats_getProcessorArch@files:EEStatsSetup.dll cdecl setuponly';
  function EEStats_getGpuVendorId: PAnsiChar;
    external 'EEStats_getGpuVendorId@files:EEStatsSetup.dll cdecl setuponly';

#if InstallType == "NeoEE"
  // Closed-source NeoEE tool, see RegisterCDKeys. delayload: the DLL is only loaded when the keys
  // are registered, so a DLL removed by an anti-virus no longer stops the setup from starting.
  function generate_cdkeys(args: PAnsiChar; admin: BOOL): DWORD;
    external 'generate_cdkeys@files:authtools.dll cdecl setuponly delayload';
#endif

  // The uninstaller cannot use "files:" DLLs, it loads EEStatsSetup.dll from {app}\{#SetupDataDir}.
  // delayload: the DLL is only loaded when the function is called (IsWine catches a failure), so a
  // missing DLL cannot stop the uninstaller from starting. The current uninstall code never calls
  // it, so the elevated uninstaller does not load code from the installation folder.
  function EEStats_isWine_U: BOOL;
    external 'EEStats_isWine@{app}\{#SetupDataDir}\EEStatsSetup.dll cdecl uninstallonly delayload';

    // GetSystemMetrics
  function GetSystemMetrics(nIndex: Integer): Integer;
    external 'GetSystemMetrics@user32.dll stdcall';

var
  LanguageInstallQuestionPage: TInputOptionWizardPage;
  ManualInstallQuestionPage: TInputOptionWizardPage;
  GPUInstallQuestionPage: TInputOptionWizardPage;
  Langs: TStringList;
  IsUpdate: Boolean;
  IsInstalled: Boolean;
  ServersReacheable: Boolean;

#include "extention.iss"
#include "pages.iss"
#include "downloads.iss"
#include "randommaps.iss"

function GetCompatibilityFlags(Param: String): String;
begin
  Result :=  '~'

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

function IsWine(): Boolean;
begin
  if not IsUninstaller then
    Result := EEStats_IsWine()
  else
  begin
    try
      Result := EEStats_IsWine_U();
    except
      // EEStatsSetup.dll missing or not loadable (e.g. removed by an anti-virus): assume Windows
      Log('Unable to use EEStatsSetup.dll, assuming Windows: ' + GetExceptionMessage);
      Result := False;
    end;
  end;
end;

function GetInstallWithoutDriveLetterBase(Param: String): String;
begin
    Result := UpperCase(GetInstallWithoutDriveLetter(Param));
end;

function GetScreenResolutionHeight(Param: String): String;
var
  Tmp: Integer;
begin
  Tmp := GetSystemMetrics(1)
  if Tmp < 768 then
    Tmp := 768;
  if Tmp > 1080 then
    Tmp := 1080;
  Result := IntToStr(Tmp); 
end;

function GetScreenResolutionWidth(Param: String): String;
var
  Tmp: Integer;
begin
  Tmp := GetSystemMetrics(0)
  if Tmp < 1024 then
    Tmp := 1024;
  if Tmp > 1920 then
    Tmp := 1920;
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

// Latest version for the update question, '?' if the answer does not look like a version
function GetLatestVersionText(const Params: String): String;
var
  I: Integer;
begin
  if not QueryUpdateApi(Params, Result) or (Result = '') or (Length(Result) > 32) then
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
  if IsDomainOrSubdomain(Host, 'empireearth.eu') or IsDomainOrSubdomain(Host, 'neoee.net') then
    Result := True
  else if Host = 'github.com' then
    // Anyone can publish on github.com: only the EE-modders organization, no dot segments/escapes
    Result := (CompareText(Copy(Path, 1, 12), '/EE-modders/') = 0) and (Pos('..', Path) = 0) and (Pos('%', Path) = 0);
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

// Asks whether to download the update; True (= exit setup) if the user wants it
function AskForUpdate(const UpdateMessage, LatestVersionParams: String): Boolean;
var
  Msg: String;
begin
  Msg := UpdateMessage;
  StringChangeEx(Msg, '[LAST]', GetLatestVersionText(LatestVersionParams), True);
  Result := MsgBox(Msg, mbConfirmation, MB_YESNO) = IDYES;
  if Result then
    OpenUpdateDownloadPage();
end;

// Return True when update dialog return yes (= exit setup & open web page)
function CheckUpdate: Boolean;
var
  Answer: String;
begin
  Result := False;
  if QueryUpdateApi('&type=game&version={#MyAppVersion}', Answer) and (Answer = 'false') then
    Result := AskForUpdate(ExpandConstant('{cm:GameUpdate}'), '&type=game')
  else if QueryUpdateApi('&type=setup&version={#MySetupVersion}', Answer) and (Answer = 'false') then
    Result := AskForUpdate(ExpandConstant('{cm:SetupUpdate}'), '&type=setup');
end;

function CorrectLanguageCode(Param: String): String;
begin
  if (Pos('_', Param) > 0) then
  begin
    Param[Pos('_', Param)] := '-';
  end;
  Result := Param;
end;

function GetSelectedLanguageFromComponents(Dummy: String): String;
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
  Langs.Add('de');
  Langs.Add('en');
  Langs.Add('es');
  Langs.Add('fr');
  Langs.Add('it');
  Langs.Add('ko');
  Langs.Add('pl');
  Langs.Add('pt_BR');
  Langs.Add('ru');
  Langs.Add('zh_CN');
  Langs.Add('zh_TW');
  Log('Registered languages: ' + Langs.CommaText);
end;

function InitializeSetup: Boolean;
var
  ErrorCode : Integer;
begin
  Result := False;

  if (not SilentInstall and not IsWine) then
  begin
    bassInit();
  end;

  if (IsWine()) then
  begin
    Log('Wine detected v' + EEStats_getWineVersion());
  end;

  if (not SuppressMsgBoxes and not SilentInstall) then
  begin
    if (CheckUpdate()) then
    begin
      Log('Update found and user want to download it! Exiting setup...');
      Exit;
    end;
  end else begin
    Log('Update check skipped because using silent mode');
  end;

  // Already Installed
  if (not IsGameInstalled and (not SilentInstall and not SuppressMsgBoxes)) then
  begin
    // Legal Question
    if MsgBox(ExpandConstant('{cm:LegalQuestion}'), mbConfirmation, MB_YESNO) = IDNO then
    begin
      ShellExecAsOriginalUser('open', 'https://www.gog.com/game/empire_earth_gold_edition', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
      Exit;
    end;
  end;

#if TestID != 0
  // Test Warning, force pop up even with silent mode
  MsgBox('THIS IS A TEST SETUP ID = {#TestID} [Setup v{#MySetupVersion} - Game v{#MyAppVersion}]' + #13#10 + 'PLEASE USE THIS INSTALLER ONLY FOR TESTING' + #13#10 + 'DO >>NOT<< SHARE IT!' , mbInformation, MB_OK);
#endif

  // AntiVirus/Portable/User Warning
  if (not SilentInstall and not SuppressMsgBoxes) then
  begin
    //if IsAdminInstallMode and not IsWine then
    //begin
    //  MsgBox(ExpandConstant('{cm:AntiVirusWarning}'), mbInformation, MB_OK);
    //end;

    if (ExpandConstant('{#InstallMode}') = 'Portable') then
    begin
      if MsgBox(ExpandConstant('{cm:PortableQuestion}'), mbConfirmation, MB_YESNO) = IDNO then
        Exit;
      end
    else if (not IsAdminInstallMode) then
    begin
      MsgBox(ExpandConstant('{cm:UserInstallMode}'), mbInformation, MB_OK);
    end;
  end;

#if InstallType == "NeoEE"
  // Wine Environment Detection
  if (IsWine() and (not SilentInstall and not SuppressMsgBoxes)) then
    MsgBox('Wine Detected !' + #13#10 + 'NeoEE connection GUI which causes the game to crash because it uses GDI/GDI+!'
            + #13#10 + 'To avoid crash the NeoEE connection GUI will be disabled, if you install it with Winetricks you can enable the GUI again in NeoEE.cfg.', mbInformation, MB_OK);
#endif

  Result :=  True;
end;

// Setup statistics. Only sent with consent, i.e. when the telemetry component of this product is
// selected in this setup: otherwise no request is made at all. The uninstaller never sends any.
procedure SendSetupTelemetry();
var
  InstallUrlStats: String;
begin
  if (IsUninstaller or not WizardIsComponentSelected('additional\telemetry')) then
  begin
    Log('Setup stats not sent (no consent)');
    Exit;
  end;

  Log('Sending setup stats over HTTPS!');
  InstallUrlStats := 'https://api.' + DomainMain + '/eestats/setup/'
    + '?install_type=' + UrlEncode('{#AppID}')
    + '&install_lang=' + UrlEncode(CorrectLanguageCode(GetSelectedLanguageFromComponents('')))
    + '&is_uninstall=0'
    + '&setup_version=' + UrlEncode('{#MySetupVersion}')
    + '&game_version=' + UrlEncode('{#MyAppVersion}')
    + '&components=' + UrlEncode(WizardSelectedComponents(False))
    + '&tasks=' + UrlEncode(WizardSelectedTasks(False))
    + '&arch=' + UrlEncode(String(EEStats_getProcessorArch()))
    + '&user_uid=' + UrlEncode(String(EEStats_getUID()));

  if (IsInstalled) then
    InstallUrlStats := InstallUrlStats + '&already_installed=1&install_update=' + IntToStr(Integer(IsUpdate))
  else
    InstallUrlStats := InstallUrlStats + '&already_installed=0&install_update=0';

  InstallUrlStats := InstallUrlStats + '&os_virtual_machine=' + IntToStr(Integer(EEStats_runInVM()));

  if (IsWine()) then
    InstallUrlStats := InstallUrlStats + '&wine=1&os_version=' + UrlEncode(String(EEStats_getWineVersion()))
  else
    InstallUrlStats := InstallUrlStats + '&os_version=' + UrlEncode(GetWindowsVersionString()) + '&wine=0';

  SendRequest(InstallUrlStats, True);
end;

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
    else if UninstallKeyHasTask(GetUninstallRegPath(True), 'certinclude') then
      Log('Certificate still used by the other setup, not removed')
    else
      RemoveCertificate();
#endif
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  // If components or taks page and recommanded install type -> don't show those page
  if ((PageID = wpSelectComponents) or (PageID = wpSelectTasks)) and (ManualInstallQuestionPage.Values[3] = False) then
  begin
    Result := True;
  end else if (PageID = GPUInstallQuestionPage.ID) and ((ManualInstallQuestionPage.Values[0] = False) or IsWine()) then
  begin
    Result := True;
  end
end;

#if InstallType == "NeoEE"
const
  CDKeysAuthServer = 'neoee.net';
  CDKeysAuthPort = '10003';

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
// NeoEE CDKeys Regedit Hell
// HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Sierra\CDKeys
// HKEY_LOCAL_MACHINE\Software\Sierra\CDKeys
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
    0: Log('CD Keys registered');
    1: ShowCDKeysError(CustomMessage('CDKeysErrorVM'));
    2: ShowCDKeysError(CustomMessage('CDKeysErrorGeneral'));
    3: ShowCDKeysError(CustomMessage('CDKeysErrorNetwork'));
    4: ShowCDKeysError(CustomMessage('CDKeysErrorRegistry'));
    5: ShowCDKeysError(CustomMessage('CDKeysErrorSyntax'));
    6: ShowCDKeysError(CustomMessage('CDKeysErrorProtection'));
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

// NeoEE setups install the NeoEE version of a localized file where there is one, like [Files]
// does with the local files (the NeoEE entries come last and overwrite the EE ones); otherwise,
// and in EE setups, the EE version
procedure AddLocalizedOnlineFile(const RelPath, NeoEERelPath, RelDest: String);
begin
#if InstallType == "NeoEE"
  if AddOnlineFile(NeoEERelPath, RelDest) then
    Exit;
#endif
  AddOnlineFile(RelPath, RelDest);
end;

procedure RegisterOnlineFiles();
var
  LangCode, Game, Lobby, NeoGame, NeoLobby: String;
begin
  // Register Online Files (Game default is in english, online files will recover the located one if asked)
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

  LangCode := CorrectLanguageCode(GetSelectedLanguageFromComponents(''));
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
  Game := 'Game/' + LangCode;
  Lobby := 'Lobby/' + LangCode;
  NeoGame := 'Mods/NeoEE/Game/' + LangCode;
  NeoLobby := 'Mods/NeoEE/Lobby/' + LangCode;

  // -------- EE (always installed) --------
  AddLocalizedOnlineFile(Game + '/EE/Language.dll', NeoGame + '/EE/Language.dll', 'EE\Language.dll');
  AddOnlineFile(Game + '/EE/Data/data.ssa', 'EE\Data\data.ssa');
  AddOnlineFile(Game + '/EE/Data/Campaigns/EELearningCampaign.ssa', 'EE\Data\Campaigns\EELearningCampaign.ssa');
  AddOnlineFile(Game + '/EE/Data/Campaigns/EETheBritish.ssa', 'EE\Data\Campaigns\EETheBritish.ssa');
  AddOnlineFile(Game + '/EE/Data/Campaigns/EETheFuture.ssa', 'EE\Data\Campaigns\EETheFuture.ssa');
  AddOnlineFile(Game + '/EE/Data/Campaigns/EETheGermans.ssa', 'EE\Data\Campaigns\EETheGermans.ssa');
  AddOnlineFile(Game + '/EE/Data/Campaigns/EETheGreeks.ssa', 'EE\Data\Campaigns\EETheGreeks.ssa');
  if (WizardIsComponentSelected('additional\movies')) then
    AddOnlineFile(Game + '/EE/Data/Movies/Empire Earth.bik', 'EE\Data\Movies\Empire Earth.bik');
  AddOnlineFile(Lobby + '/shared/Data/WONLobby Resources/_WONStatus.cfg', 'EE\Data\WONLobby Resources\_WONStatus.cfg');
  AddOnlineFile(Lobby + '/shared/Data/WONLobby Resources/_GameResource.cfg', 'EE\Data\WONLobby Resources\_GameResource.cfg');
  AddOnlineFile(Lobby + '/shared/Data/WONLobby Resources/_LobbyResource.cfg', 'EE\Data\WONLobby Resources\_LobbyResource.cfg');
  AddLocalizedOnlineFile(Lobby + '/EE/WONLobby.cfg', NeoLobby + '/EE/WONLobby.cfg', 'EE\WONLobby.cfg');
  #if InstallType == "NeoEE"
    AddOnlineFile(NeoLobby + '/shared/Data/WONLobby Resources/_NeoEEResource.cfg', 'EE\Data\WONLobby Resources\_NeoEEResource.cfg');
  #endif

  // -------- AoC --------
  if (not WizardIsComponentSelected('gameaoc')) then
    Exit;
  AddLocalizedOnlineFile(Game + '/AoC/Language.dll', NeoGame + '/AoC/Language.dll', 'AoC\Language.dll');
  AddOnlineFile(Game + '/AoC/Data/data.ssa', 'AoC\Data\data.ssa');
  AddOnlineFile(Game + '/AoC/Data/Campaigns/AOCAsian.ssa', 'AoC\Data\Campaigns\AOCAsian.ssa');
  AddOnlineFile(Game + '/AoC/Data/Campaigns/AOCPacific.ssa', 'AoC\Data\Campaigns\AOCPacific.ssa');
  AddOnlineFile(Game + '/AoC/Data/Campaigns/AOCRoman.ssa', 'AoC\Data\Campaigns\AOCRoman.ssa');
  // Same files as for EE: downloaded once and copied (see AddOnlineFile)
  AddOnlineFile(Lobby + '/shared/Data/WONLobby Resources/_WONStatus.cfg', 'AoC\Data\WONLobby Resources\_WONStatus.cfg');
  AddOnlineFile(Lobby + '/shared/Data/WONLobby Resources/_GameResource.cfg', 'AoC\Data\WONLobby Resources\_GameResource.cfg');
  AddOnlineFile(Lobby + '/shared/Data/WONLobby Resources/_LobbyResource.cfg', 'AoC\Data\WONLobby Resources\_LobbyResource.cfg');
  AddLocalizedOnlineFile(Lobby + '/AoC/WONLobby.cfg', NeoLobby + '/AoC/WONLobby.cfg', 'AoC\WONLobby.cfg');
  #if InstallType == "NeoEE"
    AddOnlineFile(NeoLobby + '/shared/Data/WONLobby Resources/_NeoEEResource.cfg', 'AoC\Data\WONLobby Resources\_NeoEEResource.cfg');
  #endif
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

function NextButtonClick(CurPageID: Integer): Boolean;
var
  i: Integer;
begin
  if (not SilentInstall and (CurPageID = ManualInstallQuestionPage.ID)) then
  begin
    // Game Selection
    if (ManualInstallQuestionPage.Values[0]) then
    begin
      if (ManualInstallQuestionPage.Values[1]) then
      begin
        WizardSelectComponents('game');
        WizardSelectComponents('!gameaoc');
      end else if (ManualInstallQuestionPage.Values[2]) then
      begin
        WizardSelectComponents('game');
        WizardSelectComponents('gameaoc');
      end;
    end
    else if (IsGameInstalled() and not ManualInstallQuestionPage.Values[0]) then
    begin
      // For some reasons WizardSelectComponents (on top) will badly unselect the component
      // This make any component(/task?) unselected by code automatically re-selected on reinstall...
      if (WizardIsComponentInstalled('gameaoc')) then
        WizardSelectComponents('gameaoc')
      else
        WizardSelectComponents('!gameaoc');
    end;

    // Telelmetry Selection
    if (IsGameInstalled()) then
    begin
      if (ManualInstallQuestionPage.Values[5]) then
      begin
        WizardSelectComponents('additional\telemetry');
      end
      else begin
        WizardSelectComponents('!additional\telemetry');
      end
    end else if (not IsGameInstalled()) then
    begin
      if (ManualInstallQuestionPage.Values[4]) then
      begin
        WizardSelectComponents('additional\telemetry');
      end
      else begin
        WizardSelectComponents('!additional\telemetry');
      end
    end
  end;

  if (CurPageID = GPUInstallQuestionPage.ID) then
  begin
    if (GPUInstallQuestionPage.Values[0]) then          // NVIDIA
    begin
      Log('Using NVIDIA GPU settings');
      WizardSelectComponents('additional\directx_wrapper\dx11_lvl11');
    end
    else if (GPUInstallQuestionPage.Values[1]) then     // AMD
    begin
      Log('Using AMD GPU settings');
      if (IsWindows10OrNewer) then
        WizardSelectComponents('additional\directx_wrapper\dx11_lvl11')
      else
        WizardSelectComponents('additional\directx_wrapper\dx11_lvl10_1');
    end
    else if (GPUInstallQuestionPage.Values[2]) then     // Intel Sh$t
    begin
      Log('Using Intel GPU settings');
      // https://www.intel.com/content/www/us/en/support/articles/000005524/graphics.html
      // We could eventually use lvl 11, but Intel HD Graphics 2000/3000 don't support it 
      WizardSelectComponents('additional\directx_wrapper\dx11_lvl10_1');
    end
    else if (GPUInstallQuestionPage.Values[3]) then     // Idk
    begin
      Log('Using general GPU settings');
      WizardSelectComponents('additional\directx_wrapper\dx9');
    end
    else if (GPUInstallQuestionPage.Values[4]) then     // Native
    begin
      Log('Using general Native');
      WizardSelectComponents('!additional\directx_wrapper');
    end;
  end;

  if (CurPageID = LanguageInstallQuestionPage.ID) then
  begin
    for i := 0 to Langs.Count - 1 do
    begin
      if (LanguageInstallQuestionPage.Values[i]) then
      begin
        SelectLanguageFromIndex(i);
        break;
      end;
    end;
  end;

  if (CurPageID = wpFinished) then
  begin
    SendSetupTelemetry();
#if InstallMode == "Regular"
    // Portable installations have no uninstall key (CreateUninstallRegKey=no): writing the value
    // there would create one that is never removed
    if (ManualInstallQuestionPage.Values[0]) then
    begin
      // We need to force register the install type as custom
      // because we edited ourselves the components list
      Log('Forcing custom install type, because we used the manual install question page.');
      if not RegKeyExists(HKA, GetUninstallRegPath(False)) then
        Log('Uninstall key not found, install type not changed')
      else if not RegWriteStringValue(HKA, GetUninstallRegPath(False), 'Inno Setup: Setup Type', 'custom') then
        Log('Unable to write the install type to the uninstall key');
    end;
#endif
  end;

  // Register files after components page
  if (CurPageID = wpReady) then
	begin
    RegisterOnlineFiles();
  end;
  Result := True;
end;

function InitializeUninstall(): Boolean;
begin
  RegisterLangs()
#if CertInclude
  CertAddedBySetup := UninstallKeyHasTask(GetUninstallRegPath(False), 'certinclude');
#endif
  Result := True;
end;

{ Setup }
procedure InitializeWizard;
var
  BackgroundImage: TBitmapImage;
  Diff: double;
  ScrWidth: double;
  ScrHeight: double;
begin

  if (not SilentInstall and not IsWine) then
  begin
    bassCreateButton();
  end;

  RegisterLangs();
  RegisterDownloadPins();
  IsUpdate := WizardIsUpdate();
  IsInstalled := IsGameInstalled();

  Log('Init custom setup pages');
  SetupLanguagePage();
  SetupManualCustomInstallPage();
  SetupGPUInstallPage();

  Log('Init setup background');
  BackgroundImage := TBitmapImage.Create(MainForm);
  BackgroundImage.Parent := MainForm;
  BackgroundImage.SetBounds(0, 0, MainForm.ClientWidth, MainForm.ClientHeight);
  BackgroundImage.Stretch := True;

  // Auto Select 16:9 or 4:3
  ScrWidth := MainForm.ClientWidth;
  ScrHeight := MainForm.ClientHeight;

  Diff := ScrWidth / ScrHeight

  Log('Extracting and defining image banner');
  if (Diff > 1.55) then
  begin
    ExtractTemporaryFile('SetupBackground-16-9.bmp');
    BackgroundImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\SetupBackground-16-9.bmp'));
  end;

  if (Diff <= 1.55) then
  begin
    ExtractTemporaryFile('SetupBackground-4-3.bmp');
    BackgroundImage.Bitmap.LoadFromFile(ExpandConstant('{tmp}\SetupBackground-4-3.bmp'));
  end;

  if (not SilentInstall and not IsWine) then
  begin
    bassPlay();
  end;

  // Create tmp dir to download files
  CreateDir(ExpandConstant('{tmp}\EE'));
  CreateDir(ExpandConstant('{tmp}\EE\Data'));
  CreateDir(ExpandConstant('{tmp}\EE\Data\Campaigns'));
  CreateDir(ExpandConstant('{tmp}\EE\Data\Movies'));
  CreateDir(ExpandConstant('{tmp}\EE\Data\WONLobby Resources'))
  CreateDir(ExpandConstant('{tmp}\AoC'));
  CreateDir(ExpandConstant('{tmp}\AoC\Data'));
  CreateDir(ExpandConstant('{tmp}\AoC\Data\Campaigns'));
  CreateDir(ExpandConstant('{tmp}\AoC\Data\WONLobby Resources'));

  idpSetOption('DetailedMode',  '1');
  // Timeouts in milliseconds, per connection attempt and per network operation (not for a whole
  // file, so large files like the intro video are fine): 0.5 s used to make slow, mobile or VPN
  // connections fail. RegisterOnlineFiles only uses a server that answered.
  idpSetOption('ConnectTimeout', '15000');
  idpSetOption('SendTimeout', '30000');
  idpSetOption('ReceiveTimeout', '30000');
  idpSetOption('ErrorDialog', 'UrlList');
  // Never accept an invalid TLS certificate (the IDP default would let the user ignore it).
  // Downloads are also checked against their SHA-256 (downloads.iss).
  idpSetOption('InvalidCert', 'Stop');
  // Failed downloads can be skipped: VerifyDownloadedFiles reports every file that is missing then
  idpSetOption('AllowContinue', '1');

  idpDownloadAfter(wpReady);
end;

procedure DeinitializeSetup;
begin
  if (not SilentInstall and not IsWine) then
  begin
    bassFree;
  end;
end;
