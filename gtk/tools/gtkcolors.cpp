// gtkcolors: prints the colors.css that kde-gtk-config would generate from kdeglobals in $XDG_CONFIG_HOME.
// colors() is copied unchanged from kde-gtk-config 6.7.6 (configvalueprovider.cpp)
// (GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL).
#include <QGuiApplication>
#include <QColor>
#include <QMap>
#include <KColorScheme>
#include <KColorUtils>
#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>
#include <cstdio>

static KSharedConfigPtr kdeglobalsConfig;

static QMap<QString, QColor> colors()
{
    using KCS = KColorScheme;

    const qreal bias = KColorScheme::frameContrast();

    // Color Schemes Collection
    QHash<QString, QHash<QString, KCS>> csc{
        {QStringLiteral("active"),
         {
             {QStringLiteral("view"), KCS(QPalette::Active, KCS::View)},
             {QStringLiteral("window"), KCS(QPalette::Active, KCS::Window)},
             {QStringLiteral("button"), KCS(QPalette::Active, KCS::Button)},
             {QStringLiteral("selection"), KCS(QPalette::Active, KCS::Selection)},
             {QStringLiteral("tooltip"), KCS(QPalette::Active, KCS::Tooltip)},
             {QStringLiteral("complementary"), KCS(QPalette::Active, KCS::Complementary)},
             {QStringLiteral("header"), KCS(QPalette::Active, KCS::Header)},
         }},
        {QStringLiteral("inactive"),
         {
             {QStringLiteral("view"), KCS(QPalette::Inactive, KCS::View)},
             {QStringLiteral("window"), KCS(QPalette::Inactive, KCS::Window)},
             {QStringLiteral("button"), KCS(QPalette::Inactive, KCS::Button)},
             {QStringLiteral("selection"), KCS(QPalette::Inactive, KCS::Selection)},
             {QStringLiteral("tooltip"), KCS(QPalette::Inactive, KCS::Tooltip)},
             {QStringLiteral("complementary"), KCS(QPalette::Inactive, KCS::Complementary)},
             {QStringLiteral("header"), KCS(QPalette::Inactive, KCS::Header)},
         }},
        {QStringLiteral("disabled"),
         {
             {QStringLiteral("view"), KCS(QPalette::Disabled, KCS::View)},
             {QStringLiteral("window"), KCS(QPalette::Disabled, KCS::Window)},
             {QStringLiteral("button"), KCS(QPalette::Disabled, KCS::Button)},
             {QStringLiteral("selection"), KCS(QPalette::Disabled, KCS::Selection)},
             {QStringLiteral("tooltip"), KCS(QPalette::Disabled, KCS::Tooltip)},
             {QStringLiteral("complementary"), KCS(QPalette::Disabled, KCS::Complementary)},
             {QStringLiteral("header"), KCS(QPalette::Disabled, KCS::Header)},
         }},
    };

    // Color mixing
    QColor windowForegroundColor = csc["active"]["window"].foreground(KCS::NormalText).color();
    QColor windowBackgroundColor = csc["active"]["window"].background(KCS::NormalBackground).color();
    QColor bordersColor = KColorUtils::mix(windowBackgroundColor, windowForegroundColor, bias);

    QColor inactiveWindowForegroundColor = csc["inactive"]["window"].foreground(KCS::NormalText).color();
    QColor inactiveWindowBackgroundColor = csc["inactive"]["window"].background(KCS::NormalBackground).color();
    QColor inactiveBordersColor = KColorUtils::mix(inactiveWindowBackgroundColor, inactiveWindowForegroundColor, bias);

    QColor disabledWindowForegroundColor = csc["disabled"]["window"].foreground(KCS::NormalText).color();
    QColor disabledWindowBackgroundColor = csc["disabled"]["window"].background(KCS::NormalBackground).color();
    QColor disabledBordersColor = KColorUtils::mix(disabledWindowBackgroundColor, disabledWindowForegroundColor, bias);

    QColor unfocusedDisabledWindowForegroundColor = csc["disabled"]["window"].foreground(KCS::NormalText).color();
    QColor unfocusedDisabledWindowBackgroundColor = csc["disabled"]["window"].background(KCS::NormalBackground).color();
    QColor unfocusedDisabledBordersColor = KColorUtils::mix(unfocusedDisabledWindowBackgroundColor, unfocusedDisabledWindowForegroundColor, bias);

    QColor tooltipForegroundColor = csc["active"]["tooltip"].foreground(KCS::NormalText).color();
    QColor tooltipBackgroundColor = csc["active"]["tooltip"].background(KCS::NormalBackground).color();
    QColor tooltipBorderColor = KColorUtils::mix(tooltipBackgroundColor, tooltipForegroundColor, bias);

    KConfigGroup windowManagerConfig = kdeglobalsConfig->group(QStringLiteral("WM"));

    QMap<QString, QColor> result = {
        /*
         * Normal (Non Backdrop, Non Insensitive)
         */

        // General Colors
        {"theme_fg_color_breeze", csc["active"]["window"].foreground(KCS::NormalText).color()},
        {"theme_bg_color_breeze", csc["active"]["window"].background(KCS::NormalBackground).color()},
        {"theme_text_color_breeze", csc["active"]["view"].foreground(KCS::NormalText).color()},
        {"theme_base_color_breeze", csc["active"]["view"].background(KCS::NormalBackground).color()},
        {"theme_view_hover_decoration_color_breeze", csc["active"]["view"].decoration(KCS::HoverColor).color()},
        {"theme_hovering_selected_bg_color_breeze", csc["active"]["selection"].decoration(KCS::HoverColor).color()},
        {"theme_selected_bg_color_breeze", csc["active"]["selection"].background(KCS::NormalBackground).color()},
        {"theme_selected_fg_color_breeze", csc["active"]["selection"].foreground(KCS::NormalText).color()},
        {"theme_view_active_decoration_color_breeze", csc["active"]["view"].decoration(KCS::HoverColor).color()},

        // Button Colors
        {"theme_button_background_normal_breeze", csc["active"]["button"].background(KCS::NormalBackground).color()},
        {"theme_button_decoration_hover_breeze", csc["active"]["button"].decoration(KCS::HoverColor).color()},
        {"theme_button_decoration_focus_breeze", csc["active"]["button"].decoration(KCS::FocusColor).color()},
        {"theme_button_foreground_normal_breeze", csc["active"]["button"].foreground(KCS::NormalText).color()},
        {"theme_button_foreground_active_breeze", csc["active"]["selection"].foreground(KCS::NormalText).color()},

        // Misc Colors
        {"borders_breeze", bordersColor},
        {"warning_color_breeze", csc["active"]["view"].foreground(KCS::NeutralText).color()},
        {"success_color_breeze", csc["active"]["view"].foreground(KCS::PositiveText).color()},
        {"error_color_breeze", csc["active"]["view"].foreground(KCS::NegativeText).color()},

        /*
         * Backdrop (Inactive)
         */

        // General
        {"theme_unfocused_fg_color_breeze", csc["inactive"]["window"].foreground(KCS::NormalText).color()},
        {"theme_unfocused_text_color_breeze", csc["inactive"]["view"].foreground(KCS::NormalText).color()},
        {"theme_unfocused_bg_color_breeze", csc["inactive"]["window"].background(KCS::NormalBackground).color()},
        {"theme_unfocused_base_color_breeze", csc["inactive"]["view"].background(KCS::NormalBackground).color()},
        {"theme_unfocused_selected_bg_color_alt_breeze", csc["inactive"]["selection"].background(KCS::NormalBackground).color()},
        {"theme_unfocused_selected_bg_color_breeze", csc["inactive"]["selection"].background(KCS::NormalBackground).color()},
        {"theme_unfocused_selected_fg_color_breeze", csc["inactive"]["selection"].foreground(KCS::NormalText).color()},

        // Button
        {"theme_button_background_backdrop_breeze", csc["inactive"]["button"].background(KCS::NormalBackground).color()},
        {"theme_button_decoration_hover_backdrop_breeze", csc["inactive"]["button"].decoration(KCS::HoverColor).color()},
        {"theme_button_decoration_focus_backdrop_breeze", csc["inactive"]["button"].decoration(KCS::FocusColor).color()},
        {"theme_button_foreground_backdrop_breeze", csc["inactive"]["button"].foreground(KCS::NormalText).color()},
        {"theme_button_foreground_active_backdrop_breeze", csc["inactive"]["selection"].foreground(KCS::NormalText).color()},

        // Misc Colors
        {"unfocused_borders_breeze", inactiveBordersColor},
        {"warning_color_backdrop_breeze", csc["inactive"]["view"].foreground(KCS::NeutralText).color()},
        {"success_color_backdrop_breeze", csc["inactive"]["view"].foreground(KCS::PositiveText).color()},
        {"error_color_backdrop_breeze", csc["inactive"]["view"].foreground(KCS::NegativeText).color()},

        /*
         * Insensitive (Disabled)
         */

        // General
        {"insensitive_fg_color_breeze", csc["disabled"]["window"].foreground(KCS::NormalText).color()},
        {"insensitive_base_fg_color_breeze", csc["disabled"]["view"].foreground(KCS::NormalText).color()},
        {"insensitive_bg_color_breeze", csc["disabled"]["window"].background(KCS::NormalBackground).color()},
        {"insensitive_base_color_breeze", csc["disabled"]["view"].background(KCS::NormalBackground).color()},
        {"insensitive_selected_bg_color_breeze", csc["disabled"]["selection"].background(KCS::NormalBackground).color()},
        {"insensitive_selected_fg_color_breeze", csc["disabled"]["selection"].foreground(KCS::NormalText).color()},

        // Button
        {"theme_button_background_insensitive_breeze", csc["disabled"]["button"].background(KCS::NormalBackground).color()},
        {"theme_button_decoration_hover_insensitive_breeze", csc["disabled"]["button"].decoration(KCS::HoverColor).color()},
        {"theme_button_decoration_focus_insensitive_breeze", csc["disabled"]["button"].decoration(KCS::FocusColor).color()},
        {"theme_button_foreground_insensitive_breeze", csc["disabled"]["button"].foreground(KCS::NormalText).color()},
        {"theme_button_foreground_active_insensitive_breeze", csc["disabled"]["selection"].foreground(KCS::NormalText).color()},

        // Misc Colors
        {"insensitive_borders_breeze", disabledBordersColor},
        {"warning_color_insensitive_breeze", csc["disabled"]["view"].foreground(KCS::NeutralText).color()},
        {"success_color_insensitive_breeze", csc["disabled"]["view"].foreground(KCS::PositiveText).color()},
        {"error_color_insensitive_breeze", csc["disabled"]["view"].foreground(KCS::NegativeText).color()},

        /*
         * Insensitive Backdrop (Inactive Disabled)
         * These pretty much have the same appearance as regular inactive colors,
         * but they're separate in case we decide to make them different in the future.
         */

        // General
        {"insensitive_unfocused_fg_color_breeze", csc["disabled"]["window"].foreground(KCS::NormalText).color()},
        {"theme_unfocused_view_text_color_breeze", csc["disabled"]["view"].foreground(KCS::NormalText).color()},
        {"insensitive_unfocused_bg_color_breeze", csc["disabled"]["window"].background(KCS::NormalBackground).color()},
        {"theme_unfocused_view_bg_color_breeze", csc["disabled"]["view"].background(KCS::NormalBackground).color()},
        {"insensitive_unfocused_selected_bg_color_breeze", csc["disabled"]["selection"].background(KCS::NormalBackground).color()},
        {"insensitive_unfocused_selected_fg_color_breeze", csc["disabled"]["selection"].foreground(KCS::NormalText).color()},

        // Button
        {"theme_button_background_backdrop_insensitive_breeze", csc["disabled"]["button"].background(KCS::NormalBackground).color()},
        {"theme_button_decoration_hover_backdrop_insensitive_breeze", csc["disabled"]["button"].decoration(KCS::HoverColor).color()},
        {"theme_button_decoration_focus_backdrop_insensitive_breeze", csc["disabled"]["button"].decoration(KCS::FocusColor).color()},
        {"theme_button_foreground_backdrop_insensitive_breeze", csc["disabled"]["button"].foreground(KCS::NormalText).color()},
        {"theme_button_foreground_active_backdrop_insensitive_breeze", csc["disabled"]["selection"].foreground(KCS::NormalText).color()},

        // Misc Colors
        {"unfocused_insensitive_borders_breeze", unfocusedDisabledBordersColor},
        {"warning_color_insensitive_backdrop_breeze", csc["disabled"]["view"].foreground(KCS::NeutralText).color()},
        {"success_color_insensitive_backdrop_breeze", csc["disabled"]["view"].foreground(KCS::PositiveText).color()},
        {"error_color_insensitive_backdrop_breeze", csc["disabled"]["view"].foreground(KCS::NegativeText).color()},

        /*
         * Ignorant Colors (These colors do not care about backdrop or insensitive states)
         */

        {"link_color_breeze", csc["active"]["view"].foreground(KCS::LinkText).color()},
        {"link_visited_color_breeze", csc["active"]["view"].foreground(KCS::VisitedText).color()},

        {"tooltip_text_breeze", tooltipForegroundColor},
        {"tooltip_background_breeze", tooltipBackgroundColor},
        {"tooltip_border_breeze", tooltipBorderColor},

        {"content_view_bg_breeze", csc["active"]["view"].background(KCS::NormalBackground).color()},

    };
    // Handle Headers (menu bars and some of toolbars)
    if (KCS::isColorSetSupported(kdeglobalsConfig, KCS::Header)) {
        // If we have a separate Header color set, use it for both titlebar and header coloring...
        result.insert({{"theme_header_background_breeze", csc["active"]["header"].background().color()},
                       {"theme_header_foreground_breeze", csc["active"]["header"].foreground().color()},
                       {"theme_header_background_light_breeze", csc["active"]["window"].background().color()},
                       {"theme_header_foreground_backdrop_breeze", csc["inactive"]["header"].foreground().color()},
                       {"theme_header_background_backdrop_breeze", csc["inactive"]["header"].background().color()},
                       {"theme_header_foreground_insensitive_breeze", csc["inactive"]["header"].foreground().color()},
                       {"theme_header_foreground_insensitive_backdrop_breeze", csc["inactive"]["header"].foreground().color()},

                       {"theme_titlebar_background_breeze", csc["active"]["header"].background().color()},
                       {"theme_titlebar_foreground_breeze", csc["active"]["header"].foreground().color()},
                       {"theme_titlebar_background_light_breeze", csc["active"]["window"].background().color()},
                       {"theme_titlebar_foreground_backdrop_breeze", csc["inactive"]["header"].foreground().color()},
                       {"theme_titlebar_background_backdrop_breeze", csc["inactive"]["header"].background().color()},
                       {"theme_titlebar_foreground_insensitive_breeze", csc["inactive"]["header"].foreground().color()},
                       {"theme_titlebar_foreground_insensitive_backdrop_breeze", csc["inactive"]["header"].foreground().color()}});
    } else {
        //... if we don't we'll use regular window colors for headerbar and WM group for a titlebar
        result.insert({
            {"theme_header_background_breeze", csc["active"]["window"].background().color()},
            {"theme_header_foreground_breeze", csc["active"]["window"].foreground().color()},
            {"theme_header_background_light_breeze", csc["active"]["window"].background().color()},
            {"theme_header_foreground_backdrop_breeze", csc["inactive"]["window"].foreground().color()},
            {"theme_header_background_backdrop_breeze", csc["inactive"]["window"].background().color()},
            {"theme_header_foreground_insensitive_breeze", csc["inactive"]["window"].foreground().color()},
            {"theme_header_foreground_insensitive_backdrop_breeze", csc["inactive"]["window"].foreground().color()},

            {"theme_titlebar_background_breeze", windowManagerConfig.readEntry("activeBackground", QColor())},
            {"theme_titlebar_foreground_breeze", windowManagerConfig.readEntry("activeForeground", QColor())},
            {"theme_titlebar_background_light_breeze", csc["active"]["window"].background(KCS::NormalBackground).color()},
            {"theme_titlebar_foreground_backdrop_breeze", windowManagerConfig.readEntry("inactiveForeground", QColor())},
            {"theme_titlebar_background_backdrop_breeze", windowManagerConfig.readEntry("inactiveBackground", QColor())},
            {"theme_titlebar_foreground_insensitive_breeze", windowManagerConfig.readEntry("inactiveForeground", QColor())},
            {"theme_titlebar_foreground_insensitive_backdrop_breeze", windowManagerConfig.readEntry("inactiveForeground", QColor())},
        });
    }

    return result;
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    // read kdeglobals from $XDG_CONFIG_HOME (as KColorScheme does)
    kdeglobalsConfig = KSharedConfig::openConfig();
    const auto c = colors();
    for (auto it = c.cbegin(); it != c.cend(); ++it)
        printf("@define-color %s %s;\n", qPrintable(it.key()), qPrintable(it.value().name()));
    return 0;
}
