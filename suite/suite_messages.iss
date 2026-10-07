[CustomMessages]
; Texts of the suite installer (suite.iss), English (the entry without language prefix, which every
; other language shows too), German and French. The suite has these three languages only; the
; product setups it runs have their own (messages.iss). Message names start with "Suite".
; ci/check_messages.py checks this file like messages.iss (languages, duplicates, order) and that
; every message the suite scripts use is defined here.
; Texts that need no translation do not exist: a silent run (/SILENT, /VERYSILENT) shows no
; message, it logs and exits with a code (suite_common.iss, SuiteExit*).

; Prechecks (InitializeSetup): every message ends with the statement that nothing was installed.
; %1 = the missing or damaged files, one per line
SuiteSlicesMissing=The package is incomplete or damaged. These files next to the setup are missing or have the wrong size:%n%n%1%n%nDownload the package again if necessary, extract the whole ZIP archive (all files into one folder) and start "Empire Earth Community Setup.exe" from that folder.%n%nNothing was installed.
de.SuiteSlicesMissing=Das Paket ist unvollständig oder beschädigt. Diese Dateien neben dem Setup fehlen oder haben eine falsche Größe:%n%n%1%n%nLade das Paket gegebenenfalls erneut herunter, entpacke das gesamte ZIP-Archiv (alle Dateien in einen Ordner) und starte "Empire Earth Community Setup.exe" aus diesem Ordner.%n%nEs wurde nichts installiert.
fr.SuiteSlicesMissing=Le paquet est incomplet ou endommagé. Ces fichiers à côté du programme d'installation sont manquants ou n'ont pas la bonne taille :%n%n%1%n%nTéléchargez à nouveau le paquet si nécessaire, extrayez toute l'archive ZIP (tous les fichiers dans un seul dossier) et lancez « Empire Earth Community Setup.exe » depuis ce dossier.%n%nRien n'a été installé.
; The setup was started from inside the ZIP archive (Windows Explorer copies only that one file to a temporary folder)
SuiteZipView=The setup was started from inside the ZIP archive (or from a temporary folder), so the other files of the package are missing:%n%n%1%n%nRight-click the ZIP file, choose "Extract All...", and start "Empire Earth Community Setup.exe" from the new folder.%n%nNothing was installed.
de.SuiteZipView=Das Setup wurde direkt aus dem ZIP-Archiv (oder aus einem temporären Ordner) gestartet, deshalb fehlen die übrigen Dateien des Pakets:%n%n%1%n%nKlicke mit der rechten Maustaste auf die ZIP-Datei, wähle "Alle extrahieren..." und starte "Empire Earth Community Setup.exe" aus dem neuen Ordner.%n%nEs wurde nichts installiert.
fr.SuiteZipView=Le programme d'installation a été lancé depuis l'archive ZIP (ou depuis un dossier temporaire), les autres fichiers du paquet sont donc absents :%n%n%1%n%nFaites un clic droit sur le fichier ZIP, choisissez « Extraire tout... » et lancez « Empire Earth Community Setup.exe » depuis le nouveau dossier.%n%nRien n'a été installé.
; %1 = drive, %2 = space needed, %3 = space free (e.g. "C:", "2300 MB", "1200 MB")
SuiteNotEnoughSpace=There is not enough free space on drive %1: the setup needs about %2 there, only %3 are free.%n%nFree up space on that drive and start the setup again.%n%nNothing was installed.
de.SuiteNotEnoughSpace=Auf dem Laufwerk %1 ist nicht genug Platz frei: Das Setup braucht dort etwa %2, frei sind nur %3.%n%nSchaffe auf diesem Laufwerk Platz und starte das Setup erneut.%n%nEs wurde nichts installiert.
fr.SuiteNotEnoughSpace=Il n'y a pas assez d'espace libre sur le lecteur %1 : le programme d'installation y a besoin d'environ %2, seuls %3 sont libres.%n%nLibérez de l'espace sur ce lecteur et relancez le programme d'installation.%n%nRien n'a été installé.
; A game or the launcher is running (their mutexes)
SuiteRunning=Empire Earth, The Art of Conquest, NeoEE or the Empire Earth Launcher is running.%n%nClose it and start the setup again.%n%nNothing was installed.
de.SuiteRunning=Empire Earth, The Art of Conquest, NeoEE oder der Empire Earth Launcher läuft.%n%nBeende das Programm und starte das Setup erneut.%n%nEs wurde nichts installiert.
fr.SuiteRunning=Empire Earth, The Art of Conquest, NeoEE ou l'Empire Earth Launcher est en cours d'exécution.%n%nFermez-le et relancez le programme d'installation.%n%nRien n'a été installé.

; ---- Wizard pages (suite_pages.iss) ----
; Button names in the texts come from Setup's own button captions (%1), so they are the names the
; user sees in the language of the wizard. The legal texts are copies: SuiteLegalQuestion is the
; text of LegalQuestion in messages.iss (en, de, fr), word for word; ci/check_suite_texts.py fails when they differ.

