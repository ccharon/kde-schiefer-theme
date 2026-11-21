/*
 * Schiefer – Fensterdekoration im Motif/CDE-Stil.
 * Struktur angelehnt an die Breeze-Dekoration (KDE, GPL-2.0-only OR GPL-3.0-only).
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
 */
#include "retrodecoration.h"

#include <KDecoration3/ScaleHelpers>

#include <KConfigGroup>
#include <KPluginFactory>
#include <KSharedConfig>

#include <QDBusConnection>
#include <QFontMetricsF>
#include <QPainter>
#include <QPolygonF>
#include <QTimer>

K_PLUGIN_FACTORY_WITH_JSON(SchieferDecoFactory,
                           "schiefer.json",
                           registerPlugin<Schiefer::Decoration>();
                           registerPlugin<Schiefer::Button>(&Schiefer::Button::createFromArgs);)

namespace Schiefer
{
using KDecoration3::ColorGroup;
using KDecoration3::ColorRole;
using KDecoration3::DecorationButtonType;

namespace
{
// Geometrie nach CDE/dtwm vermessen (logische Pixel, bei Skalierung 1 = Gerätepixel):
// Rahmen 5 px = 2 px äußere Lichtkante + 2 px Fläche + 1 px innere (versenkte) Kante.
// Bei Skalierung ≠ 1 wird jede Kante auf ganze Gerätepixel gerundet (siehe Decoration::devicePixels).
constexpr qreal FrameWidth = 5;
constexpr qreal OuterBevel = 2;
constexpr qreal InnerBevel = 1;
constexpr qreal ButtonBevel = 1;  // Titelknöpfe und Titelfeld
constexpr qreal MinTitleHeight = 20;

QColor mix(const QColor &a, const QColor &b, qreal t)
{
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t,
                            a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t);
}

// Rechteck in Gerätepixeln (ganzzahlig) → logische Koordinaten
QRectF fromDevice(qreal x, qreal y, qreal w, qreal h, qreal scale)
{
    return QRectF(x / scale, y / scale, w / scale, h / scale);
}

// Lichtkante: oben/links hell, unten/rechts dunkel (vertauscht = versenkt).
// width = Anzahl Gerätepixel; je Ring ein Gerätepixel, Ecken diagonal geteilt.
void bevel(QPainter *p, const QRectF &r, QColor hi, QColor lo, int width, qreal scale, bool sunken = false)
{
    if (sunken) {
        std::swap(hi, lo);
    }
    // Rechteck auf das Gerätepixelraster legen und dort rechnen
    const qreal x0 = std::round(r.left() * scale), y0 = std::round(r.top() * scale);
    const qreal w0 = std::round(r.right() * scale) - x0, h0 = std::round(r.bottom() * scale) - y0;
    for (int i = 0; i < width; ++i) {
        const qreal x = x0 + i, y = y0 + i;
        const qreal w = w0 - 2 * i, h = h0 - 2 * i;
        if (w <= 0 || h <= 0) {
            break;
        }
        p->fillRect(fromDevice(x, y, w, 1, scale), hi);                 // oben
        p->fillRect(fromDevice(x, y, 1, h, scale), hi);                 // links
        p->fillRect(fromDevice(x + 1, y + h - 1, w - 1, 1, scale), lo); // unten
        p->fillRect(fromDevice(x + w - 1, y + 1, 1, h - 1, scale), lo); // rechts
    }
}
} // namespace

//________________________________________________________________ ColorCache
std::shared_ptr<ColorCache> ColorCache::instance()
{
    // lebt, solange eine Dekoration ihn hält
    static std::weak_ptr<ColorCache> s_instance;
    auto cache = s_instance.lock();
    if (!cache) {
        cache = std::make_shared<ColorCache>();
        s_instance = cache;
    }
    return cache;
}

