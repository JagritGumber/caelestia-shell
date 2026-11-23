pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// One volume control for a PipeWire node: the speaker or mic icon mutes it, the
// slider (or the scroll wheel over it) sets the volume, and the level shows in
// percent. Moving the slider of a muted node unmutes it.
RowLayout {
    id: root

    required property PwNode node
    property bool isInput
    property bool showIcon: true

    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: !!node?.audio?.muted

    function setVolume(value: real): void {
        Audio.setStreamVolume(node, value);
    }

    spacing: Tokens.spacing.medium

    IconButton {
        visible: root.showIcon
        icon: root.isInput ? Icons.getMicVolumeIcon(root.volume, root.muted) : Icons.getVolumeIcon(root.volume, root.muted)
        type: IconButton.Tonal
        checked: root.muted
        onClicked: Audio.setStreamMuted(root.node, !root.muted)
    }

    CustomMouseArea {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3

        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.setVolume(root.volume + GlobalConfig.services.audioIncrement);
            else if (event.angleDelta.y < 0)
                root.setVolume(root.volume - GlobalConfig.services.audioIncrement);
        }

        StyledSlider {
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight

            fgColour: root.muted ? Qt.alpha(Colours.palette.m3onSurface, 0.38) : Colours.palette.m3primary
            value: root.volume
            onInteraction: value => root.setVolume(value)
        }
    }

    StyledText {
        Layout.preferredWidth: percentWidth.advanceWidth
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(root.volume * 100)}%`
        font: Tokens.font.body.small
        color: root.muted ? Colours.palette.m3outline : Colours.palette.m3onSurfaceVariant

        TextMetrics {
            id: percentWidth

            font: Tokens.font.body.small
            text: "100%"
        }
    }
}
