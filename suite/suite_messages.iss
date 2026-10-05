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
SuiteLauncherNoDotNet=The Empire Earth Launcher needs the .NET Framework 4.8, which is missing on this computer. Without it only the games are installed, and their shortcuts start the games directly.
de.SuiteLauncherNoDotNet=Der Empire Earth Launcher braucht das .NET Framework 4.8, das auf diesem Computer fehlt. Ohne es werden nur die Spiele installiert, und ihre Verknüpfungen starten die Spiele direkt.
fr.SuiteLauncherNoDotNet=L'Empire Earth Launcher a besoin du .NET Framework 4.8, absent de cet ordinateur. Sans lui, seuls les jeux sont installés et leurs raccourcis lancent directement les jeux.
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
SuiteCdKeyUnknown=NeoEE CD keys: result unknown. Start this setup again to repair the registration.
de.SuiteCdKeyUnknown=NeoEE-CD-Keys: Ergebnis unbekannt. Starte dieses Setup erneut, um die Registrierung zu reparieren.
fr.SuiteCdKeyUnknown=Clés CD de NeoEE : résultat inconnu. Relancez ce programme d'installation pour réparer l'enregistrement.
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
