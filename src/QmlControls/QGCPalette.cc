/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/// @file
///     @author Don Gagne <don@thegagnes.com>

#include "QGCPalette.h"
#include "QGCCorePlugin.h"

#include <QtCore/QDebug>

QList<QGCPalette*>   QGCPalette::_paletteObjects;

QGCPalette::Theme QGCPalette::_theme = QGCPalette::Dark;

QMap<int, QMap<int, QMap<QString, QColor>>> QGCPalette::_colorInfoMap;

QStringList QGCPalette::_colors;

QGCPalette::QGCPalette(QObject* parent) :
    QObject(parent),
    _colorGroupEnabled(true)
{
    if (_colorInfoMap.isEmpty()) {
        _buildMap();
    }

    // We have to keep track of all QGCPalette objects in the system so we can signal theme change to all of them
    _paletteObjects += this;
}

QGCPalette::~QGCPalette()
{
    bool fSuccess = _paletteObjects.removeOne(this);
    if (!fSuccess) {
        qWarning() << "Internal error";
    }
}

void QGCPalette::_buildMap()
{
    //                                      Light                 Dark
    //                                      Disabled   Enabled    Disabled   Enabled
    // ── HILM Dark Theme: #0D1117 base, #00BFFF teal accent ──
    DECLARE_QGC_COLOR(window,               "#ffffff", "#ffffff", "#0D1117", "#0D1117")
    DECLARE_QGC_COLOR(windowTransparent,    "#ccffffff", "#ccffffff", "#cc0D1117", "#cc0D1117")
    DECLARE_QGC_COLOR(windowShadeLight,     "#909090", "#828282", "#2A3040", "#1E2530")
    DECLARE_QGC_COLOR(windowShade,          "#d9d9d9", "#d9d9d9", "#161B22", "#161B22")
    DECLARE_QGC_COLOR(windowShadeDark,      "#bdbdbd", "#bdbdbd", "#090D12", "#090D12")
    DECLARE_QGC_COLOR(text,                 "#9d9d9d", "#333333", "#506070", "#E0E8F0")
    DECLARE_QGC_COLOR(windowTransparentText,"#9d9d9d", "#000000", "#506070", "#E0E8F0")
    DECLARE_QGC_COLOR(warningText,          "#cc0808", "#cc0808", "#FF5252", "#FF5252")
    DECLARE_QGC_COLOR(button,               "#ffffff", "#ffffff", "#1A2332", "#1A2332")
    DECLARE_QGC_COLOR(buttonBorder,         "#9d9d9d", "#3A9BDC", "#1E3A4A", "#00BFFF50")
    DECLARE_QGC_COLOR(buttonText,           "#9d9d9d", "#333333", "#607080", "#C0D0E0")
    DECLARE_QGC_COLOR(buttonHighlight,      "#e4e4e4", "#3A9BDC", "#0A2030", "#00BFFF")
    DECLARE_QGC_COLOR(buttonHighlightText,  "#2c2c2c", "#ffffff", "#2c2c2c", "#000000")
    DECLARE_QGC_COLOR(primaryButton,        "#585858", "#8cb3be", "#0A3040", "#00BFFF")
    DECLARE_QGC_COLOR(primaryButtonText,    "#2c2c2c", "#333333", "#90B0C0", "#000000")
    DECLARE_QGC_COLOR(textField,            "#ffffff", "#ffffff", "#1A2332", "#131A24")
    DECLARE_QGC_COLOR(textFieldText,        "#808080", "#333333", "#607080", "#E0E8F0")
    DECLARE_QGC_COLOR(mapButton,            "#585858", "#333333", "#0D1117", "#000000")
    DECLARE_QGC_COLOR(mapButtonHighlight,   "#585858", "#be781c", "#0D1117", "#00BFFF")
    DECLARE_QGC_COLOR(mapIndicator,         "#585858", "#be781c", "#0D1117", "#00BFFF")
    DECLARE_QGC_COLOR(mapIndicatorChild,    "#585858", "#766043", "#0D1117", "#0080AA")
    DECLARE_QGC_COLOR(colorGreen,           "#008f2d", "#008f2d", "#4CAF50", "#4CAF50")
    DECLARE_QGC_COLOR(colorYellow,          "#a2a200", "#a2a200", "#FFD600", "#FFD600")
    DECLARE_QGC_COLOR(colorYellowGreen,     "#799f26", "#799f26", "#9dbe2f", "#9dbe2f")
    DECLARE_QGC_COLOR(colorOrange,          "#bf7539", "#bf7539", "#FF9800", "#FF9800")
    DECLARE_QGC_COLOR(colorRed,             "#b52b2b", "#b52b2b", "#FF5252", "#FF5252")
    DECLARE_QGC_COLOR(colorGrey,            "#808080", "#808080", "#8090A0", "#8090A0")
    DECLARE_QGC_COLOR(colorBlue,            "#1a72ff", "#1a72ff", "#00BFFF", "#00BFFF")
    DECLARE_QGC_COLOR(alertBackground,      "#eecc44", "#eecc44", "#1A2332", "#1A2332")
    DECLARE_QGC_COLOR(alertBorder,          "#808080", "#808080", "#FF9800", "#FF9800")
    DECLARE_QGC_COLOR(alertText,            "#000000", "#000000", "#FFD600", "#FFD600")
    DECLARE_QGC_COLOR(missionItemEditor,    "#585858", "#dbfef8", "#0D1820", "#0D1820")
    DECLARE_QGC_COLOR(toolStripHoverColor,  "#585858", "#9D9D9D", "#0A2030", "#0A2030")
    DECLARE_QGC_COLOR(statusFailedText,     "#9d9d9d", "#000000", "#506070", "#FF5252")
    DECLARE_QGC_COLOR(statusPassedText,     "#9d9d9d", "#000000", "#506070", "#4CAF50")
    DECLARE_QGC_COLOR(statusPendingText,    "#9d9d9d", "#000000", "#506070", "#FF9800")
    DECLARE_QGC_COLOR(toolbarBackground,    "#00ffffff", "#00ffffff", "#000D1117", "#000D1117")
    DECLARE_QGC_COLOR(groupBorder,          "#bbbbbb", "#3A9BDC", "#1E3A4A", "#1E3A4A")

    // Colors not affecting by theming
    //                                                      Disabled     Enabled
    DECLARE_QGC_NONTHEMED_COLOR(brandingPurple,             "#4A2C6D", "#4A2C6D")
    DECLARE_QGC_NONTHEMED_COLOR(brandingBlue,               "#48D6FF", "#6045c5")
    DECLARE_QGC_NONTHEMED_COLOR(toolStripFGColor,           "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(photoCaptureButtonColor,    "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(videoCaptureButtonColor,    "#f89a9e", "#f32836")

    // Colors not affecting by theming or enable/disable
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderLight,          "#ffffff")
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderDark,           "#000000")
    DECLARE_QGC_SINGLE_COLOR(mapMissionTrajectory,          "#00BFFF")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonInterior,         "green")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonTerrainCollision, "red")

// Colors for UTM Adapter
#ifdef QGC_UTM_ADAPTER
    DECLARE_QGC_COLOR(switchUTMSP,        "#b0e0e6", "#b0e0e6", "#b0e0e6", "#b0e0e6");
    DECLARE_QGC_COLOR(sliderUTMSP,        "#9370db", "#9370db", "#9370db", "#9370db");
    DECLARE_QGC_COLOR(successNotifyUTMSP, "#3cb371", "#3cb371", "#3cb371", "#3cb371");
#endif
}

void QGCPalette::setColorGroupEnabled(bool enabled)
{
    _colorGroupEnabled = enabled;
    emit paletteChanged();
}

void QGCPalette::setGlobalTheme(Theme newTheme)
{
    // Mobile build does not have themes
    if (_theme != newTheme) {
        _theme = newTheme;
        _signalPaletteChangeToAll();
    }
}

void QGCPalette::_signalPaletteChangeToAll()
{
    // Notify all objects of the new theme
    for (QGCPalette *palette : std::as_const(_paletteObjects)) {
        palette->_signalPaletteChanged();
    }
}

void QGCPalette::_signalPaletteChanged()
{
    emit paletteChanged();
}
