# Schiefer

Motif/CDE-artiges Erscheinungsbild für KDE Plasma 6, abgeleitet von Breeze. Abstände und Verhalten bleiben bei
Breeze, nur das Zeichnen ist ersetzt: 2-px-Kanten (hell oben links, dunkel unten rechts), versenkte Felder,
erhabene Knöpfe, helles Schieferblau-grau.

Git-Repository (Branch `main`, lokal, kein Remote). Stand: **Version 0.4** (neu: Farbkern nach Motif, fünf Paletten,
Hintergrund-Plugin je Arbeitsfläche, Mauszeiger, Fensterwechsler, Rauten, `schiefer-config`); über das lokale
Gentoo-Overlay laufen ältere Versionen auf dem Desktop (amd64) und dem MacBook Air mit Gentoo Asahi (arm64).

Grundsatz seit 0.4: Jede Motif-Eigenheit, die sich sinnvoll abschalten lässt, hat einen Schalter
(`schiefer-config`, siehe unten); Vorgabe ist das Motif-Verhalten.

## Aufbau

| Ordner / Datei | Inhalt |
|---|---|
| `colors/*.colors` | Farbschemata Schiefer, Sandstein, Jade, Granit, Basalt (dunkel), erzeugt von `palettes/make_palette.py` aus `palettes/*.toml` (eingecheckt, das Ebuild braucht den Generator nicht). Helle Paletten: Fensterhintergrund `qGray ≥ 192`, sonst schalten GTK/Firefox auf dunkel. Eigene Gruppe `[Schiefer]` mit den CDE-Rollen Color1–8, `FrontPanel` und `DesktopColors` (KDE kopiert sie nicht nach kdeglobals – Leser öffnen die Schemadatei). |
| `common/` | Farbkern: Motif-Formel für Licht/Schatten/Auswahl, exakt nach Motif 2.3.8 `lib/Xm/Color.c` (LGPL-2.1+), als `schiefercolors.h` (Deko, Qt-Stil, Dock) und `schiefercolors.py` (Plasma-Stil, Paletten); Test `test_colors.py`. GTK nähert die Formel mit festen `mix()`-Anteilen (`gtk/tools/retro_colors.py` misst die Abweichung), der Fensterwechsler hat eine geprüfte JS-Fassung (`kwin/tabbox/schiefer/contents/ui/motif.js`). |
| `cursors/make_cursors.py` | Mauszeiger „Schiefer“: moderne Vektor-Fassung der X11-Kernzeiger (left_ptr, Taschenuhr, xterm-Balken …), Nenngröße 24 wie Breeze, kantengeglättet ohne Pixel-Vergrößerung; reines Python (eigener Rasterer): 41 Zeiger + 89 Aliase, XCursor 24–96 px und SVG für Wayland; `--preview bild.png` (braucht PIL) zeigt alle |
| `kwin/tabbox/schiefer/` | Fensterwechsler (Alt+Tab) als schmale Motif-Liste; Testhilfe `kwin/test/tab6.sh` (Alt+Tab per libei in der Testsitzung) |
| `wallpaper/plugin/` | Hintergrund-Plugin `org.kde.schiefer.backdrop`: Muster und Farbe je Arbeitsfläche (CDE), pixelgenau bei jeder Skalierung, wahlweise Überblenden; Farben schreibt `schiefer-config palette` |
| `tools/schiefer-config` | Schalter und Paletten umschalten (installiert als `/usr/bin/schiefer-config`) |
| `kdecoration/` | Fensterdekoration (eigener C++-Code, Plugin-ID `schiefer`) |
| `kstyle/` | Qt-Widget-Stil, Fork von Breeze 6.7.6 (Schlüssel `Schiefer`) – Update siehe `UPSTREAM.md` |
| `make_theme.py` | erzeugt das Icon-Theme `schiefer` aus breeze-icons (SVGs umgefärbt, Schärfe wie Breeze; `--dither`: 56-Farben-Palette + Schachbrett-Dithering als Vektor-Maske, siehe `dither.py`) |
| `plasma/make_plasma_theme.py` | erzeugt den Plasma-Stil `schiefer` (SVG-Rahmenstücke) |
| `gtk/Schiefer/` | GTK3/4-Theme: importiert Breeze-GTK, `retro.css` überschreibt das Zeichnen; abschaltbare Teile als `opt-*.css`, Liste in `optionen.txt` |
| `wallpaper/` | Muster (`tiles/`, gewählt: Köper), Hintergrundpaket-Generator, `apply.sh` (= `schiefer-wallpaper`) |
| `lookandfeel/` | globales Design „Schiefer“ (Farben, Plasma-Stil, Icons, Qt-Stil, Deko, Zeiger, Fensterwechsler, Bild-Hintergrund; nicht GTK und keine Plasma-Schalter – danach `schiefer-config standard`) |
| `packaging/` | Ebuild-Vorlagen für `x11-themes/schiefer{,-kde,-icons,-themes,-dock,-backdrop}`: `-themes` = Farbschemata, Plasma-Stil, GTK, Zeiger, Fensterwechsler, Bild-Hintergrund; `-backdrop` = Hintergrund-Plugin; `schiefer` = Look-and-Feel, `schiefer-config`, Metapaket |
| `dock/` | Plasma-Widgets im CDE/Motif-Stil: `org.kde.schiefer.drawer` (Starter mit Schublade, Uhr, Kalenderblatt, Ordner – zeigt den Inhalt eines Ordners, z. B. des Schreibtischs –, optional Systemabschnitt), `org.kde.schiefer.console` (Arbeitsflächen, Sperren, Startlampe, EXIT; Fensterknöpfe abschaltbar), `org.kde.schiefer.iconbox` (Fensterliste als Icon-Manager wie bei twm oder als Icon Box wie bei mwm; Zustand über das Relief, Fenster einer Anwendung gruppiert mit seitlicher Schublade, auf Wunsch Abschnitte je Arbeitsfläche; `SCHIEFER_DOCK_OPEN=<Programm>` klappt im Test eine Gruppe auf), `org.kde.schiefer.endcap` (rein dekorative Abschlussstücke links und rechts wie die Griffe am CDE-Frontpanel; `dock/add-endcaps.js` fügt sie in eine vorhandene Leiste ein), `org.kde.schiefer.tiles` (Systemabschnitt als Kacheln wie Window-Maker-Dockapps; braucht einen ausgeblendeten Plasma-Systray in derselben Leiste; die Kacheln messen ihre Lage im Leistenfenster und sitzen mit 3 px Rand mittig zwischen den sichtbaren Kanten, weil Plasmas Applet-Polster die Kante nicht kennt). `dock/layout.js` baut Dock unten, Icon Box links und Kacheln rechts oben, die beiden letzten im Modus „Fenstern ausweichen“ (entfernt vorhandene Leisten unten, links und rechts!) |
| `tools/` | Test- und Paketwerkzeuge (siehe unten) |
| `src/` | entpackte Upstream-Quellen zum Nachschlagen (Breeze, libplasma, kde-gtk-config …), nicht Teil des Pakets |

