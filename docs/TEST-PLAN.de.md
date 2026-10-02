# Testplan: Empire Earth Community Setup v2 auf echtem Windows

Dieser Plan beschreibt die Handtests des Setups auf echtem Windows (Laptop des Testers und
virtuelle Maschinen). Er gehört zur Architektur in [ARCHITECTURE.md](ARCHITECTURE.md) (Abschnitt 8,
Teststrategie) und zu den Entscheidungen in [docs/adr](adr/README.md). Was das Setup für den
Launcher hinterlässt, steht in [CONTRACT.md](CONTRACT.md).

Stand: Gerüst aus Arbeitspaket S-WP2, Block 1 (Downloads, TP-10 bis TP-17) aus S-WP3, Block 2
(Kompatibilität und Grafik, TP-20 bis TP-24) aus S-WP4. Ausgearbeitet sind die
Server-Vorabprüfung [TP-00](#tp-00-server-vorabprüfung), die Fälle der Blöcke 1 und 2 und der
Grundablauf [TP-70](#tp-70-grundablauf-installieren-starten-deinstallieren).
Jedes weitere Arbeitspaket (S-WP5 bis S-WP8) arbeitet die Fälle seines Blocks aus, S-WP9
vervollständigt den Plan. Fälle, die noch nicht ausgearbeitet sind, tragen den Status
`geplant: S-WPx`. `ci/check_test_plan.py` prüft die Form dieses Dokuments (siehe
[Abschnitt 10](#10-automatische-prüfung-dieses-dokuments)).

Inhalt: [1. Zweck](#1-zweck) · [2. Sicherheitsregeln](#2-sicherheitsregeln) ·
[3. ID-Schema](#3-id-schema) · [4. Vorlage je Fall](#4-vorlage-je-fall) ·
[5. Testumgebungen und Snapshots](#5-testumgebungen-und-snapshots) ·
[6. Testbuild herstellen](#6-testbuild-herstellen) · [7. Testfälle](#7-testfälle) ·
[8. Forum-Testfälle §8](#8-forum-testfälle-8) · [9. Protokoll](#9-protokoll) ·
[10. Automatische Prüfung](#10-automatische-prüfung-dieses-dokuments)

## 1. Zweck

- Prüfen, was CI und Unit-Tests nicht prüfen können: das Laufzeitverhalten des Setups auf echtem
  Windows (Assistent, Downloads, Registry, installierte Dateien, Update, Reparatur,
  Deinstallation) und, mit echten Daten, ob das Spiel danach läuft.
- Jede Annahme der ADRs, die nur auf Windows prüfbar ist, bekommt einen Fall mit eigener ID
  (`TP-xy`). Abnahmekriterien der Arbeitspakete verweisen auf diese IDs, statt „auf Windows
  testen“ zu schreiben.
- Die Testfälle für echtes Windows aus der Forumsstudie (save-ee.com, Bericht Abschnitt 8,
  Nummern 1 bis 22) sind in [Abschnitt 8](#8-forum-testfälle-8) einer ID zugeordnet oder
  begründet ausgenommen.
- Nicht Teil dieses Plans: der Launcher (eigene Tests im Launcher-Repository) und der Betrieb der
  Dateiserver; nur deren Zustand prüft [TP-00](#tp-00-server-vorabprüfung) vorab.

## 2. Sicherheitsregeln

Vor jedem Testtag lesen. Diese Regeln gehen jedem einzelnen Fall vor.

1. **VM bzw. Snapshot.** Ein Placeholder-Build (Weg A, [6.2](#62-weg-a-placeholder-build)) läuft
   nur in einer virtuellen Maschine, in der Windows-Sandbox oder auf einem Snapshot, nie auf dem
   Laptop über eine echte Installation. Jeder Fall nennt seinen Ausgangs-Snapshot
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
4. **Testbuilds nie weitergeben.** Weder Weg A noch Weg B: nicht hochladen (auch nicht zu
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
Nummer ihres Blocks.

| IDs | Block | Paket | Inhalt |
|---|---|---|---|
| TP-00 | Vorabprüfung | S-WP2 | Zustand der beiden Dateiserver vor jedem Testtag mit Downloads |
| TP-1x | Downloads | S-WP3 | eingebaute Downloads statt IDP: Hauptserver ungültig und Spiegel (TP-10), offline (TP-11), Stopp-Knopf am ersten und am zweiten Server (TP-12, TP-13), Silent (TP-14), Koreanisch (TP-15), verworfener Download (TP-16), TLS 1.2 unter Windows 7 (TP-17) |
| TP-2x | Kompatibilität und Grafik | S-WP4 | Windows 7 ohne Kompatibilitätswerte (TP-20), Bereinigung beim Update unter Windows 7 (TP-21), Windows 10/11 unverändert (TP-22), Grafikmatrix mit und ohne DirectX-Wrapper (TP-23), 150 % Anzeigeskalierung mit und ohne `compatibility` (TP-24) |
| TP-3x | Build und Log | S-WP5 | SHA-256-Dateien der Setups, Setup-Log ohne `/LOG` |
| TP-4x | Installationseintrag und `install.ini` | S-WP6 | Registry-Eintrag, `install.ini`, Defaults-Marker, `SetupBuild`, Wert `ContractVersion` im Uninstall-Schlüssel |
| TP-5x | Integritätsmanifest | S-WP7 | `files.sha256`, Dateiprüfung nach der Installation, Dauer des Hashens |
| TP-6x | Umgebung | S-WP8 | niedrige Auflösung, fremde und alte Installationen, deren Ordner, EE und NeoEE in einem Ordner |
| TP-7x | Allgemeine Abläufe und Forumfälle | S-WP2, S-WP9 | Grundablauf, Standardnutzer, Version, Reparatur, Firewall, CD-Keys, Sprachen, laufendes Spiel |

## 4. Vorlage je Fall

Jeder Fall ist eine Überschrift `#### TP-xy: <Titel>` im Block seines Pakets (Abschnitt 7) mit
dieser Liste darunter. Ein ausgearbeiteter Fall hat alle Felder; ein geplanter Fall hat mindestens
`Status`, `Bezug` und `Ziel`.

```markdown
#### TP-xy: <Titel>

- **Status:** ausgearbeitet | geplant: S-WPn | entfällt: <Grund>
- **Bezug:** Anforderung (R…), ADR, Vertrag, Forum (§8 Nr., t=…/p=…)
- **Ziel:** was der Fall zeigen soll (ein Satz)
- **Build-Art:** A (Placeholder-Build) | B (echter Build) | A oder B | keine (kein Setup nötig)
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

## 5. Testumgebungen und Snapshots

| Snapshot | Inhalt | wofür |
|---|---|---|
| `S-Basis` | VM mit Windows 11 oder 10 (64 Bit), aktuelle Updates, kein Empire Earth, keine Reste alter Installationen; ein Administratorkonto und ein Standardkonto „Spieler“; Netzwerk an | Erstinstallation, Weg A und B |
| `S-Sandbox` | Windows-Sandbox (Windows 10/11 Pro): startet jedes Mal frisch, ohne 3D-Beschleunigung | schnelle Läufe mit Weg A (das Spiel startet dort nicht) |
| `S-172-EE`, `S-172-NeoEE` | `S-Basis` plus offizielles Setup 1.7.2 (EE bzw. NeoEE) als Administrator installiert, einmal gestartet | Update über 1.7.2, nur Weg B |
| `S-Win7` | VM mit Windows 7 SP1 (64 Bit), ohne KB3140245 und ohne SChannel-Änderungen | TLS 1.2 und Kompatibilitätswerte unter Windows 7 (S-WP3, S-WP4) |
| `S-Win7-172-EE` | `S-Win7` plus offizielles Setup 1.7.2 (EE) als Administrator mit „Empfohlene Einstellungen“ und AoC installiert, einmal gestartet | Update über 1.7.2 unter Windows 7 (TP-21), nur Weg B |
| `S-Alt` | `S-Basis` plus eine alte Installation: Original-CD unter `C:\Sierra\Empire Earth` bzw. GOG-Version | fremde und alte Installationen (S-WP8) |
| `Laptop` | das echte System des Testers, mit Wiederherstellungspunkt und Sicherung (Regel 1) | nur Weg B |

Die Windows-7-VM bekommt nur Fälle, die das ausdrücklich verlangen; sie hat keinen aktuellen
Browser, `TP-00` läuft deshalb auf dem Laptop.

## 6. Testbuild herstellen

Ein Testbuild ist ein Setup mit `TestID > 0`: schnelle Kompression (`zip/1`) und beim Start die
Warnung `TestSetupWarning` mit der Nummer. `MySetupVersion` bleibt `1.7.2`, damit die Update-API
den Testbuild nicht als veraltet meldet; Testbuilds unterscheidet ab S-WP6 der Wert `SetupBuild`
(`test<TestID>-<Commit>`).

### 6.1 Voraussetzungen (beide Wege)

- Windows 10 oder 11, Windows PowerShell 5.1 (eingebaut) oder PowerShell 7.
- Eine Arbeitskopie dieses Repositorys mit dem Stand, der getestet wird (Branch `v2`). Den Commit
  notieren (`git log -1 --oneline`), er kommt ins Protokoll.
- **Inno Setup 6.2.2**, genau diese Version (ADR 0002; neuere Versionen bauen dieses Skript nicht
  unverändert). Aus dem Download-Archiv von jrsoftware.org oder mit
  `choco install innosetup --version=6.2.2`. `ci\build.ps1` findet `ISCC.exe` im Standardordner
  `C:\Program Files (x86)\Inno Setup 6\`, sonst `-Iscc <Pfad>`; `-RequireVersion 6.2.2` bricht bei
  einer anderen Version ab.
- Python 3 nur für Weg A (`ci\make_placeholder_assets.py`; `python` im `PATH`, sonst
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
gibt es nur Weg A; Fälle mit Build-Art B kommen dann ins Protokoll als „nicht durchgeführt: keine
Daten“.

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

   Erwartet: die Warnung „Test build 1: … never distribute it“, dann `PASS EE/Regular -> …` für
   alle vier Varianten und `All 4 variant(s) built into …\out`, also
   `out\EE_Regular\EE_Setup_v1.7.2.exe`, `out\NeoEE_Regular\NeoEE_v2.0.0.5_Setup_v1.7.2.exe`,
   `out\EE_Portable\EE_Portable_Setup_v1.7.2.exe` und
   `out\NeoEE_Portable\NeoEE_Portable_v2.0.0.5_Setup_v1.7.2.exe`. In der Analyse (unter Wine)
   dauerte das rund vier Minuten; jedes Setup ist etwa 650 MB (EE) bzw. 700 MB (NeoEE) groß. Nur
   eine Variante: `-Variants EE/Regular`. Ohne `-TestID` entstünde ein Release-Build, der sich von
   einem veröffentlichten Setup nicht unterscheiden lässt: für Tests nie ohne `-TestID` bauen, nie
   signieren.
5. Nach der Testrunde `out\` löschen (Regel 4).

### 6.4 Silent-Tests

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

## 7. Testfälle

### Block 0: Vorabprüfung

#### TP-00: Server-Vorabprüfung

- **Status:** ausgearbeitet
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

### Block 2: Kompatibilität und Grafik (S-WP4)

Diese Fälle prüfen, was ADR 0005 und Vertrag 3.7 nur auf Windows zeigen können: Unter Windows 7
schreibt das Setup keine Kompatibilitätswerte mehr (außer dem freiwilligen `~ RUNASADMIN`) und
entfernt bei einem Update nur die Werte früherer Setups (TP-20, TP-21); unter Windows 10/11 bleibt
alles wie bisher (TP-22). Dazu kommen die Grafikmatrix mit und ohne DirectX-Wrapper (TP-23) und der
Fall 150 % Anzeigeskalierung mit und ohne Aufgabe `compatibility` (TP-24, Vertrag O4). Welche Werte
als „Werte früherer Setups“ gelten, entscheidet `IsLegacyVistaCompatValue`; die Unit-Tests in
`ci/tests/unit_tests.iss` decken alle Kombinationen ab.

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
  nur ab Windows 8; dort sind sie vorausgewählt. Ihre Seite „Zusätzliche Aufgaben auswählen“
  erscheint nur mit „Benutzerdefinierte Installationseinstellungen“. „Spiel immer als Administrator
  ausführen, für alle Benutzer …“ (`everyoneadminstart`) gibt es nur im Modus „admin“, sie ist nie
  vorausgewählt.
- Log-Zeilen der Bereinigung (`setup_is6.iss`, `RemoveLegacyVistaCompatValues`), nur unter
  Windows Vista/7:
  `Windows 6.1: this setup writes no compatibility values on Windows Vista/7, checking HKLM for values of earlier setups`
  (bzw. `HKCU`), danach je Spielprogramm eine der Zeilen `No compatibility value of <Pfad> (HKLM)`,
  `Removed the old Windows Vista/7 compatibility value "<Wert>" of <Pfad> (HKLM)`,
  `Kept the compatibility value "<Wert>" of <Pfad> (HKLM): not a value of an earlier setup` oder
  `Unable to remove the old Windows Vista/7 compatibility value "<Wert>" of <Pfad> (HKLM)`. Den
  alten Wert `~ RUNASADMIN` in HKCU (Modus „admin“, Setups bis 1.7.2) entfernt das Setup auf jeder
  Windows-Version: `Removed the old per-user RUNASADMIN flag of <Pfad>`.
- Spiel starten heißt in diesem Block: bis ins Hauptmenü, dann eine Zufallskarte gegen einen
  Computergegner etwa zwei Minuten spielen und beenden. Abstürze, Runtime-Fehler und schwarze
  Bildschirme mit Variante ins Protokoll (Forum t=4280 p=30477: „a long black screen and a runtime
  error“ im Kompatibilitätsmodus).

#### TP-20: Windows 7: Neuinstallation ohne Kompatibilitätswerte (nur VM)

- **Status:** ausgearbeitet
- **Bezug:** R15, ADR 0005, Vertrag 3.7; Forum §8 Nr. 5 (t=4280 p=30477 und p=30479, t=1827
  p=12147, t=5814)
- **Ziel:** Unter Windows 7 bietet das Setup die beiden Kompatibilitätsaufgaben nicht an und schreibt
  keinen Kompatibilitätswert, außer `~ RUNASADMIN` mit der freiwilligen Aufgabe; das Spiel startet
  ohne Werte.
- **Build-Art:** A oder B (Schritt 5 nur B)
- **Ausgangszustand:** Windows 7 SP1, kein Empire Earth, keine Werte für `Empire Earth.exe` und
  `EE-AOC.exe` (Schritt 1), Anzeigeskalierung 100 % (150 % prüft TP-24).
- **Snapshot:** `S-Win7` (nur VM, nie auf dem Laptop)
- **Varianten:** (a) EE-admin mit den angebotenen Aufgaben, (b) EE-admin mit `everyoneadminstart`,
  (c) EE-user. NeoEE und portable nutzen dieselben Einträge (portable wie user in HKCU) und werden
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
- **Erwartetes Ergebnis:**
  - Die Aufgabenseite zeigt weder „Kompatibilitätseinstellungen aktivieren“ noch
    „Kompatibilitätsmodus für ältere Windows-Versionen aktivieren“. „Spiel immer als Administrator
    ausführen …“ steht in (a) und (b) da und ist nicht vorausgewählt, in (c) fehlt es.
  - (a) und (c): Schritt 3 zeigt weder in HKLM noch in HKCU eine Zeile mit `Empire Earth.exe` oder
    `EE-AOC.exe`.
  - (b): In HKLM steht für beide Programme genau `~ RUNASADMIN`, z. B.
    `C:\Program Files (x86)\Empire Earth\Empire Earth\Empire Earth.exe    REG_SZ    ~ RUNASADMIN`;
    in HKCU nichts.
  - Schritt 5: Beide Spiele starten ohne Fehlermeldung, Runtime-Fehler oder schwarzen Bildschirm.
- **Log-Hinweis:** (a) `Windows 6.1: this setup writes no compatibility values on Windows Vista/7, checking HKLM for values of earlier setups`,
  dann zweimal `No compatibility value of … (HKLM)`; (b) zweimal
  `Kept the compatibility value "~ RUNASADMIN" of … (HKLM): not a value of an earlier setup` (der
  Wert dieses Laufs bleibt); (c) wie (a) mit `HKCU`. In keinem Lauf eine Zeile
  `Removed the old Windows Vista/7 compatibility value`.

#### TP-21: Windows 7: Update entfernt nur die Werte früherer Setups (nur VM)

- **Status:** ausgearbeitet
- **Bezug:** R15, ADR 0005 (Bereinigung, `IsLegacyVistaCompatValue`), Vertrag 3.7; Forum §8 Nr. 5
  („Unter Windows 7 besonders den Standardfall WINXPSP3 prüfen“)
- **Ziel:** Ein Update unter Windows 7 entfernt genau die Werte, die frühere Setups dort geschrieben
  haben (bei 1.7.2 der Wert von `EE-AOC.exe`), und lässt jeden anderen Wert stehen: einen, den der
  Spieler selbst gesetzt hat, und `~ RUNASADMIN`.
- **Build-Art:** (a) B; (b) A oder B
- **Ausgangszustand:** (a) offizielles Setup 1.7.2 (EE) unter Windows 7 als Administrator mit
  „Empfohlene Einstellungen“ und „Installiere Empire Earth und Die Kunst der Eroberungen -
  Erweiterung“ installiert, einmal gestartet; dazu ein eigener Wert des Spielers für
  `Empire Earth.exe` (Schritt 3). (b) Kein Empire Earth; die Werte früherer Setups werden mit
  `reg add` nachgestellt, für Tests ohne die Daten von Weg B.
- **Snapshot:** (a) `S-Win7-172-EE`; (b) `S-Win7` (nur VM, nie auf dem Laptop)
- **Varianten:** (a) EE-admin als Update an Ort und Stelle (NeoEE nutzt denselben Code); (b)
  EE-admin (HKLM) und EE-user (HKCU).
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

  4. Den Testbuild (Weg B, offizielle AppIds) mit `/LOG="C:\EE-Test\logs\TP-21a_EE-admin.log"`
     starten, „Aktuelle Installation aktualisieren“ bzw. „Vorhandene Installation reparieren“,
     Telemetrie aus, installieren, fertigstellen. Die `reg query`-Befehle wiederholen und AoC wie in
     Schritt 2 starten.
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
- **Erwartetes Ergebnis:**
  - (a) nach dem Update: kein Wert mehr für `EE-AOC.exe` in HKLM; für `Empire Earth.exe` in HKLM
    weiterhin `~ WINXPSP3 DISABLEDWM` (der Wert des Spielers); in HKCU keine der beiden
    `~ RUNASADMIN`-Zeilen mehr. AoC startet nach dem Update ohne Fehler; das Ergebnis aus Schritt 2
    steht zum Vergleich im Protokoll.
  - (b) admin: der Wert von `Empire Earth.exe` ist entfernt, `EE-AOC.exe` behält
    `~ WINXPSP3 DISABLEDWM`.
  - (b) user: der Wert von `Empire Earth.exe` ist entfernt, `EE-AOC.exe` behält `~ RUNASADMIN`.
  - Kein anderer Wert unter `AppCompatFlags\Layers` hat sich geändert (Ausgaben vorher und nachher
    vergleichen).
- **Log-Hinweis:** (a) `Removed the old Windows Vista/7 compatibility value "~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3" of …\EE-AOC.exe (HKLM)`,
  `Kept the compatibility value "~ WINXPSP3 DISABLEDWM" of …\Empire Earth.exe (HKLM): not a value of an earlier setup`
  und zweimal `Removed the old per-user RUNASADMIN flag of …`; (b) admin
  `Removed the old Windows Vista/7 compatibility value "~ RUNASADMIN DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WINXPSP3" of …\Empire Earth.exe (HKLM)`
  und `Kept the compatibility value "~ WINXPSP3 DISABLEDWM" of …\EE-AOC.exe (HKLM): …`; (b) user
  `Removed the old Windows Vista/7 compatibility value "~ WINXPSP3" of …\Empire Earth.exe (HKCU)` und
  `Kept the compatibility value "~ RUNASADMIN" of …\EE-AOC.exe (HKCU): …`.

#### TP-22: Windows 10/11: Kompatibilitätswerte unverändert

- **Status:** ausgearbeitet
- **Bezug:** R15, ADR 0005 (ab Windows 8 unverändert), Vertrag 3.4 und 3.7; Forum §8 Nr. 5 (t=5842
  p=39349, t=5748 p=38768)
- **Ziel:** Ab Windows 8 schreibt das Setup dieselben Werte wie vor S-WP4 (`WIN7RTM`, die Flags der
  Aufgabe `compatibility`, die GPU-Präferenz), ein Update entfernt keinen Kompatibilitätswert außer
  dem alten `~ RUNASADMIN` in HKCU, und das Spiel startet mit allen Aufgaben, ohne
  `compatibility_windows` und ohne beide.
- **Build-Art:** A oder B (Schritt 5 und Variante (e) nur B)
- **Ausgangszustand:** (a) bis (d) kein Empire Earth; (e) offizielles Setup 1.7.2 (EE) als
  Administrator installiert, einmal gestartet.
- **Snapshot:** (a) bis (d) `S-Basis`; (e) `S-172-EE`. Auf dem `Laptop` nur Weg B mit
  Wiederherstellungspunkt.
- **Varianten:** (a) EE-admin mit beiden Aufgaben, (b) EE-admin ohne `compatibility_windows`, (c)
  EE-admin ohne beide, (d) EE-user mit beiden, (e) EE-admin als Update über 1.7.2. NeoEE nutzt
  dieselben Einträge.
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
  4. (e) Auf `S-172-EE` die Ausgaben der `reg query`-Befehle notieren, den Testbuild (Weg B,
     offizielle AppIds) mit `/LOG="C:\EE-Test\logs\TP-22e_EE-admin.log"` und „Aktuelle Installation
     aktualisieren“ bzw. „Vorhandene Installation reparieren“ ausführen, danach dieselben Abfragen.
  5. Nur Weg B: nach (a), (b) und (c) Empire Earth und AoC je starten (siehe oben).
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
- **Log-Hinweis:** Keine Zeile `… this setup writes no compatibility values on Windows Vista/7 …`
  und keine Zeile `Removed the old Windows Vista/7 compatibility value`; bei (e) zweimal
  `Removed the old per-user RUNASADMIN flag of …`.

#### TP-23: Grafikmatrix mit und ohne DirectX-Wrapper

- **Status:** ausgearbeitet
- **Bezug:** ADR 0005 (Punkt 2: Wrapper-Vorauswahl bleibt, wählbar), Vertrag 3.3 (`Rasterizer Name`);
  Forum §8 Nr. 3 (t=5751, t=1862, t=1643, t=2884, t=5588, t=5887 p=39385; NeoEE-Einblendung
  t=10968 p=47345)
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
    Funktioniert die Vorauswahl schlechter als „Nativ“ oder ein anderer Wrapper, geht das mit
    Grafikchip und Treiber an die Maintainer (ADR 0005, Folgen: Die Wrapper-Frage bleibt für echte
    Tests offen).
- **Log-Hinweis:** `<Hersteller> GPU detected` bzw. `Unknown GPU detected` und
  `Using <Hersteller> GPU settings: additional\directx_wrapper\dx11_lvl11` (bzw. `…\dx11_lvl10_1`,
  `…\dx9`, `!additional\directx_wrapper` bei „Nativ“). Bei der benutzerdefinierten Installation
  steht die Auswahl im Uninstall-Schlüssel: `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v "Inno Setup: Selected Components" /reg:64`.

#### TP-24: 150 % Anzeigeskalierung mit und ohne Aufgabe compatibility

- **Status:** ausgearbeitet
- **Bezug:** Vertrag O4 und 3.3 (`Game Window Width`, `Game Window Height` in physischen Pixeln),
  ADR 0005 (Folgen: ohne `HIGHDPIAWARE` unter Windows 7), R15
- **Ziel:** Bei 150 % schreibt das Setup die Fenstergröße in physischen Pixeln, und es ist
  festgehalten, ob das Spiel mit `HIGHDPIAWARE` (Aufgabe `compatibility`) und ohne auf den
  Bildschirm passt, auch unter Windows 7, wo es die Aufgabe nicht mehr gibt.
- **Build-Art:** B (Schritte 1 und 2 auch A)
- **Ausgangszustand:** (a), (b) Windows 10/11, *Einstellungen › System › Anzeige › Skalierung* auf
  150 %, danach ab- und wieder angemeldet; (c) Windows 7, *Systemsteuerung › Anzeige* „Größer –
  150 %“, abgemeldet und wieder angemeldet. Physische Auflösung notieren (Windows 10/11:
  „Bildschirmauflösung“ auf derselben Seite; Windows 7: *Bildschirmauflösung*). Kein Empire Earth.
- **Snapshot:** (a), (b) `Laptop` (Weg B) oder `S-Basis`; (c) `S-Win7`
- **Varianten:** (a) EE-admin mit beiden Aufgaben (`HIGHDPIAWARE`), (b) EE-admin ohne
  „Kompatibilitätseinstellungen aktivieren“ (Wert `~ WIN7RTM`), (c) EE-admin unter Windows 7 (keine
  Werte).
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
  5. (c) Schritte 1 bis 3 auf `S-Win7` mit `TP-24c` (die Aufgabenseite zeigt keine
     Kompatibilitätsaufgaben).
- **Erwartetes Ergebnis:**
  - Schritt 2, alle Varianten: `Game Window Width` und `Game Window Height` sind die physische
    Auflösung, begrenzt auf 1024 bis 1920 bzw. 768 bis 1080 (bei 1920 × 1080: `0x780` und `0x438`,
    nicht die logischen 1280 × 720). Logische Werte sind ein Befund zu Vertrag O4.
  - Kompatibilitätswerte: (a) `~ DWM8And16BitMitigation HIGHDPIAWARE HeapClearAllocation WIN7RTM`,
    (b) `~ WIN7RTM`, (c) keiner.
  - Schritt 3 ist ein Befund, kein Bestanden/Nicht bestanden: je Variante und Spiel „passt“, „zu
    groß“ oder „zu klein“. Passt das Bild nur in (a), bekommt Vertrag 3.3 den Hinweis, dass die
    Fenstergröße nur mit `HIGHDPIAWARE` passt (Vertrag O4), und (c) ist die bekannte Folge von
    ADR 0005 für Windows 7 (README).
- **Log-Hinweis:** Das Setup schreibt die Bildschirmgröße nicht ins Log; maßgeblich sind die
  Registry-Werte aus Schritt 2. Bei (c) zusätzlich die Zeilen aus [TP-20](#tp-20-windows-7-neuinstallation-ohne-kompatibilitätswerte-nur-vm) (a).

### Block 3: Build und Log (S-WP5)

S-WP5 arbeitet hier aus, was ADR 0008 verlangt: SHA-256-Datei neben jedem Setup und ihre Prüfung
mit `Get-FileHash`, Setup-Log ohne `/LOG` unter `%TEMP%`.

#### TP-30: Prüfsumme des Setups und Setup-Log ohne Schalter

- **Status:** geplant: S-WP5
- **Bezug:** R14, ADR 0008
- **Ziel:** Die veröffentlichte SHA-256 passt zur Setup-Datei, und jedes Setup schreibt ein Log,
  ohne dass der Spieler `/LOG` kennen muss.

### Block 4: Installationseintrag und install.ini (S-WP6)

S-WP6 arbeitet hier aus, was ADR 0004 (Punkte 2, 9, 10) und Vertrag 1.1, 1.2, 3.5 verlangen:
Registry-Eintrag je Installationsmodus, `install.ini`, Defaults-Marker nur bei den regulären
Varianten, `SetupBuild`, der Wert `Empire Earth Community: ContractVersion` und sein Fehlen nach
einem älteren Setup.

#### TP-40: Installationseintrag und install.ini je Variante

- **Status:** geplant: S-WP6
- **Bezug:** D5, ADR 0004, Vertrag 1.1 und 1.2
- **Ziel:** Jede Variante hinterlässt genau den Eintrag und die `install.ini`, die der Vertrag
  beschreibt, und die Deinstallation entfernt sie wieder.

#### TP-41: Spieleinstellungen für ein zweites Konto

- **Status:** geplant: S-WP6
- **Bezug:** R1, ADR 0004 (Defaults-Marker), Vertrag 3.5; Forum §8 Nr. 1 (zweites Konto,
  Over-the-Shoulder-Erhöhung)
- **Ziel:** Zeigen, welche Spieleinstellungen das installierende Konto und welche ein zweites
  Konto bekommt, und dass der Marker nur beim installierenden Konto steht.

### Block 5: Integritätsmanifest (S-WP7)

S-WP7 arbeitet hier aus, was ADR 0004 (Punkte 3 bis 8) verlangt: `files.sha256` nach jeder
Installation, Dauer des Hashens (Schwelle: unter 30 s auf dem Testlaptop, keine Meldung „Keine
Rückmeldung“), Dateien, die während der Installation verschwinden.

#### TP-50: Von Antivirenprogrammen gelöschte Dateien

- **Status:** geplant: S-WP7
- **Bezug:** R2, R11, ADR 0004 (Punkt 7); Forum §8 Nr. 14 (t=11045, t=41147)
- **Ziel:** Fehlen wichtige Dateien nach der Installation, nennt das Setup sie und rät zu einer
  Ausnahme im Virenscanner und zur Reparatur.

### Block 6: Umgebung (S-WP8)

S-WP8 arbeitet hier aus, was ADR 0007 verlangt: Hinweis bei einer Bildschirmhöhe unter 768,
gefundene fremde oder alte Installationen, Fragen `ForeignFolderQuestion` und
`SharedFolderQuestion`, im Silent-Modus nur Log.

#### TP-60: Niedrige Bildschirmauflösung

- **Status:** geplant: S-WP8
- **Bezug:** R13, ADR 0007 (Punkt 1); Forum §8 Nr. 6 (t=3863, t=5831)
- **Ziel:** Unter 768 Pixeln Höhe warnt das Setup; die Fenstergröße bleibt auf 1024 bis 1920 mal
  768 bis 1080 begrenzt.

#### TP-61: Alte Installation vorhanden

- **Status:** geplant: S-WP8
- **Bezug:** R12, ADR 0007 (Punkt 2); Forum §8 Nr. 8 (t=1036 p=4756, t=12082 p=49553)
- **Ziel:** Das Setup meldet eine alte CD- oder GOG-Installation, ändert nichts an ihr und
  erwähnt, dass `Software\Sierra\CDKeys` beim Aufräumen bleiben muss.

#### TP-62: EE und NeoEE im selben Ordner

- **Status:** geplant: S-WP8
- **Bezug:** ADR 0007 (Punkt 3), Vertrag O11; Forum §8 Nr. 9
- **Ziel:** Die Frage `SharedFolderQuestion` erscheint, und die Folgen (Integritätsprüfung,
  Deinstallation, Firewall-Regeln) treten wie beschrieben ein.

#### TP-63: Installation in den Ordner einer GOG- oder CD-Installation

- **Status:** geplant: S-WP8
- **Bezug:** ADR 0007 (Punkt 4); Forum §8 Nr. 21 (t=5733, t=5727, t=12082)
- **Ziel:** Die Frage `ForeignFolderQuestion` erscheint mit „anderen Ordner wählen“ als Vorgabe;
  in einen eigenen Ordner installiert, laufen GOG- und Community-Version nebeneinander.

### Block 7: Allgemeine Abläufe und Forumfälle

#### TP-70: Grundablauf: installieren, starten, deinstallieren

- **Status:** ausgearbeitet
- **Bezug:** Grundlage aller anderen Fälle; README „Build switches“ (`TestID`); Vertrag 1.3
  (Uninstall-Schlüssel); Forum §8 Nr. 2 (Version, nur Startbild)
- **Ziel:** Ein Testbuild installiert sich vollständig, das Spiel startet (Weg B), und die
  Deinstallation räumt auf. Jeder andere Fall setzt voraus, dass dieser besteht.
- **Build-Art:** A oder B (Schritt 6 nur B)
- **Ausgangszustand:** (a) Erstinstallation: kein Empire Earth installiert. (b) Update, nur
  Weg B: offizielles Setup 1.7.2 desselben Produkts als Administrator installiert.
- **Snapshot:** (a) `S-Basis` oder `S-Sandbox` (nur Weg A); (b) `S-172-EE` bzw. `S-172-NeoEE`.
  Auf dem `Laptop` nur Weg B und nur mit Wiederherstellungspunkt.
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
     Grafikkarte wie vorgeschlagen, Zielordner unverändert, installieren, „Fertigstellen“. Bei Weg A ist die Meldung zu `dxwebsetup.exe` erwartet
     ([6.2](#62-weg-a-placeholder-build)); wer sie vermeiden will, nimmt die benutzerdefinierten
     Einstellungen und wählt dort die Aufgabe „DirectX-Endbenutzer-Runtime installieren“ ab.
  5. Prüfen (Eingabeaufforderung):
     `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{<AppId>}_is1" /v DisplayName /reg:64`
     (bei „user“ `HKCU\Software\…` ohne `/reg:64`; bei Weg A die Platzhalter-AppId), und im
     Explorer den Spielordner mit `Empire Earth\Empire Earth.exe`,
     `Empire Earth - The Art of Conquest\EE-AOC.exe` und dem versteckten Ordner
     `_setupdata_EE` bzw. `_setupdata_NeoEE`.
  6. Nur Weg B: Empire Earth und The Art of Conquest je einmal bis ins Hauptmenü starten, die
     angezeigte Version notieren, beenden.
  7. Deinstallieren: `"<Installationsordner>\unins000.exe" /LOG="C:\EE-Test\logs\TP-70_EE-admin_uninstall.log"`.
- **Erwartetes Ergebnis:**
  - Die Testwarnung nennt `ID = 1`, Setup-Version 1.7.2 und die Spielversion. Außer ihr, der
    Rechtsfrage bei (a), dem Hinweis zum Benutzermodus bei „user“ und den bekannten Grenzen von
    Weg A ([6.2](#62-weg-a-placeholder-build)) erscheint keine Fehlermeldung. Ausnahme NeoEE in
    einer VM mit Weg B: Die CD-Key-Registrierung kann die VM erkennen und `CDKeysErrorVM` melden
    (das prüft TP-77); die Installation läuft trotzdem zu Ende.
  - Schritt 5: `DisplayName` ist `Empire Earth v2.0.0.0 - Setup v1.7.2` bzw.
    `NeoEE v2.0.0.5 - Setup v1.7.2`; Spielordner und `_setupdata_<Produkt>` existieren. Bei (b)
    gibt es unter „Apps“ genau einen Eintrag des Produkts, der Zielordner ist der der Installation
    1.7.2, und der alte versteckte Ordner `<Spielordner>\<AppId>` ist entfernt. Portable: kein
    Uninstall-Schlüssel, Ordner `Empire Earth Portable` bzw. `Neo Empire Earth Portable` neben dem
    Setup.
  - Schritt 6: Beide Spiele erreichen das Hauptmenü ohne Fehlermeldung.
  - Schritt 7: Der Eintrag unter „Apps“ und der Uninstall-Schlüssel sind weg; im Spielordner
    bleiben höchstens Dateien, die das Spiel selbst angelegt hat; `Software\Sierra\CDKeys` ist
    unverändert (NeoEE).
- **Log-Hinweis:** Das Setup-Log enthält `Installation process succeeded.` und keine Zeile mit
  `Exception` oder `Runtime error`. Bei Weg A erklären die Zeilen zu `dxwebsetup.exe` bzw.
  `authtools.dll` die erwarteten Hinweise. Bei Problemen beide Logs ins Protokoll.

#### TP-71: Als Administrator installieren, als Standardbenutzer spielen

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 1 (t=3001 p=22273, VirtualStore), Launcher R8
- **Ziel:** Ob unter `%LOCALAPPDATA%\VirtualStore\…\Empire Earth` Dateien entstehen
  (`_won*`, `neoee.log`, `upnp_info.txt`) und ob die Version im Hauptmenü mit und ohne
  „Als Administrator“ gleich ist.

#### TP-72: Versionsanzeige und Mehrspieler zwischen zwei Installationen

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 2 (t=11034 p=47982), Forum 4.12
- **Ziel:** EE und AoC zeigen den erwarteten NeoEE-Stand, und zwei Setup-Installationen treten
  einem Mehrspielerspiel ohne Versionskonflikt bei.

#### TP-73: Reparatur durch erneutes Ausführen des Setups

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 4 (t=10931, 16 Bit) und Nr. 22 (t=5825, t=10915, t=11034),
  Vertrag 4
- **Ziel:** Ein erneuter Lauf über eine veränderte oder teilweise beschädigte Installation stellt
  die Dateien und die Spieleinstellungen (z. B. 32 Bit) wieder her, ohne in die Sackgasse
  „nur Ändern/Reparieren/Entfernen“ zu führen.

#### TP-74: AoC ohne vorherigen Start von EE

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 7 (t=2825), Forum 4.5
- **Ziel:** The Art of Conquest startet direkt nach der Installation, weil das Setup
  `Installed From` setzt.

#### TP-75: EE und NeoEE in getrennten Ordnern, eines deinstallieren

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 9
- **Ziel:** Nach der Deinstallation eines Produkts bleiben Firewall-Regeln, CD-Keys und Registry
  des anderen erhalten.

#### TP-76: Firewall-Regeln beim Hosten

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 10, Forum 4.9
- **Ziel:** Mit der Aufgabe `firewallexception` kommen Mitspieler ohne Windows-Firewall-Dialog ins
  gehostete NeoEE-Spiel, im Netzwerkprofil „Öffentlich“ und „Privat“; Gegenprobe ohne Aufgabe.

#### TP-77: NeoEE-CD-Keys bei gesperrtem Server und in einer VM

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 13 (t=10950), Forum 4.19
- **Ziel:** Bei gesperrtem `neoee.net:10003` und in einer VM erscheint die passende verständliche
  Meldung; `CDKeyCheck` in `WONLobby.cfg` steht auf `true`; `Software\Sierra\CDKeys` wird nie
  gelöscht.

#### TP-78: Deutsche Sprachversion von EE und AoC

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 16 (t=1610, t=4726, t=11041, t=1905) und Nr. 13 des Problemabgleichs
- **Ziel:** Mit Deutsch sind Space Age und die Spezial-Zivilisationen von AoC wählbar und die
  deutschen Kampagnen starten.

#### TP-79: Setup bei laufendem Spiel

- **Status:** geplant: S-WP9
- **Bezug:** Forum §8 Nr. 18 (t=2815, t=5859)
- **Ziel:** Läuft EE oder AoC, verhindert das Setup die Installation (`AppMutex`) mit einem
  verständlichen Hinweis.

## 8. Forum-Testfälle §8

Zuordnung der Testfälle für echtes Windows aus dem Forumsbericht (Abschnitt 8, „Testfälle für
echtes Windows“). „Launcher“ heißt: Der Fall prüft den Launcher und gehört in dessen Testplan;
„entfällt“: Das Setup hat mit dem Fall nichts zu tun. Beides steht mit Grund in der Spalte
„Zuordnung“. Die Spalte „Stand“ folgt dem Status der genannten Fälle.

| Nr. | Forum-Testfall | Zuordnung | Stand |
|---|---|---|---|
| 1 | Frische Installation, Standardnutzer startet, zweites Konto, Over-the-Shoulder-Erhöhung | TP-41, TP-71; Launcher: Spielordner und Standardwerte für andere Konten (R1) | geplant: S-WP6, S-WP9 |
| 2 | Versionsanzeige, MP-Beitritt ohne Versionskonflikt | TP-72, TP-70 (Version im Hauptmenü) | ausgearbeitet: TP-70; geplant: S-WP9 |
| 3 | Grafikmatrix mit und ohne Wrapper | TP-23 | ausgearbeitet |
| 4 | Farbtiefe 16 Bit, Reparatur stellt 32 Bit her | TP-73; Launcher: „Reset the Game“ (R4) | geplant: S-WP9 |
| 5 | Kompatibilitätsflags, Windows 7 | TP-20, TP-21 (Windows 7), TP-22 (alle Aufgaben, ohne `compatibility_windows`, ohne beide) | ausgearbeitet |
| 6 | Auflösungsgrenzen, 1024x600 | TP-60 | geplant: S-WP8 |
| 7 | AoC ohne vorherigen EE-Start | TP-74 | geplant: S-WP9 |
| 8 | Alt-Installation (CD, GOG) vorhanden | TP-61; Launcher: welche Installation er erkennt (Vertrag 1.4) | geplant: S-WP8 |
| 9 | EE und NeoEE parallel, eines deinstallieren | TP-62 (gleicher Ordner), TP-75 (getrennte Ordner) | geplant: S-WP8, S-WP9 |
| 10 | Firewall beim Hosten | TP-76 | geplant: S-WP9 |
| 11 | Hosting-Varianten, Portweiterleitung, zwei PCs hinter einem Router | Launcher: Netzwerkdiagnose (R7); Router und Portweiterleitung liegen außerhalb des Setups, dessen Firewall-Regeln prüft TP-76 | Launcher |
| 12 | Netzwerkadapter (VPN, Hamachi) | Launcher: Vergleich der Adapter (R7); das Setup wählt keinen Adapter | Launcher |
| 13 | CD-Keys: Server gesperrt, VM, `CDKeyCheck` | TP-77 | geplant: S-WP9 |
| 14 | Antivirus löscht Dateien | TP-50 | geplant: S-WP7 |
| 15 | Offline, nur Spiegel, manipulierter Download | TP-00, TP-10, TP-11, TP-16 | ausgearbeitet |
| 16 | Sprachen: Deutsch für EE und AoC | TP-78 | geplant: S-WP9 |
| 17 | Spielstände im Mehrspieler, Namen mit Sonderzeichen | Launcher: Export und Import der Spielstände, Namensprüfung (R10); das Setup fasst Spielstände nicht an | Launcher |
| 18 | Laufende Instanz | TP-79; Launcher: hängende Prozesse beim Start (R3) | geplant: S-WP9 |
| 19 | Kampagnen-Tribut | entfällt: Spiellogik der installierten Spieldateien, die das Setup unverändert installiert und nicht prüfen kann; ob die erwartete Version installiert ist, zeigt TP-72 | entfällt |
| 20 | Launcher: Spielerliste ohne Netz, beschädigte `user.config`, Pfad mit Umlauten | Launcher: der ganze Fall betrifft den Launcher | Launcher |
| 21 | GOG als Basis | TP-63 | geplant: S-WP8 |
| 22 | NeoEE-Wartungsmodus über kaputter Installation | TP-73 | geplant: S-WP9 |

## 9. Protokoll

Jeder Testlauf ist eine Zeile. Die Logs liegen unter `C:\EE-Test\logs` und heißen wie in
[Regel 6](#2-sicherheitsregeln).

| Datum | TP-ID | Build (Art, TestID, Commit) | Windows (Version, Build, VM/Laptop) | Variante | Ergebnis | Log-Datei | Bemerkung |
|---|---|---|---|---|---|---|---|
| 2026-mm-tt | TP-00 | keine | Windows 11 23H2, Laptop | - | bestanden / Abweichung / Fehler / nicht durchgeführt: Grund | - | |

„Abweichung“ heißt: Das Ergebnis weicht vom erwarteten ab, aber anders als ein Fehler (z. B.
ein anderer Text); in die Bemerkung gehört, was genau. Ergebnisse zurückmelden mit dieser
Tabelle und den Logs der betroffenen Läufe (vorher auf persönliche Daten ansehen, Regel 6).

## 10. Automatische Prüfung dieses Dokuments

`python ci/check_test_plan.py` (auch im CI-Workflow) prüft:

- jede ID ist als Überschrift `#### TP-xy: …` genau einmal definiert,
- jeder Fall hat einen gültigen Status; ein ausgearbeiteter Fall hat alle Felder der Vorlage,
  ein geplanter mindestens `Bezug` und `Ziel`,
- die Tabelle in [Abschnitt 8](#8-forum-testfälle-8) hat die Nummern 1 bis 22 je einmal, jede mit
  einer ID oder mit „Launcher“/„entfällt“ und Grund, und ihre Spalte „Stand“ passt zum Status der
  genannten Fälle,
- jede ID, die in diesem Dokument, in der README, in `docs/ARCHITECTURE.md`, in den ADRs oder in
  einer anderen Markdown-Datei des Repositorys (außer `ci/`, `.github/` und den Asset-Ordnern)
  genannt wird, ist hier definiert, und jede ID hat genau zwei Ziffern (`TP-1x` meint einen
  Block und zählt nicht als ID).

`python ci/check_test_plan.py --self-test` prüft die Prüfung selbst mit veränderten Kopien.
