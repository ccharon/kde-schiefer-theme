/*
 * Schiefer: colors from the active color scheme for the dock widgets
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "schieferscheme.h"

#include "schiefercolors.h"

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>

#include <Kirigami/Platform/PlatformTheme>

#include <QFile>
#include <QQuickItem>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QtQml/qqml.h>

#include <functional>

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
    // option frontpanel-color: schieferrc [Dock] FrontPanelColor
    m_dockWatcher = KConfigWatcher::create(KSharedConfig::openConfig(QStringLiteral("schieferrc"), KConfig::NoGlobals));
    connect(m_dockWatcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group, const QByteArrayList &) {
        if (group.name() == QLatin1String("Dock")) {
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

QColor SchieferScheme::hoverColor(const QColor &base) const
{
    // A third of the way from the base color to the Motif light edge: stays visibly below
    // the light edge (the relief stays readable) and looks similarly strong in light and dark palettes
    const QColor top = SchieferColors::motifColors(base).topShadow;
    const QColor b = base.toRgb();
    auto third = [](int from, int to) {
        return from + (to - from) / 3;
    };
    return QColor(third(b.red(), top.red()), third(b.green(), top.green()), third(b.blue(), top.blue()), b.alpha());
}

void SchieferScheme::tintFrames(QQuickItem *item) const
{
    if (!item || !item->window() || !item->window()->contentItem()) {
        return;
    }
    const QColor color = panelColor();
    // The panel background (shell Panel.qml) and popup background (DialogBackground) are
    // KSvg frames; they tint their ColorScheme-Background areas from their Kirigami.Theme.
    // Only the frame's own background color is set (does not affect children).
    std::function<void(QQuickItem *)> walk = [&](QQuickItem *it) {
        if (it->inherits("KSvg::FrameSvgItem")) {
            const QString path = it->property("imagePath").toString();
            if (path.endsWith(QLatin1String("widgets/panel-background")) || path.endsWith(QLatin1String("dialogs/background"))) {
                const bool tinted = it->property("_schieferTint").toBool();
                if (color.isValid() || tinted) {
                    auto *theme = qobject_cast<Kirigami::Platform::PlatformTheme *>(
                        qmlAttachedPropertiesObject<Kirigami::Platform::PlatformTheme>(it, true));
                    if (theme) {
                        theme->setCustomBackgroundColor(color);
                        it->setProperty("_schieferTint", color.isValid());
                    }
                }
            }
        }
        const auto children = it->childItems();
        for (QQuickItem *c : children) {
            walk(c);
        }
    };
    walk(item->window()->contentItem());
}

void SchieferScheme::reload()
{
    auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    globals->reparseConfiguration();
    const QString name = globals->group(QStringLiteral("General")).readEntry("ColorScheme", QString());

    // scheme file color-schemes/<name>.colors; ~/.local/share comes before /usr/share
    QString file;
    if (!name.isEmpty()) {
        file = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("color-schemes/") + name + QStringLiteral(".colors"));
    }
    KConfigGroup g;
    KConfig fileCfg(file.isEmpty() ? QStringLiteral("/nonexistent") : file, KConfig::SimpleConfig);
    if (!file.isEmpty() && fileCfg.hasGroup(QStringLiteral("Schiefer"))) {
        g = fileCfg.group(QStringLiteral("Schiefer"));
    } else {
        // fallback: [Schiefer] in kdeglobals (for example copied there by hand or by a test setup)
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

    auto rc = KSharedConfig::openConfig(QStringLiteral("schieferrc"), KConfig::NoGlobals);
    rc->reparseConfiguration();
    const bool panelEnabled = rc->group(QStringLiteral("Dock")).readEntry("FrontPanelColor", true);

    // watch the file (an atomic rewrite removes the watch, so add it again every time)
    if (!m_files.files().isEmpty()) {
        m_files.removePaths(m_files.files());
    }
    if (!file.isEmpty()) {
        m_files.addPath(file);
    }
    // kdeglobals itself too (scheme changes without a D-Bus notification, for example kwriteconfig6 without --notify)
    const QString configDir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    m_files.addPath(configDir + QStringLiteral("/kdeglobals"));
    // schieferrc edited by hand; schiefer-config notifies through m_dockWatcher, which also covers a new file
    const QString rcFile = configDir + QStringLiteral("/schieferrc");
    if (QFile::exists(rcFile)) {
        m_files.addPath(rcFile);
    }

    if (name != m_name || file != m_file || colors != m_desktopColors || panel != m_frontPanel || panelEnabled != m_panelEnabled) {
        m_panelEnabled = panelEnabled;
        m_name = name;
        m_file = file;
        m_desktopColors = colors;
        m_frontPanel = panel;
        Q_EMIT changed();
    }
}
