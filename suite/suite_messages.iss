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
de.SuiteSlicesMissing=Das Paket ist unvollständig oder beschädigt. Diese Dateien neben dem Setup fehlen oder haben eine falsche Größe:%n%n%1%n%nLaden Sie das Paket gegebenenfalls erneut herunter, entpacken Sie das gesamte ZIP-Archiv (alle Dateien in einen Ordner) und starten Sie "Empire Earth Community Setup.exe" aus diesem Ordner.%n%nEs wurde nichts installiert.
fr.SuiteSlicesMissing=Le paquet est incomplet ou endommagé. Ces fichiers à côté du programme d'installation sont manquants ou n'ont pas la bonne taille :%n%n%1%n%nTéléchargez à nouveau le paquet si nécessaire, extrayez toute l'archive ZIP (tous les fichiers dans un seul dossier) et lancez « Empire Earth Community Setup.exe » depuis ce dossier.%n%nRien n'a été installé.
; The setup was started from inside the ZIP archive (Windows Explorer copies only that one file to a temporary folder)
SuiteZipView=The setup was started from inside the ZIP archive (or from a temporary folder), so the other files of the package are missing:%n%n%1%n%nRight-click the ZIP file, choose "Extract All...", and start "Empire Earth Community Setup.exe" from the new folder.%n%nNothing was installed.
de.SuiteZipView=Das Setup wurde direkt aus dem ZIP-Archiv (oder aus einem temporären Ordner) gestartet, deshalb fehlen die übrigen Dateien des Pakets:%n%n%1%n%nKlicken Sie mit der rechten Maustaste auf die ZIP-Datei, wählen Sie "Alle extrahieren..." und starten Sie "Empire Earth Community Setup.exe" aus dem neuen Ordner.%n%nEs wurde nichts installiert.
fr.SuiteZipView=Le programme d'installation a été lancé depuis l'archive ZIP (ou depuis un dossier temporaire), les autres fichiers du paquet sont donc absents :%n%n%1%n%nFaites un clic droit sur le fichier ZIP, choisissez « Extraire tout... » et lancez « Empire Earth Community Setup.exe » depuis le nouveau dossier.%n%nRien n'a été installé.
; %1 = drive, %2 = space needed, %3 = space free (e.g. "C:", "2300 MB", "1200 MB")
SuiteNotEnoughSpace=There is not enough free space on drive %1: the setup needs about %2 there, only %3 are free.%n%nFree up space on that drive and start the setup again.%n%nNothing was installed.
de.SuiteNotEnoughSpace=Auf dem Laufwerk %1 ist nicht genug Platz frei: Das Setup braucht dort etwa %2, frei sind nur %3.%n%nSchaffen Sie auf diesem Laufwerk Platz und starten Sie das Setup erneut.%n%nEs wurde nichts installiert.
fr.SuiteNotEnoughSpace=Il n'y a pas assez d'espace libre sur le lecteur %1 : le programme d'installation y a besoin d'environ %2, seuls %3 sont libres.%n%nLibérez de l'espace sur ce lecteur et relancez le programme d'installation.%n%nRien n'a été installé.
; A game or the launcher is running (their mutexes)
SuiteRunning=Empire Earth, The Art of Conquest, NeoEE or the Empire Earth Launcher is running.%n%nClose it and start the setup again.%n%nNothing was installed.
de.SuiteRunning=Empire Earth, The Art of Conquest, NeoEE oder der Empire Earth Launcher läuft.%n%nBeenden Sie das Programm und starten Sie das Setup erneut.%n%nEs wurde nichts installiert.
fr.SuiteRunning=Empire Earth, The Art of Conquest, NeoEE ou l'Empire Earth Launcher est en cours d'exécution.%n%nFermez-le et relancez le programme d'installation.%n%nRien n'a été installé.