ColorCache::ColorCache()
{
    read();
    // Farbschema-Wechsel kommt über KGlobalSettings
    QDBusConnection::sessionBus().connect(QString(),
                                          QStringLiteral("/KGlobalSettings"),
                                          QStringLiteral("org.kde.KGlobalSettings"),
                                          QStringLiteral("notifyChange"),
                                          this,
                                          SLOT(notifyChange(int, int)));
}

void ColorCache::notifyChange(int type, int arg)
{
    Q_UNUSED(arg)
    // KGlobalSettings::ChangeType: PaletteChanged = 0, StyleChanged = 2, SettingsChanged = 3;
    // Schrift, Icons, Cursor usw. betreffen die Titelleistenfarben nicht
    if (type != 0 && type != 2 && type != 3) {
        return;
    }
    read();
    Q_EMIT changed();
}

void ColorCache::read()
{
    // [WM] aus dem aktiven Farbschema (kdeglobals)
    auto config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    config->reparseConfiguration();
    const KConfigGroup wm(config, QStringLiteral("WM"));
    activeBg = wm.readEntry("activeBackground", QColor());
    activeFg = wm.readEntry("activeForeground", QColor());
    inactiveBg = wm.readEntry("inactiveBackground", QColor());
    inactiveFg = wm.readEntry("inactiveForeground", QColor());
}

//________________________________________________________________ Decoration
Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

bool Decoration::init()
{
    m_colors = ColorCache::instance();
    connect(m_colors.get(), &ColorCache::changed, this, &Decoration::reconfigure);
    readColors();

    auto s = settings();
    connect(s.get(), &KDecoration3::DecorationSettings::borderSizeChanged, this, &Decoration::recalculateBorders);
    connect(s.get(), &KDecoration3::DecorationSettings::fontChanged, this, &Decoration::recalculateBorders);
    connect(s.get(), &KDecoration3::DecorationSettings::reconfigured, this, &Decoration::reconfigure);
    connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsLeftChanged, this, [this] {
        QTimer::singleShot(0, this, &Decoration::updateLayout);
    });
    connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsRightChanged, this, [this] {
        QTimer::singleShot(0, this, &Decoration::updateLayout);
    });

    auto w = window();
    connect(w, &KDecoration3::DecoratedWindow::activeChanged, this, [this] {
        update();
    });
    connect(w, &KDecoration3::DecoratedWindow::captionChanged, this, [this] {
        update();
    });
    connect(w, &KDecoration3::DecoratedWindow::paletteChanged, this, &Decoration::reconfigure);
    connect(w, &KDecoration3::DecoratedWindow::maximizedChanged, this, &Decoration::recalculateBorders);
    connect(w, &KDecoration3::DecoratedWindow::maximizedHorizontallyChanged, this, &Decoration::recalculateBorders);
    connect(w, &KDecoration3::DecoratedWindow::maximizedVerticallyChanged, this, &Decoration::recalculateBorders);
    connect(w, &KDecoration3::DecoratedWindow::shadedChanged, this, &Decoration::recalculateBorders);
    connect(w, &KDecoration3::DecoratedWindow::adjacentScreenEdgesChanged, this, &Decoration::recalculateBorders);
    connect(w, &KDecoration3::DecoratedWindow::widthChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::nextScaleChanged, this, &Decoration::recalculateBorders);
    connect(this, &KDecoration3::Decoration::bordersChanged, this, &Decoration::updateLayout);

    m_leftButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Left, this, &Button::create);
    m_rightButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Right, this, &Button::create);

    recalculateBorders();
    updateLayout();
    return true;
}

void Decoration::readColors()
{
    // [WM] aus dem geteilten Cache; Rückfall auf die Dekorationsfarben von KWin
    const auto w = window();
    auto pick = [](const QColor &c, const QColor &fallback) {
        return c.isValid() ? c : fallback;
    };
    m_activeBg = pick(m_colors->activeBg, w->color(ColorGroup::Active, ColorRole::TitleBar));
    m_activeFg = pick(m_colors->activeFg, w->color(ColorGroup::Active, ColorRole::Foreground));
    m_inactiveBg = pick(m_colors->inactiveBg, w->color(ColorGroup::Inactive, ColorRole::TitleBar));
    m_inactiveFg = pick(m_colors->inactiveFg, w->color(ColorGroup::Inactive, ColorRole::Foreground));
}

