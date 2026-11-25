pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import "kit"

// The revealed dock, v7: one card at a time, like catching up on a phone.
// The front card sits in the middle with the next three stacked behind it,
// each a little higher and smaller. Tabs above filter the deck (All /
// Actions / Updates, or a tab per source).
// - Later: drag the card left, ←, the Later button, or a sideways swipe
//   left. It goes to the back, unread.
// - Mark read: drag it right, → or R, or the button. It flies off and
//   comes back only if its work changes.
// - The card's own primary action (Yes, Approve, Accept, Reply...) also
//   completes it: it flies off once Junco says it's done.
// An empty deck says "All caught up".
FocusScope {
    id: root

    required property ScreenState screenState
    property real panelHeight: 600

    readonly property var deck: NotifDockState.deckOf(NotifDockState.view)
    readonly property var front: deck[0] ?? null
    readonly property real cardWidth: 600
    readonly property real peek: 14
    readonly property int behind: 3
    readonly property real cardHeight: stage.height - peek * behind
    // Distinct cards moved past since the deck opened (or the tab changed),
    // for "3 of 10".
    property var seen: ({})
    readonly property int seenCount: Object.keys(seen).length
    readonly property int total: {
        const all = Object.assign({}, seen);
        for (const unit of deck)
            all[unit.unit] = true;
        return Object.keys(all).length;
    }
    readonly property int position: Math.min(seenCount + 1, total)

    // The front card's sideways offset while dragged or flying.
    property real dragX
    property bool flying
    property var afterFly: null
    // What the flying card's hint says: Later, Mark read, or Done.
    property string flyHint

    function markSeen(key: string): void {
        if (seen[key])
            return;
        const next = Object.assign({}, seen);
        next[key] = true;
        seen = next;
    }

    // Fly the front card off to the left (-1) or right (+1), then do `then`.
    function fly(direction: int, then: var, hint: string): void {
        if (!front || flying)
            return;
        flying = true;
        flyHint = hint;
        markSeen(front.unit);
        afterFly = then;
        springBack.stop();
        flyOff.to = direction * (root.width / 2 + root.cardWidth);
        flyOff.restart();
    }

    function later(): void {
        const unit = front;
        fly(-1, () => NotifDockState.later(unit), "later");
    }

    function markRead(): void {
        const unit = front;
        fly(1, () => NotifDockState.markRead(unit), "read");
    }

    implicitHeight: panelHeight

    Component.onCompleted: {
        NotifDockState.deckOpen = true;
        NotifDockState.registerCard("__panel", root);
        forceActiveFocus();
    }
    Component.onDestruction: {
        NotifDockState.deckOpen = false;
        NotifDockState.forget(root);
    }

    Keys.onLeftPressed: later()
    Keys.onRightPressed: markRead()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_R) {
            event.accepted = true;
            markRead();
        }
    }
    Keys.onEscapePressed: screenState.notifDock = false

    Connections {
        // A card's action completed it: off it goes, then it's hidden.
        function onCompleted(unit: string): void {
            const target = NotifDockState.unitOf(unit);
            if (target && root.front?.unit === unit && !root.flying)
                root.fly(1, () => NotifDockState.hide(target.items), "done");
            else if (target)
                NotifDockState.hide(target.items);
        }

        function onViewChanged(): void {
            root.seen = {};
        }

        // A reply box closed: the deck takes the keys back.
        function onTypingChanged(): void {
            if (!NotifDockState.typing)
                root.forceActiveFocus();
        }

        target: NotifDockState
    }

    NumberAnimation {
        id: flyOff

        target: root
        property: "dragX"
        duration: 260
        easing.type: Easing.InCubic
        onFinished: {
            const then = root.afterFly;
            root.afterFly = null;
            if (then)
                then();
            root.dragX = 0;
            root.flying = false;
            root.flyHint = "";
        }
    }

    SpringAnimation {
        id: springBack

        target: root
        property: "dragX"
        to: 0
        spring: 4
        damping: 0.28
        epsilon: 0.5
    }

    // Tabs, and the way to Junco.
    RowLayout {
        id: top

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        LaneTabs {
            visible: NotifDockState.tabsMode !== "sources"
        }

        Row {
            visible: NotifDockState.tabsMode === "sources"
            spacing: 2

            SourceTab {
                label: qsTr("All")
                symbol: "inbox"
                count: NotifDockState.units.length
                active: NotifDockState.view === "all"
                onPicked: NotifDockState.view = "all"
            }

            Repeater {
                model: ScriptModel {
                    values: NotifDockState.sources.map(s => s.source)
                }

                SourceTab {
                    id: sourceTab

                    required property string modelData

                    readonly property var info: NotifDockState.sources.find(x => x.source === modelData) ?? null
                    readonly property var first: info?.units[0]?.items[0] ?? null

                    label: modelData
                    icon: first?.icon ?? ""
                    symbol: first?.symbol ?? "inbox"
                    count: info?.units.length ?? 0
                    critical: info?.critical ?? false
                    active: NotifDockState.view === modelData
                    onPicked: NotifDockState.view = sourceTab.modelData
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // The front card's mail in Junco (its `open-junco` action).
        IconTextButton {
            id: juncoButton

            visible: !!(root.front?.items ?? []).find(i => i.deckActions?.openJunco)
            type: TextButton.Tonal
            icon: "open_in_new"
            text: qsTr("Open in Junco")
            font: Tokens.font.label.large
            horizontalPadding: Tokens.padding.large
            verticalPadding: Tokens.padding.small + 2
            onClicked: NotifDockState.openInJunco(root.front)
            Component.onCompleted: NotifDockState.registerButton("__deck|junco", juncoButton)
            Component.onDestruction: NotifDockState.forget(juncoButton)
        }
    }

    // The deck: the front card and up to three behind it.
    Item {
        id: stage

        anchors.top: top.bottom
        anchors.bottom: controls.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.spacing.large
        anchors.bottomMargin: Tokens.spacing.large
        width: root.cardWidth

        Repeater {
            model: ScriptModel {
                values: root.deck.slice(0, root.behind + 1).map(u => u.unit)
            }

            Item {
                id: slot

                required property string modelData
                required property int index

                readonly property bool isFront: index === 0

                width: root.cardWidth
                height: root.cardHeight
                z: 10 - index
                y: root.peek * (root.behind - index)
                x: isFront ? root.dragX : 0
                scale: 1 - 0.045 * index
                transformOrigin: Item.Top
                opacity: index > root.behind - 1 ? 0.85 : 1
                // Dragged, the card tilts the way it goes, about a point
                // below it, like a card held at the bottom.
                transform: Rotation {
                    origin.x: slot.width / 2
                    origin.y: slot.height * 1.6
                    angle: slot.isFront ? root.dragX / root.cardWidth * 7 : 0
                }

                Behavior on y {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                Elevation {
                    anchors.fill: parent
                    radius: Tokens.rounding.large + 8
                    level: slot.isFront ? (root.dragX !== 0 ? 4 : 3) : 1
                    z: -1
                }

                ItemCard {
                    anchors.fill: parent
                    unitKey: slot.modelData
                    // Further back, darker; the next card's content still
                    // shows a little, the rest are plain surfaces.
                    shade: slot.index === 0 ? 0 : 0.28 + 0.16 * slot.index
                    // Only the front card takes clicks.
                    enabled: slot.isFront && !root.flying
                }

                // Which way the card goes, as it is dragged (or flies off).
                StyledRect {
                    id: hint

                    readonly property string kind: root.flyHint || (root.dragX < 0 ? "later" : "read")
                    readonly property color fill: kind === "later" ? Colours.palette.m3tertiary : kind === "done" ? Colours.palette.m3success : Colours.palette.m3primary
                    readonly property color ink: kind === "later" ? Colours.palette.m3onTertiary : kind === "done" ? Colours.palette.m3onSuccess : Colours.palette.m3onPrimary

                    anchors.top: parent.top
                    anchors.topMargin: 72
                    anchors.left: root.dragX > 0 ? parent.left : undefined
                    anchors.right: root.dragX < 0 ? parent.right : undefined
                    anchors.margins: Tokens.padding.large + 4
                    visible: slot.isFront && Math.abs(root.dragX) > 24
                    opacity: Math.min(1, (Math.abs(root.dragX) - 24) / 90)
                    implicitWidth: dragHint.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    color: fill

                    Row {
                        id: dragHint

                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hint.kind === "later" ? "schedule" : hint.kind === "done" ? "check" : "done_all"
                            color: hint.ink
                            fontStyle: Tokens.font.icon.builders.small.size(13).build()
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hint.kind === "later" ? qsTr("Later") : hint.kind === "done" ? qsTr("Done") : qsTr("Mark read")
                            font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                            color: hint.ink
                        }
                    }
                }

                DragHandler {
                    id: drag

                    enabled: slot.isFront && !root.flying && !NotifDockState.typing
                    target: null
                    yAxis.enabled: false
                    onActiveTranslationChanged: {
                        if (active)
                            root.dragX = activeTranslation.x;
                    }
                    onActiveChanged: {
                        if (active) {
                            springBack.stop();
                            return;
                        }
                        if (root.dragX < -110)
                            root.later();
                        else if (root.dragX > 110)
                            root.markRead();
                        else
                            springBack.restart();
                    }
                }
            }
        }

        // Nothing left in this deck.
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.deck.length === 0
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 84
                implicitHeight: 84
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3success, 0.14)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "done_all"
                    color: Colours.palette.m3success
                    fontStyle: Tokens.font.icon.builders.small.size(30).build()
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("All caught up")
                font: Tokens.font.title.builders.large.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: NotifDockState.view === "all" ? qsTr("New work will show up here.") : qsTr("Nothing left in this tab.")
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        // A sideways swipe or wheel: left is later, right is read.
        WheelHandler {
            property real spill

            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            orientation: Qt.Horizontal
            onWheel: event => {
                spill += event.angleDelta.x;
                if (Math.abs(spill) >= 120) {
                    if (spill > 0)
                        root.later();
                    else
                        root.markRead();
                    spill = 0;
                }
            }
        }
    }

    // Later, where we are, Mark read.
    RowLayout {
        id: controls

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        anchors.leftMargin: (root.width - root.cardWidth) / 2
        anchors.rightMargin: (root.width - root.cardWidth) / 2
        visible: root.deck.length > 0

        IconTextButton {
            id: laterButton

            type: TextButton.Tonal
            icon: "arrow_back"
            text: qsTr("Later")
            font: Tokens.font.label.large
            horizontalPadding: Tokens.padding.large
            verticalPadding: Tokens.padding.small + 2
            disabled: root.flying
            onClicked: root.later()
            Component.onCompleted: NotifDockState.registerButton("__deck|later", laterButton)
            Component.onDestruction: NotifDockState.forget(laterButton)
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("%1 of %2").arg(root.position).arg(root.total)
            font: Tokens.font.label.builders.large.weight(Font.Medium).build()
            color: Colours.palette.m3onSurfaceVariant
        }

        IconTextButton {
            id: readButton

            type: TextButton.Tonal
            icon: "done_all"
            text: qsTr("Mark read")
            font: Tokens.font.label.large
            horizontalPadding: Tokens.padding.large
            verticalPadding: Tokens.padding.small + 2
            disabled: root.flying
            onClicked: root.markRead()
            Component.onCompleted: NotifDockState.registerButton("__deck|read", readButton)
            Component.onDestruction: NotifDockState.forget(readButton)
        }
    }
}
