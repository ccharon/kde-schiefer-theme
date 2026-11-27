/*
 * SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
 *
 * SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
 */
#include "mocksettings.h"
#include "kdecoration3/decorationsettings.h"

MockSettings::MockSettings(KDecoration3::DecorationSettings *parent)
    : DecorationSettingsPrivateV2(parent)
{
}

KDecoration3::BorderSize MockSettings::borderSize() const
{
    return KDecoration3::BorderSize::Normal;
}

QList<KDecoration3::DecorationButtonType> MockSettings::decorationButtonsLeft() const
{
    return {KDecoration3::DecorationButtonType::Menu}; // Schiefer test: window menu on the left
}

QList<KDecoration3::DecorationButtonType> MockSettings::decorationButtonsRight() const
{
    using T = KDecoration3::DecorationButtonType;
    // SCHIEFER_DECO_ALLBUTTONS: every button type, for the paintShot picture
    if (qEnvironmentVariableIsSet("SCHIEFER_DECO_ALLBUTTONS")) {
        return {T::OnAllDesktops, T::KeepAbove, T::KeepBelow, T::ContextHelp, T::ApplicationMenu, T::ExcludeFromCapture,
                T::Shade, T::Minimize, T::Maximize, T::Close};
    }
    // Schiefer test: as in the Schiefer layout (minimize, maximize, close)
    return {T::Minimize, T::Maximize, T::Close};
}

bool MockSettings::isAlphaChannelSupported() const
{
    return true;
}

bool MockSettings::isCloseOnDoubleClickOnMenu() const
{
    return m_closeDoubleClickOnMenu;
}

bool MockSettings::isOnAllDesktopsAvailable() const
{
    return m_onAllDesktopsAvailable;
}

bool MockSettings::isAlwaysShowExcludeFromCapture() const
{
    return m_alwaysShowExcludeFromCapture;
}

void MockSettings::setOnAllDesktopsAvailabe(bool set)
{
    if (m_onAllDesktopsAvailable == set) {
        return;
    }
    m_onAllDesktopsAvailable = set;
    Q_EMIT decorationSettings()->onAllDesktopsAvailableChanged(m_onAllDesktopsAvailable);
}

void MockSettings::setCloseOnDoubleClickOnMenu(bool set)
{
    if (m_closeDoubleClickOnMenu == set) {
        return;
    }
    m_closeDoubleClickOnMenu = set;
    Q_EMIT decorationSettings()->closeOnDoubleClickOnMenuChanged(m_closeDoubleClickOnMenu);
}

void MockSettings::setAlwaysShowExcludeFromCapture(bool set)
{
    if (m_alwaysShowExcludeFromCapture == set) {
        return;
    }
    m_alwaysShowExcludeFromCapture = set;
    Q_EMIT decorationSettings()->alwaysShowExcludeFromCaptureChanged(m_alwaysShowExcludeFromCapture);
}
