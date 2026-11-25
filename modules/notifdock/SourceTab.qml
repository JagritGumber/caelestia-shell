import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import "kit"

// A source's tab (tabsMode "sources"): its icon and count; the shown tab
// also spells out the name. The count's badge is a tertiary container while
// a critical item is open (the scheme's accent, never the error colour).
StyledRect {
    id: root

    property string label
    property string icon
    property string symbol: "inbox"
    property int count
    property bool critical
    property bool active

    signal picked

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: 40
    radius: Tokens.rounding.full
    color: active ? Colours.palette.m3secondaryContainer : "transparent"

    StateLayer {
        color: root.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        onClicked: root.picked()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        SourceBadge {
            anchors.verticalCenter: parent.verticalCenter
            size: 30
            icon: root.icon
            symbol: root.symbol
            color: "transparent"
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.active
            text: root.label
            font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
            color: Colours.palette.m3onSecondaryContainer
        }

        StyledRect {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(implicitHeight, badge.implicitWidth + 10)
            implicitHeight: 18
            radius: Tokens.rounding.full
            color: root.critical ? Colours.palette.m3tertiaryContainer : root.active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

            StyledText {
                id: badge

                anchors.centerIn: parent
                text: root.count
                font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                color: root.critical ? Colours.palette.m3onTertiaryContainer : root.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
