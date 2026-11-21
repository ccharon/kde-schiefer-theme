/*
 * SPDX-FileCopyrightText: 2014 Hugo Pereira Da Costa <hugo.pereira@free.fr>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "breezehelper.h"

#include "breeze.h"
#include "breezepropertynames.h"

#include <KColorScheme>
#include <KColorUtils>
#include <KIconLoader>
#include <KWindowSystem>
#include <qobject.h>
#if __has_include(<KX11Extras>)
#include <KX11Extras>
#endif

#include <QApplication>
#include <QDockWidget>
#include <QFileInfo>
#include <QMainWindow>
#include <QMdiArea>
#include <QMenuBar>
#include <QPainter>
#include <QStyleOption>
#include <QTreeView>
#include <QWindow>

#include <QDialog>
#include <QtMath>
#include <algorithm>

namespace Schiefer
{
// Schiefer: Lichtkanten im Gerätepixelraster (fraktionale Skalierung)
namespace
{
// Skalierungsfaktor logisch -> Gerät, falls nur verschoben und gleichmäßig um einen gebrochenen
// Faktor (z. B. 1,25 oder 1,5) skaliert wird; sonst 0. Dann wird wie bisher in logischen Pixeln
// gezeichnet: bei ganzzahligen Faktoren (1, 2, 3) sind die Kanten ohnehin gleichmäßig und bleiben pixelgleich.
qreal bevelDeviceScale(const QPainter *painter)
{
    const QTransform t = painter->deviceTransform();
    if (t.type() > QTransform::TxScale || t.m11() <= 0 || !qFuzzyCompare(t.m11(), t.m22()) || qFuzzyCompare(t.m11(), qreal(qRound(t.m11())))) {
        return 0;
    }
    return t.m11();
}

// Kante wie fillRect ohne AA (x,5 wird aufgerundet, wie auch die Widget-Clips), Toleranz gegen Rundungsfehler
int snapToDevice(qreal v)
{
    return qFloor(v + 0.5 + 1e-4);
}

// ganzzahliges logisches Rechteck in Gerätepixel; Painter danach auf Gerätekoordinaten umstellen
QRect beginDevicePixels(QPainter *painter, const QRect &logical)
{
    const QTransform t = painter->deviceTransform();
    const QRectF m = t.mapRect(QRectF(logical));
    painter->setWorldTransform(t.inverted() * painter->worldTransform());
    return QRect(QPoint(snapToDevice(m.left()), snapToDevice(m.top())), QPoint(snapToDevice(m.right()) - 1, snapToDevice(m.bottom()) - 1));
}

// eigentliche Lichtkante, je Linie 1 Pixel im aktuellen Koordinatensystem
void fillBevel(QPainter *painter, const QRect &rect, const QColor &hi, const QColor &lo, int width)
{
    for (int i = 0; i < width; ++i) {
        const int x = rect.left() + i, y = rect.top() + i;
        const int w = rect.width() - 2 * i, h = rect.height() - 2 * i;
        if (w <= 0 || h <= 0) {
            break;
        }
        painter->fillRect(QRect(x, y, w, 1), hi); // oben
        painter->fillRect(QRect(x, y, 1, h), hi); // links
        painter->fillRect(QRect(x + 1, y + h - 1, w - 1, 1), lo); // unten
        painter->fillRect(QRect(x + w - 1, y + 1, 1, h - 1), lo); // rechts
    }
}
}

//* contrast for arrow and treeline rendering
static const qreal arrowShade = 0.15;

static const qreal highlightBackgroundAlpha = Metrics::Blend_Value;

static const auto radioCheckSunkenDarkeningFactor = 110;

PaletteChangedEventFilter::PaletteChangedEventFilter(Helper *helper)
    : QObject(helper)
    , _helper(helper)
{
}

bool PaletteChangedEventFilter::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() != QEvent::ApplicationPaletteChange || watched != qApp) {
        return QObject::eventFilter(watched, event);
    }
    if (!qApp->property("KDE_COLOR_SCHEME_PATH").isValid()) {
        return QObject::eventFilter(watched, event);
    }
    const auto path = qApp->property("KDE_COLOR_SCHEME_PATH").toString();
    if (!path.isEmpty()) {
        KConfig config(path, KConfig::SimpleConfig);
        KConfigGroup group(config.group(QStringLiteral("WM")));
        const QPalette palette(QApplication::palette());
        _helper->_activeTitleBarColor = group.readEntry("activeBackground", palette.color(QPalette::Active, QPalette::Highlight));
        _helper->_activeTitleBarTextColor = group.readEntry("activeForeground", palette.color(QPalette::Active, QPalette::HighlightedText));
        _helper->_inactiveTitleBarColor = group.readEntry("inactiveBackground", palette.color(QPalette::Disabled, QPalette::Highlight));
        _helper->_inactiveTitleBarTextColor = group.readEntry("inactiveForeground", palette.color(QPalette::Disabled, QPalette::HighlightedText));
    }
    return QObject::eventFilter(watched, event);
}

//____________________________________________________________________
Helper::Helper(KSharedConfig::Ptr config)
    : QObject()
    , _config(std::move(config))
    , _kwinConfig(KSharedConfig::openConfig("kwinrc"))
    , _eventFilter(new PaletteChangedEventFilter(this))
{
}

//____________________________________________________________________
KSharedConfig::Ptr Helper::config() const
{
    return _config;
}

//____________________________________________________________________
void Helper::loadConfig()
{
    _viewFocusBrush = KStatefulBrush(KColorScheme::View, KColorScheme::FocusColor);
    _viewHoverBrush = KStatefulBrush(KColorScheme::View, KColorScheme::HoverColor);
    _viewNegativeTextBrush = KStatefulBrush(KColorScheme::View, KColorScheme::NegativeText);
    _viewNeutralTextBrush = KStatefulBrush(KColorScheme::View, KColorScheme::NeutralText);

    const QPalette palette(QApplication::palette());
    _config->reparseConfiguration();
    _kwinConfig->reparseConfiguration();
    _cachedAutoValid = false;

    KConfigGroup globalGroup(_config->group(QStringLiteral("WM")));
    _activeTitleBarColor = globalGroup.readEntry("activeBackground", palette.color(QPalette::Active, QPalette::Highlight));
    _activeTitleBarTextColor = globalGroup.readEntry("activeForeground", palette.color(QPalette::Active, QPalette::HighlightedText));
    _inactiveTitleBarColor = globalGroup.readEntry("inactiveBackground", palette.color(QPalette::Disabled, QPalette::Highlight));
    _inactiveTitleBarTextColor = globalGroup.readEntry("inactiveForeground", palette.color(QPalette::Disabled, QPalette::HighlightedText));
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    _contrastBias = KColorScheme::frameContrast();
#else
    _contrastBias = 0.2;
#endif

    if (const QString colorSchemePath = qApp->property("KDE_COLOR_SCHEME_PATH").toString(); !colorSchemePath.isEmpty()) {
        KConfig config(colorSchemePath, KConfig::SimpleConfig);
        KConfigGroup appGroup(config.group(QStringLiteral("WM")));
        _activeTitleBarColor = appGroup.readEntry("activeBackground", _activeTitleBarColor);
        _activeTitleBarTextColor = appGroup.readEntry("activeForeground", _activeTitleBarTextColor);
        _inactiveTitleBarColor = appGroup.readEntry("inactiveBackground", _inactiveTitleBarColor);
        _inactiveTitleBarTextColor = appGroup.readEntry("inactiveForeground", _inactiveTitleBarTextColor);
    }
}

void Helper::installEventFilter(QApplication *app) const
{
    if (app) {
        app->installEventFilter(_eventFilter);
    }
}

void Helper::removeEventFilter(QApplication *app) const
{
    if (app) {
        app->removeEventFilter(_eventFilter);
    }
}

QColor transparentize(const QColor &color, qreal amount)
{
    auto clone = color;
    clone.setAlphaF(amount);
    return clone;
}

//____________________________________________________________________
QColor Helper::frameOutlineColor(const QPalette &palette, bool mouseOver, bool hasFocus, qreal opacity, AnimationMode mode) const
{
    QColor outline(KColorUtils::mix(palette.color(QPalette::Window), palette.color(QPalette::WindowText), frameIntensityBias()));

    // focus takes precedence over hover
    if (mode == AnimationFocus) {
        const QColor focus(focusColor(palette));
        const QColor hover(hoverColor(palette));

        if (mouseOver) {
            outline = KColorUtils::mix(hover, focus, opacity);
        } else {
            outline = KColorUtils::mix(outline, focus, opacity);
        }

    } else if (hasFocus) {
        outline = focusColor(palette);

    } else if (mode == AnimationHover) {
        const QColor hover(hoverColor(palette));
        outline = KColorUtils::mix(outline, hover, opacity);

    } else if (mouseOver) {
        outline = hoverColor(palette);
    }

    return outline;
}

//____________________________________________________________________
QColor Helper::focusOutlineColor(const QPalette &palette) const
{
    return KColorUtils::mix(focusColor(palette), palette.color(QPalette::WindowText), 0.15);
}

//____________________________________________________________________
QColor Helper::hoverOutlineColor(const QPalette &palette) const
{
    return KColorUtils::mix(hoverColor(palette), palette.color(QPalette::WindowText), 0.15);
}

//____________________________________________________________________
QColor Helper::sidePanelOutlineColor(const QPalette &palette, bool hasFocus, qreal opacity, AnimationMode mode) const
{
    QColor outline(palette.color(QPalette::Inactive, QPalette::Highlight));
    const QColor &focus = palette.color(QPalette::Active, QPalette::Highlight);

    if (mode == AnimationFocus) {
        outline = KColorUtils::mix(outline, focus, opacity);

    } else if (hasFocus) {
        outline = focus;
    }

    return outline;
}

//____________________________________________________________________
QColor Helper::frameBackgroundColor(const QPalette &palette, QPalette::ColorGroup group) const
{
    return palette.color(group, QPalette::Window); // Schiefer: Motif-Flächen in Fensterfarbe
}

//____________________________________________________________________
QColor Helper::arrowColor(const QPalette &palette, QPalette::ColorGroup group, QPalette::ColorRole role) const
{
    switch (role) {
    case QPalette::Text:
        return KColorUtils::mix(palette.color(group, QPalette::Text), palette.color(group, QPalette::Base), arrowShade);
    case QPalette::WindowText:
        return KColorUtils::mix(palette.color(group, QPalette::WindowText), palette.color(group, QPalette::Window), arrowShade);
    case QPalette::ButtonText:
        return KColorUtils::mix(palette.color(group, QPalette::ButtonText), palette.color(group, QPalette::Button), arrowShade);
    default:
        return palette.color(group, role);
    }
}

//____________________________________________________________________
QColor Helper::arrowColor(const QPalette &palette, bool mouseOver, bool hasFocus, qreal opacity, AnimationMode mode) const
{
    QColor outline(arrowColor(palette, QPalette::WindowText));
    if (mode == AnimationHover) {
        const QColor focus(focusColor(palette));
        const QColor hover(hoverColor(palette));
        if (hasFocus) {
            outline = KColorUtils::mix(focus, hover, opacity);
        } else {
            outline = KColorUtils::mix(outline, hover, opacity);
        }

    } else if (mouseOver) {
        outline = hoverColor(palette);

    } else if (mode == AnimationFocus) {
        const QColor focus(focusColor(palette));
        outline = KColorUtils::mix(outline, focus, opacity);

    } else if (hasFocus) {
        outline = focusColor(palette);
    }

    return outline;
}

//____________________________________________________________________
QColor Helper::sliderOutlineColor(const QPalette &palette, bool mouseOver, bool hasFocus, qreal opacity, AnimationMode mode) const
{
    QColor outline(KColorUtils::mix(palette.color(QPalette::Button), palette.color(QPalette::ButtonText), frameIntensityBias()));

    // hover takes precedence over focus
    if (mode == AnimationHover) {
        const QColor hover(hoverColor(palette));
        const QColor focus(focusColor(palette));
        if (hasFocus) {
            outline = KColorUtils::mix(focus, hover, opacity);
        } else {
            outline = KColorUtils::mix(outline, hover, opacity);
        }

    } else if (mouseOver) {
        outline = hoverColor(palette);

    } else if (mode == AnimationFocus) {
        const QColor focus(focusColor(palette));
        outline = KColorUtils::mix(outline, focus, opacity);

    } else if (hasFocus) {
        outline = focusColor(palette);
    }

    return outline;
}

//____________________________________________________________________
QColor Helper::scrollBarHandleColor(const QPalette &palette, bool mouseOver, bool hasFocus, qreal opacity, AnimationMode mode) const
{
    QColor color(alphaColor(palette.color(QPalette::WindowText), 0.5));

    // hover takes precedence over focus
    if (mode == AnimationHover) {
        const QColor hover(hoverColor(palette));
        const QColor focus(focusColor(palette));
        if (hasFocus) {
            color = KColorUtils::mix(focus, hover, opacity);
        } else {
            color = KColorUtils::mix(color, hover, opacity);
        }

    } else if (mouseOver) {
        color = hoverColor(palette);

    } else if (mode == AnimationFocus) {
        const QColor focus(focusColor(palette));
        color = KColorUtils::mix(color, focus, opacity);

    } else if (hasFocus) {
        color = focusColor(palette);
    }

    return color;
}

//______________________________________________________________________________
QColor Helper::checkBoxIndicatorColor(const QPalette &palette, bool mouseOver, bool active, qreal opacity, AnimationMode mode) const
{
    QColor color(KColorUtils::mix(palette.color(QPalette::Window), palette.color(QPalette::WindowText), 0.6));
    if (mode == AnimationHover) {
        const QColor focus(focusColor(palette));
        const QColor hover(hoverColor(palette));
        if (active) {
            color = KColorUtils::mix(focus, hover, opacity);
        } else {
            color = KColorUtils::mix(color, hover, opacity);
        }

    } else if (mouseOver) {
        color = hoverColor(palette);

    } else if (active) {
        color = focusColor(palette);
    }

    return color;
}

//______________________________________________________________________________
QColor Helper::separatorColor(const QPalette &palette) const
{
    return KColorUtils::mix(palette.color(QPalette::Window), palette.color(QPalette::WindowText), frameIntensityBias());
}

//______________________________________________________________________________
QPalette Helper::disabledPalette(const QPalette &source, qreal ratio) const
{
    QPalette copy(source);

    const QList<QPalette::ColorRole> roles =
        {QPalette::Window, QPalette::Highlight, QPalette::WindowText, QPalette::ButtonText, QPalette::Text, QPalette::Button};
    for (const QPalette::ColorRole &role : roles) {
        copy.setColor(role, KColorUtils::mix(source.color(QPalette::Active, role), source.color(QPalette::Disabled, role), 1.0 - ratio));
    }

    return copy;
}

//____________________________________________________________________
QColor Helper::alphaColor(QColor color, qreal alpha) const
{
    if (alpha >= 0 && alpha < 1.0) {
        color.setAlphaF(alpha * color.alphaF());
    }
    return color;
}

//______________________________________________________________________________
void Helper::renderDebugFrame(QPainter *painter, const QRectF &rect) const
{
    painter->save();
    painter->setRenderHints(QPainter::Antialiasing);
    painter->setBrush(Qt::NoBrush);
    painter->setPen(Qt::red);
    painter->drawRect(strokedRect(rect));
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderFocusRect(QPainter *painter, const QRectF &rect, const QBrush &brush, const QColor &outline, Sides sides) const
{
    painter->save();
    painter->setRenderHints(QPainter::Antialiasing);
    painter->setBrush(brush);

    if (!(outline.isValid() && sides)) {
        painter->setPen(Qt::NoPen);
        painter->drawRect(rect);

    } else {
        painter->setClipRect(rect);

        QRectF copy(strokedRect(rect));

        const qreal radius(0); // Schiefer: eckig
        if (!(sides & SideTop)) {
            copy.adjust(0, -radius, 0, 0);
        }
        if (!(sides & SideBottom)) {
            copy.adjust(0, 0, 0, radius);
        }
        if (!(sides & SideLeft)) {
            copy.adjust(-radius, 0, 0, 0);
        }
        if (!(sides & SideRight)) {
            copy.adjust(0, 0, radius, 0);
        }

        painter->setPen(outline);
        // painter->setBrush( Qt::NoBrush );
        painter->drawRoundedRect(copy, radius, radius);
    }

    painter->restore();
}

//______________________________________________________________________________
void Helper::renderFocusLine(QPainter *painter, const QRectF &rect, const QColor &color, const QRect &bounds) const
{
    if (!color.isValid()) {
        return;
    }

    // Schiefer: Motif-Fokusrahmen um den Text statt Unterstrich.
    // Belegte Pixel: 3 px links/rechts, 1 px oben/unten um den Text. Der Rahmen wird in den
    // Bereich des Aufrufers geklemmt (nach innen gelegt statt abgeschnitten), damit beim
    // Fokuswechsel keine Reste außerhalb des neu gezeichneten Rechtecks stehen bleiben.
    QRect frame = rect.toAlignedRect().adjusted(-3, -1, 3, 1);
    if (bounds.isValid()) {
        frame = frame.intersected(bounds);
    }
    if (frame.width() < 2 || frame.height() < 2) {
        return;
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    painter->setBrush(Qt::NoBrush);
    painter->setPen(color);
    painter->drawRect(frame.adjusted(0, 0, -1, -1)); // drawRect(QRect) zeichnet eine Spalte/Zeile mehr
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderFrameWithSides(QPainter *painter, const QRectF &rect, const QColor &color, Qt::Edges edges, const QColor &outline) const
{
    painter->save();

    painter->setRenderHint(QPainter::Antialiasing);

    QRectF frameRect(rect);

    // set brush
    painter->setBrush(color);
    painter->setPen(Qt::NoPen);

    // render
    painter->drawRect(frameRect);

    // set brush again
    painter->setBrush(Qt::NoBrush);
    painter->setPen(outline);

    // manually apply the effects of StrokedRect here but only to the edges with a frame
    if (edges & Qt::LeftEdge) {
        frameRect.adjust(0.5, 0.0, 0.0, 0.0);
    }
    if (edges & Qt::RightEdge) {
        frameRect.adjust(0.0, 0, -0.5, 0.0);
    }
    if (edges & Qt::TopEdge) {
        frameRect.adjust(0.0, 0.5, 0.0, 0.0);
    }
    if (edges & Qt::BottomEdge) {
        frameRect.adjust(0.0, 0.0, 0.0, -0.5);
    }

    // draw lines
    if (edges & Qt::LeftEdge) {
        painter->drawLine(QLineF(frameRect.topLeft(), frameRect.bottomLeft()));
    }
    if (edges & Qt::RightEdge) {
        painter->drawLine(QLineF(frameRect.topRight(), frameRect.bottomRight()));
    }
    if (edges & Qt::TopEdge) {
        painter->drawLine(QLineF(frameRect.topLeft(), frameRect.topRight()));
    }
    if (edges & Qt::BottomEdge) {
        painter->drawLine(QLineF(frameRect.bottomLeft(), frameRect.bottomRight()));
    }

    painter->restore();
}

//______________________________________________________________________________
void Helper::renderFrame(QPainter *painter, const QRectF &rect, const QColor &color, const QColor &outline) const
{
    painter->setRenderHint(QPainter::Antialiasing);

    QRectF frameRect(rect);
    qreal radius(frameRadius(PenWidth::NoPen));

    // set pen
    if (outline.isValid()) {
        painter->setPen(outline);
        frameRect = strokedRect(frameRect);
        radius = frameRadiusForNewPenWidth(radius, PenWidth::Frame);

    } else {
        painter->setPen(Qt::NoPen);
    }

    // set brush
    if (color.isValid()) {
        painter->setBrush(color);
    } else {
        painter->setBrush(Qt::NoBrush);
    }

    // render
    painter->drawRoundedRect(frameRect, radius, radius);
}

//______________________________________________________________________________
// Schiefer: Grundbausteine
QColor Helper::bevelLight(const QColor &base) const
{
    return KColorUtils::mix(base, Qt::white, 0.55);
}

QColor Helper::bevelDark(const QColor &base) const
{
    return KColorUtils::mix(base, Qt::black, 0.5);
}

void Helper::renderBevel(QPainter *painter, const QRectF &rectF, const QColor &base, bool sunken, int width) const
{
    const QRect rect = rectF.toAlignedRect();
    QColor hi = bevelLight(base), lo = bevelDark(base);
    if (sunken) {
        std::swap(hi, lo);
    }
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    // Schiefer: bei fraktionaler Skalierung in Gerätepixeln, Kantenbreite = round(width * Faktor)
    if (const qreal scale = bevelDeviceScale(painter)) {
        fillBevel(painter, beginDevicePixels(painter, rect), hi, lo, qMax(1, qRound(width * scale)));
    } else {
        fillBevel(painter, rect, hi, lo, width);
    }
    painter->restore();
}

void Helper::renderBevelPanel(QPainter *painter, const QRectF &rectF, const QColor &fill, const QColor &base, bool sunken, int width, int inset) const
{
    // Schiefer: Einzug und Kante bei fraktionaler Skalierung in ganzen Gerätepixeln
    if (const qreal scale = bevelDeviceScale(painter)) {
        QColor hi = bevelLight(base), lo = bevelDark(base);
        if (sunken) {
            std::swap(hi, lo);
        }
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing, false);
        const int d = qRound(inset * scale);
        const QRect r = beginDevicePixels(painter, rectF.toAlignedRect()).adjusted(d, d, -d, -d);
        if (fill.isValid() && !r.isEmpty()) {
            painter->fillRect(r, fill);
        }
        fillBevel(painter, r, hi, lo, qMax(1, qRound(width * scale)));
        painter->restore();
        return;
    }

    const QRect rect = rectF.toAlignedRect().adjusted(inset, inset, -inset, -inset);
    if (fill.isValid()) {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing, false);
        painter->fillRect(rect, fill);
        painter->restore();
    }
    renderBevel(painter, rect, base, sunken, width);
}

void Helper::renderEtchedFrame(QPainter *painter, const QRectF &rectF, const QColor &base) const
{
    const QRect r = rectF.toAlignedRect();
    // Schiefer: bei fraktionaler Skalierung beide Linien gleich breit in Gerätepixeln
    if (const qreal scale = bevelDeviceScale(painter)) {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing, false);
        const QRect d = beginDevicePixels(painter, r);
        const int w = qMax(1, qRound(scale));
        fillBevel(painter, d.adjusted(0, 0, -w, -w), bevelDark(base), bevelLight(base), w);
        fillBevel(painter, d.adjusted(w, w, 0, 0), bevelLight(base), bevelDark(base), w);
        painter->restore();
        return;
    }
    // versenkte 1-px-Kante außen, erhabene 1-px-Kante innen -> geätzte Rille
    renderBevel(painter, r.adjusted(0, 0, -1, -1), base, true, 1);
    renderBevel(painter, r.adjusted(1, 1, 0, 0), base, false, 1);
}

void Helper::renderSunkenField(QPainter *painter, const QRectF &rect, const QPalette &palette, bool hasFocus, bool fill) const
{
    const QRect r = rect.toAlignedRect();
    renderBevelPanel(painter, r, fill ? palette.color(QPalette::Base) : QColor(), palette.color(QPalette::Window), true, 2);
    if (hasFocus) {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing, false);
        painter->setPen(palette.color(QPalette::Highlight).darker(130));
        painter->setBrush(Qt::NoBrush);
        painter->drawRect(r.adjusted(2, 2, -3, -3));
        painter->restore();
    }
}

//______________________________________________________________________________
void Helper::renderSidePanelFrame(QPainter *painter, const QRectF &rect, const QColor &outline, Side side) const
{
    // check color
    if (!outline.isValid()) {
        return;
    }

    // adjust rect
    QRectF frameRect(strokedRect(rect));

    // setup painter
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(outline);

    // render
    switch (side) {
    default:
    case SideLeft:
        painter->drawLine(frameRect.topRight(), frameRect.bottomRight());
        break;

    case SideTop:
        painter->drawLine(frameRect.topLeft(), frameRect.topRight());
        break;

    case SideRight:
        painter->drawLine(frameRect.topLeft(), frameRect.bottomLeft());
        break;

    case SideBottom:
        painter->drawLine(frameRect.bottomLeft(), frameRect.bottomRight());
        break;

    case AllSides: {
        const qreal radius(frameRadius(PenWidth::Frame));
        painter->drawRoundedRect(frameRect, radius, radius);
        break;
    }
    }
}

//______________________________________________________________________________
void Helper::renderMenuFrame(QPainter *painter, const QRectF &rect, const QColor &color, const QColor &outline, bool roundCorners, Qt::Edges seamlessEdges)
    const
{
    // Schiefer: eckiger, erhabener Motif-Menürahmen
    Q_UNUSED(outline)
    Q_UNUSED(roundCorners)
    Q_UNUSED(seamlessEdges)
    const QColor base = color.isValid() ? QColor(color.red(), color.green(), color.blue()) : QColor(Qt::gray);
    renderBevelPanel(painter, rect, color, base, false, 2);
}

QRegion Helper::menuFrameRegion(const QMenu *widget)
{
    if (!widget) {
        return {};
    }

    const bool hasAlpha(hasAlphaChannel(widget));
    const auto seamlessEdges = menuSeamlessEdges(widget);
    const auto roundCorners = false && hasAlpha; // Schiefer: eckig

    if (roundCorners) {
        QRectF frameRect(widget->rect());

        qreal radius(Metrics::Frame_FrameRadius);

        frameRect.adjust( //
            seamlessEdges.testFlag(Qt::LeftEdge) ? -radius : 0,
            seamlessEdges.testFlag(Qt::TopEdge) ? -radius : 0,
            seamlessEdges.testFlag(Qt::RightEdge) ? radius : 0,
            seamlessEdges.testFlag(Qt::BottomEdge) ? radius : 0);

        // outline is always valid/drawn
        frameRect = strokedRect(frameRect);
        radius = frameRadiusForNewPenWidth(radius, PenWidth::Frame);

        QPainterPath path;
        path.addRoundedRect(frameRect, radius, radius);
        return QRegion(path.toFillPolygon().toPolygon()).intersected(widget->rect());
    }

    return QRegion(widget->rect());
}

//______________________________________________________________________________
void Helper::renderButtonFrame(QPainter *painter,
                               const QRectF &rect,
                               const QPalette &palette,
                               const QHash<QByteArray, bool> &stateProperties,
                               qreal bgAnimation,
                               qreal penAnimation) const
{
    // Schiefer: Motif-Knopf – erhabene Fläche, gedrückt/eingerastet versenkt
    Q_UNUSED(bgAnimation)
    Q_UNUSED(penAnimation)
    const bool enabled = stateProperties.value("enabled", true);
    const bool visualFocus = stateProperties.value("visualFocus");
    const bool hovered = stateProperties.value("hovered");
    const bool down = stateProperties.value("down");
    const bool checked = stateProperties.value("checked");
    const bool flat = stateProperties.value("flat");
    const bool defaultButton = stateProperties.value("defaultButton");
    const bool hasNeutralHighlight = stateProperties.value("hasNeutralHighlight");

    // flache Knöpfe (Werkzeugleiste) nur bei Hover/Druck/Zustand zeigen
    if (flat && !(hovered || down || checked || visualFocus)) {
        return;
    }

    QRect r = shadowedRect(rect).toAlignedRect();
    const QColor base = palette.color(QPalette::Button);
    const bool sunken = (down && enabled) || checked;
    QColor fill = base;
    if (sunken) {
        fill = KColorUtils::mix(base, Qt::black, 0.08);
    }
    if (hasNeutralHighlight) {
        fill = KColorUtils::mix(fill, neutralText(palette), 0.25);
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);

    // Standardknopf: zusätzlicher dunkler Ring wie bei Motif
    if (defaultButton && !flat) {
        painter->setPen(Qt::NoPen);
        renderBevel(painter, r, base, true, 1);
    }

    // Schiefer: Einzug für den Ring über inset (in Gerätepixeln gleich breit wie der Ring)
    const int ring = (defaultButton && !flat) ? 1 : 0;
    renderBevelPanel(painter, r, fill, base, sunken, flat ? 1 : 2, ring);
    r.adjust(ring, ring, -ring, -ring);

    // Tastaturfokus: dunkles Rechteck innen
    if (visualFocus && enabled) {
        painter->setPen(QPen(palette.color(QPalette::Highlight).darker(130), 1));
        painter->setBrush(Qt::NoBrush);
        painter->drawRect(r.adjusted(3, 3, -4, -4));
    }
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderToolBoxFrame(QPainter *painter, const QRectF &rect, int tabWidth, const QColor &outline) const
{
    if (!outline.isValid()) {
        return;
    }

    // round radius
    const qreal radius(frameRadius(PenWidth::Frame));
    const QSizeF cornerSize(2 * radius, 2 * radius);

    // if rect - tabwidth is even, need to increase tabWidth by 1 unit
    // for anti aliasing
    if (!((rect.toRect().width() - tabWidth) % 2)) {
        ++tabWidth;
    }

    // adjust rect for antialiasing
    QRectF baseRect(strokedRect(rect));

    // create path
    QPainterPath path;
    path.moveTo(0, baseRect.height() - 1);
    path.lineTo((baseRect.width() - tabWidth) / 2 - radius, baseRect.height() - 1);
    path.arcTo(QRectF(QPointF((baseRect.width() - tabWidth) / 2 - 2 * radius, baseRect.height() - 1 - 2 * radius), cornerSize), 270, 90);
    path.lineTo((baseRect.width() - tabWidth) / 2, radius);
    path.arcTo(QRectF(QPointF((baseRect.width() - tabWidth) / 2, 0), cornerSize), 180, -90);
    path.lineTo((baseRect.width() + tabWidth) / 2 - 1 - radius, 0);
    path.arcTo(QRectF(QPointF((baseRect.width() + tabWidth) / 2 - 1 - 2 * radius, 0), cornerSize), 90, -90);
    path.lineTo((baseRect.width() + tabWidth) / 2 - 1, baseRect.height() - 1 - radius);
    path.arcTo(QRectF(QPointF((baseRect.width() + tabWidth) / 2 - 1, baseRect.height() - 1 - 2 * radius), cornerSize), 180, 90);
    path.lineTo(baseRect.width() - 1, baseRect.height() - 1);

    // render
    painter->setRenderHints(QPainter::Antialiasing);
    painter->setBrush(Qt::NoBrush);
    painter->setPen(outline);
    painter->translate(baseRect.topLeft());
    painter->drawPath(path);
}

//______________________________________________________________________________
void Helper::renderTabWidgetFrame(QPainter *painter, const QRectF &rect, const QColor &color, const QColor &outline, Corners corners) const
{
    // Schiefer: erhabene Reiterfläche
    Q_UNUSED(outline)
    Q_UNUSED(corners)
    const QColor base = color.isValid() ? color : QColor(Qt::gray);
    renderBevelPanel(painter, rect.adjusted(1, 1, -1, -1), color, base, false, 2);
}

//______________________________________________________________________________
void Helper::renderSeparator(QPainter *painter, const QRectF &rect, const QColor &color, bool vertical) const
{
    // Schiefer: geätzte Linie (dunkel + hell)
    painter->setRenderHint(QPainter::Antialiasing, false);
    const QRect r = rect.toAlignedRect();
    const QColor dark = color.darker(115);
    const QColor light(255, 255, 255, 170);
    if (vertical) {
        const int x = r.left() + r.width() / 2 - 1;
        painter->fillRect(QRect(x, r.top(), 1, r.height()), dark);
        painter->fillRect(QRect(x + 1, r.top(), 1, r.height()), light);
    } else {
        const int y = r.top() + r.height() / 2 - 1;
        painter->fillRect(QRect(r.left(), y, r.width(), 1), dark);
        painter->fillRect(QRect(r.left(), y + 1, r.width(), 1), light);
    }
}

//______________________________________________________________________________
void Helper::renderCheckBoxBackground(QPainter *painter,
                                      const QRectF &rect,
                                      const QPalette &palette,
                                      CheckBoxState state,
                                      bool neutalHighlight,
                                      bool sunken,
                                      qreal animation) const
{
    // Schiefer: versenktes Kästchen
    Q_UNUSED(state)
    Q_UNUSED(animation)
    const QRect box = rect.toAlignedRect().adjusted(2, 2, -2, -2);
    QColor fill = palette.color(QPalette::Base);
    if (sunken) {
        fill = KColorUtils::mix(fill, Qt::black, 0.1);
    }
    if (neutalHighlight) {
        fill = KColorUtils::mix(fill, neutralText(palette), 0.25);
    }
    renderBevelPanel(painter, box, fill, palette.color(QPalette::Window), true, 2);
}

//______________________________________________________________________________
void Helper::renderCheckBox(QPainter *painter,
                            const QRectF &rect,
                            const QPalette &palette,
                            bool mouseOver,
                            CheckBoxState state,
                            CheckBoxState target,
                            bool neutalHighlight,
                            bool sunken,
                            qreal animation,
                            qreal hoverAnimation) const
{
    Q_UNUSED(sunken)
    Q_UNUSED(hoverAnimation)

    // setup painter
    painter->setRenderHint(QPainter::Antialiasing, true);

    // copy rect and radius
    QRectF frameRect(rect);
    frameRect.adjust(2, 2, -2, -2);

    if (false && mouseOver) { // Schiefer: kein Hover-Ring
        painter->save();

        if (hoverAnimation != AnimationData::OpacityInvalid) {
            painter->setOpacity(hoverAnimation);
        }

        painter->setPen(QPen(neutalHighlight ? neutralText(palette).lighter() : focusColor(palette), PenWidth::Frame));
        painter->setBrush(Qt::NoBrush);

        painter->drawRoundedRect(frameRect.adjusted(0.5, 0.5, -0.5, -0.5), Metrics::CheckBox_Radius, Metrics::CheckBox_Radius);

        painter->restore();
    }

    // check
    auto leftPoint = frameRect.center();
    leftPoint.setX(frameRect.left() + 4);

    auto bottomPoint = frameRect.center();
    bottomPoint.setX(bottomPoint.x() - 1);
    bottomPoint.setY(frameRect.bottom() - 5);

    auto rightPoint = frameRect.center();
    rightPoint.setX(rightPoint.x() + 4.5);
    rightPoint.setY(frameRect.top() + 5.5);

    QPainterPath path;
    path.moveTo(leftPoint);
    path.lineTo(bottomPoint);
    path.lineTo(rightPoint);

    // dots
    auto centerDot = QRectF(frameRect.center(), QSize(2, 2));
    centerDot.adjust(-1, -1, -1, -1);
    auto leftDot = centerDot.adjusted(-4, 0, -4, 0);
    auto rightDot = centerDot.adjusted(4, 0, 4, 0);

    painter->setPen(Qt::transparent);
    painter->setBrush(Qt::transparent);

    auto checkPen = QPen(palette.text(), PenWidth::Frame * 2);
    checkPen.setJoinStyle(Qt::MiterJoin);

    switch (state) {
    case CheckOff:
        break;
    case CheckOn:
        painter->setPen(checkPen);
        painter->drawPath(path);
        break;
    case CheckPartial:
        painter->setBrush(palette.text());
        painter->drawRect(leftDot);
        painter->drawRect(centerDot);
        painter->drawRect(rightDot);
        break;
    case CheckAnimated:
        checkPen.setDashPattern({path.length() * animation, path.length()});

        switch (target) {
        case CheckOff:
            break;
        case CheckOn:
            painter->setPen(checkPen);
            painter->drawPath(path);
            break;
        case CheckPartial:
            if (animation >= 3.0 / 3.0) {
                painter->drawRect(rightDot);
            }
            if (animation >= 2.0 / 3.0) {
                painter->drawRect(centerDot);
            }
            if (animation >= 1.0 / 3.0) {
                painter->drawRect(leftDot);
            }
            break;
        case CheckAnimated:
            break;
        }
        break;
    }
}

//______________________________________________________________________________
void Helper::renderRadioButtonBackground(QPainter *painter,
                                         const QRectF &rect,
                                         const QPalette &palette,
                                         RadioButtonState state,
                                         bool neutalHighlight,
                                         bool sunken,
                                         qreal animation) const
{
    // Schiefer: versenkter Kreis (CDE)
    Q_UNUSED(state)
    Q_UNUSED(animation)
    const QRectF r = QRectF(rect).adjusted(3, 3, -3, -3);
    const QColor base = palette.color(QPalette::Window);
    QColor fill = palette.color(QPalette::Base);
    if (sunken) {
        fill = KColorUtils::mix(fill, Qt::black, 0.1);
    }
    if (neutalHighlight) {
        fill = KColorUtils::mix(fill, neutralText(palette), 0.25);
    }
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);
    painter->setPen(Qt::NoPen);
    painter->setBrush(fill);
    painter->drawEllipse(r);
    // Schatten oben links, Licht unten rechts
    QPen pen(bevelDark(base), 2);
    pen.setCapStyle(Qt::FlatCap);
    painter->setBrush(Qt::NoBrush);
    painter->setPen(pen);
    const QRectF ring = r.adjusted(1, 1, -1, -1);
    painter->drawArc(ring, 45 * 16, 180 * 16);
    pen.setColor(bevelLight(base));
    painter->setPen(pen);
    painter->drawArc(ring, 225 * 16, 180 * 16);
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderRadioButton(QPainter *painter,
                               const QRectF &rect,
                               const QPalette &palette,
                               bool mouseOver,
                               RadioButtonState state,
                               bool neutralHighlight,
                               bool sunken,
                               qreal animation,
                               qreal animationHover) const
{
    Q_UNUSED(sunken)
    Q_UNUSED(animationHover)

    // copy rect
    QRectF frameRect(rect);
    frameRect.adjust(1, 1, -1, -1);

    if (false && mouseOver) { // Schiefer: kein Hover-Ring
        painter->save();

        if (animationHover != AnimationData::OpacityInvalid) {
            painter->setOpacity(animationHover);
        }

        painter->setPen(QPen(neutralHighlight ? neutralText(palette).lighter() : focusColor(palette), PenWidth::Frame));
        painter->setBrush(Qt::NoBrush);

        const QRectF contentRect(frameRect.adjusted(1, 1, -1, -1).adjusted(0.5, 0.5, -0.5, -0.5));
        painter->drawEllipse(contentRect);

        painter->restore();
    }

    painter->setRenderHint(QPainter::Antialiasing, true);
    painter->setBrush(palette.color(QPalette::Highlight));
    painter->setPen(Qt::NoPen);

    const int radius = (std::min(frameRect.width(), frameRect.height()) - 10) / 2;
    const QPointF center = frameRect.center();

    // mark
    switch (state) {
    case RadioOn:
        painter->drawEllipse(center, radius, radius);
        break;
    case RadioAnimated: {
        const qreal animationRadius = radius * animation;
        painter->drawEllipse(center, animationRadius, animationRadius);
        break;
    }
    default:
        break;
    }
}

//______________________________________________________________________________
void Helper::renderSliderGroove(QPainter *painter, const QRectF &rect, const QColor &fg, const QColor &bg) const
{
    // Schiefer: versenkte Rinne (fg wird nicht genutzt – Motif kennt keine Füllung)
    Q_UNUSED(fg)
    renderBevelPanel(painter, rect, KColorUtils::mix(bg, Qt::black, 0.12), bg, true, 2);
}

//______________________________________________________________________________
void Helper::renderDialGroove(QPainter *painter, const QRectF &rect, const QColor &fg, const QColor &bg, qreal first, qreal last) const
{
    // setup painter
    painter->setRenderHint(QPainter::Antialiasing, true);

    const QRectF baseRect(rect);

    // content
    if (fg.isValid()) {
        const qreal penWidth(Metrics::Slider_GrooveThickness);
        const QRectF grooveRect(rect.adjusted(penWidth / 2, penWidth / 2, -penWidth / 2, -penWidth / 2));

        // setup angles
        const int angleStart(first * 180 * 16 / M_PI);
        const int angleSpan((last - first) * 180 * 16 / M_PI);
        const QPen bgPen(fg, penWidth, Qt::SolidLine, Qt::RoundCap);
        const QPen fgPen(transparentize(KColorUtils::overlayColors(bg, alphaColor(fg, 0.5)), frameIntensityBias()), penWidth - 2, Qt::SolidLine, Qt::RoundCap);

        // setup pen
        if (angleSpan != 0) {
            painter->setPen(bgPen);
            painter->setBrush(Qt::NoBrush);
            painter->drawArc(grooveRect, angleStart, angleSpan);
            painter->setPen(fgPen);
            painter->drawArc(grooveRect, angleStart, angleSpan);
        }
    }
}

//______________________________________________________________________________
void Helper::initSliderStyleOption(const QSlider *slider, QStyleOptionSlider *option) const
{
    option->initFrom(slider);
    option->subControls = QStyle::SC_None;
    option->activeSubControls = QStyle::SC_None;
    option->orientation = slider->orientation();
    option->maximum = slider->maximum();
    option->minimum = slider->minimum();
    option->tickPosition = slider->tickPosition();
    option->tickInterval = slider->tickInterval();
    option->upsideDown = (slider->orientation() == Qt::Horizontal) //
        ? (slider->invertedAppearance() != (option->direction == Qt::RightToLeft))
        : (!slider->invertedAppearance());
    option->direction = Qt::LeftToRight; // we use the upsideDown option instead
    option->sliderPosition = slider->sliderPosition();
    option->sliderValue = slider->value();
    option->singleStep = slider->singleStep();
    option->pageStep = slider->pageStep();
    if (slider->orientation() == Qt::Horizontal) {
        option->state |= QStyle::State_Horizontal;
    }
    // Can't fetch activeSubControls, because it's private API
}

//______________________________________________________________________________
QRectF Helper::pathForSliderHandleFocusFrame(QPainterPath &focusFramePath, const QRectF &rect, int hmargin, int vmargin) const
{
    // Mimics path and adjustments of renderSliderHandle
    QRectF frameRect(rect);
    frameRect.translate(hmargin, vmargin);
    frameRect.adjust(1, 1, -1, -1);
    frameRect = strokedRect(frameRect);
    focusFramePath.addEllipse(frameRect);
    frameRect.adjust(-hmargin, -vmargin, hmargin, vmargin);
    focusFramePath.addEllipse(frameRect);
    return frameRect;
}

//______________________________________________________________________________
void Helper::renderSliderHandle(QPainter *painter, const QRectF &rect, const QColor &color, const QColor &outline, const QColor &shadow, bool sunken) const
{
    // Schiefer: erhabener eckiger Daumen
    Q_UNUSED(outline)
    Q_UNUSED(shadow)
    Q_UNUSED(sunken)
    const QRect r = rect.toAlignedRect().adjusted(1, 1, -1, -1);
    renderBevelPanel(painter, r, color, color, false, 2);
}

void Helper::renderRetroSliderThumb(QPainter *painter, const QRectF &rect, const QColor &color, bool horizontal) const
{
    // Motif-Daumen: länglich quer zur Rinne, mit geätzter Mittellinie
    QRect r = rect.toAlignedRect();
    if (horizontal) {
        r.adjust(0, 2, 0, -2);
    } else {
        r.adjust(2, 0, -2, 0);
    }
    if (r.isEmpty()) {
        return; // Schiefer: zu klein
    }
    renderBevelPanel(painter, r, color, color, false, 2);
    // geätzte Mittellinie nur, wenn innerhalb der Kanten Platz ist
    if ((horizontal ? r.height() : r.width()) <= 4) {
        return;
    }
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    const QPoint c = r.center();
    if (horizontal) {
        painter->fillRect(QRect(c.x(), r.top() + 2, 1, r.height() - 4), bevelDark(color));
        painter->fillRect(QRect(c.x() + 1, r.top() + 2, 1, r.height() - 4), bevelLight(color));
    } else {
        painter->fillRect(QRect(r.left() + 2, c.y(), r.width() - 4, 1), bevelDark(color));
        painter->fillRect(QRect(r.left() + 2, c.y() + 1, r.width() - 4, 1), bevelLight(color));
    }
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderProgressBarGroove(QPainter *painter, const QRectF &rect, const QColor &fg, const QColor &bg) const
{
    // Schiefer: versenkte Rinne
    Q_UNUSED(fg)
    renderBevelPanel(painter, rect, KColorUtils::mix(bg, Qt::black, 0.12), bg, true, 2);
}

//______________________________________________________________________________
void Helper::renderProgressBarBusyContents(QPainter *painter,
                                           const QRectF &rect,
                                           const QColor &first,
                                           const QColor &second,
                                           bool horizontal,
                                           bool reverse,
                                           int progress) const
{
    // setup painter
    painter->setRenderHint(QPainter::Antialiasing, true);

    const QRectF baseRect(rect);
    const qreal radius(0); // Schiefer

    // setup brush
    QPixmap pixmap(horizontal ? 2 * Metrics::ProgressBar_BusyIndicatorSize : 1, horizontal ? 1 : 2 * Metrics::ProgressBar_BusyIndicatorSize);
    pixmap.fill(second);
    if (horizontal) {
        QPainter painter(&pixmap);
        painter.setBrush(first);
        painter.setPen(Qt::NoPen);

        progress %= 2 * Metrics::ProgressBar_BusyIndicatorSize;
        if (reverse) {
            progress = 2 * Metrics::ProgressBar_BusyIndicatorSize - progress - 1;
        }
        painter.drawRect(QRect(0, 0, Metrics::ProgressBar_BusyIndicatorSize, 1).translated(progress, 0));

        if (progress > Metrics::ProgressBar_BusyIndicatorSize) {
            painter.drawRect(QRect(0, 0, Metrics::ProgressBar_BusyIndicatorSize, 1).translated(progress - 2 * Metrics::ProgressBar_BusyIndicatorSize, 0));
        }

    } else {
        QPainter painter(&pixmap);
        painter.setBrush(first);
        painter.setPen(Qt::NoPen);

        progress %= 2 * Metrics::ProgressBar_BusyIndicatorSize;
        progress = 2 * Metrics::ProgressBar_BusyIndicatorSize - progress - 1;
        painter.drawRect(QRect(0, 0, 1, Metrics::ProgressBar_BusyIndicatorSize).translated(0, progress));

        if (progress > Metrics::ProgressBar_BusyIndicatorSize) {
            painter.drawRect(QRect(0, 0, 1, Metrics::ProgressBar_BusyIndicatorSize).translated(0, progress - 2 * Metrics::ProgressBar_BusyIndicatorSize));
        }
    }

    painter->setPen(Qt::NoPen);
    painter->setBrush(pixmap);
    painter->drawRoundedRect(baseRect, radius, radius);
}

//______________________________________________________________________________
void Helper::renderScrollBarHandle(QPainter *painter, const QRectF &rect, const QColor &fg, const QColor &bg) const
{
    // Schiefer: erhabener Motif-Schieber (fg = Knopffarbe)
    Q_UNUSED(bg)
    renderBevelPanel(painter, rect, fg, fg, false, 2);
}

//______________________________________________________________________________
void Helper::renderScrollBarBorder(QPainter *painter, const QRectF &rect, const QColor &color) const
{
    // content
    if (color.isValid()) {
        painter->setPen(Qt::NoPen);
        painter->setBrush(color);
        painter->drawRect(rect);
    }
}

void Helper::renderStaticTabBarTab(QPainter *painter,
                                   const QRectF &rect,
                                   const QPalette &palette,
                                   const QHash<QByteArray, bool> &stateProperties,
                                   Corners corners,
                                   qreal animation) const
{
    // Schiefer: Motif-Reiter – drei erhabene Kanten, der aktive verschmilzt mit der Fläche
    Q_UNUSED(corners)
    Q_UNUSED(animation)
    const bool selected = stateProperties.value("selected");
    const bool north = stateProperties.value("north");
    const bool south = stateProperties.value("south");
    const bool west = stateProperties.value("west");
    const bool east = stateProperties.value("east");
    const QColor base = palette.color(QPalette::Window);
    const QColor hi = bevelLight(base), lo = bevelDark(base);
    QRect r = rect.toAlignedRect();
    // inaktive Reiter etwas niedriger und dunkler
    if (!selected) {
        if (north) r.adjust(0, 2, 0, 0);
        else if (south) r.adjust(0, 0, 0, -2);
        else if (west) r.adjust(2, 0, 0, 0);
        else if (east) r.adjust(0, 0, -2, 0);
    }
    if (r.width() < 4 || r.height() < 4) {
        return; // Schiefer: zu klein für zwei Kanten
    }
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    painter->fillRect(r, selected ? base : KColorUtils::mix(base, Qt::black, 0.07));
    const int w = 2;
    for (int i = 0; i < w; ++i) {
        const QRect q = r.adjusted(i, i, -i, -i);
        if (north || (!south && !west && !east)) {
            painter->fillRect(QRect(q.left(), q.top(), q.width(), 1), hi);
            painter->fillRect(QRect(q.left(), q.top(), 1, r.height() - i), hi);
            painter->fillRect(QRect(q.right(), q.top() + 1, 1, r.height() - i - 1), lo);
        } else if (south) {
            painter->fillRect(QRect(q.left(), q.bottom(), q.width(), 1), lo);
            painter->fillRect(QRect(q.left(), r.top(), 1, r.height() - i), hi);
            painter->fillRect(QRect(q.right(), r.top(), 1, r.height() - i), lo);
        } else if (west) {
            painter->fillRect(QRect(q.left(), q.top(), 1, q.height()), hi);
            painter->fillRect(QRect(q.left(), q.top(), r.width() - i, 1), hi);
            painter->fillRect(QRect(q.left() + 1, q.bottom(), r.width() - i - 1, 1), lo);
        } else if (east) {
            painter->fillRect(QRect(q.right(), q.top(), 1, q.height()), lo);
            painter->fillRect(QRect(r.left(), q.top(), r.width() - i, 1), hi);
            painter->fillRect(QRect(r.left(), q.bottom(), r.width() - i, 1), lo);
        }
    }
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderTabBarTab(QPainter *painter,
                             const QRectF &rect,
                             const QPalette &palette,
                             const QHash<QByteArray, bool> &stateProperties,
                             Corners corners,
                             qreal animation) const
{
    // Schiefer: Motif-Reiter – drei erhabene Kanten, der aktive verschmilzt mit der Fläche
    Q_UNUSED(corners)
    Q_UNUSED(animation)
    const bool selected = stateProperties.value("selected");
    const bool north = stateProperties.value("north");
    const bool south = stateProperties.value("south");
    const bool west = stateProperties.value("west");
    const bool east = stateProperties.value("east");
    const QColor base = palette.color(QPalette::Window);
    const QColor hi = bevelLight(base), lo = bevelDark(base);
    QRect r = rect.toAlignedRect();
    // inaktive Reiter etwas niedriger und dunkler
    if (!selected) {
        if (north) r.adjust(0, 2, 0, 0);
        else if (south) r.adjust(0, 0, 0, -2);
        else if (west) r.adjust(2, 0, 0, 0);
        else if (east) r.adjust(0, 0, -2, 0);
    }
    if (r.width() < 4 || r.height() < 4) {
        return; // Schiefer: zu klein für zwei Kanten
    }
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    painter->fillRect(r, selected ? base : KColorUtils::mix(base, Qt::black, 0.07));
    const int w = 2;
    for (int i = 0; i < w; ++i) {
        const QRect q = r.adjusted(i, i, -i, -i);
        if (north || (!south && !west && !east)) {
            painter->fillRect(QRect(q.left(), q.top(), q.width(), 1), hi);
            painter->fillRect(QRect(q.left(), q.top(), 1, r.height() - i), hi);
            painter->fillRect(QRect(q.right(), q.top() + 1, 1, r.height() - i - 1), lo);
        } else if (south) {
            painter->fillRect(QRect(q.left(), q.bottom(), q.width(), 1), lo);
            painter->fillRect(QRect(q.left(), r.top(), 1, r.height() - i), hi);
            painter->fillRect(QRect(q.right(), r.top(), 1, r.height() - i), lo);
        } else if (west) {
            painter->fillRect(QRect(q.left(), q.top(), 1, q.height()), hi);
            painter->fillRect(QRect(q.left(), q.top(), r.width() - i, 1), hi);
            painter->fillRect(QRect(q.left() + 1, q.bottom(), r.width() - i - 1, 1), lo);
        } else if (east) {
            painter->fillRect(QRect(q.right(), q.top(), 1, q.height()), lo);
            painter->fillRect(QRect(r.left(), q.top(), r.width() - i, 1), hi);
            painter->fillRect(QRect(r.left(), q.bottom(), r.width() - i, 1), lo);
        }
    }
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderArrow(QPainter *painter, const QRectF &rect, const QColor &color, ArrowOrientation orientation) const
{
    int size = std::min({rect.toRect().width(), rect.toRect().height(), Metrics::ArrowSize});
    // No point in trying to draw if it's too small
    if (size <= 0) {
        return;
    }

    qreal penOffset = PenWidth::Symbol / 2.0;
    qreal center = size / 2.0;
    qreal maxExtent = size * 0.75;
    qreal minExtent = size / 4.0;
    qreal sizeOffset = 0;
    int remainder = size % 4;
    if (remainder == 2) {
        sizeOffset = 0.5;
    } else if (remainder == 1) {
        sizeOffset = -0.25;
    } else if (remainder == 3) {
        sizeOffset = 0.25;
    }

    QPolygonF arrow;
    switch (orientation) {
    case ArrowUp:
        arrow = QVector<QPointF>{
            {penOffset, maxExtent - penOffset - sizeOffset}, // left
            {center, minExtent - sizeOffset}, // mid
            {size - penOffset, maxExtent - penOffset - sizeOffset} // right
        };
        break;
    case ArrowDown:
        arrow = QVector<QPointF>{
            {penOffset, minExtent + penOffset + sizeOffset}, // left
            {center, maxExtent + sizeOffset}, // mid
            {size - penOffset, minExtent + penOffset + sizeOffset} // right
        };
        break;
    case ArrowLeft:
        arrow = QVector<QPointF>{
            {maxExtent - penOffset - sizeOffset, penOffset}, // top
            {minExtent - sizeOffset, center}, // mid
            {maxExtent - penOffset - sizeOffset, size - penOffset}, // bottom
        };
        break;
    case ArrowRight:
        arrow = QVector<QPointF>{
            {minExtent + penOffset + sizeOffset, penOffset}, // top
            {maxExtent + sizeOffset, center}, // mid
            {minExtent + penOffset + sizeOffset, size - penOffset}, // bottom
        };
        break;
    default:
        break;
    }

    arrow.translate(rect.x() + (rect.width() - size) / 2.0, rect.y() + (rect.height() - size) / 2.0);

    // Schiefer: gefülltes Motif-Dreieck
    painter->save();
    painter->setRenderHints(QPainter::Antialiasing);
    painter->setPen(QPen(color, 1));
    painter->setBrush(color);
    painter->drawPolygon(arrow);
    painter->restore();
}

//______________________________________________________________________________
void Helper::renderDecorationButton(QPainter *painter, const QRectF &rect, const QColor &color, ButtonType buttonType, bool inverted) const
{
    painter->save();
    painter->setViewport(rect.toRect());
    painter->setWindow(0, 0, 18, 18);
    painter->setRenderHints(QPainter::Antialiasing);

    // initialize pen
    QPen pen;
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::MiterJoin);

    if (inverted) {
        // render circle
        painter->setPen(Qt::NoPen);
        painter->setBrush(color);
        painter->drawEllipse(QRectF(0, 0, 18, 18));

        // take out the inner part
        painter->setCompositionMode(QPainter::CompositionMode_DestinationOut);
        painter->setBrush(Qt::NoBrush);
        pen.setColor(Qt::black);

    } else {
        painter->setBrush(Qt::NoBrush);
        pen.setColor(color);
    }

    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::MiterJoin);
    pen.setWidthF(PenWidth::Symbol * qMax(1.0, 18.0 / rect.width()));
    painter->setPen(pen);

    switch (buttonType) {
    case ButtonClose: {
        painter->drawLine(QPointF(5, 5), QPointF(13, 13));
        painter->drawLine(13, 5, 5, 13);
        break;
    }

    case ButtonMaximize: {
        painter->drawPolyline(QVector<QPointF>{QPointF(4, 11), QPointF(9, 6), QPointF(14, 11)});
        break;
    }

    case ButtonMinimize: {
        painter->drawPolyline(QVector<QPointF>{QPointF(4, 7), QPointF(9, 12), QPointF(14, 7)});
        break;
    }

    case ButtonRestore: {
        pen.setJoinStyle(Qt::RoundJoin);
        painter->setPen(pen);
        painter->drawPolygon(QVector<QPointF>{QPointF(4.5, 9), QPointF(9, 4.5), QPointF(13.5, 9), QPointF(9, 13.5)});
        break;
    }

    default:
        break;
    }

    painter->restore();
}

//______________________________________________________________________________
void Helper::renderRoundedRectShadow(QPainter *painter, const QRectF &rect, const QColor &color, qreal radius) const
{
    if (!color.isValid()) {
        return;
    }

    painter->setRenderHint(QPainter::Antialiasing, true);

    qreal adjustment = 0.5 * PenWidth::Shadow; // Translate for the pen
    QRectF shadowRect = rect.adjusted(adjustment, adjustment, -adjustment, adjustment);

    painter->setPen(QPen(color, PenWidth::Shadow));
    painter->setBrush(Qt::NoBrush);
    painter->drawRoundedRect(shadowRect, radius, radius);
}

//______________________________________________________________________________
void Helper::renderEllipseShadow(QPainter *painter, const QRectF &rect, const QColor &color) const
{
    if (!color.isValid()) {
        return;
    }

    painter->save();

    // Clipping does not improve performance here

    qreal adjustment = 0.5 * PenWidth::Shadow; // Adjust for the pen

    qreal radius = rect.width() / 2 - adjustment;

    /* The right side is offset by +0.5 for the visible part of the shadow.
     * The other sides are offset by +0.5 or -0.5 because of the pen.
     */
    QRectF shadowRect = rect.adjusted(adjustment, adjustment, adjustment, -adjustment);

    painter->translate(rect.center());
    painter->rotate(45);
    painter->translate(-rect.center());
    painter->setPen(color);
    painter->setBrush(Qt::NoBrush);
    painter->drawRoundedRect(shadowRect, radius, radius);

    painter->restore();
}

