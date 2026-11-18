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
                           registerPlugin<Schiefer::Button>();)

namespace Schiefer
{
using KDecoration3::ColorGroup;
using KDecoration3::ColorRole;
using KDecoration3::DecorationButtonType;

namespace
{
// Geometrie nach CDE/dtwm vermessen:
// Rahmen 5 px = 2 px äußere Lichtkante + 2 px Fläche + 1 px innere (versenkte) Kante
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

// Lichtkante: oben/links hell, unten/rechts dunkel (vertauscht = versenkt)
void bevel(QPainter *p, const QRectF &r, QColor hi, QColor lo, qreal width, bool sunken = false)
{
    if (sunken) {
        std::swap(hi, lo);
    }
    for (int i = 0; i < int(width); ++i) {
        const qreal x = r.left() + i, y = r.top() + i;
        const qreal w = r.width() - 2 * i, h = r.height() - 2 * i;
        if (w <= 0 || h <= 0) {
            break;
        }
        p->fillRect(QRectF(x, y, w, 1), hi);           // oben
        p->fillRect(QRectF(x, y, 1, h), hi);           // links
        p->fillRect(QRectF(x + 1, y + h - 1, w - 1, 1), lo); // unten
        p->fillRect(QRectF(x + w - 1, y + 1, 1, h - 1), lo); // rechts
    }
}
} // namespace

//________________________________________________________________ Decoration
Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

bool Decoration::init()
{
    readColors();

    // Farbschema-Wechsel kommt über KGlobalSettings
    QDBusConnection::sessionBus().connect(QString(),
                                          QStringLiteral("/KGlobalSettings"),
                                          QStringLiteral("org.kde.KGlobalSettings"),
                                          QStringLiteral("notifyChange"),
                                          this,
                                          SLOT(reconfigure()));

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
    // [WM] aus dem aktiven Farbschema (kdeglobals); Rückfall auf die Dekorationsfarben von KWin
    auto config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    config->reparseConfiguration();
    const KConfigGroup wm(config, QStringLiteral("WM"));
    const auto w = window();
    m_activeBg = wm.readEntry("activeBackground", w->color(ColorGroup::Active, ColorRole::TitleBar));
    m_activeFg = wm.readEntry("activeForeground", w->color(ColorGroup::Active, ColorRole::Foreground));
    m_inactiveBg = wm.readEntry("inactiveBackground", w->color(ColorGroup::Inactive, ColorRole::TitleBar));
    m_inactiveFg = wm.readEntry("inactiveForeground", w->color(ColorGroup::Inactive, ColorRole::Foreground));
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
        return KDecoration3::snapToPixelGrid(FrameWidth, window()->nextScale());
    }
}

qreal Decoration::titleHeight() const
{
    const QFontMetricsF fm(settings()->font());
    return KDecoration3::snapToPixelGrid(std::max<qreal>(MinTitleHeight, std::ceil(fm.height()) + 4), window()->nextScale());
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
                         noSides ? 3 : bottom));
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

    for (auto *button : m_leftButtons->buttons() + m_rightButtons->buttons()) {
        button->setGeometry(QRectF(0, 0, t, t));
    }
    m_leftButtons->setSpacing(0);
    m_rightButtons->setSpacing(0);
    m_leftButtons->setPos(QPointF(b, b));
    m_rightButtons->setPos(QPointF(width - b - m_rightButtons->geometry().width(), b));

    setTitleBar(QRectF(b, b, width - 2 * b, t));
    update();
}

