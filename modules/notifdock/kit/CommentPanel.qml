pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// Someone said something to you: who, where, and what they said, big as a
// speech bubble. The reply field is the main thing to do, with +1 and
// Resolve beside it. The code they mean and the earlier replies are behind
// Details.
// Sections: person, diff, comment, thread. Actions: input (the reply),
// then quick ones.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})
    property bool showDetails

    readonly property var person: Kit.section(item, "person") ?? ({})
    readonly property var diff: Kit.section(item, "diff")
    readonly property var comment: Kit.section(item, "comment") ?? ({})
    readonly property var thread: Kit.section(item, "thread")
    readonly property var replyAction: (item?.actions ?? []).find(a => a.type === "input") ?? null
    readonly property var quick: (item?.actions ?? []).filter(a => a.type !== "input")
    property Component detailsContent: diff || thread || item?.original ? extra : null
    property Component actionsContent: actionsRow

    spacing: NotifDockState.px(Tokens.spacing.large)

    CardHead {
        Layout.fillWidth: true
        item: root.item
        unit: root.unit
        kind: root.item?.kind ?? ""
        status: root.head.text ?? ""
        statusIcon: root.head.icon ?? "chat_bubble"
        tone: root.head.tone ?? ""
        hasDetails: root.detailsContent !== null
        detailsOpen: root.showDetails
        onToggleDetails: root.showDetails = !root.showDetails
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: NotifDockState.px(Tokens.spacing.medium)

        Face {
            size: NotifDockState.px(44)
            name: root.person.name ?? ""
            image: root.person.image ?? ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: root.person.name ?? ""
                font: NotifDockState.dfont(Tokens.font.title.builders.medium.weight(Font.DemiBold))
            }

            StyledText {
                Layout.fillWidth: true
                text: root.item?.subtitle ?? ""
                elide: Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.body.builders.small)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // The hero: what they said.
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: said.implicitHeight + NotifDockState.px(Tokens.padding.large) * 2
        radius: NotifDockState.px(Tokens.rounding.large + 4)
        topLeftRadius: NotifDockState.px(Tokens.rounding.extraSmall)
        color: Colours.palette.m3surfaceContainerHigh

        StyledText {
            id: said

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: NotifDockState.px(Tokens.padding.large)
            text: root.comment.text ?? ""
            wrapMode: Text.WordWrap
            maximumLineCount: NotifDockState.compact ? 1000 : 4
            elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
            font: NotifDockState.compact ? NotifDockState.dfont(Tokens.font.body.builders.medium) : NotifDockState.dfont(Tokens.font.body.builders.large)
            lineHeight: 1.1
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

            RowLayout {
                Layout.fillWidth: true
                spacing: NotifDockState.px(Tokens.spacing.small)

                QuickReply {
                    Layout.fillWidth: true
                    visible: !!root.replyAction
                    item: root.item
                    action: root.replyAction
                    hint: `Reply to ${String(root.person.name ?? "").split(" ")[0]}…`
                }

                ActionGroup {
                    Layout.alignment: Qt.AlignTop
                    item: root.item
                    unit: null
                    actions: root.quick
                    iconOnly: true
                }
            }
        }
    }

    Component {
        id: extra

        Column {
            spacing: NotifDockState.px(Tokens.spacing.large)

            StyledClippingRect {
                width: parent.width
                visible: !!root.diff
                implicitHeight: diffCol.implicitHeight
                radius: NotifDockState.px(Tokens.rounding.medium)
                color: Colours.palette.m3surfaceContainerLowest

                Column {
                    id: diffCol

                    width: parent.width

                    StyledText {
                        width: parent.width
                        leftPadding: NotifDockState.px(Tokens.padding.medium)
                        topPadding: NotifDockState.px(Tokens.padding.small)
                        bottomPadding: NotifDockState.px(4)
                        text: root.diff?.file ?? ""
                        elide: Text.ElideMiddle
                        font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                        color: Colours.palette.m3outline
                    }

                    Repeater {
                        model: root.diff?.lines ?? []

                        StyledRect {
                            id: line

                            required property var modelData

                            width: diffCol.width
                            implicitHeight: lineText.implicitHeight + NotifDockState.px(4)
                            color: modelData.kind === "add" ? Qt.alpha(Colours.palette.m3success, 0.14) : modelData.kind === "del" ? Qt.alpha(Colours.palette.m3error, 0.14) : "transparent"

                            StyledText {
                                id: lineText

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: NotifDockState.px(Tokens.padding.medium)
                                text: `${line.modelData.n ?? ""}  ${line.modelData.kind === "add" ? "+" : line.modelData.kind === "del" ? "−" : " "} ${line.modelData.text ?? ""}`
                                elide: Text.ElideRight
                                font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                                color: line.modelData.kind === "add" ? Colours.palette.m3success : line.modelData.kind === "del" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: NotifDockState.px(Tokens.padding.small)
                    }
                }
            }

            Row {
                visible: !!root.thread
                spacing: NotifDockState.px(Tokens.spacing.small)

                FaceStack {
                    anchors.verticalCenter: parent.verticalCenter
                    people: root.thread?.people ?? []
                    size: NotifDockState.px(22)
                    ring: Colours.palette.m3surfaceContainerHigh
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.thread ? `${root.thread.count} earlier ${root.thread.count === 1 ? "reply" : "replies"}` : ""
                    font: NotifDockState.dfont(Tokens.font.label.builders.large)
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StyledText {
                width: parent.width
                text: root.comment.text ?? ""
                wrapMode: Text.WordWrap
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
            }

            Link {
                item: root.item
                text: root.item?.original?.label ?? ""
                url: root.item?.original?.url ?? ""
            }
        }
    }
}
