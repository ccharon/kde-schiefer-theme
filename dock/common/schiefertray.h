/*
 * Schiefer: bridge to the Plasma system tray (org.kde.plasma.systemtray)
 *
 * The system drawer shows the system tray entries itself. The system tray stays
 * in the same panel but hidden (HiddenStatus); its popups are reparented
 * to the drawer. Access is only through properties and Q_INVOKABLEs, without private headers.
 * UPSTREAM.md lists these Plasma internals ("Plasma internals used by the dock").
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <QAbstractItemModel>
#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QSet>
#include <QTimer>
#include <qqmlregistration.h>

#include <Plasma/Plasma>

namespace Plasma
{
class Applet;
class Containment;
}

class SchieferTray : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(TrayBridge)

    // our own applet (Plasmoid), used to find the system tray in the same panel
    Q_PROPERTY(QObject *applet READ applet WRITE setApplet NOTIFY appletChanged)
    // item at which the system tray popups should appear
    Q_PROPERTY(QQuickItem *popupAnchor READ popupAnchor WRITE setPopupAnchor NOTIFY popupAnchorChanged)
    Q_PROPERTY(bool hideTray READ hideTray WRITE setHideTray NOTIFY hideTrayChanged)
    Q_PROPERTY(bool available READ available NOTIFY trayChanged)
    Q_PROPERTY(QAbstractItemModel *model READ model NOTIFY trayChanged)
    // test helper: value of SCHIEFER_DOCK_TRAY
    Q_PROPERTY(QString testItem READ testItem CONSTANT)

public:
    explicit SchieferTray(QObject *parent = nullptr);
    ~SchieferTray() override;

    QObject *applet() const;
    void setApplet(QObject *applet);
    QQuickItem *popupAnchor() const;
    void setPopupAnchor(QQuickItem *item);
    bool hideTray() const;
    void setHideTray(bool hide);
    bool available() const;
    QAbstractItemModel *model() const;
    QString testItem() const;

    // expand or collapse a plasmoid entry (model.applet)
    Q_INVOKABLE void togglePlasmoid(QQuickItem *appletItem);
    // activate a StatusNotifierItem (model.DataEngineSource) / context menu
    Q_INVOKABLE void activateSni(const QString &service, QQuickItem *source);
    Q_INVOKABLE void sniContextMenu(const QString &service, QQuickItem *source);
    Q_INVOKABLE void sniScroll(const QString &service, int delta, bool horizontal);
    // system tray popup with all entries (Breeze view)
    Q_INVOKABLE void toggleTrayPopup();
    Q_INVOKABLE void configureTray();

Q_SIGNALS:
    void appletChanged();
    void popupAnchorChanged();
    void hideTrayChanged();
    void trayChanged();

private:
    void findTray();
    void setTray(Plasma::Applet *tray);
    void applyHidden();
    // attach the popup to m_anchor; warn: report a missing popup (on click, not on start)
    void retargetPopup(bool warn = false);
    // restore the original visualParent of the system tray popup
    void restorePopup();
    QObject *findPopup() const;
    // waits briefly if model or popup of the system tray are still missing when found
    void retryTick();
    bool checkInvoke(bool ok, const char *method);
    void warnOnce(const char *key, const QString &message);
    QPoint globalCenter(QQuickItem *item) const;

    QPointer<Plasma::Applet> m_applet;
    QPointer<Plasma::Containment> m_containment;
    QPointer<Plasma::Applet> m_tray;
    QPointer<QQuickItem> m_anchor;
    bool m_hideTray = true;
    bool m_trayHiddenByUs = false;
    Plasma::Types::ItemStatus m_trayOldStatus = Plasma::Types::PassiveStatus;

    // reparented popup and its visualParent before reparenting (the system tray item)
    QPointer<QObject> m_popup;
    QPointer<QQuickItem> m_popupOrigParent;
    QPointer<QQuickItem> m_popupSetTo;

    QTimer m_retry;
    int m_retryCount = 0;
    bool m_hadModel = false;
    QSet<QByteArray> m_warned;
};
