pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// The OSD's mixer, beside its volume or microphone pill: a pill for each app
// that is playing (or recording) right now, lined up with the OSD's own pill,
// and a device chip over (or under) them that lists the outputs (or inputs)
// to switch to.
Item {
    id: root

    property bool input
    // The chip under the app pills instead of over them: Content.qml puts it
    // beside whichever OSD pill has room to spare.
    property bool chipBelow
    property bool showDevices

    // The apps playing (or recording) now; Content.qml picks them.
    required property list<PwNode> streams
    readonly property PwNode device: input ? Audio.source : Audio.sink
    readonly property list<PwNode> devices: input ? Audio.sources : Audio.sinks
    readonly property real spacing: Tokens.spacing.small
    // Where the app pills start, from the top: Content.qml lines them up with
    // their OSD pill.
    readonly property real pillsTop: chipBelow ? 0 : chipRect.implicitHeight + spacing

    signal interacted

    function deviceIcon(node: PwNode): string {
        const text = `${node?.description ?? ""} ${node?.name ?? ""}`.toLowerCase();
        if (input)
            return /headset|headphone|epos|airpods|buds|bluez/.test(text) ? "headset_mic" : "mic";
        if (/bluez|bluetooth/.test(text))
            return "bluetooth";
        if (/headset|headphone|epos|airpods|buds/.test(text))
            return "headphones";
        if (/hdmi|displayport|monitor/.test(text))
            return "tv";
        return "speaker";
    }

    // Never narrower than the chip (one app pill, or none, is narrower than
    // the icon and the arrow). Content.qml sets the width itself, easing it
    // towards this one.
    implicitWidth: Math.max(chipRect.implicitWidth, body.implicitWidth)
    implicitHeight: chipRect.implicitHeight + spacing + body.implicitHeight

    // The device in use; click for the list of every device.
    StyledRect {
        id: chipRect

        y: root.chipBelow ? body.implicitHeight + root.spacing : 0
        width: root.width
        implicitWidth: chip.implicitWidth + Tokens.padding.small * 2
        implicitHeight: chip.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: root.showDevices ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 2)

        StateLayer {
            radius: Tokens.rounding.full
            color: Colours.palette.m3onSecondaryContainer
            onClicked: {
                root.showDevices = !root.showDevices;
                root.interacted();
            }
        }

        Row {
            id: chip

            anchors.centerIn: parent
            spacing: 0

            MaterialIcon {
                text: root.deviceIcon(root.device)
                color: root.showDevices ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            MaterialIcon {
                visible: root.devices.length > 1
                text: root.showDevices ? "arrow_drop_up" : "arrow_drop_down"
                color: root.showDevices ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    // The app pills, or the device list in their place.
    Item {
        id: body

        y: root.pillsTop
        width: root.width
        implicitWidth: root.showDevices ? Tokens.sizes.osd.sliderWidth * 8.5 : pills.implicitWidth
        implicitHeight: root.showDevices ? Math.max(Tokens.sizes.osd.sliderHeight, deviceList.implicitHeight) : pills.implicitHeight

        // One pill per app, or an empty one. The first app sits next to the
        // OSD's pill and later ones join on the far side, so the pills already
        // there keep their places; when an app leaves, the rest slide over.
        // Each pill is placed from the right edge, the one that stays put (a
        // Row's x counts from its left edge, which moves as pills come).
        Item {
            id: pills

            readonly property real step: Tokens.sizes.osd.sliderWidth + Tokens.spacing.medium

            anchors.right: parent.right
            visible: !root.showDevices
            implicitWidth: Math.max(1, root.streams.length) * step - Tokens.spacing.medium
            implicitHeight: Tokens.sizes.osd.sliderHeight

            Repeater {
                model: ScriptModel {
                    values: [...root.streams]
                }

                AppPill {
                    required property PwNode modelData
                    required property int index

                    // Not parent.right: a pill on its way out has no parent.
                    anchors.right: pills.right
                    anchors.rightMargin: index * pills.step
                    stream: modelData
                    onInteracted: root.interacted()

                    Behavior on anchors.rightMargin {
                        Anim {}
                    }
                }
            }

            StyledRect {
                anchors.right: parent.right
                visible: root.streams.length === 0
                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight
                radius: Tokens.rounding.full
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.input ? "mic_off" : "music_off"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        // The devices, as a short list.
        ColumnLayout {
            id: deviceList

            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.showDevices
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.devices

                StyledRect {
                    id: deviceRow

                    required property PwNode modelData
                    readonly property bool current: root.device?.id === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: deviceText.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: current ? Colours.palette.m3secondary : Colours.layer(Colours.palette.m3surfaceContainer, 2)

                    StateLayer {
                        radius: Tokens.rounding.full
                        color: deviceRow.current ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface
                        onClicked: {
                            if (root.input)
                                Audio.setAudioSource(deviceRow.modelData);
                            else
                                Audio.setAudioSink(deviceRow.modelData);
                            root.showDevices = false;
                            root.interacted();
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: root.deviceIcon(deviceRow.modelData)
                            color: deviceRow.current ? Colours.palette.m3onSecondary : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            id: deviceText

                            Layout.fillWidth: true
                            text: deviceRow.modelData.description || deviceRow.modelData.nickname || deviceRow.modelData.name || Tr.trCtx("Unknown device", "unknown audio device")
                            font: Tokens.font.body.small
                            color: deviceRow.current ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
