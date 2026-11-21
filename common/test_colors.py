#!/usr/bin/env python3
"""Prüft, dass schiefercolors.h (C++) und schiefercolors.py dieselben Motif-Farben liefern.

    python3 common/test_colors.py [anzahl]      (Standard: 300 Farben, darunter Grenzfälle)

Baut dafür ein kleines Qt-Programm in einem Wegwerf-Ordner (braucht g++ und pkg-config Qt6Gui).
"""
import os
import random
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import schiefercolors as sc  # noqa: E402

CPP = r"""
#include "schiefercolors.h"
#include <cstdio>
int main()
{
    int r, g, b;
    while (std::scanf("%d %d %d", &r, &g, &b) == 3) {
        const auto m = SchieferColors::motifColors(QColor(r, g, b));
        const char *model = m.model == SchieferColors::Model::Dark ? "dark" : m.model == SchieferColors::Model::Light ? "light" : "medium";
        std::printf("%s %s %s %s %s\n", qPrintable(m.foreground.name()), qPrintable(m.topShadow.name()),
                    qPrintable(m.bottomShadow.name()), qPrintable(m.select.name()), model);
    }
}
"""


def samples(n):
    rnd = random.Random(1987)
    cols = [(0, 0, 0), (255, 255, 255), (190, 194, 211), (112, 130, 170), (214, 218, 230), (128, 128, 128)]
    # Graustufen über alle Zweige und rund um die Schwellen (20 %, 70 %, 93 %)
    cols += [(v, v, v) for v in range(0, 256, 5)]
    cols += [(v, v, v) for v in (50, 51, 52, 178, 179, 180, 237, 238, 239)]
    while len(cols) < n:
        cols.append(tuple(rnd.randrange(256) for _ in range(3)))
    return cols


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    cols = samples(n)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "t.cpp")
        exe = os.path.join(tmp, "t")
        with open(src, "w") as f:
            f.write(CPP)
        flags = subprocess.run(["pkg-config", "--cflags", "--libs", "Qt6Gui"], check=True,
                               capture_output=True, text=True).stdout.split()
        subprocess.run(["g++", "-std=c++20", "-fPIC", "-O1", f"-I{HERE}", src, "-o", exe] + flags, check=True)
        inp = "".join("%d %d %d\n" % c for c in cols)
        out = subprocess.run([exe], input=inp, capture_output=True, text=True, check=True).stdout.split("\n")
    bad = 0
    models = {}
    for c, line in zip(cols, out):
        m = sc.motif_colors(c)
        py = " ".join([sc.hexcolor(m[k]) for k in ("fg", "top", "bottom", "select")] + [m["model"]])
        models[m["model"]] = models.get(m["model"], 0) + 1
        if py != line.strip():
            bad += 1
            print("ABWEICHUNG", c, "py:", py, "c++:", line)
    print(f"{len(cols)} Farben geprüft ({', '.join(f'{k}: {v}' for k, v in sorted(models.items()))}), "
          f"{bad} Abweichungen")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
