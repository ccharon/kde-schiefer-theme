/*
 * Schiefer: window decoration in Motif/CDE style.
 * Structure follows the Breeze decoration (KDE, GPL-2.0-only OR GPL-3.0-only).
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
 */
#pragma once

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>

#include <QColor>
#include <QVariantList>

#include <memory>

class KPluginMetaData;
class QTimer;
class QWidget;

namespace Schiefer
{

// Title bar colors from [WM] in kdeglobals, shared by all decorations:
// kdeglobals is reread once per change, not by every window.
class ColorCache : public QObject
{
    Q_OBJECT
public:
    static std::shared_ptr<ColorCache> instance();
    ColorCache();

    // invalid if the entry is missing (then the window palette is used)
    QColor activeBg, activeFg, inactiveBg, inactiveFg;

Q_SIGNALS:
    void changed();

private Q_SLOTS:
    void notifyChange(int type, int arg);

private:
    void read();
};

// Options from ~/.config/schieferrc, group [Decoration], shared by all decorations.
// Reread on DecorationSettings::reconfigured (qdbus6 org.kde.KWin /KWin reconfigure).
class DecorationConfig : public QObject
{
    Q_OBJECT
public:
    static std::shared_ptr<DecorationConfig> instance();
    DecorationConfig();

    // connect once per settings object (KWin shares it between all decorations)
    void watch(const std::shared_ptr<KDecoration3::DecorationSettings> &settings);

    bool doubleClickClose = true; // double click on the window menu button closes (mwm/dtwm)
    bool motifCorners = true; // corner grips reach up to the notches (frame + title height)

public Q_SLOTS:
    void read();

private:
    std::weak_ptr<KDecoration3::DecorationSettings> m_settings;
};

class Decoration : public KDecoration3::Decoration
{
    Q_OBJECT
public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());

    void paint(QPainter *painter, const QRectF &repaintRegion) override;

    // colors of the current state (active/inactive)
    QColor faceColor() const;
    QColor lightColor() const;
    QColor darkColor() const;
    QColor fontColor() const;

    qreal frameWidth() const;   // frame width (0 when maximized)
    qreal titleHeight() const   // title row height = button size
    {
        return m_titleHeight;
    }

    // scale and edge widths in whole device pixels (logical values rounded to the grid)
    qreal scale() const;
    int devicePixels(qreal logical) const; // at least 1
    qreal snap(qreal logical) const;

    const DecorationConfig &config() const
    {
        return *m_config;
    }

    // Motif corner grips: wanted frame section at p (NoSection = let KDecoration3 decide)
    Qt::WindowFrameSection motifSection(const QPointF &p) const;

protected:
    // Motif corner grips: move the position so KDecoration3 picks the wanted section
    void hoverEnterEvent(QHoverEvent *event) override;
    void hoverMoveEvent(QHoverEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;

public Q_SLOTS:
    bool init() override;

private Q_SLOTS:
    void reconfigure();
    void recalculateBorders();
    void updateLayout();

private:
    void readColors();
    // from the title font and the scale; cached because hit testing needs it on every pointer move
    void updateTitleHeight();
    bool isMaximized() const;
    // left/right inset of the title row: 0 if that side has no border at the screen edge
    qreal leftInset() const;
    qreal rightInset() const;

    KDecoration3::DecorationButtonGroup *m_leftButtons = nullptr;
    KDecoration3::DecorationButtonGroup *m_rightButtons = nullptr;

    // proxy point that KDecoration3 reliably classifies as section (otherwise p unchanged)
    QPointF motifRemap(const QPointF &p) const;

    std::shared_ptr<ColorCache> m_colors;
    std::shared_ptr<DecorationConfig> m_config;
    QColor m_activeBg, m_activeFg, m_inactiveBg, m_inactiveFg;
    qreal m_titleHeight = 0;
};

class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT
public:
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);
    // for the plugin factory (preview in System Settings): args = {button type, decoration};
    // nullptr instead of a crash for missing or wrong arguments
    static QObject *createFromArgs(QWidget *parentWidget, QObject *parent, const KPluginMetaData &metaData, const QVariantList &args);

    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);

    void paint(QPainter *painter, const QRectF &repaintRegion) override;

protected:
    void mousePressEvent(QMouseEvent *event) override;

private:
    // window menu button: menu only after the double-click interval, so a second click can close
    void menuClicked(Qt::MouseButton button);
    QTimer *m_menuTimer = nullptr;
};

} // namespace Schiefer
