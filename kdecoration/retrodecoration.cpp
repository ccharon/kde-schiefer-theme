/*
 * Schiefer: window decoration in Motif/CDE style.
 * Structure follows the Breeze decoration (KDE, GPL-2.0-only OR GPL-3.0-only).
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
 */
#include "retrodecoration.h"
#include "schiefercolors.h"

#include <KDecoration3/ScaleHelpers>

#include <KConfigGroup>
#include <KPluginFactory>
#include <KSharedConfig>

#include <cmath>

#include <QDBusConnection>
#include <QFontMetricsF>
#include <QGuiApplication>
#include <QHoverEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QPolygonF>
#include <QStyleHints>
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
// Geometry measured from CDE/dtwm (logical pixels; at scale 1 equal to device pixels):
// frame 5 px = 2 px outer bevel + 2 px surface + 1 px inner (sunken) edge.
// At other scales every edge is rounded to whole device pixels (see Decoration::devicePixels).
constexpr qreal FrameWidth = 5;
constexpr qreal OuterBevel = 2;
constexpr qreal InnerBevel = 1;
constexpr qreal ButtonBevel = 1;  // title buttons and title field
constexpr qreal MinTitleHeight = 20;

// rectangle in (integer) device pixels -> logical coordinates
QRectF fromDevice(qreal x, qreal y, qreal w, qreal h, qreal scale)
{
    return QRectF(x / scale, y / scale, w / scale, h / scale);
}

// Bevel: light top/left, dark bottom/right (swapped = sunken).
// width = number of device pixels; one device pixel per ring, corners split diagonally.
void bevel(QPainter *p, const QRectF &r, QColor hi, QColor lo, int width, qreal scale, bool sunken = false)
{
    if (sunken) {
        std::swap(hi, lo);
    }
    // snap the rectangle to the device pixel grid and compute there
    const qreal x0 = std::round(r.left() * scale), y0 = std::round(r.top() * scale);
    const qreal w0 = std::round(r.right() * scale) - x0, h0 = std::round(r.bottom() * scale) - y0;
    for (int i = 0; i < width; ++i) {
        const qreal x = x0 + i, y = y0 + i;
        const qreal w = w0 - 2 * i, h = h0 - 2 * i;
        if (w <= 0 || h <= 0) {
            break;
        }
        p->fillRect(fromDevice(x, y, w, 1, scale), hi);                 // top
        p->fillRect(fromDevice(x, y, 1, h, scale), hi);                 // left
        p->fillRect(fromDevice(x + 1, y + h - 1, w - 1, 1, scale), lo); // bottom
        p->fillRect(fromDevice(x + w - 1, y + 1, 1, h - 1, scale), lo); // right
    }
}
} // namespace

//________________________________________________________________ ColorCache
std::shared_ptr<ColorCache> ColorCache::instance()
{
    // lives as long as a decoration holds it
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
    // color scheme changes arrive through KGlobalSettings
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
    // fonts, icons, cursors etc. do not affect the title bar colors
    if (type != 0 && type != 2 && type != 3) {
        return;
    }
    read();
    Q_EMIT changed();
}

void ColorCache::read()
{
    // [WM] from the active color scheme (kdeglobals)
    auto config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    config->reparseConfiguration();
    const KConfigGroup wm(config, QStringLiteral("WM"));
    activeBg = wm.readEntry("activeBackground", QColor());
    activeFg = wm.readEntry("activeForeground", QColor());
    inactiveBg = wm.readEntry("inactiveBackground", QColor());
    inactiveFg = wm.readEntry("inactiveForeground", QColor());
}

//________________________________________________________________ DecorationConfig
std::shared_ptr<DecorationConfig> DecorationConfig::instance()
{
    static std::weak_ptr<DecorationConfig> s_instance;
    auto config = s_instance.lock();
    if (!config) {
        config = std::make_shared<DecorationConfig>();
        s_instance = config;
    }
    return config;
}

DecorationConfig::DecorationConfig()
{
    read();
}

void DecorationConfig::watch(const std::shared_ptr<KDecoration3::DecorationSettings> &settings)
{
    if (!settings || m_settings.lock() == settings) {
        return;
    }
    m_settings = settings;
    connect(settings.get(), &KDecoration3::DecorationSettings::reconfigured, this, &DecorationConfig::read);
}

void DecorationConfig::read()
{
    // the values are only read on click or hover, so no repaint is needed
    auto config = KSharedConfig::openConfig(QStringLiteral("schieferrc"), KConfig::NoGlobals);
    config->reparseConfiguration();
    const KConfigGroup group(config, QStringLiteral("Decoration"));
    doubleClickClose = group.readEntry("DoubleClickClose", true);
    motifCorners = group.readEntry("MotifCorners", true);
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
    m_config = DecorationConfig::instance();
    m_config->watch(s);
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

    updateTitleHeight();
    m_leftButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Left, this, &Button::create);
    m_rightButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Right, this, &Button::create);

    recalculateBorders();
    updateLayout();
    return true;
}