void Helper::renderViewItemPosition(QPainter *painter,
                                    const QStyleOptionViewItem::ViewItemPosition &pos,
                                    const Qt::LayoutDirection direction,
                                    const QRectF &rect,
                                    const QBrush &bg,
                                    const QColor &outline) const
{
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    QFlags<Schiefer::Side> sides;
    const bool reverse = direction == Qt::RightToLeft;

    switch (pos) {
    case QStyleOptionViewItem::Invalid:
        painter->setBrush(bg);
        painter->setPen(outline);
        painter->drawRect(rect);
        painter->restore();
        return;
    case QStyleOptionViewItem::Beginning:
        painter->setClipping(true);
        painter->setClipRect(rect);
        sides = SideTop | SideBottom | (reverse ? SideRight : SideLeft);
        break;
    case QStyleOptionViewItem::Middle:;
        sides = SideTop | SideBottom;
        break;
    case QStyleOptionViewItem::End:
        painter->setClipping(true);
        painter->setClipRect(rect);
        sides = SideTop | SideBottom | (reverse ? SideLeft : SideRight);
        break;
    case QStyleOptionViewItem::OnlyOne:
        sides = SideTop | SideBottom | SideLeft | SideRight;
        break;
    }
    renderFocusRect(painter, rect, bg, outline, sides);
    painter->restore();
}