void Decoration::reconfigure()
{
    readColors();
    recalculateBorders();
    update();
}

bool Decoration::isMaximized() const
{
    return window()->isMaximized();
}

qreal Decoration::scale() const
{
    return window()->nextScale();
}

int Decoration::devicePixels(qreal logical) const
{
    return std::max(1, int(std::round(logical * scale())));
}

qreal Decoration::snap(qreal logical) const
{
    return KDecoration3::snapToPixelGrid(logical, scale());
}

qreal Decoration::leftInset() const
{
    return borderLeft() > 0 ? frameWidth() : 0;
}

qreal Decoration::rightInset() const
{
    return borderRight() > 0 ? frameWidth() : 0;
}

QColor Decoration::faceColor() const
{
    return window()->isActive() ? m_activeBg : m_inactiveBg;
}

QColor Decoration::lightColor() const
{
    return mix(faceColor(), Qt::white, 0.55);
}

QColor Decoration::darkColor() const
{
    return mix(faceColor(), Qt::black, 0.5);
}

QColor Decoration::fontColor() const
{
    return window()->isActive() ? m_activeFg : m_inactiveFg;
}

qreal Decoration::frameWidth() const
{
    if (isMaximized()) {
        return 0;
    }
    switch (settings()->borderSize()) {
    case KDecoration3::BorderSize::None:
    case KDecoration3::BorderSize::NoSides:
        return 0;
    default:
        return snap(FrameWidth);
    }
}

qreal Decoration::titleHeight() const
{
    const QFontMetricsF fm(settings()->font());
    return snap(std::max<qreal>(MinTitleHeight, std::ceil(fm.height()) + 4));
}

void Decoration::recalculateBorders()
{
    const qreal b = frameWidth();
    const auto edges = window()->adjacentScreenEdges();
    const qreal side = b;
    const qreal bottom = window()->isShaded() ? 0 : b;
    // KDE-Einstellung „Keine Seitenränder“: unten trotzdem schmal lassen
    const bool noSides = !isMaximized() && settings()->borderSize() == KDecoration3::BorderSize::NoSides;
    setBorders(QMarginsF((edges & Qt::LeftEdge) ? 0 : side,
                         b + titleHeight(),
                         (edges & Qt::RightEdge) ? 0 : side,
                         noSides ? snap(3) : bottom));
    setBorderRadius(KDecoration3::BorderRadius());
    setBorderOutline(KDecoration3::BorderOutline());
    setOpaque(isMaximized());
    // ohne Ränder trotzdem an den Seiten greifbar machen
    const qreal ext = (side == 0 && !isMaximized()) ? 4 : 0;
    setResizeOnlyBorders(QMarginsF(ext, 0, ext, ext));
    updateLayout();
    update();
}

void Decoration::updateLayout()
{
    if (!m_leftButtons || !m_rightButtons) {
        return;
    }
    const qreal b = frameWidth();
    const qreal t = titleHeight();
    const qreal width = size().width();
    const qreal l = leftInset(), r = rightInset();

    for (auto *button : m_leftButtons->buttons() + m_rightButtons->buttons()) {
        button->setGeometry(QRectF(0, 0, t, t));
    }
    m_leftButtons->setSpacing(0);
    m_rightButtons->setSpacing(0);
    m_leftButtons->setPos(QPointF(l, b));
    m_rightButtons->setPos(QPointF(width - r - m_rightButtons->geometry().width(), b));

    setTitleBar(QRectF(l, b, width - l - r, t));
    update();
}

