pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// A change waiting for your approval: what it is and who sent it, then how
// big (lines added against removed, as a bar), where it merges and if its
// checks pass. Approve (a second click confirms), Open, Comment. The files
// and the description are behind Details.
// Sections: person, status, branch, size, stats, files, text.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})
    property bool showDetails
    property bool commenting

    readonly property var person: Kit.section(item, "person") ?? ({})
    readonly property var branch: Kit.section(item, "branch")
    readonly property var size: Kit.section(item, "size")
    readonly property var stats: Kit.section(item, "stats")?.items ?? []
    readonly property var status: Kit.section(item, "status")
    readonly property var files: Kit.section(item, "files")
    readonly property string description: Kit.section(item, "text")?.text ?? ""
    readonly property real added: size?.additions ?? 0
    readonly property real removed: size?.deletions ?? 0
    readonly property var inputAction: (item?.actions ?? []).find(a => a.type === "input") ?? null
    property Component detailsContent: (files?.items ?? []).length || description ? extra : null
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

    ColumnLayout {
        Layout.fillWidth: true
        spacing: NotifDockState.px(Tokens.spacing.small)

        StyledText {
            Layout.fillWidth: true
            text: root.item?.title ?? ""
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font: NotifDockState.dfont(Tokens.font.title.builders.medium.size(Tokens.font.title.medium.pointSize * NotifDockState.emph(1.15)).weight(Font.DemiBold))
        }

        RowLayout {
            spacing: NotifDockState.px(Tokens.spacing.small)

            Face {
                size: NotifDockState.px(26)
                name: root.person.name ?? ""
                image: root.person.image ?? ""
            }

            StyledText {
                text: root.person.name ?? ""
                font: NotifDockState.dfont(Tokens.font.label.builders.large.weight(Font.DemiBold))
            }

            StyledText {
                text: root.item?.subtitle ?? ""
                font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // The hero: how big the change is.
    StyledRect {
        Layout.fillWidth: true
        visible: !!root.size
        implicitHeight: sizeCol.implicitHeight + NotifDockState.px(Tokens.padding.large) * 2
        radius: NotifDockState.px(Tokens.rounding.large)
        color: Colours.palette.m3surfaceContainerHigh

        ColumnLayout {
            id: sizeCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: NotifDockState.px(Tokens.padding.large)
            spacing: NotifDockState.px(Tokens.spacing.medium)

            RowLayout {
                Layout.fillWidth: true
                spacing: NotifDockState.px(Tokens.spacing.large)

                StyledText {
                    text: `+${root.added}`
                    font: NotifDockState.dfont(Tokens.font.mono.builders.medium.size(Tokens.font.title.large.pointSize).weight(Font.DemiBold))
                    color: Colours.palette.m3success
                }

                StyledText {
                    text: `−${root.removed}`
                    font: NotifDockState.dfont(Tokens.font.mono.builders.medium.size(Tokens.font.title.large.pointSize).weight(Font.DemiBold))
                    color: Colours.palette.m3error
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.stats.map(s => `${s.value} ${s.label ?? ""}`).join(" · ")
                    font: NotifDockState.dfont(Tokens.font.label.builders.large)
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: NotifDockState.px(10)

                StyledRect {
                    id: addBar

                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: (parent.width - NotifDockState.px(4)) * root.added / Math.max(1, root.added + root.removed)
                    radius: NotifDockState.px(5)
                    color: Colours.palette.m3success
                }

                StyledRect {
                    anchors.left: addBar.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: NotifDockState.px(4)
                    radius: NotifDockState.px(5)
                    color: Colours.palette.m3error
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: NotifDockState.px(Tokens.spacing.small)

                Chip {
                    visible: !!root.branch
                    text: root.branch?.base ?? ""
                    mono: true
                }

                MaterialIcon {
                    visible: !!root.branch
                    text: "arrow_back"
                    color: Colours.palette.m3outline
                    fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(11))
                }

                Chip {
                    visible: !!root.branch
                    text: root.branch?.head ?? ""
                    mono: true
                    tone: "primary"
                }

                Item {
                    Layout.fillWidth: true
                }

                Chip {
                    visible: !!root.status
                    text: root.status?.label ?? ""
                    icon: root.status?.state === "passed" ? "check_circle" : root.status?.state === "failed" ? "cancel" : "pending"
                    tone: root.status?.state === "passed" ? "success" : root.status?.state === "failed" ? "error" : "tertiary"
                }
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

            Loader {
                Layout.fillWidth: true
                active: root.commenting && !!root.inputAction
                visible: active

                sourceComponent: QuickReply {
                    item: root.item
                    action: root.inputAction
                    hint: "Comment on the PR…"
                    Component.onCompleted: start()
                }
            }

            ActionGroup {
                Layout.fillWidth: true
                item: root.item
                unit: root.unit
                actions: root.item?.actions ?? []
                onInput: root.commenting = !root.commenting
            }
        }
    }

    Component {
        id: extra

        Column {
            spacing: NotifDockState.px(Tokens.spacing.medium)

            Flow {
                width: parent.width
                spacing: NotifDockState.px(Tokens.spacing.extraSmall + 2)

                Repeater {
                    model: root.files?.items ?? []

                    Chip {
                        required property var modelData

                        text: `${String(modelData.path ?? "").split("/").pop()}  +${modelData.additions ?? 0}`
                        mono: true
                    }
                }

                Chip {
                    visible: (root.files?.more ?? 0) > 0
                    text: `+${root.files?.more ?? 0} more`
                }
            }

            StyledText {
                width: parent.width
                text: root.description
                wrapMode: Text.WordWrap
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
