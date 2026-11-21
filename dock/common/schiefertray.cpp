/*
 * Schiefer: bridge to the Plasma system tray
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

// model or popup may be missing when the system tray is found: retry this often at this interval
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
    // show the system tray again and return its popup when the drawer goes away (widget removed)
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
    qCWarning(lcSchieferDock).noquote() << "system tray bridge:" << message
                                        << "- did org.kde.plasma.systemtray change? See UPSTREAM.md, \"Plasma internals used by the dock\".";
}

bool SchieferTray::checkInvoke(bool ok, const char *method)
{
    if (!ok) {
        warnOnce(method,
                 QStringLiteral("QMetaObject::invokeMethod(\"%1\") on the system tray failed (method missing or signature changed)")
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
        // if the anchor goes away (tile or drawer removed), the system tray gets its popup back
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
        // the system tray sets RequiresAttention or Passive itself when expanding or collapsing
        connect(m_tray, &Plasma::Applet::statusChanged, this, [this](Plasma::Types::ItemStatus status) {
            if (m_hideTray && status != Plasma::Types::HiddenStatus) {
                m_trayOldStatus = Plasma::Types::PassiveStatus;
                m_tray->setStatus(Plasma::Types::HiddenStatus);
                m_trayHiddenByUs = true;
            }
        });
        // in case it goes away before us: the pointers are QPointer, but available/model change
        connect(m_tray, &QObject::destroyed, this, [this]() {
            m_retry.stop();
            m_hadModel = false;
            Q_EMIT trayChanged();
        });
    }
    applyHidden();
    Q_EMIT trayChanged();
    // The system tray creates the model on first read (present once init() ran); the popup
    // appears only with its QML UI. If either is still missing, look again shortly after.
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
                     QStringLiteral("the system tray has no property \"systemTrayModel\" (QAbstractItemModel*); the entries stay empty"));
        }
        if (!popupOk) {
            warnOnce("popupWindow",
                     QStringLiteral("system tray popup (objectName \"popupWindow\" with property \"visualParent\") not found; it opens at the system tray"));
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
    // windows are not always QObject children of the item: search the window list
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
                     QStringLiteral("system tray popup (objectName \"popupWindow\" with property \"visualParent\") not found; it opens at the system tray"));
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
        // only restore if nobody else has reparented it in the meantime
        // (a destroyed anchor shows up as nullptr in the popup, which holds it in a QPointer)
        const auto current = m_popup->property("visualParent").value<QQuickItem *>();
        if (current != orig && (current == m_popupSetTo.data() || !current)) {
            m_popup->setProperty("visualParent", QVariant::fromValue<QQuickItem *>(orig));
            qCDebug(lcSchieferDock) << "system tray popup returned to" << orig;
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
        warnOnce("expanded", QStringLiteral("property \"expanded\" on the applet item (model.applet) cannot be set"));
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
    // the system tray toggles its popup on activated() (main.qml: Connections { target: Plasmoid; onActivated })
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
        warnOnce("configure", QStringLiteral("the system tray has no internalAction(\"configure\")"));
    }
}
