pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "kit.js" as Kit

// An invitation: the day as a calendar leaf, the title, when and where;
// then that day as a strip against your calendar, any clash marked, with
// "Propose new time" beside it. Accept / Maybe / Decline. Who else is
// coming is behind Details.
// Sections: when, person, day, people, place.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var head: ({})
    property bool showDetails

    readonly property var when: Kit.section(item, "when") ?? ({})
    readonly property var day: Kit.section(item, "day")
    readonly property var people: Kit.section(item, "people")
    readonly property var place: Kit.section(item, "place")
    readonly property var person: Kit.section(item, "person")
    readonly property real startAt: Kit.timeOf(when.start ?? "")
    readonly property int length: Math.round((Kit.timeOf(when.end ?? "") - startAt) / 60000)
    readonly property var conflicts: strip.conflicts
    property Component detailsContent: people || person ? extra : null
    property Component actionsContent: actionsRow

    spacing: NotifDockState.px(Tokens.spacing.large)

    CardHead {
        Layout.fillWidth: true
        item: root.item
        unit: root.unit
        kind: root.item?.kind ?? ""
        status: root.head.text ?? ""
        statusIcon: root.head.icon ?? "event"
        tone: root.head.tone ?? ""
        hasDetails: root.detailsContent !== null
        detailsOpen: root.showDetails
        onToggleDetails: root.showDetails = !root.showDetails
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: NotifDockState.px(Tokens.spacing.large)

        // The day, as a calendar leaf.
        StyledClippingRect {
            implicitWidth: NotifDockState.px(58)
            implicitHeight: NotifDockState.px(62)
            radius: NotifDockState.px(Tokens.rounding.medium)
            color: Colours.palette.m3surfaceContainerHigh

            StyledRect {
                id: leafTop

                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: NotifDockState.px(20)
                color: Colours.palette.m3tertiary

                StyledText {
                    anchors.centerIn: parent
                    text: root.startAt ? ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][new Date(root.startAt).getDay()] : ""
                    font: NotifDockState.dfont(Tokens.font.label.builders.small.weight(Font.Bold).letterSpacing(1))
                    color: Colours.palette.m3onTertiary
                }
            }

            StyledText {
                anchors.top: leafTop.bottom
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                text: root.startAt ? new Date(root.startAt).getDate() : ""
                font: NotifDockState.dfont(Tokens.font.title.builders.large.size(Tokens.font.title.large.pointSize * NotifDockState.emph(1.1)).weight(Font.DemiBold))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: NotifDockState.px(4)

            StyledText {
                Layout.fillWidth: true
                text: root.item?.title ?? ""
                elide: Text.ElideRight
                font: NotifDockState.dfont(Tokens.font.title.builders.medium.size(Tokens.font.title.medium.pointSize * NotifDockState.emph(1.15)).weight(Font.DemiBold))
            }

            RowLayout {
                spacing: NotifDockState.px(Tokens.spacing.small)

                StyledText {
                    text: `${Kit.clock(root.when.start ?? "")} – ${Kit.clock(root.when.end ?? "")}`
                    font: NotifDockState.dfont(Tokens.font.title.builders.small.weight(Font.Medium))
                }

                Chip {
                    text: Kit.minutes(root.length)
                    icon: "timer"
                }

                Chip {
                    visible: !!root.place
                    text: root.place?.label ?? ""
                    icon: root.place?.kind === "meet" ? "videocam" : "location_on"
                    tone: "primary"
                }
            }
        }
    }

    // The hero: that day against your calendar.
    StyledRect {
        Layout.fillWidth: true
        visible: !!root.day
        implicitHeight: dayCol.implicitHeight + NotifDockState.px(Tokens.padding.medium) * 2
        radius: NotifDockState.px(Tokens.rounding.large)
        color: Colours.palette.m3surfaceContainerHigh

        ColumnLayout {
            id: dayCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: NotifDockState.px(Tokens.padding.medium)
            anchors.leftMargin: NotifDockState.px(Tokens.padding.large)
            anchors.rightMargin: NotifDockState.px(Tokens.padding.large)
            spacing: NotifDockState.px(Tokens.spacing.small)

            DayStrip {
                id: strip

                Layout.fillWidth: true
                from: root.day?.from ?? 9
                to: root.day?.to ?? 19
                events: root.day?.events ?? []
                slot: ({
                        title: root.item?.title ?? "",
                        start: root.when.start ?? "",
                        end: root.when.end ?? ""
                    })
                suggest: root.day?.suggest ?? null
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: NotifDockState.px(Tokens.spacing.small)

                MaterialIcon {
                    text: root.conflicts.length ? "warning" : "event_available"
                    fill: 1
                    color: root.conflicts.length ? Colours.palette.m3tertiary : Colours.palette.m3success
                    fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(11))
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.conflicts.length ? `Clashes with ${root.conflicts[0].title}` : "You're free then"
                    elide: Text.ElideRight
                    font: NotifDockState.dfont(Tokens.font.label.builders.large)
                    color: root.conflicts.length ? Colours.palette.m3tertiary : Colours.palette.m3success
                }

                ActionGroup {
                    item: root.item
                    unit: null
                    actions: (root.item?.actions ?? []).filter(a => a.role === "quiet")
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

            ActionGroup {
                Layout.fillWidth: true
                item: root.item
                unit: root.unit
                actions: (root.item?.actions ?? []).filter(a => a.role !== "quiet")
            }
        }
    }

    Component {
        id: extra

        Column {
            spacing: NotifDockState.px(Tokens.spacing.medium)

            StyledText {
                visible: !!root.person
                text: `${root.person?.name ?? ""} invited you`
                font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }

            Row {
                spacing: NotifDockState.px(Tokens.spacing.medium)

                FaceStack {
                    anchors.verticalCenter: parent.verticalCenter
                    people: root.people?.people ?? []
                    size: NotifDockState.px(32)
                    ring: Colours.palette.m3surfaceContainerHigh
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.people?.summary ?? ""
                    font: NotifDockState.dfont(Tokens.font.label.builders.large)
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Column {
                Repeater {
                    model: root.people?.people ?? []

                    StyledText {
                        required property var modelData

                        text: modelData.name ?? ""
                        font: NotifDockState.dfont(Tokens.font.body.builders.medium)
                    }
                }
            }
        }
    }
}
