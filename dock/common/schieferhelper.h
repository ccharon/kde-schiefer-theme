/*
 * Schiefer – kleine Helfer für die Dock-Widgets (Starten, Arbeitsfläche, Sitzung)
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

    // name, icon, genericName eines Starters (.desktop, applications:-URL oder Datei)
    Q_INVOKABLE QVariantMap launcherData(const QUrl &url) const;
    Q_INVOKABLE void openUrl(const QUrl &url);
    // „Programm wählen“-Dialog; Ergebnis über launcherChosen()
    Q_INVOKABLE void chooseLauncher(const QString &tag);

    Q_INVOKABLE void setCurrentDesktop(const QString &id);
    Q_INVOKABLE void lockScreen();
    // KDE-Dialog mit allen Möglichkeiten (Bereitschaft, Ruhezustand, Neustart, Herunterfahren, Abmelden)
    Q_INVOKABLE void powerPrompt();
    // Testhilfe: true, wenn die Umgebungsvariable SCHIEFER_DOCK_OPEN gleich title ist
    Q_INVOKABLE bool testOpen(const QString &title) const;
    Q_INVOKABLE QString testValue() const;

Q_SIGNALS:
    void launcherChosen(const QString &url, const QString &tag);
};
