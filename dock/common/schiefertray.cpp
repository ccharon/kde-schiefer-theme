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
#include <QLoggingCategory>
#include <QQuickWindow>
#include <QWindow>

Q_LOGGING_CATEGORY(lcSchieferDock, "schiefer.dock", QtInfoMsg)

static const QString trayPluginId = QStringLiteral("org.kde.plasma.systemtray");
static const QString popupObjectName = QStringLiteral("popupWindow");

// Modell oder Popup fehlen beim Fund des Systrays noch: so oft im Abstand nachsehen
static constexpr int retryInterval = 500;
static constexpr int retryMax = 20;

SchieferTray::SchieferTray(QObject *parent)
    : QObject(parent)
{
    m_retry.setInterval(retryInterval);
    connect(&m_retry, &QTimer::timeout, this, &SchieferTray::retryTick);
}

SchieferTray::~SchieferTray()
{
    m_retry.stop();
    // Systray wieder zeigen und sein Popup zurückgeben, wenn die Schublade verschwindet (Widget entfernt)
    restorePopup();
    if (m_tray) {
        disconnect(m_tray, nullptr, this, nullptr);
        if (m_trayHiddenByUs) {
            m_tray->setStatus(m_trayOldStatus);
        }
    }
}

void SchieferTray::warnOnce(const char *key, const QString &message)
{
    if (m_warned.contains(key)) {
        return;
    }
    m_warned.insert(key);
    qCWarning(lcSchieferDock).noquote() << "Systray-Brücke:" << message
                                        << "– hat sich org.kde.plasma.systemtray geändert? Siehe UPSTREAM.md, „Plasma-Interna des Docks“.";
}

bool SchieferTray::checkInvoke(bool ok, const char *method)
{
    if (!ok) {
        warnOnce(method,
                 QStringLiteral("QMetaObject::invokeMethod(\"%1\") am Systray ist fehlgeschlagen (Methode fehlt oder Signatur anders)")
                     .arg(QLatin1String(method)));
    }
    return ok;
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
    if (m_anchor) {
        disconnect(m_anchor, &QObject::destroyed, this, nullptr);
    }
    m_anchor = item;
    if (m_anchor) {
        // verschwindet der Anker (Kachel/Schublade entfernt), bekommt der Systray sein Popup zurück
        connect(m_anchor, &QObject::destroyed, this, [this]() {
            restorePopup();
        });
    }
    Q_EMIT popupAnchorChanged();
    if (m_anchor) {
        retargetPopup();
    } else {
        restorePopup();
    }
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
    // SystemTray: Q_PROPERTY(QAbstractItemModel *systemTrayModel READ sortedSystemTrayModel CONSTANT)
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
    m_retry.stop();
    restorePopup();
    if (m_tray) {
        disconnect(m_tray, nullptr, this, nullptr);
        if (m_trayHiddenByUs) {
            m_tray->setStatus(m_trayOldStatus);
        }
    }
    m_tray = tray;
    m_trayHiddenByUs = false;
    m_hadModel = model() != nullptr;
    if (m_tray) {
        // der Systray setzt beim Auf-/Zuklappen selbst RequiresAttention bzw. Passive
        connect(m_tray, &Plasma::Applet::statusChanged, this, [this](Plasma::Types::ItemStatus status) {
            if (m_hideTray && status != Plasma::Types::HiddenStatus) {
                m_trayOldStatus = Plasma::Types::PassiveStatus;
                m_tray->setStatus(Plasma::Types::HiddenStatus);
                m_trayHiddenByUs = true;
            }
        });
        // falls er vor uns verschwindet: Zeiger sind QPointer, aber available/model ändern sich
        connect(m_tray, &QObject::destroyed, this, [this]() {
            m_retry.stop();
            m_hadModel = false;
            Q_EMIT trayChanged();
        });
    }
    applyHidden();
    Q_EMIT trayChanged();
    // Das Modell legt der Systray beim ersten Lesen an (vorhanden, sobald init() lief); das Popup
    // entsteht erst mit seiner QML-Oberfläche. Fehlt eins davon noch, kurz danach erneut nachsehen.
    if (m_tray) {
        m_retryCount = 0;
        QMetaObject::invokeMethod(this, &SchieferTray::retryTick, Qt::QueuedConnection);
    }
}

