/*
 * Schiefer: small helpers for the dock widgets (launching, desktops, session)
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <qqmlregistration.h>

class SchieferHelper : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Helper)

public:
    explicit SchieferHelper(QObject *parent = nullptr);

    // name, icon, genericName of a launcher (.desktop, applications: URL or file)
    Q_INVOKABLE QVariantMap launcherData(const QUrl &url) const;
    // open a launcher: also runs programs and scripts (like a click in the launcher menu)
    Q_INVOKABLE void openUrl(const QUrl &url);
    // open an entry of the folder drawer: files only with their application, never execute;
    // .desktop launchers go through the KIO trust check (executable bit or standard location)
    Q_INVOKABLE void openFile(const QUrl &url);
    // "choose application" dialog; result through launcherChosen()
    Q_INVOKABLE void chooseLauncher(const QString &tag);

    Q_INVOKABLE void setCurrentDesktop(const QString &id);
    Q_INVOKABLE void lockScreen();
    // KDE dialog with all choices (sleep, hibernate, restart, shut down, log out)
    Q_INVOKABLE void powerPrompt();
    // test helper: true if the environment variable SCHIEFER_DOCK_OPEN equals title
    Q_INVOKABLE bool testOpen(const QString &title) const;
    Q_INVOKABLE QString testValue() const;

Q_SIGNALS:
    void launcherChosen(const QString &url, const QString &tag);
};