void Decoration::paint(QPainter *painter, const QRectF &repaintRegion)
{
    const QRectF full = rect();
    const qreal b = frameWidth();
    const qreal t = titleHeight();
    const qreal top = b + t;
    const qreal s = scale();
    const QColor face = faceColor(), hi = lightColor(), lo = darkColor();
    // Kantenstärken in Gerätepixeln (bei Skalierung 1: außen 2, innen 1, Knöpfe/Kerben 1)
    const int outerPx = devicePixels(OuterBevel), innerPx = devicePixels(InnerBevel), buttonPx = devicePixels(ButtonBevel);

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    painter->setClipRect(full, Qt::IntersectClip);

    // Rahmenflächen (nicht über den Fensterinhalt malen)
    painter->fillRect(QRectF(0, 0, full.width(), top), face);
    if (!window()->isShaded()) {
        painter->fillRect(QRectF(0, top, borderLeft(), full.height() - top), face);
        painter->fillRect(QRectF(full.width() - borderRight(), top, borderRight(), full.height() - top), face);
        painter->fillRect(QRectF(0, full.height() - borderBottom(), full.width(), borderBottom()), face);
    }

    if (std::round(b * s) >= outerPx + innerPx) {
        // Seiten ohne Rand (am Bildschirmrand): Rahmen gedanklich über den Rand hinaus verlängern,
        // der Ausschnitt schneidet Seitenkanten und -kerben dort ab
        const QRectF frame = full.adjusted(leftInset() - b, 0, b - rightInset(), 0);

        // außen 2 px erhaben (Ecken diagonal geteilt), innen 1 px versenkt
        bevel(painter, frame, hi, lo, outerPx, s);
        const qreal in = b - innerPx / s;
        bevel(painter, frame.adjusted(in, in, -in, -in), hi, lo, innerPx, s, true);

        // Motif-Eckkerben bei Rahmen + Titelhöhe: verlängern die Fugen der Titelleiste
        // (rechte Kante des ersten linken Knopfs, linke Kante des letzten rechten Knopfs,
        // Unterkante der Titelleiste) durch den Rahmen; unten gespiegelt.
        // Die äußerste Pixelreihe bleibt durchgehend. Alles in Gerätepixeln gerechnet.
        auto dev = [s](qreal logical) {
            return std::round(logical * s);
        };
        const qreal X0 = dev(frame.left()), Y0 = dev(frame.top());
        const qreal W = dev(frame.right()) - X0, H = dev(frame.bottom()) - Y0;
        const qreal B = dev(b), C = dev(top); // = b + t
        const qreal skip = devicePixels(1); // durchgehende äußerste Reihe
        const qreal len = B - skip;
        // Fuge an Position pos: dunkel davor, hell danach (je buttonPx breit)
        auto vnotch = [&](qreal pos, qreal y0) {
            painter->fillRect(fromDevice(X0 + pos - buttonPx, Y0 + y0, buttonPx, len, s), lo);
            painter->fillRect(fromDevice(X0 + pos, Y0 + y0, buttonPx, len, s), hi);
        };
        auto hnotch = [&](qreal pos, qreal x0) {
            painter->fillRect(fromDevice(X0 + x0, Y0 + pos - buttonPx, len, buttonPx, s), lo);
            painter->fillRect(fromDevice(X0 + x0, Y0 + pos, len, buttonPx, s), hi);
        };
        if (W > 2 * C + 2 * buttonPx) {
            vnotch(C, skip);
            vnotch(W - C, skip);
            if (!window()->isShaded()) {
                vnotch(C, H - B);
                vnotch(W - C, H - B);
            }
        }
        if (!window()->isShaded() && H > 2 * C + 2 * buttonPx) {
            hnotch(C, skip);
            hnotch(C, W - B);
            hnotch(H - C, skip);
            hnotch(H - C, W - B);
        }
    }

    // Titelfeld zwischen den Knopfgruppen
    const qreal left = m_leftButtons->buttons().isEmpty() ? leftInset() : m_leftButtons->geometry().right();
    const qreal right = m_rightButtons->buttons().isEmpty() ? full.width() - rightInset() : m_rightButtons->geometry().left();
    const QRectF label(left, b, std::max<qreal>(0, right - left), t);
    if (label.width() > 0) {
        bevel(painter, label, hi, lo, buttonPx, s);
        painter->setFont(settings()->font());
        painter->setPen(fontColor());
        const QRectF textRect = label.adjusted(6, 0, -6, 0);
        const QString caption = painter->fontMetrics().elidedText(window()->caption(), Qt::ElideMiddle, int(textRect.width()));
        painter->drawText(textRect, Qt::AlignCenter | Qt::TextSingleLine, caption);
    }
    painter->restore();

    m_leftButtons->paint(painter, repaintRegion);
    m_rightButtons->paint(painter, repaintRegion);
}

