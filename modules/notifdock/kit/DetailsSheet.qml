import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// What a card keeps behind "Details": a sheet that slides up over the
// card's lower part, under its head, and scrolls if it must. The card's
// main view stays short; this is where the rest goes.
StyledRect {
    id: root

    property bool open
    property Component content
    property real sheetTop: 56
    // 0 closed, 1 open. Animated by itself, so a card that is created (or
    // resized) never shows the sheet sliding.
    property real shown: open ? 1 : 0

    y: parent.height - shown * (parent.height - sheetTop)
    width: parent.width
    height: parent.height - sheetTop
    visible: shown > 0
    radius: NotifDockState.px(Tokens.rounding.large + 4)
    color: Colours.palette.m3surfaceContainerHigh

    Behavior on shown {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: NotifDockState.px(Tokens.padding.large + 4)
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Loader {
            id: body

            width: parent.width
            active: root.open || root.visible
            sourceComponent: root.content
        }
    }
}