## Schalter und Paletten: `schiefer-config`

```bash
schiefer-config                   # Liste: Schalter, Zustand, Vorgabe, Beschreibung
schiefer-config raute aus         # Schalter setzen, wirkt sofort (soweit das Programm neu lädt)
schiefer-config standard          # alle Schalter auf die Motif-Vorgabe (z. B. nach dem globalen Design)
schiefer-config palette basalt    # Farbschema + Arbeitsflächenfarben (schiefer, sandstein, jade, granit, basalt)
schiefer-config schrift helvetica # Nimbus Sans / TeX Gyre Heros wie bei CDE; zurück: schrift noto
```

| Schalter | Vorgabe | wirkt auf | gespeichert in |
|---|---|---|---|
| `raute` | an | Optionsfelder als Raute (Qt + GTK) | `schieferrc [Style] RadioDiamond`, GTK-Überlagerung |
| `animationen` | aus | Breeze-Übergänge im Qt-Stil | `schieferrc [Style] AnimationsEnabled` |
| `plasma-animationen` | an | KWin/Plasma-Animationen | `kdeglobals [KDE] AnimationDurationFactor` |
| `doppelklick-schliessen` | an | Doppelklick auf Menüknopf schließt (Einfachklick öffnet das Menü dann nach der Doppelklickzeit) | `schieferrc [Decoration] DoubleClickClose` |
| `eckgriffe` | an | Rahmenecken bis zur Kerbe ziehen diagonal | `schieferrc [Decoration] MotifCorners` |
| `kopfleiste` | an | Motif-Kopfleiste für GTK-Programme mit CSD | GTK-Überlagerung |
| `arbeitsbereichsmenue` | an | Rechtsklick auf Arbeitsfläche = Programmmenü | appletsrc `[ActionPlugins][0]` |
| `fensterliste` | an | Mittelklick auf Arbeitsfläche = Fensterliste | appletsrc `[ActionPlugins][0]` |
| `fensterwechsler` | an | Alt+Tab im Motif-Stil | `kwinrc [TabBox] LayoutName` |
| `kicker` | an | Programmmenü mit Untermenüs statt Kickoff (gleiche Stelle, Symbol bleibt) | Leiste |
| `muster-hintergrund` | an | Hintergrund-Plugin statt Bild | Arbeitsflächen |
| `je-arbeitsflaeche` | an | eigenes Muster/eigene Farbe je Arbeitsfläche | Plugin `PerDesktop` |
| `ueberblenden` | aus | beim Wechsel überblenden statt sofort | Plugin `Crossfade` |
| `mauszeiger` | an | Schiefer-Zeiger statt Breeze | `kcminputrc [Mouse] cursorTheme` |