//______________________________________________________________________________
bool Helper::isX11()
{
    static const bool s_isX11 = KWindowSystem::isPlatformX11();
    return s_isX11;
}

//______________________________________________________________________________
bool Helper::isWayland()
{
    static const bool s_isWayland = KWindowSystem::isPlatformWayland();
    return s_isWayland;
}

//______________________________________________________________________________
QRectF Helper::strokedRect(const QRectF &rect, const qreal penWidth) const
{
    /* With a pen stroke width of 1, the rectangle should have each of its
     * sides moved inwards by half a pixel. This allows the stroke to be
     * pixel perfect instead of blurry from sitting between pixels and
     * prevents the rectangle with a stroke from becoming larger than the
     * original size of the rectangle.
     */
    qreal adjustment = 0.5 * penWidth;
    return rect.adjusted(adjustment, adjustment, -adjustment, -adjustment);
}

QMargins Helper::itemViewItemMargins(const QStyleOptionViewItem *option) const
{
    QMargins margins(Metrics::ItemView_ItemMarginLeft, Metrics::ItemView_ItemMarginTop, Metrics::ItemView_ItemMarginRight, Metrics::ItemView_ItemMarginBottom);
    if (!option) {
        return margins;
    }

    const QFrame *frame = qobject_cast<const QFrame *>(option->widget);
    const QAbstractItemView *abstractItemView = qobject_cast<const QAbstractItemView *>(option->widget);

    const bool isFirst = option->index.row() == 0;
    const bool hasFrame = frame && frame->frameShape() == QFrame::StyledPanel;
    const bool reverse = option->direction == Qt::RightToLeft;

    if (isFirst) {
        margins.setTop(Metrics::ItemView_FirstItemTopMarginHeight);
    }

    // Breeze frame has one extra white pixel
    if (hasFrame) {
        margins -= {1, isFirst ? 1 : 0, 1, 0};
    }

    // If a treeview wants to show the highlight separate for each column, always draw rounded borders
    // if (tree && !tree->allColumnsShowFocus()) {
    if (abstractItemView && abstractItemView->selectionBehavior() != QAbstractItemView::SelectRows) {
        return margins;
    }

    if ((reverse && option->viewItemPosition == QStyleOptionViewItem::End) || (!reverse && option->viewItemPosition == QStyleOptionViewItem::Beginning)
        || option->viewItemPosition == QStyleOptionViewItem::Middle) {
        margins.setRight(0);
    }
    if ((reverse && option->viewItemPosition == QStyleOptionViewItem::Beginning) || (!reverse && option->viewItemPosition == QStyleOptionViewItem::End)
        || option->viewItemPosition == QStyleOptionViewItem::Middle) {
        margins.setLeft(0);
    }

    return margins;
}

