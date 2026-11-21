/*
 * Schiefer – Farben aus dem aktiven Farbschema für die Dock-Widgets
 *  - motifColors(): Kantenfarben nach der Motif-Formel (common/schiefercolors.h)
 *  - desktopColors / frontPanel: Gruppe [Schiefer] der Schemadatei (color-schemes/<Name>.colors);
 *    KDE kopiert diese Gruppe nicht nach kdeglobals, deshalb wird die Datei selbst gelesen.
 *    Aktualisiert sich, wenn sich das Schema in kdeglobals ändert (KConfigWatcher) oder die Datei.
 *  - usePanelColor / panelColor: Schalter `frontpanel-farbe` (schieferrc [Dock] FrontPanelColor,
 *    Vorgabe an). Gilt nur, wenn das Schema eine FrontPanel-Farbe hat; sonst bleibt es bei der
 *    Fensterfarbe (Kirigami.Theme.backgroundColor).
 *  - hoverColor(): Hover-Tönung aus der Motif-Formel, ein Drittel des Wegs zur Lichtkante.
 *  - tintFrames(): färbt die Plasma-Rahmen (Leistenhintergrund, Popup-Hintergrund) im Fenster
 *    eines Items in der Frontpanel-Farbe bzw. setzt sie zurück.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <KConfigWatcher>
#include <QColor>
#include <QFileSystemWatcher>
#include <QObject>
#include <QQuickItem>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>
#include <qqmlregistration.h>

class SchieferScheme : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Scheme)
    QML_SINGLETON

    Q_PROPERTY(QString schemeName READ schemeName NOTIFY changed)
    // leer, wenn das Schema keine [Schiefer]-Gruppe hat
    Q_PROPERTY(QStringList desktopColors READ desktopColors NOTIFY changed)
    Q_PROPERTY(QColor frontPanel READ frontPanel NOTIFY changed)
    Q_PROPERTY(bool hasFrontPanel READ hasFrontPanel NOTIFY changed)
    // Schalter frontpanel-farbe an und Schema hat FrontPanel
    Q_PROPERTY(bool usePanelColor READ usePanelColor NOTIFY changed)
    // Frontpanel-Farbe, wenn usePanelColor, sonst ungültig
    Q_PROPERTY(QColor panelColor READ panelColor NOTIFY changed)

public:
    explicit SchieferScheme(QObject *parent = nullptr);

    QString schemeName() const { return m_name; }
    QStringList desktopColors() const { return m_desktopColors; }
    QColor frontPanel() const { return m_frontPanel; }
    bool hasFrontPanel() const { return m_frontPanel.isValid(); }
    bool usePanelColor() const { return m_panelEnabled && m_frontPanel.isValid(); }
    QColor panelColor() const { return usePanelColor() ? m_frontPanel : QColor(); }

    // {top, bottom, select, foreground} zur Grundfarbe, Motif-Formel
    Q_INVOKABLE QVariantMap motifColors(const QColor &base) const;
    // Hover-Tönung zur Grundfarbe: ein Drittel des Wegs zur Motif-Lichtkante (hell wie dunkel)
    Q_INVOKABLE QColor hoverColor(const QColor &base) const;
    // Plasma-Rahmen (widgets/panel-background, dialogs/background) im Fenster von item färben
    // (usePanelColor) bzw. zurücksetzen
    Q_INVOKABLE void tintFrames(QQuickItem *item) const;

Q_SIGNALS:
    void changed();

private:
    void reload();
    void scheduleReload();

    KConfigWatcher::Ptr m_watcher;
    QFileSystemWatcher m_files;
    QTimer m_timer;
    QString m_name;
    QString m_file;
    QStringList m_desktopColors;
    QColor m_frontPanel;
    bool m_panelEnabled = true;
    KConfigWatcher::Ptr m_dockWatcher;
};
