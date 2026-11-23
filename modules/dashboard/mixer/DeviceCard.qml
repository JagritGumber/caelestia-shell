pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// The default output or input: its name (a button that lists every device to
// switch to), its volume and mute, and anything a caller adds below.
StyledRect {
    id: root

    required property string title
    required property string icon
    required property PwNode node
    required property list<PwNode> devices
    property bool isInput
    property bool expanded

    default property alias extra: extraColumn.data

    signal deviceSelected(device: PwNode)

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge
    implicitHeight: column.implicitHeight + Tokens.padding.large * 2

    ButtonGroup {
        id: deviceGroup
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: root.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                text: root.title
                font: Tokens.font.title.medium
                color: Colours.palette.m3primary
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // The device in use; with more than one, a button that lists them all.
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: deviceRow.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.full
            color: root.expanded ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

            StateLayer {
                disabled: root.devices.length < 2
                color: Colours.palette.m3onSecondaryContainer
                onClicked: root.expanded = !root.expanded
            }

            RowLayout {
                id: deviceRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.large
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.node?.description || root.node?.nickname || root.node?.name || Tr.trCtx("No device", "no audio device")
                    font: Tokens.font.body.medium
                    color: root.expanded ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    opacity: root.devices.length > 1 ? 1 : 0 // keeps the pill's height
                    text: root.expanded ? "expand_less" : "expand_more"
                    color: root.expanded ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.expanded
            spacing: Tokens.spacing.small

            Repeater {
                model: root.devices

                StyledRadioButton {
                    required property PwNode modelData

                    Layout.fillWidth: true
                    ButtonGroup.group: deviceGroup
                    checked: root.node?.id === modelData.id
                    text: modelData.description || modelData.nickname || modelData.name
                    onClicked: {
                        root.deviceSelected(modelData);
                        root.expanded = false;
                    }
                }
            }
        }

        VolumeRow {
            Layout.fillWidth: true
            node: root.node
            isInput: root.isInput
            enabled: !!root.node
        }

        ColumnLayout {
            id: extraColumn

            Layout.fillWidth: true
            spacing: Tokens.spacing.small
        }
    }
}
