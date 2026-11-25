pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// A yes/no only you can answer ("Was this you?"): the question big, the
// three facts that decide it, and the two answers. Anything more (a fourth
// fact, the source's own message) is behind Details. In the sheet: the hero,
// all four facts (never cut), the email's own text, and, pinned below the
// scrolling detail, the question with its answers.
// Sections: question {text, detail, icon, tone}, facts {items: [{icon,
// label, value, detail}]}. Actions: the two answers.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})
    property bool showDetails

    readonly property var question: Kit.section(item, "question") ?? ({})
    readonly property var facts: Kit.section(item, "facts")?.items ?? []
    readonly property color ink: Kit.tone(Colours.palette, question.tone ?? "tertiary")
    // The sheet (layoutMode "sheet"): what happened as the hero, all the
    // facts in one row, then the question and its answers (pill buttons).
    readonly property bool sheet: NotifDockState.layoutMode === "sheet"
    property Component detailsContent: facts.length > 3 || item?.original ? extra : null
    property Component actionsContent: actionsRow
    // The email's own text (the sheet shows it under the facts).
    readonly property string body: String(item?.body ?? "").trim()

    spacing: sheet ? NotifDockState.px(Tokens.spacing.medium) : NotifDockState.px(Tokens.spacing.large)

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
        visible: !root.sheet
        spacing: NotifDockState.px(Tokens.spacing.large)

        StyledRect {
            implicitWidth: NotifDockState.px(64)
            implicitHeight: NotifDockState.px(64)
            radius: NotifDockState.px(Tokens.rounding.full)
            color: Qt.alpha(root.ink, 0.16)

            MaterialIcon {
                anchors.centerIn: parent
                text: root.question.icon ?? "help"
                fill: 1
                color: root.ink
                fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(26))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: NotifDockState.px(2)

            StyledText {
                Layout.fillWidth: true
                text: root.question.text ?? root.item?.title ?? ""
                elide: Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.title.builders.large.size(Tokens.font.title.large.pointSize * NotifDockState.emph(1.4)).weight(Font.DemiBold))
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.item?.subtitle || (root.question.detail ?? "")
                elide: Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // The sheet's hero: what happened.
    RowLayout {
        Layout.fillWidth: true
        visible: root.sheet
        spacing: NotifDockState.px(Tokens.spacing.large)

        StyledRect {
            implicitWidth: NotifDockState.px(64)
            implicitHeight: NotifDockState.px(64)
            radius: NotifDockState.px(Tokens.rounding.full)
            color: Qt.alpha(root.ink, 0.16)

            MaterialIcon {
                anchors.centerIn: parent
                text: root.question.icon ?? "help"
                fill: 1
                color: root.ink
                fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(30))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: NotifDockState.px(4)

            StyledText {
                Layout.fillWidth: true
                text: root.item?.title ?? ""
                wrapMode: Text.WordWrap
                font: NotifDockState.dfont(Tokens.font.title.builders.large.size(Tokens.font.title.large.pointSize * NotifDockState.emph(1.2)).weight(Font.DemiBold))
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.item?.subtitle ?? ""
                wrapMode: Text.WordWrap
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    FactRow {
        Layout.fillWidth: true
        visible: root.sheet && root.facts.length > 0
        facts: root.facts
    }

    // The sheet: the email's own words, under the facts (the detail
    // scrolls when they are long).
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: NotifDockState.px(Tokens.spacing.small)
        visible: root.sheet && root.body !== ""
        spacing: NotifDockState.px(4)

        StyledText {
            text: qsTr("From the email")
            font: NotifDockState.dfont(Tokens.font.label.builders.medium)
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.fillWidth: true
            text: root.body
            wrapMode: Text.WordWrap
            font: NotifDockState.dfont(Tokens.font.body.builders.medium)
            color: Colours.palette.m3onSurface
            lineHeight: 1.1
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !root.sheet
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
        Layout.fillHeight: !root.sheet
    }

    // The answers (in the sheet, with the question above them): here in the
    // deck; in the sheet, pinned under the scrolling detail (ItemCard loads
    // actionsContent there).
    Loader {
        Layout.fillWidth: true
        active: !NotifDockState.compact
        visible: active
        sourceComponent: actionsRow
    }

    Item {
        Layout.fillHeight: root.sheet
    }

    Component {
        id: actionsRow

        ColumnLayout {
            spacing: root.spacing

            // The sheet's question, above its answers.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.sheet
                spacing: NotifDockState.px(2)

                StyledText {
                    Layout.fillWidth: true
                    text: root.question.text ?? ""
                    wrapMode: Text.WordWrap
                    font: NotifDockState.dfont(Tokens.font.title.builders.medium.size(Tokens.font.title.medium.pointSize * NotifDockState.emph(1.2)).weight(Font.DemiBold))
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.question.detail ?? ""
                    wrapMode: Text.WordWrap
                    font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            ActionGroup {
                Layout.fillWidth: true
                item: root.item
                unit: root.unit
                actions: (root.item?.actions ?? []).slice(0, 2)
                equal: !root.sheet
                big: !root.sheet
            }
        }
    }

    Component {
        id: extra

        Column {
            spacing: NotifDockState.px(Tokens.spacing.medium)

            Repeater {
                model: root.facts.slice(3)

                Tile {
                    required property var modelData

                    width: NotifDockState.px(260)
                    icon: modelData.icon ?? "info"
                    label: modelData.label ?? ""
                    value: modelData.value ?? ""
                    detail: modelData.detail ?? ""
                }
            }

            Link {
                item: root.item
                text: root.item?.original?.label ?? ""
                url: root.item?.original?.url ?? ""
            }
        }
    }
}
