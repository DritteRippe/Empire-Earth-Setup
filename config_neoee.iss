; NeoEE setup (InstallType NeoEE)
; Product configuration, included by setup_is6.iss (see "Product configuration" there).
; config_ee.iss and config_neoee.iss define the same names: the values that differ between the
; EE and the NeoEE setup apart from their content (files, components, tasks and code, which stay
; in the scripts under "#if InstallType"). A new define must be added to both files.
; Requires: EE_AppID, NeoEE_AppID (ISPP, setup_is6.iss).

; Setup identity: AppId of this product and of the other one (see the AppId notes in setup_is6.iss)
#define AppID NeoEE_AppID
#define OtherAppID EE_AppID

; Product shown by the setup and in the uninstall entry
#define MyAppVersion "2.0.0.5"
#define MyAppName "NeoEE"
#define MyAppPublisher "Empire Earth Community & NeoEE"
#define MyAppURL "https://www.neoee.net/"
#define MyInstallDirName "Neo Empire Earth"
#define MySetupPassword "neo"

; Registry keys of the game settings (Empire Earth, The Art of Conquest)
#define BaseRegEE "Software\Neo\Empire Earth"
#define BaseRegAoC "Software\Neo\Art of Conquest"

; [Setup]: icon, wizard image, sign tool name (ISCC /S, signed builds), file shown before the
; installation ("" for none) and the part of the output file name after the product name
#define MySetupIconFile "data\NeoEE Base\shared\neoee.ico"
#define MyWizardSmallImageFile "internal\media\WizardSmallImageFileNeo.bmp"
#define MySignTool "NameInInnoSetupNeo"
#define MyInfoBeforeFile "data\NeoEE Base\shared\neoee_rules.rtf"
#define MyOutputVersionPart "_v" + MyAppVersion
