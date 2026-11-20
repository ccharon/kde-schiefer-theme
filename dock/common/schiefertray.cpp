/*
 * Schiefer – Brücke zum Plasma-Systemabschnitt
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "schiefertray.h"

#include <Plasma/Applet>
#include <Plasma/Containment>
#include <PlasmaQuick/AppletQuickItem>

#include <QAction>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QWindow>

static const QString trayPluginId = QStringLiteral("org.kde.plasma.systemtray");

SchieferTray::SchieferTray(QObject *parent)
    : QObject(parent)
{
}

SchieferTray::~SchieferTray()
{
    // Systray wieder zeigen, wenn die Schublade verschwindet (Widget entfernt)
    if (m_tray) {
        disconnect(m_tray, nullptr, this, nullptr);
        if (m_trayHiddenByUs) {
            m_tray->setStatus(m_trayOldStatus);
        }
    }
}

QObject *SchieferTray::applet() const
{
    return m_applet;
}

void SchieferTray::setApplet(QObject *applet)
{
    auto *a = qobject_cast<Plasma::Applet *>(applet);
    if (a == m_applet) {
        return;
    }
    if (m_containment) {
        disconnect(m_containment, nullptr, this, nullptr);
    }
    m_applet = a;
    m_containment = a ? a->containment() : nullptr;
    setTray(nullptr);
    if (m_containment) {
        connect(m_containment, &Plasma::Containment::appletAdded, this, &SchieferTray::findTray);
        connect(m_containment, &Plasma::Containment::appletRemoved, this, [this](Plasma::Applet *removed) {
            if (removed == m_tray) {
                setTray(nullptr);
            }
            findTray();
        });
    }
    Q_EMIT appletChanged();
    findTray();
}

QQuickItem *SchieferTray::popupAnchor() const
{
    return m_anchor;
}

void SchieferTray::setPopupAnchor(QQuickItem *item)
{
    if (item == m_anchor) {
        return;
    }
    m_anchor = item;
    Q_EMIT popupAnchorChanged();
    retargetPopup();
}

bool SchieferTray::hideTray() const
{
    return m_hideTray;
}

void SchieferTray::setHideTray(bool hide)
{
    if (hide == m_hideTray) {
        return;
    }
    m_hideTray = hide;
    Q_EMIT hideTrayChanged();
    applyHidden();
}

bool SchieferTray::available() const
{
    return m_tray && model();
}

QAbstractItemModel *SchieferTray::model() const
{
    if (!m_tray) {
        return nullptr;
    }
    return m_tray->property("systemTrayModel").value<QAbstractItemModel *>();
}

QString SchieferTray::testItem() const
{
    return qEnvironmentVariable("SCHIEFER_DOCK_TRAY");
}

void SchieferTray::findTray()
{
    if (m_tray || !m_containment) {
        return;
    }
    const auto applets = m_containment->applets();
    for (Plasma::Applet *a : applets) {
        if (a->pluginMetaData().pluginId() == trayPluginId) {
            setTray(a);
            return;
        }
    }
}

void SchieferTray::setTray(Plasma::Applet *tray)
{
    if (tray == m_tray) {
        return;
    }
    if (m_tray) {
        disconnect(m_tray, nullptr, this, nullptr);
        if (m_trayHiddenByUs) {
            m_tray->setStatus(m_trayOldStatus);
        }
    }
    m_tray = tray;
    m_trayHiddenByUs = false;
    if (m_tray) {
        // der Systray setzt beim Auf-/Zuklappen selbst RequiresAttention bzw. Passive
        connect(m_tray, &Plasma::Applet::statusChanged, this, [this](Plasma::Types::ItemStatus status) {
            if (m_hideTray && status != Plasma::Types::HiddenStatus) {
                m_trayOldStatus = Plasma::Types::PassiveStatus;
                m_tray->setStatus(Plasma::Types::HiddenStatus);
                m_trayHiddenByUs = true;
            }
        });
    }
    applyHidden();
    Q_EMIT trayChanged();
    // das Popup entsteht erst mit der QML-Oberfläche des Systrays
    if (m_tray) {
        QMetaObject::invokeMethod(this, &SchieferTray::retargetPopup, Qt::QueuedConnection);
    }
}

void SchieferTray::applyHidden()
{
    if (!m_tray) {
        return;
    }
    if (m_hideTray && m_tray->status() != Plasma::Types::HiddenStatus) {
        m_trayOldStatus = m_tray->status();
        m_tray->setStatus(Plasma::Types::HiddenStatus);
        m_trayHiddenByUs = true;
    } else if (!m_hideTray && m_trayHiddenByUs) {
        m_tray->setStatus(m_trayOldStatus);
        m_trayHiddenByUs = false;
    }
}

void SchieferTray::retargetPopup()
{
    if (!m_tray || !m_anchor) {
        return;
    }
    auto *trayItem = PlasmaQuick::AppletQuickItem::itemForApplet(m_tray);
    if (!trayItem) {
        return;
    }
    // Hauptpopup des Systrays (objectName "popupWindow", visualParent = Systray-Item)
    QObject *popup = trayItem->findChild<QObject *>(QStringLiteral("popupWindow"));
    if (!popup) {
        const auto windows = QGuiApplication::allWindows();
        for (QWindow *w : windows) {
            if (w->objectName() == QLatin1String("popupWindow") && w->property("visualParent").value<QQuickItem *>() == trayItem) {
                popup = w;
                break;
            }
        }
    }
    if (popup && popup->property("visualParent").value<QQuickItem *>() != m_anchor.data()) {
        popup->setProperty("visualParent", QVariant::fromValue<QQuickItem *>(m_anchor));
    }
}

QPoint SchieferTray::globalCenter(QQuickItem *item) const
{
    if (!item || !item->window()) {
        return {};
    }
    return item->mapToGlobal(QPointF(item->width() / 2, item->height() / 2)).toPoint();
}

void SchieferTray::togglePlasmoid(QQuickItem *appletItem)
{
    if (!appletItem) {
        return;
    }
    retargetPopup();
    appletItem->setProperty("expanded", !appletItem->property("expanded").toBool());
}

void SchieferTray::activateSni(const QString &service, QQuickItem *source)
{
    if (!m_tray) {
        return;
    }
    QMetaObject::invokeMethod(m_tray, "activate", Q_ARG(QString, service), Q_ARG(QPoint, globalCenter(source)), Q_ARG(QQuickItem *, source));
}

void SchieferTray::sniContextMenu(const QString &service, QQuickItem *source)
{
    if (!m_tray) {
        return;
    }
    QMetaObject::invokeMethod(m_tray, "openContextMenu", Q_ARG(QString, service), Q_ARG(QPoint, globalCenter(source)), Q_ARG(QQuickItem *, source));
}

void SchieferTray::sniScroll(const QString &service, int delta, bool horizontal)
{
    if (!m_tray) {
        return;
    }
    QMetaObject::invokeMethod(m_tray,
                              "scroll",
                              Q_ARG(QString, service),
                              Q_ARG(int, delta),
                              Q_ARG(QString, horizontal ? QStringLiteral("Horizontal") : QStringLiteral("Vertical")));
}

void SchieferTray::toggleTrayPopup()
{
    if (!m_tray) {
        return;
    }
    retargetPopup();
    // der Systray schaltet bei activated() sein Popup um
    Q_EMIT m_tray->activated();
}

void SchieferTray::configureTray()
{
    if (!m_tray) {
        return;
    }
    if (QAction *a = m_tray->internalAction(QStringLiteral("configure"))) {
        a->trigger();
    }
}