//______________________________________________________________________________
QPainterPath Helper::roundedPath(const QRectF &rect, Corners corners, qreal radius) const
{
    QPainterPath path;

    // simple cases
    if (corners == 0) {
        path.addRect(rect);
        return path;
    }

    if (corners == AllCorners) {
        path.addRoundedRect(rect, radius, radius);
        return path;
    }

    const QSizeF cornerSize(2 * radius, 2 * radius);

    // rotate counterclockwise
    // top left corner
    if (corners & CornerTopLeft) {
        path.moveTo(rect.topLeft() + QPointF(radius, 0));
        path.arcTo(QRectF(rect.topLeft(), cornerSize), 90, 90);

    } else {
        path.moveTo(rect.topLeft());
    }

    // bottom left corner
    if (corners & CornerBottomLeft) {
        path.lineTo(rect.bottomLeft() - QPointF(0, radius));
        path.arcTo(QRectF(rect.bottomLeft() - QPointF(0, 2 * radius), cornerSize), 180, 90);

    } else {
        path.lineTo(rect.bottomLeft());
    }

    // bottom right corner
    if (corners & CornerBottomRight) {
        path.lineTo(rect.bottomRight() - QPointF(radius, 0));
        path.arcTo(QRectF(rect.bottomRight() - QPointF(2 * radius, 2 * radius), cornerSize), 270, 90);

    } else {
        path.lineTo(rect.bottomRight());
    }

    // top right corner
    if (corners & CornerTopRight) {
        path.lineTo(rect.topRight() + QPointF(0, radius));
        path.arcTo(QRectF(rect.topRight() - QPointF(2 * radius, 0), cornerSize), 0, 90);

    } else {
        path.lineTo(rect.topRight());
    }

    path.closeSubpath();
    return path;
}