GTK-Optionen arbeiten über eine Überlagerung `~/.local/share/themes/Schiefer/` (importiert per absolutem Pfad die
installierten Teile ohne die abgeschalteten `opt-*.css`; sind alle Optionen auf Vorgabe, wird sie gelöscht).
Plasma-Schalter brauchen eine laufende Plasma-Sitzung (`evaluateScript`). Ohne Plasma zeigt die Liste `?`.

## Neue Version ausrollen

```bash
echo 0.4 > VERSION
tools/install-overlay.sh          # packt dist/, dann per sudo: Overlay /var/db/repos/local, digest, root:root, 644/755
sudo emerge -av x11-themes/schiefer
```
MacBook: `tools/make-dist.sh`, `dist/` hinüberkopieren, dort `dist/install-overlay.sh`.
Nach Deko-Änderungen: `kwin_wayland --replace &`.

## Testen ohne die laufende Sitzung anzufassen

- `tools/screenshot.sh out.png [programm …]` – eigene KWin-Sitzung mit eigenem D-Bus, Deko, Qt-Stil,
  Farben, GTK-Theme und Plasma-Stil aus dem Projekt. Beispiele:
  - `tools/screenshot.sh /tmp/a.png dolphin kwrite`
  - `tools/screenshot.sh /tmp/a.png plasmashell` (+ `BR_SHELL_CMD="qdbus6 org.kde.plasmashell /PlasmaShell activateLauncherMenu"`)
  - `tools/screenshot.sh /tmp/a.png "plasmawindowed org.kde.plasma.volume"`
  - `tools/screenshot.sh /tmp/a.png "python3 $PWD/gtk/test/gallery3.py --popover"` (GTK4: `gallery4.py`)
  - frisch erzeugte Icons prüfen: `python3 make_theme.py --out /tmp/ic && BR_ICON_DIR=/tmp/ic tools/screenshot.sh /tmp/a.png dolphin` (als Theme „schiefer-test“, das installierte bleibt unberührt)
  - Dock: `BR_WIDTH=1920 BR_HEIGHT=1080 BR_DESKTOPS=4 BR_SHELL_CMD="qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript \"\$(cat $PWD/dock/layout.js)\"" tools/screenshot.sh /tmp/a.png plasmashell`
    (`SCHIEFER_DOCK_OPEN=<Schubladentitel>` öffnet eine Schublade, `SCHIEFER_DOCK_TRAY=<itemId>` z. B. `org.kde.plasma.volume` öffnet das Popup eines Systray-Eintrags, `=more` die Liste der Statuskacheln, `BR_LOG=datei` sammelt die Ausgaben)
  - Varianten: `BR_GTK_THEME=Breeze`, `BR_COLORS=andere.colors`
  - zusätzliche Datenverzeichnisse: `BR_DATA_DIRS=$PWD/wallpaper/plugin/build/data:…` (Hintergrund-Plugin, Ordner mit
    `color-schemes/` für die Paletten, `kwin-wayland/tabbox/schiefer` als Symlink, `icons/Schiefer` aus `make_cursors.py --out`)
  - `schiefer-config` in der Testsitzung: `BR_SHELL_CMD="tools/schiefer-config standard"` (schreibt nur in die
    Test-Konfiguration; `XDG_CONFIG_HOME`/`XDG_DATA_HOME` zeigen dort auf temporäre Ordner)
  - Fensterwechsler: `B=/tmp/tb BR_DATA_DIRS=<Ordner mit kwin-wayland/tabbox/schiefer> BR_SHELL_CMD="B=/tmp/tb bash $PWD/kwin/test/tab6.sh" tools/screenshot.sh /tmp/a.png dolphin kwrite` (Bilder `/tmp/tb/tab1.png` …)
  - Skalierung: `BR_SCALE=1.5 tools/screenshot.sh /tmp/a.png kwrite` (setzt die virtuelle Ausgabe per kscreen-doctor auf 1,5; BR_WIDTH/BR_HEIGHT bleiben logisch, das Bild wird größer)