void SchieferTray::retryTick()
{
    if (!m_tray) {
        m_retry.stop();
        return;
    }
    if (!m_hadModel && model()) {
        m_hadModel = true;
        Q_EMIT trayChanged();
    }
    retargetPopup();
    const bool popupOk = !m_anchor || m_popup;
    if (m_hadModel && popupOk) {
        m_retry.stop();
        return;
    }
    if (++m_retryCount >= retryMax) {
        m_retry.stop();
        if (!m_hadModel) {
            warnOnce("systemTrayModel",
                     QStringLiteral("der Systray hat keine Property „systemTrayModel“ (QAbstractItemModel*); die Einträge bleiben leer"));
        }
        if (!popupOk) {
            warnOnce("popupWindow",
                     QStringLiteral("Popup des Systrays (objectName „popupWindow“ mit Property „visualParent“) nicht gefunden; es öffnet am Systray"));
        }
        return;
    }
    if (!m_retry.isActive()) {
        m_retry.start();
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

static bool hasVisualParent(QObject *o)
{
    return o && o->metaObject()->indexOfProperty("visualParent") >= 0;
}

QObject *SchieferTray::findPopup() const
{
    if (!m_tray) {
        return nullptr;
    }
    auto *trayItem = PlasmaQuick::AppletQuickItem::itemForApplet(m_tray);
    if (!trayItem) {
        return nullptr;
    }
    // Hauptpopup des Systrays: PlasmaCore.AppletPopup { objectName: "popupWindow"; visualParent: root }
    QObject *popup = trayItem->findChild<QObject *>(popupObjectName);
    if (hasVisualParent(popup)) {
        return popup;
    }
    // Fenster hängen nicht immer als QObject-Kind am Item: über die Fensterliste suchen
    const auto windows = QGuiApplication::allWindows();
    for (QWindow *w : windows) {
        if (w->objectName() != popupObjectName || !hasVisualParent(w)) {
            continue;
        }
        auto *vp = w->property("visualParent").value<QQuickItem *>();
        if (vp == trayItem) {
            return w;
        }
    }
    return nullptr;
}

void SchieferTray::retargetPopup(bool warn)
{
    if (!m_tray || !m_anchor) {
        return;
    }
    QObject *popup = m_popup ? m_popup.data() : findPopup();
    if (!popup) {
        if (warn && PlasmaQuick::AppletQuickItem::itemForApplet(m_tray)) {
            warnOnce("popupWindow",
                     QStringLiteral("Popup des Systrays (objectName „popupWindow“ mit Property „visualParent“) nicht gefunden; es öffnet am Systray"));
        }
        return;
    }
    if (popup != m_popup.data()) {
        restorePopup();
        m_popup = popup;
        m_popupOrigParent = popup->property("visualParent").value<QQuickItem *>();
    }
    if (popup->property("visualParent").value<QQuickItem *>() != m_anchor.data()) {
        popup->setProperty("visualParent", QVariant::fromValue<QQuickItem *>(m_anchor));
        qCDebug(lcSchieferDock) << "Systray-Popup an" << m_anchor.data();
    }
    m_popupSetTo = m_anchor;
}

void SchieferTray::restorePopup()
{
    if (m_popup) {
        QQuickItem *orig = m_popupOrigParent.data();
        if (!orig && m_tray) {
            orig = PlasmaQuick::AppletQuickItem::itemForApplet(m_tray);
        }
        // nur zurückstellen, wenn niemand sonst es inzwischen umgehängt hat
        // (ein zerstörter Anker steht im Popup als nullptr, es hält ihn per QPointer)
        const auto current = m_popup->property("visualParent").value<QQuickItem *>();
        if (current != orig && (current == m_popupSetTo.data() || !current)) {
            m_popup->setProperty("visualParent", QVariant::fromValue<QQuickItem *>(orig));
            qCDebug(lcSchieferDock) << "Systray-Popup zurück an" << orig;
        }
    }
    m_popup = nullptr;
    m_popupOrigParent = nullptr;
    m_popupSetTo = nullptr;
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
    retargetPopup(true);
    // PlasmaQuick::AppletQuickItem: Q_PROPERTY(bool expanded …)
    if (!appletItem->setProperty("expanded", !appletItem->property("expanded").toBool())) {
        warnOnce("expanded", QStringLiteral("Property „expanded“ am Applet-Item (model.applet) lässt sich nicht setzen"));
    }
}

void SchieferTray::activateSni(const QString &service, QQuickItem *source)
{
    if (!m_tray) {
        return;
    }
    checkInvoke(QMetaObject::invokeMethod(m_tray,
                                          "activate",
                                          Q_ARG(QString, service),
                                          Q_ARG(QPoint, globalCenter(source)),
                                          Q_ARG(QQuickItem *, source)),
                "activate");
}

void SchieferTray::sniContextMenu(const QString &service, QQuickItem *source)
{
    if (!m_tray) {
        return;
    }
    checkInvoke(QMetaObject::invokeMethod(m_tray,
                                          "openContextMenu",
                                          Q_ARG(QString, service),
                                          Q_ARG(QPoint, globalCenter(source)),
                                          Q_ARG(QQuickItem *, source)),
                "openContextMenu");
}

void SchieferTray::sniScroll(const QString &service, int delta, bool horizontal)
{
    if (!m_tray) {
        return;
    }
    checkInvoke(QMetaObject::invokeMethod(m_tray,
                                          "scroll",
                                          Q_ARG(QString, service),
                                          Q_ARG(int, delta),
                                          Q_ARG(QString, horizontal ? QStringLiteral("Horizontal") : QStringLiteral("Vertical"))),
                "scroll");
}

void SchieferTray::toggleTrayPopup()
{
    if (!m_tray) {
        return;
    }
    retargetPopup(true);
    // der Systray schaltet bei activated() sein Popup um (main.qml: Connections { target: Plasmoid; onActivated })
    Q_EMIT m_tray->activated();
}

void SchieferTray::configureTray()
{
    if (!m_tray) {
        return;
    }
    if (QAction *a = m_tray->internalAction(QStringLiteral("configure"))) {
        a->trigger();
    } else {
        warnOnce("configure", QStringLiteral("der Systray hat keine internalAction(\"configure\")"));
    }
}