; Page "Choose what to install"
SuiteSelectTitle=Choose what to install
de.SuiteSelectTitle=Was möchtest du installieren?
fr.SuiteSelectTitle=Choisir ce qu'il faut installer
SuiteSelectSubtitle=Tick the games you want to install. The Empire Earth Launcher is installed with them.
de.SuiteSelectSubtitle=Setze einen Haken bei den Spielen, die du installieren möchtest. Der Empire Earth Launcher wird mit installiert.
fr.SuiteSelectSubtitle=Cochez les jeux que vous voulez installer. L'Empire Earth Launcher est installé avec eux.
SuiteProductEE=Empire Earth (with The Art of Conquest)
de.SuiteProductEE=Empire Earth (mit The Art of Conquest)
fr.SuiteProductEE=Empire Earth (avec The Art of Conquest)
SuiteProductNeoEE=Neo Empire Earth (NeoEE)
SuiteNameLauncher=Empire Earth Launcher
SuiteStateNew=Not installed yet.
de.SuiteStateNew=Noch nicht installiert.
fr.SuiteStateNew=Pas encore installé.
SuiteStateInstalled=Already installed. The setup updates or repairs it.
de.SuiteStateInstalled=Schon installiert. Das Setup aktualisiert oder repariert es.
fr.SuiteStateInstalled=Déjà installé. Le programme d'installation le met à jour ou le répare.
SuiteStateUserOnly=Installed for one user only. This setup skips it. To change that, remove it in Windows under Settings > Apps and start this setup again.
de.SuiteStateUserOnly=Nur für einen Benutzer installiert. Dieses Setup überspringt es. Um das zu ändern, entferne es in Windows unter "Einstellungen" > "Apps" und starte dieses Setup danach erneut.
fr.SuiteStateUserOnly=Installé pour un seul utilisateur. Ce programme d'installation l'ignore. Pour changer cela, supprimez-le dans Windows sous « Paramètres » > « Applications » et relancez ce programme d'installation.
SuiteLauncherInfo=The Empire Earth Launcher is installed too. It starts the games and has tools for settings and repair.
de.SuiteLauncherInfo=Der Empire Earth Launcher wird auch installiert. Mit ihm startest du die Spiele und findest Werkzeuge für Einstellungen und Reparatur.
fr.SuiteLauncherInfo=L'Empire Earth Launcher est installé aussi. Il lance les jeux et propose des outils pour les réglages et la réparation.
SuiteLauncherNoDotNet=The Empire Earth Launcher needs the .NET Framework 4.8, which is missing on this computer. Without it only the games are installed, and the shortcut "Empire Earth Community" starts Neo Empire Earth (or Empire Earth, if only it is installed) directly. Install the .NET Framework 4.8 and run this setup again to get the launcher.
de.SuiteLauncherNoDotNet=Der Empire Earth Launcher braucht das .NET Framework 4.8, das auf diesem Computer fehlt. Ohne es werden nur die Spiele installiert, und die Verknüpfung „Empire Earth Community“ startet Neo Empire Earth (oder Empire Earth, wenn nur das installiert ist) direkt. Installiere das .NET Framework 4.8 und starte dieses Setup erneut, um den Launcher zu bekommen.
fr.SuiteLauncherNoDotNet=L'Empire Earth Launcher a besoin du .NET Framework 4.8, absent de cet ordinateur. Sans lui, seuls les jeux sont installés et le raccourci « Empire Earth Community » lance directement Neo Empire Earth (ou Empire Earth, s'il est le seul installé). Installez le .NET Framework 4.8 et relancez ce programme d'installation pour obtenir le launcher.
SuiteAdvanced=Advanced: go through the setup of each game myself
de.SuiteAdvanced=Erweitert: Das Setup jedes Spiels selbst durchgehen
fr.SuiteAdvanced=Avancé : parcourir moi-même le programme d'installation de chaque jeu
SuiteAdvancedHint=Each game then shows its own setup with all its questions (folder, components, tasks). Most people do not need this.
de.SuiteAdvancedHint=Jedes Spiel zeigt dann sein eigenes Setup mit allen Fragen (Ordner, Komponenten, Aufgaben). Die meisten brauchen das nicht.
fr.SuiteAdvancedHint=Chaque jeu affiche alors son propre programme d'installation avec toutes ses questions (dossier, composants, tâches). La plupart des gens n'en ont pas besoin.
; %1 = the name of the button that goes on (e.g. "Next")
SuiteSelectNone=Tick at least one game to continue with "%1".
de.SuiteSelectNone=Setze einen Haken bei mindestens einem Spiel, um mit "%1" weiterzumachen.
fr.SuiteSelectNone=Cochez au moins un jeu pour continuer avec « %1 ».

