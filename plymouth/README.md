# Boot screen

Plymouth script theme in the style of a workstation console. A raised banner shows the host name, system,
kernel, machine, CPU and memory. Below it, every unit that systemd starts appears as a log line with the time
since Plymouth started. A sunken bar at the bottom shows the boot progress. Passphrase prompts (for example
for an encrypted ZFS pool) appear as a Motif text field below the last log line. At shutdown the lines read
"stopping" and the bar is hidden.

## Files

| File | Purpose |
|---|---|
| `make_plymouth.py` | renders the glyph atlases (Noto Sans Mono, Noto Sans Bold; UI scale 1, 1.5, 2, 2.5 and 3), the emblem and the 1 px colors for every palette in `colors/` into `palettes/<palette>/`, and fills the glyph tables into `schiefer/schiefer.script.in` |
| `schiefer.script.tmpl` | the Plymouth script; source of `schiefer.script.in` |
| `render_emblem.qml` | renders the emblem of the login screens (`greeter/kit/Emblem.qml`) |
| `schiefer-plymouth-info` | writes `/var/lib/schiefer/plymouth/schiefer.script` from the template with the details of this machine, and copies the images of the system palette (`/etc/schiefer/palette`) to `/var/lib/schiefer/plymouth/images` |
| `dracut/90schiefer-plymouth/` | runs `schiefer-plymouth-info` for the kernel being built and copies the script into the initramfs; active only while `schiefer` is the default Plymouth theme |
| `build-test-plymouth.sh`, `test-plymouth.sh` | test tools, see below |

Run `make_plymouth.py` after changing the template or a palette. Its output in `schiefer/` and `palettes/` is committed.

## How it works

- Plymouth 22 copies neither its label plugin nor fonts into the initramfs, so `Image.Text` is not available
  during early boot. The script crops glyphs from the atlases instead. The UI scale follows the pixel height
  (below 1550 px: 1, up to 4K: 2). With exactly one connected screen `schiefer-plymouth-info` reads its height
  in mm from the EDID and writes it into the script; a dense panel (laptop) then goes up until a log line gets
  about 6 mm. The EDID never lowers the scale, because large monitors are viewed from further away. At least 30 lines of the small font stay on the screen.
- Plymouth's progress is an estimate from the unit times of the last boot (`/var/lib/plymouth/boot-duration`).
  The dracut module copies that file into the initramfs, otherwise Plymouth assumes 60 s there and slows the bar
  to a crawl at about 27 %. Plymouth writes the file with the locale's decimal separator (`0,159` in German),
  but reads it in the initramfs in the C locale and ignores it there, so the copy gets decimal points. The bar
  holds while a prompt waits and shows 100 % when Plymouth quits.
- Plymouth cannot read machine details at boot. `schiefer.plymouth` points `ScriptFile` to
  `/var/lib/schiefer/plymouth/schiefer.script`, which `schiefer-plymouth-info` writes at every dracut run
  (and once at installation). The shutdown screen reads the same file from the root file system.
- The images are colored per palette. `ImageDir` points to `/var/lib/schiefer/plymouth/images`, which holds
  only the set of the system palette, so the initramfs carries one set. Plymouth's own dracut module copies
  that directory before `90schiefer-plymouth` runs, so the Schiefer module replaces the copy with the fresh set.
- systemd sends Plymouth the name of every unit it starts or stops. It does not send the result, so the
  screen shows no OK or FAILED column. Escapes such as `\x2d` in unit names are shown as plain characters.

## Testing without rebooting

`test-plymouth.sh` runs Plymouth with its x11 renderer in an isolated KWin session. Plymouth runs as
namespace root (bwrap) with a private `/dev`, `/run` and network, so it touches neither the real Plymouth,
the graphics card nor the consoles. The status feed is the list of units active on this machine.

```bash
plymouth/build-test-plymouth.sh ~/plytest          # once: Plymouth 22 with tracing and a fixed x11 renderer
PLY_PREFIX=~/plytest plymouth/test-plymouth.sh out.png            # boot
PLY_PREFIX=~/plytest plymouth/test-plymouth.sh out.png password   # passphrase prompt
PLY_PREFIX=~/plytest plymouth/test-plymouth.sh out.png shutdown
BR_WIDTH=3840 BR_HEIGHT=2160 BR_MM=336 PLY_PREFIX=~/plytest plymouth/test-plymouth.sh out.png
PLYMOUTH_FORCE_SCALE=2 BR_WIDTH=2560 BR_HEIGHT=1600 PLY_PREFIX=~/plytest plymouth/test-plymouth.sh out.png
PALETTE=broica PLY_PREFIX=~/plytest plymouth/test-plymouth.sh out.png
```

The distribution build of the x11 renderer keeps showing the first frame under Xwayland, and Gentoo builds
Plymouth without tracing. `build-test-plymouth.sh` fixes both in its own copy. The trace of a run is kept
with `KEEP=1` (the directory is printed on stderr).
