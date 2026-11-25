pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// Rows of label and value with hairlines between (DataTable).
Column {
    id: root

    property var rows: []

    Repeater {
        model: root.rows

        Item {
            id: row

            required property var modelData
            required property int index

            width: root.width
            implicitHeight: NotifDockState.px(36)

            StyledRect {
                anchors.top: parent.top
                width: parent.width
                height: 1
                visible: row.index > 0
                color: Colours.palette.m3outlineVariant
                opacity: 0.6
            }

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label ?? ""
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.value ?? ""
                font: row.modelData.mono ? NotifDockState.dfont(Tokens.font.mono.builders.medium) : NotifDockState.dfont(Tokens.font.body.builders.medium.weight(Font.Medium))
                color: row.modelData.tone ? Kit.tone(Colours.palette, row.modelData.tone) : Colours.palette.m3onSurface
            }
        }
    }
}
