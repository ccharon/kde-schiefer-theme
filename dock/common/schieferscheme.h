/*
 * Schiefer: colors from the active color scheme for the dock widgets
 *  - motifColors(): edge colors from the Motif formula (common/schiefercolors.h)
 *  - desktopColors / frontPanel: group [Schiefer] of the scheme file (color-schemes/<name>.colors);
 *    KDE does not copy this group to kdeglobals, so the file itself is read.
 *    Updates when the scheme in kdeglobals changes (KConfigWatcher) or the file changes.
 *  - usePanelColor / panelColor: option `frontpanel-color` (schieferrc [Dock] FrontPanelColor,
 *    default on). Applies only if the scheme has a FrontPanel color; otherwise the
 *    window color stays (Kirigami.Theme.backgroundColor).
 *  - tabRaise / ledge: schieferrc [Dock] TabRaise (pixels the drawer tabs grow upward, default 3)
 *    and Ledge (ledge at the bottom of the front panel, default on).
 *  - activeTitle / activeTitleText: title bar colors of the active window (kdeglobals [WM]
 *    activeBackground/activeForeground), for the drawer title and the focus frame like dtwm;
 *    invalid if the scheme has none.
 *  - hoverColor(): hover tint from the Motif formula, a third of the way to the light edge.
 *  - tintFrames(): tints the Plasma frames (panel background, popup background) in the window
 *    of an item with the front panel color, or resets them.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <KConfigWatcher>
#include <QColor>
#include <QFileSystemWatcher>
#include <QObject>
#include <QQuickItem>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>
#include <qqmlregistration.h>

class SchieferScheme : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Scheme)
    QML_SINGLETON

    Q_PROPERTY(QString schemeName READ schemeName NOTIFY changed)
    // empty if the scheme has no [Schiefer] group
    Q_PROPERTY(QStringList desktopColors READ desktopColors NOTIFY changed)
    Q_PROPERTY(QColor frontPanel READ frontPanel NOTIFY changed)
    Q_PROPERTY(bool hasFrontPanel READ hasFrontPanel NOTIFY changed)
    // option frontpanel-color on and the scheme has FrontPanel
    Q_PROPERTY(bool usePanelColor READ usePanelColor NOTIFY changed)
    // front panel color if usePanelColor, otherwise invalid
    Q_PROPERTY(QColor panelColor READ panelColor NOTIFY changed)
    Q_PROPERTY(int tabRaise READ tabRaise NOTIFY changed)
    Q_PROPERTY(bool ledge READ ledge NOTIFY changed)
    Q_PROPERTY(QColor activeTitle READ activeTitle NOTIFY changed)
    Q_PROPERTY(QColor activeTitleText READ activeTitleText NOTIFY changed)

public:
    explicit SchieferScheme(QObject *parent = nullptr);

    QString schemeName() const { return m_name; }
    QStringList desktopColors() const { return m_desktopColors; }
    QColor frontPanel() const { return m_frontPanel; }
    bool hasFrontPanel() const { return m_frontPanel.isValid(); }
    bool usePanelColor() const { return m_panelEnabled && m_frontPanel.isValid(); }
    QColor panelColor() const { return usePanelColor() ? m_frontPanel : QColor(); }
    int tabRaise() const { return m_tabRaise; }
    bool ledge() const { return m_ledge; }
    QColor activeTitle() const { return m_activeTitle; }
    QColor activeTitleText() const { return m_activeTitleText; }

    // {top, bottom, select, foreground} for the base color, Motif formula
    Q_INVOKABLE QVariantMap motifColors(const QColor &base) const;
    // hover tint for the base color: a third of the way to the Motif light edge (light and dark)
    Q_INVOKABLE QColor hoverColor(const QColor &base) const;
    // tint the Plasma frames (widgets/panel-background, dialogs/background) in the window of item
    // (usePanelColor) or reset them
    Q_INVOKABLE void tintFrames(QQuickItem *item) const;

Q_SIGNALS:
    void changed();

private:
    void reload();
    void scheduleReload();

    KConfigWatcher::Ptr m_watcher;
    QFileSystemWatcher m_files;
    QTimer m_timer;
    QString m_name;
    QString m_file;
    QStringList m_desktopColors;
    QColor m_frontPanel;
    bool m_panelEnabled = true;
    int m_tabRaise = 3;
    bool m_ledge = true;
    QColor m_activeTitle;
    QColor m_activeTitleText;
    KConfigWatcher::Ptr m_dockWatcher;
};