//________________________________________________________________ Button
Button::Button(DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
    const qreal t = decoration->titleHeight();
    setGeometry(QRectF(0, 0, t, t));
    connect(this, &KDecoration3::DecorationButton::hoveredChanged, this, [this] {
        update();
    });
}

QObject *Button::createFromArgs(QWidget *parentWidget, QObject *parent, const KPluginMetaData &metaData, const QVariantList &args)
{
    Q_UNUSED(parentWidget)
    Q_UNUSED(metaData)
    if (args.size() < 2 || !args.at(0).canConvert<DecorationButtonType>()) {
        return nullptr;
    }
    auto d = qobject_cast<Decoration *>(args.at(1).value<QObject *>());
    if (!d) {
        return nullptr;
    }
    return create(args.at(0).value<DecorationButtonType>(), d, parent);
}

KDecoration3::DecorationButton *Button::create(DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent)
{
    auto d = qobject_cast<Decoration *>(decoration);
    if (!d) {
        return nullptr;
    }
    auto *b = new Button(type, d, parent);
    const auto c = d->window();
    switch (type) {
    case DecorationButtonType::Close:
        b->setVisible(c->isCloseable());
        QObject::connect(c, &KDecoration3::DecoratedWindow::closeableChanged, b, &Button::setVisible);
        break;
    case DecorationButtonType::Maximize:
        b->setVisible(c->isMaximizeable());
        QObject::connect(c, &KDecoration3::DecoratedWindow::maximizeableChanged, b, &Button::setVisible);
        break;
    case DecorationButtonType::Minimize:
        b->setVisible(c->isMinimizeable());
        QObject::connect(c, &KDecoration3::DecoratedWindow::minimizeableChanged, b, &Button::setVisible);
        break;
    case DecorationButtonType::ContextHelp:
        b->setVisible(c->providesContextHelp());
        QObject::connect(c, &KDecoration3::DecoratedWindow::providesContextHelpChanged, b, &Button::setVisible);
        break;
    case DecorationButtonType::Shade:
        b->setVisible(c->isShadeable());
        QObject::connect(c, &KDecoration3::DecoratedWindow::shadeableChanged, b, &Button::setVisible);
        break;
    default:
        break;
    }
    return b;
}

