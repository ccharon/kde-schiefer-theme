/*
 * Schiefer – Farben aus dem aktiven Farbschema für die Dock-Widgets
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "schieferscheme.h"

#include "schiefercolors.h"

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>

#include <QFile>
#include <QStandardPaths>

SchieferScheme::SchieferScheme(QObject *parent)
    : QObject(parent)
{
    m_timer.setSingleShot(true);
    m_timer.setInterval(150);
    connect(&m_timer, &QTimer::timeout, this, &SchieferScheme::reload);
    connect(&m_files, &QFileSystemWatcher::fileChanged, this, &SchieferScheme::scheduleReload);

    auto cfg = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    m_watcher = KConfigWatcher::create(cfg);
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group, const QByteArrayList &) {
        const QString n = group.name();
        if (n == QLatin1String("General") || n == QLatin1String("Schiefer")) {
            scheduleReload();
        }
    });
    reload();
}

void SchieferScheme::scheduleReload()
{
    m_timer.start();
}

QVariantMap SchieferScheme::motifColors(const QColor &base) const
{
    const auto m = SchieferColors::motifColors(base);
    return QVariantMap{{QStringLiteral("top"), m.topShadow},
                       {QStringLiteral("bottom"), m.bottomShadow},
                       {QStringLiteral("select"), m.select},
                       {QStringLiteral("foreground"), m.foreground}};
}

void SchieferScheme::reload()
{
    auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    globals->reparseConfiguration();
    const QString name = globals->group(QStringLiteral("General")).readEntry("ColorScheme", QString());

    // Schemadatei: color-schemes/<Name>.colors, ~/.local/share vor /usr/share
    QString file;
    if (!name.isEmpty()) {
        file = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("color-schemes/") + name + QStringLiteral(".colors"));
    }
    KConfigGroup g;
    KConfig fileCfg(file.isEmpty() ? QStringLiteral("/nonexistent") : file, KConfig::SimpleConfig);
    if (!file.isEmpty() && fileCfg.hasGroup(QStringLiteral("Schiefer"))) {
        g = fileCfg.group(QStringLiteral("Schiefer"));
    } else {
        // Ersatz: [Schiefer] in kdeglobals (z. B. von Hand oder Testumgebung hineinkopiert)
        g = globals->group(QStringLiteral("Schiefer"));
    }

    QStringList colors;
    const auto parts = g.readEntry("DesktopColors", QString()).split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (const QString &p : parts) {
        const QColor c(p.trimmed());
        if (c.isValid()) {
            colors << c.name();
        }
    }
    QColor panel(g.readEntry("FrontPanel", QString()).trimmed());

    // Datei beobachten (atomares Neuschreiben entfernt den Eintrag, deshalb jedes Mal neu setzen)
    if (!m_files.files().isEmpty()) {
        m_files.removePaths(m_files.files());
    }
    if (!file.isEmpty()) {
        m_files.addPath(file);
    }
    // auch kdeglobals selbst (Schemawechsel ohne D-Bus-Meldung, z. B. kwriteconfig6 ohne --notify)
    m_files.addPath(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kdeglobals"));

    if (name != m_name || file != m_file || colors != m_desktopColors || panel != m_frontPanel) {
        m_name = name;
        m_file = file;
        m_desktopColors = colors;
        m_frontPanel = panel;
        Q_EMIT changed();
    }
}
