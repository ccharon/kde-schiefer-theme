# Schiefer

A Motif/CDE look for KDE Plasma 6, derived from Breeze. Spacing and behavior stay as in Breeze; only the
drawing changes: 2 px bevels (light top left, dark bottom right), sunken fields, raised buttons and a light
slate blue palette. Every Motif feature that can reasonably be switched off has an option in
`schiefer-config`; the default is the Motif behavior.

The user interface is available in English and German.

## Parts

| Directory | Content |
|---|---|
| `kdecoration/` | window decoration (plugin ID `schiefer`) |
| `kstyle/` | Qt widget style, fork of Breeze 6.7.6 (key `Schiefer`); updating: `UPSTREAM.md` |
| `common/` | color core: the Motif formula for light, shadow and select colors from Motif 2.3.8 `lib/Xm/Color.c` (LGPL-2.1+), as C++ header and Python module |
| `palettes/`, `colors/` | five palettes (Schiefer, Sandstein, Jade, Granit, Basalt) and the KDE color schemes generated from them |
| `plasma/` | generator for the Plasma style `schiefer` |
| `gtk/Schiefer/` | GTK 3/4 theme on top of Breeze GTK; optional parts are `opt-*.css`, listed in `options.txt` |
| `make_theme.py` | generates the icon theme `schiefer` from breeze-icons |
| `cursors/` | generator for the cursor theme `Schiefer` (vector versions of the X11 core cursors) |
| `kwin/tabbox/` | window switcher (Alt+Tab) |
| `wallpaper/` | tiled patterns, wallpaper package generator, `schiefer-wallpaper`, and the backdrop plugin `org.kde.schiefer.backdrop` with a pattern and color per virtual desktop |
| `dock/` | Plasma widgets in the style of the CDE front panel: drawer, console, icon box, end pieces, status tiles |
| `greeter/` | SDDM login, lock screen, and the shared Motif QML kit used by splash and logout |
| `lookandfeel/` | global theme `Schiefer` including splash screen and logout dialog |
| `plymouth/` | boot screen: Plymouth script theme with machine banner, systemd units as they start, progress bar and passphrase prompt; generator, dracut module, test tools |
| `konsole/` | Konsole color scheme and profile `Schiefer` (black on the light text field, contrast-checked by `make_konsole.py`) and the matching Midnight Commander skin |
| `tools/schiefer-config` | command line tool for options and palettes |
| `packaging/` | ebuild templates for `x11-themes/schiefer{,-kde,-icons,-themes,-dock,-backdrop,-plymouth}` |

## Installation (Gentoo)

