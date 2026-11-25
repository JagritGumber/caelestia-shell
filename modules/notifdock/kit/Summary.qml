pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// Anything that names no other component: an alert, a sign-in, a payment,
// and every v1/v2 item that isn't CI, a review or a comment (kit/adapt.js).
// What happened, big, beside its symbol; one line of context; up to three
// facts as tiles; the actions. The whole message and any other facts are
// behind Details.
// Sections: facts {items}, text {text}.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})
    property bool showDetails

    readonly property var facts: Kit.section(item, "facts")?.items ?? []
    readonly property string body: Kit.section(item, "text")?.text || String(item?.body ?? "").trim()
    readonly property color ink: item?.urgency === "critical" ? Colours.palette.m3tertiary : Colours.palette.m3primary
    // In the sheet the body and four facts are inline, so Details keeps the rest.
    property Component detailsContent: (NotifDockState.compact ? facts.length > 4 || item?.original : facts.length > 3 || body || item?.original) ? extra : null
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

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: NotifDockState.px(Tokens.spacing.small)
        spacing: NotifDockState.px(Tokens.spacing.large)

        StyledRect {
            Layout.alignment: Qt.AlignTop
            implicitWidth: NotifDockState.px(64)
            implicitHeight: NotifDockState.px(64)
            radius: NotifDockState.px(Tokens.rounding.full)
            color: Qt.alpha(root.ink, 0.16)

            MaterialIcon {
                anchors.centerIn: parent
                text: root.item?.symbol ?? "notifications"
                fill: 1
                color: root.ink
                fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(26))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: NotifDockState.px(4)

            StyledText {
                Layout.fillWidth: true
                text: root.item?.title ?? ""
                wrapMode: Text.WordWrap
                maximumLineCount: NotifDockState.compact ? 1000 : 2
                elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.title.builders.large.size(Tokens.font.title.large.pointSize * NotifDockState.emph(1.15)).weight(Font.DemiBold))
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.item?.subtitle ?? ""
                wrapMode: Text.WordWrap
                maximumLineCount: NotifDockState.compact ? 1000 : 2
                elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // The sheet: up to four facts, never cut (FactRow), then the text.
    FactRow {
        Layout.fillWidth: true
        visible: NotifDockState.compact && root.facts.length > 0
        facts: root.facts
    }

    StyledText {
        Layout.fillWidth: true
        visible: NotifDockState.compact && text !== ""
        text: root.body
        wrapMode: Text.WordWrap
        font: NotifDockState.dfont(Tokens.font.body.builders.medium)
        color: Colours.palette.m3onSurface
        lineHeight: 1.1
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !NotifDockState.compact && root.facts.length > 0
        spacing: NotifDockState.px(Tokens.spacing.small)

        Repeater {
            model: root.facts.slice(0, 3)

            Tile {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: modelData.icon ?? "info"
                label: modelData.label ?? ""
                value: modelData.value ?? ""
                detail: modelData.detail ?? ""
                tone: modelData.tone ?? ""
            }
        }
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
                actions: (root.item?.actions ?? []).slice(0, 3)
            }
        }
    }

    Component {
        id: extra

        Column {
            spacing: NotifDockState.px(Tokens.spacing.large)

            Flow {
                width: parent.width
                visible: root.facts.length > (NotifDockState.compact ? 4 : 3)
                spacing: NotifDockState.px(Tokens.spacing.small)

                Repeater {
                    model: root.facts.slice(NotifDockState.compact ? 4 : 3)

                    Tile {
                        required property var modelData

                        width: NotifDockState.px(250)
                        icon: modelData.icon ?? "info"
                        label: modelData.label ?? ""
                        value: modelData.value ?? ""
                        detail: modelData.detail ?? ""
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: text !== "" && !NotifDockState.compact
                text: root.body
                wrapMode: Text.WordWrap
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }

            Link {
                item: root.item
                text: root.item?.original?.label ?? ""
                url: root.item?.original?.url ?? ""
            }
        }
    }
}
