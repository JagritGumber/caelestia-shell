import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// A person: their picture from a local file (file:// only), else their
// initials on one of four container colours, fixed per name. `ring` draws a
// border in the card's colour, for faces that overlap in a stack.
StyledClippingRect {
    id: root

    property string image
    property string name
    property real size: 32
    property color ring: "transparent"
    property real ringWidth: 0

    readonly property int hue: Kit.hue(name)
    readonly property var fills: [Colours.palette.m3primaryContainer, Colours.palette.m3secondaryContainer, Colours.palette.m3tertiaryContainer, Colours.palette.m3successContainer]
    readonly property var inks: [Colours.palette.m3onPrimaryContainer, Colours.palette.m3onSecondaryContainer, Colours.palette.m3onTertiaryContainer, Colours.palette.m3onSuccessContainer]

    implicitWidth: size
    implicitHeight: size
    radius: NotifDockState.px(Tokens.rounding.full)
    color: fills[hue]
    border.width: ringWidth
    border.color: ring

    StyledText {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        text: Kit.initials(root.name)
        font.family: Tokens.font.label.large.family
        font.pixelSize: Math.round(root.size * 0.38)
        font.weight: Font.DemiBold
        color: root.inks[root.hue]
    }

    Image {
        id: picture

        anchors.fill: parent
        anchors.margins: root.ringWidth
        source: root.image.startsWith("file:") ? root.image : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
}
