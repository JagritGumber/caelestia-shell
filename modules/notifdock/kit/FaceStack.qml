import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Several people as overlapping faces, then "+N" for the rest.
Row {
    id: root

    // [{name, image}]
    property var people: []
    property int max: 5
    property real size: 30
    property color ring: Colours.palette.m3surfaceContainer

    spacing: -Math.round(size * 0.28)

    Repeater {
        model: root.people.slice(0, root.max)

        Face {
            required property var modelData

            size: root.size
            name: modelData.name ?? ""
            image: modelData.image ?? ""
            ring: root.ring
            ringWidth: 2
        }
    }

    StyledRect {
        visible: root.people.length > root.max
        implicitWidth: root.size
        implicitHeight: root.size
        radius: NotifDockState.px(Tokens.rounding.full)
        color: Colours.palette.m3surfaceContainerHighest
        border.width: 2
        border.color: root.ring

        StyledText {
            anchors.centerIn: parent
            text: `+${root.people.length - root.max}`
            font: NotifDockState.dfont(Tokens.font.label.builders.medium)
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