- `kstyle/render.sh out.png` – Qt-Galerie offscreen (`SCHIEFERRC=datei` für andere Schalter)
- `python3 common/test_colors.py` – Farbkern gegen die Motif-Referenzwerte; `kdecoration/test/` – Deko-Tests mit Mock-Klassen
- Bauen für Tests: `cmake -S kstyle -B kstyle/build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON`
  (ebenso `kdecoration`, `dock` und `wallpaper/plugin`; die Dock-Applets landen in `dock/build/bin/plasma/applets`), danach Symlinks `kstyle/build/plugins/styles/schiefer6.so` und
  `kdecoration/build/plugins/org.kde.kdecoration3/schiefer.so` auf `../../bin/…`.
  Für `gtk/tools` und `plasma/tools` jeweils `cmake -S … -B …/build -G Ninja` (Hilfsprogramme `gtkcolors`, `svgbounds`).

## Wissenswertes

- Plasma 6.7 kann Bild-Hintergründe nicht kacheln – deshalb das eigene Hintergrund-Plugin (Shader, pixelgenau).
  Das Bildpaket und `schiefer-wallpaper` bleiben für den Sperrbildschirm und als Rückfall.
- Das Farbschema hat absichtlich keine `[Colors:Header]`-Gruppe: so übernehmen GTK-Kopfleisten (Firefox usw.)
  die Titelleistenfarbe aus `[WM]`.
- Firefox/Thunderbird zeichnen Leisten und Formulare selbst; sie übernehmen Farben und Hell/Dunkel,
  keine Motif-Kanten (möglich wäre eine eigene `userChrome.css`).
- GTK-Kopfleisten (`opt-kopfleiste.css`): Titel im erhabenen Feld, eckige erhabene Fensterknöpfe; die Kerben des
  KWin-Rahmens kann CSS nicht nachbilden.
- Plasma-Mausaktionen heißen teils ohne `org.kde.`-Präfix (`switchwindow`); unbekannte Namen verwirft Plasma still.
- Leistenreihenfolge in Plasma 6 steht in `[General] AppletOrder` der Leiste; Plasma schreibt sie nach `addWidget`
  verzögert neu – `schiefer-config kicker` setzt sie deshalb in einem zweiten Schritt.

## Mögliche nächste Schritte


- Qt-Stil auf Breeze 6.8 heben, sobald Plasma 6.8 kommt (`UPSTREAM.md`)
- `userChrome.css` für Firefox/Thunderbird
- Kalender und Zähler-Anzeigen im Plasma-Stil (noch Breeze)
- alte Breeze-Retro-Reste auf dem Desktop: `tools/cleanup-breeze-retro.sh`
