/*
 * Schiefer – Farbkern nach Motif (C++-Fassung von schiefercolors.py).
 *
 * Motif leitet aus einer Hintergrundfarbe Vordergrund, obere/untere Schattenfarbe und
 * Auswahlfarbe ab. Die Formel ist exakt aus Motif 2.3.8 übernommen
 * (lib/Xm/Color.c: Brightness, CalculateColorsFor{Light,Dark,Medium}Background,
 * CalculateColorsRGB; Konstanten aus lib/Xm/ColorP.h und lib/Xm/Xm.h.in),
 * Copyright (c) 1987-2012 The Open Group, LGPL-2.1-or-later.
 *
 * Gerechnet wird wie in Motif in 16 bit je Kanal (QColor::rgba64(); eine 8-bit-Farbe c
 * ergibt c * 257 wie XQueryColor auf TrueColor-Bildschirmen) mit ganzzahliger C-Division.
 * Das Ergebnis ist eine 16-bit-QColor; 8-bit-Werte rundet Qt (round(v / 257)) – genauso
 * rechnet common/schiefercolors.py, geprüft mit common/test_colors.py.
 *
 * Nur von QColor abhängig; eingebunden von kdecoration/ und kstyle/ (include_directories ../common).
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */
#pragma once

#include <QColor>