void Decoration::readColors()
{
    // [WM] from the shared cache; falls back to the KWin decoration colors
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

// light and shadow edges from the Motif formula (common/schiefercolors.h)
QColor Decoration::lightColor() const
{
    return SchieferColors::topShadow(faceColor());
}

QColor Decoration::darkColor() const
{
    return SchieferColors::bottomShadow(faceColor());
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

void Decoration::updateTitleHeight()
{
    const QFontMetricsF fm(settings()->font());
    m_titleHeight = snap(std::max<qreal>(MinTitleHeight, std::ceil(fm.height()) + 4));
}

void Decoration::recalculateBorders()
{
    updateTitleHeight();
    const qreal b = frameWidth();
    const auto edges = window()->adjacentScreenEdges();
    const qreal side = b;
    const qreal bottom = window()->isShaded() ? 0 : b;
    // KDE setting "No side borders": keep a narrow bottom border anyway
    const bool noSides = !isMaximized() && settings()->borderSize() == KDecoration3::BorderSize::NoSides;
    setBorders(QMarginsF((edges & Qt::LeftEdge) ? 0 : side,
                         b + titleHeight(),
                         (edges & Qt::RightEdge) ? 0 : side,
                         noSides ? snap(3) : bottom));
    setBorderRadius(KDecoration3::BorderRadius());
    setBorderOutline(KDecoration3::BorderOutline());
    setOpaque(isMaximized());
    // keep the sides grabbable even without borders
    const qreal ext = (side == 0 && !isMaximized()) ? 4 : 0;
    setResizeOnlyBorders(QMarginsF(ext, 0, ext, ext));
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

// Motif corner grips (mwm/dtwm): the frame corners extend along each edge up to the notches,
// that is frame + title height from the outer border; dragging there resizes diagonally.
// KDecoration3 determines the section itself (Decoration::Private::updateSectionUnderMouse, corner
// length 2 * largeSpacing, not configurable). So the pointer position is first moved to a
// proxy point that KDecoration3 unambiguously maps to the wanted section.
Qt::WindowFrameSection Decoration::motifSection(const QPointF &pos) const
{
    const qreal b = frameWidth();
    if (!m_config || !m_config->motifCorners || b <= 0 || isMaximized()) {
        return Qt::NoSection;
    }
    const QSizeF sz = size();
    const QPointF p(std::floor(pos.x()), std::floor(pos.y())); // as KDecoration3 does
    if (titleBar().toRect().contains(p.toPoint())) {
        return Qt::NoSection;
    }
    const bool inLeft = p.x() < borderLeft();
    const bool inRight = p.x() >= sz.width() - borderRight();
    const bool inTop = p.y() < b; // frame above the title row
    const bool inBottom = borderBottom() > 0 && p.y() >= sz.height() - borderBottom();
    if (!inLeft && !inRight && !inTop && !inBottom) {
        return Qt::NoSection; // title row height next to the buttons, outside etc.
    }
    // notches as in paint(): the frame is treated as extending beyond borderless sides
    const qreal reach = b + titleHeight();
    const qreal frameLeft = leftInset() - b;
    const qreal frameRight = sz.width() - rightInset() + b;
    const qreal midX = (frameLeft + frameRight) / 2, midY = sz.height() / 2;
    const bool west = p.x() < std::min(frameLeft + reach, midX);
    const bool east = !west && p.x() >= std::max(frameRight - reach, midX);
    const bool shaded = window()->isShaded();
    const bool north = shaded || p.y() < std::min(reach, midY);
    const bool south = !north && p.y() >= std::max(sz.height() - reach, midY);

    if (north && west) {
        return Qt::TopLeftSection;
    }
    if (north && east) {
        return Qt::TopRightSection;
    }
    if (south && west) {
        return Qt::BottomLeftSection;
    }
    if (south && east) {
        return Qt::BottomRightSection;
    }
    // no corner: straight edge, also where KDecoration3 would already see a corner
    if (inLeft) {
        return Qt::LeftSection;
    }
    if (inRight) {
        return Qt::RightSection;
    }
    return inTop ? Qt::TopSection : Qt::BottomSection;
}

QPointF Decoration::motifRemap(const QPointF &p) const
{
    const QSizeF sz = size();
    const qreal r = sz.width() - 1, bt = sz.height() - 1;
    switch (motifSection(p)) {
    case Qt::TopLeftSection:
        return QPointF(0, 0);
    case Qt::TopRightSection:
        return QPointF(r, 0);
    case Qt::BottomLeftSection:
        return QPointF(0, bt);
    case Qt::BottomRightSection:
        return QPointF(r, bt);
    // edge centers: never a KDecoration3 corner there (except for tiny windows) and never a button
    case Qt::LeftSection:
        return QPointF(0, std::floor((titleBar().bottom() + sz.height()) / 2));
    case Qt::RightSection:
        return QPointF(r, std::floor((titleBar().bottom() + sz.height()) / 2));
    case Qt::TopSection:
        return QPointF(std::floor(sz.width() / 2), 0);
    case Qt::BottomSection:
        return QPointF(std::floor(sz.width() / 2), bt);
    default:
        return p;
    }
}

void Decoration::hoverEnterEvent(QHoverEvent *event)
{
    const QPointF p = motifRemap(event->position());
    if (p == event->position()) {
        KDecoration3::Decoration::hoverEnterEvent(event);
        return;
    }
    QHoverEvent e(event->type(), p, event->globalPosition(), event->oldPosF(), event->modifiers());
    KDecoration3::Decoration::hoverEnterEvent(&e);
    event->setAccepted(e.isAccepted());
}

void Decoration::hoverMoveEvent(QHoverEvent *event)
{
    const QPointF p = motifRemap(event->position());
    if (p == event->position()) {
        KDecoration3::Decoration::hoverMoveEvent(event);
        return;
    }
    QHoverEvent e(event->type(), p, event->globalPosition(), event->oldPosF(), event->modifiers());
    KDecoration3::Decoration::hoverMoveEvent(&e);
    event->setAccepted(e.isAccepted());
}

void Decoration::mouseReleaseEvent(QMouseEvent *event)
{
    // KDecoration3 recomputes the section after release (if no button was pressed)
    const QPointF p = motifRemap(event->position());
    if (p == event->position()) {
        KDecoration3::Decoration::mouseReleaseEvent(event);
        return;
    }
    QMouseEvent e(event->type(), p, event->globalPosition(), event->button(), event->buttons(), event->modifiers());
    KDecoration3::Decoration::mouseReleaseEvent(&e);
    event->setAccepted(e.isAccepted());
}

void Decoration::paint(QPainter *painter, const QRectF &repaintRegion)
{
    const QRectF full = rect();
    const qreal b = frameWidth();
    const qreal t = titleHeight();
    const qreal top = b + t;
    const qreal s = scale();
    const QColor face = faceColor(), hi = lightColor(), lo = darkColor();
    // edge widths in device pixels (at scale 1: outer 2, inner 1, buttons/notches 1)
    const int outerPx = devicePixels(OuterBevel), innerPx = devicePixels(InnerBevel), buttonPx = devicePixels(ButtonBevel);

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    painter->setClipRect(full, Qt::IntersectClip);

    // frame areas (never paint over the window content)
    painter->fillRect(QRectF(0, 0, full.width(), top), face);
    if (!window()->isShaded()) {
        painter->fillRect(QRectF(0, top, borderLeft(), full.height() - top), face);
        painter->fillRect(QRectF(full.width() - borderRight(), top, borderRight(), full.height() - top), face);
        painter->fillRect(QRectF(0, full.height() - borderBottom(), full.width(), borderBottom()), face);
    }

    if (std::round(b * s) >= outerPx + innerPx) {
        // sides without a border (at the screen edge): treat the frame as extending beyond the border;
        // the clip cuts off side edges and notches there
        const QRectF frame = full.adjusted(leftInset() - b, 0, b - rightInset(), 0);

        // outside 2 px raised (corners split diagonally), inside 1 px sunken
        bevel(painter, frame, hi, lo, outerPx, s);
        const qreal in = b - innerPx / s;
        bevel(painter, frame.adjusted(in, in, -in, -in), hi, lo, innerPx, s, true);

        // Motif corner notches at frame + title height: they continue the joints of the title bar
        // (right edge of the first left button, left edge of the last right button,
        // bottom edge of the title bar) through the frame; mirrored at the bottom.
        // The outermost pixel row stays continuous. Everything is computed in device pixels.
        auto dev = [s](qreal logical) {
            return std::round(logical * s);
        };
        const qreal X0 = dev(frame.left()), Y0 = dev(frame.top());
        const qreal W = dev(frame.right()) - X0, H = dev(frame.bottom()) - Y0;
        const qreal B = dev(b), C = dev(top); // = b + t
        const qreal skip = devicePixels(1); // continuous outermost row
        const qreal len = B - skip;
        // joint at position pos: dark before, light after (each buttonPx wide)
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

    // title field between the button groups
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

    if (type == DecorationButtonType::Menu) {
        // Option DoubleClickClose: KDecoration3 opens the window menu right on release (clicked);
        // the menu (KWin PopupInputFilter) then takes the second click and a double click never
        // arrives. So the built-in connection clicked -> requestShowWindowMenu is replaced.
        // Motif press-drag-release (choose the item on release) is not possible: KDecoration3
        // opens the menu only after release, and opening on press would not help because KWin keeps
        // the pointer with the decoration while the button is held (implicit pointer grab).
        disconnect(this, &KDecoration3::DecorationButton::clicked, decoration, nullptr);
        connect(this, &KDecoration3::DecorationButton::clicked, this, &Button::menuClicked, Qt::QueuedConnection);
        m_menuTimer = new QTimer(this);
        m_menuTimer->setSingleShot(true);
        connect(m_menuTimer, &QTimer::timeout, this, [this] {
            if (auto d = this->decoration()) {
                d->requestShowWindowMenu(geometry().toRect());
            }
        });
    }
}

void Button::menuClicked(Qt::MouseButton button)
{
    auto d = qobject_cast<Decoration *>(decoration());
    if (!d) {
        return;
    }
    // KWin's own setting (CloseOnDoubleClickOnMenu: menu only on long press) takes precedence
    const bool ours = d->config().doubleClickClose && !d->settings()->isCloseOnDoubleClickOnMenu();
    if (ours && button == Qt::LeftButton) {
        m_menuTimer->start(QGuiApplication::styleHints()->mouseDoubleClickInterval());
        return;
    }
    d->requestShowWindowMenu(geometry().toRect());
}

void Button::mousePressEvent(QMouseEvent *event)
{
    // second click within the double-click interval: close the window instead of opening the menu
    if (m_menuTimer && m_menuTimer->isActive() && event->button() == Qt::LeftButton && contains(event->position())) {
        m_menuTimer->stop();
        event->setAccepted(true);
        if (auto d = decoration()) {
            QMetaObject::invokeMethod(d, &KDecoration3::Decoration::requestClose, Qt::QueuedConnection);
        }
        return;
    }
    KDecoration3::DecorationButton::mousePressEvent(event);
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

    // lengths in whole device pixels (whole pixels at scale 1)
    auto snap = [d](qreal v) {
        return d->snap(v);
    };
    auto floorSnap = [scale](qreal v) {
        return std::floor(v * scale) / scale;
    };
    // rectangle centered in the button on the device pixel grid
    auto centered = [&](qreal w, qreal h) {
        return QRectF(g.left() + floorSnap((g.width() - w) / 2), g.top() + floorSnap((g.height() - h) / 2), w, h);
    };
    // small raised or sunken box
    auto box = [&](const QRectF &r, bool in) {
        const QRectF rr = KDecoration3::snapToPixelGrid(r, scale);
        painter->fillRect(rr, face);
        bevel(painter, rr, hi, lo, bevelPx, scale, in);
    };

    switch (type()) {
    case DecorationButtonType::Menu: {
        // Motif: flat horizontal bar
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
        // Schiefer: raised X in the frame color like the minimize and maximize boxes, drawn in
        // whole device pixels: two crossed bars filled with the face; an edge pixel is light when
        // the outside lies above or left of it, dark when below or right (sunken while pressed)
        const QRectF r = KDecoration3::snapToPixelGrid(centered(snap(s * 0.6), snap(s * 0.6)), scale);
        const QTransform dt = painter->deviceTransform();
        const QRect dr = dt.mapRect(r).toAlignedRect();
        painter->setWorldTransform(dt.inverted() * painter->worldTransform());
        const int n = dr.width();
        const int half = std::max(1, int(std::lround(s * 0.22 * scale / 2))); // bar = 2 * half + 1
        auto inside = [&](int x, int y) {
            if (x < 0 || y < 0 || x >= n || y >= n) {
                return false;
            }
            return std::abs(x - y) <= half || std::abs(x - (n - 1 - y)) <= half;
        };
        const bool in = isPressed();
        const QColor light = in ? lo : hi, dark = in ? hi : lo;
        for (int y = 0; y < n; ++y) {
            for (int x = 0; x < n; ++x) {
                if (!inside(x, y)) {
                    continue;
                }
                bool up = false, left = false, down = false, right = false;
                for (int k = 1; k <= bevelPx; ++k) {
                    up = up || !inside(x, y - k);
                    left = left || !inside(x - k, y);
                    down = down || !inside(x, y + k);
                    right = right || !inside(x + k, y);
                }
                const int score = int(up) + int(left) - int(down) - int(right);
                QColor c = face;
                if (score > 0 || (score == 0 && up)) {
                    c = light;
                } else if (score < 0 || (score == 0 && down)) {
                    c = dark;
                }
                painter->fillRect(QRect(dr.left() + x, dr.top() + y, 1, 1), c);
            }
        }
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
