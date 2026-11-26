/*
 * Schiefer: small helpers for the dock widgets
 * Launcher part after the Quicklaunch applet from kdeplasma-addons (David Rosca, GPL-2.0-only OR GPL-3.0-only)
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "schieferhelper.h"

#include <KConfigGroup>
#include <KDesktopFile>
#include <KFileItem>
#include <KIO/ApplicationLauncherJob>
#include <KIO/JobUiDelegateFactory>
#include <KIO/OpenUrlJob>
#include <KLocalizedString>
#include <KNotificationJobUiDelegate>
#include <KOpenWithDialog>
#include <KService>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusVariant>
#include <QFileInfo>
#include <QMimeDatabase>

SchieferHelper::SchieferHelper(QObject *parent)
    : QObject(parent)
{
}

static QUrl resolve(const QUrl &url)
{
    // applications:org.kde.dolphin.desktop (dragged from the launcher) -> file
    if (url.scheme() == QLatin1String("applications")) {
        if (KService::Ptr s = KService::serviceByStorageId(url.path())) {
            return QUrl::fromLocalFile(s->entryPath());
        }
    }
    if (url.scheme().isEmpty() && url.path().endsWith(QLatin1String(".desktop"))) {
        if (KService::Ptr s = KService::serviceByStorageId(url.path())) {
            return QUrl::fromLocalFile(s->entryPath());
        }
    }
    return url;
}

QVariantMap SchieferHelper::launcherData(const QUrl &rawUrl) const
{
    const QUrl url = resolve(rawUrl);
    QString name, icon, genericName;

    if (url.isLocalFile() && KDesktopFile::isDesktopFile(url.toLocalFile())) {
        const KDesktopFile f(url.toLocalFile());
        name = f.readName();
        icon = f.readIcon();
        genericName = f.readGenericName();
        if (name.isEmpty()) {
            name = QFileInfo(url.toLocalFile()).completeBaseName();
        }
    } else if (url.isLocalFile()) {
        name = QFileInfo(url.toLocalFile()).fileName();
        icon = KFileItem(url).iconName();
    } else if (url.scheme() == QLatin1String("trash")) {
        name = KDesktopFile(QStringLiteral("trash.desktop")).readName();
        if (name.isEmpty() || name == QLatin1String("trash")) {
            name = i18nc("@label name of the trash in the dock", "Trash");
        }
        icon = QStringLiteral("user-trash");
    } else if (url.isValid()) {
        name = url.toDisplayString();
        icon = QMimeDatabase().mimeTypeForUrl(url).iconName();
    }
    if (icon.isEmpty()) {
        icon = QStringLiteral("application-x-executable");
    }

    return QVariantMap{{QStringLiteral("name"), name},
                       {QStringLiteral("icon"), icon},
                       {QStringLiteral("genericName"), genericName},
                       {QStringLiteral("url"), url.toString()}};
}

QString SchieferHelper::appId(const QUrl &rawUrl) const
{
    const QUrl url = resolve(rawUrl);
    if (url.isLocalFile() && KDesktopFile::isDesktopFile(url.toLocalFile())) {
        return QFileInfo(url.toLocalFile()).completeBaseName();
    }
    // applications: URL without an installed service (for example a window of an uninstalled program)
    if (url.scheme() == QLatin1String("applications")) {
        QString id = url.path();
        if (id.endsWith(QLatin1String(".desktop"))) {
            id.chop(8);
        }
        return id;
    }
    return {};
}

bool SchieferHelper::singleMainWindow(const QUrl &rawUrl) const
{
    const QUrl url = resolve(rawUrl);
    if (url.isLocalFile() && KDesktopFile::isDesktopFile(url.toLocalFile())) {
        return KDesktopFile(url.toLocalFile()).desktopGroup().readEntry("SingleMainWindow", false);
    }
    return false;
}

void SchieferHelper::openUrl(const QUrl &url)
{
    auto *job = new KIO::OpenUrlJob(resolve(url));
    job->setUiDelegate(new KNotificationJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled));
    job->setRunExecutables(true);
    job->start();
}

void SchieferHelper::openFile(const QUrl &url)
{
    // Start launchers (Type=Application) like the Plasma folder view does: ApplicationLauncherJob checks
    // isAuthorizedDesktopFile() and asks for foreign files without the executable bit.
    // Type=Link and everything else goes to OpenUrlJob without setRunExecutables, so a link to a
    // program or an executable script is only opened, never run.
    if (url.isLocalFile() && KDesktopFile::isDesktopFile(url.toLocalFile())) {
        const KDesktopFile f(url.toLocalFile());
        if (f.hasApplicationType()) {
            KService::Ptr service(new KService(url.toLocalFile()));
            if (service->isValid() && !service->exec().isEmpty()) {
                auto *job = new KIO::ApplicationLauncherJob(service);
                job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
                job->start();
                return;
            }
        }
    }
    auto *job = new KIO::OpenUrlJob(url);
    job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
    job->setRunExecutables(false);
    job->start();
}

void SchieferHelper::chooseLauncher(const QString &tag)
{
    auto *dialog = new KOpenWithDialog();
    dialog->setModal(false);
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->hideRunInTerminal();
    dialog->setSaveNewApplications(true);
    dialog->show();
    connect(dialog, &KOpenWithDialog::accepted, this, [this, dialog, tag]() {
        if (dialog->service()) {
            Q_EMIT launcherChosen(QUrl::fromLocalFile(dialog->service()->entryPath()).toString(), tag);
        }
    });
}

void SchieferHelper::setCurrentDesktop(const QString &id)
{
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                              QStringLiteral("/VirtualDesktopManager"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"),
                                              QStringLiteral("Set"));
    msg << QStringLiteral("org.kde.KWin.VirtualDesktopManager") << QStringLiteral("current")
        << QVariant::fromValue(QDBusVariant(id));
    QDBusConnection::sessionBus().asyncCall(msg);
}

void SchieferHelper::lockScreen()
{
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"),
                                              QStringLiteral("/ScreenSaver"),
                                              QStringLiteral("org.freedesktop.ScreenSaver"),
                                              QStringLiteral("Lock"));
    QDBusConnection::sessionBus().asyncCall(msg);
}

void SchieferHelper::powerPrompt()
{
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.LogoutPrompt"),
                                              QStringLiteral("/LogoutPrompt"),
                                              QStringLiteral("org.kde.LogoutPrompt"),
                                              QStringLiteral("promptAll"));
    QDBusConnection::sessionBus().asyncCall(msg);
}

bool SchieferHelper::testOpen(const QString &title) const
{
    return !title.isEmpty() && qEnvironmentVariable("SCHIEFER_DOCK_OPEN") == title;
}

QString SchieferHelper::testValue() const
{
    return qEnvironmentVariable("SCHIEFER_DOCK_OPEN");
}