The ebuilds live in the overlay [schiefer-overlay](https://github.com/ccharon/schiefer-overlay):

```bash
eselect repository add schiefer-overlay git https://github.com/ccharon/schiefer-overlay.git
emaint sync -r schiefer-overlay
emerge -av x11-themes/schiefer
```

Then select **System Settings > Global Theme > Schiefer** with **Desktop and window layout**
checked (this builds the dock, icon box and status tiles and replaces the existing panels),
choose the GTK theme under **Application Style > GTK Theme**, and run `schiefer-config defaults`
once per user. To rebuild only the panels later: **Add Panel > Schiefer Front Panel**, or
`qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript "$(cat /usr/share/schiefer/dock/layout.js)"`.

| Package | Content |
|---|---|
| `schiefer-kde` | window decoration and Qt style |
| `schiefer-icons` | icons, generated from the installed breeze-icons at build time |
| `schiefer-themes` | color schemes, Plasma style, GTK theme, cursors, window switcher, image wallpaper, `schiefer-wallpaper`, Konsole scheme and profile, mc skin |
| `schiefer-dock` | dock widgets |
| `schiefer-backdrop` | backdrop plugin |
| `schiefer-plymouth` | boot screen (Plymouth theme and dracut module) |
| `schiefer` | global theme, lock screen, SDDM theme, `schiefer-config`; pulls in all of the above |

Each part comes with a USE flag of `x11-themes/schiefer`, all enabled by default: `backdrop`, `dock`, `icons`,
`kde` (schiefer-kde), `plymouth` and `themes`. To leave a part out, for example the boot screen and the dock:

```bash
echo "x11-themes/schiefer -plymouth -dock" >> /etc/portage/package.use/schiefer
```

Without `dock` the global theme's layout sets up the Plasma default panel, without `backdrop` the image wallpaper.

Boot screen: with `schiefer-plymouth` installed, run `plymouth-set-default-theme -R schiefer` as root. This
rebuilds the initramfs with dracut. The kernel command line needs `splash`. The previous theme comes back with
`plymouth-set-default-theme -R <name>`.

Other distributions: each part builds with CMake or a Python generator; the ebuilds show the steps.

## Configuration: `schiefer-config`

```bash
schiefer-config                   # list options with state and default
schiefer-config diamond off       # set an option; takes effect immediately where possible
schiefer-config defaults          # all options to the Motif defaults
schiefer-config palette basalt    # color scheme and desktop colors
```

The command affects only the calling user. German command names (`liste`, `standard`, `an`, `aus`,
`raute`, ...) are accepted as well.

| Option | Default | Effect | Stored in |
|---|---|---|---|
| `diamond` | on | radio buttons as a sunken diamond (Qt and GTK) | `schieferrc [Style] RadioDiamond`, GTK overlay |
| `animations` | off | Breeze transitions in the Qt style | `schieferrc [Style] AnimationsEnabled` |
| `plasma-animations` | on | KWin and Plasma animations | `kdeglobals [KDE] AnimationDurationFactor` |
| `double-click-close` | on | double click on the window menu button closes the window; a single click opens the menu after the double-click interval | `schieferrc [Decoration] DoubleClickClose` |
| `corner-grips` | on | frame corners up to the notches resize diagonally | `schieferrc [Decoration] MotifCorners` |
| `headerbar` | on | Motif header bar for GTK applications with client-side decorations | GTK overlay |
| `desktop-menu` | on | right click on the desktop opens the application menu | appletsrc `[ActionPlugins][0]` |
| `window-list` | on | middle click on the desktop shows the window list | appletsrc `[ActionPlugins][0]` |
| `window-switcher` | on | Alt+Tab in Motif style | `kwinrc [TabBox] LayoutName` |
| `kicker` | on | application menu with submenus (Kicker) instead of Kickoff | panel |
| `pattern-backdrop` | on | backdrop plugin instead of an image wallpaper | desktops |
| `per-desktop` | on | own pattern and color per virtual desktop | plugin `PerDesktop` |
| `crossfade` | off | crossfade when switching desktops | plugin `Crossfade` |
| `cursor` | on | Schiefer cursors instead of Breeze | `kcminputrc [Mouse] cursorTheme` |
| `lockscreen` | on | Schiefer lock screen | copy of the Plasma shell in `~/.local/share/plasma/shells/` |
| `frontpanel-color` | on | dock, its panels and drawers in the CDE front panel color of the palette | `schieferrc [Dock] FrontPanelColor` |
| `dock-ledge` | on | raised ledge along the bottom of the dock, only under Schiefer widgets | `schieferrc [Dock] Ledge` |
| `tab-raise` | 2 | pixels (0-16) the drawer tabs and end piece buttons grow upward; what does not fit above the widget makes the tab taller downward | `schieferrc [Dock] TabRaise` |

The SDDM theme reads `/usr/share/sddm/themes/schiefer/theme.conf`:

| Key | Type | Default | Effect |
|---|---|---|---|
| `hostName` | text | system host name | large name on the panel |
| `subtitle` | text | `PRETTY_NAME` from `/etc/os-release` | line below the host name |
| `fontSize` | points | system font, at least 10 | text size |
| `showClock` | bool | `true` | seven-segment clock |
| `background`, `backgroundColor`, `dialogColor`, `fieldColor`, `activeColor`, `activeTextColor`, `textColor` | file, colors | Schiefer palette | appearance |

## Development

```bash
python3 common/test_colors.py              # C++ and Python color core agree
tools/screenshot.sh out.png dolphin kwrite # isolated KWin session with all parts from the source tree
kstyle/render.sh out.png                   # Qt gallery offscreen
greeter/test-sddm.sh out.png               # SDDM theme offscreen
greeter/test-lock.sh out.png dialog        # lock screen in an isolated session
plymouth/make_plymouth.py                  # boot screen images and script template
python3 konsole/make_konsole.py            # Konsole scheme and profile; fails if a color pair is hard to read
PLY_PREFIX=... plymouth/test-plymouth.sh out.png [boot|password|shutdown]   # see plymouth/README.md
tools/make-dist.sh                         # release tarball and ebuilds in dist/
```

`tools/screenshot.sh` documents its environment variables (`BR_WIDTH`, `BR_SCALE`, `BR_DATA_DIRS`,
`BR_SHELL_CMD`, ...) in its header. Build directories are `<part>/build` (`cmake -S <part> -B <part>/build -G Ninja`).

Releases: set `VERSION`, run `tools/make-dist.sh`, attach `dist/schiefer-<version>.tar.xz` to a GitHub release
`v<version>`, and copy the ebuilds from `dist/overlay` into the overlay with a new Manifest.

## Known limitations

- Plasma 6 cannot tile image wallpapers; the backdrop plugin does it with a shader. The image wallpaper and
  `schiefer-wallpaper` remain as a fallback.
- GTK approximates the Motif formula with fixed fractions; `gtk/tools/retro_colors.py` reports the deviation
  per palette. CSS cannot draw the notches of the KWin frame.
- Firefox and Thunderbird draw their own toolbars and forms; they follow the colors but not the Motif edges.
- The dock's system tray features rely on Plasma internals; see "Plasma internals used by the dock" in `UPSTREAM.md`.
- The lock screen is a copy of the Plasma shell package, because Plasma 6 loads the lock screen only from the
  shell package. A login script refreshes the copy after updates.
- The splash screen always uses the Schiefer palette for its pattern.
- The boot screen draws text from glyph images, because Plymouth 22 has no fonts in the initramfs. With
  Plymouth's device scale 2 (HiDPI laptops) Plymouth enlarges these images, so the text is slightly soft.

## License

GPL-2.0-or-later, except the color formula (LGPL-2.1-or-later, Motif) and the files taken from Breeze and
KDecoration, which keep their SPDX headers. Generated icons are LGPL-3 like breeze-icons. The glyph images of the boot screen are rendered from Noto Sans
and Noto Sans Mono (SIL Open Font License 1.1).
