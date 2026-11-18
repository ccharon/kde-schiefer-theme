# Schiefer

Motif/CDE-artiges Erscheinungsbild für KDE Plasma 6, abgeleitet von Breeze. Abstände und Verhalten bleiben bei
Breeze, nur das Zeichnen ist ersetzt: 2-px-Kanten (hell oben links, dunkel unten rechts), versenkte Felder,
erhabene Knöpfe, helles Schieferblau-grau.

Stand: **Version 0.1**, über das lokale Gentoo-Overlay installiert auf dem Desktop (amd64) und dem
MacBook Air mit Gentoo Asahi (arm64).

## Aufbau

| Ordner / Datei | Inhalt |
|---|---|
| `colors/Schiefer.colors` | Farbschema. Fensterhintergrund muss `qGray ≥ 192` bleiben, sonst schalten GTK/Firefox auf dunkel. |
| `kdecoration/` | Fensterdekoration (eigener C++-Code, Plugin-ID `schiefer`) |
| `kstyle/` | Qt-Widget-Stil, Fork von Breeze 6.7.6 (Schlüssel `Schiefer`) – Update siehe `UPSTREAM.md` |
| `make_theme.py` | erzeugt das Icon-Theme `schiefer` aus breeze-icons |
| `plasma/make_plasma_theme.py` | erzeugt den Plasma-Stil `schiefer` (SVG-Rahmenstücke) |
| `gtk/Schiefer/` | GTK3/4-Theme: importiert Breeze-GTK, `retro.css` überschreibt das Zeichnen |
| `wallpaper/` | Muster (`tiles/`, gewählt: Köper), Hintergrundpaket-Generator, `apply.sh` (= `schiefer-wallpaper`) |
| `lookandfeel/` | globales Design „Schiefer“ (setzt alles außer GTK auf einmal) |
| `packaging/` | Ebuild-Vorlagen für `x11-themes/schiefer{,-kde,-icons,-themes}` |
| `tools/` | Test- und Paketwerkzeuge (siehe unten) |
| `src/` | entpackte Upstream-Quellen zum Nachschlagen (Breeze, libplasma, kde-gtk-config …), nicht Teil des Pakets |

## Neue Version ausrollen

```bash
echo 0.2 > VERSION
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
  - Varianten: `BR_GTK_THEME=Breeze`, `BR_COLORS=andere.colors`
- `kstyle/render.sh out.png` – Qt-Galerie offscreen
- Bauen für Tests: `cmake -S kstyle -B kstyle/build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON`
  (ebenso `kdecoration`), danach Symlinks `kstyle/build/plugins/styles/schiefer6.so` und
  `kdecoration/build/plugins/org.kde.kdecoration3/schiefer.so` auf `../../bin/…`.
  Für `gtk/tools` und `plasma/tools` jeweils `cmake -S … -B …/build -G Ninja` (Hilfsprogramme `gtkcolors`, `svgbounds`).

## Wissenswertes

- Plasma 6.7 kann Hintergründe nicht kacheln und skaliert immer auf Bildschirmgröße – deshalb ein
  Hintergrundpaket mit vielen Auflösungen und `schiefer-wallpaper` für pixelgenaue Vollbilder (HiDPI-fähig).
- Das Farbschema hat absichtlich keine `[Colors:Header]`-Gruppe: so übernehmen GTK-Kopfleisten (Firefox usw.)
  die Titelleistenfarbe aus `[WM]`.
- Firefox/Thunderbird zeichnen Leisten und Formulare selbst; sie übernehmen Farben und Hell/Dunkel,
  keine Motif-Kanten (möglich wäre eine eigene `userChrome.css`).
- GTK4-Fensterknöpfe bleiben flach (Breeze gibt ihnen riesige Klickflächen); unter GTK3 sind sie erhaben.

## Mögliche nächste Schritte

- Qt-Stil auf Breeze 6.8 heben, sobald Plasma 6.8 kommt (`UPSTREAM.md`)
- `userChrome.css` für Firefox/Thunderbird
- Kalender und Zähler-Anzeigen im Plasma-Stil (noch Breeze)
- alte Breeze-Retro-Reste auf dem Desktop: `tools/cleanup-breeze-retro.sh`
