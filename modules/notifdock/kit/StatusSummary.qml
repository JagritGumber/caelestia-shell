pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// Where a run stands: a big mark and the count in words, every job as one
// segment of a bar (named under it, the failed one in red), and the one
// failing test. Re-run is the main thing to do. The log and the branch's
// history are behind Details.
// Sections: status, jobs, failure, log, history.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})
    property bool showDetails

    readonly property var status: Kit.section(item, "status") ?? ({})
    readonly property var jobs: Kit.section(item, "jobs")?.items ?? []
    readonly property var failure: Kit.section(item, "failure")
    readonly property var log: Kit.section(item, "log")?.lines ?? []
    readonly property var history: Kit.section(item, "history")
    readonly property bool failed: status.state === "failed"
    // The mark's circle is tonal; only the ✗ itself (a failed state) is red.
    readonly property color ink: status.state === "passed" ? Colours.palette.m3success : Colours.palette.m3tertiary
    // In the sheet the log is inline, so Details keeps only the rest.
    property Component detailsContent: (NotifDockState.compact ? history || failure?.location : log.length || history || failure) ? extra : null
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
            implicitWidth: NotifDockState.px(64)
            implicitHeight: NotifDockState.px(64)
            radius: NotifDockState.px(Tokens.rounding.full)
            color: Qt.alpha(root.ink, 0.16)

            MaterialIcon {
                anchors.centerIn: parent
                text: root.failed ? "close" : root.status.state === "passed" ? "check" : "progress_activity"
                color: root.failed ? Colours.palette.m3error : root.ink
                fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(24).weight(Font.Bold))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: NotifDockState.px(2)

            StyledText {
                Layout.fillWidth: true
                text: root.status.label ?? root.item?.title ?? ""
                elide: Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.title.builders.large.size(Tokens.font.title.large.pointSize * NotifDockState.emph(1.15)).weight(Font.DemiBold))
            }

            StyledText {
                Layout.fillWidth: true
                text: root.item?.subtitle ?? ""
                elide: Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // Every job as a segment, named under it.
    Row {
        id: segments

        Layout.fillWidth: true
        spacing: NotifDockState.px(4)

        Repeater {
            model: root.jobs

            Column {
                id: job

                required property var modelData

                readonly property bool bad: modelData.state === "failed"

                width: (segments.width - segments.spacing * (root.jobs.length - 1)) / Math.max(1, root.jobs.length)
                spacing: NotifDockState.px(6)

                StyledRect {
                    width: parent.width
                    height: NotifDockState.px(10)
                    radius: NotifDockState.px(5)
                    color: job.bad ? Colours.palette.m3error : job.modelData.state === "passed" ? Colours.palette.m3success : Colours.palette.m3outlineVariant
                }

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: job.modelData.name ?? ""
                    elide: Text.ElideRight
                    font: job.bad ? NotifDockState.dfont(Tokens.font.mono.builders.small.weight(Font.Bold)) : NotifDockState.dfont(Tokens.font.mono.builders.small)
                    color: job.bad ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    // The failing test.
    StyledRect {
        Layout.fillWidth: true
        visible: !!root.failure
        implicitHeight: failCol.implicitHeight + NotifDockState.px(Tokens.padding.large) * 2
        radius: NotifDockState.px(Tokens.rounding.large)
        color: Colours.palette.m3surfaceContainerHigh

        ColumnLayout {
            id: failCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: NotifDockState.px(Tokens.padding.large)
            spacing: NotifDockState.px(4)

            StyledText {
                Layout.fillWidth: true
                text: root.failure?.title ?? ""
                elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
                wrapMode: NotifDockState.compact ? Text.Wrap : Text.NoWrap
                font: NotifDockState.dfont(Tokens.font.mono.builders.small.weight(Font.DemiBold))
                color: Colours.palette.m3error
            }

            StyledText {
                Layout.fillWidth: true
                text: root.failure?.detail ?? ""
                elide: NotifDockState.compact ? Text.ElideNone : Text.ElideRight
                wrapMode: NotifDockState.compact ? Text.Wrap : Text.NoWrap
                font: NotifDockState.dfont(Tokens.font.body.builders.small)
            }
        }
    }

    // The sheet: the failing job's log lines, under the failure (the detail
    // scrolls when there are many).
    StyledRect {
        Layout.fillWidth: true
        visible: NotifDockState.compact && root.log.length > 0
        implicitHeight: sheetLog.implicitHeight + NotifDockState.px(Tokens.padding.medium) * 2
        radius: NotifDockState.px(Tokens.rounding.medium)
        color: Colours.palette.m3surfaceContainerLowest

        Column {
            id: sheetLog

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: NotifDockState.px(Tokens.padding.medium)
            spacing: NotifDockState.px(1)

            Repeater {
                model: NotifDockState.compact ? root.log : []

                StyledText {
                    required property string modelData

                    width: sheetLog.width
                    text: modelData
                    wrapMode: Text.WrapAnywhere
                    font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                    color: /error|fail|✗|×/i.test(modelData) ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
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

            RowLayout {
                Layout.fillWidth: true

                ActionGroup {
                    Layout.fillWidth: true
                    visible: (root.item?.actions ?? []).length > 0
                    item: root.item
                    unit: root.unit
                    actions: root.item?.actions ?? []
                }

                Item {
                    Layout.fillWidth: true
                }

                Link {
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    item: root.item
                    text: root.item?.original?.label ?? ""
                    url: root.item?.original?.url ?? ""
                    icon: "open_in_new"
                }
            }
        }
    }

    Component {
        id: extra

        Column {
            spacing: NotifDockState.px(Tokens.spacing.large)

            StyledText {
                visible: !!root.failure?.location
                text: root.failure?.location ?? ""
                font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledRect {
                width: parent.width
                visible: root.log.length > 0 && !NotifDockState.compact
                implicitHeight: logCol.implicitHeight + NotifDockState.px(Tokens.padding.medium) * 2
                radius: NotifDockState.px(Tokens.rounding.medium)
                color: Colours.palette.m3surfaceContainerLowest

                Column {
                    id: logCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: NotifDockState.px(Tokens.padding.medium)

                    Repeater {
                        model: root.log.slice(-7)

                        StyledText {
                            required property string modelData

                            width: logCol.width
                            text: modelData
                            elide: Text.ElideRight
                            font: NotifDockState.dfont(Tokens.font.mono.builders.small)
                            color: /error|fail|✗|×/i.test(modelData) ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            Column {
                visible: (root.history?.runs ?? []).length > 0
                spacing: NotifDockState.px(6)

                StyledText {
                    text: root.history?.label ?? ""
                    font: NotifDockState.dfont(Tokens.font.label.builders.medium)
                    color: Colours.palette.m3onSurfaceVariant
                }

                Row {
                    spacing: NotifDockState.px(4)

                    Repeater {
                        model: root.history?.runs ?? []

                        StyledRect {
                            required property var modelData
                            required property int index

                            implicitWidth: NotifDockState.px(14)
                            implicitHeight: NotifDockState.px(20)
                            radius: NotifDockState.px(3)
                            color: modelData.state === "failed" ? Colours.palette.m3error : modelData.state === "passed" ? Colours.palette.m3success : Colours.palette.m3outlineVariant
                            opacity: index === (root.history?.runs ?? []).length - 1 ? 1 : 0.55
                        }
                    }
                }
            }
        }
    }
}
