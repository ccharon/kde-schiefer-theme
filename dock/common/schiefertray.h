/*
 * Schiefer – Brücke zum Plasma-Systemabschnitt (org.kde.plasma.systemtray)
 *
 * Die System-Schublade zeigt die Einträge des Systrays selbst an. Der Systray bleibt
 * dafür im selben Panel, wird aber ausgeblendet (HiddenStatus); seine Popups hängen
 * wir an die Schublade um. Zugriff nur über Properties/Q_INVOKABLEs, ohne private Header.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <QAbstractItemModel>
#include <QObject>
#include <QPointer>
#include <QQuickItem>
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

    // das eigene Applet (Plasmoid), darüber finden wir den Systray im selben Panel
    Q_PROPERTY(QObject *applet READ applet WRITE setApplet NOTIFY appletChanged)
    // Item, an dem die Systray-Popups erscheinen sollen
    Q_PROPERTY(QQuickItem *popupAnchor READ popupAnchor WRITE setPopupAnchor NOTIFY popupAnchorChanged)
    Q_PROPERTY(bool hideTray READ hideTray WRITE setHideTray NOTIFY hideTrayChanged)
    Q_PROPERTY(bool available READ available NOTIFY trayChanged)
    Q_PROPERTY(QAbstractItemModel *model READ model NOTIFY trayChanged)
    // Testhilfe: Inhalt von SCHIEFER_DOCK_TRAY
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

    // Plasmoid-Eintrag (model.applet) auf- bzw. zuklappen
    Q_INVOKABLE void togglePlasmoid(QQuickItem *appletItem);
    // StatusNotifierItem (model.DataEngineSource) aktivieren / Kontextmenü
    Q_INVOKABLE void activateSni(const QString &service, QQuickItem *source);
    Q_INVOKABLE void sniContextMenu(const QString &service, QQuickItem *source);
    Q_INVOKABLE void sniScroll(const QString &service, int delta, bool horizontal);
    // Popup des Systrays mit allen Einträgen (Breeze-Ansicht)
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
    void retargetPopup();
    QPoint globalCenter(QQuickItem *item) const;

    QPointer<Plasma::Applet> m_applet;
    QPointer<Plasma::Containment> m_containment;
    QPointer<Plasma::Applet> m_tray;
    QPointer<QQuickItem> m_anchor;
    bool m_hideTray = true;
    bool m_trayHiddenByUs = false;
    Plasma::Types::ItemStatus m_trayOldStatus = Plasma::Types::PassiveStatus;
};
