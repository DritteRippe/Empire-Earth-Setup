# Testplan: Empire Earth Community Setup v2 auf echtem Windows

Dieser Plan beschreibt die Handtests des Setups auf echtem Windows (Laptop des Testers und
virtuelle Maschinen). Er gehört zur Architektur in [ARCHITECTURE.md](ARCHITECTURE.md) (Abschnitt 8,
Teststrategie) und zu den Entscheidungen in [docs/adr](adr/README.md). Was das Setup für den
Launcher hinterlässt, steht in [CONTRACT.md](CONTRACT.md).

Stand: vollständig. Gerüst aus Arbeitspaket S-WP2, Block 1 (Downloads, TP-10 bis TP-17) aus
S-WP3, Block 2 (Kompatibilität und Grafik, TP-20 bis TP-24) aus S-WP4, Block 3 (Build und Log,
TP-30) aus S-WP5, Block 4 (Installationseintrag und `install.ini`, TP-40 und TP-41) aus S-WP6,
Block 5 (Integritätsmanifest, TP-50) aus S-WP7, Block 6 (Umgebung, TP-60 bis TP-63) aus S-WP8,
Block 8 (Links in `Data` und `Users`, TP-80) aus S-WP11; S-WP9 hat die Build-Art A+ für das Update
über 1.7.2 ohne Daten der Maintainer, die Fälle TP-71 bis TP-79 von Block 7, die
Windows-8.1-Variante von TP-22 und die Entscheidungsregeln in TP-23 und TP-71 ergänzt. Alle Fälle
sind ausgearbeitet; jeder hat eine Priorität (P1 bis P3, [Abschnitt 4](#4-vorlage-je-fall)).
`ci/check_test_plan.py` prüft die Form dieses Dokuments (siehe
[Abschnitt 11](#11-automatische-prüfung-dieses-dokuments)).

Inhalt: [1. Zweck](#1-zweck) · [2. Sicherheitsregeln](#2-sicherheitsregeln) ·
[3. ID-Schema](#3-id-schema) · [4. Vorlage je Fall](#4-vorlage-je-fall) ·
[5. Testumgebungen und Snapshots](#5-testumgebungen-und-snapshots) ·
[6. Testbuild herstellen](#6-testbuild-herstellen) ·
[7. Kurzdurchlauf und Freigabe](#7-kurzdurchlauf-p1-und-freigabe) · [8. Testfälle](#8-testfälle) ·
[9. Forum-Testfälle §8](#9-forum-testfälle-8) · [10. Protokoll](#10-protokoll) ·
[11. Automatische Prüfung](#11-automatische-prüfung-dieses-dokuments)

Wer den Plan zum ersten Mal benutzt: [Abschnitt 2](#2-sicherheitsregeln) lesen, dann den
Kurzdurchlauf in [Abschnitt 7](#7-kurzdurchlauf-p1-und-freigabe); er führt durch die nötigen Teile
von Abschnitt 5, 6 und 8.

## 1. Zweck

- Prüfen, was CI und Unit-Tests nicht prüfen können: das Laufzeitverhalten des Setups auf echtem
  Windows (Assistent, Downloads, Registry, installierte Dateien, Update, Reparatur,
  Deinstallation) und, mit echten Daten, ob das Spiel danach läuft.
- Jede Annahme der ADRs, die nur auf Windows prüfbar ist, bekommt einen Fall mit eigener ID
  (`TP-xy`). Abnahmekriterien der Arbeitspakete verweisen auf diese IDs, statt „auf Windows
  testen“ zu schreiben.
- Die Testfälle für echtes Windows aus der Forumsstudie (save-ee.com, Bericht Abschnitt 8,
  Nummern 1 bis 22) sind in [Abschnitt 9](#9-forum-testfälle-8) einer ID zugeordnet oder
  begründet ausgenommen.
- Nicht Teil dieses Plans: der Launcher (eigene Tests im Launcher-Repository) und der Betrieb der
  Dateiserver; nur deren Zustand prüft [TP-00](#tp-00-server-vorabprüfung) vorab.

## 2. Sicherheitsregeln

Vor jedem Testtag lesen. Diese Regeln gehen jedem einzelnen Fall vor.

1. **VM bzw. Snapshot.** Ein Placeholder-Build (Weg A, [6.2](#62-weg-a-placeholder-build)) läuft
   nur in einer virtuellen Maschine, in der Windows-Sandbox oder auf einem Snapshot, nie auf dem
   Laptop über eine echte Installation. Ein Placeholder-Build mit den offiziellen AppIds (Weg A+,
   [6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids)) läuft nur in einer VM oder
   Sandbox, in der vorher das offizielle Setup 1.7.2 installiert wurde, **nie auf dem Laptop**,
   auch nicht „nur zum Ausprobieren“: Er ist für Windows dasselbe Produkt wie die echte
   Installation und überschreibt sie. Jeder Fall nennt seinen Ausgangs-Snapshot
   ([Abschnitt 5](#5-testumgebungen-und-snapshots)); vor dem Fall wird er wiederhergestellt. Ein
   echter Build (Weg B) darf auf dem Laptop laufen, aber nur mit Rückweg: vorher einen
   Wiederherstellungspunkt anlegen (*Systemsteuerung › System › Computerschutz*) und den
   Spielordner sowie `Data\Saved Games` sichern.
2. **Nur eigene, legal bezogene Spieldaten.** Getestet wird nur mit dem eigenen Spiel (Original-CD,
   Gold Edition oder digitaler Kauf, z. B. GOG) und mit Daten, die man selbst erhalten hat.
   Keine Spieldaten von Dritten, keine Cracks, keine Keygens. Die Rechtsfrage des Setups
   (`LegalQuestion`) wird wahrheitsgemäß beantwortet.
3. **`Software\Sierra\CDKeys` nie löschen**, in keiner Registry-Ansicht und keinem Zweig (HKLM,
   `HKLM\SOFTWARE\WOW6432Node`, HKCU), auch nicht beim Aufräumen nach einem Test. Dort liegen die
   NeoEE-CD-Keys; danach meldet das Spiel „CD key invalid“ (Forumsbericht 4.19). Die Werte gehören
   auch nicht in Protokolle oder Bildschirmfotos.
4. **Testbuilds nie weitergeben.** Weder Weg A noch A+ noch B: nicht hochladen (auch nicht zu
   Online-Virenscannern), nicht in Cloud-Ordner legen, nicht im Forum oder auf Discord teilen.
   Nach der Testrunde den Ordner `out\` und die Kopien in den VMs löschen. Testbuilds zeigen beim
   Start „DIES IST EIN TEST-SETUP, ID = …“ (`TestSetupWarning`).
5. **Netzwerk.** Das Setup spricht mit `api.empireearth.eu` (Updateprüfung), den Dateiservern
   (Downloads, [TP-00](#tp-00-server-vorabprüfung)) und, beim NeoEE-Setup mit der Aufgabe
   „CD-Keys“, mit `neoee.net:10003`. Statistiken sendet es nur mit Zustimmung: In Tests die
   Telemetrie-Zustimmung auf der Seite „Installationsmodus“ abwählen (Komponente
   `additional\telemetry`), damit Testläufe nicht als echte Installationen zählen.
6. **Wo das Setup-Log liegt.** Jeder Testlauf schreibt ein Log an eine feste Stelle: Setup und
   Deinstallation immer mit `/LOG="C:\EE-Test\logs\<TP-ID>_<Variante>.log"` starten (Ordner vorher
   anlegen). Ohne Schalter schreibt jedes Setup seit S-WP5 (`SetupLogging=yes`) sein Log nach
   `%TEMP%\Setup Log <Datum> #<n>.txt` (im Explorer `%TEMP%` eingeben), bei
   Over-the-Shoulder-Erhöhung in das `%TEMP%` des Administratorkontos, das die Erhöhung bestätigt
   hat ([TP-30](#tp-30-prüfsumme-des-setups-und-setup-log-ohne-schalter)). Die Deinstallation
   schreibt nur mit `/LOG` ein Log: `"<Installationsordner>\unins000.exe" /LOG="C:\EE-Test\logs\…"`.
   Das Log enthält keine CD-Keys, aber Pfade mit dem Benutzernamen: vor dem Weitergeben ansehen.

## 3. ID-Schema

Eine ID hat die Form `TP-` und zwei Ziffern. Die erste Ziffer ist der Block, also das
Arbeitspaket, das den Fall einführt; `TP-1x` steht für alle zehn IDs von Block 1, auch die noch
nicht vergebenen. Die ID eines ausgearbeiteten Falls wird nie neu vergeben oder umnummeriert
(Protokolle verweisen auf sie); ein Fall, der wegfällt, bleibt mit `Status: entfällt: <Grund>`
stehen. Ein geplanter Fall hat noch kein Protokoll: Das Paket seines Blocks darf ihn beim
Ausarbeiten aufteilen und die geplanten IDs des Blocks neu ordnen (S-WP4: die Grafikmatrix steht
jetzt unter TP-23, TP-21 ist das Update unter Windows 7). Neue Fälle bekommen die nächste freie
Nummer ihres Blocks. Ein neues Arbeitspaket mit eigenen Fällen bekommt den nächsten freien Block
(S-WP11: Block 8, weil Block 7 schon die allgemeinen Abläufe enthält); die Blöcke stehen in
[Abschnitt 8](#8-testfälle) in der Reihenfolge ihrer Nummern.

| IDs | Block | Paket | Inhalt |
|---|---|---|---|
| TP-00 | Vorabprüfung | S-WP2 | Zustand der beiden Dateiserver vor jedem Testtag mit Downloads |
| TP-1x | Downloads | S-WP3 | eingebaute Downloads statt IDP: Hauptserver ungültig und Spiegel (TP-10), offline (TP-11), Stopp-Knopf am ersten und am zweiten Server (TP-12, TP-13), Silent (TP-14), Koreanisch (TP-15), verworfener Download (TP-16), TLS 1.2 unter Windows 7 (TP-17) |
| TP-2x | Kompatibilität und Grafik | S-WP4, S-WP10 | Windows 7 ohne Kompatibilitätswerte und mit der freiwilligen Aufgabe `compatibility_legacy` (TP-20), Bereinigung beim Update unter Windows 7, auch mit `compatibility_legacy` (TP-21), Windows 10/11 unverändert, optional Windows 8.1 (TP-22), Grafikmatrix mit und ohne DirectX-Wrapper und die Entscheidungsregel aus ADR 0010 (TP-23), 150 % Anzeigeskalierung mit und ohne `compatibility` bzw. `compatibility_legacy` (TP-24) |
| TP-3x | Build und Log | S-WP5 | SHA-256-Dateien der Setups und Setup-Log ohne `/LOG`, auch bei Over-the-Shoulder-Erhöhung (TP-30) |
| TP-4x | Installationseintrag und `install.ini` | S-WP6 | Installationseintrag, `install.ini`, Defaults-Marker, `SetupBuild` und der Wert `Empire Earth Community: ContractVersion` im Uninstall-Schlüssel je Variante, auch bei schreibgeschützter oder geöffneter `install.ini` und nach dem Setup 1.7.2, Deinstallation (TP-40); Spieleinstellungen und Marker beim installierenden und bei einem zweiten Konto, Over-the-Shoulder-Erhöhung (TP-41) |
| TP-5x | Integritätsmanifest | S-WP7 | `files.sha256` je Variante (Inhalt geprüft mit `Get-FileHash` bzw. `sha256sum -c`), von einem Virenscanner gelöschte Dateien mit Hinweis und `[MissingAfterInstall]`, eine gesperrte Datei, Dauer des Prüfens auf dem Laptop und auf HDD bzw. unter Windows 7 (TP-50) |
| TP-6x | Umgebung | S-WP8 | Hinweis unter 768 Pixeln Höhe und Bildschirm, DPI und Spielfenster im Log (TP-60), fremde und alte Installationen: Schlüssel in HKLM, fremde Uninstall-Einträge, CD-Ordner, Wortlaut zu den CD-Keys (TP-61), EE und NeoEE in einem Ordner (TP-62), Installation in den Ordner einer GOG- oder CD-Installation (TP-63) |
| TP-7x | Allgemeine Abläufe und Forumfälle | S-WP2, S-WP9 | Grundablauf mit Update über 1.7.2 (TP-70), Standardnutzer und VirtualStore (TP-71), Version und Mehrspieler (TP-72), Reparatur (TP-73), AoC ohne EE-Start (TP-74), EE und NeoEE getrennt, eines deinstalliert (TP-75), Firewall beim Hosten (TP-76), CD-Keys (TP-77), Deutsch (TP-78), laufendes Spiel (TP-79) |
| TP-8x | Links in den für alle beschreibbaren Ordnern | S-WP11 | Ein Standardbenutzer ersetzt `Data\Movies` durch eine Junction; das Update als Administrator hält auf der Seite „Vorbereitung der Installation“ an, ändert nichts und läuft nach dem Entfernen des Links durch; still Exit-Code 7; ein Link im Spielerordner unter `Users` hält ebenfalls an (TP-80) |

## 4. Vorlage je Fall

Jeder Fall ist eine Überschrift `#### TP-xy: <Titel>` im Block seines Pakets (Abschnitt 8) mit
dieser Liste darunter. Ein ausgearbeiteter Fall hat alle Felder; ein geplanter Fall hat mindestens
`Status`, `Priorität`, `Bezug` und `Ziel`.

```markdown
#### TP-xy: <Titel>

- **Status:** ausgearbeitet | geplant: S-WPn | entfällt: <Grund>
- **Priorität:** P1 | P2 | P3
- **Bezug:** Anforderung (R…), ADR, Vertrag, Forum (§8 Nr., t=…/p=…)
- **Ziel:** was der Fall zeigen soll (ein Satz)
- **Build-Art:** A (Placeholder-Build) | A+ (Placeholder-Build mit den offiziellen AppIds) | B (echter Build) | A oder B | keine (kein Setup nötig)
- **Ausgangszustand:** was vor dem Fall installiert bzw. eingestellt ist
- **Snapshot:** Name aus Abschnitt 5, der vor dem Fall wiederhergestellt wird
- **Varianten:** welche von EE/NeoEE × admin/user/portable; ausgelassene mit Grund
- **Schritte:**
  1. …
- **Erwartetes Ergebnis:** woran der Tester „bestanden“ erkennt
- **Log-Hinweis:** welche Zeilen im Setup-Log das Ergebnis belegen
```

Varianten werden als `EE-admin`, `EE-user`, `EE-portable`, `NeoEE-admin`, `NeoEE-user`,
`NeoEE-portable` geschrieben:

- **admin:** reguläres Setup (`EE_Setup_v…`, `NeoEE_v…_Setup_v…`), Frage „Für alle Benutzer
  installieren“ bzw. Schalter `/ALLUSERS`; Ziel `C:\Program Files (x86)\Empire Earth` bzw.
  `…\Neo Empire Earth`.
- **user:** reguläres Setup, „Nur für mich installieren“ bzw. `/CURRENTUSER`; Ziel
  `%LOCALAPPDATA%\Programs\…`, keine Firewall-Regeln.
- **portable:** Portable-Setup (`EE_Portable_Setup_v…`, `NeoEE_Portable_v…_Setup_v…`), ohne
  Deinstallation und ohne Uninstall-Schlüssel; Ziel `<Ordner des Setups>\Empire Earth Portable`
  bzw. `…\Neo Empire Earth Portable`.

`Priorität` sagt, wann ein Fall gebraucht wird; jeder Fall hat genau eine (Pflichtfeld, auch bei
geplanten Fällen):

- **P1:** gehört zum Kurzdurchlauf vor jeder Freigabe: zusammen höchstens drei Stunden, auf dem
  Laptop, in der Windows-Sandbox oder in einer VM mit Windows 10/11. Welche Teile eines P1-Falls
  dazugehören, sagt sein Feld `Priorität` (z. B. `P1 (Teile a und b; c: P2)`); den Ablauf und das
  Freigabekriterium (alle P1-Fälle bestanden oder mit Grund ausgenommen) beschreibt
  [Abschnitt 7](#7-kurzdurchlauf-p1-und-freigabe).
- **P2:** wichtig, aber außerhalb des Kurzdurchlaufs: braucht mehr Zeit, echte Spieldaten über
  Weg A hinaus oder eine besondere Ausgangslage (zweites Konto, langsame Leitung, Grafikmatrix,
  hohe Anzeigeskalierung). Vor einer Freigabe erwünscht; ein ausgelassener P2-Fall steht mit Grund
  im Protokoll.
- **P3:** optional: nur mit besonderer Umgebung (Windows 7 oder 8.1 in einer VM, ein zweiter
  Rechner für Mehrspieler, eine Original-CD) oder für Befunde ohne Einfluss auf die Freigabe.

Das Paket, das einen geplanten Fall ausarbeitet, darf seine Priorität mit Begründung ändern (im
Feld selbst, z. B. `P2 (P1 bei Weg B)`, oder in der Commit-Nachricht).

## 5. Testumgebungen und Snapshots

| Snapshot | Inhalt | wofür |
|---|---|---|
| `S-Basis` | VM mit Windows 11 oder 10 (64 Bit), aktuelle Updates, kein Empire Earth, keine Reste alter Installationen; ein Administratorkonto und ein Standardkonto „Spieler“; Netzwerk an | Erstinstallation, Weg A und B |
| `S-Sandbox` | Windows-Sandbox (Windows 10/11 Pro): startet jedes Mal frisch, ohne 3D-Beschleunigung, ein Konto mit Administratorrechten | schnelle Läufe mit Weg A (das Spiel startet dort nicht); mit dem offiziellen Setup 1.7.2 in derselben Sitzung auch Weg A+ (siehe unten) |
| `S-172-EE`, `S-172-NeoEE` | `S-Basis` plus offizielles Setup 1.7.2 (EE bzw. NeoEE) als Administrator installiert, einmal gestartet | Update über 1.7.2, Weg A+ oder B |
| `S-Win7` | VM mit Windows 7 SP1 (64 Bit), ohne KB3140245 und ohne SChannel-Änderungen | TLS 1.2 und Kompatibilitätswerte unter Windows 7 (S-WP3, S-WP4) |
| `S-Win7-172-EE` | `S-Win7` plus offizielles Setup 1.7.2 (EE) als Administrator mit „Empfohlene Einstellungen“ und AoC installiert, einmal gestartet | Update über 1.7.2 unter Windows 7 (TP-21), Weg A+ oder B |
| `S-Win81` | VM mit Windows 8.1 (64 Bit), aktuelle Updates, kein Empire Earth | nur die Windows-8.1-Variante von TP-22 (P3) |
| `S-Alt` | `S-Basis` plus eine alte Installation: Original-CD unter `C:\Sierra\Empire Earth` bzw. GOG-Version | fremde und alte Installationen (S-WP8) |
| `Laptop` | das echte System des Testers, mit Wiederherstellungspunkt und Sicherung (Regel 1) | nur Weg B |

Die Windows-7-VM bekommt nur Fälle, die das ausdrücklich verlangen; sie hat keinen aktuellen
Browser, `TP-00` läuft deshalb auf dem Laptop.

**Windows-Sandbox.** Sie gibt es nur in Windows 10/11 Pro, Enterprise und Education
(*Windows-Features aktivieren oder deaktivieren › Windows-Sandbox*); unter Windows Home übernimmt
eine VM mit dem Snapshot `S-Basis` ihre Rolle. Alles in der Sandbox ist beim Schließen weg, auch die
Logs. Deshalb eine Konfigurationsdatei anlegen, die den Ordner `C:\EE-Test` des Laptops beschreibbar
in die Sandbox legt (er erscheint dort auf dem Desktop), und die Sandbox per Doppelklick auf diese
Datei starten:

```xml
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\EE-Test</HostFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
</Configuration>
```

Gespeichert als `C:\EE-Test\EE-Test.wsb`; für Läufe ohne Netz eine Kopie `EE-Test-offline.wsb` mit
der zusätzlichen Zeile `<Networking>Disable</Networking>` direkt unter `<Configuration>`. Die Setups
liegen in `C:\EE-Test\setups` (vom Laptop dorthin kopiert) und werden in der Sandbox vom Desktop
gestartet. In der Sandbox den Ordner `C:\EE-Test\logs` anlegen (Regel 6) und vor dem Schließen die
Logs auf den freigegebenen Ordner kopieren:
`xcopy C:\EE-Test\logs "%USERPROFILE%\Desktop\EE-Test\logs\" /y`.

**`S-172-EE` in der Sandbox.** Für den Kurzdurchlauf lässt sich `S-172-EE` in einer frischen
Sandbox-Sitzung herstellen: das offizielle EE-Setup 1.7.2 (selbst heruntergeladen, in
`C:\EE-Test\setups`) als Administrator mit „Empfohlene Einstellungen“ und AoC installieren,
Spielsprache Englisch (keine Downloads), Telemetrie aus. Das Spiel startet in der Sandbox nicht;
der Schritt „einmal gestartet“ entfällt. Er ändert nichts, was die Update-Fälle prüfen (Registry
des Setups, versteckter Setup-Ordner, Kompatibilitätswerte), nur Dateien, die das Spiel selbst
anlegt. Nach dem Schließen der Sandbox ist der Zustand weg und wird beim nächsten Mal neu
hergestellt.

## 6. Testbuild herstellen

Ein Testbuild ist ein Setup mit `TestID > 0`: schnelle Kompression (`zip/1`) und beim Start die
Warnung `TestSetupWarning` mit der Nummer. `MySetupVersion` bleibt `1.7.2`, damit die Update-API
den Testbuild nicht als veraltet meldet; Testbuilds unterscheidet der Wert `SetupBuild`:
`ci\build.ps1` setzt `test<TestID>-<Commit>` (der kurze Git-Commit der Arbeitskopie, ohne Git nur
`test<TestID>`) und gibt ihn beim Bauen als `SetupBuild: …` aus. Er steht in `install.ini`, im
Installationseintrag und in der ersten eigenen Zeile des Setup-Logs
([TP-40](#tp-40-installationseintrag-und-installini-je-variante)).

Es gibt drei Wege; die Build-Art jedes Falls nennt, welche er braucht:

| Weg | Spieldaten | AppIds | wofür | wo |
|---|---|---|---|---|
| A ([6.2](#62-weg-a-placeholder-build)) | Platzhalter | Platzhalter (eigenes Produkt) | Mechanik einer Erstinstallation, Reparatur, Deinstallation | VM, Windows-Sandbox, Snapshot |
| A+ ([6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids)) | Platzhalter | die offiziellen (aus der eigenen Installation abgelesen) | Mechanik des Updates über 1.7.2 ohne Daten der Maintainer | nur VM bzw. Sandbox mit dem offiziellen Setup 1.7.2 (`S-172-*`, `S-Win7-172-EE`) |
| B ([6.3](#63-weg-b-echter-build-aus-eigenen-daten)) | eigene echte Daten | die offiziellen | alles, auch Spielstart und Dauer mit echten Daten | Laptop (mit Rückweg, Regel 1) oder VM |

### 6.1 Voraussetzungen (alle Wege)

- Windows 10 oder 11, Windows PowerShell 5.1 (eingebaut) oder PowerShell 7.
- Eine Arbeitskopie dieses Repositorys mit dem Stand, der getestet wird (Branch `v2`). Den Commit
  notieren (`git log -1 --oneline`), er kommt ins Protokoll.
- **Inno Setup 6.2.2**, genau diese Version (ADR 0002; neuere Versionen bauen dieses Skript nicht
  unverändert). Aus dem Download-Archiv von jrsoftware.org oder mit
  `choco install innosetup --version=6.2.2`. `ci\build.ps1` findet `ISCC.exe` im Standardordner
  `C:\Program Files (x86)\Inno Setup 6\`, sonst `-Iscc <Pfad>`; `-RequireVersion 6.2.2` bricht bei
  einer anderen Version ab.
- Python 3 nur für Weg A und A+ (`ci\make_placeholder_assets.py`; `python` im `PATH`, sonst
  `-Python <Pfad>`).

### 6.2 Weg A: Placeholder-Build

> **Warnung:** Einen Placeholder-Build nur in einer VM, in der Windows-Sandbox oder auf einem
> Snapshot ausführen, **nie über eine echte Installation**. Er ersetzt die Spieldateien durch
> Platzhalter-Textdateien, löscht vorher alte EXE- und Wrapper-Dateien (`[InstallDelete]`),
> überschreibt die Spieleinstellungen in HKCU und legt Firewall-Regeln an. Sein Standardordner
> ist derselbe wie der einer echten Installation.

Wofür: nur die Mechanik des Setups (Assistent, Fragen und Hinweise, Registry, geschriebene
Dateien, Downloads, Deinstallation). Das Spiel startet damit nicht.

1. **`EEStatsSetup.dll` bereitstellen.** Das Setup lädt diese DLL beim Start (`eestats.iss`,
   Import ohne `delayload`); ein Platzhalter ist keine DLL, das Setup bricht dann sofort mit einem
   Laufzeitfehler ab. Die echte Datei aus einer eigenen Installation des Community-Setups nach
   `data\Add-on\DLLs\EEStats\EEStatsSetup.dll` kopieren (Ordner anlegen). Sie liegt im versteckten
   Ordner `<Spielordner>\_setupdata_EE` (bzw. `_setupdata_NeoEE`), bei Installationen bis 1.7.2
   im versteckten Ordner `<Spielordner>\<AppId>`. Der Placeholder-Generator überschreibt
   vorhandene Dateien nie.
2. **Bauen** (im Repository-Ordner):

   ```powershell
   powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders -TestID 1
   ```

   Ergebnis: vier Setups in `out\EE_Regular`, `out\NeoEE_Regular`, `out\EE_Portable`,
   `out\NeoEE_Portable`. Die AppIds sind Platzhalter (`00000000-…-0000000000EE` bzw.
   `…0AEE`): Der Testbuild ist ein eigenes Produkt mit eigenem Eintrag unter „Apps“, kein Update
   einer echten Installation.
3. **Grenzen von Weg A**, die in den Fällen als erwartet gelten:
   - Die Aufgabe „DirectX-Endbenutzer-Runtime installieren“ (`dxwebsetup`, aktiv mit dem
     DX9-Wrapper oder ohne Wrapper) startet einen Platzhalter und meldet, dass die Datei nicht
     ausgeführt werden kann. Abwählen (benutzerdefinierte Installation) oder
     `/MERGETASKS="!dxwebsetup"`.
   - NeoEE: Die CD-Key-Registrierung scheitert am Platzhalter von `authtools.dll` (Hinweis
     `CDKeysToolMissing`).
   - Downloads: Die Pins entstehen aus den Platzhaltern in `data\localized-text`. Eine echte
     `Language.dll` vom Server passt nicht dazu und wird verworfen und gemeldet; ungepinnte
     Datendateien (Stimmen, Kampagnen, Video, Lobby-Dateien) werden über geprüftes TLS angenommen.
   - Keine Musik, Platzhalterbilder im Assistenten.

### 6.3 Weg B: echter Build aus eigenen Daten

Wofür: realistische Installation, Update über 1.7.2, Reparatur und alle Fälle, in denen das
Spiel gestartet wird. Der Build verlässt den Laptop bzw. die VM nie (Regel 4).

**Woher die Daten kommen.** Ein echter Build braucht `data\` (Spieldateien, Add-ons,
`localized-text`), `internal\media` (Bilder des Assistenten), `internal\misc\Loop.flac` und
`internal\runtime\directx\dxwebsetup.exe` (siehe README, „Assets“). Es gibt zwei Quellen:

1. **Ein vorhandener `data\`-Ordner**: der Build-Ordner, aus dem die offiziellen Setups gebaut
   werden. Ihn haben die Maintainer; er ist die Quelle jedes Releases. Ein Tester bekommt ihn nur
   von ihnen, für den eigenen Test, und gibt ihn nicht weiter.
2. **Rekonstruktion aus selbst heruntergeladenen offiziellen Setups 1.7.2.** Technisch möglich:
   Die Analyse für v2 hat `data\` aus dem EE- und dem NeoEE-Setup 1.7.2 byte-genau
   rekonstruiert und beide Setups daraus identisch nachgebaut. Dafür braucht es Werkzeuge, die
   nur unter Linux oder WSL laufen (ein angepasster Debug-Build von innoextract, ISCC unter Wine,
   das Upstream-Skript als zweiter Arbeitsbaum).

**Entscheidung: Die Rekonstruktionswerkzeuge kommen nicht in dieses Repository.** Gründe:

- Sie sind Analysewerkzeuge, keine Build-Werkzeuge: Linux/WSL, ein selbst gepatchtes innoextract,
  Wine und das Upstream-Skript als Voraussetzung. Auf dem Windows-Laptop vereinfachen sie nichts,
  und im Repository bräuchten sie Pflege und Tests, die ohne die Installer nicht in CI laufen.
- Ihr einziger Zweck ist, aus den offiziellen Installern wieder einen baufähigen Datenbaum zu
  machen. Im öffentlichen Repository machten sie das Umpacken der Spieldaten in eigene Setups
  trivial; davor warnt die README („Notes for Modders“: keine Spaltung in viele Spielversionen).
  Ob die Community das will und rechtlich darf, entscheiden die Maintainer, nicht ein
  Arbeitspaket.
- Für Releases ist der `data\`-Ordner der Maintainer die Quelle, nicht eine Rekonstruktion.

Folge: Weg B setzt Quelle 1 voraus, oder eine Rekonstruktion, die der Tester selbst mit eigenen
Werkzeugen aus selbst heruntergeladenen Setups erstellt (nur lokal, nie weitergeben). Ohne Daten
gibt es nur Weg A und Weg A+ ([6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids)); Fälle
und Teile mit Build-Art B kommen dann ins Protokoll als „nicht durchgeführt: keine Daten“.

**Schritte:**

1. **Daten einsetzen**: `data\`, `internal\media`, `internal\misc`, `internal\runtime` in die
   Arbeitskopie kopieren (alle stehen in `.gitignore` und werden nie committet). Wurde in derselben
   Arbeitskopie vorher Weg A gebaut, zuerst die Ordner `data`, `internal\media`, `internal\misc`,
   `internal\runtime`, `tools` und `out` löschen: `ci\build.ps1` ohne `-Placeholders` erzeugt
   keine Platzhalter, nimmt vorhandene aber mit.
2. **Offizielle AppIds ablesen.** Der Testbuild braucht dieselben AppIds wie die veröffentlichten
   Setups, sonst ist er für Windows ein anderes Produkt (eigener Eintrag unter „Apps“, kein Update
   an Ort und Stelle). Im Repository sind sie absichtlich leer (README, „AppIds“). Sie stehen im
   Namen des Uninstall-Schlüssels `{<AppId>}_is1` einer Installation 1.7.2 (oder einer anderen
   Installation des Community-Setups) und lassen sich in der Eingabeaufforderung ablesen:

   ```bat
   reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Empire Earth Community" /d /reg:64
   reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Empire Earth Community" /d
   ```

   Die erste Zeile gilt für Installationen als Administrator (das Setup schreibt den Schlüssel auf
   64-Bit-Windows in die 64-Bit-Ansicht; findet sie nichts, dieselbe Abfrage mit `/reg:32`), die
   zweite für Installationen „nur für mich“; auf 32-Bit-Windows `/reg:64` weglassen. Jeder Treffer
   nennt einen Schlüssel wie
   `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}_is1`
   mit `Publisher    REG_SZ    Empire Earth Community` (EE) bzw.
   `Empire Earth Community & NeoEE` (NeoEE). Zur Kontrolle
   `reg query "<Schlüssel>" /v DisplayName`: `Empire Earth v2.0.0.0 - Setup v1.7.2` bzw.
   `NeoEE v2.0.0.5 - Setup v1.7.2` (bei älteren Setups deren Versionen; die AppIds bleiben über
   alle Versionen gleich). Die AppId ist die GUID zwischen den geschweiften Klammern,
   ohne Klammern und ohne `_is1`. Die beiden AppIds ins Protokoll schreiben, nicht in Dateien des
   Repositorys.
3. **Zuerst die Hashliste schreiben** und prüfen, dass `data\localized-text` vollständig ist:

   ```powershell
   powershell -ExecutionPolicy Bypass -File ci\build.ps1 -DownloadHashesOnly
   ```

   Erwartet: `Download hashes: <n> file(s) of …\data\localized-text -> …\data\localized-text.sha256`
   (mit den offiziellen Daten 1.7.2: 124 Dateien). Eine Warnung „not found“ heißt, dass
   `data\localized-text` fehlt: Dann lädt das Setup keine `Language.dll` herunter.
4. **Bauen:**

   ```powershell
   powershell -ExecutionPolicy Bypass -File ci\build.ps1 -EEAppID <EE-AppId> -NeoEEAppID <NeoEE-AppId> -TestID 1 -RequireVersion 6.2.2
   ```

   Erwartet: die Warnung „Test build 1: … never distribute it“, `SetupBuild: test1-<Commit>`
   (ins Protokoll), dann `PASS EE/Regular -> …` für
   alle vier Varianten und `All 4 variant(s) built into …\out`, also
   `out\EE_Regular\EE_Setup_v1.7.2.exe`, `out\NeoEE_Regular\NeoEE_v2.0.0.5_Setup_v1.7.2.exe`,
   `out\EE_Portable\EE_Portable_Setup_v1.7.2.exe` und
   `out\NeoEE_Portable\NeoEE_Portable_v2.0.0.5_Setup_v1.7.2.exe`. In der Analyse (unter Wine)
   dauerte das rund vier Minuten; jedes Setup ist etwa 650 MB (EE) bzw. 700 MB (NeoEE) groß. Nur
   eine Variante: `-Variants EE/Regular`. Ohne `-TestID` entstünde ein Release-Build, der sich von
   einem veröffentlichten Setup nicht unterscheiden lässt: für Tests nie ohne `-TestID` bauen, nie
   signieren.
5. Nach der Testrunde `out\` löschen (Regel 4).

### 6.4 Weg A+: Placeholder-Build mit den offiziellen AppIds

> **Warnung:** Ein A+-Build ist für Windows **dieselbe Anwendung** wie das veröffentlichte Setup.
> Auf einem Rechner mit einer echten Installation desselben Produkts aktualisiert er diese
> Installation an Ort und Stelle und ersetzt die Spieldateien durch Platzhalter; das Spiel startet
> danach nicht mehr, und seine Deinstallation entfernt die ganze Installation. Deshalb nur in einer
> VM bzw. Sandbox mit dem offiziellen Setup 1.7.2 (`S-172-EE`, `S-172-NeoEE`, `S-Win7-172-EE`, die
> Sandbox wie in [Abschnitt 5](#5-testumgebungen-und-snapshots)), **nie auf dem Laptop** und nie
> weitergeben (Regel 4).

Wofür: die Mechanik des Updates über eine Installation des offiziellen Setups 1.7.2, ohne die
Daten der Maintainer (Weg B). Dieselbe AppId lässt Inno Setup die vorhandene Installation
erkennen: derselbe Ordner, die Komponenten und Aufgaben des vorigen Laufs, die Option „Vorhandene
Installation reparieren“ auf der Seite „Installationsmodus“ (Spiel- und Setup-Version sind gleich,
deshalb nicht „Aktuelle Installation aktualisieren“), derselbe Uninstall-Schlüssel. Damit prüfbar:
das Entfernen des alten versteckten Ordners `<Spielordner>\<AppId>`, die Bereinigung alter
Kompatibilitätswerte und des alten `~ RUNASADMIN`, der neue Installationseintrag, `install.ini`,
`files.sha256` und der Wert `Empire Earth Community: ContractVersion` im Uninstall-Schlüssel nach
einem Update, und dass unter „Apps“ genau ein Eintrag bleibt.

1. **`EEStatsSetup.dll` bereitstellen** wie in [6.2](#62-weg-a-placeholder-build) Schritt 1. Bei
   einer Installation 1.7.2 liegt sie im versteckten Ordner `<Spielordner>\<AppId>` (z. B. in der
   Sandbox nach der Installation von 1.7.2: `dir /a "C:\Program Files (x86)\Empire Earth"`).
2. **Offizielle AppIds ablesen** wie in [6.3](#63-weg-b-echter-build-aus-eigenen-daten) Schritt 2:
   aus der eigenen Installation des Community-Setups auf dem Laptop (nur lesen) oder einmalig in der
   VM bzw. Sandbox nach der Installation des offiziellen Setups 1.7.2. Die AppIds ändern sich über
   die Versionen nicht; einmal ins Protokoll geschrieben, gelten sie für alle weiteren Runden.
3. **Bauen** (im Repository-Ordner, in einen eigenen Ausgabeordner, damit die Setups nicht mit denen
   von Weg A verwechselt werden):

   ```powershell
   powershell -ExecutionPolicy Bypass -File ci\build.ps1 -Placeholders -EEAppID <EE-AppId> -NeoEEAppID <NeoEE-AppId> -TestID 1 -OutputDir out\aplus
   ```

   `-Placeholders` setzt Platzhalter-AppIds nur für die Produkte ein, deren AppId fehlt. Wer nur das
   EE-Setup 1.7.2 hat, baut nur EE: `-EEAppID <EE-AppId> -Variants EE/Regular` (NeoEE bekommt die
   Platzhalter-AppId und wird nicht gebaut). Erwartet: die Warnungen „Test build 1: …“ und
   „Placeholder build: …“, `SetupBuild: test1-<Commit>`, `PASS EE/Regular -> EE_Setup_v1.7.2.exe`
   und `All <n> variant(s) built into …\out\aplus`; das EE-Setup liegt in
   `out\aplus\EE_Regular\EE_Setup_v1.7.2.exe`. Im Protokoll steht als Build `A+, 1, <Commit>`.
4. Nach der Testrunde `out\aplus` löschen (Regel 4).

**Grenzen von Weg A+** (gelten in den Fällen als erwartet):

- Alle Grenzen von Weg A ([6.2](#62-weg-a-placeholder-build) Schritt 3): `dxwebsetup`, die
  CD-Key-Registrierung von NeoEE (`CDKeysToolMissing`), verworfene gepinnte Downloads, keine Musik.
- Nach dem Update sind die Spieldateien Platzhalter: kein Spielstart, keine Aussage darüber, ob die
  Dateien von 1.7.2 und von v2 zusammenpassen (das zeigt der Vergleich mit den echten Daten der
  Maintainer und Weg B). `files.sha256` enthält die Prüfsummen der Platzhalter.
- Nur Produkte mit offizieller AppId sind ein Update. Ein EE-Build ohne die offizielle NeoEE-AppId
  erkennt eine NeoEE-Installation 1.7.2 nicht als „das andere Produkt“ (Frage
  `SharedFolderQuestion`, [TP-62](#tp-62-ee-und-neoee-im-selben-ordner) (d)): dafür beide AppIds
  angeben.
- Die Deinstallation des A+-Builds entfernt die Installation 1.7.2 mit (es ist dieselbe); der
  Ausgangszustand kommt nur über den Snapshot bzw. eine neue Sandbox zurück.

### 6.5 Silent-Tests

Testbuilds zeigen die Warnung `TestSetupWarning` auch im Silent-Modus (`setup_is6.iss`:
„shown even in silent mode“). Ohne `/SUPPRESSMSGBOXES` wartet ein Silent-Setup deshalb auf einen
Klick. Silent-Tests immer so starten:

```bat
EE_Setup_v1.7.2.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\EE-Test\logs\TP-70_EE-admin_silent.log"
```

Dazu je nach Variante `/ALLUSERS` oder `/CURRENTUSER`, bei Weg A `/MERGETASKS="!dxwebsetup"`. Im
Silent-Modus überspringt das Setup die Updateprüfung, die Rechtsfrage und die Hinweise zum
Installationsmodus. Deinstallation:

```bat
"<Installationsordner>\unins000.exe" /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\EE-Test\logs\TP-70_EE-admin_silent_uninstall.log"
```

## 7. Kurzdurchlauf (P1) und Freigabe

Der Kurzdurchlauf ist der Test vor jeder Freigabe: alle P1-Fälle mit ihren P1-Teilen (das Feld
`Priorität` jedes Falls nennt sie), zusammen höchstens drei Stunden auf dem Laptop und in der
Windows-Sandbox ([Abschnitt 5](#5-testumgebungen-und-snapshots)). Er braucht keine Daten der
Maintainer: Die Mechanik prüft Weg A, das Update über 1.7.2 Weg A+
([6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids)); nur der letzte Schritt braucht
Weg B. Windows 7, Windows 8.1, Original-CD und GOG, zweite Konten und zweite Rechner sind P2 oder
P3 und gehören nicht dazu.

**Freigabekriterium.** Ein Stand (Commit) ist freigegeben, wenn jeder P1-Fall mit allen seinen
P1-Teilen im Protokoll „bestanden“ hat oder mit Grund ausgenommen ist. Gültige Gründe sind:

- „nicht durchgeführt: keine Daten“ für die Teile mit Weg B, wenn es keine Daten der Maintainer
  gibt (Schritt K10 unten);
- die Ausnahmen, die ein Fall selbst nennt (z. B. TP-10, wenn nach TP-00 nur der Hauptserver
  gültig ist: „nicht durchgeführt: Spiegel ungültig“).

Ein „Fehler“ in einem P1-Teil verhindert die Freigabe, bis eine Korrektur ihn in einem neuen
Kurzdurchlauf behebt. Über eine „Abweichung“ entscheiden die Maintainer; die Entscheidung steht in
der Bemerkung des Protokolls. Findet [TP-00](#tp-00-server-vorabprüfung) keinen Dateiserver mit
gültigem Zertifikat, ist das ein Release-Blocker auf Serverseite (ADR 0006), keine Ausnahme. P2- und
P3-Fälle verhindern die Freigabe nicht; ein ausgelassener P2-Fall steht mit Grund im Protokoll. Die
Freigabe gilt für den getesteten Commit: Ändert ein späterer Commit das kompilierte Setup, braucht
er einen neuen Kurzdurchlauf.

**Vorbereitung** (einmal, nicht in den drei Stunden): Inno Setup 6.2.2, Python 3 und Git auf dem
Laptop, eine Arbeitskopie des Branches ([6.1](#61-voraussetzungen-alle-wege)); die Windows-Sandbox
mit den beiden `.wsb`-Dateien aus [Abschnitt 5](#5-testumgebungen-und-snapshots); das offizielle
EE-Setup 1.7.2, selbst heruntergeladen, in `C:\EE-Test\setups`; `EEStatsSetup.dll` und die
offiziellen AppIds ([6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids) Schritte 1 und 2,
ohne eigene Installation einmal in der Sandbox nach der Installation von 1.7.2). Unter Windows Home
tritt eine VM mit dem Snapshot `S-Basis` an die Stelle der Sandbox; „Sandbox neu starten“ heißt dann
„Snapshot zurücksetzen“.

**Ablauf.** Die Schritte legen Fälle zusammen, die denselben Ausgangszustand brauchen: Ein Lauf
belegt dann mehrere Fälle. Das Log heißt nach dem ersten Fall des Laufs (Regel 6), im Protokoll
steht je Fall eine Zeile mit derselben Log-Datei. Jeder Schritt in der Sandbox beginnt mit einer
frisch gestarteten Sandbox und endet mit dem Kopieren der Logs. Die Minuten gelten für eine Leitung
mit etwa 50 Mbit/s: Jede Installation mit Spielsprache Deutsch lädt rund 0,5 GB (Stimmen und
Kampagnen von EE und AoC). Ist die Leitung deutlich langsamer, in den Läufen, die keinen Download
prüfen (alle außer TP-10, TP-11 und TP-14), Englisch als Spielsprache wählen: dann gibt es keine
Downloads, und `install.ini` nennt `language\en` statt `language\de`.

| Schritt | Umgebung | Inhalt | Fälle | Minuten |
|---|---|---|---|---|
| K1 | Laptop | Server-Vorabprüfung; ihr Ergebnis bestimmt K4 | TP-00 | 5 |
| K2 | Laptop | Weg A bauen ([6.2](#62-weg-a-placeholder-build), alle vier Varianten) und Weg A+ (`-Variants EE/Regular -OutputDir out\aplus`), die Setups nach `C:\EE-Test\setups` kopieren | - | 10 |
| K3 | Laptop | die SHA-256-Dateien der vier Setups von Weg A prüfen | TP-30 (a) | 5 |
| K4 | Sandbox, Netz | EE-admin neu installieren (Deutsch, „Empfohlene Einstellungen“ mit EE und AoC, Telemetrie aus) und prüfen: TP-70 (a) Schritte 1 bis 5; derselbe Lauf belegt TP-10 (ist der Hauptserver laut K1 inzwischen gültig, vorher die `hosts`-Zeile aus TP-10 eintragen), TP-22 (a) (mit den empfohlenen Einstellungen sind beide Kompatibilitätsaufgaben gewählt; die Aufgabenseite entfällt), TP-40 (a) und TP-50 (a). Dann TP-40 (e) Teil a (schreibgeschützte `install.ini`), dann TP-73 (a) (die Reparatur nach dem Schaden ist zugleich die letzte Reparatur von TP-40 (e)). Dann NeoEE-admin: TP-70 (a), TP-40 (d), TP-50 (a); zum Schluss beide deinstallieren (TP-70 Schritt 7, TP-40 (d)) | TP-10, TP-22, TP-40, TP-50, TP-70, TP-73 | 43 |
| K5 | Sandbox, Netz | EE-user mit der „Virenscanner“-Schleife: TP-50 (b) ohne den stillen Lauf; dieselbe Installation belegt TP-70 (a) EE-user (der Hinweis zu fehlenden Dateien ist hier erwartet) und TP-22 (d) (Werte in HKCU); nach der Reparatur ohne Schleife TP-40 (b); deinstallieren (TP-70 Schritt 7) | TP-22, TP-40, TP-50, TP-70 | 21 |
| K6 | Sandbox, Netz | EE-portable: TP-70 (a), TP-40 (c), TP-50 (a); dann EE-admin still: TP-14 (a) | TP-14, TP-40, TP-50, TP-70 | 16 |
| K7 | Sandbox, ohne Netz (`EE-Test-offline.wsb`) | EE-admin per Doppelklick ohne `/LOG`: TP-11 (a) und zugleich TP-30 (b) (das Log aus `%TEMP%` als `C:\EE-Test\logs\TP-11a_EE-admin.log` sichern); dann TP-14 (b) still, hier als Reparatur über diese Installation (ohne Netz verhält sie sich wie eine Neuinstallation) | TP-11, TP-14, TP-30 | 13 |
| K8 | Sandbox, Netz | TP-61 (a) mit Installation, EE deinstallieren, (b) bis nach der Ordnerseite, (c) sichtbar und still; aufräumen | TP-61 | 23 |
| K9 | Sandbox, Netz | das offizielle EE-Setup 1.7.2 installieren (Englisch, `S-172-EE` wie in [Abschnitt 5](#5-testumgebungen-und-snapshots)), die Werte für TP-22 (e) notieren, dann das A+-Setup aus `out\aplus` als Update: TP-70 (b) EE-admin und TP-22 (e) | TP-22, TP-70 | 19 |
| K10 | Laptop, nur Weg B | TP-50 (d): EE-admin mit allen Komponenten, Dauer der Seite „Installierte Dateien werden geprüft“; auf derselben Installation den Spielstart von TP-70 (a) Schritt 6; deinstallieren. Ohne Daten: „nicht durchgeführt: keine Daten“ | TP-50, TP-70 | 15 |
| Summe | | | | 170 |

Ohne Daten der Maintainer entfällt K10; der Kurzdurchlauf dauert dann etwa 155 Minuten. Die Zeiten
sind Schätzungen aus den Schritten der Fälle (ein Lauf mit dem Assistenten etwa 5 Minuten, eine
Reparatur 4, ein Neustart der Sandbox 2, die Abfragen eines Falls 2 bis 3); die tatsächliche Dauer
gehört ins Protokoll (Bemerkung zu K1), damit der Plan nachgeschärft werden kann.
`ci/check_test_plan.py` prüft, dass die Spalte „Fälle“ genau die P1-Fälle nennt und die Summe
stimmt und höchstens 180 Minuten beträgt.

## 8. Testfälle

### Block 0: Vorabprüfung

#### TP-00: Server-Vorabprüfung

- **Status:** ausgearbeitet
- **Priorität:** P1
- **Bezug:** R16, ADR 0006 (Freigabekriterium: mindestens ein Dateiserver mit gültigem
  Zertifikat), ADR 0003; Forum §8 Nr. 15
- **Ziel:** Vor allen Download-Tests klären, ob der Hauptserver und der Spiegel über HTTPS mit
  gültigem Zertifikat antworten, damit ein Download-Fehler im Test nicht dem Setup angelastet
  wird.
- **Build-Art:** keine (kein Setup nötig)
- **Ausgangszustand:** Laptop mit Internetzugang, ohne Proxy, der TLS aufbricht (sonst prüft man
  den Proxy).
- **Snapshot:** `Laptop` (nichts wird verändert)
- **Varianten:** keine (gilt für alle; die Setups nutzen dieselben Server)
- **Schritte:**
  1. Windows PowerShell öffnen (nicht als Administrator nötig) und ausführen:

     ```powershell
     [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
     foreach ($server in 'https://files.empireearth.eu/localized/', 'https://storage.ee.zocker-160.de/localized/') {
       foreach ($url in $server, ($server + 'Game/de/EE/Data/data.ssa')) {
         try {
           $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30
           '{0}  HTTP {1}  Content-Length: {2}' -f $url, [int]$r.StatusCode, $r.Headers['Content-Length']
         } catch {
           if ($_.Exception.Response) { '{0}  HTTP {1} (Antwort mit gültigem TLS)' -f $url, [int]$_.Exception.Response.StatusCode }
           else { '{0}  FEHLER: {1}' -f $url, $_.Exception.Message }
         }
       }
     }
     ```

     Die erste Zeile schaltet TLS 1.2 für Windows PowerShell 5.1 ein (PowerShell 7 braucht sie
     nicht, sie schadet dort nicht). Die Ordner-URL ist dieselbe, die das Setup vor den Downloads
     prüft (`SelectOnlineFilesServer`); `Data/data.ssa` ist eine ungepinnte Datei, für die die
     Größe zählt.
  2. Alternative ohne PowerShell: `curl.exe -sSI https://files.empireearth.eu/localized/` und
     dasselbe für den Spiegel (Windows 10 ab 1803 hat `curl.exe`).
  3. Ausgabe und Datum ins Protokoll übernehmen.
- **Erwartetes Ergebnis:** Je Server gilt:
  - **gültig**: eine HTTP-Antwort ohne TLS-Fehler. Für den Ordner sind `200`, `403` oder `404`
    möglich (das Setup wertet jede HTTP-Antwort als erreichbar); für `data.ssa` `200` mit einer
    `Content-Length` größer als 0. Fehlt `Content-Length`, ist das ein Hinweis an die
    Serverbetreiber (das Setup kann die Größe ungepinnter Dateien dann nicht prüfen, ADR 0003),
    kein Testabbruch.
  - **ungültig**: `FEHLER` mit einer Zertifikats- oder TLS-Meldung (Windows PowerShell z. B.
    „Für den geschützten SSL/TLS-Kanal konnte keine Vertrauensstellung hergestellt werden“,
    PowerShell 7 „The SSL connection could not be established“), oder keine Verbindung (Name nicht
    auflösbar, Zeitüberschreitung).

  Bewertung:
  - **Beide gültig**: Alle Download-Fälle (TP-1x) sind uneingeschränkt testbar.
  - **Nur einer gültig**: Freigabekriterium erfüllt. Ist nur der Spiegel gültig, ist der Weg
    „Hauptserver ungültig, Spiegel übernimmt“ der Normalfall; die Fälle, die einen funktionierenden
    Hauptserver brauchen, werden als eingeschränkt protokolliert.
  - **Keiner gültig**: **Release-Blocker auf Serverseite** (ADR 0006), kein Fehler des Setups.
    Die Download-Tests sind nur eingeschränkt möglich: Prüfbar bleiben nur „beide Server
    scheitern“ (Hinweis `OnlineFilesUnreachable`, Installation mit den eigenen Dateien) und das
    Verhalten ohne Netz; erfolgreiche Downloads, Pins gegen echte Serverdateien und der Wechsel
    zum Spiegel nicht. Im Protokoll vermerken und die Maintainer informieren.

  Beobachtung aus der Analyseumgebung am 2026-10-02 (zum Vergleich, kein Ersatz für den Test):
  `files.empireearth.eu` lieferte das Standardzertifikat des Hosters
  (`CN=cluster131.hosting.ovh.net`), also **ungültig**; der Spiegel war von dort nicht erreichbar
  (Proxy-Fehler 502) und ist damit **unbekannt**.
- **Log-Hinweis:** kein Setup-Log. In den Download-Fällen (TP-1x) zeigt das Setup-Log die Ursache
  (`HTTP GET https://files.empireearth.eu/localized failed: <Ursache>`) und den Serverwechsel
  (`Main online files server unreachable or without a valid certificate (see the HTTP GET line above), downloading from the mirror first`,
  `downloads.iss`); was die Betreiber prüfen, steht in [SERVER-OPERATIONS.md](SERVER-OPERATIONS.md).

### Block 1: Downloads (S-WP3)

Diese Fälle prüfen, was ADR 0003 und ADR 0006 nur auf Windows zeigen können: die eingebauten
Downloads von Inno Setup statt IDP (eine Datei nach der anderen, erst der zuerst gewählte Server,
dann einmal der andere), den Stopp-Knopf, den Silent-Modus, Koreanisch und TLS 1.2 unter
Windows 7. Die Entscheidung nach jedem Versuch ist zusätzlich als Unit-Test abgedeckt
(`NextDownloadAction` in `ci/tests/unit_tests.iss`).

Gemeinsam für alle Fälle dieses Blocks:

- Vorher [TP-00](#tp-00-server-vorabprüfung) am selben Tag ausführen. Sein Ergebnis bestimmt, welche
  Fälle durchführbar sind (jeder Fall nennt es unter „Ausgangszustand“).
- Downloads gibt es nur mit einer anderen Spielsprache als Englisch und mit der Komponente
  „Lokalisierte Sprachausgabe und Kampagnen herunterladen“ (in den empfohlenen Einstellungen und
  in allen Installationsarten vorausgewählt). Wenn nicht anders gesagt: Spielsprache „Deutsch“.
- Die Download-Seite heißt „Lokalisierte Dateien werden heruntergeladen“; unter dem
  Fortschrittsbalken steht die URL der Datei, die gerade geladen wird, darunter der Knopf
  „Download abbrechen“.
- **Weg A:** Die Pins stammen aus Platzhaltern ([6.2](#62-weg-a-placeholder-build)). Jede gepinnte
  Datei (mindestens `Language.dll`) passt deshalb nicht zum Server, wird auf beiden Servern
  verworfen und im Hinweis als „nicht die Version, die dieses Setup kennt … verworfen“ gemeldet.
  Das ist bei Weg A in jedem Fall dieses Blocks erwartet und genau der Inhalt von
  [TP-16](#tp-16-manipulierter-download-wird-verworfen).
- Langsame Leitung für die Stopp-Fälle: Damit man den Knopf rechtzeitig trifft, in der VM die
  Bandbreite begrenzen (VirtualBox: *Netzwerk › Bandbreitengruppe*, etwa 1 MBit/s; Hyper-V:
  *Netzwerkkarte › Bandbreitenverwaltung*) und die Komponente „Intro-Videos installieren“ wählen
  (nur in der benutzerdefinierten Installation; das lokalisierte Video ist die größte Datei).
- Log-Zeilen des Download-Teils (`downloads.iss`), die die Fälle zitieren:
  `Downloading <n> online files, one at a time`; je Versuch
  `Downloading temporary file from <URL>: <Ziel>` (Inno Setup) und danach
  `Online file downloaded, SHA-256 pinned: <URL>`,
  `Online file downloaded, TLS-verified, size checked: <URL>`,
  `Online file downloaded, TLS-verified, accepted without size check (the server sent no Content-Length): <URL>`,
  `Online file download failed from <URL>: <Ursache>` oder
  `Online file rejected, SHA-256 mismatch: <URL> (got <SHA-256>)`; der Wechsel
  `Online file: trying the other server, <URL>`; bei `ssInstall` je Datei
  `Online file verified, SHA-256 pinned: …`, `Online file accepted, TLS-verified, not pinned: …`
  oder `Online file not downloaded: …` und am Ende
  `<k> of <n> selected online files are missing, the setup installs its own files instead:` mit der
  Liste (bzw. `All <n> online files accepted`).

#### TP-10: Hauptserver ungültig, Download vom Spiegel

- **Status:** ausgearbeitet
- **Priorität:** P1 (EE-admin; NeoEE-admin mit Weg B: P2)
- **Bezug:** ADR 0003, ADR 0006, R16; Forum §8 Nr. 15 („nur mit Spiegel erreichbar“), Forum
  §8 Nr. 12 des Problemabgleichs (t=5741, t=3763: kaputte Downloads)
- **Ziel:** Mit ungültigem Zertifikat des Hauptservers lädt das Setup die lokalisierten Dateien
  vom Spiegel und nennt die Ursache im Log; ein ungültiges Zertifikat wird nie akzeptiert.
- **Build-Art:** A oder B (B zeigt den Normalfall ohne verworfene Dateien)
- **Ausgangszustand:** TP-00: Spiegel gültig. Ist der Hauptserver noch ungültig (Stand
  2026-10-02), ist das der Fall selbst. Ist er inzwischen gültig, wird der Fehler nachgestellt:
  in der VM als Administrator die Adresse des Spiegels ermitteln (`nslookup storage.ee.zocker-160.de`)
  und in `C:\Windows\System32\drivers\etc\hosts` die Zeile `<diese IPv4-Adresse> files.empireearth.eu`
  eintragen, dann `ipconfig /flushdns`. `curl.exe -sSI https://files.empireearth.eu/localized/`
  muss jetzt mit einem Zertifikatsfehler scheitern.
- **Snapshot:** `S-Basis` (die Zeile in `hosts` verschwindet mit dem Zurücksetzen)
- **Varianten:** EE-admin; NeoEE-admin bei Weg B (lädt die NeoEE-Fassungen aus `Mods/NeoEE/`).
  Die anderen Varianten nutzen denselben Code.
- **Schritte:**
  1. Setup mit `/LOG="C:\EE-Test\logs\TP-10_EE-admin.log"` starten (bei Weg A zusätzlich
     `/MERGETASKS="!dxwebsetup"`), Spielsprache Deutsch, empfohlene Einstellungen mit „Empire
     Earth und Die Kunst der Eroberungen“, Telemetrie aus.
  2. Auf „Bereit zur Installation“ „Installieren“ klicken; die Download-Seite beobachten (die URLs
     müssen mit `https://storage.ee.zocker-160.de/` beginnen) und die Installation fertigstellen.
  3. `certutil -hashfile "C:\Program Files (x86)\Empire Earth\Empire Earth\Data\data.ssa" SHA256`
     ausführen und mit der Zeile `Online file accepted, TLS-verified, not pinned: Game/de/EE/Data/data.ssa (SHA-256 …)`
     im Log vergleichen.
  4. Bei nachgestelltem Fehler die Zeile in `hosts` wieder entfernen (oder den Snapshot
     zurücksetzen).
- **Erwartetes Ergebnis:** Keine Fehlermeldung und kein Hinweis `OnlineFilesUnreachable`. Weg B:
  kein Hinweis `DownloadIncomplete` (sofern der Spiegel vollständig ist); Weg A: der Hinweis listet
  nur die gepinnten Dateien als verworfen. Die SHA-256 aus Schritt 3 gleicht der im Log. Keine
  Anfrage an den Hauptserver lädt eine Datei.
- **Log-Hinweis:** `HTTP GET https://files.empireearth.eu/localized failed: <Ursache>` (ein
  Zertifikatsfehler, z. B. „Die Zertifizierungsstelle ist ungültig oder falsch“ oder „Der
  Zertifikatsname ist ungültig oder stimmt nicht überein“), danach
  `Main online files server unreachable or without a valid certificate (see the HTTP GET line above), downloading from the mirror first`
  und `Downloading temporary file from https://storage.ee.zocker-160.de/localized/…`. Scheitert
  eine Datei am Spiegel, folgt `Online file: trying the other server, https://files.empireearth.eu/…`
  und `Online file download failed from https://files.empireearth.eu/…: <Zertifikatsfehler>`. Steht
  bei einer ungepinnten Datei `accepted without size check`, sendet der Spiegel kein
  `Content-Length`: ins Protokoll und an die Serverbetreiber (SERVER-OPERATIONS.md, Abschnitt 2).

#### TP-11: Keiner der Server erreichbar

- **Status:** ausgearbeitet
- **Priorität:** P1 (Teil a mit EE-admin; Teil b und EE-user: P2)
- **Bezug:** ADR 0006 (Hinweis `OnlineFilesUnreachable`); Forum §8 Nr. 15 („ohne Internet“)
- **Ziel:** Ohne Netz bzw. ohne gültigen Server installiert das Setup seine eigenen Dateien und
  erklärt das verständlich: Server nicht erreichbar oder ohne gültiges Zertifikat, ein Problem der
  Server, später erneut ausführen.
- **Build-Art:** A oder B
- **Ausgangszustand:** beliebiges Ergebnis von TP-00. (a) Netzwerk aus: in der VM die
  Netzwerkkarte trennen. (b) Netz an, aber beide Dateiserver ohne gültiges Zertifikat: in
  `C:\Windows\System32\drivers\etc\hosts` beide Namen auf einen fremden HTTPS-Server umleiten,
  dessen Zertifikat nicht zu ihnen passt, z. B. `www.gog.com` (Adresse mit `nslookup www.gog.com`):
  `<diese IPv4-Adresse> files.empireearth.eu` und `<diese IPv4-Adresse> storage.ee.zocker-160.de`,
  dann `ipconfig /flushdns`. Nicht die Adresse von `empireearth.eu` nehmen: Deren
  Wildcard-Zertifikat gilt auch für `files.empireearth.eu`.
- **Snapshot:** `S-Basis`
- **Varianten:** EE-admin (a und b), EE-user (a)
- **Schritte:**
  1. Ausgangszustand (a) herstellen, Setup mit `/LOG="C:\EE-Test\logs\TP-11a_EE-admin.log"`
     starten, Spielsprache Deutsch, empfohlene Einstellungen, installieren.
  2. Den Hinweis nach „Installieren“ lesen und mit OK bestätigen, die Installation fertigstellen.
  3. Snapshot zurücksetzen, Ausgangszustand (b) herstellen, Schritte 1 und 2 mit `TP-11b` im
     Log-Namen wiederholen.
- **Erwartetes Ergebnis:** Nach „Installieren“ erscheint genau ein Hinweis (kein Fehler):
  „Die Server der lokalisierten Dateien waren nicht erreichbar oder haben kein gültiges
  Sicherheitszertifikat vorgelegt (ein Problem der Server, nicht Ihres Computers). Das Spiel wird
  mit den Dateien installiert, die dieses Setup enthält, daher bleiben einige Inhalte (zum Beispiel
  Stimmen und Kampagnen) möglicherweise englisch. Um die lokalisierten Dateien hinzuzufügen,
  führen Sie dieses Setup später erneut aus.“ Die Download-Seite erscheint nicht, die Installation
  läuft zu Ende, `Language.dll` und die Lobby-Dateien sind die des Setups (deutsch), Stimmen und
  Kampagnen englisch.
- **Log-Hinweis:** zwei Zeilen `HTTP GET https://…/localized failed: <Ursache>` (a: Name nicht
  auflösbar bzw. keine Verbindung; b: Zertifikatsfehler), danach
  `Unable to reach the online files server! The setup will only use local files...`; keine Zeile
  `Downloading temporary file`.

#### TP-12: Stopp beim zuerst verwendeten Server

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** ADR 0003 (Stopp-Knopf beendet alle Anfragen, nie der Spiegel), Review „Stopp vs
  Mirror“; Unit-Test `NextDownloadAction stop at the main server`
- **Ziel:** Ein Stopp während des Downloads vom zuerst verwendeten Server beendet alle Downloads:
  keine Anfrage an den anderen Server, keine weitere Datei; die Installation läuft mit den
  eigenen Dateien weiter und meldet die übersprungenen Dateien.
- **Build-Art:** A oder B
- **Ausgangszustand:** TP-00: mindestens ein Server gültig. Bandbreite begrenzt (siehe oben).
- **Snapshot:** `S-Basis`
- **Varianten:** EE-admin
- **Schritte:**
  1. Setup mit `/LOG="C:\EE-Test\logs\TP-12_EE-admin.log"` starten, Spielsprache Deutsch,
     benutzerdefinierte Installation mit „Intro-Videos installieren“, Telemetrie aus.
  2. „Installieren“ klicken. Sobald die Download-Seite eine URL mit `Data/data.ssa` oder
     `Data/Movies/Empire Earth.bik` zeigt, „Download abbrechen“ klicken und die Frage „Sind Sie
     sicher, dass Sie den Download abbrechen wollen?“ mit „Ja“ beantworten.
  3. Den Hinweis lesen, bestätigen, die Installation fertigstellen.
- **Erwartetes Ergebnis:** Die Download-Seite schließt sich sofort, ohne weitere Datei zu laden;
  die Installation läuft weiter. Der Hinweis „Einige lokalisierte Dateien konnten nicht aus dem
  Download installiert werden: …“ listet die abgebrochene und alle folgenden Dateien mit
  „(Download abgebrochen, nicht heruntergeladen)“; vorher fertig geladene Dateien fehlen in der
  Liste (bei Weg A stehen die gepinnten als verworfen darin). Kein Fehler.
- **Log-Hinweis:** `Online file download stopped by the user: <URL>` und direkt danach
  `Online files: downloads stopped by the user, no further request (neither the other server nor the remaining files)`,
  dann je restlicher Datei `Online file skipped, downloads stopped by the user: <Pfad>`. **Nach**
  der Stopp-Zeile gibt es keine Zeile `Downloading temporary file from` und keine Zeile
  `Online file: trying the other server` mehr.

#### TP-13: Stopp beim zweiten Server

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** ADR 0003 (Stopp-Knopf), Review „Stopp vs Mirror“; Unit-Test
  `NextDownloadAction stop at the mirror`
- **Ziel:** Ein Stopp während des Versuchs am zweiten Server (nach einem Fehlschlag am ersten)
  beendet ebenfalls alle Downloads.
- **Build-Art:** A (mit dem Video-Pin aus Schritt 1)
- **Ausgangszustand:** TP-00: **beide** Server gültig (sonst scheitert der zweite Versuch sofort
  und der Fall ist nicht durchführbar: im Protokoll „nicht durchgeführt: nur ein gültiger Server“).
  Bandbreite begrenzt.
- **Snapshot:** `S-Basis`
- **Varianten:** EE-admin
- **Schritte:**
  1. Vor dem Bauen eine beliebige kleine Datei als
     `data\localized-text\Game\de\EE\Data\Movies\Empire Earth.bik` anlegen (z. B. eine Textdatei
     mit dem Inhalt `x`), dann wie in [6.2](#62-weg-a-placeholder-build) bauen. Die Hashliste pinnt
     das Video damit auf einen falschen Wert: Das echte Video wird am ersten Server verworfen, und
     das Setup lädt es noch einmal vom zweiten. Die Datei nach dem Test wieder löschen.
  2. Setup mit `/LOG="C:\EE-Test\logs\TP-13_EE-admin.log"` starten, Spielsprache Deutsch,
     benutzerdefinierte Installation mit „Intro-Videos installieren“.
  3. Warten, bis die Download-Seite das Video vom **zweiten** Server zeigt (die URL wechselt von
     `files.empireearth.eu` zu `storage.ee.zocker-160.de` oder umgekehrt), dann „Download
     abbrechen“ und „Ja“.
  4. Hinweis bestätigen, Installation fertigstellen.
- **Erwartetes Ergebnis:** wie [TP-12](#tp-12-stopp-beim-zuerst-verwendeten-server): Die Seite
  schließt sich, die Installation läuft weiter, das Video und alle folgenden Dateien stehen mit
  „(Download abgebrochen, nicht heruntergeladen)“ im Hinweis.
- **Log-Hinweis:** `Online file rejected, SHA-256 mismatch: <URL des ersten Servers>/…/Empire Earth.bik (got …)`,
  `Online file: trying the other server, <URL des zweiten Servers>`,
  `Online file download stopped by the user: <URL des zweiten Servers>`, dann die Stopp-Zeile wie
  in TP-12 und danach keine Zeile `Downloading temporary file from` mehr.

#### TP-14: Silent-Installation ohne Dialog

- **Status:** ausgearbeitet
- **Priorität:** P1 (Teile a und b; c, d und EE-portable: P2)
- **Bezug:** ADR 0003; ARCHITECTURE Abschnitt 5 (Hinweise nicht im Silent-Modus und nicht mit
  `/SUPPRESSMSGBOXES`); Forum §8 Nr. 15
- **Ziel:** Mit `/SILENT`, `/VERYSILENT` oder `/SUPPRESSMSGBOXES` erscheint wegen der Downloads
  kein Dialog; alles, was sonst ein Hinweis wäre, steht im Log.
- **Build-Art:** A oder B
- **Ausgangszustand:** TP-00: mindestens ein Server gültig (für a und c). Für b und d Netzwerk
  aus.
- **Snapshot:** `S-Basis` (vor jedem Lauf)
- **Varianten:** EE-admin, EE-portable (nur a)
- **Schritte:**
  1. (a) `EE_Setup_v1.7.2.exe /VERYSILENT /SUPPRESSMSGBOXES /ALLUSERS /LANG=de /LOG="C:\EE-Test\logs\TP-14a_EE-admin.log"`
     (Weg A zusätzlich `/MERGETASKS="!dxwebsetup"`) in einer Eingabeaufforderung als
     Administrator starten und warten, bis der Prozess endet (Task-Manager).
  2. (b) wie (a) mit getrenntem Netzwerk, Log `TP-14b_…`.
  3. (c) wie (a) mit `/SILENT` statt `/VERYSILENT`, Log `TP-14c_…`.
  4. (d) interaktiv nur mit `/SUPPRESSMSGBOXES /LOG="C:\EE-Test\logs\TP-14d_EE-admin.log"` und
     getrenntem Netzwerk durch den Assistenten klicken (Spielsprache Deutsch).
  5. (a) für EE-portable mit `EE_Portable_Setup_v1.7.2.exe` wiederholen.
- **Erwartetes Ergebnis:** In keinem Lauf erscheint ein Hinweis oder eine Frage (weder
  `OnlineFilesUnreachable` noch `DownloadIncomplete` noch die Testwarnung). (a) und (c) zeigen
  höchstens das Fortschrittsfenster (c) bzw. gar nichts (a), die Installation endet von selbst mit
  den heruntergeladenen deutschen Dateien. (b) und (d) installieren mit den eigenen Dateien.
- **Log-Hinweis:** (a), (c): die Download-Zeilen wie in TP-10 und `All <n> online files accepted`
  bzw. bei Weg A die Liste `… selected online files are missing …`; (b), (d):
  `Unable to reach the online files server! The setup will only use local files...`. In allen
  Läufen `Installation process succeeded.`

#### TP-15: Koreanisch

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** ADR 0003 (Texte der Download-Seite), TRANSLATING.md („Korean (ko): texts of the
  download page“), R17
- **Ziel:** Mit Koreanisch als Setup- und Spielsprache funktionieren die Downloads; die Texte der
  Download-Seite und die Hinweise dazu erscheinen englisch, weil die inoffizielle koreanische
  Sprachdatei sie nicht hat (bekannte Lücke, kein Fehler).
- **Build-Art:** A oder B
- **Ausgangszustand:** TP-00: mindestens ein Server gültig.
- **Snapshot:** `S-Basis`
- **Varianten:** EE-admin
- **Schritte:**
  1. Setup mit `/LANG=ko /LOG="C:\EE-Test\logs\TP-15_EE-admin.log"` starten (Setup-Sprache
     Koreanisch; die Spielsprache folgt ihr), empfohlene Einstellungen, Telemetrie aus.
  2. Auf der Download-Seite die Texte notieren (ein Bildschirmfoto genügt), während des Downloads
     „Stop download“ klicken und mit „Yes“ bestätigen.
  3. Den Hinweis lesen, Installation fertigstellen.
- **Erwartetes Ergebnis:** Der Assistent ist koreanisch; die Download-Seite zeigt englisch
  „Downloading localized files“, „Downloading additional files...“ und den Knopf „Stop download“,
  die Frage „Are you sure you want to stop the download?“, danach den englischen Hinweis „Some
  localized files could not be installed from the download: …“ mit „(download stopped, not
  downloaded)“. Keine Fehlermeldung, keine leeren Texte.
- **Log-Hinweis:** `Downloading temporary file from https://…/localized/Game/ko/EE/…` (bzw.
  `Lobby/ko/…`), die Stopp-Zeile wie in TP-12; keine Zeile mit `Exception`.

#### TP-16: Manipulierter Download wird verworfen

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** ADR 0003 (Pin direkt nach dem Download, `DownloadFileRejected`); Forum §8 Nr. 15
  („manipulierter Download“), Forum §8 Nr. 12 des Problemabgleichs (t=5741, t=3763)
- **Ziel:** Eine heruntergeladene Datei, die nicht zu ihrem Pin passt, wird verworfen, auf dem
  anderen Server noch einmal versucht, gemeldet und durch die eigene Version ersetzt; sie wird nie
  installiert.
- **Build-Art:** A (die Platzhalter-Pins passen nie zu den Serverdateien). Mit Weg B nur, wenn
  vor `ci\build.ps1 -DownloadHashesOnly` eine Datei in `data\localized-text` verändert wird (z. B.
  ein Zeichen in `Lobby\de\EE\WONLobby.cfg`); danach die Originaldatei zurücklegen und neu bauen.
- **Ausgangszustand:** TP-00: mindestens ein Server gültig (mit beiden gültigen wird zusätzlich der
  zweite Versuch geprüft).
- **Snapshot:** `S-Basis`
- **Varianten:** EE-admin, NeoEE-admin (NeoEE pinnt die NeoEE-Fassungen aus `Mods\NeoEE`)
- **Schritte:**
  1. Setup mit `/LOG="C:\EE-Test\logs\TP-16_EE-admin.log"` starten, Spielsprache Deutsch,
     empfohlene Einstellungen, installieren.
  2. Den Hinweis lesen und bestätigen, Installation fertigstellen.
  3. `certutil -hashfile "C:\Program Files (x86)\Empire Earth\Empire Earth\Language.dll" SHA256`
     ausführen und mit `certutil -hashfile data\localized-text\Game\de\EE\Language.dll SHA256` in
     der Arbeitskopie vergleichen (NeoEE: `data\localized-text\Mods\NeoEE\Game\de\EE\Language.dll`).
- **Erwartetes Ergebnis:** Der Hinweis „Einige lokalisierte Dateien konnten nicht aus dem
  Download installiert werden: …“ nennt `Empire Earth\Language.dll` (und die anderen gepinnten
  Dateien) mit „(nicht die Version, die dieses Setup kennt: inzwischen auf dem Server
  aktualisiert oder beschädigt, verworfen)“. Die installierte `Language.dll` hat die SHA-256 der
  Datei des Setups (Schritt 3), nicht die der Serverdatei aus dem Log. Ungepinnte Dateien
  (`data.ssa`, Kampagnen) sind installiert.
- **Log-Hinweis:** je gepinnter Datei `Online file rejected, SHA-256 mismatch: <URL> (got <SHA-256>)`,
  `Online file: trying the other server, <URL>`, ein zweites `rejected` (oder
  `download failed` bei ungültigem zweiten Server) und
  `Online file not downloaded, it failed on both servers: <Pfad>`; bei `ssInstall`
  `Online file not downloaded: <Pfad>` und die Liste nach
  `… selected online files are missing, the setup installs its own files instead:`.

#### TP-17: TLS 1.2 unter Windows 7 SP1 ohne und mit KB3140245 (nur VM)

- **Status:** ausgearbeitet
- **Priorität:** P3
- **Bezug:** R16, ADR 0006 (Hypothese: explizit angeforderte Protokolle genügen ohne KB3140245);
  README „Support“; SERVER-OPERATIONS.md Abschnitt 3.3
- **Ziel:** Zeigen, ob Updateprüfung, Erreichbarkeitsprüfung und Downloads unter Windows 7 SP1
  ohne KB3140245 und ohne SChannel-Änderungen TLS 1.2 schaffen, und dass das Setup selbst nie
  SChannel- oder WinHTTP-Werte schreibt.
- **Build-Art:** A oder B
- **Ausgangszustand:** TP-00: mindestens ein Dateiserver gültig, und die SSL-Labs-Simulation
  „IE 11 / Win 7“ (SERVER-OPERATIONS.md 3.3) für `api.empireearth.eu` und diesen Server notiert
  (scheitert sie dort, scheitert auch dieser Fall; das ist dann ein Serverbefund).
  (a) `S-Win7` ohne KB3140245 und ohne SChannel-Werte; (b) dieselbe VM mit KB3140245 und den
  Registry-Werten aus Microsofts Artikel (Schritt 4).
- **Snapshot:** `S-Win7` (nur VM, nie auf dem Laptop)
- **Varianten:** EE-admin
- **Schritte:**
  1. Zustand festhalten (Eingabeaufforderung als Administrator), Ausgaben ins Protokoll:
     `wmic qfe get HotFixID | find "3140245"` (keine Ausgabe erwartet),
     `reg query "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols" /s`,
     `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols`,
     `reg query "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DefaultSecureProtocols`.
  2. (a) Setup **nicht** silent mit `/LOG="C:\EE-Test\logs\TP-17a_EE-admin.log"` starten (die
     Updateprüfung läuft nur interaktiv), Spielsprache Deutsch, empfohlene Einstellungen,
     installieren, fertigstellen.
  3. Die `reg query`-Befehle aus Schritt 1 wiederholen: Die Ausgaben müssen gleich sein.
  4. (b) KB3140245 aus dem Microsoft Update Catalog installieren und die Werte aus Microsofts
     Artikel setzen: `DefaultSecureProtocols` = `0xA00` (DWORD) in beiden `WinHttp`-Schlüsseln aus
     Schritt 1, `DisabledByDefault` = `0` (DWORD) unter `…\SCHANNEL\Protocols\TLS 1.1\Client` und
     `…\TLS 1.2\Client`; neu starten. Das Setup deinstallieren und Schritt 2 mit `TP-17b` im
     Log-Namen wiederholen.
- **Erwartetes Ergebnis:** Das Setup läuft in (a) und (b) ohne Fehlermeldung zu Ende; Schritt 3
  zeigt keine Änderung durch das Setup. Bestanden ist der Fall, wenn das gilt; das Ergebnis der
  Hypothese steht zusätzlich in der Bemerkung des Protokolls:
  - **Hypothese bestätigt**, wenn in (a) die Updateprüfung `status 200` meldet und die Dateien
    heruntergeladen werden.
  - **Hypothese widerlegt**, wenn (a) mit TLS- oder Verbindungsfehlern scheitert (dann erscheint
    `OnlineFilesUnreachable` und das Spiel wird mit den eigenen Dateien installiert) und (b)
    funktioniert. Dann gilt für Windows 7 der Weg aus der README („Support“: KB3140245), und
    ADR 0006 wird angepasst.
  - Scheitern (a) und (b) mit einem Zertifikatsfehler, fehlen der VM vermutlich aktuelle
    Stammzertifikate (in `certmgr.msc` unter „Vertrauenswürdige Stammzertifizierungsstellen“
    nachsehen); das ist kein Befund zum Setup.
- **Log-Hinweis:** `HTTP GET https://api.empireearth.eu/setup/?product=…: TLS 1.0, 1.1 and 1.2 requested explicitly (Windows 6.1)`
  (bzw. `unable to request TLS 1.0, 1.1 and 1.2 explicitly (Windows 6.1), …: <Ursache>`), danach
  `HTTP GET …: status 200, …` oder `HTTP GET … failed: <Ursache>`; dasselbe für
  `https://files.empireearth.eu/localized` bzw. den Spiegel; bei den Downloads
  `Online file downloaded, …` oder `Online file download failed from <URL>: <Ursache>`. Die
  Ursachen wörtlich ins Protokoll übernehmen.

### Block 2: Kompatibilität und Grafik (S-WP4, S-WP10)

Diese Fälle prüfen, was ADR 0005, ADR 0010 und Vertrag 3.7 nur auf Windows zeigen können: Unter
Windows 7 schreibt das Setup standardmäßig keine Kompatibilitätswerte mehr (nur mit den freiwilligen
Aufgaben `everyoneadminstart` und `compatibility_legacy`) und entfernt bei einem Update nur die
Werte früherer Setups, nicht den Wert, den derselbe Lauf mit `compatibility_legacy` schreibt
(TP-20, TP-21); unter Windows 10/11 bleibt alles wie bisher, Windows 8.1 bekommt dieselben Werte
(TP-22, die Windows-8.1-Variante optional). Dazu kommen die Grafikmatrix mit und ohne
DirectX-Wrapper und die vorab festgelegte Regel, was aus ihr folgt (TP-23), und der Fall 150 % Anzeigeskalierung mit und ohne Aufgabe
`compatibility` bzw. `compatibility_legacy` (TP-24, Vertrag O4). Welche Werte als „Werte früherer
Setups“ gelten, entscheidet `IsLegacyVistaCompatValue`, ob der Wert dieses Laufs bleibt,
`ShouldRemoveLegacyVistaCompatValue`; die Unit-Tests in `ci/tests/unit_tests.iss` decken alle
Kombinationen ab. Die Varianten mit `compatibility_legacy` (S-WP10) laufen wie alle
Windows-7-Fälle nur in einer VM und haben die Priorität P3.

Gemeinsam für alle Fälle dieses Blocks:

- Die Kompatibilitätswerte stehen unter `Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`,
  Wertname ist der volle Pfad der EXE (`…\Empire Earth\Empire Earth.exe`,
  `…\Empire Earth - The Art of Conquest\EE-AOC.exe`). Im Modus „admin“ schreibt das Setup nach HKLM
  (auf 64-Bit-Windows in die 64-Bit-Ansicht), in „user“ und „portable“ nach HKCU. Abfrage in der
  Eingabeaufforderung (auf 32-Bit-Windows ohne `/reg:64`):

  ```bat
  reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /reg:64
  reg query "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
  ```

  Es zählen nur die Zeilen mit `Empire Earth.exe` und `EE-AOC.exe`; „Der angegebene
  Registrierungsschlüssel bzw. Wert wurde nicht gefunden“ heißt: kein Wert. Die Ausgaben ins
  Protokoll übernehmen.
- Die Aufgaben „Kompatibilitätseinstellungen aktivieren“ (`compatibility`) und
  „Kompatibilitätsmodus für ältere Windows-Versionen aktivieren“ (`compatibility_windows`) gibt es
  nur ab Windows 8; dort sind sie vorausgewählt. „Kompatibilitätseinstellungen aktivieren
  (optional unter Windows 7: kann helfen, wenn das Spiel bei vergrößerter Anzeige unscharf aussieht
  oder nicht auf den Bildschirm passt)“ (`compatibility_legacy`) gibt es nur unter Windows 7, nie
  vorausgewählt; sie schreibt `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation` (mit
  `everyoneadminstart` `~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`), nie
  `WINXPSP3`. Die Seite „Zusätzliche Aufgaben auswählen“ erscheint nur mit „Benutzerdefinierte
  Installationseinstellungen“. „Spiel immer als Administrator ausführen, für alle Benutzer …“
  (`everyoneadminstart`) gibt es nur im Modus „admin“, sie ist nie vorausgewählt.
- Log-Zeilen der Bereinigung (`setup_is6.iss`, `RemoveLegacyVistaCompatValues`), nur unter
  Windows Vista/7:
  `Windows 6.1: this setup writes no compatibility values on Windows Vista/7 by default, checking HKLM for values of earlier setups`
  (bzw. `HKCU`; mit `compatibility_legacy` folgt am Ende ` (opt-in task compatibility_legacy selected)`),
  danach je Spielprogramm eine der Zeilen `No compatibility value of <Pfad> (HKLM)`,
  `Removed the old Windows Vista/7 compatibility value "<Wert>" of <Pfad> (HKLM)`,
  `Kept the compatibility value "<Wert>" of <Pfad> (HKLM): not a value of an earlier setup`,
  `Kept the compatibility value "<Wert>" of <Pfad> (HKLM): written by this run (task compatibility_legacy)` oder
  `Unable to remove the old Windows Vista/7 compatibility value "<Wert>" of <Pfad> (HKLM)`. Den
  alten Wert `~ RUNASADMIN` in HKCU (Modus „admin“, Setups bis 1.7.2) entfernt das Setup auf jeder
  Windows-Version: `Removed the old per-user RUNASADMIN flag of <Pfad>`.
- Spiel starten heißt in diesem Block: bis ins Hauptmenü, dann eine Zufallskarte gegen einen
  Computergegner etwa zwei Minuten spielen und beenden. Abstürze, Runtime-Fehler und schwarze
  Bildschirme mit Variante ins Protokoll (Forum t=4280 p=30477: „a long black screen and a runtime
  error“ im Kompatibilitätsmodus).

#### TP-20: Windows 7: Neuinstallation ohne Kompatibilitätswerte und mit compatibility_legacy (nur VM)

- **Status:** ausgearbeitet
- **Priorität:** P3 (nur VM; auch die Varianten (d) bis (f) mit `compatibility_legacy`)
- **Bezug:** R15, ADR 0005, ADR 0010 (freiwillige Aufgabe `compatibility_legacy`), Vertrag 3.7;
  Forum §8 Nr. 5 (t=4280 p=30477 und p=30479, t=1827 p=12147, t=5814)
- **Ziel:** Unter Windows 7 bietet das Setup die beiden vorausgewählten Kompatibilitätsaufgaben
  nicht an und schreibt standardmäßig keinen Kompatibilitätswert; mit den freiwilligen Aufgaben
  schreibt es genau `~ RUNASADMIN` bzw. die Flags ohne `WINXPSP3`, behält sie bei der Bereinigung
  und entfernt sie bei der Deinstallation; das Spiel startet mit und ohne Werte.
- **Build-Art:** A oder B (Schritt 5 und der Spielstart in Schritt 7 nur B)
- **Ausgangszustand:** Windows 7 SP1, kein Empire Earth, keine Werte für `Empire Earth.exe` und
  `EE-AOC.exe` (Schritt 1), Anzeigeskalierung 100 % (150 % prüft TP-24).
- **Snapshot:** `S-Win7` (nur VM, nie auf dem Laptop)
- **Varianten:** (a) EE-admin mit den angebotenen Aufgaben, (b) EE-admin mit `everyoneadminstart`,
  (c) EE-user; mit `compatibility_legacy` (S-WP10): (d) EE-admin mit Empire Earth und AoC, (e)
  EE-admin mit `compatibility_legacy` und `everyoneadminstart`, (f) EE-user nur mit Empire Earth
  (ohne AoC). NeoEE und portable nutzen dieselben Einträge (portable wie user in HKCU) und werden
  ausgelassen.
- **Schritte:**
  1. Die beiden `reg query`-Befehle (siehe oben) ausführen und die Ausgaben notieren.
  2. (a) Setup mit `/LOG="C:\EE-Test\logs\TP-20a_EE-admin.log"` starten, „Für alle Benutzer
     installieren“, Spielsprache Deutsch, „Benutzerdefinierte Installationseinstellungen“ mit
     Empire Earth und AoC, Telemetrie aus. Auf der Seite „Zusätzliche Aufgaben auswählen“ die
     angezeigten Aufgaben notieren und sie unverändert lassen (bei Weg A nur „DirectX-Endbenutzer-Runtime
     installieren“ abwählen); installieren, fertigstellen.
  3. Die `reg query`-Befehle wiederholen.
  4. (b) Snapshot zurücksetzen, Schritt 2 mit `TP-20b` im Log-Namen, dazu „Spiel immer als
     Administrator ausführen, für alle Benutzer …“ anhaken; dann Schritt 3.
  5. Nur Weg B, nach (a): Empire Earth und AoC je starten (siehe oben).
  6. (c) Snapshot zurücksetzen, Setup mit `/CURRENTUSER /LOG="C:\EE-Test\logs\TP-20c_EE-user.log"`
     starten, sonst wie Schritt 2; dann Schritt 3.
  7. (d) Snapshot zurücksetzen, Schritt 2 mit `TP-20d` im Log-Namen, dazu
     „Kompatibilitätseinstellungen aktivieren (optional unter Windows 7: …)“ anhaken; dann
     Schritt 3. Nur Weg B: Empire Earth und AoC je starten (siehe oben). Danach über
     *Systemsteuerung › Programme und Funktionen* deinstallieren und Schritt 3 wiederholen.
  8. (e) Snapshot zurücksetzen, Schritt 2 mit `TP-20e`, dazu „Kompatibilitätseinstellungen
     aktivieren (optional unter Windows 7: …)“ und „Spiel immer als Administrator ausführen, für
     alle Benutzer …“ anhaken; dann Schritt 3.
  9. (f) Snapshot zurücksetzen, Setup mit `/CURRENTUSER /LOG="C:\EE-Test\logs\TP-20f_EE-user.log"`,
     „Benutzerdefinierte Installationseinstellungen“ nur mit Empire Earth (AoC abgewählt), dazu
     „Kompatibilitätseinstellungen aktivieren (optional unter Windows 7: …)“ anhaken; dann Schritt 3.
- **Erwartetes Ergebnis:**
  - Die Aufgabenseite zeigt weder die vorausgewählte Aufgabe „Kompatibilitätseinstellungen
    aktivieren“ (ohne Zusatz) noch „Kompatibilitätsmodus für ältere Windows-Versionen aktivieren“,
    aber „Kompatibilitätseinstellungen aktivieren (optional unter Windows 7: …)“, nicht angehakt.
    „Spiel immer als Administrator ausführen …“ steht in den admin-Varianten da und ist nicht
    vorausgewählt, in (c) und (f) fehlt es.
  - (a) und (c): Schritt 3 zeigt weder in HKLM noch in HKCU eine Zeile mit `Empire Earth.exe` oder
    `EE-AOC.exe`.
  - (b): In HKLM steht für beide Programme genau `~ RUNASADMIN`, z. B.
    `C:\Program Files (x86)\Empire Earth\Empire Earth\Empire Earth.exe    REG_SZ    ~ RUNASADMIN`;
    in HKCU nichts.
  - (d): In HKLM für beide Programme genau `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`
    (kein `WINXPSP3`), in HKCU nichts; nach der Deinstallation keine der beiden Zeilen mehr.
  - (e): In HKLM für beide genau `~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`,
    in HKCU nichts.
  - (f): In HKCU nur für `Empire Earth.exe` `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`,
    für `EE-AOC.exe` nichts; in HKLM nichts.
  - Schritt 5 und der Spielstart in Schritt 7: Beide Spiele starten ohne Fehlermeldung,
    Runtime-Fehler oder schwarzen Bildschirm.
- **Log-Hinweis:** (a) `Windows 6.1: this setup writes no compatibility values on Windows Vista/7 by default, checking HKLM for values of earlier setups`,
  dann zweimal `No compatibility value of … (HKLM)`; (b) zweimal
  `Kept the compatibility value "~ RUNASADMIN" of … (HKLM): not a value of an earlier setup` (der
  Wert dieses Laufs bleibt); (c) wie (a) mit `HKCU`; (d) die Kopfzeile endet mit
  ` (opt-in task compatibility_legacy selected)`, dann zweimal
  `Kept the compatibility value "~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation" of … (HKLM): written by this run (task compatibility_legacy)`;
  (e) ebenso mit `"~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation"`; (f)
  `Kept the compatibility value "~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation" of …\Empire Earth.exe (HKCU): written by this run (task compatibility_legacy)`
  und `No compatibility value of …\EE-AOC.exe (HKCU)`. In keinem Lauf eine Zeile
  `Removed the old Windows Vista/7 compatibility value`.

#### TP-21: Windows 7: Update entfernt nur die Werte früherer Setups (nur VM)

- **Status:** ausgearbeitet
- **Priorität:** P3 (nur VM; auch die Variante (c) mit `compatibility_legacy`)
- **Bezug:** R15, ADR 0005 (Bereinigung, `IsLegacyVistaCompatValue`), ADR 0010 (Ausnahme für den
  Wert von `compatibility_legacy`, `ShouldRemoveLegacyVistaCompatValue`), Vertrag 3.7; Forum §8
  Nr. 5 („Unter Windows 7 besonders den Standardfall WINXPSP3 prüfen“)
- **Ziel:** Ein Update unter Windows 7 entfernt genau die Werte, die frühere Setups dort geschrieben
  haben (bei 1.7.2 der Wert von `EE-AOC.exe`), und lässt jeden anderen Wert stehen: einen, den der
  Spieler selbst gesetzt hat, `~ RUNASADMIN` und den Wert, den derselbe Lauf mit
  `compatibility_legacy` schreibt; wird die Aufgabe bei einem späteren Lauf abgewählt, entfernt die
  Bereinigung ihren Wert.
- **Build-Art:** (a) A+ oder B (die Spielstarts in Schritt 2 und 4 nur B); (b) und (c) A oder B
- **Ausgangszustand:** (a) offizielles Setup 1.7.2 (EE) unter Windows 7 als Administrator mit
  „Empfohlene Einstellungen“ und „Installiere Empire Earth und Die Kunst der Eroberungen -
  Erweiterung“ installiert, einmal gestartet; dazu ein eigener Wert des Spielers für
  `Empire Earth.exe` (Schritt 3). (b) Kein Empire Earth; die Werte früherer Setups werden mit
  `reg add` nachgestellt, für Tests ohne die Daten von Weg B.
- **Snapshot:** (a) `S-Win7-172-EE`; (b) und (c) `S-Win7` (nur VM, nie auf dem Laptop)
- **Varianten:** (a) EE-admin als Update an Ort und Stelle (NeoEE nutzt denselben Code); (b)
  EE-admin (HKLM) und EE-user (HKCU); (c) EE-admin mit `compatibility_legacy` über nachgestellten
  Werten früherer Setups, danach ein zweiter Lauf ohne die Aufgabe (S-WP10).
- **Schritte:**
  1. (a) Die `reg query`-Befehle ausführen. Nach 1.7.2 erwartet: in HKLM für `EE-AOC.exe`
     `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3`, für `Empire Earth.exe`
     kein Wert (der Versionsfilter `0.6.2` von 1.7.2 hat ihn nie greifen lassen); in HKCU für beide
     `~ RUNASADMIN`. Weicht das ab, die Ausgabe ins Protokoll und trotzdem weitermachen.
  2. Nur Weg B: AoC mit dem Wert von 1.7.2 starten (siehe oben) und das Ergebnis notieren; das ist
     der Vergleich für ADR 0005.
  3. In einer Eingabeaufforderung als Administrator einen eigenen Wert des Spielers setzen (Pfad an
     den Installationsordner anpassen):

     ```bat
     reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "C:\Program Files (x86)\Empire Earth\Empire Earth\Empire Earth.exe" /t REG_SZ /d "~ WINXPSP3 DISABLEDWM" /f /reg:64
     ```

  4. Den Testbuild mit den offiziellen AppIds (Weg A+ aus
     [6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids) oder Weg B) mit
     `/LOG="C:\EE-Test\logs\TP-21a_EE-admin.log"` starten (Weg A+ zusätzlich
     `/MERGETASKS="!dxwebsetup"`), „Aktuelle Installation aktualisieren“ bzw. „Vorhandene
     Installation reparieren“, Telemetrie aus, installieren, fertigstellen. Die `reg query`-Befehle
     wiederholen; nur Weg B: AoC wie in Schritt 2 starten.
  5. (b) admin: Auf `S-Win7` in einer Eingabeaufforderung als Administrator nachstellen, was ein
     früheres Setup mit `everyoneadminstart` und beiden Kompatibilitätsaufgaben für Empire Earth
     geschrieben hätte, und einen eigenen Wert für AoC setzen:

     ```bat
     set L=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
     reg add "%L%" /v "C:\Program Files (x86)\Empire Earth\Empire Earth\Empire Earth.exe" /t REG_SZ /d "~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3" /f /reg:64
     reg add "%L%" /v "C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\EE-AOC.exe" /t REG_SZ /d "~ WINXPSP3 DISABLEDWM" /f /reg:64
     ```

     Dann das Setup mit `/LOG="C:\EE-Test\logs\TP-21b_EE-admin.log"`, „Für alle Benutzer
     installieren“, „Empfohlene Einstellungen“ mit Empire Earth und AoC, Zielordner unverändert
     (`C:\Program Files (x86)\Empire Earth`), installieren; die `reg query`-Befehle wiederholen.
  6. (b) user: Snapshot zurücksetzen, in einer Eingabeaufforderung ohne Administratorrechte:

     ```bat
     set L=HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
     reg add "%L%" /v "%LOCALAPPDATA%\Programs\Empire Earth\Empire Earth\Empire Earth.exe" /t REG_SZ /d "~ WINXPSP3" /f
     reg add "%L%" /v "%LOCALAPPDATA%\Programs\Empire Earth\Empire Earth - The Art of Conquest\EE-AOC.exe" /t REG_SZ /d "~ RUNASADMIN" /f
     ```

     Dann das Setup mit `/CURRENTUSER /LOG="C:\EE-Test\logs\TP-21b_EE-user.log"`, „Empfohlene
     Einstellungen“ mit Empire Earth und AoC, Zielordner unverändert (er muss zu den Pfaden oben
     passen), installieren; `reg query` für HKCU wiederholen.
  7. (c) Snapshot `S-Win7` zurücksetzen und in einer Eingabeaufforderung als Administrator die Werte
     von 1.7.2 und einem früheren Setup nachstellen:

     ```bat
     set L=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
     reg add "%L%" /v "C:\Program Files (x86)\Empire Earth\Empire Earth\Empire Earth.exe" /t REG_SZ /d "~ RUNASADMIN WINXPSP3" /f /reg:64
     reg add "%L%" /v "C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\EE-AOC.exe" /t REG_SZ /d "~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3" /f /reg:64
     ```

     Dann das Setup mit `/LOG="C:\EE-Test\logs\TP-21c_EE-admin.log"`, „Für alle Benutzer
     installieren“, „Benutzerdefinierte Installationseinstellungen“ mit Empire Earth und AoC,
     Zielordner unverändert, auf der Aufgabenseite „Kompatibilitätseinstellungen aktivieren
     (optional unter Windows 7: …)“ anhaken, installieren; die `reg query`-Befehle wiederholen.
  8. (c) Das Setup ein zweites Mal mit `/LOG="C:\EE-Test\logs\TP-21c2_EE-admin.log"` starten,
     „Aktuelle Installation aktualisieren“ bzw. „Vorhandene Installation reparieren“ nicht wählen,
     sondern „Benutzerdefinierte Installationseinstellungen“ mit Empire Earth und AoC; auf der
     Aufgabenseite prüfen, dass „Kompatibilitätseinstellungen aktivieren (optional unter Windows 7:
     …)“ vom ersten Lauf her angehakt ist, den Haken entfernen, installieren; die `reg query`-Befehle
     wiederholen.
- **Erwartetes Ergebnis:**
  - (a) nach dem Update: kein Wert mehr für `EE-AOC.exe` in HKLM; für `Empire Earth.exe` in HKLM
    weiterhin `~ WINXPSP3 DISABLEDWM` (der Wert des Spielers); in HKCU keine der beiden
    `~ RUNASADMIN`-Zeilen mehr. Nur Weg B: AoC startet nach dem Update ohne Fehler; das Ergebnis
    aus Schritt 2 steht zum Vergleich im Protokoll.
  - (b) admin: der Wert von `Empire Earth.exe` ist entfernt, `EE-AOC.exe` behält
    `~ WINXPSP3 DISABLEDWM`.
  - (b) user: der Wert von `Empire Earth.exe` ist entfernt, `EE-AOC.exe` behält `~ RUNASADMIN`.
  - (c) nach Schritt 7: in HKLM für beide Programme genau
    `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`: die Einträge der Aufgabe haben die
    nachgestellten Werte ersetzt, und die Bereinigung hat den neuen Wert stehen lassen; nirgends
    `WINXPSP3`. Nach Schritt 8: kein Wert mehr für beide Programme (die Bereinigung entfernt den
    Wert der abgewählten Aufgabe, denn er ist einer der Werte früherer Setups).
  - Kein anderer Wert unter `AppCompatFlags\Layers` hat sich geändert (Ausgaben vorher und nachher
    vergleichen).
- **Log-Hinweis:** (a) `Removed the old Windows Vista/7 compatibility value "~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3" of …\EE-AOC.exe (HKLM)`,
  `Kept the compatibility value "~ WINXPSP3 DISABLEDWM" of …\Empire Earth.exe (HKLM): not a value of an earlier setup`
  und zweimal `Removed the old per-user RUNASADMIN flag of …`; (b) admin
  `Removed the old Windows Vista/7 compatibility value "~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3" of …\Empire Earth.exe (HKLM)`
  und `Kept the compatibility value "~ WINXPSP3 DISABLEDWM" of …\EE-AOC.exe (HKLM): …`; (b) user
  `Removed the old Windows Vista/7 compatibility value "~ WINXPSP3" of …\Empire Earth.exe (HKCU)` und
  `Kept the compatibility value "~ RUNASADMIN" of …\EE-AOC.exe (HKCU): …`; (c) Schritt 7: Kopfzeile
  mit ` (opt-in task compatibility_legacy selected)` und zweimal
  `Kept the compatibility value "~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation" of … (HKLM): written by this run (task compatibility_legacy)`;
  Schritt 8: Kopfzeile ohne den Zusatz und zweimal
  `Removed the old Windows Vista/7 compatibility value "~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation" of … (HKLM)`.

#### TP-22: Windows 10/11 und 8.1: Kompatibilitätswerte unverändert

- **Status:** ausgearbeitet
- **Priorität:** P1 (Varianten a, d und e; b und c: P2, sie sagen erst mit dem Spielstart von Weg B
  mehr als die Contract-Prüfung; f unter Windows 8.1: P3, nur VM)
- **Bezug:** R15, ADR 0005 (ab Windows 8 unverändert), ADR 0010 Punkt 6 (Windows 8 und 8.1 gegenüber
  1.7.2), Vertrag 3.4 und 3.7; Forum §8 Nr. 5 (t=5842 p=39349, t=5748 p=38768)
- **Ziel:** Ab Windows 8 schreibt das Setup dieselben Werte wie vor S-WP4 (`WIN7RTM`, die Flags der
  Aufgabe `compatibility`, die GPU-Präferenz), ein Update entfernt keinen Kompatibilitätswert außer
  dem alten `~ RUNASADMIN` in HKCU, und das Spiel startet mit allen Aufgaben, ohne
  `compatibility_windows` und ohne beide.
- **Build-Art:** (a) bis (d) und (f) A oder B, (e) A+ oder B (Schritt 5 und der Spielstart in
  Schritt 6 nur B)
- **Ausgangszustand:** (a) bis (d) und (f) kein Empire Earth; (e) offizielles Setup 1.7.2 (EE) als
  Administrator installiert, einmal gestartet.
- **Snapshot:** (a) bis (d) `S-Basis`; (e) `S-172-EE`; (f) `S-Win81` (nur VM). Auf dem `Laptop` nur
  Weg B mit Wiederherstellungspunkt.
- **Varianten:** (a) EE-admin mit beiden Aufgaben, (b) EE-admin ohne `compatibility_windows`, (c)
  EE-admin ohne beide, (d) EE-user mit beiden, (e) EE-admin als Update über 1.7.2, (f) optional
  EE-admin unter Windows 8.1 mit beiden Aufgaben und ohne beide: Das offizielle Setup 1.7.2 schrieb
  dort keine Werte, unter Windows 8.1 ist das Verhalten neu und bisher ungetestet (ADR 0010 Punkt
  6). NeoEE nutzt dieselben Einträge.
- **Schritte:**
  1. Die `reg query`-Befehle ausführen (vor (a) bis (d): keine Werte).
  2. (a) Setup mit `/LOG="C:\EE-Test\logs\TP-22a_EE-admin.log"`, „Für alle Benutzer installieren“,
     „Benutzerdefinierte Installationseinstellungen“ mit Empire Earth und AoC, Telemetrie aus; auf
     der Aufgabenseite prüfen, dass beide Kompatibilitätsaufgaben angehakt sind, und installieren.
     Danach die `reg query`-Befehle und
     `reg query "HKCU\Software\Microsoft\DirectX\UserGpuPreferences"`.
  3. Snapshot zurücksetzen und wie Schritt 2 mit (b) „Kompatibilitätsmodus für ältere
     Windows-Versionen aktivieren“ abgewählt (`TP-22b`), (c) beide abgewählt (`TP-22c`), (d)
     `/CURRENTUSER` mit beiden Aufgaben (`TP-22d_EE-user`).
  4. (e) Auf `S-172-EE` die Ausgaben der `reg query`-Befehle notieren, den Testbuild mit den
     offiziellen AppIds (Weg A+ mit `/MERGETASKS="!dxwebsetup"` oder Weg B) mit
     `/LOG="C:\EE-Test\logs\TP-22e_EE-admin.log"` und „Aktuelle Installation aktualisieren“ bzw.
     „Vorhandene Installation reparieren“ ausführen, danach dieselben Abfragen.
  5. Nur Weg B: nach (a), (b) und (c) Empire Earth und AoC je starten (siehe oben).
  6. (f) Nur in der VM `S-Win81`: Schritt 2 mit `TP-22f` im Log-Namen (die Aufgabenseite zeigt beide
     Kompatibilitätsaufgaben angehakt), dann die `reg query`-Befehle und die Abfrage von
     `UserGpuPreferences`; nur Weg B: Empire Earth und AoC je starten. Snapshot zurücksetzen und
     dasselbe mit beiden Aufgaben abgewählt (`TP-22f2`), wieder beide Spiele starten.
- **Erwartetes Ergebnis:**
  - (a): in HKLM für beide Programme `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WIN7RTM`,
    in HKCU keine; unter `UserGpuPreferences` für beide `GpuPreference=2;`.
  - (b): in HKLM für beide `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`; keine
    GPU-Präferenz.
  - (c): weder Kompatibilitätswerte noch GPU-Präferenz.
  - (d): in HKCU für beide `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WIN7RTM`, in
    HKLM keine; GPU-Präferenz wie (a).
  - (e): nach dem Update in HKLM dieselben Werte wie vorher (1.7.2 schrieb unter Windows 10 schon
    `… WIN7RTM`); in HKCU keine `~ RUNASADMIN`-Zeilen mehr.
  - Schritt 5: Alle Varianten starten ohne Fehlermeldung, Runtime-Fehler oder schwarzen Bildschirm.
  - (f): mit beiden Aufgaben in HKLM dieselben Werte wie (a), aber keine GPU-Präferenz (sie gibt es
    erst ab Windows 10, Vertrag 3.4); ohne beide Aufgaben keine Werte. Die Spielstarts sind ein
    Befund: Startet ein Spiel unter Windows 8.1 nur ohne die Werte, geht das mit Grafikchip und
    Treiber an die Maintainer, als Vorschlag für ein Folgepaket, das die beiden Aufgaben unter
    Windows 8 und 8.1 nicht mehr vorauswählt. Ohne Windows-8.1-VM steht der Teil als „nicht
    durchgeführt: ungetestet“ im Protokoll.
- **Log-Hinweis:** Keine Zeile `… this setup writes no compatibility values on Windows Vista/7 …`
  und keine Zeile `Removed the old Windows Vista/7 compatibility value`; bei (e) zweimal
  `Removed the old per-user RUNASADMIN flag of …`.

#### TP-23: Grafikmatrix mit und ohne DirectX-Wrapper

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** ADR 0005 (Punkt 2: Wrapper-Vorauswahl bleibt, wählbar), ADR 0010 Punkt 4 (die
  Entscheidungsregel), Vertrag 3.3 (`Rasterizer Name`); Forum §8 Nr. 3 (t=5751, t=1862, t=1643,
  t=2884, t=5588, t=5887 p=39385; NeoEE-Einblendung t=10968 p=47345)
- **Ziel:** Für den Grafikchip des Testrechners belegen, wie sich die Spiele ohne Wrapper und mit
  jedem Wrapper verhalten (Menütexte, HUD, Einheiten, Flackern, Maus, NeoEE-Einblendung), und dass
  der Weg zu „Nativ“ funktioniert. Das Ergebnis entscheidet, ob die Vorauswahl je Hersteller bleibt.
- **Build-Art:** B
- **Ausgangszustand:** Windows 10/11 mit echter 3D-Beschleunigung (der Laptop oder ein anderer
  Rechner; eine VM ohne 3D-Beschleunigung zählt nicht), aktueller Grafiktreiber; Grafikchip und
  Treiberversion ins Protokoll (Geräte-Manager › Grafikkarten). Kein Empire Earth installiert.
- **Snapshot:** `Laptop` (mit Wiederherstellungspunkt, Regel 1)
- **Varianten:** NeoEE-admin mit vier Einstellungen: DirectX 11 (Vorauswahl bei NVIDIA, AMD und
  Intel), Nativ, DirectX 7 und DirectX 9; EE-admin nur DirectX 11 und Nativ (ohne
  NeoEE-Einblendung). Weitere Rechner (NVIDIA, AMD, Intel HD 4000/4600, Hybrid-Laptop), soweit
  vorhanden, je mit eigenen Protokollzeilen.
- **Schritte:**
  1. NeoEE-Setup mit `/LOG="C:\EE-Test\logs\TP-23_NeoEE-admin_dx11.log"`, „Empfohlene
     Einstellungen“ mit Empire Earth und AoC, Telemetrie aus. Auf der Seite „Wählen Sie Ihren
     Grafikkartenhersteller aus“ notieren, welche Option vorausgewählt ist, sie lassen und
     installieren.
  2. In `<Installationsordner>\Empire Earth` die Wrapper-Dateien notieren (DirectX 11/dgVoodoo:
     `DDraw.dll`, `D3DImm.dll`, `dgVoodooCpl.exe`, `dgVoodoo.conf`; DirectX 7 und DirectX 9: nur
     `DDraw.dll`; Nativ: keine davon) und
     `reg query "HKCU\Software\Neo\Empire Earth" /v "Rasterizer Name"` ausführen (EE-Setup:
     `HKCU\Software\SSSI\Empire Earth`).
  3. Empire Earth starten: Sind im Hauptmenü alle Texte lesbar? Dann im Mehrspielermenü ein Spiel im
     lokalen Netzwerk erstellen, einen Computergegner hinzufügen und starten (lässt das Spiel den
     Start allein nicht zu, mit einem zweiten Rechner wie in TP-72): Erscheint die
     NeoEE-Einblendung (Ball-Animation während der Initialisierung, `ShowGui: true` in
     `NeoEE.cfg`) über dem Spiel? Drei Minuten spielen: HUD-Werte (Rohstoffe, Bevölkerung)
     sichtbar, Einheiten und Gebäude sichtbar, kein Flackern, die Maus reagiert (Einheiten
     auswählen, Bildlauf am Rand, Menüs). Dasselbe mit AoC.
  4. Setup erneut starten (`…_native.log`), „Empfohlene Einstellungen“ mit Empire Earth und AoC
     (nicht „reparieren“, sonst fehlt die Grafikkarten-Seite), dort „Nativ“; Schritte 2 und 3.
  5. Setup erneut starten (`…_dx7.log`), „Benutzerdefinierte Installationseinstellungen“, auf der
     Komponentenseite unter „DirectX-Wrapper“ „DirectX 7 [Am ressourcenschonendsten]“; Schritte 2
     und 3. Dasselbe mit „DirectX 9 [Am kompatibelsten]“ (`…_dx9.log`).
  6. Das EE-Setup (eigener Standardordner `Empire Earth`) mit der Vorauswahl und mit „Nativ“;
     Schritte 2 und 3 ohne die NeoEE-Einblendung.
- **Erwartetes Ergebnis:**
  - Nach jedem Lauf liegen genau die Wrapper-Dateien der Einstellung im Spielordner (die Dateien der
    vorigen Einstellung entfernt das Setup vorher); `Rasterizer Name` ist `Direct3D` mit Wrapper und
    `Direct3D Hardware TnL` bei „Nativ“.
  - Die Spiele erreichen in jeder Einstellung das Hauptmenü. Ob Menütexte, HUD, Einheiten, Maus und
    NeoEE-Einblendung funktionieren, ist der Befund dieses Falls: je Einstellung und Spiel eine Zeile
    im Protokoll mit „ok“ oder dem Fehlerbild (z. B. „Maus reagiert im Spiel nicht“, t=5887).
  - Was aus dem Befund folgt, legt die Regel aus ADR 0010 Punkt 4 fest, die vor dem Test bestimmt
    wurde: Zeigt die vorausgewählte Stufe bei diesem Hersteller einen Defekt, den „Nativ“ auf
    demselben Rechner nicht zeigt (Menütexte fehlen, die Maus reagiert nicht, die
    NeoEE-Einblendung fehlt, Absturz oder Einfrieren), geht das Ergebnis mit Grafikchip und Treiber
    an die Maintainer, als Vorschlag, die Vorauswahl **für diesen Hersteller** auf die beste Stufe
    der Matrix zu ändern; die Änderung selbst ist ein Folgepaket mit CHANGELOG-Eintrag. Bei gleichem
    Ergebnis bleibt die Vorauswahl. Ein Defekt, den auch „Nativ“ zeigt, betrifft nicht die
    Vorauswahl (ins Protokoll, an die Maintainer).
- **Log-Hinweis:** `<Hersteller> GPU detected` bzw. `Unknown GPU detected` und
  `Using <Hersteller> GPU settings: additional\directx_wrapper\dx11_lvl11` (bzw. `…\dx11_lvl10_1`,
  `…\dx9`, `!additional\directx_wrapper` bei „Nativ“). Bei der benutzerdefinierten Installation
  steht die Auswahl im Uninstall-Schlüssel: `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v "Inno Setup: Selected Components" /reg:64`.

#### TP-24: 150 % Anzeigeskalierung mit und ohne Aufgabe compatibility

- **Status:** ausgearbeitet
- **Priorität:** P2 (Windows-7-Varianten (c) und (d): P3, nur VM)
- **Bezug:** Vertrag O4 und 3.3 (`Game Window Width`, `Game Window Height` in physischen Pixeln),
  ADR 0005 (Folgen: ohne `HIGHDPIAWARE` unter Windows 7), ADR 0010 (`compatibility_legacy` setzt
  `HIGHDPIAWARE` unter Windows 7), R15
- **Ziel:** Bei 150 % schreibt das Setup die Fenstergröße in physischen Pixeln, und es ist
  festgehalten, ob das Spiel mit `HIGHDPIAWARE` (Aufgabe `compatibility`, unter Windows 7 die
  freiwillige Aufgabe `compatibility_legacy`) und ohne auf den Bildschirm passt.
- **Build-Art:** B (Schritte 1 und 2 auch A)
- **Ausgangszustand:** (a), (b) Windows 10/11, *Einstellungen › System › Anzeige › Skalierung* auf
  150 %, danach ab- und wieder angemeldet; (c) Windows 7, *Systemsteuerung › Anzeige* „Größer –
  150 %“, abgemeldet und wieder angemeldet. Physische Auflösung notieren (Windows 10/11:
  „Bildschirmauflösung“ auf derselben Seite; Windows 7: *Bildschirmauflösung*). Kein Empire Earth.
- **Snapshot:** (a), (b) `Laptop` (Weg B) oder `S-Basis`; (c), (d) `S-Win7`
- **Varianten:** (a) EE-admin mit beiden Aufgaben (`HIGHDPIAWARE`), (b) EE-admin ohne
  „Kompatibilitätseinstellungen aktivieren“ (Wert `~ WIN7RTM`), (c) EE-admin unter Windows 7 mit den
  vorgegebenen Aufgaben (keine Werte), (d) EE-admin unter Windows 7 mit `compatibility_legacy`
  (`HIGHDPIAWARE`, S-WP10).
- **Schritte:**
  1. (a) Setup mit `/LOG="C:\EE-Test\logs\TP-24a_EE-admin.log"`, „Benutzerdefinierte
     Installationseinstellungen“ mit Empire Earth und AoC, Aufgaben unverändert, installieren.
  2. Abfragen:
     `reg query "HKCU\Software\SSSI\Empire Earth" /v "Game Window Width"`,
     `reg query "HKCU\Software\SSSI\Empire Earth" /v "Game Window Height"` (hexadezimal:
     `0x780` = 1920, `0x438` = 1080, `0x500` = 1280, `0x2d0` = 720) und die `reg query`-Befehle der
     Kompatibilitätswerte.
  3. Nur Weg B: Empire Earth starten. Füllt das Bild den Bildschirm genau, ist es größer (Teile
     abgeschnitten, z. B. die untere Leiste mit dem HUD) oder kleiner (schwarze Ränder)? Ein
     Bildschirmfoto ins Protokoll. Dasselbe mit AoC (`HKCU\Software\Mad Doc Software\EE-AOC`).
  4. (b) Deinstallieren bzw. Snapshot zurücksetzen, Schritt 1 mit `TP-24b` im Log-Namen und
     abgewählter Aufgabe „Kompatibilitätseinstellungen aktivieren“; Schritte 2 und 3.
  5. (c) Schritte 1 bis 3 auf `S-Win7` mit `TP-24c` (die Aufgabenseite zeigt nur die nicht
     angehakte Aufgabe „Kompatibilitätseinstellungen aktivieren (optional unter Windows 7: …)“; sie
     bleibt aus).
  6. (d) Snapshot `S-Win7` zurücksetzen, Schritte 1 bis 3 mit `TP-24d` und angehakter Aufgabe
     „Kompatibilitätseinstellungen aktivieren (optional unter Windows 7: …)“.
- **Erwartetes Ergebnis:**
  - Schritt 2, alle Varianten: `Game Window Width` und `Game Window Height` sind die physische
    Auflösung, begrenzt auf 1024 bis 1920 bzw. 768 bis 1080 (bei 1920 × 1080: `0x780` und `0x438`,
    nicht die logischen 1280 × 720). Logische Werte sind ein Befund zu Vertrag O4.
  - Kompatibilitätswerte: (a) `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WIN7RTM`,
    (b) `~ WIN7RTM`, (c) keiner, (d) `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation`.
  - Schritt 3 ist ein Befund, kein Bestanden/Nicht bestanden: je Variante und Spiel „passt“, „zu
    groß“ oder „zu klein“. Passt das Bild nur mit `HIGHDPIAWARE` ((a) bzw. (d)), bekommt Vertrag 3.3
    den Hinweis, dass die Fenstergröße nur mit `HIGHDPIAWARE` passt (Vertrag O4); (c) ist dann die
    bekannte Folge von ADR 0005 für Windows 7, die (d) mit der freiwilligen Aufgabe beheben soll (README).
- **Log-Hinweis:** Seit S-WP8 steht am Anfang jedes Logs die Zeile
  `Screen: <Breite> x <Höhe> pixels (primary screen, SM_CXSCREEN x SM_CYSCREEN), <dpi> DPI
  (LOGPIXELSX, <p> % scaling), game window <Breite> x <Höhe>` ([TP-60](#tp-60-niedrige-bildschirmauflösung)):
  bei 150 % `144 DPI (LOGPIXELSX, 150 % scaling)` und die physische Auflösung, das Spielfenster
  gleich den Registry-Werten aus Schritt 2. Zeigt sie 96 DPI und die logische Auflösung (bei
  1920 × 1080 also 1280 x 720), ist das ein Befund zu Vertrag O4. Bei (c) zusätzlich die Zeilen aus
  [TP-20](#tp-20-windows-7-neuinstallation-ohne-kompatibilitätswerte-und-mit-compatibility_legacy-nur-vm) (a),
  bei (d) die aus TP-20 (d).

### Block 3: Build und Log (S-WP5)

Was ADR 0008 (Punkte 1 und 5) verlangt und nur auf Windows prüfbar ist: die SHA-256-Datei neben
jedem Setup und ihre Prüfung mit `Get-FileHash` und `sha256sum -c`, und das Setup-Log, das jedes
Setup ohne `/LOG` unter `%TEMP%` schreibt (`SetupLogging=yes`), auch bei Over-the-Shoulder-Erhöhung.
Die Form der SHA-256-Datei prüft zusätzlich `ci/tests/build_helpers.tests.ps1`.

#### TP-30: Prüfsumme des Setups und Setup-Log ohne Schalter

- **Status:** ausgearbeitet
- **Priorität:** P1 (Teile a und b; c bis e: P2, c braucht ein zweites Konto)
- **Bezug:** R14, ADR 0008 (Punkte 1 und 5), README „Checksums of the setups“ und „Support“;
  Forum §8 Nr. 12 des Problemabgleichs (t=5741, t=3763: kaputte und umgepackte Downloads)
- **Ziel:** Die SHA-256-Datei neben jedem Setup passt zur Setup-Datei und lässt sich mit
  `Get-FileHash` und `sha256sum -c` prüfen; jedes Setup schreibt ohne `/LOG` ein Log nach `%TEMP%`,
  bei Over-the-Shoulder-Erhöhung in das `%TEMP%` des Administratorkontos, und `/LOG` gilt weiter.
- **Build-Art:** A oder B; Teil (a) prüft nur die Dateien des Builds (keine Installation).
- **Ausgangszustand:** (a) Ordner `out\` des Testbuilds aus [Abschnitt 6](#6-testbuild-herstellen)
  mit den vier Setups und ihren `.sha256`-Dateien. (b) bis (e) kein Empire Earth installiert, ein
  Administratorkonto und das Standardkonto „Spieler“.
- **Snapshot:** (a) keiner (es wird nichts verändert; auf dem Rechner, auf dem gebaut wurde);
  (b) bis (e) `S-Basis`, vor jedem Teil zurückgesetzt (die Windows-Sandbox hat kein
  Standardkonto).
- **Varianten:** (a) alle vier Setups; (b), (c), (e) EE-admin; (d) EE-user. NeoEE und portable
  schreiben ihr Log auf dieselbe Weise (eine Einstellung von Inno Setup für alle Varianten) und
  kommen nur in (a) vor.
- **Schritte:**
  1. (a) PowerShell im Ordner `out\EE_Regular` öffnen und ausführen:

     ```powershell
     Get-FileHash .\EE_Setup_v1.7.2.exe -Algorithm SHA256
     Get-Content .\EE_Setup_v1.7.2.exe.sha256
     (Get-FileHash .\EE_Setup_v1.7.2.exe -Algorithm SHA256).Hash -eq (Get-Content .\EE_Setup_v1.7.2.exe.sha256).Split(' ')[0]
     ```

     Dasselbe in `out\NeoEE_Regular`, `out\EE_Portable` und `out\NeoEE_Portable` mit den
     Dateinamen dort.
  2. (a) Mit Git Bash oder WSL im selben Ordner `sha256sum -c EE_Setup_v1.7.2.exe.sha256`. Gegenprobe
     an einer Kopie (das Original bleibt unverändert), in PowerShell:

     ```powershell
     New-Item -ItemType Directory C:\EE-Test\tp30 -Force | Out-Null
     Copy-Item .\EE_Setup_v1.7.2.exe, .\EE_Setup_v1.7.2.exe.sha256 C:\EE-Test\tp30\
     Add-Content C:\EE-Test\tp30\EE_Setup_v1.7.2.exe -Value 'x'
     ```

     In `C:\EE-Test\tp30` erneut `sha256sum -c EE_Setup_v1.7.2.exe.sha256` und den Vergleich aus
     Schritt 1 ausführen, danach `C:\EE-Test\tp30` löschen. Ohne Git Bash und WSL entfällt nur
     `sha256sum` (im Protokoll vermerken), nicht der Vergleich mit `Get-FileHash`.
  3. (b) Als Administrator anmelden, im Explorer `%TEMP%` öffnen und die vorhandenen Dateien
     `Setup Log *.txt` notieren. Das Setup per Doppelklick starten (ohne `/LOG`), „Für alle
     Benutzer installieren“, Spielsprache Deutsch, empfohlene Einstellungen, Telemetrie aus,
     installieren (Weg A: Grenzen in [6.2](#62-weg-a-placeholder-build)). Danach `%TEMP%` neu
     laden (F5).
  4. (c) Snapshot zurücksetzen, als „Spieler“ anmelden, `%TEMP%` öffnen und notieren, das Setup
     per Doppelklick starten, „Für alle Benutzer installieren“ wählen und in der
     Benutzerkontensteuerung Name und Kennwort des Administratorkontos eingeben
     (Over-the-Shoulder-Erhöhung), wie in (b) installieren. Danach `%TEMP%` von „Spieler“ neu
     laden; dann abmelden, als Administrator anmelden und dessen `%TEMP%` öffnen
     (`C:\Users\<Administrator>\AppData\Local\Temp`).
  5. (d) Snapshot zurücksetzen, als „Spieler“ das Setup starten, „Nur für mich installieren“
     wählen (keine Benutzerkontensteuerung) und installieren; `%TEMP%` von „Spieler“ neu laden.
  6. (e) Snapshot zurücksetzen, als Administrator `%TEMP%` notieren, das Setup mit
     `/LOG="C:\EE-Test\logs\TP-30e_EE-admin.log"` starten und wie in (b) installieren. Danach über
     *Einstellungen › Apps* deinstallieren (ohne `/LOG`) und `%TEMP%` neu laden.
  7. Das neue Log aus (c) öffnen und mit Strg+F nach den Namen der beiden Konten suchen.
- **Erwartetes Ergebnis:**
  - (a) `Get-FileHash` zeigt dieselben 64 Zeichen wie die `.sha256`-Datei (dort in
    Kleinbuchstaben), der Vergleich ergibt `True`. Die `.sha256`-Datei hat genau eine Zeile:
    Prüfsumme, zwei Leerzeichen, Dateiname ohne Ordner. `sha256sum -c` meldet
    `EE_Setup_v1.7.2.exe: OK`; an der veränderten Kopie `EE_Setup_v1.7.2.exe: FAILED` mit einer
    Warnung „computed checksum did NOT match“, und der Vergleich ergibt `False`. Dasselbe für alle
    vier Setups.
  - (b) Genau eine neue Datei `Setup Log <heutiges Datum> #<n>.txt` (z. B.
    `Setup Log 2026-10-02 #001.txt`) im `%TEMP%` des Administrators.
  - (c) Im `%TEMP%` von „Spieler“ keine neue Datei `Setup Log …`; die neue Datei liegt im
    `%TEMP%` des Administratorkontos, wie README „Support“ sagt.
  - (d) Die neue Datei liegt im `%TEMP%` von „Spieler“.
  - (e) Das Log steht in `C:\EE-Test\logs\TP-30e_EE-admin.log`; in `%TEMP%` entsteht dabei keine
    neue Datei `Setup Log …`, und die Deinstallation ohne `/LOG` schreibt kein Log.
  - Schritt 7: Das Log enthält Pfade mit dem Namen des Administratorkontos (mindestens das
    temporäre Verzeichnis), aber keine Kennwörter und keine CD-Keys. Der Rat der README, das Log
    vor dem öffentlichen Posten anzusehen, ist also nötig.
- **Log-Hinweis:** Die ersten Zeilen jedes Setup-Logs: `Setup version: Inno Setup version 6.2.2`,
  `Original Setup EXE: <Pfad des Setups>`, `Setup command line: …` (in b bis d ohne `/LOG`, in e
  mit), `User privileges: Administrative` (b, c, e) bzw. `User privileges: None` (d),
  `Administrative install mode: Yes` (b, c, e) bzw. `No` (d) und
  `Created temporary directory: C:\Users\<Konto>\AppData\Local\Temp\is-….tmp` mit dem Konto, in
  dessen `%TEMP%` das Log liegt (c: das Administratorkonto). Am Ende
  `Installation process succeeded.`

### Block 4: Installationseintrag und install.ini (S-WP6)

Was ADR 0004 (Punkte 1, 2, 6, 9, 10) und Vertrag 1.1, 1.2, 1.3 und 3.5 verlangen und nur auf
Windows prüfbar ist: der Installationseintrag (`HKA\Software\Empire Earth Community\Installations\<Produkt>`,
nur reguläre Varianten), `install.ini` im versteckten Ordner `_setupdata_<Produkt>` (alle Varianten,
ASCII mit CRLF, ohne BOM), der Defaults-Marker (`HKCU\Software\Empire Earth Community\GameDefaults\<Produkt>`,
nur reguläre Varianten, nur für das Konto, das das Setup ausführt), `SetupBuild`, der Wert
`Empire Earth Community: ContractVersion` im Uninstall-Schlüssel und sein Fehlen, wenn das Setup
`install.ini` nicht ersetzen konnte oder ein älteres Setup danach lief, und die Deinstallation.
Die Logik prüfen zusätzlich die Unit-Tests (`BuildInstallIniText`, `IsAsciiText`,
`ShouldWriteContractVersionValue`, `ReplaceStateFile` auf Dateiebene) und eine Wine-Probe der
Analyse (ADR 0004, „Implementation“); hier geht es um das echte Windows (64-Bit-Registry-Ansicht,
Benutzerkonten, Freigabemodi beim Löschen).

Werte für die Prüfung (Weg A, `ci\build.ps1 -Placeholders -TestID 1`): AppId EE
`00000000-0000-0000-0000-0000000000EE`, NeoEE `00000000-0000-0000-0000-000000000AEE`; Spielversion
EE `2.0.0.0`, NeoEE `2.0.0.5`; Setup-Version `1.7.2`; `SetupBuild` ist `test1-<Commit>` mit dem
kurzen Commit, den `ci\build.ps1` beim Bauen als `SetupBuild: …` ausgibt (ins Protokoll). Weg A+
und B: die offiziellen AppIds aus [6.3](#63-weg-b-echter-build-aus-eigenen-daten).

#### TP-40: Installationseintrag und install.ini je Variante

- **Status:** ausgearbeitet
- **Priorität:** P1 (Teile a bis d und von e der Teil a mit schreibgeschützter Datei; von e der Teil b
  mit geöffneter Datei und f mit dem offiziellen Setup 1.7.2: P2)
- **Bezug:** D5, R1, ADR 0004 (Punkte 1, 2, 6, 9, 10), Vertrag 1.1, 1.2, 1.3, 2.5 und 3.5,
  Entscheidung K4 der Planrevision (kein Wert im Uninstall-Schlüssel, wenn Löschen oder Umbenennen
  scheitert)
- **Ziel:** Jede Variante hinterlässt genau den Eintrag, die `install.ini` und den Marker, die der
  Vertrag beschreibt; der Wert `Empire Earth Community: ContractVersion` steht nur nach einem Lauf,
  der `install.ini` wirklich ersetzt hat; die Deinstallation entfernt Eintrag, Marker und Ordner und
  lässt `Software\Sierra\CDKeys` stehen.
- **Build-Art:** A oder B; Teil (f) A+ oder B (offizielle AppIds, damit das Setup 1.7.2 dieselbe
  Installation aktualisiert).
- **Ausgangszustand:** kein Empire Earth installiert; für (f) das offizielle EE-Setup 1.7.2
  (selbst heruntergeladen) in der VM.
- **Snapshot:** `S-Basis` vor (a), (b), (c) und (f); (d) und (e) laufen direkt nach (a) auf
  demselben Stand. `S-Sandbox` reicht für (a) bis (e), wenn sie in einer Sitzung nacheinander laufen.
- **Varianten:** (a) EE-admin, (b) EE-user, (c) EE-portable, (d) NeoEE-admin zusätzlich zu (a) in
  einem eigenen Ordner, (e) EE-admin mit schreibgeschützter bzw. geöffneter `install.ini`, (f)
  EE-admin, danach das offizielle Setup 1.7.2. NeoEE-user und NeoEE-portable schreiben dieselben
  Einträge mit `NeoEE` statt `EE` (derselbe Code, nur `InstallType` anders) und sind nicht eigens
  aufgeführt.
- **Schritte:**
  1. Ordner `C:\EE-Test\logs` anlegen. Bei allen Läufen: Setup mit
     `/LOG="C:\EE-Test\logs\TP-40<Teil>_<Variante>.log"` starten, Spielsprache Deutsch, empfohlene
     Einstellungen mit Empire Earth und AoC, Telemetrie aus (Weg A: Grenzen in
     [6.2](#62-weg-a-placeholder-build)).
  2. (a) EE-admin installieren („Für alle Benutzer installieren“). Danach in der
     Eingabeaufforderung:

     ```bat
     reg query "HKLM\SOFTWARE\Empire Earth Community\Installations\EE" /reg:64
     reg query "HKCU\Software\Empire Earth Community\GameDefaults\EE"
     reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v "Empire Earth Community: ContractVersion" /reg:64
     reg query "HKLM\SOFTWARE\WOW6432Node\Empire Earth Community"
     ```

     und in PowerShell (Pfad je Variante anpassen):

     ```powershell
     $p = 'C:\Program Files (x86)\Empire Earth\_setupdata_EE\install.ini'
     $b = [IO.File]::ReadAllBytes($p)
     'BOM: ' + ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
     'Nicht-ASCII: ' + @($b | Where-Object { $_ -gt 127 }).Count
     'LF ohne CR: ' + @(for ($i = 0; $i -lt $b.Length; $i++) { if ($b[$i] -eq 10 -and ($i -eq 0 -or $b[$i - 1] -ne 13)) { $i } }).Count
     Get-Content $p
     Get-ChildItem -Force (Split-Path $p) | Select-Object Name, Attributes
     ```

  3. (b) Snapshot zurücksetzen, EE-user installieren („Nur für mich installieren“), dieselben
     Abfragen mit `HKCU\Software\Empire Earth Community\Installations\EE`,
     `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1` (ohne `/reg:64`) und
     `$p = "$env:LOCALAPPDATA\Programs\Empire Earth\_setupdata_EE\install.ini"`.
  4. (c) Snapshot zurücksetzen, das Portable-Setup in einen eigenen Ordner kopieren (z. B.
     `C:\EE-Test\portable`) und dort ausführen; dieselben Abfragen,
     `$p = 'C:\EE-Test\portable\Empire Earth Portable\_setupdata_EE\install.ini'`. Danach
     `C:\EE-Test\portable\Empire Earth Portable` von Hand löschen (Portable hat keine
     Deinstallation).
  5. (d) Auf dem Stand nach (a): NeoEE-admin in seinen Standardordner (`…\Neo Empire Earth`)
     installieren, `reg query "HKLM\SOFTWARE\Empire Earth Community\Installations" /s /reg:64` und
     `reg query "HKCU\Software\Empire Earth Community\GameDefaults" /s`. Dann EE über
     *Einstellungen › Apps* deinstallieren (mit `/LOG`: `"<Ordner>\unins000.exe" /LOG="…"`) und
     dieselben zwei Abfragen wiederholen; danach NeoEE deinstallieren und noch einmal abfragen:
     `reg query "HKLM\SOFTWARE\Empire Earth Community" /reg:64` und
     `reg query "HKCU\Software\Empire Earth Community"`. Vorher und nachher
     `reg query "HKLM\SOFTWARE\WOW6432Node\Sierra\CDKeys"` und `reg query "HKCU\Software\Sierra\CDKeys"`
     notieren (bei Weg A gibt es dort nichts; der Inhalt geht nicht ins Protokoll, Regel 3).
  6. (e) EE-admin wie in (a) installieren. Dann a) die Datei schreibgeschützt machen
     (Eingabeaufforderung als Administrator: `attrib +r "C:\Program Files (x86)\Empire Earth\_setupdata_EE\install.ini"`),
     das Setup erneut ausführen („Vorhandene Installation reparieren“), den Wert im
     Uninstall-Schlüssel und `install.ini` abfragen, `attrib -r …` und noch einmal reparieren;
     b) in einer PowerShell die Datei offen halten, ohne Löschen zu erlauben (wie ein Programm,
     das sie ohne `FILE_SHARE_DELETE` liest):
     `$f = [IO.File]::Open('C:\Program Files (x86)\Empire Earth\_setupdata_EE\install.ini', 'Open', 'Read', 'Read')`,
     das Setup reparieren lassen (PowerShell dabei offen lassen), erst nach dem Ende des Setups
     `$f.Close()`, abfragen, und noch einmal reparieren.
  7. (f) Nur Weg A+ oder B: Snapshot zurücksetzen, den Testbuild EE-admin installieren, dann das
     offizielle Setup 1.7.2 über diese Installation laufen lassen („Aktuelle Installation
     aktualisieren“ bzw. „reparieren“), danach den Wert im Uninstall-Schlüssel, den
     Installationseintrag und `install.ini` abfragen; zum Schluss den Testbuild noch einmal laufen
     lassen und erneut abfragen.
- **Erwartetes Ergebnis:**
  - (a) Der Eintrag `HKLM\SOFTWARE\Empire Earth Community\Installations\EE` (64-Bit-Ansicht, nicht
    unter `WOW6432Node`: die vierte Abfrage findet nichts) hat genau `AppId` (die AppId ohne
    Klammern), `ContractVersion` `0x1`, `GameVersion` `2.0.0.0`, `InstallMode` `admin`,
    `InstallPath` (der Installationsordner ohne `\` am Ende), `SetupBuild` `test1-<Commit>`,
    `SetupVersion` `1.7.2`. Der Marker hat `EE` `0x1` und `AoC` `0x1`. Der Uninstall-Schlüssel hat
    `Empire Earth Community: ContractVersion    REG_DWORD    0x1`. PowerShell: `BOM: False`,
    `Nicht-ASCII: 0`, `LF ohne CR: 0`, dann `[Install]` und die Schlüssel in dieser Reihenfolge:
    `ContractVersion=1`, `Product=EE`, `AppId=…`, `InstallMode=admin`, `GameVersion=2.0.0.0`,
    `SetupVersion=1.7.2`, `SetupBuild=test1-<Commit>`, `Components=…` (mit `game`, `gameaoc`,
    `language\de`), `Tasks=…` (die gewählten Aufgaben), `Written=<Datum Uhrzeit>`; im Ordner liegt
    keine `install.ini.tmp`.
  - (b) Wie (a), aber Eintrag und Uninstall-Schlüssel in HKCU, `InstallMode` `user` (Eintrag und
    `install.ini`), Marker in HKCU.
  - (c) `install.ini` wie (a) mit `InstallMode=portable`; kein Installationseintrag, kein Marker
    (beide Abfragen: Schlüssel nicht gefunden), kein Uninstall-Schlüssel.
  - (d) Nach beiden Installationen gibt es `Installations\EE` und `Installations\NeoEE` (NeoEE:
    `GameVersion` `2.0.0.5`) sowie `GameDefaults\EE` und `GameDefaults\NeoEE`. Nach der
    Deinstallation von EE sind nur noch die NeoEE-Schlüssel da, nach der von NeoEE auch
    `Software\Empire Earth Community` selbst nicht mehr (HKLM und HKCU), und die Ordner
    `_setupdata_EE` bzw. `_setupdata_NeoEE` sind weg. `Software\Sierra\CDKeys` ist in beiden Ansichten
    unverändert.
  - (e) Schreibgeschützt bzw. offen: Die Reparatur läuft ohne Meldung zu Ende; der Uninstall-Schlüssel
    hat danach **keinen** Wert `Empire Earth Community: ContractVersion` (der Launcher meldet dann
    „Unbekannt“). `install.ini` ist in a) und b) die alte Datei (`Written` unverändert), denn das
    Setup kann sie weder bei `ssInstall` noch am Ende löschen und überschreibt nie. Nach der letzten
    Reparatur ohne Störung ist der Wert wieder da und `Written` neu. Nie bleibt eine
    `install.ini.tmp` liegen.
  - (f) Nach dem Setup 1.7.2 fehlt der Wert im Uninstall-Schlüssel (das alte Setup legt den
    Schlüssel neu an), Eintrag und `install.ini` des Testbuilds sind noch da (Vertrag 1.5); den
    alten versteckten Ordner `<Spielordner>\<AppId>` gibt es wieder. Nach dem erneuten Lauf des
    Testbuilds ist der Wert wieder da.
- **Log-Hinweis:** Erste eigene Zeile `Empire Earth 2.0.0.0, setup 1.7.2 (EE, Regular), SetupBuild
  "test1-<Commit>", TestID 1, contract version 1` (Portable: `(EE, Portable)`). Bei `ssInstall`:
  `Install state of the previous run deleted (or there was none): …\install.ini`; am Ende:
  `Wrote …\install.ini (contract version 1, install mode admin)` und
  `Wrote "Empire Earth Community: ContractVersion" = 1 into the uninstall key`, bei Portable
  stattdessen `Portable setup: no uninstall key, …`. Die Registry-Einträge stehen als
  `Key: HKEY_LOCAL_MACHINE\Software\Empire Earth Community\Installations\EE` (bzw.
  `HKEY_CURRENT_USER`) mit `Value name: …`. (e) a): `Unable to delete …\install.ini: it is read-only`,
  `The install state of the previous run could not be deleted: this run writes no …`,
  `Not writing …\install.ini: the old file is still there` und `Not writing "Empire Earth Community:
  ContractVersion" into the uninstall key: the install state of the previous run could not be
  deleted at ssInstall; …`; b): dieselben Zeilen mit `it is held open by another program or access
  is denied` statt `it is read-only`.

#### TP-41: Spieleinstellungen für ein zweites Konto

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** R1, ADR 0004 (Punkt 2, Defaults-Marker; Konsequenzen: Over-the-Shoulder-Erhöhung),
  Vertrag 3.1, 3.5 und 3.6; Forum §8 Nr. 1 (zweites Konto, Over-the-Shoulder-Erhöhung)
- **Ziel:** Zeigen, welche Spieleinstellungen das installierende Konto und welche ein zweites
  Konto bekommt, und dass der Marker nur beim installierenden Konto steht.
- **Build-Art:** A oder B
- **Ausgangszustand:** kein Empire Earth installiert; ein Administratorkonto („Admin“) und das
  Standardkonto „Spieler“, beide schon einmal angemeldet.
- **Snapshot:** `S-Basis` vor (a), (c) und (e) (die Windows-Sandbox hat kein zweites Konto).
- **Varianten:** EE-admin in (a) bis (d), EE-user in (e). NeoEE schreibt dieselben Werte unter
  `Software\Neo\…` und `GameDefaults\NeoEE` und ist nicht eigens aufgeführt.
- **Schritte:**
  1. (a) Als „Admin“ anmelden, EE-admin wie in [TP-40](#tp-40-installationseintrag-und-installini-je-variante)
     installieren, dann in der Eingabeaufforderung von „Admin“:

     ```bat
     reg query "HKCU\Software\SSSI\Empire Earth"
     reg query "HKCU\Software\Mad Doc Software\EE-AOC"
     reg query "HKCU\Software\Empire Earth Community\GameDefaults\EE"
     reg query "HKLM\SOFTWARE\Empire Earth Community\Installations\EE" /reg:64
     ```

  2. (b) Abmelden, als „Spieler“ anmelden und dieselben vier Abfragen ausführen.
  3. (c) Snapshot zurücksetzen, als „Spieler“ anmelden, das Setup starten, „Für alle Benutzer
     installieren“ wählen und in der Benutzerkontensteuerung Name und Kennwort von „Admin“ eingeben
     (Over-the-Shoulder-Erhöhung); wie in (a) installieren. Danach die vier Abfragen als „Spieler“,
     dann abmelden und als „Admin“.
  4. (d) Als „Admin“ über *Einstellungen › Apps* deinstallieren, dann die Abfragen von (a) als
     „Admin“.
  5. (e) Snapshot zurücksetzen, als „Spieler“ EE-user („Nur für mich installieren“, keine
     Benutzerkontensteuerung) installieren; die Abfragen als „Spieler“ (Eintrag unter
     `HKCU\Software\Empire Earth Community\Installations\EE`), dann als „Admin“.
- **Erwartetes Ergebnis:**
  - (a) Bei „Admin“ gibt es beide Spieleinstellungsschlüssel (z. B. `Wait for VSync` `0x0`,
    `Game Bit Depth` `0x20`, `Installed From Directory`) und den Marker mit `EE` `0x1` und `AoC`
    `0x1`; den Installationseintrag in HKLM.
  - (b) Bei „Spieler“ fehlen beide Spieleinstellungsschlüssel und der Marker („Der angegebene
    Registrierungsschlüssel bzw. Wert wurde nicht gefunden“); den Installationseintrag in HKLM
    kann „Spieler“ lesen. Das ist der Fall, den der Launcher beim ersten Start für „Spieler“ löst
    (R1, Vertrag 3.6, Testplan des Launchers).
  - (c) Bei „Spieler“ wie (b): keine Spieleinstellungen, kein Marker, obwohl „Spieler“ das Setup
    gestartet hat; bei „Admin“ wie (a). Das Setup schreibt beides in das HKCU des Kontos, das die
    Erhöhung bestätigt hat (ADR 0004, Konsequenzen; README „Empire Earth Launcher“).
  - (d) Installationseintrag und Marker von „Admin“ sind weg, `Software\Empire Earth Community`
    gibt es in HKLM und im HKCU von „Admin“ nicht mehr. Die Spieleinstellungen von „Admin“ entfernt
    die Deinstallation wie bisher (`uninsdeletekey`).
  - (e) Bei „Spieler“ Spieleinstellungen, Marker und Installationseintrag in HKCU
    (`InstallMode` `user`); bei „Admin“ nichts davon, auch kein Eintrag in HKLM.
- **Log-Hinweis:** In (a) und (c) `Administrative install mode: Yes` und die Registry-Zeilen
  `Key: HKEY_CURRENT_USER\Software\Empire Earth Community\GameDefaults\EE`; das Log von (c) liegt im
  `%TEMP%` von „Admin“ ([TP-30](#tp-30-prüfsumme-des-setups-und-setup-log-ohne-schalter)). In (e)
  `Administrative install mode: No` und
  `Key: HKEY_CURRENT_USER\Software\Empire Earth Community\Installations\EE`.

### Block 5: Integritätsmanifest (S-WP7)

Was ADR 0004 (Punkte 3 bis 8) und Vertrag 1.2 und 2 verlangen und nur auf Windows prüfbar ist:
`files.sha256` im versteckten Ordner `_setupdata_<Produkt>` nach jeder Installation (alle Varianten,
ASCII mit LF, ohne BOM, jede Datei einmal, sortiert), die Seite „Installierte Dateien werden
geprüft“ am Ende der Installation und ihre Dauer, Dateien, die während der Installation verschwinden
(`[MissingAfterInstall]` in `install.ini` und der Hinweis mit dem Rat zur Antivirus-Ausnahme), und
eine Datei, die ein anderes Programm gesperrt hält (kein Manifest, kein Wert
`Empire Earth Community: ContractVersion` im Uninstall-Schlüssel). Die Logik prüfen zusätzlich die
Unit-Tests (Pfade, Zeilen, Sortierung mit 2000 Einträgen, `[MissingAfterInstall]`, Hinweisliste und
auf Dateiebene das ganze Schreiben mit gelöschter und gesperrter Datei) und eine Wine-Probe der
Analyse (ADR 0004, „Implementation“); hier geht es um das echte Windows (Virenscanner,
Freigabemodi, Dauer auf echter Hardware).

Unter Windows gibt es kein `sha256sum`. Die PowerShell-Zeilen in TP-50 prüfen das Manifest Zeile für
Zeile mit `Get-FileHash`; wer Git für Windows installiert hat, kann im Installationsordner in der
„Git Bash“ auch `sha256sum -c _setupdata_EE/files.sha256` aufrufen (gleiches Ergebnis).

#### TP-50: Von Antivirenprogrammen gelöschte Dateien

- **Status:** ausgearbeitet
- **Priorität:** P1 (Teile a, b ohne den stillen Lauf und d; c mit gesperrter Datei und der stille
  Lauf von b: P2; Zeitmessung auf HDD bzw. in der Windows-7-VM, Teil e: P3)
- **Bezug:** R2, R11, D5, ADR 0004 (Punkte 3 bis 8), Vertrag 1.2, 2.1 bis 2.3, Entscheidungen K4
  und K12 der Planrevision; Forum §8 Nr. 14 (t=11045 p=48037, t=41147 p=80317: Antivirenprogramme
  löschen Spieldateien)
- **Ziel:** Jede Installation hinterlässt ein `files.sha256`, das genau die installierten Dateien mit
  ihren SHA-256 nennt; verschwindet eine Datei während der Installation, nennt das Setup sie, rät zur
  Ausnahme im Virenscanner und zur Reparatur; eine gesperrte Datei führt zu keinem Manifest statt zu
  einem falschen; das Prüfen dauert auf dem Laptop unter 30 s, ohne dass Windows „Keine Rückmeldung“
  meldet.
- **Build-Art:** A oder B für (a) bis (c); (d) und (e) nur B (die Dauer hängt an den echten
  Spieldaten: bei allen Komponenten bis gut 700 MB bei EE und 800 MB bei NeoEE aus dem Setup, dazu
  die heruntergeladenen Sprachdateien).
- **Ausgangszustand:** kein Empire Earth installiert; Microsoft Defender wie im Auslieferungszustand
  (keine eigene Ausnahme für den Spielordner).
- **Snapshot:** `S-Basis` vor (a), (b) und (c), `S-Sandbox` reicht für (a) bis (c); `Laptop` für (d);
  `S-Win7` oder eine VM auf einer HDD für (e).
- **Varianten:** (a) EE-admin und NeoEE-admin, zusätzlich EE-portable; (b) EE-user (dabei auch
  `/VERYSILENT`); (c) EE-user; (d) EE-admin mit allen Komponenten (Weg B, Laptop); (e) EE-admin
  (Weg B, HDD oder Windows-7-VM). EE-user und NeoEE-user schreiben das Manifest mit demselben Code
  wie EE-admin; NeoEE-portable wie EE-portable.
- **Schritte:**
  1. Ordner `C:\EE-Test\logs` anlegen. Bei allen Läufen: Setup mit
     `/LOG="C:\EE-Test\logs\TP-50<Teil>_<Variante>.log"` starten, Spielsprache Deutsch, empfohlene
     Einstellungen mit Empire Earth und AoC, Telemetrie aus (Weg A: Grenzen in
     [6.2](#62-weg-a-placeholder-build)).
  2. (a) EE-admin installieren. Am Ende der Installation erscheint kurz die Seite „Installierte
     Dateien werden geprüft“ mit Fortschrittsbalken und Dateinamen. Danach in PowerShell (Pfad je
     Variante anpassen; NeoEE: `…\Neo Empire Earth` und `_setupdata_NeoEE`; portable:
     `<Ordner des Setups>\Empire Earth Portable`):

     ```powershell
     $root = 'C:\Program Files (x86)\Empire Earth'
     $m = Join-Path $root '_setupdata_EE\files.sha256'
     $b = [IO.File]::ReadAllBytes($m)
     'BOM: ' + ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
     'CR: ' + @($b | Where-Object { $_ -eq 13 }).Count
     'Nicht-ASCII: ' + @($b | Where-Object { $_ -gt 127 }).Count
     $lines = @(Get-Content -LiteralPath $m)
     $paths = @($lines | ForEach-Object { $_.Substring(66) })
     'Zeilen: ' + $lines.Count
     'Form falsch: ' + @($lines | Where-Object { $_ -notmatch '^[0-9a-f]{64}  [^\\:]+$' }).Count
     'Doppelt (ohne Gross-/Kleinschreibung): ' + ($paths.Count - @($paths | Sort-Object -Unique).Count)
     'Setup-Datenordner oder unins*: ' + @($paths | Where-Object { $_ -like '_setupdata_*' -or $_ -like 'unins*' }).Count
     $falsch = foreach ($l in $lines) {
       $p = Join-Path $root ($l.Substring(66) -replace '/', '\')
       if (-not (Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() -ne $l.Substring(0, 64)) { $l.Substring(66) }
     }
     'Hash falsch oder Datei fehlt: ' + @($falsch).Count; $falsch
     Get-ChildItem -Force (Split-Path $m) | Select-Object Name, Length
     Get-Content -LiteralPath (Join-Path $root '_setupdata_EE\install.ini')
     reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v "Empire Earth Community: ContractVersion" /reg:64
     ```

     Dasselbe nach NeoEE-admin (in seinem eigenen Snapshot) und nach EE-portable.
  3. (b) Snapshot zurücksetzen. Vor dem Setup in einer **normalen** PowerShell (EE-user braucht keine
     Administratorrechte) einen „Virenscanner“ starten, der zwei Dateien löscht, sobald das Setup sie
     angelegt hat, und das 15 Minuten lang wiederholt:

     ```powershell
     $spiel = "$env:LOCALAPPDATA\Programs\Empire Earth\Empire Earth"
     $ziele = @("$spiel\Language.dll", "$spiel\help.rtf")
     $ende = (Get-Date).AddMinutes(15)
     while ((Get-Date) -lt $ende) {
       foreach ($z in $ziele) { if (Test-Path -LiteralPath $z) { Remove-Item -LiteralPath $z -Force -ErrorAction SilentlyContinue; if (-not (Test-Path -LiteralPath $z)) { "gelöscht: $z" } } }
       Start-Sleep -Milliseconds 200
     }
     ```

     Beide Dateien gibt es in Weg A und B (`Language.dll` ist die deutsche Sprachdatei, eine Datei mit
     Programmcode, wie sie Virenscanner oft treffen). Dann EE-user installieren („Nur für mich installieren“). Den Hinweis am Ende fotografieren bzw.
     abschreiben, das Setup beenden, die Schleife mit Strg+C stoppen und abfragen:
     `Get-Content "$env:LOCALAPPDATA\Programs\Empire Earth\_setupdata_EE\install.ini"`,
     `Select-String -Path "$env:LOCALAPPDATA\Programs\Empire Earth\_setupdata_EE\files.sha256" -Pattern 'Language.dll|help.rtf'`
     und `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v "Empire Earth Community: ContractVersion"`.
     Danach das Setup noch einmal ohne Schleife ausführen („Vorhandene Installation reparieren“) und
     dieselben Abfragen wiederholen. Zum Schluss mit laufender Schleife (vorher neu starten) noch
     einmal still reparieren: `<Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\EE-Test\logs\TP-50b_silent.log"`.
     Mehr als zehn Dateien (Zeile „und … weitere“, nur Weg B): statt der zwei Dateien alle Dateien
     eines Ordners löschen, also in der Schleife die `foreach`-Zeile durch
     `Get-ChildItem -LiteralPath "$spiel\Users\default\Civilizations" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue`
     ersetzen (Komponente mit den eC-Zivilisationen gewählt, 15 Dateien).
  4. (c) Snapshot zurücksetzen. Eine PowerShell starten, die `Empire Earth\EULA_DSML.txt` (eine Datei,
     die nur der erste Eintrag des Setups kopiert) zwei Sekunden nach ihrem Erscheinen ohne Freigabe
     öffnet und bis zum Ende des Setups offen hält, wie ein Virenscanner, der eine Datei länger prüft:

     ```powershell
     $z = "$env:LOCALAPPDATA\Programs\Empire Earth\Empire Earth\EULA_DSML.txt"
     while (-not (Test-Path -LiteralPath $z)) { Start-Sleep -Milliseconds 100 }
     Start-Sleep -Seconds 2
     $f = [IO.File]::Open($z, 'Open', 'Read', 'None'); 'gesperrt'
     ```

     EE-user installieren; erst nach dem Ende des Setups `$f.Close()`. Abfragen wie in (b), dazu `Test-Path "$env:LOCALAPPDATA\Programs\Empire Earth\_setupdata_EE\files.sha256"`.
     Danach ohne Sperre reparieren und noch einmal abfragen. Meldet das Setup schon beim Kopieren,
     dass die Datei verwendet wird, war die Sperre zu früh: „Wiederholen“ nach `$f.Close()` wählen und
     den Teil mit einer längeren Pause wiederholen.
  5. (d) Nur Weg B, auf dem Laptop: EE-admin mit „Benutzerdefinierte Installation“ und allen
     Komponenten (HD-Pakete, Filme, Zivilisationen, Werkzeuge) installieren. Während
     die Seite „Installierte Dateien werden geprüft“ zu sehen ist, auf die Titelleiste achten und die
     Zeit mit der Uhr stoppen; danach im Log die Zeile `Manifest: …` suchen:
     `Select-String -Path C:\EE-Test\logs\TP-50d_EE-admin.log -Pattern 'Manifest:'`. Die Abfrage aus
     (a) läuft auf dem Laptop gegen alle Dateien (sie braucht selbst etwa so lange wie das Setup).
  6. (e) Nur Weg B, auf einer HDD oder in der Windows-7-VM (`S-Win7`): wie (d), nur Zeit und Logzeile
     notieren.
- **Erwartetes Ergebnis:**
  - (a) `BOM: False`, `CR: 0`, `Nicht-ASCII: 0`, `Form falsch: 0`, `Doppelt …: 0`,
    `Setup-Datenordner oder unins*: 0`, `Hash falsch oder Datei fehlt: 0`. Die Zeilen sind nach dem
    Pfad sortiert (ohne Groß-/Kleinschreibung; `Empire Earth - The Art of Conquest/…` vor
    `Empire Earth/…`, `Tools/…` zuletzt), jede Datei steht einmal, auch `Empire Earth.exe` bei NeoEE
    (dort mit dem Hash der Admin-Version aus `NeoEE - Admin`). Im Ordner `_setupdata_EE` liegen
    `EEStatsSetup.dll`, `files.sha256` und `install.ini`, keine `.tmp`-Datei; `install.ini` hat keinen
    Abschnitt `[MissingAfterInstall]`; der Uninstall-Schlüssel hat
    `Empire Earth Community: ContractVersion    REG_DWORD    0x1` (portable: kein Uninstall-Schlüssel,
    das Manifest gibt es trotzdem).
  - (b) Die Schleife meldet beide Dateien als gelöscht. Am Ende erscheint ein Hinweis (Fehlersymbol):
    „Einige installierte Dateien fehlten am Ende der Installation:“ mit den zwei Dateien
    (`Empire Earth\help.rtf`, `Empire Earth\Language.dll`, mit `\`), dem Satz zu
    Antivirenprogrammen, dem Installationsordner und dem Rat, danach das Setup erneut für denselben
    Ordner auszuführen. Das Setup endet normal. `install.ini` endet mit einer Leerzeile und
    `[MissingAfterInstall]`, `1=Empire Earth/help.rtf`, `2=Empire Earth/Language.dll`;
    `files.sha256` nennt die beiden Dateien nicht; der Wert im
    Uninstall-Schlüssel ist da (fehlende Dateien verhindern ihn nicht, der Launcher wertet
    `[MissingAfterInstall]` aus). Nach der Reparatur ohne Schleife: kein Hinweis, kein
    `[MissingAfterInstall]`, beide Dateien stehen wieder im Manifest. Still mit Schleife: kein Fenster,
    die Dateien stehen in `install.ini` und im Log. Mit mehr als zehn Dateien zeigt der Hinweis zehn
    Namen und die Zeile „und <Anzahl> weitere“.
  - (c) Das Setup endet ohne Meldung. `files.sha256` gibt es **nicht** (`Test-Path`: `False`),
    `install.ini` gibt es; der Uninstall-Schlüssel hat **keinen** Wert
    `Empire Earth Community: ContractVersion` (der Launcher meldet dann „Unbekannt“ und rät zur
    Reparatur). Nach der Reparatur ohne Sperre sind Manifest und Wert wieder da.
  - (d) Die Seite „Installierte Dateien werden geprüft“ zeigt den Fortschritt, die Titelleiste nie
    „(Keine Rückmeldung)“, und das Prüfen dauert unter 30 s (`<ms>` der Logzeile unter 30000). Die
    Logzeile nennt die Anzahl der Dateien, die Größe (bei allen Komponenten einige hundert MB) und
    den Durchsatz; alle Werte ins Protokoll.
  - (e) Zeit und Logzeile im Protokoll; mehr als 60 s oder „Keine Rückmeldung“ als Abweichung melden
    (dann entscheiden die Betreuer über den Rückfall aus ADR 0004, „Consequences“: nur die Dateien der
    Klasse `code` hashen).
- **Log-Hinweis:** Bei `ssInstall`: `Install state of the previous run deleted (or there was none):
  …\install.ini, …\files.sha256`. Am Ende: `Checking <n> recorded destinations of installed files for
  …\files.sha256`, `Manifest: <n> files, <MB> MB, <ms> ms, <MB/s> MB/s`,
  `Wrote …\files.sha256 (<n> files, <k> missing)`, `Wrote …\install.ini (…)` und
  `Wrote "Empire Earth Community: ContractVersion" = 1 into the uninstall key`. (b): je Datei
  `Installed file missing after the installation (deleted or moved, e.g. by an antivirus program): …`
  und `2 installed files were missing at the end of the installation, listed in
  [MissingAfterInstall] of install.ini …`. (c): dreimal `Unable to hash …\EULA_DSML.txt (attempt
  <i> of 3): …` (je etwa 300 ms auseinander), dann `No manifest in this run: unable to hash … after 3
  attempts: …`, `Not writing …\files.sha256: the manifest of this run is not complete (see above)` und
  `Not writing "Empire Earth Community: ContractVersion" into the uninstall key: install.ini or
  files.sha256 of this run could not be written; …`.

### Block 6: Umgebung (S-WP8)

Was ADR 0007 verlangt und nur auf Windows prüfbar ist: der Hinweis `LowScreenResolution` bei einer
Bildschirmhöhe unter 768 Pixeln und die Zeile mit Bildschirmgröße, DPI und Spielfenster in jedem
Log (TP-60); beim Verlassen der Ordnerseite einmal je Lauf der Hinweis `ForeignInstallFound` auf
Schlüssel alter oder fremder Installationen in HKLM (beide Registry-Ansichten), fremde
Uninstall-Einträge und den Ordner der CD-Version, mit dem Rat, keine Registry-Schlüssel von Hand zu
löschen (TP-61); die Fragen `SharedFolderQuestion` (der andere Community-Setup im gewählten Ordner,
TP-62) und `ForeignFolderQuestion` (der Ordner einer fremden Installation, TP-63), beide mit „Ja“ =
anderen Ordner wählen als Vorgabe. Alle Prüfungen lesen nur; still (`/VERYSILENT`, `/SILENT`) und
mit `/SUPPRESSMSGBOXES` erscheint nichts, das Log nennt jeden Fund, und die Installation läuft
weiter. Bei einem Update überspringt Inno Setup die Ordnerseite und damit diese Prüfungen.
Die Logik prüfen zusätzlich die Unit-Tests (Fenstergröße, Ordnervergleich, Uninstall-Einträge) und
eine Wine-Probe der Analyse in einem 64- und einem 32-Bit-Präfix (ADR 0007, „Implementation“).

Die Fälle legen Schlüssel und Einträge mit `reg add` in einer **Administrator**-Eingabeaufforderung
an und entfernen sie danach wieder mit `reg delete`. Nur die hier genannten Testschlüssel löschen,
nie `Software\Sierra` oder einen Teil davon (Regel 3). Ein Wert, der mit `\` endet, braucht vor dem
schließenden Anführungszeichen `\\` (sonst liest `reg.exe` das Zeichen als Anführungszeichen); die
Befehle unten lassen den abschließenden `\` deshalb weg.

#### TP-60: Niedrige Bildschirmauflösung

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** R13, ADR 0007 (Punkt 1), Vertrag 3.3 und O4, Entscheidung K13 der Planrevision; Forum
  §8 Nr. 6 (t=3863 p=26167: Netbook mit 1024 × 600, Absturz nach dem Intro; t=5831 p=39111:
  2560 × 1600 startet nicht)
- **Ziel:** Unter 768 Pixeln Bildschirmhöhe zeigt das Setup den Hinweis `LowScreenResolution` (nicht
  im Silent-Modus), die Fenstergröße bleibt auf 1024 bis 1920 mal 768 bis 1080 begrenzt, und jedes
  Log nennt Bildschirmgröße, DPI und Spielfenster.
- **Build-Art:** A oder B (Schritt 6 nur B)
- **Ausgangszustand:** kein Empire Earth installiert; eine VM, deren Auflösung sich frei einstellen
  lässt. 1024 × 600 bietet Windows in *Einstellungen › System › Anzeige* meist nicht an:
  VirtualBox `VBoxManage controlvm <VM> setvideomodehint 1024 600 32`, Hyper-V *Ansicht ›
  Bildschirmauflösung* bzw. `Set-VMVideo -VMName <VM> -HorizontalResolution 1024 -VerticalResolution 600 -ResolutionType Single`
  (VM aus); sonst 800 × 600.
- **Snapshot:** `S-Basis` (oder `S-Sandbox` für (a) bis (c)); `Laptop` für (d) mit Weg B
- **Varianten:** (a) EE-admin bei 1024 × 600 (oder 800 × 600), (b) EE-admin bei 1366 × 768, (c)
  EE-user still bei 1024 × 600, (d) EE-admin auf einem Bildschirm über 1920 × 1080 oder mit 150 %
  Skalierung. NeoEE und portable nutzen denselben Code (`environment.iss`) und werden nicht wiederholt.
- **Schritte:**
  1. (a) Auflösung 1024 × 600 einstellen. Setup mit
     `/LOG="C:\EE-Test\logs\TP-60a_EE-admin.log"` starten, Sprache Deutsch. Nach der Rechtsfrage und
     der Warnung des Testbuilds (bei „Nur für mich installieren“ auch nach dem Hinweis zum
     Benutzermodus), vor dem Assistenten, erscheint der Hinweis: abfotografieren, „OK“, normal
     installieren (Telemetrie aus).
  2. Abfragen:

     ```bat
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Game Window Width"
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Game Window Height"
     reg query "HKCU\Software\Mad Doc Software\EE-AOC" /v "Game Window Height"
     findstr /c:"Screen:" /c:"lower than" /c:"LowScreenResolution" C:\EE-Test\logs\TP-60a_EE-admin.log
     ```

     (hexadezimal: `0x400` = 1024, `0x300` = 768, `0x556` = 1366, `0x780` = 1920, `0x438` = 1080).
  3. (b) Snapshot zurücksetzen, Auflösung 1366 × 768, Setup mit `TP-60b` im Log-Namen, Abfragen
     wie in Schritt 2.
  4. (c) Snapshot zurücksetzen, 1024 × 600:
     `<Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /LOG="C:\EE-Test\logs\TP-60c_EE-user.log"`,
     danach Schritt 2 mit `TP-60c_EE-user.log`.
  5. (d) Auf dem Laptop (Weg B) oder einer VM mit 2560 × 1440 bzw. mit 150 % Skalierung (dann wie
     [TP-24](#tp-24-150--anzeigeskalierung-mit-und-ohne-aufgabe-compatibility)): Setup mit `TP-60d`,
     Schritt 2.
  6. Nur Weg B: nach (a) Empire Earth starten und notieren, ob das Hauptmenü passt oder abgeschnitten
     ist und ob das Spiel nach dem Intro abstürzt; nach (d) prüfen, ob das Spiel mit 1920 × 1080
     startet, dann im Spiel eine höhere Auflösung wählen (falls angeboten) und notieren, ob es
     abstürzt (Forum §8 Nr. 6: die Begrenzung schützt nur den ersten Start). Beides sind Befunde.
- **Erwartetes Ergebnis:**
  - (a) Hinweis (Infosymbol): „Ihr Bildschirm hat 1024 x 600 Pixel. Die Menüs von Empire Earth
    brauchen einen Bildschirm mit mindestens 768 Pixeln Höhe, daher stellt das Setup das
    Spielfenster auf 1024 x 768 Pixel: …“ mit dem Rat zur Skalierung im Grafiktreiber oder zu einem
    DirectX-Wrapper; danach läuft die Installation normal weiter. `Game Window Width` `0x400`,
    `Game Window Height` `0x300`, für EE und AoC. Bei 800 × 600 dieselben Werte.
  - (b) Kein Hinweis; `0x556` und `0x300`.
  - (c) Kein Fenster, Installation vollständig, Werte wie (a).
  - (d) `0x780` und `0x438`; bei 150 % ist die Breite die physische (siehe TP-24).
  - Jedes Log hat genau eine Zeile `Screen: …`, deren Spielfenster den Registry-Werten entspricht.
- **Log-Hinweis:** (a) `Screen: 1024 x 600 pixels (primary screen, SM_CXSCREEN x SM_CYSCREEN), 96 DPI
  (LOGPIXELSX, 100 % scaling), game window 1024 x 768` und `The screen is lower than 768 pixels
  (1024 x 600): the game window is set to 1024 x 768, the menus may not fit (notice
  LowScreenResolution)`; (c) zusätzlich `Notice LowScreenResolution not shown (silent installation or
  /SUPPRESSMSGBOXES)`; (b) nur die Zeile `Screen: 1366 x 768 pixels …, game window 1366 x 768`.

#### TP-61: Alte Installation vorhanden

- **Status:** ausgearbeitet
- **Priorität:** P1 (Teile a bis c mit `reg add`, je wenige Minuten in der Windows-Sandbox, weil
  der Hinweis die NeoEE-CD-Keys nennt und vor jeder Freigabe stimmen muss; Teil d mit einer echten
  CD- oder GOG-Installation: P3; Teil e: P2)
- **Bezug:** R12, ADR 0007 (Punkt 2), Entscheidungen K3 und K15 der Planrevision, Vertrag 0
  (Herausgeber) und 1.4; Forum §8 Nr. 8 (t=1036 p=4756, t=12082 p=49553), Bericht 4.7 und 4.8
  (t=2847 p=19589: verwaiste Einträge, Setups bieten nur „Reparieren/Entfernen“), t=10577 p=46302
  (der störende Schlüssel lag „in a "Neo" directory“), Bericht 4.19 (t=10950, t=11021: CD-Keys weg
  nach Löschen von `Software\Sierra`)
- **Ziel:** Das Setup meldet Schlüssel alter Installationen in HKLM (auch alte NeoEE-Schlüssel),
  fremde Uninstall-Einträge und den Ordner der CD-Version einmal je Lauf, rät davon ab,
  Registry-Schlüssel von Hand zu löschen, nennt die NeoEE-CD-Keys und den Launcher, ändert nichts
  und meldet keine Community-Installationen.
- **Build-Art:** A oder B (Teil e nur B)
- **Ausgangszustand:** (a) bis (c): kein Empire Earth installiert, keine Schlüssel
  `HKLM\SOFTWARE\SSSI`, `HKLM\SOFTWARE\Mad Doc Software`, `HKLM\SOFTWARE\Neo` (in beiden Ansichten:
  `/reg:32` und `/reg:64`). (d): eine echte alte Installation (Original-CD unter
  `C:\Sierra\Empire Earth` oder die GOG-Version). (e): Internet für die CD-Keys.
- **Snapshot:** `S-Sandbox` oder `S-Basis` für (a) bis (c), `S-Basis` für (e), `S-Alt` für (d)
- **Varianten:** (a) EE-admin, (b) EE-admin, (c) NeoEE-user, sichtbar und still (HKLM wird auch
  ohne Administratorrechte gelesen), (d) EE-admin, (e) NeoEE-admin mit CD-Keys, danach EE-admin.
  Portable nutzt denselben Code.
- **Schritte:**
  1. (a) In einer Administrator-Eingabeaufforderung einen alten NeoEE-Schlüssel (32-Bit-Ansicht, wie
     das alte NeoEE-Installationsprogramm), einen fremden Uninstall-Eintrag (wie GOG) und den Ordner
     der CD-Version anlegen:

     ```bat
     reg add "HKLM\SOFTWARE\Neo\Empire Earth" /reg:32 /v "Installed From Volume" /d "C:" /f
     reg add "HKLM\SOFTWARE\Neo\Empire Earth" /reg:32 /v "Installed From Directory" /d "\SIERRA\EMPIRE EARTH" /f
     reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-GOG" /reg:32 /v DisplayName /d "Empire Earth Gold Edition" /f
     reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-GOG" /reg:32 /v Publisher /d "GOG.com" /f
     reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-GOG" /reg:32 /v InstallLocation /d "C:\GOG Games\Empire Earth Gold" /f
     mkdir "C:\Sierra\Empire Earth"
     ```

     Dann EE-admin mit `/LOG="C:\EE-Test\logs\TP-61a_EE-admin.log"` starten (Sprache Deutsch), auf
     der Ordnerseite den Standardordner lassen und „Weiter“: der Hinweis erscheint, abfotografieren,
     „OK“. Mit „Zurück“ auf die Ordnerseite und wieder „Weiter“: kein zweiter Hinweis. Installieren.
  2. Prüfen, dass das Setup nichts geändert hat:
     `reg query "HKLM\SOFTWARE\Neo\Empire Earth" /reg:32`,
     `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-GOG" /reg:32`,
     `dir "C:\Sierra"`.
  3. (b) Snapshot zurücksetzen (bzw. EE deinstallieren und die Testeinträge aus Schritt 5
     entfernen; ohne Deinstallation überspringt das Setup die Ordnerseite). Nur Einträge, die
     **nicht** gemeldet werden dürfen: eine Community-Installation mit fremder AppId (Herausgeber der
     Community) und Empire Earth II (ein anderes Spiel):

     ```bat
     reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-Community" /reg:32 /v DisplayName /d "Empire Earth v2.0.0.0 - Setup v1.7.2" /f
     reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-Community" /reg:32 /v Publisher /d "Empire Earth Community" /f
     reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-EE2" /reg:32 /v DisplayName /d "Empire Earth II" /f
     reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-EE2" /reg:32 /v Publisher /d "Sierra Entertainment" /f
     ```

     EE-admin mit `TP-61b` im Log-Namen installieren (es genügt, bis nach der Ordnerseite zu gehen:
     die Prüfung läuft beim Verlassen der Ordnerseite; danach abbrechen).
  4. (c) Die Einträge aus Schritt 1 wieder anlegen. NeoEE-user („Nur für mich installieren“) mit
     `TP-61c` im Log-Namen bis zur Ordnerseite und „Weiter“, dann abbrechen; danach still:
     `<NeoEE-Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /LOG="C:\EE-Test\logs\TP-61c_NeoEE-user-silent.log"`.
  5. Aufräumen (nur die Testeinträge, nie `Software\Sierra`):

     ```bat
     reg delete "HKLM\SOFTWARE\Neo\Empire Earth" /reg:32 /f
     reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-GOG" /reg:32 /f
     reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-Community" /reg:32 /f
     reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-EE2" /reg:32 /f
     rmdir "C:\Sierra\Empire Earth" & rmdir "C:\Sierra"
     ```

     (`HKLM\SOFTWARE\Neo` bleibt als leerer Schlüssel stehen, wenn er vorher nicht da war:
     `reg delete "HKLM\SOFTWARE\Neo" /reg:32 /f` nur dann.)
  6. (d) Auf `S-Alt` EE-admin installieren (Standardordner). Welche Zeilen der Hinweis zeigt, ins
     Protokoll; danach die alte Installation einmal starten (sie muss unverändert laufen).
  7. (e) Fehlalarm-Probe zu K3: NeoEE-admin mit der Aufgabe „NeoEE-CD-Keys registrieren“ installieren
     (Weg B, Netz nötig), dann `reg query "HKLM\SOFTWARE\Neo" /s /reg:32` und
     `reg query "HKLM\SOFTWARE\Neo" /s /reg:64`; danach EE-admin in seinen eigenen Standardordner
     installieren (`TP-61e` im Log-Namen).
- **Erwartetes Ergebnis:**
  - (a) Nach „Weiter“ auf der Ordnerseite genau ein Hinweis (Infosymbol): „Das Setup hat Spuren einer
    anderen Empire-Earth-Installation auf diesem Computer gefunden, zum Beispiel der Original-CD, von
    GOG oder eines älteren NeoEE-Installationsprogramms:“ mit den Zeilen
    `HKLM\Software\WOW6432Node\Neo\Empire Earth: C:\SIERRA\EMPIRE EARTH` (32-Bit-Windows: ohne
    `WOW6432Node`) und `Empire Earth Gold Edition: C:\GOG Games\Empire Earth Gold`, dann „Das
    Community-Setup installiert eine eigene Kopie und ändert nichts an der anderen Installation. …“
    und wörtlich: „Bitte keine Registry-Schlüssel von Hand löschen; Software\Sierra\CDKeys enthält
    die NeoEE-CD-Keys. Der Empire Earth Launcher bietet eine Bereinigung mit Sicherung an.“ Keine
    Frage (der Standardordner gehört keiner fremden Installation). Kein zweiter Hinweis nach
    „Zurück“/„Weiter“. Schritt 2: Schlüssel, Eintrag und Ordner unverändert.
  - (b) Kein Hinweis.
  - (c) Derselbe Hinweis wie (a), auch ohne Administratorrechte; still kein Fenster, die Installation
    läuft durch.
  - (d) Der Hinweis nennt die echte alte Installation (Befund: welche Zeilen); sie läuft danach
    unverändert.
  - (e) `HKLM\SOFTWARE\Neo` gibt es in keiner Ansicht, und EE-admin zeigt keinen Hinweis. Findet
    sich doch ein `Neo`-Schlüssel (dann vermutlich von `authtools.dll`, Vertrag O8), ist das ein
    Befund: die Prüfung braucht eine Ausnahme, bevor das Setup freigegeben wird.
- **Log-Hinweis:** `Checking the chosen folder …`, je Fund eine Zeile `Foreign or old installation:
  registry key HKLM\Software\WOW6432Node\Neo\Empire Earth: C:\SIERRA\EMPIRE EARTH`, `Foreign or old
  installation: folder C:\Sierra\Empire Earth (already named by a registry key above)` und `Foreign
  or old installation: uninstall entry HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EE-Test-GOG,
  DisplayName "Empire Earth Gold Edition", Publisher "GOG.com", InstallLocation "C:\GOG Games\Empire
  Earth Gold"`, dann `Checked <n> uninstall entries of HKLM in <ms> ms` (Anzahl und Dauer ins
  Protokoll) und `2 traces of foreign or old installations found, 1 of their folders exist (notice
  ForeignInstallFound)`; still zusätzlich `Notice ForeignInstallFound not shown (silent installation
  or /SUPPRESSMSGBOXES)`. (b) und (e): `No foreign or old installation of Empire Earth found`.

#### TP-62: EE und NeoEE im selben Ordner

- **Status:** ausgearbeitet
- **Priorität:** P2 (Teil d mit dem offiziellen Setup 1.7.2: P3)
- **Bezug:** ADR 0007 (Punkt 3), Vertrag O11 und 1.4 (zwei Produkte in einer Wurzel); Forum §8
  Nr. 9 (t=4723 p=33045: Parallelinstallationen, getrennte Ordner)
- **Ziel:** Wer EE und NeoEE in denselben Ordner installieren will, bekommt die Frage
  `SharedFolderQuestion` mit „Ja“ = anderen Ordner wählen als Vorgabe; „Ja“ bleibt auf der
  Ordnerseite, „Nein“ installiert; die genannten Folgen (Deinstallation, Firewall-Regeln) treten ein.
- **Build-Art:** A oder B (Teil d A+ mit beiden offiziellen AppIds oder B)
- **Ausgangszustand:** (a) bis (c): kein Empire Earth installiert. (d): offizielles NeoEE-Setup 1.7.2
  installiert.
- **Snapshot:** `S-Basis` (oder `S-Sandbox`) für (a) bis (c), `S-172-NeoEE` für (d)
- **Varianten:** (a) EE-admin, dann NeoEE-admin in denselben Ordner; (b) EE-portable, dann
  NeoEE-portable in denselben Ordner; (c) wie (a) still; (d) EE-admin dieses Testbuilds in den
  Ordner der NeoEE-1.7.2-Installation.
- **Schritte:**
  1. (a) EE-admin im Standardordner `C:\Program Files (x86)\Empire Earth` installieren, mit
     „Firewall-Ausnahme“. Dann NeoEE-admin mit `/LOG="C:\EE-Test\logs\TP-62a_NeoEE-admin.log"`
     starten, auf der Ordnerseite `C:\Program Files (x86)\Empire Earth` eintragen, „Weiter“: die
     Frage erscheint, abfotografieren, mit Enter beantworten („Ja“ ist vorgewählt). Erneut „Weiter“,
     diesmal „Nein“, installieren (mit „Firewall-Ausnahme“).
  2. Folgen ansehen: `dir /a "C:\Program Files (x86)\Empire Earth"` (beide `_setupdata_…`-Ordner und
     zwei Deinstallationsprogramme, `unins000` und `unins001`);
     `netsh advfirewall firewall show rule name=all | findstr /i /c:"Empire Earth"` notieren.
     NeoEE deinstallieren (*Einstellungen › Apps*), dann
     `dir "C:\Program Files (x86)\Empire Earth\Empire Earth\Empire Earth.exe"` und die
     `netsh`-Zeile wiederholen.
  3. (b) Snapshot zurücksetzen. EE-portable nach `C:\EE-Test\Gemeinsam` installieren, dann
     NeoEE-portable mit `TP-62b` im Log-Namen auf denselben Ordner: Frage, „Nein“, installieren.
  4. (c) Snapshot zurücksetzen, EE-admin wie in (a), dann
     `<NeoEE-Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /DIR="C:\Program Files (x86)\Empire Earth" /LOG="C:\EE-Test\logs\TP-62c_NeoEE-admin.log"`.
  5. (d) Nur Weg A+ (mit beiden offiziellen AppIds gebaut) oder B, auf `S-172-NeoEE`: EE-admin
     dieses Testbuilds starten und den Ordner der
     NeoEE-Installation (`C:\Program Files (x86)\Neo Empire Earth`) eintragen, „Weiter“, „Ja“.
- **Erwartetes Ergebnis:**
  - (a) Frage (Fragezeichen-Symbol): „Der gewählte Ordner enthält bereits Empire Earth, installiert
    vom anderen Community-Setup: …“ mit den Folgen (der Launcher kann die installierten Dateien
    nicht mehr prüfen, die Deinstallation des einen entfernt auch Dateien und die Firewall-Regeln
    des anderen) und „Möchten Sie einen anderen Ordner wählen (empfohlen)?“. „Ja“ ist vorgewählt
    und lässt die Ordnerseite stehen; „Nein“ installiert. Nach der Deinstallation von NeoEE fehlt
    `Empire Earth.exe` (oder ist nicht mehr die EE-Version) und die Firewall-Regeln für
    `…\Empire Earth\Empire Earth.exe` sind weg: genau die Folgen, die die Frage nennt.
  - (b) Dieselbe Frage (gefunden über `_setupdata_EE`).
  - (c) Kein Fenster, die Installation läuft durch.
  - (d) Dieselbe Frage mit „NeoEE“ (1.7.2 hat noch keinen Ordner `_setupdata_NeoEE`; gefunden über
    seinen Setup-Datenordner `<AppId>` oder `Inno Setup: App Path` seines Uninstall-Schlüssels).
- **Log-Hinweis:** (a) `The folder C:\Program Files (x86)\Empire Earth already holds Empire Earth:
  C:\Program Files (x86)\Empire Earth\_setupdata_EE exists (question SharedFolderQuestion)`,
  `SharedFolderQuestion: Yes, the user chooses another folder`, beim zweiten Mal `SharedFolderQuestion:
  No, the user installs into this folder anyway`; (c) `Question SharedFolderQuestion not asked (silent
  installation or /SUPPRESSMSGBOXES), the installation continues`; (d) `… already holds NeoEE: …\<AppId>
  (setup data folder of a setup up to 1.7.2) exists …` (oder `the uninstall key of the other product
  names it as Inno Setup: App Path`).

#### TP-63: Installation in den Ordner einer GOG- oder CD-Installation

- **Status:** ausgearbeitet
- **Priorität:** P2 (Teil b mit einer echten GOG-Installation: P3)
- **Bezug:** R12, ADR 0007 (Punkt 4); Forum §8 Nr. 21 (t=5733: AoC nicht erkannt, t=5727 und
  t=12082: Absturz nach dem Startbild der GOG-Version), t=5825 p=39087 (Spiel nach
  `X:\Sierra\Empire Earth` kopiert, damit ein Installationsprogramm es findet)
- **Ziel:** Wer in den Ordner einer fremden Installation installieren will, bekommt die Frage
  `ForeignFolderQuestion` mit „anderen Ordner wählen“ als Vorgabe; `C:\Sierra2` gilt nicht als Teil
  von `C:\Sierra`; in einem eigenen Ordner laufen GOG- und Community-Version nebeneinander.
- **Build-Art:** A oder B (Teil b nur B)
- **Ausgangszustand:** (a) und (c): die Einträge aus [TP-61](#tp-61-alte-installation-vorhanden)
  Schritt 1, dazu `mkdir "C:\GOG Games\Empire Earth Gold"` und `mkdir C:\Sierra2`. (b): eine echte
  GOG-Installation.
- **Snapshot:** `S-Sandbox` oder `S-Basis` für (a) und (c), `S-Alt` mit GOG-Version für (b)
- **Varianten:** (a) EE-admin, (b) EE-admin, (c) EE-admin still. NeoEE nutzt denselben Code.
- **Schritte:**
  1. (a) EE-admin mit `/LOG="C:\EE-Test\logs\TP-63a_EE-admin.log"` starten, auf der Ordnerseite
     `C:\Sierra` eintragen, „Weiter“: nach dem Hinweis aus TP-61 kommt die Frage; mit Enter („Ja“)
     beantworten. Dann `C:\Sierra2` eintragen, „Weiter“: keine Frage, mit „Zurück“ zurück zur
     Ordnerseite. Dann `C:\GOG Games\Empire Earth Gold` eintragen, „Weiter“: Frage, „Nein“,
     installieren. Danach `dir "C:\GOG Games\Empire Earth Gold"`.
  2. (b) Nur Weg B, auf `S-Alt` mit der GOG-Version: auf der Ordnerseite den GOG-Ordner eintragen,
     „Weiter“: Frage, „Ja“; dann den Standardordner lassen und installieren. Die GOG-Version und die
     Community-Version abwechselnd starten (EE und AoC) und notieren, welche Installation AoC startet.
  3. (c) `<Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /DIR="C:\Sierra" /LOG="C:\EE-Test\logs\TP-63c_EE-admin.log"`.
  4. Aufräumen wie in TP-61 Schritt 5, dazu `rmdir C:\Sierra2` und den Ordner `C:\GOG Games` (nur
     wenn er für diesen Test angelegt wurde) und die Testinstallation deinstallieren.
- **Erwartetes Ergebnis:**
  - (a) Bei `C:\Sierra`: Frage (Fragezeichen-Symbol) „Der gewählte Ordner gehört zu einer anderen
    Empire-Earth-Installation (zum Beispiel der Original-CD oder von GOG): C:\SIERRA\EMPIRE EARTH …“
    mit „Ja: zurück zur Ordnerauswahl. Nein: trotzdem in C:\Sierra installieren.“; „Ja“ ist
    vorgewählt und lässt die Ordnerseite stehen. Bei `C:\Sierra2` keine Frage. Beim GOG-Ordner
    dieselbe Frage mit `C:\GOG Games\Empire Earth Gold` (aus `InstallLocation`); nach „Nein“ liegt
    `Empire Earth` im GOG-Ordner.
  - (b) Die Frage erscheint; im eigenen Ordner installiert, starten beide Versionen (Befund: welche
    Installation AoC startet, Absturz nach dem Startbild ja/nein, fehlende Menütexte ja/nein).
  - (c) Kein Fenster, die Installation läuft durch.
- **Log-Hinweis:** `The game folders in C:\Sierra would be, contain or lie in the folder of a foreign
  or old installation: C:\SIERRA\EMPIRE EARTH (question ForeignFolderQuestion)`, `ForeignFolderQuestion:
  Yes, the user chooses another folder`, `ForeignFolderQuestion: No, the user installs into this folder
  anyway`; dazwischen für `C:\Sierra2` nur `Checking the chosen folder C:\Sierra2`, ohne Frage; (c)
  `Question ForeignFolderQuestion not asked (silent installation or /SUPPRESSMSGBOXES), the
  installation continues`.

### Block 7: Allgemeine Abläufe und Forumfälle

Fälle, die nicht zu einem Arbeitspaket gehören: der Grundablauf (TP-70, Grundlage aller anderen
Fälle) und die Testfälle für echtes Windows aus der Forumsstudie, die kein anderer Block abdeckt
(Zuordnung in [Abschnitt 9](#9-forum-testfälle-8)). Viele brauchen das laufende Spiel und damit
Weg B; ohne Daten der Maintainer bleiben von ihnen die Teile mit Weg A bzw. A+, der Rest kommt als
„nicht durchgeführt: keine Daten“ ins Protokoll. Abfragen von `Software\Sierra\CDKeys` prüfen
nur, ob es den Schlüssel gibt, nie seine Werte (Regel 3).

#### TP-70: Grundablauf: installieren, starten, deinstallieren

- **Status:** ausgearbeitet
- **Priorität:** P1 (a mit EE-admin, NeoEE-admin, EE-user und EE-portable, b mit EE-admin; a mit
  NeoEE-user und NeoEE-portable und b mit NeoEE: P2)
- **Bezug:** Grundlage aller anderen Fälle; README „Build switches“ (`TestID`); Vertrag 1.3
  (Uninstall-Schlüssel); Forum §8 Nr. 2 (Version, nur Startbild)
- **Ziel:** Ein Testbuild installiert sich vollständig, das Spiel startet (Weg B), und die
  Deinstallation räumt auf. Jeder andere Fall setzt voraus, dass dieser besteht.
- **Build-Art:** (a) A oder B, (b) A+ oder B (Schritt 6 nur B)
- **Ausgangszustand:** (a) Erstinstallation: kein Empire Earth installiert. (b) Update: offizielles
  Setup 1.7.2 desselben Produkts als Administrator installiert.
- **Snapshot:** (a) `S-Basis` oder `S-Sandbox` (nur Weg A); (b) `S-172-EE` bzw. `S-172-NeoEE`, für
  Weg A+ auch die Sandbox mit dem Setup 1.7.2 ([Abschnitt 5](#5-testumgebungen-und-snapshots)). Auf
  dem `Laptop` nur Weg B und nur mit Wiederherstellungspunkt.
- **Varianten:** EE-admin und NeoEE-admin (a und b), EE-user und NeoEE-user (a), EE-portable und
  NeoEE-portable (a; ohne Deinstallation, Schritt 7 entfällt).
- **Schritte:**
  1. Ordner `C:\EE-Test\logs` anlegen, das Setup der Variante in die VM kopieren.
  2. Setup starten:
     `EE_Setup_v1.7.2.exe /LOG="C:\EE-Test\logs\TP-70_EE-admin.log"` (Variante im Namen anpassen).
     Bei „user“ im ersten Dialog („Für alle Benutzer installieren“ / „Nur für mich installieren“)
     „Nur für mich installieren“ wählen oder `/CURRENTUSER` anhängen.
  3. Die Testwarnung mit OK bestätigen, bei (a) die Rechtsfrage mit „Ja“ beantworten, bei
     „portable“ die Frage zum portablen Modus mit „Ja“.
  4. Assistent: Spielsprache „Deutsch“; Installationsmodus bei (a) „Empfohlene Einstellungen“ mit
     „Installiere Empire Earth und Die Kunst der Eroberungen - Erweiterung“, bei (b) die angebotene
     Option für die vorhandene Installation („Aktuelle Installation aktualisieren“ bzw.
     „Vorhandene Installation reparieren“), jeweils mit abgewählter Telemetrie-Zustimmung;
     Grafikkarte wie vorgeschlagen, Zielordner unverändert, installieren, „Fertigstellen“. Bei Weg A
     ist die Meldung zu `dxwebsetup.exe` erwartet ([6.2](#62-weg-a-placeholder-build)); wer sie
     vermeiden will, nimmt die benutzerdefinierten Einstellungen und wählt dort die Aufgabe
     „DirectX-Endbenutzer-Runtime installieren“ ab. Bei (b) mit Weg A+ (das Setup aus `out\aplus`)
     zeigt die Reparatur keine Aufgabenseite: dort beim Start `/MERGETASKS="!dxwebsetup"` anhängen.
  5. Prüfen (Eingabeaufforderung):
     `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v DisplayName /reg:64`
     (bei „user“ `HKCU\Software\…` ohne `/reg:64`; bei Weg A die Platzhalter-AppId), und im
     Explorer den Spielordner mit `Empire Earth\Empire Earth.exe`,
     `Empire Earth - The Art of Conquest\EE-AOC.exe` und dem versteckten Ordner
     `_setupdata_EE` bzw. `_setupdata_NeoEE`. Bei (b) zusätzlich
     `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v "Empire Earth Community: ContractVersion" /reg:64`,
     `reg query "HKLM\SOFTWARE\Empire Earth Community\Installations\EE" /v InstallPath /reg:64`
     (NeoEE: `…\Installations\NeoEE`) und `dir /a "<Installationsordner>"`.
  6. Nur Weg B: Empire Earth und The Art of Conquest je einmal bis ins Hauptmenü starten, die
     angezeigte Version notieren, beenden.
  7. Deinstallieren: `"<Installationsordner>\unins000.exe" /LOG="C:\EE-Test\logs\TP-70_EE-admin_uninstall.log"`.
- **Erwartetes Ergebnis:**
  - Die Testwarnung nennt `ID = 1`, Setup-Version 1.7.2 und die Spielversion. Außer ihr, der
    Rechtsfrage bei (a), dem Hinweis zum Benutzermodus bei „user“ und den bekannten Grenzen von
    Weg A und A+ ([6.2](#62-weg-a-placeholder-build), [6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids))
    erscheint keine Fehlermeldung. Ausnahme NeoEE in
    einer VM mit Weg B: Die CD-Key-Registrierung kann die VM erkennen und `CDKeysErrorVM` melden
    (das prüft TP-77); die Installation läuft trotzdem zu Ende.
  - Schritt 5: `DisplayName` ist `Empire Earth v2.0.0.0 - Setup v1.7.2` bzw.
    `NeoEE v2.0.0.5 - Setup v1.7.2`; Spielordner und `_setupdata_<Produkt>` existieren. Bei (b)
    gibt es unter „Apps“ genau einen Eintrag des Produkts, der Zielordner ist der der Installation
    1.7.2, und der alte versteckte Ordner `<Spielordner>\<AppId>` ist entfernt (`dir /a` zeigt nur
    `_setupdata_<Produkt>`); der Uninstall-Schlüssel hat `Empire Earth Community: ContractVersion`
    `0x1`, `InstallPath` ist der Ordner der Installation 1.7.2. Weg A+: danach startet das Spiel nicht
    mehr (Platzhalter, [6.4](#64-weg-a-placeholder-build-mit-den-offiziellen-appids)). Portable: kein
    Uninstall-Schlüssel, Ordner `Empire Earth Portable` bzw. `Neo Empire Earth Portable` neben dem
    Setup.
  - Schritt 6: Beide Spiele erreichen das Hauptmenü ohne Fehlermeldung.
  - Schritt 7: Der Eintrag unter „Apps“ und der Uninstall-Schlüssel sind weg; im Spielordner
    bleiben höchstens Dateien, die das Spiel selbst angelegt hat; `Software\Sierra\CDKeys` ist
    unverändert (NeoEE).
- **Log-Hinweis:** Das Setup-Log enthält `Installation process succeeded.` und keine Zeile mit
  `Exception` oder `Runtime error`. Bei Weg A und A+ erklären die Zeilen zu `dxwebsetup.exe` bzw.
  `authtools.dll` die erwarteten Hinweise. Bei (b) zeigt Inno Setup, dass es die vorhandene
  Installation fortführt: `Will append to existing uninstall log: <Ordner der Installation
  1.7.2>\unins000.dat` (bei einer Erstinstallation `Creating new uninstall log: …`). Bei Problemen
  beide Logs ins Protokoll.

#### TP-71: Als Administrator installieren, als Standardbenutzer spielen

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** Forum §8 Nr. 1 (t=3001 p=22273: ohne Administratorrechte meldete EE 2.00.5038, mit
  2.00.6345; t=2631 p=17656), Forumsbericht §8 Problemabgleich Nr. 2 (VirtualStore); ADR 0010
  Punkt 5 (Entscheidungsregel); Launcher R8 (Warnung vor VirtualStore-Kopien)
- **Ziel:** Zeigen, ob ein Standardbenutzer nach einer Installation für alle Benutzer Dateien des
  Spielordners in den VirtualStore umgeleitet bekommt (`_won*`, `_wonHTTPCache`, `neoee.log`,
  `upnp_info.txt`, `0_Error.log`) und ob das Hauptmenü mit und ohne „Als Administrator ausführen“
  dieselbe Version zeigt; das Ergebnis entscheidet nach der Regel aus ADR 0010 Punkt 5.
- **Build-Art:** B (das Spiel muss laufen)
- **Ausgangszustand:** Windows 10/11 mit 3D-Beschleunigung, kein Empire Earth; ein
  Administratorkonto („Admin“) und das Standardkonto „Spieler“, beide schon einmal angemeldet;
  Internet (für die Lobby).
- **Snapshot:** `Laptop` (Wiederherstellungspunkt, Regel 1; ein Standardkonto anlegen, falls keines
  da ist) oder eine VM auf `S-Basis` mit 3D-Beschleunigung
- **Varianten:** (a) EE-admin, (b) NeoEE-admin (NeoEE schreibt zusätzlich `neoee.log` und
  `upnp_info.txt`). Nur admin: Im Modus user und portable gehört der Spielordner dem Spieler, dort
  leitet Windows nichts um.
- **Schritte:**
  1. Als „Admin“ EE-admin mit `/LOG="C:\EE-Test\logs\TP-71a_EE-admin.log"` installieren:
     „Empfohlene Einstellungen“ mit Empire Earth und AoC, Standardordner, Telemetrie aus. Abmelden.
  2. Als „Spieler“ anmelden und prüfen, dass es noch keine Kopien gibt:
     `dir /s /a "%LOCALAPPDATA%\VirtualStore\Program Files (x86)\Empire Earth"` (erwartet: „Die
     Datei wurde nicht gefunden“ bzw. „Das System kann den angegebenen Pfad nicht finden“).
  3. Empire Earth über das Startmenü starten (nicht als Administrator): die Version im Hauptmenü
     notieren, *Mehrspieler › Online* öffnen und warten, bis die Lobby geladen ist (ohne Anmeldung;
     das legt die `_won*`-Dateien an), zurück, eine Zufallskarte gegen den Computer zwei Minuten
     spielen, als `TP71` speichern, beenden. Dasselbe mit AoC.
  4. Ausgaben ins Protokoll:

     ```bat
     dir /s /a "%LOCALAPPDATA%\VirtualStore\Program Files (x86)\Empire Earth"
     dir /a "C:\Program Files (x86)\Empire Earth\Empire Earth\Data\Saved Games"
     dir /a "C:\Program Files (x86)\Empire Earth\Empire Earth\_won*"
     ```

  5. Empire Earth mit Rechtsklick › „Als Administrator ausführen“ starten (Kennwort von „Admin“),
     die Version im Hauptmenü notieren, beenden; Schritt 4 wiederholen.
  6. (b) Snapshot zurücksetzen und mit NeoEE-admin wiederholen (Ordner `…\Neo Empire Earth`, die
     NeoEE-Lobby; VirtualStore-Pfad `…\VirtualStore\Program Files (x86)\Neo Empire Earth`).
- **Erwartetes Ergebnis:**
  - Das Spiel startet als „Spieler“, der Spielstand `TP71` liegt im echten Ordner `Data\Saved Games`
    (das Setup gibt allen Benutzern Schreibrechte auf `Data`), nicht im VirtualStore. Startet das
    Spiel nicht oder kann es nicht speichern, ist der Fall nicht bestanden.
  - Die Version im Hauptmenü ist mit und ohne Administratorrechte gleich. Zwei verschiedene Werte
    sind eine Abweichung (beide ins Protokoll, mit der Liste aus Schritt 4): Dann liest das Spiel
    ohne Administratorrechte Dateien aus dem VirtualStore (t=3001 p=22273).
  - Der VirtualStore ist ein Befund, über den die vor dem Test festgelegte Regel aus ADR 0010
    Punkt 5 entscheidet: **leer** → keine Änderung am Setup (der Launcher warnt weiterhin, R8);
    **Dateien gefunden** → die Liste (Pfad und Name) an die Maintainer: Ein Folgepaket gibt genau
    diesen Dateien bzw. Ordnern `authusers-modify` (Kandidaten aus dem Forum `_won*`, `neoee.log`,
    `upnp_info.txt`); liegen sie über den Spielordner verteilt, schlägt das Folgepaket stattdessen
    einen Standardordner außerhalb von `Program Files` vor. Beides ist kein „nicht bestanden“.
- **Log-Hinweis:** Das Setup-Log belegt nur die Rechte: je Ordner `Setting permissions on
  directory: …\Empire Earth\Data` bzw. `…\Users` (und für AoC), je vorhandener `*.cfg`-, `*.ini`-
  Datei `Setting permissions on file: …`. Was im VirtualStore liegt, zeigt nur `dir` aus Schritt 4.

#### TP-72: Versionsanzeige und Mehrspieler zwischen zwei Installationen

- **Status:** ausgearbeitet
- **Priorität:** P3 (zwei Rechner mit 3D-Beschleunigung)
- **Bezug:** Forum §8 Nr. 2 (t=11034 p=47982: EE 2.00.2949 und AoC 1.00.2473 seit 2015, auch t=5750
  p=38772, t=5909 p=39456; t=3001: „your version is not the same as the host“), Forumsbericht 4.12;
  Vertrag 2 (`files.sha256`); Forum §8 Nr. 19 verweist hierher
- **Ziel:** Zwei Installationen desselben Setups haben dieselben Spielprogramme, zeigen dieselbe
  Version im Hauptmenü und spielen ohne Versionskonflikt und ohne Asynchronität miteinander.
- **Build-Art:** B
- **Ausgangszustand:** zwei Rechner im selben lokalen Netz (der Laptop und ein zweiter Rechner oder
  eine VM mit 3D-Beschleunigung), auf beiden noch kein Empire Earth.
- **Snapshot:** `Laptop` und der zweite Rechner, beide mit Wiederherstellungspunkt (Regel 1)
- **Varianten:** NeoEE-admin auf beiden (der Normalfall der Online-Lobby); EE-admin auf beiden
  optional. Eine Mischung aus EE und NeoEE ist ausgelassen: andere Programme, ein Konflikt ist dort
  erwartet.
- **Schritte:**
  1. Auf beiden Rechnern denselben Testbuild NeoEE-admin mit
     `/LOG="C:\EE-Test\logs\TP-72_NeoEE-admin_<Rechner>.log"` installieren: „Empfohlene
     Einstellungen“ mit Empire Earth und AoC, Spielsprache auf beiden gleich, Telemetrie aus; die
     Aufgabe „Spiel in der Windows-Firewall zulassen …“ bleibt angehakt (Standard, TP-76).
  2. Auf beiden in PowerShell:

     ```powershell
     $root = 'C:\Program Files (x86)\Neo Empire Earth'
     foreach ($p in 'Empire Earth\Empire Earth.exe', 'Empire Earth - The Art of Conquest\EE-AOC.exe') {
       $f = Join-Path $root $p
       '{0}  {1}  {2}' -f (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower(), (Get-Item -LiteralPath $f).VersionInfo.FileVersion, $p
     }
     Select-String -LiteralPath (Join-Path $root '_setupdata_NeoEE\files.sha256') -Pattern 'Empire Earth.exe$', 'EE-AOC.exe$'
     ```

  3. Auf beiden Empire Earth starten und die Version im Hauptmenü notieren; dasselbe mit AoC.
  4. Rechner 1: *Mehrspieler › LAN* (TCP/IP) ein Spiel erstellen; Rechner 2: beitreten. Starten und
     fünf Minuten spielen, dabei auf beiden Seiten Einheiten bauen und kämpfen. Dasselbe mit AoC.
     Optional (mit NeoEE-Konto): dasselbe über die Online-Lobby.
  5. Danach auf beiden `dir "C:\Program Files (x86)\Neo Empire Earth\Empire Earth\OOS*.log"`.
- **Erwartetes Ergebnis:**
  - Schritt 2: auf beiden Rechnern dieselben SHA-256 und Dateiversionen, gleich den Zeilen in
    `files.sha256`.
  - Schritt 3: auf beiden dieselbe Version. Die Referenz aus dem Forum für NeoEE ist EE 2.00.2949
    und AoC 1.00.2473 (Stand 2015 bis 2017); eine andere Zahl ist kein Fehler, solange beide gleich
    sind, gehört aber ins Protokoll.
  - Schritt 4: Der Beitritt gelingt ohne Meldung zu einer anderen Version, das Spiel läuft ohne
    „Out of Sync“; Schritt 5 findet keine `OOS*.log`.
- **Log-Hinweis:** In beiden Setup-Logs `Manifest: <n> files, …` mit derselben Anzahl Dateien. Eine
  Asynchronität schreibt das Spiel selbst als `OOS*.log` in den Spielordner (Schritt 5).

#### TP-73: Reparatur durch erneutes Ausführen des Setups

- **Status:** ausgearbeitet
- **Priorität:** P1 (Teil a; b und c: P2; d: P2, nur Weg B)
- **Bezug:** Forum §8 Nr. 4 (t=10931 p=47182: Einfrieren mit 16 Bit Farbtiefe unter Windows 10) und
  Nr. 22 (t=5825 p=39086, t=10915 p=46963, t=11034 p=47986: der Wartungsmodus des alten
  NeoEE-Installers „Modify/Repair/Uninstall“ als Sackgasse); Vertrag 3.2 (Klassen D und P) und 4.1
  (die Reparatur ist ein Lauf des Setups); Launcher-Testplan WP6-11
- **Ziel:** Ein erneuter Lauf über eine veränderte oder teilweise kaputte Installation stellt
  fehlende und veränderte Dateien und die Anzeigewerte (32 Bit) wieder her, lässt die Vorgaben des
  Spielers stehen und führt nie in eine Sackgasse; auch ohne Uninstall-Schlüssel läuft eine
  Installation in denselben Ordner durch.
- **Build-Art:** A oder B (Teil d nur B)
- **Ausgangszustand:** (a), (b) EE-admin mit AoC installiert, z. B. der Stand nach
  [TP-70](#tp-70-grundablauf-installieren-starten-deinstallieren) (a) vor Schritt 7; (c) NeoEE-admin
  mit AoC und der Aufgabe „NeoEE-CD-Keys registrieren“ installiert; (d) EE-admin mit Weg B auf dem
  Laptop.
- **Snapshot:** `S-Basis` oder `S-Sandbox` für (a) bis (c); `Laptop` für (d)
- **Varianten:** (a) EE-admin, Reparatur über den Assistenten; (b) EE-admin ohne
  Uninstall-Schlüssel; (c) NeoEE-admin ohne `EE-AOC.exe` und ohne `install.ini`; (d) EE-admin mit
  16 Bit unter Windows 10/11. EE-user und portable reparieren mit demselben Code; portable hat nie
  einen Uninstall-Schlüssel und läuft deshalb immer wie (b).
- **Schritte:**
  1. (a) Die Installation beschädigen und die Einstellungen verstellen (PowerShell als
     Administrator):

     ```powershell
     $spiel = 'C:\Program Files (x86)\Empire Earth\Empire Earth'
     Remove-Item -LiteralPath "$spiel\Language.dll"
     Add-Content -LiteralPath "$spiel\help.rtf" -Value 'x'
     reg add "HKCU\Software\SSSI\Empire Earth" /v "Game Bit Depth" /t REG_DWORD /d 16 /f
     reg add "HKCU\Software\SSSI\Empire Earth" /v "Texture Bit Depth" /t REG_DWORD /d 16 /f
     reg add "HKCU\Software\SSSI\Empire Earth" /v "Music Volume" /t REG_DWORD /d 10 /f
     ```

  2. Das Setup mit `/LOG="C:\EE-Test\logs\TP-73a_EE-admin.log"` starten (Weg A zusätzlich
     `/MERGETASKS="!dxwebsetup"`): Auf der Seite „Installationsmodus“ ist „Vorhandene Installation
     reparieren“ vorausgewählt; so lassen, Telemetrie aus, installieren, fertigstellen.
  3. Prüfen: die PowerShell-Zeilen aus [TP-50](#tp-50-von-antivirenprogrammen-gelöschte-dateien)
     Schritt 2 und

     ```bat
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Game Bit Depth"
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Texture Bit Depth"
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Music Volume"
     ```

  4. (b) Nur den Uninstall-Schlüssel des Testbuilds löschen (Weg A: Platzhalter-AppId; nie einen
     anderen Schlüssel, nie `Software\Sierra`):
     `reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /reg:64 /f`.
     Dann das Setup mit `TP-73b` im Log-Namen starten: Die Seite „Installationsmodus“ bietet keine
     Reparatur an; „Empfohlene Einstellungen“ mit Empire Earth und AoC, auf der Ordnerseite den
     vorgeschlagenen Ordner `C:\Program Files (x86)\Empire Earth` lassen, installieren. Danach
     `dir /a "C:\Program Files (x86)\Empire Earth"` und
     `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v "Empire Earth Community: ContractVersion" /reg:64`.
  5. (c) Beim NeoEE-admin (wie im Launcher-Testplan WP6-11) die Installation teilweise zerstören:

     ```powershell
     $root = 'C:\Program Files (x86)\Neo Empire Earth'
     Remove-Item -LiteralPath "$root\Empire Earth - The Art of Conquest\EE-AOC.exe"
     Remove-Item -LiteralPath "$root\_setupdata_NeoEE\install.ini"
     ```

     Das NeoEE-Setup mit `TP-73c` im Log-Namen starten, „Vorhandene Installation reparieren“,
     installieren; danach die PowerShell-Zeilen aus TP-50 Schritt 2 mit `$root` und
     `_setupdata_NeoEE`.
  6. (d) Nur Weg B, auf dem Laptop: wie Schritt 1 nur die beiden Bit-Tiefen auf 16 setzen, Empire
     Earth starten und ein Spiel beginnen (friert es ein? t=10931); beenden (notfalls im
     Task-Manager), reparieren wie in Schritt 2 und erneut ein Spiel beginnen.
- **Erwartetes Ergebnis:**
  - (a) Außer der Testwarnung (und bei Weg A den bekannten Grenzen) keine Frage; die Reparatur
    fragt weder nach Komponenten noch nach dem Ordner. Danach `Hash falsch oder Datei fehlt: 0`
    (`Language.dll` ist wieder da, `help.rtf` hat wieder den Hash aus dem Setup), `Game Bit Depth`
    und `Texture Bit Depth` sind `0x20` (Klasse D: jeder Lauf überschreibt), `Music Volume` bleibt
    `0xa` (Klasse P: nur angelegt, wenn er fehlt; Vertrag 3.2). Kein Hinweis zu fehlenden Dateien.
  - (b) Die Installation läuft in denselben Ordner durch, ohne Frage nach einem fremden oder
    gemeinsamen Ordner; danach gibt es den Uninstall-Schlüssel wieder mit
    `Empire Earth Community: ContractVersion` `0x1`, und im Ordner liegt weiter genau ein
    Deinstallationsprogramm `unins000.exe` (Inno Setup führt das vorhandene
    Deinstallationsprotokoll derselben AppId fort; ein zusätzliches `unins001.exe` ist eine
    Abweichung).
  - (c) Die Reparatur läuft durch, `EE-AOC.exe` und `install.ini` sind wieder da, das Manifest
    stimmt. Die CD-Key-Registrierung meldet bei Weg A `CDKeysToolMissing`, in einer VM mit Weg B
    `CDKeysErrorVM` ([TP-77](#tp-77-neoee-cd-keys-bei-gesperrtem-server-und-in-einer-vm)); die
    Installation endet trotzdem normal. Es gibt keine Sackgasse wie beim alten NeoEE-Installer: das
    Setup bietet die Reparatur selbst an, und unter „Apps“ steht ein Eintrag, der deinstalliert.
  - (d) Befund: Einfrieren mit 16 Bit ja/nein (mit Grafikchip und Treiber ins Protokoll); nach der
    Reparatur sind beide Werte `0x20`, und das Spiel läuft.
- **Log-Hinweis:** (a) `Will append to existing uninstall log: …\unins000.dat`, `Dest filename:
  …\Empire Earth\Language.dll`, die Registry-Zeilen `Key: HKEY_CURRENT_USER\Software\SSSI\Empire
  Earth` mit `Value name: Game Bit Depth`, `Manifest: …` und `Wrote "Empire Earth Community:
  ContractVersion" = 1 into the uninstall key`; (b) dieselben Zeilen und `Creating new uninstall key:
  HKEY_LOCAL_MACHINE\…\Uninstall\{<AppId>}_is1`; (c) `Register NeoEE CD Keys for EE and AoC`, dann
  `Unable to call authtools.dll: …` und `CD Keys: <Text der Meldung>` (Weg A) bzw.
  `CD Keys generation result: <n>` (Weg B).

#### TP-74: AoC ohne vorherigen Start von EE

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** Forum §8 Nr. 7 (t=2825 p=19423: AoC braucht die Registry-Schlüssel des Basisspiels),
  Forumsbericht 4.5; Vertrag 3.2 und 3.3 (`Installed From Volume`, `Installed From Directory`,
  Klasse S)
- **Ziel:** Das Setup schreibt `Installed From` für Empire Earth und AoC, sodass AoC direkt nach der
  Installation startet, ohne dass Empire Earth je lief.
- **Build-Art:** A oder B (der Spielstart in Schritt 4 nur B)
- **Ausgangszustand:** kein Empire Earth; in HKCU keine Schlüssel `Software\SSSI`,
  `Software\Mad Doc Software` und `Software\Neo` (Schritt 1). Auf dem Laptop daher nur ohne andere
  Installation des Spiels für dieses Konto.
- **Snapshot:** `S-Basis` oder `S-Sandbox` (Weg A); `Laptop` oder eine VM mit 3D-Beschleunigung
  (Weg B)
- **Varianten:** (a) EE-admin, (b) NeoEE-admin, (c) EE-user (ein Pfad unter `%LOCALAPPDATA%`).
  Portable schreibt dieselben Werte wie user.
- **Schritte:**
  1. `reg query "HKCU\Software\SSSI"`, `reg query "HKCU\Software\Mad Doc Software"` und
     `reg query "HKCU\Software\Neo"`: alle „nicht gefunden“.
  2. (a) EE-admin mit `/LOG="C:\EE-Test\logs\TP-74a_EE-admin.log"`, „Empfohlene Einstellungen“ mit
     Empire Earth und AoC, Standardordner, Telemetrie aus; das Spiel danach nicht starten.
  3. Abfragen:

     ```bat
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Installed From Volume"
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Installed From Directory"
     reg query "HKCU\Software\Mad Doc Software\EE-AOC" /v "Installed From Volume"
     reg query "HKCU\Software\Mad Doc Software\EE-AOC" /v "Installed From Directory"
     ```

  4. Nur Weg B: AoC über das Startmenü starten (nicht Empire Earth), bis ins Hauptmenü, eine
     Zufallskarte eine Minute anspielen, beenden.
  5. (b) Snapshot zurücksetzen, NeoEE-admin mit `TP-74b`, Schritte 3 und 4 mit
     `HKCU\Software\Neo\Empire Earth` und `HKCU\Software\Neo\Art of Conquest`. (c) Snapshot
     zurücksetzen, EE-user (`/CURRENTUSER`) mit `TP-74c`, Schritte 3 und 4.
- **Erwartetes Ergebnis:**
  - Schritt 3: `Installed From Volume` ist `C:`; `Installed From Directory` ist
    `\PROGRAM FILES (X86)\EMPIRE EARTH\Empire Earth\` bzw.
    `\PROGRAM FILES (X86)\EMPIRE EARTH\Empire Earth - The Art of Conquest\` (Vertrag 3.3: die Wurzel
    in Großbuchstaben, der Spielordner nicht, `\` am Ende). (b) `\PROGRAM FILES (X86)\NEO EMPIRE
    EARTH\…`; (c) `\USERS\<NAME>\APPDATA\LOCAL\PROGRAMS\EMPIRE EARTH\…`.
  - Schritt 4: AoC erreicht das Hauptmenü und startet die Karte ohne Fehlermeldung, ohne dass
    Empire Earth vorher lief (t=2825).
- **Log-Hinweis:** `Key: HKEY_CURRENT_USER\Software\SSSI\Empire Earth` und
  `Key: HKEY_CURRENT_USER\Software\Mad Doc Software\EE-AOC` (NeoEE: `…\Software\Neo\…`) je mit
  `Value name: Installed From Volume` und `Value name: Installed From Directory`.

#### TP-75: EE und NeoEE in getrennten Ordnern, eines deinstallieren

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** Forum §8 Nr. 9 (t=4723 p=33045: Parallelinstallationen in getrennten Ordnern);
  Vertrag 1.1 (ein Eintrag je Produkt), 3.1 (getrennte Schlüssel der Spieleinstellungen), 3.4, 3.7
  und 3.8 (`Software\Sierra\CDKeys`); ADR 0004 (Deinstallation)
- **Ziel:** Nach der Deinstallation eines Produkts bleiben Firewall-Regeln, Spieleinstellungen,
  Installationseintrag, Kompatibilitätswerte, GPU-Präferenzen und CD-Keys des anderen erhalten, und
  es startet weiter.
- **Build-Art:** A oder B (CD-Keys und Spielstart nur B)
- **Ausgangszustand:** kein Empire Earth.
- **Snapshot:** `S-Basis` oder `S-Sandbox` (Weg A); `Laptop` für Weg B (die CD-Keys lassen sich in
  einer VM nicht registrieren, TP-77)
- **Varianten:** (a) EE-admin und NeoEE-admin, dann EE deinstallieren; (b) dieselben, dann NeoEE
  deinstallieren. user-Installationen haben keine Firewall-Regeln und HKCU statt HKLM; derselbe Code.
- **Schritte:**
  1. EE-admin und danach NeoEE-admin je in den Standardordner installieren (`…\Empire Earth` bzw.
     `…\Neo Empire Earth`), Log `TP-75a_EE-admin` bzw. `TP-75a_NeoEE-admin`, „Empfohlene
     Einstellungen“ mit Empire Earth und AoC, Telemetrie aus; die Firewall-Aufgabe bleibt angehakt,
     bei NeoEE mit Weg B auch „NeoEE-CD-Keys registrieren“.
  2. Bestandsaufnahme als Administrator (PowerShell), die Ausgabe in eine Datei
     `C:\EE-Test\logs\TP-75a_vorher.txt`:

     ```powershell
     Get-NetFirewallRule | Where-Object { $_.DisplayName -like 'Empire Earth*' -or $_.DisplayName -like 'NeoEE*' } |
       ForEach-Object { '{0} | {1}' -f $_.DisplayName, ($_ | Get-NetFirewallApplicationFilter).Program } | Sort-Object
     reg query "HKCU\Software\SSSI\Empire Earth" /v "Installed From Directory"
     reg query "HKCU\Software\Neo\Empire Earth" /v "Installed From Directory"
     reg query "HKLM\SOFTWARE\Empire Earth Community\Installations" /s /reg:64
     reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /reg:64
     reg query "HKCU\Software\Microsoft\DirectX\UserGpuPreferences"
     foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Sierra\CDKeys', 'HKLM:\SOFTWARE\Sierra\CDKeys', 'HKCU:\Software\Sierra\CDKeys') { '{0}: {1}' -f $k, (Test-Path $k) }
     ```

     Die letzte Zeile sagt nur, ob es die Schlüssel gibt; ihre Werte nie ausgeben (Regel 3).
  3. (a) EE über *Einstellungen › Apps* deinstallieren (oder `unins000.exe` mit `/LOG`), Schritt 2
     wiederholen (`TP-75a_nachher.txt`). Nur Weg B: NeoEE (Empire Earth und AoC) starten und die
     Online-Lobby öffnen.
  4. (b) Snapshot zurücksetzen (Weg B: Wiederherstellungspunkt bzw. beide deinstallieren und neu),
     Schritte 1 und 2 mit `TP-75b`, dann NeoEE deinstallieren, Schritt 2 wiederholen. Nur Weg B:
     Empire Earth und AoC starten.
- **Erwartetes Ergebnis:**
  - Vorher: 16 Firewall-Regeln (je Produkt und Spiel TCP und UDP, ein- und ausgehend), deren
    Programm im Ordner des eigenen Produkts liegt; zwei Einträge unter `Installations`; vier
    Kompatibilitätswerte und vier GPU-Präferenzen (je Programm im eigenen Ordner); beide
    Spieleinstellungsschlüssel.
  - (a) Nachher: die acht `NeoEE`-Regeln unverändert, keine Regel mit einem Programm unter
    `…\Empire Earth\…` mehr; `Software\SSSI\Empire Earth` und `Software\Mad Doc Software\EE-AOC`
    weg, `Software\Neo\…` unverändert; unter `Installations` nur `NeoEE`; Kompatibilitätswerte und
    GPU-Präferenzen nur noch für die NeoEE-Programme; die CD-Key-Zeilen gleich wie vorher (Weg B:
    `True` für die Ansicht, in die `authtools.dll` geschrieben hat). Weg B: NeoEE startet und kommt
    in die Lobby, ohne „CD key invalid“.
  - (b) Spiegelbildlich: alles von NeoEE weg, alles von EE vollständig; die CD-Key-Zeilen bleiben
    auch nach der Deinstallation von NeoEE gleich (die Deinstallation fasst `Software\Sierra\CDKeys`
    nie an, Vertrag 3.8). Weg B: Empire Earth und AoC starten.
- **Log-Hinweis:** Setup: je Regel `-- Run entry --`, `Filename: …\netsh.exe` und `Parameters:
  advfirewall firewall add rule name="NeoEE - TCP - In" program="…\Neo Empire Earth\Empire
  Earth\Empire Earth.exe" …`. Das Deinstallations-Log (`/LOG`) nennt die Löschbefehle
  `advfirewall firewall delete rule program="<Programm des deinstallierten Produkts>" name=all`.

#### TP-76: Firewall-Regeln beim Hosten

- **Status:** ausgearbeitet
- **Priorität:** P2 (Teil c mit einem zweiten Rechner: P3)
- **Bezug:** Forum §8 Nr. 10 und Forumsbericht 4.9 (Ports 33334 bis 33336, t=4266 p=30400);
  Problemabgleich Nr. 8; Vertrag 4.1 (Firewall-Regeln legt und repariert nur das Setup); ADR 0007
  (die Regeln hängen am Programmpfad); `setup_is6.iss` `FirewallAllowRules` (TCP und UDP, ein- und
  ausgehend, `profile=any`, nur im Modus admin)
- **Ziel:** Mit der Aufgabe `firewallexception` legt das Setup für beide Programme Regeln für alle
  Netzwerkprofile an, und Mitspieler kommen ohne Firewall-Dialog ins gehostete Spiel, im Profil
  „Öffentlich“ wie „Privat“; ohne die Aufgabe gibt es keine Regeln, im Modus user gibt es die
  Aufgabe nicht.
- **Build-Art:** A oder B (Teil c nur B)
- **Ausgangszustand:** kein Empire Earth; die Windows-Firewall ist an (Standard), es gibt keine
  Regel mit „Empire Earth“ oder „NeoEE“ im Namen (Abfrage aus Schritt 1).
- **Snapshot:** `S-Basis` oder `S-Sandbox` für (a), (b) und (d); für (c) `Laptop` und ein zweiter
  Rechner im selben Netz mit derselben Installation ([TP-72](#tp-72-versionsanzeige-und-mehrspieler-zwischen-zwei-installationen))
- **Varianten:** (a) NeoEE-admin mit der Aufgabe (Standard), (b) NeoEE-admin ohne, (c) wie (a) mit
  einem Mitspieler, Profil „Öffentlich“ und „Privat“, und die Gegenprobe ohne die Aufgabe, (d)
  NeoEE-user. EE legt dieselben Regeln mit dem Namen `Empire Earth` an.
- **Schritte:**
  1. (a) NeoEE-admin mit `/LOG="C:\EE-Test\logs\TP-76a_NeoEE-admin.log"`, „Benutzerdefinierte
     Installationseinstellungen“ mit Empire Earth und AoC; auf der Aufgabenseite prüfen, dass „Spiel
     in der Windows-Firewall zulassen (eingehende Verbindungen in allen Netzwerktypen, nötig zum
     Hosten von Spielen)“ angehakt ist; installieren. Dann in PowerShell:

     ```powershell
     Get-NetFirewallRule | Where-Object { $_.DisplayName -like 'NeoEE*' -or $_.DisplayName -like 'Empire Earth*' } | ForEach-Object {
       '{0} | {1} | {2} | {3} | {4}' -f $_.DisplayName, $_.Direction, $_.Action, $_.Profile, ($_ | Get-NetFirewallApplicationFilter).Program
     } | Sort-Object
     ```

  2. (b) Snapshot zurücksetzen, wie (a) mit `TP-76b` und abgewählter Aufgabe; dieselbe Abfrage.
  3. (d) Snapshot zurücksetzen, NeoEE-user (`/CURRENTUSER`) mit `TP-76d`, benutzerdefiniert: die
     Aufgaben notieren; dieselbe Abfrage.
  4. (c) Nur Weg B: Der Laptop hostet, der zweite Rechner tritt bei. Auf dem Laptop das
     Netzwerkprofil auf „Öffentlich“ stellen (*Einstellungen › Netzwerk und Internet ›
     Eigenschaften*), NeoEE starten, *Mehrspieler › LAN* ein Spiel erstellen; der zweite Rechner
     tritt bei, beide starten und spielen eine Minute. Auf dem Laptop darauf achten, ob „Die Windows
     Defender Firewall hat einige Features dieser App blockiert“ erscheint. Dasselbe mit dem Profil
     „Privat“. Dann NeoEE deinstallieren, ohne die Aufgabe neu installieren (benutzerdefiniert) und
     den Ablauf im Profil „Öffentlich“ wiederholen; erscheint der Dialog, „Abbrechen“ wählen.
     Danach eine Regel, die Windows selbst angelegt hat, in *Windows Defender Firewall › Eine App
     durch die Firewall zulassen* entfernen und das Netzwerkprofil zurückstellen.
- **Erwartetes Ergebnis:**
  - (a) Genau acht Regeln, `NeoEE - TCP - In`, `NeoEE - TCP - Out`, `NeoEE - UDP - In`,
    `NeoEE - UDP - Out` und dieselben mit `NeoEE - AoC - …`; alle `Allow`, Profil `Any`, Programm
    `C:\Program Files (x86)\Neo Empire Earth\Empire Earth\Empire Earth.exe` bzw.
    `…\Empire Earth - The Art of Conquest\EE-AOC.exe`.
  - (b) und (d): keine Regel; in (d) bietet die Aufgabenseite die Firewall-Aufgabe nicht an.
  - (c) Mit den Regeln: in beiden Profilen kein Firewall-Dialog auf dem Laptop, der Mitspieler kommt
    ins Spiel. Ohne die Regeln im Profil „Öffentlich“: Der Dialog erscheint bzw. der Beitritt
    scheitert (Befund; er zeigt, wofür die Aufgabe da ist). Hosten über das Internet braucht
    zusätzlich die Portweiterleitung am Router; das liegt außerhalb des Setups (Launcher,
    Netzwerkdiagnose R7).
- **Log-Hinweis:** (a) acht Blöcke `-- Run entry --`, `Filename: …\netsh.exe`, `Parameters:
  advfirewall firewall add rule name="NeoEE - TCP - In" program="…" protocol=TCP dir=in
  action=allow enable=yes profile=any localport=any` (und die anderen sieben), je mit `Process exit
  code: 0`; davor die zwei Löschbefehle `advfirewall firewall delete rule program="…" name=all`. (b)
  und (d): keine Zeile mit `advfirewall`.

#### TP-77: NeoEE-CD-Keys bei gesperrtem Server und in einer VM

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** Forum §8 Nr. 13 (t=10950 p=47202, t=11021 p=47908 und p=47909, t=10968 p=47345),
  Forumsbericht 4.19; Entscheidung D6 (die Registrierung über `authtools.dll` mit `neoee.net:10003`
  bleibt unverändert); Vertrag 3.8; die Meldungen `CDKeysErrorNetwork`, `CDKeysErrorVM` und
  `CDKeysToolMissing`
- **Ziel:** Scheitert die Registrierung der NeoEE-CD-Keys, weil der Lizenzserver gesperrt ist oder
  das Setup in einer VM läuft, erscheint die passende verständliche Meldung und die Installation
  läuft zu Ende; eine Reparatur mit freiem Server registriert die Keys; `CDKeyCheck` steht in beiden
  `WONLobby.cfg` auf `true`; `Software\Sierra\CDKeys` wird nie gelöscht.
- **Build-Art:** B (Teil c mit Weg A)
- **Ausgangszustand:** kein NeoEE installiert, Internet; (a) der Laptop, (b) eine VM.
- **Snapshot:** (a) `Laptop` (Wiederherstellungspunkt, Regel 1), (b) `S-Basis`, (c) `S-Sandbox` oder
  `S-Basis`
- **Varianten:** (a) NeoEE-admin mit gesperrtem Lizenzserver, danach eine Reparatur mit freiem
  Server; (b) NeoEE-admin in einer VM; (c) NeoEE-admin mit Weg A (Platzhalter statt
  `authtools.dll`). NeoEE-user registriert die Keys mit demselben Aufruf in HKCU und ist ausgelassen.
- **Schritte:**
  1. (a) Den Lizenzserver sperren (PowerShell als Administrator):

     ```powershell
     $ip = (Resolve-DnsName neoee.net -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
     New-NetFirewallRule -DisplayName 'EE-Test neoee.net sperren' -Direction Outbound -Action Block -Protocol TCP -RemoteAddress $ip -RemotePort 10003
     Test-NetConnection neoee.net -Port 10003
     foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Sierra\CDKeys', 'HKLM:\SOFTWARE\Sierra\CDKeys') { '{0}: {1}' -f $k, (Test-Path $k) }
     ```

     `Test-NetConnection` muss `TcpTestSucceeded : False` melden. Die letzte Zeile sagt nur, ob es
     die Schlüssel gibt; ihre Werte nie ausgeben (Regel 3).
  2. NeoEE-admin mit `/LOG="C:\EE-Test\logs\TP-77a_NeoEE-admin.log"`, „Benutzerdefinierte
     Installationseinstellungen“ mit Empire Earth und AoC, Telemetrie aus; auf der Aufgabenseite ist
     „NeoEE-CD-Keys registrieren (für die Online-Lobby erforderlich)“ angehakt. Installieren, die
     Meldung abfotografieren, fertigstellen.
  3. `Remove-NetFirewallRule -DisplayName 'EE-Test neoee.net sperren'`, das Setup erneut starten
     (`TP-77a2`, „Vorhandene Installation reparieren“), danach die Abfrage der Schlüssel aus Schritt
     1; NeoEE starten und die Online-Lobby öffnen.
  4. `Select-String -Path 'C:\Program Files (x86)\Neo Empire Earth\Empire Earth\WONLobby.cfg', 'C:\Program Files (x86)\Neo Empire Earth\Empire Earth - The Art of Conquest\WONLobby.cfg' -Pattern 'CDKeyCheck'`
  5. NeoEE deinstallieren (mit `/LOG`), die Abfrage der Schlüssel wiederholen.
  6. (b) In der VM NeoEE-admin wie Schritt 2 mit `TP-77b` (Server frei).
  7. (c) In der Sandbox NeoEE-admin von Weg A wie Schritt 2 mit `TP-77c`.
- **Erwartetes Ergebnis:**
  - (a) Schritt 2: genau eine Meldung, erwartet „Die CD-Keys konnten nicht installiert werden:
    Netzwerkfehler. Wenn Sie NeoEE erst vor Kurzem installiert haben, ist dieser Fehler normal.“
    (`CDKeysErrorNetwork`); die Installation endet normal. Meldet `authtools.dll` einen anderen Code
    (eine andere `CDKeys*`-Meldung oder „Unbekannter Fehler beim Installieren der CD-Keys! Code:
    <n>“), ist das ein Befund mit Meldung und Code im Protokoll; am Aufruf ändert das Setup nichts
    (D6). Schritt 3: keine Meldung, die Schlüssel gibt es, die Lobby nimmt den Key an (kein „CD key
    invalid“). Schritt 4: in beiden Dateien `CDKeyCheck: true`. Schritt 5: die Schlüssel gibt es
    weiterhin.
  - (b) „Die CD-Keys konnten nicht installiert werden: virtuelle Maschine erkannt. …“
    (`CDKeysErrorVM`); die Installation endet normal.
  - (c) „Die Datei zum Erzeugen der NeoEE-CD-Keys konnte nicht geladen werden, …“
    (`CDKeysToolMissing`, eine Grenze von Weg A); die Installation endet normal.
- **Log-Hinweis:** `Register NeoEE CD Keys for EE and AoC`, dann `CD Keys generation result: <n>` und
  `CD Keys registered` (0) bzw. `CD Keys: <Text der Meldung>`; bei (c) `Unable to call
  authtools.dll: <Ursache>` und `CD Keys: <Text von CDKeysToolMissing>`. Das Log enthält nie die
  Keys selbst.

#### TP-78: Deutsche Sprachversion von EE und AoC

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** Forum §8 Nr. 16 und Problemabgleich Nr. 13: t=1610 p=9960 (deutsches AoC: im
  Mehrspieler fehlte die letzte Epoche), t=4726 p=31563 (mit kopierter deutscher `Language.dll`
  fehlten die Spezialkräfte der AoC-Zivilisationen), t=11041 p=48006 (deutsche EE-Kampagne friert
  bei „Bitte warten“ ein), t=1905 p=12766 (deutsche `EETheGermans.ssa` defekt); ADR 0003 (Downloads)
- **Ziel:** Mit Spielsprache Deutsch installiert das Setup für Empire Earth und AoC je die passende
  `Language.dll` und die Lobby-Dateien und lädt die deutschen Stimmen und Kampagnen; in AoC sind die
  letzte Epoche und die Zivilisationen mit Spezialkräften wählbar, und die deutschen Kampagnen beider
  Spiele starten.
- **Build-Art:** B (Schritt 2, die Dateien, auch A)
- **Ausgangszustand:** [TP-00](#tp-00-server-vorabprüfung): mindestens ein Dateiserver gültig (sonst
  bleiben Stimmen und Kampagnen englisch, Hinweis `OnlineFilesUnreachable`); kein Empire Earth.
- **Snapshot:** `Laptop` oder eine VM mit 3D-Beschleunigung (Weg B); `S-Sandbox` für Schritt 2 mit
  Weg A
- **Varianten:** EE-admin und NeoEE-admin (NeoEE lädt die Lobby-Dateien aus `Mods/NeoEE/`). user und
  portable laden dieselben Dateien.
- **Schritte:**
  1. EE-admin mit `/LOG="C:\EE-Test\logs\TP-78_EE-admin.log"`, Spielsprache Deutsch, „Empfohlene
     Einstellungen“ mit Empire Earth und AoC (die Komponente „Lokalisierte Sprachausgabe und
     Kampagnen herunterladen“ ist dabei gewählt), Telemetrie aus.
  2. Die Dateien prüfen:

     ```powershell
     $root = 'C:\Program Files (x86)\Empire Earth'
     Get-ChildItem "$root\Empire Earth\Data\Campaigns", "$root\Empire Earth - The Art of Conquest\Data\Campaigns" |
       Select-Object FullName, Length, LastWriteTime
     Select-String -Path C:\EE-Test\logs\TP-78_EE-admin.log -Pattern 'Online file (accepted|verified|not downloaded)'
     ```

  3. Nur Weg B: Empire Earth starten: Hauptmenü deutsch. *Einzelspieler › Kampagne*: die deutsche
     Kampagne und eine zweite wählen und je das erste Szenario starten: Es lädt über „Bitte warten“
     hinaus (t=11041), Texte und Sprachausgabe sind deutsch; beenden.
  4. Nur Weg B: AoC starten. *Mehrspieler › LAN* ein Spiel erstellen (ohne Mitspieler genügt der
     Einrichtungsbildschirm): In den Listen der Start- und der Endepoche steht die letzte Epoche von
     AoC (das Weltraumzeitalter, „Space Age“), ohne leere Einträge (t=1610); die Zivilisationsauswahl
     zeigt die Zivilisationen der Erweiterung mit ihren Spezialkräften (t=4726). Dann das erste
     Szenario einer AoC-Kampagne starten.
  5. NeoEE-admin (Snapshot zurücksetzen oder im eigenen Standardordner) mit `TP-78_NeoEE-admin`,
     Schritte 2 bis 4 mit `…\Neo Empire Earth`.
- **Erwartetes Ergebnis:**
  - Schritt 2: Für Empire Earth stammen `data.ssa` und die fünf Kampagnen `EELearningCampaign.ssa`,
    `EETheBritish.ssa`, `EETheFuture.ssa`, `EETheGermans.ssa`, `EETheGreeks.ssa`, für AoC `data.ssa`
    und `AOCAsian.ssa`, `AOCPacific.ssa`, `AOCRoman.ssa` vom Server; mit Weg B kein Hinweis
    `DownloadIncomplete` (Weg A: nur die gepinnten Dateien als verworfen,
    [TP-16](#tp-16-manipulierter-download-wird-verworfen)).
  - Schritte 3 und 4 wie beschrieben. Jede Abweichung (englische Texte, eine fehlende Epoche oder
    fehlende Spezialkräfte, Einfrieren) mit Spiel und Kampagne ins Protokoll; sie betrifft die
    Sprachdateien auf den Servern bzw. in `data\localized-text`, nicht den Code des Setups.
- **Log-Hinweis:** `Online file accepted, TLS-verified, not pinned: Game/de/EE/Data/Campaigns/EETheGermans.ssa (SHA-256 …)`
  und die anderen Kampagnen, `Online file verified, SHA-256 pinned: …Language.dll` (Weg B), am Ende
  `All <n> online files accepted`.

#### TP-79: Setup bei laufendem Spiel

- **Status:** ausgearbeitet
- **Priorität:** P2 (Teil e: P3, nur Weg B)
- **Bezug:** Forum §8 Nr. 18 (t=2815 p=19299: Dateien „used by another application“ beim
  Neuinstallieren; t=5859 p=39290 und p=39292: eine zweite, hängende Instanz), Problemabgleich
  Nr. 14; Vertrag 0 („Game mutexes … used by the setup as `AppMutex`“) und 4.2; `setup_is6.iss`
  `AppMutex`
- **Ziel:** Läuft Empire Earth oder AoC, hält das Setup vor jeder Änderung mit der Meldung von Inno
  Setup an: „OK“ nach dem Beenden des Spiels setzt fort, „Abbrechen“ beendet das Setup ohne
  Änderung; still endet es ohne Installation; die Deinstallation verhält sich genauso.
- **Build-Art:** A oder B (mit Weg A stellt eine PowerShell das laufende Spiel nach, indem sie seine
  Mutex hält; Teil e nur B)
- **Ausgangszustand:** (a) bis (c) kein Empire Earth; (d) EE-admin installiert; (e) EE-admin mit
  Weg B installiert, das Standardkonto „Spieler“.
- **Snapshot:** `S-Sandbox` oder `S-Basis` für (a) bis (d); `Laptop` oder eine VM mit
  3D-Beschleunigung für (e)
- **Varianten:** (a) EE-admin interaktiv, Empire Earth läuft, „OK“ nach dem Beenden; (b) EE-admin
  interaktiv, AoC läuft, „Abbrechen“; (c) still mit `/SUPPRESSMSGBOXES`; (d) Deinstallation bei
  laufendem Spiel; (e) Weg B: das echte Spiel, auch als „Spieler“ mit Over-the-Shoulder-Erhöhung des
  Setups. NeoEE nutzt dieselben Mutexe.
- **Schritte:**
  1. Das laufende Spiel nachstellen (Weg A): in einer PowerShell ohne Administratorrechte
     `$m = New-Object System.Threading.Mutex($false, 'StainlessSteelStudiosPresentsEmpireEarth')`
     (AoC: `'MadDocSoftwarePresentsEmpireEarthExpansion'`) und das Fenster offen lassen; „das Spiel
     beenden“ heißt hier `$m.Dispose()`. Mit Weg B das Spiel selbst starten und im Hauptmenü lassen.
  2. (a) Mutex von Empire Earth, das Setup mit `/LOG="C:\EE-Test\logs\TP-79a_EE-admin.log"` starten
     („Für alle Benutzer“), die ersten Fragen beantworten; die Meldung abfotografieren, dann das
     Spiel beenden, „OK“, normal installieren.
  3. (b) Snapshot zurücksetzen, Mutex von AoC, das Setup mit `TP-79b`, bei der Meldung „Abbrechen“.
     Danach `dir "C:\Program Files (x86)\Empire Earth"` und die Abfrage des Uninstall-Schlüssels
     aus [TP-70](#tp-70-grundablauf-installieren-starten-deinstallieren) Schritt 5.
  4. (c) Mutex von Empire Earth,
     `start "" /wait <Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\EE-Test\logs\TP-79c_EE-admin.log"`
     in einer Eingabeaufforderung als Administrator, danach `echo %ERRORLEVEL%` und dieselben
     Abfragen wie in (b).
  5. (d) Auf der Installation aus (a): Mutex von Empire Earth, Deinstallation mit
     `"C:\Program Files (x86)\Empire Earth\unins000.exe" /LOG="C:\EE-Test\logs\TP-79d_uninstall.log"`,
     die Meldung abfotografieren, „Abbrechen“; dann das Spiel beenden und noch einmal
     deinstallieren.
  6. (e) Nur Weg B: Empire Earth als „Admin“ starten, das Setup als „Admin“ starten („Reparieren“);
     dann als „Spieler“ Empire Earth starten und das Setup als „Spieler“ mit Over-the-Shoulder-
     Erhöhung (Kennwort von „Admin“) starten.
- **Erwartetes Ergebnis:**
  - (a) Nach den Fragen vor dem Assistenten (Testwarnung, bei der Erstinstallation die
    Rechtsfrage) die Meldung „Das Setup hat entdeckt, dass Empire Earth zurzeit ausgeführt wird.
    Bitte schließen Sie jetzt alle laufenden Instanzen und klicken Sie auf "OK", um fortzufahren,
    oder auf "Abbrechen", um zu beenden.“ Mit noch laufendem Spiel kommt sie nach „OK“ wieder; nach
    dem Beenden setzt „OK“ fort, und die Installation läuft normal.
  - (b) Dieselbe Meldung; „Abbrechen“ beendet das Setup: kein Spielordner, kein Uninstall-Schlüssel.
  - (c) Kein Fenster; das Setup endet ohne Installation mit einem Exit-Code ungleich 0 (den Wert ins
    Protokoll); kein Spielordner.
  - (d) „Die Deinstallation hat entdeckt, dass Empire Earth zurzeit ausgeführt wird. …“; „Abbrechen“
    lässt die Installation vollständig stehen; nach dem Beenden deinstalliert der zweite Lauf normal.
  - (e) Mit „Admin“ wie (a). Mit „Spieler“ und Over-the-Shoulder-Erhöhung ist das Ergebnis ein
    Befund: Die Prüfung öffnet die Mutex des Spiels, das unter einem anderen Konto läuft; je nach
    deren Zugriffsrechten (sie legt das Spiel selbst an) erscheint die Meldung oder nicht. Erscheint
    sie nicht, meldet Inno Setup beim Ersetzen von `Empire Earth.exe`, dass die Datei verwendet wird
    („Wiederholen“, „Ignorieren“, „Abbrechen“): dann „Abbrechen“ und Befund an die Maintainer.
- **Log-Hinweis:** (a) `Message box (OK/Cancel):` mit dem englischen bzw. deutschen Text der
  Meldung, dann `User chose OK.`; (b) `User chose Cancel.`; (c) `Defaulting to Cancel for suppressed
  message box (OK/Cancel):` mit dem Text der Meldung und keine Zeile `Installation process
  succeeded.`; (d) das Deinstallations-Log mit der Meldung.

### Block 8: Links in den für alle beschreibbaren Ordnern (S-WP11)

Was ADR 0009 verlangt und nur auf Windows prüfbar ist: Im Admin-Modus gibt das Setup allen
angemeldeten Benutzern Schreibrechte auf `Data` und `Users` beider Spielordner, und ein Update oder
eine Reparatur schreibt dort mit Administratorrechten. Vor jeder Änderung (`PrepareToInstall`, nach
der Seite „Bereit zur Installation“ und den Downloads in den temporären Ordner) sucht das Setup
deshalb in `Data`, `Users` und allen Ordnern darunter, in beiden vorhandenen Spielordnern, nach
Junctions und symbolischen Links (`FILE_ATTRIBUTE_REPARSE_POINT`). Findet es einen, oder einen
Ordner, den es nicht auflisten kann, hält es auf der Seite „Vorbereitung der Installation“ mit der
Meldung `LinkInGameFolder` an; still endet es mit Exit-Code 7. Anders als ursprünglich geplant gehören
die Spielerordner unter `Users` dazu: Die `[Files]`-Einträge, die die Schreibrechte der
`*.cfg`/`*.ini`-Dateien setzen, kopieren jede solche Datei in jedem Unterordner auf sich selbst und
folgen dabei Links (ADR 0009, „Revised“). Im Benutzer- und im portablen Modus prüft das Setup nicht.
Die Logik prüfen zusätzlich die Unit-Tests (auf Windows auch mit echten Junctions) und eine
Wine-Probe der Analyse (ADR 0009, „Implementation“).

Junctions legt auch ein Standardbenutzer ohne Administratorrechte an (`mklink /J`). Eine Junction
nur mit `rmdir <Link>` entfernen (ohne `/s`): Das löscht den Link, nicht den Ordner, auf den er zeigt.

#### TP-80: Junction in Data als Standardbenutzer, Update als Administrator (nur VM)

- **Status:** ausgearbeitet
- **Priorität:** P2
- **Bezug:** ADR 0009, ADR 0002 (Security-Bewertung, RedirectionGuard), R17; Inno-Setup-Quelltext
  6.2.2 (`RecurseExternalCopyFiles`, `IsRecurseableDirectory`)
- **Ziel:** Ein Link, den ein Standardbenutzer in `Data` oder `Users` anlegt, stoppt das Update im
  Admin-Modus, bevor etwas geändert ist; der Ordner, auf den der Link zeigt, bleibt leer; nach dem
  Entfernen des Links läuft das Update durch.
- **Build-Art:** A oder B (nur VM bzw. Snapshot, nie auf dem Laptop)
- **Ausgangszustand:** EE-admin mit AoC als Administrator installiert (Testbuild, „Empfohlene
  Einstellungen“, Telemetrie aus) im Standardordner `C:\Program Files (x86)\Empire Earth`; Ordner
  `C:\EE-Test\logs` und ein leerer Ordner `C:\EE-Test\scratch` (als Administrator angelegt). Das
  Standardkonto „Spieler“ aus `S-Basis`.
- **Snapshot:** `S-Basis` (nach der Installation einen Zwischenstand sichern, vor jedem Teil
  zurücksetzen)
- **Varianten:** (a) bis (d) EE-admin; (e) EE-user. NeoEE und portable nutzen denselben Code und
  werden nicht wiederholt; portable prüft nicht (kein Admin-Modus).
- **Schritte:**
  1. Als „Spieler“ anmelden (oder `runas /user:Spieler cmd`) und in einer Eingabeaufforderung
     **ohne** Administratorrechte:

     ```bat
     cd /d "C:\Program Files (x86)\Empire Earth\Empire Earth\Data"
     ren Movies Movies.orig
     mklink /J Movies C:\EE-Test\scratch
     dir /AL
     ```

     `dir /AL` zeigt `<JUNCTION> Movies [C:\EE-Test\scratch]`. Gelingt `ren` oder `mklink` nicht, hat
     das Setup keine Schreibrechte auf `Data` gesetzt (z. B. mit der Aufgabe „Spiel immer als
     Administrator starten“): Befund notieren, Fall endet.
  2. (a) Als „Spieler“ das Setup starten mit
     `/LOG="C:\EE-Test\logs\TP-80a_EE-admin.log"`, die Erhöhung mit dem Kennwort des
     Administratorkontos bestätigen (Over-the-Shoulder), falls gefragt „Installation für alle
     Benutzer“, auf der Seite „Installationsmodus“ die angebotene Option für die vorhandene
     Installation, bis „Bereit zur Installation“, „Installieren“. Die Seite „Vorbereitung der
     Installation“ abfotografieren; „Weiter“ ist grau, „Zurück“ nicht. Noch **nicht** abbrechen.
  3. (b) Als „Spieler“ in der Eingabeaufforderung den Link entfernen und den Ordner zurückholen:
     `rmdir Movies` und `ren Movies.orig Movies`. Im Setup „Zurück“, dann wieder „Installieren“:
     Die Downloads laufen noch einmal (falls gewählt), die Prüfung läuft erneut, die Installation
     läuft durch, „Fertigstellen“.
  4. (c) Snapshot-Zwischenstand zurücksetzen, Schritt 1 wiederholen, dann in einer
     Eingabeaufforderung als Administrator:
     `start "" /wait <Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\EE-Test\logs\TP-80c_EE-admin.log"`
     und danach `echo %ERRORLEVEL%`.
  5. (d) Zwischenstand zurücksetzen. Als „Spieler“ einen Spielerordner anlegen und durch einen Link
     ersetzen:
     `cd /d "C:\Program Files (x86)\Empire Earth\Empire Earth - The Art of Conquest\Users"`,
     `mklink /J Spieler C:\EE-Test\scratch`. Dann wie (c) still mit `TP-80d` im Log-Namen.
  6. (e) Zwischenstand zurücksetzen. Als „Spieler“ EE für sich selbst installieren:
     `<Setup>.exe /VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /LOG="C:\EE-Test\logs\TP-80e_EE-user.log"`;
     dann in `%LOCALAPPDATA%\Programs\Empire Earth\Empire Earth\Data` wie in Schritt 1 `Movies`
     durch eine Junction auf einen eigenen Ordner ersetzen und denselben Befehl mit `TP-80e2` im
     Log-Namen wiederholen.
  7. Nach jedem Teil: `dir /a C:\EE-Test\scratch` und `findstr /c:"Link check" /c:"installation stops" /c:"PrepareToInstall" C:\EE-Test\logs\TP-80*.log`.
  8. Nur Weg B, nach (b): die Dauer der Prüfung aus der Zeile `Link check: … examined in <ms> ms`
     notieren (mit echten Daten etwa 30 Ordner je Spiel).
- **Erwartetes Ergebnis:**
  - (a) Rotes Fehlersymbol und „Das Setup hat angehalten, bevor es etwas geändert hat. Es läuft mit
    Administratorrechten, und die Ordner Data und Users des Spiels kann jeder Benutzer ändern. Dort
    hat es Links (Junctions oder symbolische Verknüpfungen) oder nicht lesbare Ordner gefunden, …“,
    darunter `C:\Program Files (x86)\Empire Earth\Empire Earth\Data\Movies`, dann der Rat (Link
    entfernen oder durch einen normalen Ordner ersetzen, oder „Installation nur für Sie“) und Inno
    Setups Zeile „Das Setup kann nicht fortfahren …“. Der ganze Text ist lesbar (nichts
    abgeschnitten). `C:\EE-Test\scratch` ist leer, `Data\Movies.orig` unverändert.
  - (b) Nach „Zurück“ und „Installieren“ läuft die Installation ohne Meldung durch; die Filme liegen
    wieder in `Data\Movies` (Weg B), `C:\EE-Test\scratch` bleibt leer.
  - (c) Kein Fenster, `%ERRORLEVEL%` ist `7`, `C:\EE-Test\scratch` leer.
  - (d) Exit-Code `7`, gefunden wird `…\Empire Earth - The Art of Conquest\Users\Spieler`
    (Abweichung vom ursprünglichen Plan „ein Link in `Users\<Spieler>` blockiert nicht“, siehe
    ADR 0009, „Revised“).
  - (e) Beide Läufe installieren (Exit-Code `0`); die Prüfung läuft im Benutzermodus nicht, die
    Dateien landen im eigenen Ordner, auf den die Junction zeigt (der Benutzer schreibt nur in seine
    eigenen Ordner).
- **Log-Hinweis:** (a) und (c) `Link check: C:\Program Files (x86)\Empire Earth\Empire Earth\Data\Movies
  is a junction or symbolic link (reparse point)`, `Link check: <n> folders below Data and Users of
  C:\Program Files (x86)\Empire Earth examined in <ms> ms, 1 links or unreadable folders found, 0 files
  with a reparse point (allowed)`, `The installation stops before anything is changed (message
  LinkInGameFolder on the Preparing to install page; silent installation: exit code 7)` und Inno
  Setups `PrepareToInstall failed: …`; (b) danach ein zweites `Link check: …, 0 links or unreadable
  folders found, …` und `Installation process succeeded.`; (d) wie (c) mit `…\Users\Spieler`; (e)
  `Link check skipped: not the administrative install mode`.

## 9. Forum-Testfälle §8

Zuordnung der Testfälle für echtes Windows aus dem Forumsbericht (Abschnitt 8, „Testfälle für
echtes Windows“). „Launcher“ heißt: Der Fall prüft den Launcher und gehört in dessen Testplan;
„entfällt“: Das Setup hat mit dem Fall nichts zu tun. Beides steht mit Grund in der Spalte
„Zuordnung“. Die Spalte „Stand“ folgt dem Status der genannten Fälle.

| Nr. | Forum-Testfall | Zuordnung | Stand |
|---|---|---|---|
| 1 | Frische Installation, Standardnutzer startet, zweites Konto, Over-the-Shoulder-Erhöhung | TP-41 (zweites Konto, Over-the-Shoulder), TP-71 (Standardnutzer, VirtualStore, Version mit und ohne Adminrechte); Launcher: Spielordner und Standardwerte für andere Konten (R1) | ausgearbeitet |
| 2 | Versionsanzeige, MP-Beitritt ohne Versionskonflikt | TP-72, TP-70 (Version im Hauptmenü) | ausgearbeitet |
| 3 | Grafikmatrix mit und ohne Wrapper | TP-23 | ausgearbeitet |
| 4 | Farbtiefe 16 Bit, Reparatur stellt 32 Bit her | TP-73 (a: Registry, d: Einfrieren mit Weg B); Launcher: „Reset the Game“ (R4) | ausgearbeitet |
| 5 | Kompatibilitätsflags, Windows 7 | TP-20, TP-21 (Windows 7), TP-22 (alle Aufgaben, ohne `compatibility_windows`, ohne beide) | ausgearbeitet |
| 6 | Auflösungsgrenzen, 1024x600 | TP-60 | ausgearbeitet |
| 7 | AoC ohne vorherigen EE-Start | TP-74 | ausgearbeitet |
| 8 | Alt-Installation (CD, GOG) vorhanden | TP-61; Launcher: welche Installation er erkennt (Vertrag 1.4) | ausgearbeitet |
| 9 | EE und NeoEE parallel, eines deinstallieren | TP-62 (gleicher Ordner), TP-75 (getrennte Ordner) | ausgearbeitet |
| 10 | Firewall beim Hosten | TP-76 | ausgearbeitet |
| 11 | Hosting-Varianten, Portweiterleitung, zwei PCs hinter einem Router | Launcher: Netzwerkdiagnose (R7); Router und Portweiterleitung liegen außerhalb des Setups, dessen Firewall-Regeln prüft TP-76 | Launcher |
| 12 | Netzwerkadapter (VPN, Hamachi) | Launcher: Vergleich der Adapter (R7); das Setup wählt keinen Adapter | Launcher |
| 13 | CD-Keys: Server gesperrt, VM, `CDKeyCheck` | TP-77 | ausgearbeitet |
| 14 | Antivirus löscht Dateien | TP-50 | ausgearbeitet |
| 15 | Offline, nur Spiegel, manipulierter Download | TP-00, TP-10, TP-11, TP-16 | ausgearbeitet |
| 16 | Sprachen: Deutsch für EE und AoC | TP-78 | ausgearbeitet |
| 17 | Spielstände im Mehrspieler, Namen mit Sonderzeichen | Launcher: Export und Import der Spielstände, Namensprüfung (R10); das Setup fasst Spielstände nicht an | Launcher |
| 18 | Laufende Instanz | TP-79; Launcher: hängende Prozesse beim Start (R3) | ausgearbeitet |
| 19 | Kampagnen-Tribut | entfällt: Spiellogik der installierten Spieldateien, die das Setup unverändert installiert und nicht prüfen kann; ob die erwartete Version installiert ist, zeigt TP-72 | entfällt |
| 20 | Launcher: Spielerliste ohne Netz, beschädigte `user.config`, Pfad mit Umlauten | Launcher: der ganze Fall betrifft den Launcher | Launcher |
| 21 | GOG als Basis | TP-63 | ausgearbeitet |
| 22 | NeoEE-Wartungsmodus über kaputter Installation | TP-73 (c: NeoEE ohne `EE-AOC.exe` und `install.ini`, b: ohne Uninstall-Schlüssel) | ausgearbeitet |

## 10. Protokoll

Jeder Testlauf ist eine Zeile. Die Logs liegen unter `C:\EE-Test\logs` und heißen wie in
[Regel 6](#2-sicherheitsregeln).

| Datum | TP-ID | Build (Art, TestID, Commit) | Windows (Version, Build, VM/Laptop) | Variante | Ergebnis | Log-Datei | Bemerkung |
|---|---|---|---|---|---|---|---|
| 2026-mm-tt | TP-00 | keine | Windows 11 23H2, Laptop | - | bestanden / Abweichung / Fehler / nicht durchgeführt: Grund | - | |

„Abweichung“ heißt: Das Ergebnis weicht vom erwarteten ab, aber anders als ein Fehler (z. B.
ein anderer Text); in die Bemerkung gehört, was genau. Ergebnisse zurückmelden mit dieser
Tabelle und den Logs der betroffenen Läufe (vorher auf persönliche Daten ansehen, Regel 6).

Beim Kurzdurchlauf ([Abschnitt 7](#7-kurzdurchlauf-p1-und-freigabe)) nennt die Bemerkung den
Schritt (`K1` bis `K10`) und die P1-Teile, die die Zeile belegt; Beginn und Ende des Durchlaufs
stehen in der Bemerkung der ersten und der letzten Zeile. Unter der Tabelle steht das Ergebnis:
`Freigabe <Commit>: freigegeben` oder `nicht freigegeben: <TP-IDs mit Fehler>`, mit den
ausgenommenen P1-Teilen und ihrem Grund.

## 11. Automatische Prüfung dieses Dokuments

`python ci/check_test_plan.py` (auch im CI-Workflow) prüft:

- jede ID ist als Überschrift `#### TP-xy: …` genau einmal definiert,
- jeder Fall hat einen gültigen Status; ein ausgearbeiteter Fall hat alle Felder der Vorlage,
  ein geplanter mindestens `Priorität`, `Bezug` und `Ziel`,
- jeder Fall hat eine gültige Priorität: `P1`, `P2` oder `P3`, höchstens gefolgt von einer
  Bemerkung in Klammern ([Abschnitt 4](#4-vorlage-je-fall)),
- die Tabelle in [Abschnitt 9](#9-forum-testfälle-8) hat die Nummern 1 bis 22 je einmal, jede mit
  einer ID oder mit „Launcher“/„entfällt“ und Grund, und ihre Spalte „Stand“ passt zum Status der
  genannten Fälle,
- die Tabelle des Kurzdurchlaufs in [Abschnitt 7](#7-kurzdurchlauf-p1-und-freigabe) nennt in der
  Spalte „Fälle“ genau die Fälle mit der Priorität `P1` (keinen fehlt, keinen anderen), jede Zeile
  hat eine ganze Zahl in der Spalte „Minuten“, und die Zeile „Summe“ ist ihre Summe und höchstens
  180,
- jede ID, die in diesem Dokument, in der README, in `docs/ARCHITECTURE.md`, in den ADRs oder in
  einer anderen Markdown-Datei des Repositorys (außer `ci/`, `.github/` und den Asset-Ordnern)
  genannt wird, ist hier definiert, und jede ID hat genau zwei Ziffern (`TP-1x` meint einen
  Block und zählt nicht als ID).

`python ci/check_test_plan.py --self-test` prüft die Prüfung selbst mit veränderten Kopien.
