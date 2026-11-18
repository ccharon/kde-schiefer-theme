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

namespace Schiefer
{

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

public Q_SLOTS:
    bool init() override;

private Q_SLOTS:
    void reconfigure();
    void recalculateBorders();
    void updateLayout();

private:
    void readColors();
    bool isMaximized() const;

    KDecoration3::DecorationButtonGroup *m_leftButtons = nullptr;
    KDecoration3::DecorationButtonGroup *m_rightButtons = nullptr;

    QColor m_activeBg, m_activeFg, m_inactiveBg, m_inactiveFg;
};

class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT
public:
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);
    // für die Plugin-Factory (Vorschau in den Systemeinstellungen)
    Button(QObject *parent, const QVariantList &args);

    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);

    void paint(QPainter *painter, const QRectF &repaintRegion) override;
};

} // namespace Schiefer