//________________________________________________________________________________________________________
bool Helper::compositingActive() const
{
    if (isX11()) {
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
        return KWindowSystem::compositingActive();
#elif __has_include(<KX11Extras>)
        return KX11Extras::compositingActive();
#endif
    }

    return true;
}

//____________________________________________________________________
bool Helper::hasAlphaChannel(const QWidget *widget) const
{
    return compositingActive() && widget && widget->testAttribute(Qt::WA_TranslucentBackground);
}

//______________________________________________________________________________________

QPixmap Helper::coloredIcon(const QIcon &icon, const QPalette &palette, const QSize &size, qreal devicePixelRatio, QIcon::Mode mode, QIcon::State state)
{
    const QPalette activePalette = KIconLoader::global()->customPalette();
    const bool changePalette = activePalette != palette;
    if (changePalette) {
        KIconLoader::global()->setCustomPalette(palette);
    }
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    const QPixmap pixmap = icon.pixmap(size, devicePixelRatio, mode, state);
#else
    Q_UNUSED(devicePixelRatio);
    const QPixmap pixmap = icon.pixmap(size, mode, state);
#endif
    if (changePalette) {
        if (activePalette == QPalette()) {
            KIconLoader::global()->resetPalette();
        } else {
            KIconLoader::global()->setCustomPalette(activePalette);
        }
    }
    return pixmap;
}

