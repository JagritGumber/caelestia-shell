pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Up to four facts in one tonal container: a symbol, a small label, the
// value (the sheet's DecisionPanel). Four across when each gets at least
// px(150), else two across (2 x 2). Values are never cut: they wrap. A
// surface, not an outline.
StyledRect {
    id: root

    // [{icon, label, value, detail}]
    property var facts: []

    readonly property int shown: Math.min(4, facts.length)
    readonly property real inner: width - NotifDockState.px(Tokens.padding.large + 4) - NotifDockState.px(Tokens.padding.large)
    readonly property int columns: shown > 2 && inner / shown < NotifDockState.px(150) ? 2 : Math.max(1, shown)

    implicitHeight: grid.implicitHeight + NotifDockState.px(Tokens.padding.medium) * 2
    radius: NotifDockState.px(Tokens.rounding.large + 4)
    color: Colours.palette.m3surfaceContainerHigh

    GridLayout {
        id: grid

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: NotifDockState.px(Tokens.padding.large + 4)
        anchors.rightMargin: NotifDockState.px(Tokens.padding.large)
        columns: root.columns
        columnSpacing: NotifDockState.px(Tokens.spacing.large)
        rowSpacing: NotifDockState.px(Tokens.spacing.medium)

        Repeater {
            model: root.facts.slice(0, 4)

            RowLayout {
                id: fact

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: NotifDockState.px(Tokens.spacing.medium)

                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: NotifDockState.px(2)
                    text: fact.modelData.icon ?? "info"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(16))
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: NotifDockState.px(2)

                    StyledText {
                        Layout.fillWidth: true
                        text: fact.modelData.label ?? ""
                        wrapMode: Text.WordWrap
                        font: NotifDockState.dfont(Tokens.font.body.builders.small)
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: fact.modelData.value ?? ""
                        wrapMode: Text.Wrap
                        font: NotifDockState.dfont(Tokens.font.body.builders.medium.weight(Font.Medium))
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: fact.modelData.detail ?? ""
                        wrapMode: Text.WordWrap
                        font: NotifDockState.dfont(Tokens.font.body.builders.small)
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
