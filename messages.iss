[CustomMessages]
; Message names: the prefix names the custom wizard page (pages.iss) that shows the text
;   LIQP_    Language Install Question Page: the game language
;   MIQP_    Manual Install Question Page: recommended or custom settings, repair/update, telemetry
;   GPUIQP_  GPU Install Question Page: graphics card brand and DirectX wrapper
; The other messages are named after their use. The entry without language prefix is the English
; text, which every language without its own entry shows. How to translate, and which texts
; still need translators: TRANSLATING.md.
; Requires: InstallType, MyAppVersion, MySetupVersion, MySetupPassword (ISPP, setup_is6.iss).

; Translation Note
; chinese, russian and korean have been translated with a translator and are therefore
; probably of poor quality. If you can check them and suggest improvements that's perfect!
; Messages added after setup 1.7.2 are only English, German and French (see TRANSLATING.md).

; Legal
LegalQuestion=Do you have the original game and its expansion (or Gold Edition) on CD with valid keys or did you purchase the game digitally?
de.LegalQuestion=Haben Sie das Originalspiel und seine Erweiterung (oder Gold Edition) auf CD mit gültigen Schlüsseln oder haben Sie das Spiel digital erworben?
es.LegalQuestion=¿Tiene el juego original y su expansión (o la Gold Edition) en CD con claves válidas o ha comprado el juego digitalmente?
fr.LegalQuestion=Avez-vous le jeu original et son extension (ou l'édition Gold) sur CD avec des clés valides ou avez-vous acheté le jeu numériquement ?
it.LegalQuestion=Hai il gioco originale e la sua espansione (o Gold Edition) su CD con chiavi valide o hai acquistato il gioco in digitale?
ko.LegalQuestion=유효한 키가 있는 CD에 오리지널 게임과 확장(또는 Gold 에디션)이 있거나 디지털 방식으로 게임을 구입했습니까?
pl.LegalQuestion=Czy posiadasz oryginalną grę i dodatek (lub Gold Edycję) na CD z kluczami instalacyjnymi, czy też zakupiłeś grę cyfrowo?
ru.LegalQuestion=Есть ли у вас оригинальная игра и ее расширение (или Gold Edition) на CD с действующими ключами или вы приобрели игру в цифровом виде?
zh_CN.LegalQuestion=你是否有原版游戏及其扩展版（或Gold版）的CD和有效的钥匙，或者你是通过数字方式购买游戏？
zh_TW.LegalQuestion=你是否有原版游戏及其扩展版（或Gold版）的CD和有效的钥匙，或者你是通过数字方式购买游戏？

; Portable
PortableQuestion=You are currently running the portable version of the installer. This version is made to allow you to play on removable devices (USB). \
%nAn installation in portable mode cannot be uninstalled, as it is simply a copy of the game files. \
%nIf you don't know what you are doing please use the normal version of the installer. \
%n%nDo you want to continue the installation?
de.PortableQuestion=Sie führen gerade die tragbare Version des Installationsprogramms aus. Diese Version wurde entwickelt, damit Sie auf Wechseldatenträgern (USB) spielen können. \
%nEine Installation im tragbaren Modus kann nicht deinstalliert werden, da es sich lediglich um eine Kopie der Spieldateien handelt. \
%nWenn Sie nicht wissen, was Sie tun, verwenden Sie bitte die normale Version des Installationsprogramms. \
%n%nMöchten Sie die Installation fortsetzen?
es.PortableQuestion=Actualmente está ejecutando la versión portátil del instalador. Esta versión está hecha para permitirle jugar en dispositivos extraíbles (USB). \
%nUna instalación en modo portátil no puede ser desinstalada, ya que es simplemente una copia de los archivos del juego. \
%nSi no sabe lo que está haciendo por favor utilice la versión normal del instalador. \
%n%n¿Quiere continuar con la instalación?
fr.PortableQuestion=Vous utilisez actuellement la version portable de l'installateur. Cette version est faite pour vous permettre de jouer sur des périphériques amovibles (USB, etc...). \
%nUne installation en mode portable ne peut pas être désinstallée, car il s'agit simplement d'une copie des fichiers du jeu. \
%nSi vous ne savez pas ce que vous faites, veuillez utiliser la version normal de l'installateur. \
%n%nSouhaitez-vous poursuivre l'installation ?
it.PortableQuestion=Attualmente stai eseguendo la versione portatile del programma di installazione. Questa versione è fatta per permetterti di giocare su dispositivi rimovibili (USB). \
Un'installazione in modalità portatile non può essere disinstallata, in quanto è semplicemente una copia dei file di gioco. \
Se non sai cosa stai facendo, usa la versione normale del programma di installazione. \
%n%nVuoi continuare l'installazione?
ko.PortableQuestion=현재 설치 프로그램의 휴대용 버전을 실행 중입니다. 이 버전은 이동식 장치(USB)에서 재생할 수 있도록 하기 위해 만들어졌습니다. \
%n휴대용 모드의 설치는 단순히 게임 파일의 복사본이기 때문에 제거 할 수 없습니다. \
%n당신이 무엇을하고 있는지 모르는 경우 설치 프로그램의 일반 버전을 사용하시기 바랍니다. \
%n%n설치를 계속하시겠습니까?
pl.PortableQuestion=Uruchomiłeś przenośną wersję instalatora. Ta wersja została stworzona, aby umożliwić Ci grę z pamięci przenośnej (USB). \
%nInstalacji w trybie przenośnym nie można odinstalować za pomocą deinstalatora, ponieważ jest to po prostu kopia plików gry. \
Jeśli nie jesteś pewien decyzji, zalecamy użycie normalnej wersji instalatora. \
%n%nCzy chcesz kontynuować instalację w trybie przenośnym?
ru.PortableQuestion=В настоящее время вы запускаете установку портативной версии игры. Она сделана для того, чтобы вы могли играть на съемных устройствах (USB). \
%nПортативная версия игры не имеет деинсталлятора, так как это просто копия файлов игры. \
%nЕсли вы не знаете, что делаете, пожалуйста, используйте обычную версию программы установки. \
%n%nВы хотите продолжить установку?
zh_CN.PortableQuestion=你目前运行的是便携式版本的安装程序。这个版本是为了让你在可移动设备（USB）上播放。 \
在便携式模式下的安装程序不能被卸载，因为它只是游戏文件的一个副本。 \
%n如果你不知道你在做什么，请使用普通版本的安装程序。 \
%n%n你想继续安装吗？
zh_TW.PortableQuestion=你目前运行的是便携式版本的安装程序。这个版本是为了让你在可移动设备（USB）上播放。 \
在便携式模式下的安装程序不能被卸载，因为它只是游戏文件的一个副本。 \
%n如果你不知道你在做什么，请使用普通版本的安装程序。 \
%n%n你想继续安装吗？

; Game Update
GameUpdate=The game included in this setup is not up to date ({#MyAppVersion} => [LAST]), please update or YOU MAY NOT BE ABLE TO PLAY WITH OTHER PLAYERS. \
%n%nWould you like to download the latest version?
de.GameUpdate=Das in diesem Installationsprogramm enthaltene Spiel ist nicht auf dem neuesten Stand ({#MyAppVersion} => [LAST]), bitte aktualisieren Sie es, SONST KÖNNEN SIE MÖGLICHERWEISE NICHT MIT ANDEREN SPIELERN SPIELEN. \
%n%nWollen Sie die neueste Version herunterladen?
es.GameUpdate=El juego incluido en esta configuración no está actualizado ({#MyAppVersion} => [LAST]), por favor actualice o NO PODRÁ JUGAR CON OTROS JUGADORES. \
%n%n¿Quiere descargar la última versión?
fr.GameUpdate=Le jeu inclus dans cette installation n'est pas à jour ({#MyAppVersion} => [LAST]), veuillez le mettre à jour ou VOUS POURRIEZ NE PAS ÊTRE EN MESURE DE JOUER AVEC D'AUTRES JOUEURS. \
%n%nVoulez-vous télécharger la dernière version ?
it.GameUpdate=Il gioco incluso in questo setup non è aggiornato ({#MyAppVersion} => [LAST]), per favore aggiorna o potresti non essere in grado di giocare con altri giocatori. \
%n%nVuoi scaricare l'ultima versione?
ko.GameUpdate=이 설정에 포함된 게임은 최신 상태({#MyAppVersion} => [LAST]) 최신 게임이 아니며, 업데이트해 주거나 다른 플레이어와 플레이할 수 없을 수도 있습니다. \
%n%n최신 버전을 다운로드하시겠습니까?
pl.GameUpdate=Wersja gry znajdująca się w tym programie instalacyjnym jest nieaktualna ({#MyAppVersion} => [LAST]). Zalecamy aktualizację, w celu rozwiązania problemów i możliwości połączeń multiplayer z innymi graczami. \
%n%nCzy chcesz pobrać teraz najnowszą wersję?
ru.GameUpdate=Для игры, включенной в эту программу установки, доступно обновление ({#MyAppVersion} => [LAST]). Пожалуйста, обновите или ВЫ НЕ МОЖЕТЕ ИГРАТЬ С ДРУГИМИ ИГРОКАМИ. \
%n%nВы хотите скачать последнюю версию?
zh_CN.GameUpdate=这个设置中包含的游戏不是最新的（{#MyAppVersion} => [LAST]），请更新，否则你可能无法与其他玩家一起玩。 \
%n%n你想下载最新的版本吗？
zh_TW.GameUpdate=这个设置中包含的游戏不是最新的（{#MyAppVersion} => [LAST]），请更新，否则你可能无法与其他玩家一起玩。 \
%n%n你想下载最新的版本吗？

; Setup Update
SetupUpdate=The setup is not up to date ({#MySetupVersion} => [LAST]), it is strongly recommended to use the latest version to benefit from the latest fixes and compatibility improvements. \
%n%nWould you like to download the latest version?
de.SetupUpdate=Das Installationsprogramm ist nicht auf dem neuesten Stand ({#MySetupVersion} => [LAST]). Es wird dringend empfohlen, die neueste Version zu verwenden, um von den neuesten Fehlerkorrekturen und Kompatibilitätsverbesserungen zu profitieren. \
%n%nWollen Sie die neueste Version herunterladen?
es.SetupUpdate=El instalador no está actualizado ({#MySetupVersion} => [LAST]), se recomienda encarecidamente utilizar la última versión para beneficiarse de las últimas correcciones y mejoras de compatibilidad. \
%n%n¿Desea descargar la última versión?
fr.SetupUpdate=Le programme d'installation n'est pas à jour ({#MySetupVersion} => [LAST]), il est fortement recommandé d'utiliser la dernière version pour bénéficier des dernières corrections et améliorations de compatibilité. \
%n%nVoulez-vous télécharger la dernière version ?
it.SetupUpdate=Il programma di installazione non è aggiornato ({#MySetupVersion} => [LAST]), è fortemente consigliato di usare l'ultima versione per beneficiare delle ultime correzioni e dei miglioramenti di compatibilità. \
%n%nVuoi scaricare l'ultima versione?
ko.SetupUpdate=설치 프로그램은 최신 ({#MySetupVersion} => [LAST]) 최신 버전의 혜택을 누리는 것이 좋습니다. \
%n%n최신 버전을 다운로드하시겠습니까?
pl.SetupUpdate=Wersja instalatora jest nieaktualna ({#MySetupVersion} => [LAST]). Wysoce zalecamy użycie najnowszej wersji w celu zastosowania najnowszych poprawek i ulepszonej kompatybilności. \
%n%nCzy chcesz pobrać teraz najnowszą wersję instalatora?
ru.SetupUpdate=Для программы установки доступно обновление ({#MySetupVersion} => [LAST]), настоятельно рекомендуется использовать последнюю версию, чтобы воспользоваться последними исправлениями и улучшениями совместимости. \
%n%nВы хотите скачать последнюю версию?
zh_CN.SetupUpdate=安装程序不是最新的（{#MySetupVersion} => [LAST]），强烈建议使用最新的版本以受益于最新的修复和兼容性改进。 \
%n%n你想下载最新的版本吗？
zh_TW.SetupUpdate=安装程序不是最新的（{#MySetupVersion} => [LAST]），强烈建议使用最新的版本以受益于最新的修复和兼容性改进。 \
%n%n你想下载最新的版本吗？

UserInstallMode=You are using the user mode installation, which means that you will not need administrator rights for the installation. \
%nPlease note that this mode is not able to register the game with the computer's firewall, which may prevent you from hosting games (but you should still be able to join games). \
%nIf you have administrator rights on the machine, prefer the administrator mode.
de.UserInstallMode=Sie verwenden die Installation im Benutzermodus, was bedeutet, dass Sie für die Installation keine Administratorrechte benötigen. \
Bitte beachten Sie, dass dieser Modus nicht in der Lage ist, das Spiel bei der Firewall des Computers zu registrieren, was Sie möglicherweise daran hindert, Spiele zu veranstalten (Sie sollten aber trotzdem in der Lage sein, Spielen beizutreten). \
%nWenn Sie über Administratorrechte auf dem Computer verfügen, wählen Sie den Administratormodus.
es.UserInstallMode=Está utilizando la instalación en modo usuario, lo que significa que no necesitará derechos de administrador para la instalación. \
%nTenga en cuenta que este modo no es capaz de registrar el juego con el cortafuegos del ordenador, lo que puede impedirle alojar partidas (pero debería poder unirse a ellas). \
%nSi tienes derechos de administrador en la máquina, prefiere el modo administrador.
fr.UserInstallMode=Vous utilisez l'installation en mode utilisateur, ce qui signifie que vous n'aurez pas besoin de droits d'administrateur pour l'installation. \
%nVeuillez noter que ce mode n'est pas en mesure d'enregistrer le jeu auprès du pare-feu de l'ordinateur, ce qui peut vous empêcher d'héberger des parties (mais vous devriez toujours pouvoir rejoindre des parties). \
%n%nSi vous avez des droits administrateur sur la machine, préférez le mode administrateur.
it.UserInstallMode=Stai usando l'installazione in modalità utente, il che significa che non avrai bisogno dei diritti di amministratore per l'installazione. \
%nNota che questa modalità non è in grado di registrare il gioco con il firewall del computer, il che potrebbe impedirti di ospitare le partite (ma dovresti comunque essere in grado di partecipare alle partite). \
%nSe hai i diritti di amministratore sulla macchina, preferisci la modalità amministratore.
ko.UserInstallMode=사용자 모드 설치를 사용하고 있으므로 설치에 대한 관리자 권한이 필요하지 않습니다. \
%n이 모드는 컴퓨터의 방화벽으로 게임을 등록할 수 없으며, 이는 게임을 호스팅하는 것을 방지할 수 있습니다(하지만 여전히 게임에 참여할 수 있어야 합니다). \
%n컴퓨터에 관리자 권한이 있는 경우 관리자 모드를 선호합니다.
pl.UserInstallMode=Używasz instalacji w trybie użytkownika, co oznacza, że nie będziesz potrzebował praw administratora do instalacji. \
%nNależy pamiętać, że ten tryb nie jest w stanie zarejestrować gry w zaporze sieciowej komputera, co może uniemożliwić organizowanie gier (ale nadal powinieneś mieć możliwość dołączania do gier). \
%nJeśli masz prawa administratora na komputerze, wybierz tryb administratora.
ru.UserInstallMode=Вы используете установку в режиме пользователя, что означает, что вам не нужны права администратора для установки. \
%nПримите во внимание, что этот режим не может зарегистрировать игру в брандмауэре компьютера, что может помешать вам проводить игры (но вы все равно должны иметь возможность присоединяться к играм). \
%nЕсли у вас есть права администратора на компьютере, предпочитайте режим администратора.
zh_CN.UserInstallMode=你使用的是用户模式安装，这意味着你不需要管理员权限就可以安装。 \
%n请注意，这种模式不能在计算机的防火墙上注册游戏，这可能会妨碍你主持游戏（但你应该仍然能够加入游戏）。 \
%n如果你在机器上有管理员权限，请选择管理员模式。
zh_TW.UserInstallMode=你使用的是用户模式安装，这意味着你不需要管理员权限就可以安装。 \
%n请注意，这种模式不能在计算机的防火墙上注册游戏，这可能会妨碍你主持游戏（但你应该仍然能够加入游戏）。 \
%n如果你在机器上有管理员权限，请选择管理员模式。

; Checks before the installation (environment.iss, docs/adr/0007-environment-warnings.md)
; Primary screen lower than 768 pixels (InitializeSetup): %1 x %2 = screen size in pixels,
; %3 x %4 = the game window the setup sets
LowScreenResolution=Your screen is %1 x %2 pixels. The menus of Empire Earth need a screen at least 768 pixels high, so the setup sets the game window to %3 x %4 pixels: the game may not fit on the screen or may crash after the intro.%n%nThe scaling of your graphics driver (for example "GPU scaling") or a DirectX wrapper can help. The installation continues.
de.LowScreenResolution=Ihr Bildschirm hat %1 x %2 Pixel. Die Menüs von Empire Earth brauchen einen Bildschirm mit mindestens 768 Pixeln Höhe, daher stellt das Setup das Spielfenster auf %3 x %4 Pixel: Das Spiel passt möglicherweise nicht auf den Bildschirm oder stürzt nach dem Intro ab.%n%nDie Skalierung Ihres Grafiktreibers (zum Beispiel „GPU-Skalierung“) oder ein DirectX-Wrapper kann helfen. Die Installation wird fortgesetzt.
fr.LowScreenResolution=Votre écran fait %1 x %2 pixels. Les menus d'Empire Earth ont besoin d'un écran d'au moins 768 pixels de haut, le programme d'installation règle donc la fenêtre du jeu sur %3 x %4 pixels : le jeu risque de ne pas tenir à l'écran ou de planter après l'introduction.%n%nLa mise à l'échelle de votre pilote graphique (par exemple « mise à l'échelle GPU ») ou un wrapper DirectX peut aider. L'installation continue.
; Traces of foreign or old installations (folder page, once per run): %1 = list, one line per
; registry key (as regedit shows it, with the folder of its "Installed From" values), folder or
; uninstall entry (its name and folder), at most twelve, then "... (+n)"
ForeignInstallFound=The setup found traces of another Empire Earth installation on this computer, for example of the original CD, of GOG or of an older NeoEE installer:%1%n%nThe community setup installs its own copy and does not change the other installation. If Empire Earth or The Art of Conquest later starts the other installation, or does not start at all, these old entries can be the cause.%n%nPlease do not delete registry keys by hand: Software\Sierra\CDKeys holds the NeoEE CD keys. The Empire Earth Launcher offers a cleanup with a backup.
de.ForeignInstallFound=Das Setup hat Spuren einer anderen Empire-Earth-Installation auf diesem Computer gefunden, zum Beispiel der Original-CD, von GOG oder eines älteren NeoEE-Installationsprogramms:%1%n%nDas Community-Setup installiert eine eigene Kopie und ändert nichts an der anderen Installation. Startet Empire Earth oder The Art of Conquest später die andere Installation oder gar nicht, können diese alten Einträge die Ursache sein.%n%nBitte keine Registry-Schlüssel von Hand löschen; Software\Sierra\CDKeys enthält die NeoEE-CD-Keys. Der Empire Earth Launcher bietet eine Bereinigung mit Sicherung an.
fr.ForeignInstallFound=Le programme d'installation a trouvé des traces d'une autre installation d'Empire Earth sur cet ordinateur, par exemple du CD original, de GOG ou d'un ancien installateur NeoEE :%1%n%nLe programme d'installation de la communauté installe sa propre copie et ne modifie pas l'autre installation. Si Empire Earth ou The Art of Conquest lance plus tard l'autre installation, ou ne démarre pas du tout, ces anciennes entrées peuvent en être la cause.%n%nVeuillez ne pas supprimer de clés du registre à la main : Software\Sierra\CDKeys contient les clés CD NeoEE. L'Empire Earth Launcher propose un nettoyage avec sauvegarde.
; The chosen folder is, contains or lies in the folder of such an installation (folder page; Yes =
; another folder, the default): %1 = folder of the other installation, %2 = chosen folder
ForeignFolderQuestion=The chosen folder belongs to another Empire Earth installation (for example of the original CD or of GOG):%n%1%n%nInstalling there mixes the files of both installations, and uninstalling the community version later also removes files of the other installation.%n%nDo you want to choose another folder (recommended)?%n%nYes: back to the folder selection.%nNo: install into %2 anyway.
de.ForeignFolderQuestion=Der gewählte Ordner gehört zu einer anderen Empire-Earth-Installation (zum Beispiel der Original-CD oder von GOG):%n%1%n%nEine Installation dort mischt die Dateien beider Installationen, und die spätere Deinstallation der Community-Version entfernt auch Dateien der anderen Installation.%n%nMöchten Sie einen anderen Ordner wählen (empfohlen)?%n%nJa: zurück zur Ordnerauswahl.%nNein: trotzdem in %2 installieren.
fr.ForeignFolderQuestion=Le dossier choisi appartient à une autre installation d'Empire Earth (par exemple du CD original ou de GOG) :%n%1%n%nY installer mélange les fichiers des deux installations, et la désinstallation ultérieure de la version de la communauté supprime aussi des fichiers de l'autre installation.%n%nVoulez-vous choisir un autre dossier (recommandé) ?%n%nOui : retour au choix du dossier.%nNon : installer quand même dans %2.
; The chosen folder already holds the other community product (folder page; Yes = another folder,
; the default): %1 = the other product (NeoEE or Empire Earth), %2 = chosen folder
SharedFolderQuestion=The chosen folder already contains %1, installed by the other community setup:%n%2%n%nIf both are installed into the same folder, the launcher can no longer check the installed files of %1, and uninstalling one of them also removes files and the firewall rules of the other.%n%nDo you want to choose another folder (recommended)?%n%nYes: back to the folder selection.%nNo: install into this folder anyway.
de.SharedFolderQuestion=Der gewählte Ordner enthält bereits %1, installiert vom anderen Community-Setup:%n%2%n%nWerden beide in denselben Ordner installiert, kann der Launcher die installierten Dateien von %1 nicht mehr prüfen, und die Deinstallation des einen entfernt auch Dateien und die Firewall-Regeln des anderen.%n%nMöchten Sie einen anderen Ordner wählen (empfohlen)?%n%nJa: zurück zur Ordnerauswahl.%nNein: trotzdem in diesen Ordner installieren.
fr.SharedFolderQuestion=Le dossier choisi contient déjà %1, installé par l'autre programme d'installation de la communauté :%n%2%n%nSi les deux sont installés dans le même dossier, le launcher ne peut plus vérifier les fichiers installés de %1, et la désinstallation de l'un supprime aussi des fichiers et les règles du pare-feu de l'autre.%n%nVoulez-vous choisir un autre dossier (recommandé) ?%n%nOui : retour au choix du dossier.%nNon : installer quand même dans ce dossier.

; Online files (RegisterOnlineFiles, downloads.iss)
; Neither file server answered over https with a valid certificate (SelectOnlineFilesServer)
OnlineFilesUnreachable=The servers of the localized files could not be reached, or they did not present a valid security certificate (a problem of the servers, not of your computer).%n%nThe game is installed with the files included in this setup, so some content (for example voices and campaigns) may stay in English. To add the localized files, run this setup again later.
de.OnlineFilesUnreachable=Die Server der lokalisierten Dateien waren nicht erreichbar oder haben kein gültiges Sicherheitszertifikat vorgelegt (ein Problem der Server, nicht Ihres Computers).%n%nDas Spiel wird mit den Dateien installiert, die dieses Setup enthält, daher bleiben einige Inhalte (zum Beispiel Stimmen und Kampagnen) möglicherweise englisch. Um die lokalisierten Dateien hinzuzufügen, führen Sie dieses Setup später erneut aus.
fr.OnlineFilesUnreachable=Les serveurs des fichiers traduits sont injoignables ou n'ont pas présenté de certificat de sécurité valide (un problème des serveurs, pas de votre ordinateur).%n%nLe jeu est installé avec les fichiers inclus dans ce programme d'installation, certains contenus (par exemple les voix et les campagnes) pourraient donc rester en anglais. Pour ajouter les fichiers traduits, relancez ce programme d'installation plus tard.
; Title and description of the download page (CreateOnlineFilesDownloadPage); its other texts
; (progress label, stop button, the question after it) are Inno Setup's own messages
DownloadPageCaption=Downloading localized files
de.DownloadPageCaption=Lokalisierte Dateien werden heruntergeladen
fr.DownloadPageCaption=Téléchargement des fichiers traduits
DownloadPageDescription=Please wait while the setup downloads the voices, campaigns and texts of the selected language. If you stop the download, the game is installed with the files included in this setup.
de.DownloadPageDescription=Bitte warten Sie, während das Setup die Stimmen, Kampagnen und Texte der gewählten Sprache herunterlädt. Wenn Sie den Download abbrechen, wird das Spiel mit den Dateien installiert, die dieses Setup enthält.
fr.DownloadPageDescription=Veuillez patienter pendant que l'installation télécharge les voix, campagnes et textes de la langue choisie. Si vous arrêtez le téléchargement, le jeu est installé avec les fichiers inclus dans ce programme d'installation.
; Localized files that are not installed from the download: %1 = list, one "DownloadFile..." line per file
DownloadIncomplete=Some localized files could not be installed from the download:%1%n%nThe setup installs its own versions of these files instead, so some content may not be translated.
de.DownloadIncomplete=Einige lokalisierte Dateien konnten nicht aus dem Download installiert werden:%1%n%nDas Setup installiert stattdessen seine eigenen Versionen dieser Dateien, daher sind einige Inhalte möglicherweise nicht übersetzt.
fr.DownloadIncomplete=Certains fichiers traduits n'ont pas pu être installés depuis le téléchargement :%1%n%nL'installation utilise ses propres versions de ces fichiers à la place, certains contenus pourraient donc ne pas être traduits.
; %1 = file, e.g. Empire Earth\Data\data.ssa
DownloadFileMissing=%1 (not downloaded)
de.DownloadFileMissing=%1 (nicht heruntergeladen)
fr.DownloadFileMissing=%1 (non téléchargé)
DownloadFileRejected=%1 (not the version this setup knows: updated on the server since or damaged, discarded)
de.DownloadFileRejected=%1 (nicht die Version, die dieses Setup kennt: inzwischen auf dem Server aktualisiert oder beschädigt, verworfen)
fr.DownloadFileRejected=%1 (pas la version connue de ce programme d'installation : mise à jour depuis sur le serveur ou endommagée, rejeté)
DownloadFileSkipped=%1 (download stopped, not downloaded)
de.DownloadFileSkipped=%1 (Download abgebrochen, nicht heruntergeladen)
fr.DownloadFileSkipped=%1 (téléchargement arrêté, non téléchargé)
DownloadFileUnsaved=%1 (downloaded, but it could not be stored for the installation)
de.DownloadFileUnsaved=%1 (heruntergeladen, konnte aber nicht für die Installation abgelegt werden)
fr.DownloadFileUnsaved=%1 (téléchargé, mais impossible de le stocker pour l'installation)
DownloadFileUnverifiable=%1 (program file, no verified version known to this setup, not downloaded)
de.DownloadFileUnverifiable=%1 (Programmdatei, diesem Setup ist keine geprüfte Version bekannt, nicht heruntergeladen)
fr.DownloadFileUnverifiable=%1 (fichier programme, aucune version vérifiée connue de ce programme d'installation, non téléchargé)

; Integrity manifest at the end of the installation (installstate.iss): title, description and
; status text of the progress page while the installed files are checked (CreateManifestProgressPage)
ManifestPageCaption=Checking the installed files
de.ManifestPageCaption=Installierte Dateien werden geprüft
fr.ManifestPageCaption=Vérification des fichiers installés
ManifestPageDescription=Please wait while the setup checks the installed files and records their checksums.
de.ManifestPageDescription=Bitte warten Sie, während das Setup die installierten Dateien prüft und ihre Prüfsummen speichert.
fr.ManifestPageDescription=Veuillez patienter pendant que l'installation vérifie les fichiers installés et enregistre leurs sommes de contrôle.
ManifestPageStatus=Checking the installed files...
de.ManifestPageStatus=Installierte Dateien werden geprüft...
fr.ManifestPageStatus=Vérification des fichiers installés...
; Installed files that were gone at the end of the installation (ReportMissingFiles): %1 = list, one
; line per file, at most ten, then FilesMissingAfterInstallMore; %2 = installation folder
FilesMissingAfterInstall=Some installed files were missing at the end of the installation:%1%n%nAntivirus programs often delete game files or move them to quarantine. Add an exception for the installation folder in your antivirus program:%n%2%n%nThen run this setup again for the same folder to repair the installation. Until then the game may not start or may be incomplete.
de.FilesMissingAfterInstall=Einige installierte Dateien fehlten am Ende der Installation:%1%n%nAntivirenprogramme löschen Spieldateien oft oder verschieben sie in die Quarantäne. Fügen Sie in Ihrem Antivirenprogramm eine Ausnahme für den Installationsordner hinzu:%n%2%n%nFühren Sie danach dieses Setup erneut für denselben Ordner aus, um die Installation zu reparieren. Bis dahin startet das Spiel möglicherweise nicht oder ist unvollständig.
fr.FilesMissingAfterInstall=Certains fichiers installés manquaient à la fin de l'installation :%1%n%nLes antivirus suppriment souvent des fichiers du jeu ou les mettent en quarantaine. Ajoutez une exception pour le dossier d'installation dans votre antivirus :%n%2%n%nRelancez ensuite ce programme d'installation pour le même dossier afin de réparer l'installation. D'ici là, le jeu risque de ne pas démarrer ou d'être incomplet.
; %1 = number of missing files not listed
FilesMissingAfterInstallMore=and %1 more
de.FilesMissingAfterInstallMore=und %1 weitere
fr.FilesMissingAfterInstallMore=et %1 autres

; Random Map Scripts of a setup up to v1.7.2 that this setup does not install again (randommaps.iss):
; %1 = backup folder, %2 = Random Map Scripts folder
RmsBackupKept=Random map scripts that this setup does not install (your own maps or maps of older versions) were moved to:%n%1%n%nTo play your own maps, copy them back to:%n%2
de.RmsBackupKept=Zufallskarten-Skripte, die dieses Setup nicht installiert (eigene Karten oder Karten älterer Versionen), wurden verschoben nach:%n%1%n%nUm Ihre eigenen Karten zu spielen, kopieren Sie sie zurück nach:%n%2
fr.RmsBackupKept=Les scripts de cartes aléatoires que ce programme d'installation n'installe pas (vos propres cartes ou des cartes d'anciennes versions) ont été déplacés vers :%n%1%n%nPour jouer avec vos propres cartes, copiez-les à nouveau dans :%n%2
RmsBackupNotRestored=The installation was not completed. Your random map scripts had been moved to:%n%1%n%nThey could not be moved back. To play your own maps, copy them back to:%n%2
de.RmsBackupNotRestored=Die Installation wurde nicht abgeschlossen. Ihre Zufallskarten-Skripte waren verschoben worden nach:%n%1%n%nSie konnten nicht zurückverschoben werden. Um Ihre eigenen Karten zu spielen, kopieren Sie sie zurück nach:%n%2
fr.RmsBackupNotRestored=L'installation n'a pas été terminée. Vos scripts de cartes aléatoires avaient été déplacés vers :%n%1%n%nIls n'ont pas pu être remis en place. Pour jouer avec vos propres cartes, copiez-les à nouveau dans :%n%2

; Tasks
TaskAdminStart=Always run the game as administrator, for all users (not recommended, only if the game does not work otherwise)
de.TaskAdminStart=Spiel immer als Administrator ausführen, für alle Benutzer (nicht empfohlen, nur falls das Spiel sonst nicht funktioniert)
fr.TaskAdminStart=Toujours lancer le jeu en tant qu'administrateur, pour tous les utilisateurs (déconseillé, uniquement si le jeu ne fonctionne pas autrement)
TaskFirewall=Allow the game through the Windows Firewall (incoming connections on all network types, needed to host games)
de.TaskFirewall=Spiel in der Windows-Firewall zulassen (eingehende Verbindungen in allen Netzwerktypen, nötig zum Hosten von Spielen)
fr.TaskFirewall=Autoriser le jeu dans le pare-feu Windows (connexions entrantes sur tous les types de réseau, nécessaire pour héberger des parties)
TaskCertInclude=Trust the Empire Earth Community certificate (adds it to the trusted publishers, only check this if you trust its publisher)
de.TaskCertInclude=Dem Zertifikat der Empire Earth Community vertrauen (fügt es den vertrauenswürdigen Herausgebern hinzu, nur auswählen, wenn Sie dem Herausgeber vertrauen)
fr.TaskCertInclude=Faire confiance au certificat de la communauté Empire Earth (l'ajoute aux éditeurs approuvés, à cocher uniquement si vous faites confiance à son éditeur)
TaskCompatibility=Enable compatibility flags
de.TaskCompatibility=Kompatibilitätseinstellungen aktivieren
fr.TaskCompatibility=Activer les options de compatibilité
; Opt-in task compatibility_legacy, only shown on Windows 7 (the same flags as TaskCompatibility)
TaskCompatibilityLegacy=Enable compatibility flags (optional on Windows 7: can help if the game looks blurry or does not fit on the screen with enlarged display scaling)
de.TaskCompatibilityLegacy=Kompatibilitätseinstellungen aktivieren (optional unter Windows 7: kann helfen, wenn das Spiel bei vergrößerter Anzeige unscharf aussieht oder nicht auf den Bildschirm passt)
fr.TaskCompatibilityLegacy=Activer les options de compatibilité (facultatif sous Windows 7 : peut aider si le jeu est flou ou ne tient pas à l'écran avec une mise à l'échelle de l'affichage agrandie)
TaskCompatibilityWindows=Enable earlier Windows compatibility mode
de.TaskCompatibilityWindows=Kompatibilitätsmodus für ältere Windows-Versionen aktivieren
fr.TaskCompatibilityWindows=Activer le mode de compatibilité avec une version antérieure de Windows
TaskDirectPlay=Install DirectPlay
de.TaskDirectPlay=DirectPlay installieren
fr.TaskDirectPlay=Installer DirectPlay
TaskDxWebSetup=Install DirectX End-User Runtime
de.TaskDxWebSetup=DirectX-Endbenutzer-Runtime installieren
fr.TaskDxWebSetup=Installer le runtime DirectX pour l'utilisateur final

; Installation types ([Types])
TypeFull=Full game install
de.TypeFull=Vollständige Installation
fr.TypeFull=Installation complète
TypeCompact=Compact game install
de.TypeCompact=Kompakte Installation
fr.TypeCompact=Installation compacte
TypeCustom=Custom game install
de.TypeCustom=Benutzerdefinierte Installation
fr.TypeCustom=Installation personnalisée
TypeRaw=Raw game install
de.TypeRaw=Nur das Spiel (ohne Zusätze)
fr.TypeRaw=Jeu seul (sans ajouts)

; Components ([Components]). Names of games, mods and content packs are not translated.
; CompByAuthor: %1 = content pack with its version, %2 = its authors
CompByAuthor=%1 (by %2)
de.CompByAuthor=%1 (von %2)
fr.CompByAuthor=%1 (par %2)
CompAdditional=Additional Recommended Content
de.CompAdditional=Empfohlene Zusatzinhalte
fr.CompAdditional=Contenu supplémentaire recommandé
CompMovies=Install intro videos
de.CompMovies=Intro-Videos installieren
fr.CompMovies=Installer les vidéos d'introduction
CompHD=HD/HQ Content
de.CompHD=HD/HQ-Inhalte
fr.CompHD=Contenu HD/HQ
CompDrexmod=dreXmod to enhance/add features (by Yukon)
de.CompDrexmod=dreXmod zum Verbessern und Erweitern von Funktionen (von Yukon)
fr.CompDrexmod=dreXmod pour améliorer/ajouter des fonctionnalités (par Yukon)
CompDrexmodV3=dreXmod v3 for better Camera/HUD/Lobby/Ranking/AntiCheat
de.CompDrexmodV3=dreXmod v3 für bessere Kamera/HUD/Lobby/Rangliste/Anti-Cheat
fr.CompDrexmodV3=dreXmod v3 pour une meilleure caméra/interface/lobby/classement/anti-triche
CompDrexmodV2=dreXmod v2 for better Camera/HUD/Lobby
de.CompDrexmodV2=dreXmod v2 für bessere Kamera/HUD/Lobby
fr.CompDrexmodV2=dreXmod v2 pour une meilleure caméra/interface/lobby
CompRms=Random Map Scripts
de.CompRms=Zufallskarten-Skripte
fr.CompRms=Scripts de cartes aléatoires
CompDxWrapper=DirectX Wrapper
de.CompDxWrapper=DirectX-Wrapper
fr.CompDxWrapper=Wrapper DirectX
; CompDxWrapperLevel: %1 = DirectX version, %2 = API (feature) level, %3 = dgVoodoo version
CompDxWrapperLevel=DirectX %1 API lvl %2 %3
de.CompDxWrapperLevel=DirectX %1 API-Level %2 %3
fr.CompDxWrapperLevel=DirectX %1 API niveau %2 %3
; Shown in brackets after a DirectX wrapper
CompTagLightest=Lightest
de.CompTagLightest=Am ressourcenschonendsten
fr.CompTagLightest=Le plus léger
CompTagMostCompatible=Most Compatible
de.CompTagMostCompatible=Am kompatibelsten
fr.CompTagMostCompatible=Le plus compatible
CompTagRecommended=Generally Recommended
de.CompTagRecommended=Allgemein empfohlen
fr.CompTagRecommended=Généralement recommandé
CompTagExperimental=Experimental
de.CompTagExperimental=Experimentell
fr.CompTagExperimental=Expérimental
CompTelemetry=Telemetry (Compatibility and Stats)
de.CompTelemetry=Telemetrie (Kompatibilität und Statistiken)
fr.CompTelemetry=Télémétrie (compatibilité et statistiques)
CompDiscord=Discord Presence
de.CompDiscord=Discord-Statusanzeige
fr.CompDiscord=Présence Discord
CompTools=Tools
de.CompTools=Werkzeuge
fr.CompTools=Outils
CompCivs=Civilizations
de.CompCivs=Zivilisationen
fr.CompCivs=Civilisations
CompCivsEcStandard=eC Standard Civilizations (25)
de.CompCivsEcStandard=eC-Standardzivilisationen (25)
fr.CompCivsEcStandard=Civilisations standard eC (25)
CompCivsEcFull=eC Full Civilizations (71)
de.CompCivsEcFull=Alle eC-Zivilisationen (71)
fr.CompCivsEcFull=Toutes les civilisations eC (71)
CompLanguage=Game Language
de.CompLanguage=Spielsprache
fr.CompLanguage=Langue du jeu
CompLanguageUpdate=Download localized voices and campaigns
de.CompLanguageUpdate=Lokalisierte Sprachausgabe und Kampagnen herunterladen
fr.CompLanguageUpdate=Télécharger les voix et les campagnes traduites

; Status texts while installing ([Run], [UninstallRun]); StatusFirewall*: %1 = game
StatusCertificate=Adding the Empire Earth Community certificate to the trusted publishers
de.StatusCertificate=Zertifikat der Empire Earth Community wird den vertrauenswürdigen Herausgebern hinzugefügt
fr.StatusCertificate=Ajout du certificat de la communauté Empire Earth aux éditeurs approuvés
StatusDirectPlay=Installing DirectPlay
de.StatusDirectPlay=DirectPlay wird installiert
fr.StatusDirectPlay=Installation de DirectPlay
StatusFirewallRemove=Removing %1 in Firewall
de.StatusFirewallRemove=%1 wird aus der Firewall entfernt
fr.StatusFirewallRemove=Suppression des règles du pare-feu pour %1
StatusFirewallOpen=Opening %1 in Firewall
de.StatusFirewallOpen=%1 wird in der Firewall freigegeben
fr.StatusFirewallOpen=Autorisation dans le pare-feu pour %1
StatusDxWebSetup=Installing legacy DirectX End-User Runtime...
de.StatusDxWebSetup=Ältere DirectX-Endbenutzer-Runtime wird installiert...
fr.StatusDxWebSetup=Installation de l'ancien runtime DirectX pour l'utilisateur final...

; Test builds only (TestID > 0): %1 = test id, %2 = setup version, %3 = game version
TestSetupWarning=THIS IS A TEST SETUP ID = %1 [Setup v%2 - Game v%3]%nPLEASE USE THIS INSTALLER ONLY FOR TESTING%nDO >>NOT<< SHARE IT!
de.TestSetupWarning=DIES IST EIN TEST-SETUP, ID = %1 [Setup v%2 - Spiel v%3]%nBITTE VERWENDEN SIE DIESES INSTALLATIONSPROGRAMM NUR ZUM TESTEN%nGEBEN SIE ES >>NICHT<< WEITER!
fr.TestSetupWarning=CECI EST UN PROGRAMME D'INSTALLATION DE TEST, ID = %1 [Setup v%2 - Jeu v%3]%nUTILISEZ-LE UNIQUEMENT POUR DES TESTS%nNE LE PARTAGEZ >>PAS<< !

#if InstallType == "NeoEE"
TaskNeoEECDKeys=Register NeoEE CDKeys (Required to use the online lobby)
de.TaskNeoEECDKeys=NeoEE-CD-Keys registrieren (für die Online-Lobby erforderlich)
fr.TaskNeoEECDKeys=Enregistrer les clés CD NeoEE (nécessaire pour utiliser le lobby en ligne)
; NeoEE setups under Wine (InitializeSetup)
WineNeoEEGuiDisabled=Wine detected!%nThe NeoEE connection GUI makes the game crash under Wine because it uses GDI/GDI+, so it will be disabled.%nIf you install GDI+ with Winetricks, you can enable the GUI again in NeoEE.cfg.
de.WineNeoEEGuiDisabled=Wine erkannt!%nDie NeoEE-Verbindungsoberfläche bringt das Spiel unter Wine zum Absturz, weil sie GDI/GDI+ verwendet, daher wird sie deaktiviert.%nWenn Sie GDI+ mit Winetricks installieren, können Sie die Oberfläche in NeoEE.cfg wieder aktivieren.
fr.WineNeoEEGuiDisabled=Wine détecté !%nL'interface de connexion NeoEE fait planter le jeu sous Wine car elle utilise GDI/GDI+, elle sera donc désactivée.%nSi vous installez GDI+ avec Winetricks, vous pouvez la réactiver dans NeoEE.cfg.
; NeoEE CD keys (RegisterCDKeys); CDKeysPathUnsupported: %1 = installation folder,
; CDKeysErrorUnknown: %1 = exit code of authtools.dll
CDKeysStatusEE=Registering the NeoEE CD key for Empire Earth...
de.CDKeysStatusEE=NeoEE-CD-Key für Empire Earth wird registriert...
fr.CDKeysStatusEE=Enregistrement de la clé CD NeoEE pour Empire Earth...
CDKeysStatusEEAoC=Registering the NeoEE CD keys for Empire Earth and The Art of Conquest...
de.CDKeysStatusEEAoC=NeoEE-CD-Keys für Empire Earth und The Art of Conquest werden registriert...
fr.CDKeysStatusEEAoC=Enregistrement des clés CD NeoEE pour Empire Earth et The Art of Conquest...
CDKeysWine=You are using Wine: for security reasons the NeoEE CD keys cannot be generated there (this may be supported later).%nFor now, contact the Reborn or NeoEE developers to get a key for your Wine installation.
de.CDKeysWine=Sie verwenden Wine: Aus Sicherheitsgründen können die NeoEE-CD-Keys dort nicht erzeugt werden (das wird eventuell später unterstützt).%nWenden Sie sich vorerst an die Reborn- oder NeoEE-Entwickler, um einen Key für Ihre Wine-Installation zu erhalten.
fr.CDKeysWine=Vous utilisez Wine : pour des raisons de sécurité, les clés CD NeoEE ne peuvent pas y être générées (cela sera peut-être possible plus tard).%nPour le moment, contactez les développeurs de Reborn ou de NeoEE pour obtenir une clé pour votre installation Wine.
CDKeysToolMissing=The file used to generate the NeoEE CD keys could not be loaded, it was probably removed by your anti-virus. Without the keys the game cannot be played on NeoEE.%nPlease disable your anti-virus and install NeoEE again.
de.CDKeysToolMissing=Die Datei zum Erzeugen der NeoEE-CD-Keys konnte nicht geladen werden, wahrscheinlich wurde sie von Ihrem Antivirenprogramm entfernt. Ohne die Keys kann das Spiel nicht auf NeoEE gespielt werden.%nBitte deaktivieren Sie Ihr Antivirenprogramm und installieren Sie NeoEE erneut.
fr.CDKeysToolMissing=Le fichier servant à générer les clés CD NeoEE n'a pas pu être chargé, il a probablement été supprimé par votre antivirus. Sans les clés, le jeu ne peut pas être utilisé sur NeoEE.%nVeuillez désactiver votre antivirus et réinstaller NeoEE.
CDKeysPathUnsupported=The NeoEE CD keys cannot be registered for this installation folder:%n%1%nThe CD key tool does not support folders containing a comma or characters outside the system code page. Install NeoEE into another folder to use the online lobby.
de.CDKeysPathUnsupported=Die NeoEE-CD-Keys können für diesen Installationsordner nicht registriert werden:%n%1%nDas CD-Key-Werkzeug unterstützt keine Ordner mit Komma oder mit Zeichen außerhalb der System-Codepage. Installieren Sie NeoEE in einen anderen Ordner, um die Online-Lobby zu nutzen.
fr.CDKeysPathUnsupported=Les clés CD NeoEE ne peuvent pas être enregistrées pour ce dossier d'installation :%n%1%nL'outil des clés CD ne prend pas en charge les dossiers contenant une virgule ou des caractères hors de la page de code du système. Installez NeoEE dans un autre dossier pour utiliser le lobby en ligne.
CDKeysErrorVM=Unable to install the CD keys: virtual machine detected.%nContact the Reborn or NeoEE developers to get a key for your virtual machine.
de.CDKeysErrorVM=Die CD-Keys konnten nicht installiert werden: virtuelle Maschine erkannt.%nWenden Sie sich an die Reborn- oder NeoEE-Entwickler, um einen Key für Ihre virtuelle Maschine zu erhalten.
fr.CDKeysErrorVM=Impossible d'installer les clés CD : machine virtuelle détectée.%nContactez les développeurs de Reborn ou de NeoEE pour obtenir une clé pour votre machine virtuelle.
CDKeysErrorGeneral=Unable to install the CD keys: general/unknown error.
de.CDKeysErrorGeneral=Die CD-Keys konnten nicht installiert werden: allgemeiner/unbekannter Fehler.
fr.CDKeysErrorGeneral=Impossible d'installer les clés CD : erreur générale/inconnue.
CDKeysErrorNetwork=Unable to install the CD keys: network error.%nIf you installed NeoEE very recently, this error is normal.
de.CDKeysErrorNetwork=Die CD-Keys konnten nicht installiert werden: Netzwerkfehler.%nWenn Sie NeoEE erst vor Kurzem installiert haben, ist dieser Fehler normal.
fr.CDKeysErrorNetwork=Impossible d'installer les clés CD : erreur réseau.%nSi vous avez installé NeoEE très récemment, cette erreur est normale.
CDKeysErrorRegistry=Unable to install the CD keys: registry error.
de.CDKeysErrorRegistry=Die CD-Keys konnten nicht installiert werden: Fehler in der Registrierung.
fr.CDKeysErrorRegistry=Impossible d'installer les clés CD : erreur de registre.
CDKeysErrorSyntax=Unable to install the CD keys: syntax error.
de.CDKeysErrorSyntax=Die CD-Keys konnten nicht installiert werden: Syntaxfehler.
fr.CDKeysErrorSyntax=Impossible d'installer les clés CD : erreur de syntaxe.
CDKeysErrorProtection=Unable to install the CD keys: protection error.
de.CDKeysErrorProtection=Die CD-Keys konnten nicht installiert werden: Schutzfehler.
fr.CDKeysErrorProtection=Impossible d'installer les clés CD : erreur de protection.
CDKeysErrorUnknown=Unknown error while installing the CD keys!%nCode: %1
de.CDKeysErrorUnknown=Unbekannter Fehler beim Installieren der CD-Keys!%nCode: %1
fr.CDKeysErrorUnknown=Erreur inconnue lors de l'installation des clés CD !%nCode : %1
#endif

; Sound Control
; Since our custom button isn't auto scaled to content
; better keep Mute / Unmute, tiny and everyone should understand
SoundCtrlButtonCaptionSoundOn=Unmute
SoundCtrlButtonCaptionSoundOff=Mute

; Setup Custom Page
; Manual / Custom install page
MIQP_Title=Select the desired installation mode
de.MIQP_Title=Wählen Sie den gewünschten Installationsmodus
es.MIQP_Title=Seleccione el modo de instalación deseado
fr.MIQP_Title=Sélectionnez le mode d'installation souhaité
it.MIQP_Title=Selezionare la modalità di installazione desiderata
ko.MIQP_Title=원하는 설치 모드를 선택하십시오.
pl.MIQP_Title=Wybierz pożądany tryb instalacji
ru.MIQP_Title=Выберите нужный режим установки
zh_CN.MIQP_Title=选择所需的安装模式
zh_TW.MIQP_Title=选择所需的安装模式

MIQP_Desc=Do you want to use the default or your own install settings?
de.MIQP_Desc=Möchten Sie die Standardeinstellungen oder Ihre eigenen Installationseinstellungen verwenden?
es.MIQP_Desc=¿Quiere usar la instalación predeterminada o personalizada?
fr.MIQP_Desc=Voulez-vous utiliser les paramètres par défaut ou vos propres paramètres d'installation ?
it.MIQP_Desc=Vuoi usare le impostazioni di default o le tue impostazioni di installazione?
ko.MIQP_Desc=기본 또는 자체 설치 설정을 사용하시겠습니까?
pl.MIQP_Desc=Czy chcesz użyć domyślnych opcji instalacji, czy wybrać własne?
ru.MIQP_Desc=Вы хотите использовать настройки по умолчанию или собственные настройки установки?
zh_CN.MIQP_Desc=你想使用默认的还是你自己的安装设置？
zh_TW.MIQP_Desc=你想使用默认的还是你自己的安装设置？

MIQP_Content=Choose whether you prefer to use the default settings or use more advanced settings that you select manually from those offered in the installer.
de.MIQP_Content=Wählen Sie aus, ob Sie die Standardeinstellungen oder die erweiterten Einstellungen verwenden möchten, welche Sie manuell aus dem Angebot des Installationsassistenten selektieren müssen.
es.MIQP_Content=Elija si prefiere usar las opciones predeterminadas o las opciones más avanzadas donde podrá seleccionar manualmente de entre las ofrecidas por el instalador.
fr.MIQP_Content=Choisissez si vous préférez utiliser les paramètres par défaut ou des paramètres plus avancés que vous sélectionnez manuellement parmi ceux proposés dans le programme d'installation.
it.MIQP_Content=Scegliete se preferite usare le impostazioni predefinite o usare impostazioni più avanzate che selezionate manualmente tra quelle offerte nel programma di installazione.
ko.MIQP_Content=기본 설정을 사용할지 또는 설치 관리자에서 제공하는 설정 중에서 수동으로 선택하는 고급 설정을 사용할지 선택합니다.
pl.MIQP_Content=Wybierz czy preferujesz użycie domyślnych opcji instalacji, czy bardziej zaawansowanych, które pozwolą ręcznie wybrać komponenty.
ru.MIQP_Content=Выберите, хотите ли вы использовать настройки по умолчанию или использовать более продвинутые настройки, которые вы выбираете вручную из предложенных в программе установки.
zh_CN.MIQP_Content=选择你是喜欢使用默认设置，还是使用你从安装程序提供的设置中手动选择的更高级设置。
zh_TW.MIQP_Content=选择你是喜欢使用默认设置，还是使用你从安装程序提供的设置中手动选择的更高级设置。

MIQP_Recommended=Recommended settings
de.MIQP_Recommended=Empfohlene Einstellungen
es.MIQP_Recommended=Opciones recomendadas
fr.MIQP_Recommended=Paramètres recommandés
it.MIQP_Recommended=Impostazioni raccomandate
ko.MIQP_Recommended=명령된 설정
pl.MIQP_Recommended=Zalecane ustawienia
ru.MIQP_Recommended=Рекомендуемые настройки
zh_CN.MIQP_Recommended=建议的设置
zh_TW.MIQP_Recommended=建议的设置

MIQP_Recommended_EE=Install Empire Earth
de.MIQP_Recommended_EE=Installiere Empire Earth
es.MIQP_Recommended_EE=Instalar Empire Earth
fr.MIQP_Recommended_EE=Installer Empire Earth
it.MIQP_Recommended_EE=Installare Empire Earth
ko.MIQP_Recommended_EE=Empire Earth 설치
pl.MIQP_Recommended_EE=Zainstaluj Empire Earth
ru.MIQP_Recommended_EE=Установите Empire Earth
zh_CN.MIQP_Recommended_EE=安装 Empire Earth
zh_TW.MIQP_Recommended_EE=安装 Empire Earth

MIQP_Recommended_EE_AoC=Install Empire Earth and The Art of Conquest Expansion
de.MIQP_Recommended_EE_AoC=Installiere Empire Earth und Die Kunst der Eroberungen - Erweiterung
es.MIQP_Recommended_EE_AoC=Instalar Empire Earth y la expansión The Art of Conquest
fr.MIQP_Recommended_EE_AoC=Installer Empire Earth et l'extension The Art of Conquest
it.MIQP_Recommended_EE_AoC=Installare Empire Earth e The Art of Conquest Expansion
ko.MIQP_Recommended_EE_AoC=Empire Earth 와 The Art of Conquest 확장 설치
pl.MIQP_Recommended_EE_AoC=Zainstaluj Empire Earth wraz z dodatkiem The Art of Conquest
ru.MIQP_Recommended_EE_AoC=Установите Empire Earth и расширение The Art of Conquest
zh_CN.MIQP_Recommended_EE_AoC=安装 Empire Earth 和 The Art of Conquest 扩展版
zh_TW.MIQP_Recommended_EE_AoC=安装 Empire Earth 和 The Art of Conquest 扩展版

MIQP_Custom=Custom install settings
de.MIQP_Custom=Benutzerdefinierte Installationseinstellungen
es.MIQP_Custom=Opciones personalizadas de instalación
fr.MIQP_Custom=Paramètres d'installation personnalisés
it.MIQP_Custom=Impostazioni di installazione personalizzate
ko.MIQP_Custom=사용자 지정 설치 설정
pl.MIQP_Custom=Ręczne ustawienia instalacji
ru.MIQP_Custom=Пользовательские настройки установки
zh_CN.MIQP_Custom=自定义安装设置
zh_TW.MIQP_Custom=自定义安装设置

MIQP_Repair=Repair current installation
de.MIQP_Repair=Vorhandene Installation reparieren
es.MIQP_Repair=Reparar instalación actual
fr.MIQP_Repair=Réparer l'installation actuelle
it.MIQP_Repair=Riparare l'installazione corrente
ko.MIQP_Repair=현재 설치 복구
pl.MIQP_Repair=Napraw istniejącą instalację
ru.MIQP_Repair=Ремонт текущей установки
zh_CN.MIQP_Repair=修复当前的安装
zh_TW.MIQP_Repair=修复当前的安装

MIQP_Update=Update current installation
de.MIQP_Update=Aktuelle Installation aktualisieren
es.MIQP_Update=Actualizar la instalación actual
fr.MIQP_Update=Mise à jour de l'installation actuelle
it.MIQP_Update=Aggiornare l'installazione corrente
ko.MIQP_Update=현재 설치 업데이트
pl.MIQP_Update=Aktualizacja bieżącej instalacji
ru.MIQP_Update=Обновление текущей установки
zh_CN.MIQP_Update=更新当前安装
zh_TW.MIQP_Update=更新目前安裝

MIQP_Telemetry=Allow telemetry to improve the game compatibility and follow its evolution.
de.MIQP_Telemetry=Ermöglichen Sie Telemetrie, um die Kompatibilität des Spiels zu verbessern und seine Entwicklung zu verfolgen.
es.MIQP_Telemetry=Permite que la telemetría mejore la compatibilidad del juego y siga su evolución.
fr.MIQP_Telemetry=Autorisez la télémétrie pour améliorer la compatibilité du jeu et suivre son évolution.
it.MIQP_Telemetry=Consenti alla telemetria di migliorare la compatibilità del gioco e seguirne l'evoluzione.
ko.MIQP_Telemetry=원격 분석을 허용하여 게임 호환성을 개선하고 진화를 따릅니다.
pl.MIQP_Telemetry=Zezwalaj telemetrii na poprawę zgodności gry i śledzenie jej ewolucji.
ru.MIQP_Telemetry=Разрешите телеметрию, чтобы улучшить совместимость игр и следить за ее эволюцией.
zh_CN.MIQP_Telemetry=允许遥测来提高游戏兼容性并遵循其演变。
zh_TW.MIQP_Telemetry=允許遙測來提高遊戲相容性並遵循其演變。

; GPU vendor install page
GPUIQP_Title=Select your graphics card (GPU) brand
de.GPUIQP_Title=Wählen Sie Ihren Grafikkartenhersteller aus
es.GPUIQP_Title=Seleccione la marca de su tarjeta de video (GPU)
fr.GPUIQP_Title=Sélectionnez la marque de votre carte graphique (GPU)
it.GPUIQP_Title=Seleziona la marca della tua scheda grafica (GPU)
ko.GPUIQP_Title=그래픽 카드(GPU) 브랜드 선택
pl.GPUIQP_Title=Wybierz producenta swojej karty graficznej (GPU)
ru.GPUIQP_Title=Выберите марку вашей видеокарты (GPU)
zh_CN.GPUIQP_Title=选择你的显卡（GPU）品牌
zh_TW.GPUIQP_Title=选择你的显卡（GPU）品牌

GPUIQP_Desc=In this step the setup will try to apply parameters for your graphics card.
de.GPUIQP_Desc=Auf diese Art und Weise wird der Installationsassistent versuchen, geeignete Kompatibilitätseinstellungen für Ihre Grafikkarte zu übernehmen.
es.GPUIQP_Desc=De esta manera el instalador intentará aplicar los parámetros que se ajusten a su tarjeta de video.
fr.GPUIQP_Desc=De cette façon, l'installation essaiera d'appliquer des paramètres pour votre carte graphique.
it.GPUIQP_Desc=In questo modo il setup cercherà di applicare i parametri per la vostra scheda grafica.
ko.GPUIQP_Desc=이런 식으로 설치 프로그램은 그래픽 카드에 매개 변수를 적용하려고합니다.
pl.GPUIQP_Desc=Na tym etapie, program instalacyjny spróbuje zastosować parametry dla Twojej karty graficznej.
ru.GPUIQP_Desc=Таким образом, установка попытается применить параметры для вашей видеокарты.
zh_CN.GPUIQP_Desc=通过这种方式，设置将尝试应用你的显卡参数。
zh_TW.GPUIQP_Desc=通过这种方式，设置将尝试应用你的显卡参数。

GPUIQP_Content=Choose the brand of the main graphics card for this computer. This way the installer will try to apply the compatibility settings for it. \
%nIf this is not your first installation and the previous one did not work, you can try the other modes even if they do not match your graphics card brand or perform a manual installation to get access to all installation settings.
de.GPUIQP_Content=Wählen Sie den Hersteller Ihrer primären Grafikkarte für diesen Computer aus. Der Installationsassistent wird versuchen, geeignete Kompatibilitätseinstellungen zu übernehmen. \
%nSollte dies nicht Ihre erste Installation sein und die vorherige nicht erfolgreich war, können Sie die anderen Installationsmodi ausprobieren, selbst wenn diese nicht mit Ihrem Grafikkartenhersteller übereinstimmen. Sie können ebenfalls eine manuelle Installation durchführen, um Zugriff auf alle Installationseinstellungen zu erhalten.
es.GPUIQP_Content=Seleccione la marca de la tarjeta de video principal de este computador. De esta forma el instalador intentará aplicar las opciones de compatibilidad correctas. \
%nSi ésta no es su primera instalación y la anterior no funcionó, puede intentar los otros modos incluso si no coinciden con la marca de su tarjeta de video o intentar una instalación manual para obtener acceso a todas las opciones de instalación.
fr.GPUIQP_Content=Choisissez la marque de la carte graphique principale de cet ordinateur, de cette façon, le programme d'installation essaiera d'appliquer les paramètres de compatibilité pour celle-ci. \
%nSi ce n'est pas votre première installation et que la précédente n'a pas fonctionné, vous pouvez essayer les autres modes même s'ils ne correspondent pas à la marque de votre carte graphique ou effectuer une installation manuelle pour avoir accès à tous les paramètres d'installation.
it.GPUIQP_Content=Scegliete la marca della scheda grafica principale di questo computer. In questo modo il programma di installazione cercherà di applicare le impostazioni di compatibilità per essa. \
%nSe questa non è la tua prima installazione e la precedente non ha funzionato, puoi provare le altre modalità anche se non corrispondono alla marca della tua scheda grafica o eseguire un'installazione manuale per avere accesso a tutte le impostazioni di installazione.
ko.GPUIQP_Content=이 컴퓨터의 기본 그래픽 카드 브랜드를 선택합니다. 이렇게하면 설치 관리자가 호환성 설정을 적용하려고합니다. \
%n첫 번째 설치가 아니고 이전 모드가 작동하지 않는 경우 그래픽 카드 브랜드와 일치하지 않더라도 다른 모드를 시도하거나 수동 설치를 수행하여 모든 설치 설정에 액세스할 수 있습니다.
pl.GPUIQP_Content=Wybierz producenta Twojej głównej karty graficznej zainstalowanej w komputerze. Na tym etapie, instalator spróbuje zastosować dla niej opcje kompatybilności. \
%nJeśli nie jest to Twoja pierwsza próba instalacji, a poprzednie nie powiodły się - możesz spróbować innych trybów, nawet jeśli nie są bezpośrednio przeznaczone dla modelu Twojej karty graficznej. Możesz również przeprowadzić ręczny tryb instalacji, dający możliwość wyboru wszystkich zaawansowanych ustawień samodzielnie.
ru.GPUIQP_Content=Выберите марку основной видеокарты для этого компьютера. Таким образом, программа установки попытается применить настройки совместимости для нее. \
%nЕсли это не первая установка и предыдущая не сработала, вы можете попробовать другие режимы, даже если они не соответствуют марке вашей видеокарты, или выполнить ручную установку, чтобы получить доступ ко всем настройкам установки.
zh_CN.GPUIQP_Content=选择这台电脑的主显卡的品牌。这样，安装程序将尝试为其应用兼容性设置。 \
%n如果这不是你的第一次安装，而且之前的安装没有成功，你可以尝试其他模式，即使它们与你的显卡品牌不匹配，或者执行手动安装以获得所有安装设置。
zh_TW.GPUIQP_Content=选择这台电脑的主显卡的品牌。这样，安装程序将尝试为其应用兼容性设置。 \
%n如果这不是你的第一次安装，而且之前的安装没有成功，你可以尝试其他模式，即使它们与你的显卡品牌不匹配，或者执行手动安装以获得所有安装设置。

GPUIQP_NVIDIA=NVIDIA
de.GPUIQP_NVIDIA=NVIDIA
es.GPUIQP_NVIDIA=NVIDIA
fr.GPUIQP_NVIDIA=NVIDIA
it.GPUIQP_NVIDIA=NVIDIA
ko.GPUIQP_NVIDIA=NVIDIA
pl.GPUIQP_NVIDIA=NVIDIA
ru.GPUIQP_NVIDIA=NVIDIA
zh_CN.GPUIQP_NVIDIA=NVIDIA
zh_TW.GPUIQP_NVIDIA=NVIDIA

GPUIQP_AMD=AMD
de.GPUIQP_AMD=AMD
es.GPUIQP_AMD=AMD
fr.GPUIQP_AMD=AMD
it.GPUIQP_AMD=AMD
ko.GPUIQP_AMD=AMD
pl.GPUIQP_AMD=AMD
ru.GPUIQP_AMD=AMD
zh_CN.GPUIQP_AMD=AMD
zh_TW.GPUIQP_AMD=AMD

GPUIQP_Intel=Intel HD Series
de.GPUIQP_Intel=Intel HD Series
es.GPUIQP_Intel=Intel HD Series
fr.GPUIQP_Intel=Intel HD Series
it.GPUIQP_Intel=Intel HD Series
ko.GPUIQP_Intel=Intel HD Series
pl.GPUIQP_Intel=Intel HD Series
ru.GPUIQP_Intel=Intel HD Series
zh_CN.GPUIQP_Intel=Intel HD Series
zh_TW.GPUIQP_Intel=Intel HD Series

GPUIQP_Default=I don't know
de.GPUIQP_Default=Ich weiß es nicht
es.GPUIQP_Default=No lo sé
fr.GPUIQP_Default=Je ne sais pas
it.GPUIQP_Default=Non so
ko.GPUIQP_Default=몰라요
pl.GPUIQP_Default=Nie wiem
ru.GPUIQP_Default=Я не знаю.
zh_CN.GPUIQP_Default=我不知道
zh_TW.GPUIQP_Default=我不知道

; GPU option without DirectX wrapper
GPUIQP_Native=Native
de.GPUIQP_Native=Nativ
fr.GPUIQP_Native=Natif
; DirectX wrapper of a GPU option: %1 = DirectX version and API level, e.g. "11 API 10.1"
GPUIQP_Wrapper=DirectX Wrapper %1
de.GPUIQP_Wrapper=DirectX-Wrapper %1
fr.GPUIQP_Wrapper=wrapper DirectX %1

; Language install page
LIQP_Title=Select the game language to install
de.LIQP_Title=Wählen Sie die Sprache des Spiels aus, die Sie installieren möchten
es.LIQP_Title=Selecciona el idioma del juego que deseas instalar
fr.LIQP_Title=Sélectionnez la langue du jeu à installer
it.LIQP_Title=Seleziona la lingua del gioco da installare
ko.LIQP_Title=설치할 게임 언어를 선택하십시오
pl.LIQP_Title=Wybierz język gry do zainstalowania
pt_BR.LIQP_Title=Selecione o idioma do jogo para instalar
ru.LIQP_Title=Выберите язык игры для установки
zh_CN.LIQP_Title=选择要安装的游戏语言
zh_TW.LIQP_Title=選擇要安裝的遊戲語言

LIQP_Desc=Select the language you want to install. The game don't have any option to change the language after the installation. \
So, if you want to change the language, you will have to reinstall the game.
de.LIQP_Desc=Wählen Sie die Sprache aus, die Sie installieren möchten. Das Spiel hat keine Option, um die Sprache nach der Installation zu ändern. \
Wenn Sie die Sprache ändern möchten, müssen Sie das Spiel neu installieren.
es.LIQP_Desc=Selecciona el idioma del juego que deseas instalar. El juego no tiene ninguna opción para cambiar el idioma después de la instalación. \
Por lo tanto, si deseas cambiar el idioma, deberás reinstalar el juego.
fr.LIQP_Desc=Sélectionnez la langue que vous souhaitez installer. Le jeu n'a aucune option pour changer la langue après l'installation. \
Donc, si vous souhaitez changer de langue, vous devrez réinstaller le jeu.
it.LIQP_Desc=Seleziona la lingua del gioco che vuoi installare. Il gioco non ha alcuna opzione per cambiare la lingua dopo l'installazione. \
Quindi, se vuoi cambiare lingua, dovrai reinstallare il gioco.
ko.LIQP_Desc=설치할 언어를 선택하십시오. 게임은 설치 후에 언어를 변경할 수 있는 옵션이 없습니다. \
따라서 언어를 변경하려면 게임을 다시 설치해야합니다.
pl.LIQP_Desc=Wybierz język, który chcesz zainstalować. Gra nie ma żadnej opcji zmiany języka po instalacji. \
Więc, jeśli chcesz zmienić język, będziesz musiał ponownie zainstalować grę.
pt_BR.LIQP_Desc=Selecione o idioma que você deseja instalar. O jogo não tem nenhuma opção para alterar o idioma após a instalação. \
Portanto, se você quiser mudar o idioma, você terá que reinstalar o jogo.
ru.LIQP_Desc=Выберите язык, который вы хотите установить. В игре нет никакой возможности изменить язык после установки. \
Поэтому, если вы хотите изменить язык, вам придется переустановить игру.
zh_CN.LIQP_Desc=选择要安装的语言。游戏在安装后没有任何更改语言的选项。 \
因此，如果您想更改语言，您将不得不重新安装游戏。
zh_TW.LIQP_Desc=選擇要安裝的語言。遊戲在安裝後沒有任何更改語言的選項。 \
因此，如果您想更改語言，您將不得不重新安裝遊戲。

LIQP_en=English
de.LIQP_en=Englisch (English)
es.LIQP_en=Inglés (English)
fr.LIQP_en=Anglais (English)
it.LIQP_en=Inglese (English)
ko.LIQP_en=영어 (English)
pl.LIQP_en=Angielski (English)
pt_BR.LIQP_en=Inglês (English)
ru.LIQP_en=Английский (English)
zh_CN.LIQP_en=英语 (English)
zh_TW.LIQP_en=英語 (English)

LIQP_fr=French (Français)
de.LIQP_fr=Französisch (Français)
es.LIQP_fr=Francés (Français)
fr.LIQP_fr=Français
it.LIQP_fr=Francese (Français)
ko.LIQP_fr=프랑스어 (Français)
pl.LIQP_fr=Francuski (Français)
pt_BR.LIQP_fr=Francês (Français)
ru.LIQP_fr=Французский (Français)
zh_CN.LIQP_fr=法语 (Français)
zh_TW.LIQP_fr=法語 (Français)

LIQP_de=German (Deutsch)
de.LIQP_de=Deutsch
es.LIQP_de=Alemán (Deutsch)
fr.LIQP_de=Allemand (Deutsch)
it.LIQP_de=Tedesco (Deutsch)
ko.LIQP_de=독일어 (Deutsch)
pl.LIQP_de=Niemiecki (Deutsch)
pt_BR.LIQP_de=Alemão (Deutsch)
ru.LIQP_de=Немецкий (Deutsch)
zh_CN.LIQP_de=德语 (Deutsch)
zh_TW.LIQP_de=德語 (Deutsch)

LIQP_it=Italian (Italiano)
de.LIQP_it=Italienisch (Italiano)
es.LIQP_it=Italiano (Italiano)
fr.LIQP_it=Italien (Italiano)
it.LIQP_it=Italiano
ko.LIQP_it=이탈리아어 (Italiano)
pl.LIQP_it=Włoski (Italiano)
pt_BR.LIQP_it=Italiano (Italiano)
ru.LIQP_it=Итальянский (Italiano)
zh_CN.LIQP_it=意大利语 (Italiano)
zh_TW.LIQP_it=意大利語 (Italiano)

LIQP_es=Spanish (Español)
de.LIQP_es=Spanisch (Español)
es.LIQP_es=Español
fr.LIQP_es=Espagnol (Español)
it.LIQP_es=Spagnolo (Español)
ko.LIQP_es=스페인어 (Español)
pl.LIQP_es=Hiszpański (Español)
pt_BR.LIQP_es=Espanhol (Español)
ru.LIQP_es=Испанский (Español)
zh_CN.LIQP_es=西班牙语 (Español)
zh_TW.LIQP_es=西班牙語 (Español)

LIQP_ru=Russian (Русский)
de.LIQP_ru=Russisch (Русский)
es.LIQP_ru=Ruso (Русский)
fr.LIQP_ru=Russe (Русский)
it.LIQP_ru=Russo (Русский)
ko.LIQP_ru=러시아어 (Русский)
pl.LIQP_ru=Rosyjski (Русский)
pt_BR.LIQP_ru=Russo (Русский)
ru.LIQP_ru=Русский
zh_CN.LIQP_ru=俄语 (Русский)
zh_TW.LIQP_ru=俄語 (Русский)

LIQP_pl=Polish (Polski)
de.LIQP_pl=Polnisch (Polski)
es.LIQP_pl=Polaco (Polski)
fr.LIQP_pl=Polonais (Polski)
it.LIQP_pl=Polacco (Polski)
ko.LIQP_pl=폴란드어 (Polski)
pl.LIQP_pl=Polski
pt_BR.LIQP_pl=Polonês (Polski)
ru.LIQP_pl=Польский (Polski)
zh_CN.LIQP_pl=波兰语 (Polski)
zh_TW.LIQP_pl=波蘭語 (Polski)

LIQP_pt_BR=Brazilian Portuguese (Português brasileiro)
de.LIQP_pt_BR=Brasilianisches Portugiesisch (Português brasileiro)
es.LIQP_pt_BR=Portugués brasileño (Português brasileiro)
fr.LIQP_pt_BR=Portugais brésilien (Português brasileiro)
it.LIQP_pt_BR=Portoghese brasiliano (Português brasileiro)
ko.LIQP_pt_BR=브라질 포르투갈어 (Português brasileiro)
pl.LIQP_pt_BR=Portugalski (Português brasileiro)
pt_BR.LIQP_pt_BR=Português brasileiro
ru.LIQP_pt_BR=Бразильский португальский (Português brasileiro)
zh_CN.LIQP_pt_BR=巴西葡萄牙语 (Português brasileiro)
zh_TW.LIQP_pt_BR=巴西葡萄牙語 (Português brasileiro)

LIQP_zh_CN=Chinese Simplified (简体中文)
de.LIQP_zh_CN=Chinesisch (简体中文)
es.LIQP_zh_CN=Chino simplificado (简体中文)
fr.LIQP_zh_CN=Chinois simplifié (简体中文)
it.LIQP_zh_CN=Cinese semplificato (简体中文)
ko.LIQP_zh_CN=중국어 간체 (简体中文)
pl.LIQP_zh_CN=Chiński uproszczony (简体中文)
pt_BR.LIQP_zh_CN=Chinês simplificado (简体中文)
ru.LIQP_zh_CN=Китайский упрощенный (简体中文)
zh_CN.LIQP_zh_CN=简体中文
zh_TW.LIQP_zh_CN=簡體中文

LIQP_zh_TW=Chinese Traditional (繁體中文)
de.LIQP_zh_TW=Chinesisch (繁體中文)
es.LIQP_zh_TW=Chino tradicional (繁體中文)
fr.LIQP_zh_TW=Chinois traditionnel (繁體中文)
it.LIQP_zh_TW=Cinese tradizionale (繁體中文)
ko.LIQP_zh_TW=중국어 번체 (繁體中文)
pl.LIQP_zh_TW=Chiński tradycyjny (繁體中文)
pt_BR.LIQP_zh_TW=Chinês tradicional (繁體中文)
ru.LIQP_zh_TW=Китайский традиционный (繁體中文)
zh_CN.LIQP_zh_TW=繁体中文
zh_TW.LIQP_zh_TW=繁體中文

LIQP_ko=Korean (한국어)
de.LIQP_ko=Koreanisch (한국어)
es.LIQP_ko=Coreano (한국어)
fr.LIQP_ko=Coréen (한국어)
it.LIQP_ko=Coreano (한국어)
ko.LIQP_ko=한국어
pl.LIQP_ko=Koreański (한국어)
pt_BR.LIQP_ko=Coreano (한국어)
ru.LIQP_ko=Корейский (한국어)
zh_CN.LIQP_ko=韩语 (한국어)
zh_TW.LIQP_ko=韓語 (한국어)

[Messages]
; Replaces the Inno Setup password label when the setup is encrypted (see Encryption in [Setup])
PasswordLabel3=Please write '{#MySetupPassword}' (case-sensitive), then click Next to continue.
de.PasswordLabel3=Bitte geben Sie '{#MySetupPassword}' ein, und klicken Sie danach auf Weiter. Achten Sie auf korrekte Groß- und Kleinschreibung.
es.PasswordLabel3=Por favor, introduzca '{#MySetupPassword}', y haga clic en Siguiente para continuar. La contraseña distingue entre mayúsculas y minúsculas
fr.PasswordLabel3=Veuillez saisir '{#MySetupPassword}' (attention à la distinction entre majuscules et minuscules) puis cliquez sur Suivant pour continuer.
it.PasswordLabel3=Inserire '{#MySetupPassword}', poi premere Avanti per continuare. Le password sono sensibili alle maiuscole/minuscole.
ko.PasswordLabel3='{#MySetupPassword}'(사례 에 민감한)를 작성한 다음 다음을 클릭하여 계속하십시오.
pl.PasswordLabel3=Proszę wpisać '{#MySetupPassword}' (z uwzględnieniem wielkości liter), a następnie kliknąć 'Dalej', aby kontynuować.
ru.PasswordLabel3=Пожалуйста, введите '{#MySetupPassword}' (с учетом регистра), затем нажмите Далее, чтобы продолжить.
zh_CN.PasswordLabel3=请写上'{#MySetupPassword}'（区分大小写），然后点击下一步继续。
zh_TW.PasswordLabel3=请写上'{#MySetupPassword}'（区分大小写），然后点击下一步继续。
IncorrectPassword=The password you entered is not correct. Please enter '{#MySetupPassword}' (case-sensitive).
de.IncorrectPassword=Das eingegebene Passwort ist nicht korrekt. Bitte geben Sie '{#MySetupPassword}' noch einmal ein.
es.IncorrectPassword=La contraseña ingresada no es correcta. Por favor, introduzca '{#MySetupPassword}'.
fr.IncorrectPassword=Le mot de passe saisi n'est pas valide. Merci de saisir '{#MySetupPassword}'.
it.IncorrectPassword=La password inserita non è corretta, riprovare. Inserisci '{#MySetupPassword}'.
ko.IncorrectPassword=입력한 암호가 올바르지 않습니다. '{#MySetupPassword}'(사례 에 민감한)를 입력하십시오.
pl.IncorrectPassword=Wprowadzone hasło jest nieprawidłowe. Proszę wpisać '{#MySetupPassword}' (z uwzględnieniem wielkości liter).
ru.IncorrectPassword=Введенный вами пароль неверен. Пожалуйста, введите '{#MySetupPassword}' (с учетом регистра).
zh_CN.IncorrectPassword=你输入的密码不正确。请输入'{#MySetupPassword}'（区分大小写）。
zh_TW.IncorrectPassword=你输入的密码不正确。请输入'{#MySetupPassword}'（区分大小写）。
; BeveledLabel=Little message at the bottom of the setup in case we want but it's ugly
; For later ? Additional help in cmd: HelpTextNote=/PORTABLE=1%nEnable portable mode.