bool Helper::shouldDrawToolsArea(const QWidget *widget) const
{
    if (!widget) {
        return false;
    }
    static bool isAuto = false;
    static QString borderSize;
    if (!_cachedAutoValid) {
        KConfigGroup kdecorationGroup(_kwinConfig->group(QStringLiteral("org.kde.kdecoration2")));
        isAuto = kdecorationGroup.readEntry("BorderSizeAuto", true);
        borderSize = kdecorationGroup.readEntry("BorderSize", "Normal");
        _cachedAutoValid = true;
    }
    if (isAuto) {
        auto window = widget->window();
        if (qobject_cast<const QDialog *>(widget)) {
            return true;
        }
        if (window) {
            auto handle = window->windowHandle();
            if (handle) {
                auto toolbar = qobject_cast<const QToolBar *>(widget);
                if (toolbar) {
                    if (toolbar->isFloating()) {
                        return false;
                    }
                }
                return true;
            }
        } else {
            return false;
        }
    }
    if (borderSize != "None" && borderSize != "NoSides") {
        return false;
    }
    return true;
}

Qt::Edges Helper::menuSeamlessEdges(const QWidget *widget)
{
    if (widget) {
        auto edges = widget->property(PropertyNames::menuSeamlessEdges).value<Qt::Edges>();
        // Fallback to older property
        if (edges == Qt::Edges() && widget->property(PropertyNames::isTopMenu).toBool()) {
            edges = Qt::TopEdge;
        }
        return edges;
    }
    return Qt::Edges();
}

