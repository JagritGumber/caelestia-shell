pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// Numbers that matter: the one figure big, then up to three rows of label
// and value, a value in a tone when it is the point ("Due 24 Nov" in red).
// More rows are behind Details.
// Sections: amount {value, currency, label}, table {rows: [{label, value,
// tone, mono}]}.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})
    property bool showDetails

    readonly property var amount: Kit.section(item, "amount")
    readonly property var rows: Kit.section(item, "table")?.rows ?? []
    property Component detailsContent: rows.length > 3 ? extra : null
    property Component actionsContent: actionsRow

    spacing: NotifDockState.px(Tokens.spacing.large)

    CardHead {
        Layout.fillWidth: true
        item: root.item
        unit: root.unit
        kind: root.item?.kind ?? ""
        status: root.head.text ?? ""
        statusIcon: root.head.icon ?? "schedule"
        tone: root.head.tone ?? ""
        hasDetails: root.detailsContent !== null
        detailsOpen: root.showDetails
        onToggleDetails: root.showDetails = !root.showDetails
    }

    // The hero: the figure.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: NotifDockState.px(Tokens.spacing.small)
        visible: !!root.amount
        spacing: 0

        StyledText {
            text: Kit.money(root.amount?.value, root.amount?.currency)
            font: NotifDockState.dfont(Tokens.font.title.builders.large.size(Tokens.font.title.large.pointSize * NotifDockState.emph(2)).weight(Font.DemiBold))
        }

        StyledText {
            text: root.amount?.label ?? ""
            font: NotifDockState.dfont(Tokens.font.body.builders.medium)
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    TableRows {
        Layout.fillWidth: true
        rows: root.rows.slice(0, 3)
    }

    Item {
        Layout.fillHeight: true
    }

    // The action row: here in the deck; in the sheet, pinned under the
    // scrolling detail (ItemCard loads actionsContent there).
    Loader {
        Layout.fillWidth: true
        active: !NotifDockState.compact
        visible: active
        sourceComponent: actionsRow
    }

    Component {
        id: actionsRow

        ColumnLayout {
            spacing: root.spacing

            ActionGroup {
                Layout.fillWidth: true
                item: root.item
                unit: root.unit
                actions: root.item?.actions ?? []
            }
        }
    }

    Component {
        id: extra

        TableRows {
            rows: root.rows.slice(3)
        }
    }
}
