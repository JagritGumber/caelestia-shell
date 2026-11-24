pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// The OSD's mixer, beside its volume or microphone pill: a device chip that
// lists the outputs (or inputs) to switch to, and a pill for each app that is
// playing (or recording) right now.
ColumnLayout {
    id: root

    property bool input
    property bool showDevices

    // The apps playing (or recording) now; Content.qml picks them.
    required property list<PwNode> streams
    readonly property PwNode device: input ? Audio.source : Audio.sink
    readonly property list<PwNode> devices: input ? Audio.sources : Audio.sinks
    readonly property real pillsTop: chipRect.implicitHeight + spacing

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

    spacing: Tokens.spacing.small

    // The device in use; click for the list of every device.
    StyledRect {
        id: chipRect

        Layout.fillWidth: true
        // Its own width, so the column is never narrower than the chip (one
        // app pill, or none, is narrower than the icon and the arrow).
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

    // One pill per app, or an empty one.
    RowLayout {
        Layout.alignment: Qt.AlignRight
        visible: !root.showDevices
        spacing: Tokens.spacing.medium

        Repeater {
            model: ScriptModel {
                values: [...root.streams]
            }

            AppPill {
                required property PwNode modelData

                stream: modelData
                onInteracted: root.interacted()
            }
        }

        StyledRect {
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

    // The devices, as a short list in place of the app pills.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: Tokens.sizes.osd.sliderWidth * 8.5
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
