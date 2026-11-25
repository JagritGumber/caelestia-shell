pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import "kit.js" as Kit

// One unit of work in the deck: a card surface, and inside it the
// component its newest item names (contract v3; v1 and v2 items arrive
// already mapped, kit/adapt.js), filled with that item. Unknown components
// fall back to Summary. The head's coloured line comes from the item's
// badge, else its due time, else its age. A component may keep more behind
// "Details" (showDetails, detailsContent).
// The card is a plain surface: no outline, ever. Depth in the deck comes
// from its shadow (Deck) and from `shade`: a card further back takes a
// darker surface of its own and its content fades, so nothing is laid over
// it and no edge can show.
StyledRect {
    id: root

    required property string unitKey
    // 0 for the front card, towards 1 further back.
    property real shade
    // In the sheet's detail pane: no surface of its own, no margins.
    property bool flat
    // The component in it (its showDetails, detailsContent, actionsContent).
    readonly property alias content: panel.item
    // In the sheet's detail (flat, compact): the component scrolls, with a
    // subtle bar at its right edge, and its action row (actionsContent) is
    // pinned under it. In the deck it fills the card as before.
    readonly property bool pinActions: flat && NotifDockState.compact
    // Taller than its room: it scrolls.
    readonly property bool scrolls: !!panel.item && panel.height > scroller.height + 1

    readonly property var unit: NotifDockState.unitOf(unitKey)
    readonly property var item: unit?.items[0] ?? null
    readonly property string section: NotifDockState.sectionOf(item)
    readonly property var head: {
        const now = NotifDockState.now;
        const badge = item?.badge;
        if (badge?.text)
            return {
                text: badge.text,
                icon: badge.icon ?? "info",
                tone: badge.tone ?? ""
            };
        if (item?.due)
            return {
                text: Kit.due(item.due, now),
                icon: section === "overdue" ? "event_busy" : "event",
                tone: section === "overdue" ? "tertiary" : "primary"
            };
        // The one urgency accent, the same on every kind: a critical item's
        // age in the scheme's tertiary accent (never the error colour).
        const critical = item?.urgency === "critical";
        return {
            text: Kit.age(item?.updated ?? "", now),
            icon: critical ? "priority_high" : "schedule",
            tone: critical ? "tertiary" : ""
        };
    }

    radius: NotifDockState.px(Tokens.rounding.large + 8)
    color: flat ? "transparent" : Qt.tint(Colours.palette.m3surfaceContainer, Qt.alpha(Colours.palette.m3surface, shade))
    clip: true

    Behavior on shade {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // In the deck, each card stays with its unit; the sheet's one detail card
    // changes unit, and registers itself as "__detailcard" (Sheet.qml).
    Component.onCompleted: {
        if (!flat)
            NotifDockState.registerCard(unitKey, root);
    }
    Component.onDestruction: NotifDockState.forget(root)

    onUnitKeyChanged: scroller.contentY = 0

    // Back to the top (the sheet, each time it is shown).
    function toTop(): void {
        scroller.contentY = 0;
    }

    StyledFlickable {
        id: scroller

        readonly property real inset: root.flat ? 0 : NotifDockState.px(Tokens.padding.large + 4)

        anchors.fill: parent
        anchors.margins: inset
        anchors.bottomMargin: pinned.active ? pinned.height + NotifDockState.px(Tokens.spacing.medium) : inset
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: panel.height
        interactive: root.pinActions && root.scrolls
        clip: root.pinActions

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: scroller
            visible: root.pinActions
        }

        Loader {
            id: panel

            // In the sheet it is as tall as its content (its actions are
            // pinned outside, so nothing needs pushing down); reading its
            // own implicitHeight here made a binding loop when the item
            // changed. In the deck it fills the card.
            width: scroller.width
            height: root.pinActions ? undefined : scroller.height
            opacity: 1 - Math.min(1, root.shade * 1.6)
            visible: opacity > 0
            active: !!root.item
            sourceComponent: {
                switch (root.item?.component) {
                case "DecisionPanel":
                    return decision;
                case "ReviewPanel":
                    return review;
                case "SchedulingPanel":
                    return scheduling;
                case "StatusSummary":
                    return status;
                case "CommentPanel":
                    return comment;
                case "Timeline":
                    return timeline;
                case "DataTable":
                    return table;
                default:
                    return summary;
                }
            }
        }
    }

    // The sheet: the item's action row, pinned at the bottom of the detail.
    Loader {
        id: pinned

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        active: root.pinActions && !!panel.item?.actionsContent
        visible: active
        sourceComponent: panel.item?.actionsContent ?? null
    }

    // "Details": the component's secondary content, over its lower part.
    DetailsSheet {
        open: panel.item?.showDetails ?? false
        content: panel.item?.detailsContent ?? null
        sheetTop: root.flat ? 0 : 56
    }

    Component {
        id: decision

        DecisionPanel {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }

    Component {
        id: review

        ReviewPanel {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }

    Component {
        id: scheduling

        SchedulingPanel {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }

    Component {
        id: status

        StatusSummary {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }

    Component {
        id: comment

        CommentPanel {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }

    Component {
        id: timeline

        Timeline {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }

    Component {
        id: table

        DataTable {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }

    Component {
        id: summary

        Summary {
            item: root.item
            unit: root.unit
            head: root.head
        }
    }
}
