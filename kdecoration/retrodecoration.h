/*
 * Schiefer – Fensterdekoration im Motif/CDE-Stil.
 * Struktur angelehnt an die Breeze-Dekoration (KDE, GPL-2.0-only OR GPL-3.0-only).
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
 */
#pragma once

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>

#include <QColor>
#include <QVariantList>

#include <memory>

class KPluginMetaData;
class QTimer;
class QWidget;

namespace Schiefer
{

// Titelleistenfarben aus [WM] in kdeglobals, von allen Dekorationen geteilt:
// kdeglobals wird pro Änderung nur einmal neu gelesen, nicht von jedem Fenster.
class ColorCache : public QObject
{
    Q_OBJECT
public:
    static std::shared_ptr<ColorCache> instance();
    ColorCache();

    // ungültig, wenn der Eintrag fehlt (dann Rückfall auf die Fensterpalette)
    QColor activeBg, activeFg, inactiveBg, inactiveFg;

Q_SIGNALS:
    void changed();

private Q_SLOTS:
    void notifyChange(int type, int arg);

private:
    void read();
};

// Schalter aus ~/.config/schieferrc, Gruppe [Decoration], von allen Dekorationen geteilt.
// Neu gelesen bei DecorationSettings::reconfigured (qdbus6 org.kde.KWin /KWin reconfigure).
class DecorationConfig : public QObject
{
    Q_OBJECT
public:
    static std::shared_ptr<DecorationConfig> instance();
    DecorationConfig();

    // einmal je Einstellungsobjekt verbinden (KWin teilt es zwischen allen Dekorationen)
    void watch(const std::shared_ptr<KDecoration3::DecorationSettings> &settings);

    bool doubleClickClose = true; // Doppelklick auf den Fenstermenü-Knopf schließt (mwm/dtwm)
    bool motifCorners = true; // Eckgriffe reichen bis zu den Kerben (Rahmen + Titelhöhe)

public Q_SLOTS:
    void read();

private:
    std::weak_ptr<KDecoration3::DecorationSettings> m_settings;
};

class Decoration : public KDecoration3::Decoration
{
    Q_OBJECT
public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());

    void paint(QPainter *painter, const QRectF &repaintRegion) override;

    // Farben des aktuellen Zustands (aktiv/inaktiv)
    QColor faceColor() const;
    QColor lightColor() const;
    QColor darkColor() const;
    QColor fontColor() const;

    qreal frameWidth() const;   // Rahmenbreite (0 bei maximiert)
    qreal titleHeight() const;  // Höhe der Titelzeile = Knopfgröße

    // Skalierung und Kantenstärken in ganzen Gerätepixeln (logische Werte auf das Raster gerundet)
    qreal scale() const;
    int devicePixels(qreal logical) const; // mindestens 1
    qreal snap(qreal logical) const;

    const DecorationConfig &config() const
    {
        return *m_config;
    }

    // Motif-Eckgriffe: gewünschter Rahmenabschnitt an p (NoSection = KDecoration3 entscheiden lassen)
    Qt::WindowFrameSection motifSection(const QPointF &p) const;

protected:
    // Motif-Eckgriffe: Position so umsetzen, dass KDecoration3 den gewünschten Abschnitt wählt
    void hoverEnterEvent(QHoverEvent *event) override;
    void hoverMoveEvent(QHoverEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;

public Q_SLOTS:
    bool init() override;

private Q_SLOTS:
    void reconfigure();
    void recalculateBorders();
    void updateLayout();

private:
    void readColors();
    bool isMaximized() const;
    // linker/rechter Abstand der Titelzeile: 0, wenn die Seite am Bildschirmrand keinen Rand hat
    qreal leftInset() const;
    qreal rightInset() const;

    KDecoration3::DecorationButtonGroup *m_leftButtons = nullptr;
    KDecoration3::DecorationButtonGroup *m_rightButtons = nullptr;

    // Stellvertreterpunkt, den KDecoration3 sicher als section einordnet (sonst p unverändert)
    QPointF motifRemap(const QPointF &p) const;

    std::shared_ptr<ColorCache> m_colors;
    std::shared_ptr<DecorationConfig> m_config;
    QColor m_activeBg, m_activeFg, m_inactiveBg, m_inactiveFg;
};

class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT
public:
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);
    // für die Plugin-Factory (Vorschau in den Systemeinstellungen): args = {Knopftyp, Dekoration};
    // bei fehlenden/falschen Argumenten nullptr statt Absturz
    static QObject *createFromArgs(QWidget *parentWidget, QObject *parent, const KPluginMetaData &metaData, const QVariantList &args);

    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);

    void paint(QPainter *painter, const QRectF &repaintRegion) override;

protected:
    void mousePressEvent(QMouseEvent *event) override;

private:
    // Fenstermenü-Knopf: Menü erst nach Ablauf der Doppelklickzeit, damit ein zweiter Klick schließen kann
    void menuClicked(Qt::MouseButton button);
    QTimer *m_menuTimer = nullptr;
};

} // namespace Schiefer
