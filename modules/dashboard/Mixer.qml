pragma ComponentBehavior: Bound

import "mixer"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// The dashboard's audio mixer: the output and the input with their devices,
// volumes and mute, a live level for the microphone, and every app that is
// playing or recording, each with its own volume.
Item {
    id: root

    // Streams of this shell itself (the level meter's own capture, the
    // visualiser) are not apps.
    readonly property list<PwNode> appStreams: Audio.streams.filter(s => {
        const props = s?.properties ?? {};
        return String(props["application.process.id"] ?? "") !== String(Quickshell.processId) && props["stream.monitor"] !== "true";
    })

    // The level as a share of the -60..0 dB range, so a quiet microphone still
    // shows movement.
    readonly property real micLevel: {
        const peak = micPeak.peak;
        if (!(peak > 0))
            return 0;
        return Math.max(0, Math.min(1, (20 * Math.log10(peak) + 60) / 60));
    }

    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
    implicitHeight: layout.implicitHeight

    PwNodePeakMonitor {
        id: micPeak

        node: Audio.source
        enabled: root.visible && !!Audio.source && !Audio.sourceMuted
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            DeviceCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                title: Tr.trCtx("Output", "audio output")
                icon: "speaker"
                node: Audio.sink
                devices: Audio.sinks
                onDeviceSelected: device => Audio.setAudioSink(device)
            }

            DeviceCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                title: Tr.trCtx("Input", "audio input")
                icon: "mic"
                node: Audio.source
                devices: Audio.sources
                isInput: true
                onDeviceSelected: device => Audio.setAudioSource(device)

                // The microphone's live level, under the slider.
                StyledRect {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.small
                    Layout.rightMargin: Tokens.padding.small
                    implicitHeight: Tokens.padding.extraSmall * 2
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHighest

                    StyledRect {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        implicitWidth: parent.width * root.micLevel
                        radius: Tokens.rounding.full
                        // Red from -3 dB up, close to clipping.
                        color: root.micLevel > 0.95 ? Colours.palette.m3error : Colours.palette.m3primary

                        Behavior on implicitWidth {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: appsColumn.implicitHeight + Tokens.padding.large * 2
            color: Colours.tPalette.m3surfaceContainerLow
            radius: Tokens.rounding.extraLarge

            ColumnLayout {
                id: appsColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacing.extraSmall
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "apps"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.trCtx("Apps", "apps playing or recording audio")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3primary
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: [...root.appStreams]
                    }

                    StreamRow {
                        required property PwNode modelData

                        Layout.fillWidth: true
                        stream: modelData
                    }
                }

                // Nothing playing or recording.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.padding.medium
                    Layout.bottomMargin: Tokens.padding.medium
                    visible: root.appStreams.length === 0
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "music_off"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("No apps are playing or recording")
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("Each app that plays or records sound gets its own volume here")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3outline
                    }
                }
            }
        }
    }
}