void Button::paint(QPainter *painter, const QRectF &repaintRegion)
{
    Q_UNUSED(repaintRegion)
    auto d = qobject_cast<Decoration *>(decoration());
    if (!d || !isVisible() || type() == DecorationButtonType::Spacer) {
        return;
    }

    const QRectF g = geometry();
    const qreal s = g.width();
    const qreal scale = d->scale();
    const int bevelPx = d->devicePixels(ButtonBevel);
    const QPointF c = g.center();
    QColor face = d->faceColor();
    if (isHovered() && !isPressed()) {
        face = face.lighter(110);
    }
    const QColor hi = d->lightColor(), lo = d->darkColor(), fg = d->fontColor();
    const bool sunken = isPressed() || (isChecked() && type() != DecorationButtonType::Maximize);

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    painter->fillRect(g, face);
    bevel(painter, g, hi, lo, bevelPx, scale, sunken);

    // Längen auf ganze Gerätepixel (bei Skalierung 1: ganze Pixel wie bisher)
    auto snap = [d](qreal v) {
        return d->snap(v);
    };
    auto floorSnap = [scale](qreal v) {
        return std::floor(v * scale) / scale;
    };
    // auf dem Gerätepixelraster im Knopf zentriertes Rechteck
    auto centered = [&](qreal w, qreal h) {
        return QRectF(g.left() + floorSnap((g.width() - w) / 2), g.top() + floorSnap((g.height() - h) / 2), w, h);
    };
    // kleines erhabenes/versenktes Kästchen
    auto box = [&](const QRectF &r, bool in) {
        const QRectF rr = KDecoration3::snapToPixelGrid(r, scale);
        painter->fillRect(rr, face);
        bevel(painter, rr, hi, lo, bevelPx, scale, in);
    };

    switch (type()) {
    case DecorationButtonType::Menu: {
        // Motif: flacher Querbalken
        box(centered(snap(s * 0.6), std::max<qreal>(snap(3), snap(s * 0.2))), isPressed());
        break;
    }
    case DecorationButtonType::Minimize: {
        const qreal q = std::max<qreal>(snap(4), snap(s * 0.2));
        box(centered(q, q), isPressed());
        break;
    }
    case DecorationButtonType::Maximize: {
        const qreal q = snap(s * 0.6);
        box(centered(q, q), isChecked() != isPressed());
        break;
    }
    case DecorationButtonType::Shade: {
        const QRectF r = centered(snap(s * 0.6), snap(s * 0.6));
        box(QRectF(r.left(), r.top(), r.width(), std::max<qreal>(snap(3), snap(s * 0.2))), isChecked());
        break;
    }
    case DecorationButtonType::Close: {
        painter->setRenderHint(QPainter::Antialiasing, true);
        QPen pen(fg, std::max<qreal>(2, std::round(s / 10)));
        pen.setCapStyle(Qt::SquareCap);
        painter->setPen(pen);
        const qreal in = std::round(s * 0.32);
        painter->drawLine(QPointF(g.left() + in, g.top() + in), QPointF(g.right() - in, g.bottom() - in));
        painter->drawLine(QPointF(g.left() + in, g.bottom() - in), QPointF(g.right() - in, g.top() + in));
        break;
    }
    case DecorationButtonType::KeepAbove:
    case DecorationButtonType::KeepBelow: {
        painter->setRenderHint(QPainter::Antialiasing, true);
        painter->setPen(Qt::NoPen);
        painter->setBrush(fg);
        const qreal h = s * 0.18, w = s * 0.26;
        const qreal dir = type() == DecorationButtonType::KeepAbove ? -1 : 1;
        painter->drawPolygon(QPolygonF({QPointF(c.x() - w, c.y() - dir * h), QPointF(c.x() + w, c.y() - dir * h), QPointF(c.x(), c.y() + dir * h)}));
        break;
    }
    case DecorationButtonType::OnAllDesktops: {
        painter->setRenderHint(QPainter::Antialiasing, true);
        painter->setPen(Qt::NoPen);
        painter->setBrush(fg);
        const qreal r = s * 0.12;
        painter->drawEllipse(c, r, r);
        break;
    }
    case DecorationButtonType::ContextHelp: {
        QFont f = d->settings()->font();
        f.setBold(true);
        painter->setFont(f);
        painter->setPen(fg);
        painter->drawText(g, Qt::AlignCenter, QStringLiteral("?"));
        break;
    }
    case DecorationButtonType::ApplicationMenu: {
        const qreal w = snap(s * 0.5), y0 = snap(c.y() - s * 0.18);
        for (int i = 0; i < 3; ++i) {
            painter->fillRect(QRectF(snap(c.x() - w / 2), y0 + i * snap(s * 0.18), w, snap(2)), fg);
        }
        break;
    }
    case DecorationButtonType::ExcludeFromCapture: {
        painter->setRenderHint(QPainter::Antialiasing, true);
        painter->setPen(QPen(fg, 2));
        painter->setBrush(Qt::NoBrush);
        painter->drawEllipse(c, s * 0.2, s * 0.2);
        break;
    }
    default:
        break;
    }
    painter->restore();
}

} // namespace Schiefer

#include "retrodecoration.moc"