qreal Helper::devicePixelRatio(QPainter *painter) const
{
    return painter->device() ? painter->device()->devicePixelRatioF() : qApp->devicePixelRatio();
}
//______________________________________________________________________________
void Helper::renderOptionMenuIndicator(QPainter *painter, const QRectF &rect, const QColor &base, bool enabled) const
{
    // Motif-Optionsmenü: kleiner erhabener Balken statt Pfeil
    const QRect r = rect.toAlignedRect();
    const int w = qMin(12, r.width()), h = qMin(7, r.height()); // Schiefer: nie größer als rect
    if (w < 4 || h < 4) {
        return;
    }
    const QRect bar(r.left() + (r.width() - w) / 2, r.top() + (r.height() - h) / 2, w, h);
    renderBevelPanel(painter, bar, enabled ? base : QColor(), base, false, 2);
}

//______________________________________________________________________________
void Helper::renderRetroDial(QPainter *painter, const QRectF &rect, const QPalette &palette, qreal angle, bool hasFocus, bool enabled) const
{
    const qreal size = qMin(rect.width(), rect.height()) - 2;
    if (size < 6) {
        return; // Schiefer: zu klein für Mulde und Ring
    }
    const QRectF outer(rect.center().x() - size / 2, rect.center().y() - size / 2, size, size);
    const QColor base = palette.color(QPalette::Window);
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    // versenkte Mulde
    painter->setPen(Qt::NoPen);
    painter->setBrush(KColorUtils::mix(base, Qt::black, 0.12));
    painter->drawEllipse(outer);
    QPen pen(bevelDark(base), 2);
    pen.setCapStyle(Qt::FlatCap);
    painter->setBrush(Qt::NoBrush);
    const QRectF ring = outer.adjusted(1, 1, -1, -1);
    painter->setPen(pen);
    painter->drawArc(ring, 45 * 16, 180 * 16);
    pen.setColor(bevelLight(base));
    painter->setPen(pen);
    painter->drawArc(ring, 225 * 16, 180 * 16);

    // erhabener Knopf (bei sehr kleinem Regler nur die Mulde)
    const QRectF knob = outer.adjusted(6, 6, -6, -6);
    if (knob.width() < 8) {
        painter->restore();
        return;
    }
    painter->setPen(Qt::NoPen);
    painter->setBrush(KColorUtils::mix(palette.color(QPalette::Button), Qt::white, 0.12));
    painter->drawEllipse(knob);
    const QRectF kring = knob.adjusted(1, 1, -1, -1);
    pen.setColor(bevelLight(base));
    painter->setPen(pen);
    painter->drawArc(kring, 45 * 16, 180 * 16);
    pen.setColor(bevelDark(base));
    painter->setPen(pen);
    painter->drawArc(kring, 225 * 16, 180 * 16);

    // Kerbe als Zeiger
    const QPointF c = knob.center();
    const qreal rk = knob.width() / 2;
    const QPointF dir(std::cos(angle), -std::sin(angle));
    const QPointF p1 = c + dir * (rk * 0.25), p2 = c + dir * (rk - 3);
    QColor notch = hasFocus ? palette.color(QPalette::Highlight).darker(130) : bevelDark(base).darker(130);
    if (!enabled) {
        notch = bevelDark(base);
    }
    painter->setPen(QPen(notch, 3, Qt::SolidLine, Qt::FlatCap));
    painter->drawLine(p1, p2);
    painter->restore();
}

}