void Decoration::paint(QPainter *painter, const QRectF &repaintRegion)
{
    const QRectF full = rect();
    const qreal b = frameWidth();
    const qreal t = titleHeight();
    const qreal top = b + t;
    const QColor face = faceColor(), hi = lightColor(), lo = darkColor();

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);

    // Rahmenflächen (nicht über den Fensterinhalt malen)
    painter->fillRect(QRectF(0, 0, full.width(), top), face);
    if (!window()->isShaded()) {
        painter->fillRect(QRectF(0, top, borderLeft(), full.height() - top), face);
        painter->fillRect(QRectF(full.width() - borderRight(), top, borderRight(), full.height() - top), face);
        painter->fillRect(QRectF(0, full.height() - borderBottom(), full.width(), borderBottom()), face);
    }

    if (b >= OuterBevel + InnerBevel) {
        // außen 2 px erhaben (Ecken diagonal geteilt), innen 1 px versenkt
        bevel(painter, full, hi, lo, OuterBevel);
        const qreal in = b - InnerBevel;
        bevel(painter, full.adjusted(in, in, -in, -in), hi, lo, InnerBevel, true);

        // Motif-Eckkerben bei Rahmen + Titelhöhe: verlängern die Fugen der Titelleiste
        // (rechte Kante des ersten linken Knopfs, linke Kante des letzten rechten Knopfs,
        // Unterkante der Titelleiste) durch den Rahmen; unten gespiegelt.
        // Die äußerste Pixelreihe bleibt durchgehend.
        const qreal W = full.width(), H = full.height();
        const qreal c = top; // = b + t
        const qreal len = b - 1;
        auto vnotch = [&](qreal xDark, qreal y0) {
            painter->fillRect(QRectF(xDark, y0, 1, len), lo);
            painter->fillRect(QRectF(xDark + 1, y0, 1, len), hi);
        };
        auto hnotch = [&](qreal yDark, qreal x0) {
            painter->fillRect(QRectF(x0, yDark, len, 1), lo);
            painter->fillRect(QRectF(x0, yDark + 1, len, 1), hi);
        };
        if (W > 2 * c + 2) {
            vnotch(c - 1, 1);
            vnotch(W - c - 1, 1);
            if (!window()->isShaded()) {
                vnotch(c - 1, H - b);
                vnotch(W - c - 1, H - b);
            }
        }
        if (!window()->isShaded() && H > 2 * c + 2) {
            hnotch(c - 1, 1);
            hnotch(c - 1, W - b);
            hnotch(H - c - 1, 1);
            hnotch(H - c - 1, W - b);
        }
    }

    // Titelfeld zwischen den Knopfgruppen
    const qreal left = m_leftButtons->buttons().isEmpty() ? b : m_leftButtons->geometry().right();
    const qreal right = m_rightButtons->buttons().isEmpty() ? full.width() - b : m_rightButtons->geometry().left();
    const QRectF label(left, b, std::max<qreal>(0, right - left), t);
    if (label.width() > 0) {
        bevel(painter, label, hi, lo, ButtonBevel);
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

Button::Button(QObject *parent, const QVariantList &args)
    : Button(args.at(0).value<DecorationButtonType>(), args.at(1).value<Decoration *>(), parent)
{
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
    bevel(painter, g, hi, lo, ButtonBevel, sunken);

    // ganzzahlig im Knopf zentriertes Rechteck
    auto centered = [&](qreal w, qreal h) {
        return QRectF(g.left() + std::floor((g.width() - w) / 2), g.top() + std::floor((g.height() - h) / 2), w, h);
    };
    // kleines erhabenes/versenktes Kästchen
    auto box = [&](const QRectF &r, bool in) {
        const QRectF rr = r.toAlignedRect();
        painter->fillRect(rr, face);
        bevel(painter, rr, hi, lo, 1, in);
    };

    switch (type()) {
    case DecorationButtonType::Menu: {
        // Motif: flacher Querbalken
        box(centered(std::round(s * 0.6), std::max<qreal>(3, std::round(s * 0.2))), isPressed());
        break;
    }
    case DecorationButtonType::Minimize: {
        const qreal q = std::max<qreal>(4, std::round(s * 0.2));
        box(centered(q, q), isPressed());
        break;
    }
    case DecorationButtonType::Maximize: {
        const qreal q = std::round(s * 0.6);
        box(centered(q, q), isChecked() != isPressed());
        break;
    }
    case DecorationButtonType::Shade: {
        const QRectF r = centered(std::round(s * 0.6), std::round(s * 0.6));
        box(QRectF(r.left(), r.top(), r.width(), std::max<qreal>(3, std::round(s * 0.2))), isChecked());
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
        const qreal w = std::round(s * 0.5), y0 = std::round(c.y() - s * 0.18);
        for (int i = 0; i < 3; ++i) {
            painter->fillRect(QRectF(std::round(c.x() - w / 2), y0 + i * std::round(s * 0.18), w, 2), fg);
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