; Page "License and notes" (the EULA, and the question about the original game)
SuiteLegalTitle=License and notes
de.SuiteLegalTitle=Lizenz und Hinweise
fr.SuiteLegalTitle=Licence et remarques
SuiteLegalSubtitle=Please read the license agreement of the game.
de.SuiteLegalSubtitle=Bitte lies die Lizenzvereinbarung des Spiels.
fr.SuiteLegalSubtitle=Veuillez lire le contrat de licence du jeu.
SuiteLegalEulaCaption=License agreement (EULA)
de.SuiteLegalEulaCaption=Lizenzvereinbarung (EULA)
fr.SuiteLegalEulaCaption=Contrat de licence (EULA)
SuiteLegalQuestion=Do you have the original game and its expansion (or Gold Edition) on CD with valid keys or did you purchase the game digitally?
de.SuiteLegalQuestion=Haben Sie das Originalspiel und seine Erweiterung (oder Gold Edition) auf CD mit gültigen Schlüsseln oder haben Sie das Spiel digital erworben?
fr.SuiteLegalQuestion=Avez-vous le jeu original et son extension (ou l'édition Gold) sur CD avec des clés valides ou avez-vous acheté le jeu numériquement ?
SuiteLegalYes=Yes
de.SuiteLegalYes=Ja
fr.SuiteLegalYes=Oui
; %1 = the name of the button that goes on
SuiteLegalNeedYes=Tick "Yes" to continue with "%1". Without the original game or a digital purchase this setup cannot go on.
de.SuiteLegalNeedYes=Setze den Haken bei "Ja", um mit "%1" weiterzumachen. Ohne das Originalspiel oder einen digitalen Kauf kann dieses Setup nicht weitermachen.
fr.SuiteLegalNeedYes=Cochez « Oui » pour continuer avec « %1 ». Sans le jeu original ou un achat numérique, ce programme d'installation ne peut pas continuer.
SuiteLegalKnown=You have installed a game with this setup before, so you do not have to answer this question again.
de.SuiteLegalKnown=Du hast schon ein Spiel installiert, deshalb musst du diese Frage nicht noch einmal beantworten.
fr.SuiteLegalKnown=Vous avez déjà installé un jeu, vous n'avez donc pas à répondre à nouveau à cette question.

; Page "Rules for NeoEE" (shown only when NeoEE is ticked)
SuiteRulesTitle=Rules for NeoEE
de.SuiteRulesTitle=Regeln für NeoEE
fr.SuiteRulesTitle=Règles de NeoEE
SuiteRulesSubtitle=Please read these rules before you install NeoEE.
de.SuiteRulesSubtitle=Bitte lies diese Regeln, bevor du NeoEE installierst.
fr.SuiteRulesSubtitle=Veuillez lire ces règles avant d'installer NeoEE.

; Last page (what happened)
SuiteFinishHeadingProblems=Not everything was installed
de.SuiteFinishHeadingProblems=Nicht alles wurde installiert
fr.SuiteFinishHeadingProblems=Tout n'a pas été installé
SuiteFinishIntro=This is what the setup did:
de.SuiteFinishIntro=Das hat das Setup gemacht:
fr.SuiteFinishIntro=Voici ce que le programme d'installation a fait :
SuiteStatusOk=installed
de.SuiteStatusOk=installiert
fr.SuiteStatusOk=installé
SuiteStatusFailed=failed (the log tells why)
de.SuiteStatusFailed=fehlgeschlagen (das Protokoll nennt den Grund)
fr.SuiteStatusFailed=échec (le journal en donne la raison)
SuiteStatusSkippedUser=skipped (installed for one user only)
de.SuiteStatusSkippedUser=übersprungen (nur für einen Benutzer installiert)
fr.SuiteStatusSkippedUser=ignoré (installé pour un seul utilisateur)
SuiteStatusCancelled=cancelled by you, nothing of it was changed (start this setup again to install or repair it)
de.SuiteStatusCancelled=von dir abgebrochen, nichts daran wurde geändert (starte dieses Setup erneut, um es zu installieren oder zu reparieren)
fr.SuiteStatusCancelled=annulé par vous, rien n'a été modifié (relancez ce programme d'installation pour l'installer ou le réparer)
SuiteStatusNotSelected=not selected
de.SuiteStatusNotSelected=nicht ausgewählt
fr.SuiteStatusNotSelected=non sélectionné
SuiteStatusNoDotNet=not installed (.NET Framework 4.8 is missing)
de.SuiteStatusNoDotNet=nicht installiert (.NET Framework 4.8 fehlt)
fr.SuiteStatusNoDotNet=non installé (.NET Framework 4.8 absent)
SuiteCdKeyOk=NeoEE CD keys: registered.
de.SuiteCdKeyOk=NeoEE-CD-Keys: registriert.
fr.SuiteCdKeyOk=Clés CD de NeoEE : enregistrées.
; %1 = the result number of the NeoEE setup
SuiteCdKeyFailed=NeoEE CD keys: not registered (result %1). Start this setup again to repair the registration.
de.SuiteCdKeyFailed=NeoEE-CD-Keys: nicht registriert (Ergebnis %1). Starte dieses Setup erneut, um die Registrierung zu reparieren.
fr.SuiteCdKeyFailed=Clés CD de NeoEE : non enregistrées (résultat %1). Relancez ce programme d'installation pour réparer l'enregistrement.
SuiteCdKeyNotChosen=NeoEE CD keys: registration not selected, nothing was registered.
de.SuiteCdKeyNotChosen=NeoEE-CD-Keys: Registrierung nicht gewählt, es wurde nichts registriert.
fr.SuiteCdKeyNotChosen=Clés CD de NeoEE : enregistrement non sélectionné, rien n'a été enregistré.
SuiteCdKeyUnknown=NeoEE CD keys: result unknown. Start this setup again to repair the registration.
de.SuiteCdKeyUnknown=NeoEE-CD-Keys: Ergebnis unbekannt. Starte dieses Setup erneut, um die Registrierung zu reparieren.
fr.SuiteCdKeyUnknown=Clés CD de NeoEE : résultat inconnu. Relancez ce programme d'installation pour réparer l'enregistrement.
; The language files of a game that was installed: %1 = how many arrived, %2 = how many there are, %3 = how many are missing
SuiteFinishLangOk=Language files: %1 of %2 installed from the download.
de.SuiteFinishLangOk=Sprachdateien: %1 von %2 aus dem Download installiert.
fr.SuiteFinishLangOk=Fichiers de langue : %1 sur %2 installés depuis le téléchargement.
SuiteFinishLangMissing=Language files: %1 of %2 installed from the download. For the other %3 the game uses the files of the setup, so some content may not be translated. Start this setup again with a working internet connection to get them.
de.SuiteFinishLangMissing=Sprachdateien: %1 von %2 aus dem Download installiert. Für die übrigen %3 verwendet das Spiel die Dateien des Setups, daher sind einige Inhalte möglicherweise nicht übersetzt. Starte dieses Setup erneut mit einer funktionierenden Internetverbindung, um sie nachzuholen.
fr.SuiteFinishLangMissing=Fichiers de langue : %1 sur %2 installés depuis le téléchargement. Pour les %3 autres, le jeu utilise les fichiers du programme d'installation, certains contenus ne sont donc peut-être pas traduits. Relancez ce programme d'installation avec une connexion Internet fonctionnelle pour les obtenir.
SuiteFinishLangNone=Language files: none needed.
de.SuiteFinishLangNone=Sprachdateien: keine nötig.
fr.SuiteFinishLangNone=Fichiers de langue : aucun nécessaire.
; %1 = folder of the logs
SuiteFinishLogs=Logs: %1
de.SuiteFinishLogs=Protokolle: %1
fr.SuiteFinishLogs=Journaux : %1
; %1 = the name of the last button
SuiteFinishClose=Click "%1" to close the setup.
de.SuiteFinishClose=Klicke auf "%1", um das Setup zu schließen.
fr.SuiteFinishClose=Cliquez sur « %1 » pour fermer le programme d'installation.
SuiteRunLauncher=Start the Empire Earth Launcher now
de.SuiteRunLauncher=Launcher jetzt starten
fr.SuiteRunLauncher=Lancer l'Empire Earth Launcher maintenant

; ---- The product runner (suite_run.iss) ----
; %1 = the name of the game
SuiteProductDamaged=The setup program of %1 inside this package is damaged: it does not match the checksum recorded when the package was built.%n%nDownload the package again and extract the whole ZIP archive.%n%nNothing was installed.
de.SuiteProductDamaged=Das Setup-Programm von %1 in diesem Paket ist beschädigt: Es stimmt nicht mit der Prüfsumme überein, die beim Bau des Pakets festgehalten wurde.%n%nLade das Paket erneut herunter und entpacke das ganze ZIP-Archiv.%n%nEs wurde nichts installiert.
fr.SuiteProductDamaged=Le programme d'installation de %1 dans ce paquet est endommagé : il ne correspond pas à la somme de contrôle enregistrée lors de la création du paquet.%n%nTéléchargez à nouveau le paquet et extrayez toute l'archive ZIP.%n%nRien n'a été installé.
; %1 = the product
SuiteProductUnreadable=The setup program of %1 inside this package could not be unpacked: the package is damaged or incomplete.%n%nDownload the package again and extract the whole ZIP archive.%n%nNothing was installed.
de.SuiteProductUnreadable=Das Setup-Programm von %1 in diesem Paket konnte nicht entpackt werden: Das Paket ist beschädigt oder unvollständig.%n%nLade das Paket erneut herunter und entpacke das ganze ZIP-Archiv.%n%nEs wurde nichts installiert.
fr.SuiteProductUnreadable=Le programme d'installation de %1 dans ce paquet n'a pas pu être décompressé : le paquet est endommagé ou incomplet.%n%nTéléchargez à nouveau le paquet et extrayez toute l'archive ZIP.%n%nRien n'a été installé.
SuiteRunDamaged=The setup program of %1 inside this package is damaged or was changed after the check. It was not started, and no further game is installed.%n%nDownload the package again and extract the whole ZIP archive.
de.SuiteRunDamaged=Das Setup-Programm von %1 in diesem Paket ist beschädigt oder wurde nach der Prüfung verändert. Es wurde nicht gestartet, und weitere Spiele werden nicht installiert.%n%nLade das Paket erneut herunter und entpacke das ganze ZIP-Archiv.
fr.SuiteRunDamaged=Le programme d'installation de %1 dans ce paquet est endommagé ou a été modifié après la vérification. Il n'a pas été lancé, et aucun autre jeu n'est installé.%n%nTéléchargez à nouveau le paquet et extrayez toute l'archive ZIP.
; Text of the installation page while a game is installed: %1 = number of the step, %2 = number of steps, %3 = the game
SuiteStepRun=Step %1 of %2: installing %3 ...
de.SuiteStepRun=Schritt %1 von %2: %3 wird installiert ...
fr.SuiteStepRun=Étape %1 sur %2 : installation de %3 ...
SuiteStepAdvanced=Step %1 of %2: the setup of %3 is open. Please go through it there.
de.SuiteStepAdvanced=Schritt %1 von %2: Das Setup von %3 ist geöffnet. Bitte gehe es dort durch.
fr.SuiteStepAdvanced=Étape %1 sur %2 : le programme d'installation de %3 est ouvert. Veuillez le parcourir.
; The status line while the setup of a game runs and the log tells what it does: %1 = number of the step, %2 = number of
; steps, %3 = the short name of the game, %4 = number of the language file, %5 = number of language files
SuiteStepProbe=Step %1 of %2: %3 - looking for the language files online ...
de.SuiteStepProbe=Schritt %1 von %2: %3 - sucht die Sprachdateien im Internet ...
fr.SuiteStepProbe=Étape %1 sur %2 : %3 - recherche des fichiers de langue en ligne ...
SuiteStepDownload=Step %1 of %2: %3 - downloading language file %4 of %5 ...
de.SuiteStepDownload=Schritt %1 von %2: %3 - lädt Sprachdatei %4 von %5 herunter ...
fr.SuiteStepDownload=Étape %1 sur %2 : %3 - téléchargement du fichier de langue %4 sur %5 ...
SuiteStepVerify=Step %1 of %2: %3 - checking the language files ...
de.SuiteStepVerify=Schritt %1 von %2: %3 - prüft die Sprachdateien ...
fr.SuiteStepVerify=Étape %1 sur %2 : %3 - vérification des fichiers de langue ...
SuiteStepInstall=Step %1 of %2: %3 - installing the game files ...
de.SuiteStepInstall=Schritt %1 von %2: %3 - installiert die Spieldateien ...
fr.SuiteStepInstall=Étape %1 sur %2 : %3 - installation des fichiers du jeu ...
SuiteStepCdKeys=Step %1 of %2: %3 - registering the CD keys ...
de.SuiteStepCdKeys=Schritt %1 von %2: %3 - registriert die CD-Keys ...
fr.SuiteStepCdKeys=Étape %1 sur %2 : %3 - enregistrement des clés CD ...
SuiteStepFinish=Step %1 of %2: %3 - finishing the installation ...
de.SuiteStepFinish=Schritt %1 von %2: %3 - schließt die Installation ab ...
fr.SuiteStepFinish=Étape %1 sur %2 : %3 - finalisation de l'installation ...
; The short names of the games in the status line (names, not translated)
SuiteShortEE=Empire Earth
SuiteShortNeoEE=NeoEE
; The line under the status line: the file the game setup works on. %1 = the file, %2 = the part done, %3 = the size with its unit
SuiteFileProgress=%1 - %2 of %3
de.SuiteFileProgress=%1 - %2 von %3
fr.SuiteFileProgress=%1 - %2 sur %3
; The list of the finished steps of the installation page (one block per game, headed by its name)
SuiteStageNoDownload=No language files needed
de.SuiteStageNoDownload=Keine Sprachdateien nötig
fr.SuiteStageNoDownload=Aucun fichier de langue nécessaire
; %1 = the language files that arrived, %2 = how many there are
SuiteStageDownloaded=Language files downloaded: %1 of %2
de.SuiteStageDownloaded=Sprachdateien heruntergeladen: %1 von %2
fr.SuiteStageDownloaded=Fichiers de langue téléchargés : %1 sur %2
SuiteStageInstalled=Game files installed
de.SuiteStageInstalled=Spieldateien installiert
fr.SuiteStageInstalled=Fichiers du jeu installés
SuiteStageCdKeysOk=CD keys registered
de.SuiteStageCdKeysOk=CD-Keys registriert
fr.SuiteStageCdKeysOk=Clés CD enregistrées
; %1 = the result number of the NeoEE setup
SuiteStageCdKeysFailed=CD keys not registered (result %1)
de.SuiteStageCdKeysFailed=CD-Keys nicht registriert (Ergebnis %1)
fr.SuiteStageCdKeysFailed=Clés CD non enregistrées (résultat %1)
SuiteStageManifest=List of the installed files written (for the launcher)
de.SuiteStageManifest=Liste der installierten Dateien geschrieben (für den Launcher)
fr.SuiteStageManifest=Liste des fichiers installés écrite (pour le lanceur)
SuiteStageDone=Finished
de.SuiteStageDone=Fertig
fr.SuiteStageDone=Terminé
SuiteStageFailed=Not installed (the log tells why)
de.SuiteStageFailed=Nicht installiert (das Protokoll nennt den Grund)
fr.SuiteStageFailed=Non installé (le journal en donne la raison)
; A game setup did not start because a game or the launcher is running: %1 = the game
SuiteRunGameRunning=%1 was not installed. Empire Earth, The Art of Conquest, NeoEE or the Empire Earth Launcher is probably running.%n%nClose it and start this setup again. The setup goes on with the next game.
de.SuiteRunGameRunning=%1 wurde nicht installiert. Vermutlich läuft Empire Earth, The Art of Conquest, NeoEE oder der Empire Earth Launcher.%n%nBeende das Programm und starte dieses Setup erneut. Das Setup macht mit dem nächsten Spiel weiter.
fr.SuiteRunGameRunning=%1 n'a pas été installé. Empire Earth, The Art of Conquest, NeoEE ou l'Empire Earth Launcher est probablement en cours d'exécution.%n%nFermez-le et relancez ce programme d'installation. Le programme continue avec le jeu suivant.
; A game setup failed: %1 = the game, %2 = the reason (SuiteReason...), %3 = the log file
SuiteRunFailed=%1 was not installed (%2).%n%nThe log of the game setup: %3%n%nThe setup goes on with the next game.
de.SuiteRunFailed=%1 wurde nicht installiert (%2).%n%nDas Protokoll des Spiel-Setups: %3%n%nDas Setup macht mit dem nächsten Spiel weiter.
fr.SuiteRunFailed=%1 n'a pas été installé (%2).%n%nLe journal du programme d'installation du jeu : %3%n%nLe programme continue avec le jeu suivant.
; %1 = exit code of the game setup, %2 = what it means (SuiteReason...)
SuiteReasonCode=exit code %1: %2
de.SuiteReasonCode=Exit-Code %1: %2
fr.SuiteReasonCode=code de sortie %1 : %2
SuiteReasonFatal=a fatal error
de.SuiteReasonFatal=ein schwerer Fehler
fr.SuiteReasonFatal=une erreur fatale
SuiteReasonPrecondition=the setup found that it cannot install
de.SuiteReasonPrecondition=das Setup hat festgestellt, dass es nicht installieren kann
fr.SuiteReasonPrecondition=le programme a constaté qu'il ne peut pas installer
SuiteReasonNoEntry=the setup ended without an error, but the game is not registered in Windows
de.SuiteReasonNoEntry=das Setup endete ohne Fehler, aber das Spiel ist in Windows nicht eingetragen
fr.SuiteReasonNoEntry=le programme s'est terminé sans erreur, mais le jeu n'est pas enregistré dans Windows
SuiteReasonOther=unknown error
de.SuiteReasonOther=unbekannter Fehler
fr.SuiteReasonOther=erreur inconnue
; %1 = the system's text
SuiteReasonNotStarted=the setup program could not be extracted or started: %1
de.SuiteReasonNotStarted=das Setup-Programm konnte nicht entpackt oder gestartet werden: %1
fr.SuiteReasonNotStarted=le programme d'installation n'a pas pu être extrait ou lancé : %1
; Cancel while the setup of a game runs (the game setup shows no window of its own): the question and what Cancel
; says when it is off. %1 = the game, %2 = the game that is installed already. The text depends on what stays: a game
; installed for the first time (nothing is installed yet), a game that is already installed and repaired or updated
; (it stays exactly as it is), and the game this run finished before (it stays installed, the setup then finishes with the
; launcher and the shortcuts for it). The temporary folder is the one the game setup leaves with what it had downloaded.
SuiteCancelQuestion=Do you want to stop the installation of %1?%n%nNo game files have been installed yet. What the setup has downloaded so far stays in a temporary folder of Windows (a folder named is-*.tmp, up to about 170 MB) until Windows or you delete it.
de.SuiteCancelQuestion=Möchtest du die Installation von %1 abbrechen?%n%nEs wurden noch keine Spieldateien installiert. Was das Setup bis jetzt heruntergeladen hat, bleibt in einem temporären Ordner von Windows (ein Ordner is-*.tmp, bis zu etwa 170 MB), bis Windows oder du ihn löschst.
fr.SuiteCancelQuestion=Voulez-vous arrêter l'installation de %1 ?%n%nAucun fichier du jeu n'a encore été installé. Ce que le programme a déjà téléchargé reste dans un dossier temporaire de Windows (un dossier is-*.tmp, jusqu'à environ 170 Mo) jusqu'à ce que Windows ou vous le supprimiez.
SuiteCancelQuestionKept=Do you want to stop the installation of %1?%n%nNo game files of it have been installed yet. %2 is already installed and stays installed. The setup then finishes with the launcher and the shortcuts, without %1.%n%nWhat the setup has downloaded so far stays in a temporary folder of Windows (a folder named is-*.tmp, up to about 170 MB) until Windows or you delete it.
de.SuiteCancelQuestionKept=Möchtest du die Installation von %1 abbrechen?%n%nVon diesem Spiel wurden noch keine Dateien installiert. %2 ist schon installiert und bleibt installiert. Das Setup schließt dann mit dem Launcher und den Verknüpfungen ab, ohne %1.%n%nWas das Setup bis jetzt heruntergeladen hat, bleibt in einem temporären Ordner von Windows (ein Ordner is-*.tmp, bis zu etwa 170 MB), bis Windows oder du ihn löschst.
fr.SuiteCancelQuestionKept=Voulez-vous arrêter l'installation de %1 ?%n%nAucun fichier de ce jeu n'a encore été installé. %2 est déjà installé et le reste. Le programme se termine alors avec le lanceur et les raccourcis, sans %1.%n%nCe que le programme a déjà téléchargé reste dans un dossier temporaire de Windows (un dossier is-*.tmp, jusqu'à environ 170 Mo) jusqu'à ce que Windows ou vous le supprimiez.
SuiteCancelQuestionInstalled=Do you want to stop the repair or update of %1?%n%n%1 is already installed and stays exactly as it is: the setup has not changed anything of it yet.%n%nWhat the setup has downloaded so far stays in a temporary folder of Windows (a folder named is-*.tmp, up to about 170 MB) until Windows or you delete it.
de.SuiteCancelQuestionInstalled=Möchtest du die Reparatur oder das Update von %1 abbrechen?%n%n%1 ist schon installiert und bleibt genau so, wie es ist: Das Setup hat noch nichts daran geändert.%n%nWas das Setup bis jetzt heruntergeladen hat, bleibt in einem temporären Ordner von Windows (ein Ordner is-*.tmp, bis zu etwa 170 MB), bis Windows oder du ihn löschst.
fr.SuiteCancelQuestionInstalled=Voulez-vous arrêter la réparation ou la mise à jour de %1 ?%n%n%1 est déjà installé et reste exactement tel qu'il est : le programme n'y a encore rien modifié.%n%nCe que le programme a déjà téléchargé reste dans un dossier temporaire de Windows (un dossier is-*.tmp, jusqu'à environ 170 Mo) jusqu'à ce que Windows ou vous le supprimiez.
SuiteCancelQuestionInstalledKept=Do you want to stop the repair or update of %1?%n%n%1 is already installed and stays exactly as it is: the setup has not changed anything of it yet. %2 is already finished and stays installed. The setup then finishes with the launcher and the shortcuts.%n%nWhat the setup has downloaded so far stays in a temporary folder of Windows (a folder named is-*.tmp, up to about 170 MB) until Windows or you delete it.
de.SuiteCancelQuestionInstalledKept=Möchtest du die Reparatur oder das Update von %1 abbrechen?%n%n%1 ist schon installiert und bleibt genau so, wie es ist: Das Setup hat noch nichts daran geändert. %2 ist schon fertig und bleibt installiert. Das Setup schließt dann mit dem Launcher und den Verknüpfungen ab.%n%nWas das Setup bis jetzt heruntergeladen hat, bleibt in einem temporären Ordner von Windows (ein Ordner is-*.tmp, bis zu etwa 170 MB), bis Windows oder du ihn löschst.
fr.SuiteCancelQuestionInstalledKept=Voulez-vous arrêter la réparation ou la mise à jour de %1 ?%n%n%1 est déjà installé et reste exactement tel qu'il est : le programme n'y a encore rien modifié. %2 est déjà terminé et reste installé. Le programme se termine alors avec le lanceur et les raccourcis.%n%nCe que le programme a déjà téléchargé reste dans un dossier temporaire de Windows (un dossier is-*.tmp, jusqu'à environ 170 Mo) jusqu'à ce que Windows ou vous le supprimiez.
SuiteCancelNotNow=Cancel is no longer possible: the game is being installed.
de.SuiteCancelNotNow=Abbrechen ist nicht mehr möglich: Das Spiel wird gerade installiert.
fr.SuiteCancelNotNow=L'annulation n'est plus possible : le jeu est en cours d'installation.
SuiteCancelOwnSetup=To cancel, use the Cancel button in the setup window of the game.
de.SuiteCancelOwnSetup=Zum Abbrechen verwende den Button "Abbrechen" im Setup-Fenster des Spiels.
fr.SuiteCancelOwnSetup=Pour annuler, utilisez le bouton « Annuler » dans la fenêtre du programme d'installation du jeu.
SuiteCancelUnavailable=Cancel is not available here: the setup of the game cannot be stopped safely.
de.SuiteCancelUnavailable=Abbrechen ist hier nicht möglich: Das Setup des Spiels lässt sich nicht sicher beenden.
fr.SuiteCancelUnavailable=L'annulation n'est pas possible ici : le programme d'installation du jeu ne peut pas être arrêté en toute sécurité.
; The setup of a game shows no progress for a long time: %1 = the game, %2 = the minutes
SuiteStallQuestion=The setup of %1 has shown no progress for %2 minutes. It may be stuck, or the internet connection is very slow. No game files have been installed or changed yet.%n%nDo you want to keep waiting? If you answer "No", the setup of this game is stopped.
de.SuiteStallQuestion=Das Setup von %1 hat seit %2 Minuten keinen Fortschritt gezeigt. Es hängt möglicherweise, oder die Internetverbindung ist sehr langsam. Es wurden noch keine Spieldateien installiert oder geändert.%n%nMöchtest du weiter warten? Bei "Nein" wird das Setup dieses Spiels beendet.
fr.SuiteStallQuestion=Le programme d'installation de %1 n'a montré aucune progression depuis %2 minutes. Il est peut-être bloqué, ou la connexion Internet est très lente. Aucun fichier du jeu n'a encore été installé ni modifié.%n%nVoulez-vous continuer à attendre ? Si vous répondez « Non », l'installation de ce jeu est arrêtée.
SuiteStallQuestionInstalling=The setup of %1 has shown no progress for %2 minutes. It may be stuck.%n%nDo you want to keep waiting? If you answer "No", the setup of this game is stopped and the game may be only partly installed. Start this setup again to repair it.
de.SuiteStallQuestionInstalling=Das Setup von %1 hat seit %2 Minuten keinen Fortschritt gezeigt. Es hängt möglicherweise.%n%nMöchtest du weiter warten? Bei "Nein" wird das Setup dieses Spiels beendet, und das Spiel ist dann möglicherweise nur teilweise installiert. Starte dieses Setup danach erneut, um es zu reparieren.
fr.SuiteStallQuestionInstalling=Le programme d'installation de %1 n'a montré aucune progression depuis %2 minutes. Il est peut-être bloqué.%n%nVoulez-vous continuer à attendre ? Si vous répondez « Non », l'installation de ce jeu est arrêtée et le jeu ne sera peut-être installé qu'en partie. Relancez ensuite ce programme d'installation pour le réparer.
; The reason after the suite stopped a game setup (it fits "%1 was not installed (%2)")
SuiteReasonTimeout=the setup took too long and was stopped; no game files were installed or changed
de.SuiteReasonTimeout=das Setup hat zu lange gebraucht und wurde beendet; es wurden keine Spieldateien installiert oder geändert
fr.SuiteReasonTimeout=le programme d'installation a pris trop de temps et a été arrêté ; aucun fichier du jeu n'a été installé ni modifié
SuiteReasonTimeoutInstalling=the setup took too long and was stopped while it installed the files; the game may be only partly installed, start this setup again to repair it
de.SuiteReasonTimeoutInstalling=das Setup hat zu lange gebraucht und wurde beendet, während es die Dateien installierte; das Spiel ist möglicherweise nur teilweise installiert, starte dieses Setup erneut, um es zu reparieren
fr.SuiteReasonTimeoutInstalling=le programme d'installation a pris trop de temps et a été arrêté pendant l'installation des fichiers ; le jeu n'est peut-être installé qu'en partie, relancez ce programme d'installation pour le réparer

; ---- The uninstaller (suite_uninstall.iss) ----
; A game or the launcher is running (their mutexes); nothing was removed
SuiteUninstallRunning=Empire Earth, The Art of Conquest, NeoEE or the Empire Earth Launcher is running.%n%nClose it and start the uninstallation again.%n%nNothing was removed.
de.SuiteUninstallRunning=Empire Earth, The Art of Conquest, NeoEE oder der Empire Earth Launcher läuft.%n%nBeende das Programm und starte die Deinstallation erneut.%n%nEs wurde nichts entfernt.
fr.SuiteUninstallRunning=Empire Earth, The Art of Conquest, NeoEE ou l'Empire Earth Launcher est en cours d'exécution.%n%nFermez-le et relancez la désinstallation.%n%nRien n'a été supprimé.
; Another setup or uninstallation of the suite runs (its setup mutex)
SuiteUninstallBusy=Another setup or uninstallation of Empire Earth Community is running.%n%nWait until it is finished and start the uninstallation again.%n%nNothing was removed.
de.SuiteUninstallBusy=Ein anderes Setup oder eine andere Deinstallation von Empire Earth Community läuft.%n%nWarte, bis sie fertig ist, und starte die Deinstallation erneut.%n%nEs wurde nichts entfernt.
fr.SuiteUninstallBusy=Un autre programme d'installation ou une autre désinstallation d'Empire Earth Community est en cours.%n%nAttendez qu'il soit terminé et relancez la désinstallation.%n%nRien n'a été supprimé.
; The one confirmation: %1 = the list of what is removed, one item per line
SuiteUninstallConfirm=This removes:%n%n%1%nYour saved games, profiles, own mods and launcher backups are kept unless you choose otherwise at the end.%n%nDo you want to continue?
de.SuiteUninstallConfirm=Dabei wird entfernt:%n%n%1%nDeine Spielstände, Profile, eigenen Mods und Launcher-Sicherungen bleiben erhalten, außer du entscheidest am Ende anders.%n%nMöchtest du fortfahren?
fr.SuiteUninstallConfirm=Ceci supprime :%n%n%1%nVos parties sauvegardées, profils, mods personnels et sauvegardes du lanceur sont conservés, sauf si vous décidez autrement à la fin.%n%nVoulez-vous continuer ?
; %1 = the folder of the launcher
SuiteUninstallItemLauncher=Empire Earth Launcher and Mod Creator (%1)
de.SuiteUninstallItemLauncher=Empire Earth Launcher und Mod Creator (%1)
fr.SuiteUninstallItemLauncher=Empire Earth Launcher et Mod Creator (%1)
; %1 = the name of the game, %2 = its folder
SuiteUninstallItemProduct=%1 (%2)
SuiteUninstallItemShortcuts=The shortcuts and the entries of Empire Earth Community
de.SuiteUninstallItemShortcuts=Die Verknüpfungen und Einträge von Empire Earth Community
fr.SuiteUninstallItemShortcuts=Les raccourcis et les entrées d'Empire Earth Community
; The status line while a game is removed: %1 = number, %2 = of how many, %3 = the name of the game
SuiteUninstallStatus=Step %1 of %2: removing %3 ... (this can take several minutes)
de.SuiteUninstallStatus=Schritt %1 von %2: %3 wird entfernt ... (das kann mehrere Minuten dauern)
fr.SuiteUninstallStatus=Étape %1 sur %2 : suppression de %3 ... (cela peut prendre plusieurs minutes)
; A game could not be removed: %1 = the name of the game, %2 = the reason (the next three texts)
SuiteUninstallFailed=%1 was not removed (%2).%n%nRemove it yourself: open the list of installed programs of Windows (Settings, Apps; on Windows 7: Control Panel, Programs and Features), select the entry of %1 and choose Uninstall.%n%nThe uninstallation of Empire Earth Community goes on with the rest.
de.SuiteUninstallFailed=%1 wurde nicht entfernt (%2).%n%nEntferne es selbst: Öffne die Liste der installierten Programme von Windows (Einstellungen, Apps; unter Windows 7: Systemsteuerung, Programme und Features), wähle den Eintrag von %1 und klicke auf Deinstallieren.%n%nDie Deinstallation von Empire Earth Community macht mit dem Rest weiter.
fr.SuiteUninstallFailed=%1 n'a pas été supprimé (%2).%n%nSupprimez-le vous-même : ouvrez la liste des programmes installés de Windows (Paramètres, Applications ; sous Windows 7 : Panneau de configuration, Programmes et fonctionnalités), sélectionnez l'entrée de %1 et choisissez Désinstaller.%n%nLa désinstallation d'Empire Earth Community continue avec le reste.
SuiteUninstallReasonStart=its uninstaller could not be started
de.SuiteUninstallReasonStart=sein Deinstallationsprogramm konnte nicht gestartet werden
fr.SuiteUninstallReasonStart=son programme de désinstallation n'a pas pu être lancé
; %1 = minutes
SuiteUninstallReasonTimeout=it was not finished after %1 minutes
de.SuiteUninstallReasonTimeout=nach %1 Minuten war es nicht fertig
fr.SuiteUninstallReasonTimeout=elle n'était pas terminée après %1 minutes
; The question about the user data at the end (task dialog): the title, the text (%1 = the folders, one per line)
; and the two buttons; "Keep" is the first and the default
SuiteUninstallDataTitle=Delete saved games, profiles, own mods and backups too?
de.SuiteUninstallDataTitle=Spielstände, Profile, eigene Mods und Sicherungen auch löschen?
fr.SuiteUninstallDataTitle=Supprimer aussi les parties sauvegardées, profils, mods personnels et sauvegardes ?
SuiteUninstallDataQuestion=These folders are still there:%n%n%1%n"Delete" removes exactly these folders with everything in them. This cannot be undone.
de.SuiteUninstallDataQuestion=Diese Ordner sind noch vorhanden:%n%n%1%n"Löschen" entfernt genau diese Ordner mit allem, was darin liegt. Das lässt sich nicht rückgängig machen.
fr.SuiteUninstallDataQuestion=Ces dossiers existent encore :%n%n%1%n« Supprimer » supprime exactement ces dossiers avec tout leur contenu. Cela ne peut pas être annulé.
SuiteUninstallKeep=Keep (recommended)
de.SuiteUninstallKeep=Behalten (empfohlen)
fr.SuiteUninstallKeep=Conserver (recommandé)
SuiteUninstallDelete=Delete
de.SuiteUninstallDelete=Löschen
fr.SuiteUninstallDelete=Supprimer
