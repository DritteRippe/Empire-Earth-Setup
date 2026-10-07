; Empire Earth setup (InstallType EE)
; Product configuration, included by setup_is6.iss (see "Product configuration" there).
; config_ee.iss and config_neoee.iss define the same names: the values that differ between the
; EE and the NeoEE setup apart from their content (files, components, tasks and code, which stay
; in the scripts under "#if InstallType"). A new define must be added to both files.
; Requires: EE_AppID, NeoEE_AppID (ISPP, setup_is6.iss).

; Setup identity: AppId of this product and of the other one (see the AppId notes in setup_is6.iss)
#define AppID EE_AppID
#define OtherAppID NeoEE_AppID

; Product shown by the setup and in the uninstall entry
#define MyAppVersion "2.0.0.0"
#define MyAppName "Empire Earth"
#define MyAppPublisher "Empire Earth Community"
#define MyAppURL "https://empireearth.eu/"
#define MyInstallDirName "Empire Earth"
#define MySetupPassword "ee"

; Registry keys of the game settings (Empire Earth, The Art of Conquest)
#define BaseRegEE "Software\SSSI\Empire Earth"
#define BaseRegAoC "Software\Mad Doc Software\EE-AOC"

; [Setup]: icon, wizard image, sign tool name (ISCC /S, signed builds), file shown before the
; installation ("" for none) and the part of the output file name after the product name
#define MySetupIconFile "data\Empire Earth Base\Empire Earth\game.ico"
#define MyWizardSmallImageFile "internal\media\WizardSmallImageFileEE.bmp"
#define MySignTool "NameInInnoSetupEE"
#define MyInfoBeforeFile ""
#define MyOutputVersionPart ""