namespace SchieferColors
{
// lib/Xm/ColorP.h
inline constexpr int XmMAX_SHORT = 65535;
inline constexpr int XmCOLOR_PERCENTILE = XmMAX_SHORT / 100;

inline constexpr double XmRED_LUMINOSITY = 0.30;
inline constexpr double XmGREEN_LUMINOSITY = 0.59;
inline constexpr double XmBLUE_LUMINOSITY = 0.11;

inline constexpr int XmINTENSITY_FACTOR = 75;
inline constexpr int XmLIGHT_FACTOR = 0;
inline constexpr int XmLUMINOSITY_FACTOR = 25;

inline constexpr int XmCOLOR_LITE_SEL_FACTOR = 15; // zu Schwarz hin
inline constexpr int XmCOLOR_LITE_BS_FACTOR = 40;
inline constexpr int XmCOLOR_LITE_TS_FACTOR = 20;

inline constexpr int XmCOLOR_DARK_SEL_FACTOR = 15; // zu Weiß hin
inline constexpr int XmCOLOR_DARK_BS_FACTOR = 30;
inline constexpr int XmCOLOR_DARK_TS_FACTOR = 50;

inline constexpr int XmCOLOR_HI_SEL_FACTOR = 15;
inline constexpr int XmCOLOR_HI_BS_FACTOR = 40;
inline constexpr int XmCOLOR_HI_TS_FACTOR = 60;

inline constexpr int XmCOLOR_LO_SEL_FACTOR = 15;
inline constexpr int XmCOLOR_LO_BS_FACTOR = 60;
inline constexpr int XmCOLOR_LO_TS_FACTOR = 50;

// lib/Xm/Xm.h.in: Standardwerte der XmScreen-Ressourcen (Prozent), Color.c: GetDefaultThresholdsForScreen
inline constexpr int XmCOLOR_LITE_THRESHOLD = 93 * XmCOLOR_PERCENTILE;
inline constexpr int XmCOLOR_DARK_THRESHOLD = 20 * XmCOLOR_PERCENTILE;
inline constexpr int XmFOREGROUND_THRESHOLD = 70 * XmCOLOR_PERCENTILE;

enum class Model { Dark, Medium, Light };

struct MotifColors {
    QColor foreground;
    QColor topShadow;
    QColor bottomShadow;
    QColor select;
    Model model;
};

// Color.c: Brightness() – 0 … 65535
inline int brightness16(int red, int green, int blue)
{
    const int intensity = (red + green + blue) / 3;
    const int luminosity = int((XmRED_LUMINOSITY * float(red)) + (XmGREEN_LUMINOSITY * float(green)) + (XmBLUE_LUMINOSITY * float(blue)));
    const int maxprimary = qMax(red, qMax(green, blue));
    const int minprimary = qMin(red, qMin(green, blue));
    const int light = (minprimary + maxprimary) / 2;
    return ((intensity * XmINTENSITY_FACTOR) + (light * XmLIGHT_FACTOR) + (luminosity * XmLUMINOSITY_FACTOR)) / 100;
}

inline int brightness16(const QColor &c)
{
    const QRgba64 v = c.rgba64();
    return brightness16(v.red(), v.green(), v.blue());
}

// Color.c: CalculateColorsRGB() mit CalculateColorsFor{Dark,Light,Medium}Background()
inline MotifColors motifColors(const QColor &bg)
{
    const QRgba64 v = bg.rgba64();
    const int rgb[3] = {v.red(), v.green(), v.blue()};
    const int b = brightness16(rgb[0], rgb[1], rgb[2]);

    auto towardBlack = [&rgb, &bg](int f) {
        int o[3];
        for (int i = 0; i < 3; ++i) {
            o[i] = rgb[i] - (rgb[i] * f) / 100;
        }
        return QColor::fromRgba64(quint16(o[0]), quint16(o[1]), quint16(o[2]), bg.rgba64().alpha());
    };
    auto towardWhite = [&rgb, &bg](int f) {
        int o[3];
        for (int i = 0; i < 3; ++i) {
            o[i] = rgb[i] + f * (XmMAX_SHORT - rgb[i]) / 100;
        }
        return QColor::fromRgba64(quint16(o[0]), quint16(o[1]), quint16(o[2]), bg.rgba64().alpha());
    };

    MotifColors m;
    m.foreground = b > XmFOREGROUND_THRESHOLD ? QColor(0, 0, 0) : QColor(255, 255, 255);
    if (b < XmCOLOR_DARK_THRESHOLD) {
        m.model = Model::Dark;
        m.select = towardWhite(XmCOLOR_DARK_SEL_FACTOR);
        m.bottomShadow = towardWhite(XmCOLOR_DARK_BS_FACTOR);
        m.topShadow = towardWhite(XmCOLOR_DARK_TS_FACTOR);
    } else if (b > XmCOLOR_LITE_THRESHOLD) {
        m.model = Model::Light;
        m.select = towardBlack(XmCOLOR_LITE_SEL_FACTOR);
        m.bottomShadow = towardBlack(XmCOLOR_LITE_BS_FACTOR);
        m.topShadow = towardBlack(XmCOLOR_LITE_TS_FACTOR);
    } else {
        m.model = Model::Medium;
        // C-Division schneidet zur Null ab (BS: negativer Zähler)
        m.select = towardBlack(XmCOLOR_LO_SEL_FACTOR + (b * (XmCOLOR_HI_SEL_FACTOR - XmCOLOR_LO_SEL_FACTOR) / XmMAX_SHORT));
        m.bottomShadow = towardBlack(XmCOLOR_LO_BS_FACTOR + (b * (XmCOLOR_HI_BS_FACTOR - XmCOLOR_LO_BS_FACTOR) / XmMAX_SHORT));
        m.topShadow = towardWhite(XmCOLOR_LO_TS_FACTOR + (b * (XmCOLOR_HI_TS_FACTOR - XmCOLOR_LO_TS_FACTOR) / XmMAX_SHORT));
    }
    return m;
}

inline QColor topShadow(const QColor &bg)
{
    return motifColors(bg).topShadow;
}

inline QColor bottomShadow(const QColor &bg)
{
    return motifColors(bg).bottomShadow;
}

inline QColor selectColor(const QColor &bg)
{
    return motifColors(bg).select;
}

inline QColor foregroundColor(const QColor &bg)
{
    return motifColors(bg).foreground;
}
} // namespace SchieferColors
