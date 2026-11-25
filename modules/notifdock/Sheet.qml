pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "kit"
import "kit/kit.js" as Kit

// The revealed dock as a Material 3 list-detail sheet (layoutMode "sheet"):
// a drag handle; pill tabs per source with their counts, search, and a
// filter for what needs you (Actions) or is only news (Updates); then the
// list (an icon in a tonal circle, a title, one line, the time; the chosen
// one in a filled tonal container) and ONE item's detail beside it: its
// header, its v3 component with a small picture of what it's about, and a
// footer with the original email, Later and Mark read.
// Keys (once the dock has been clicked): ↑ ↓ move through the list, ← is
// Later, → or R is Mark read. Surfaces are tonal; nothing has an outline.
// Compact: every size here and in the kit goes through NotifDockState's
// px(), font()/dfont() and pad() (shell.json notifs.dockScale; 1 is about
// 990 x 480 px), and every button and tab stays at least 36 px tall. The
// detail scrolls; its action row and Later/Mark read stay pinned below.
FocusScope {
    id: root

    required property ScreenState screenState
    property real panelHeight: 640
    // Made once and kept (Wrapper.qml); shown while the dock is revealed.
    property bool shown

    // "all", "actions" or "updates" (the filter button); the tabs are
    // sources (NotifDockState.view: "all" or a source's name).
    property string lane: "all"
    property bool searching
    property string query
    property string selectedKey
    // Units whose detail is too tall beside the illustration (it hides for
    // them while the sheet is up): unit -> true.
    property var tightUnits: ({})

    readonly property var deck: NotifDockState.deckOf(NotifDockState.view)
    readonly property var list: deck.filter(u => (lane === "all" || (lane === "actions") === (NotifDockState.laneOf(u.items[0]) === "action")) && matches(u))
    readonly property var selected: list.find(u => u.unit === selectedKey) ?? list[0] ?? null
    readonly property var item: selected?.items[0] ?? null
    // 280 px at dockScale 1, and never more than 30% of the sheet.
    readonly property real listWidth: Math.round(Math.min(width * 0.3, 280 * NotifDockState.dockScale))
    // Tabs, the search field and buttons: Material's compact height, never
    // under 36 px.
    readonly property real controlHeight: Math.max(NotifDockState.minHit, NotifDockState.px(44))

    // The unit the detail shows: the selected one, except while a cross-fade
    // holds it (below), so building the next item's detail never lands in
    // the middle of the list's animation.
    property string detailKey
    property bool holdDetail

    onSelectedChanged: {
        NotifDockState.selection = selected?.unit ?? "";
        if (!holdDetail)
            detailKey = selected?.unit ?? "";
        tightCheck.restart();
    }

    function matches(unit: var): bool {
        if (!query)
            return true;
        const i = unit.items[0];
        return [i.title, i.subtitle, i.kind, i.source].join(" ").toLowerCase().includes(query.toLowerCase());
    }

    function select(index: int): void {
        const unit = list[Math.max(0, Math.min(list.length - 1, index))];
        selectedKey = unit?.unit ?? "";
        listView.positionViewAtIndex(Math.max(0, list.indexOf(unit)), ListView.Contain);
    }

    function step(delta: int): void {
        select(list.findIndex(u => u.unit === selected?.unit) + delta);
    }

    // Later: to the back of the list, unread; Mark read: gone. Either way
    // the next item takes its place in the detail.
    function later(): void {
        const unit = selected;
        if (!unit)
            return;
        crossFade(() => {
            const index = list.indexOf(unit);
            NotifDockState.later(unit);
            select(index);
        });
    }

    function markRead(): void {
        const unit = selected;
        if (!unit)
            return;
        crossFade(() => {
            const index = list.indexOf(unit);
            NotifDockState.markRead(unit);
            select(index);
        });
    }

    // The detail's cross-fade, for Later, Mark read and a completing
    // action (only the pane; the list row has its own transition):
    // 1. capture: a still of the pane as it is (ghost) goes over it;
    // 2. once that still is drawn (two frames), the change runs: the list
    //    animates at once, but the detail holds (holdDetail);
    // 3. when the list's animation is over (DefaultSpatial + 50 ms), the
    //    detail builds the next item, under the still, so the time that
    //    takes never stalls a moving frame;
    // 4. after the next frame, the still fades out (Anim, DefaultEffects).
    property var pendingChange: null
    property int framesToWait
    property string fadePhase    // "", "capture", "hold", "reveal"

    function crossFade(change: var): void {
        if (fadePhase === "capture")
            runPending();
        if (!shown || !pane.visible) {
            change();
            return;
        }
        if (fadePhase === "hold" || fadePhase === "reveal") {
            // The still is already up: change at once, and hold again.
            holdDetail = true;
            change();
            fadePhase = "hold";
            detailTimer.restart();
            return;
        }
        ghostFade.stop();
        ghost.opacity = 1;
        ghost.scheduleUpdate();
        framesToWait = 2;
        pendingChange = change;
        fadePhase = "capture";
        ghostGuard.restart();
    }

    function runPending(): void {
        const change = pendingChange;
        pendingChange = null;
        ghostGuard.stop();
        holdDetail = true;
        if (change)
            change();
        fadePhase = "hold";
        detailTimer.restart();
    }

    function revealDetail(): void {
        holdDetail = false;
        detailKey = selected?.unit ?? "";
        tightCheck.restart();
        framesToWait = 1;
        fadePhase = "reveal";
    }

    // Closed, or the sheet goes: everything lands at once, no still.
    function finishFade(): void {
        if (fadePhase === "capture")
            runPending();
        detailTimer.stop();
        holdDetail = false;
        detailKey = selected?.unit ?? "";
        fadePhase = "";
        ghostFade.stop();
        ghost.opacity = 0;
    }

    function stopSearch(): void {
        searching = false;
        query = "";
        NotifDockState.typing = false;
        root.forceActiveFocus();
    }

    // The list's symbol for an item, and the detail's picture.
    function iconOf(item: var): string {
        switch (item?.component) {
        case "DecisionPanel":
            return Kit.section(item, "question")?.icon ?? "shield";
        case "SchedulingPanel":
            return "event";
        case "DataTable":
            return item.symbol || "payments";
        case "StatusSummary":
            return Kit.section(item, "status")?.state === "failed" ? "error" : "check_circle";
        case "ReviewPanel":
            return "rate_review";
        case "CommentPanel":
            return "chat_bubble";
        default:
            return item?.symbol || "notifications";
        }
    }

    function intentOf(item: var): string {
        const kind = String(item?.kind ?? "").toLowerCase();
        switch (item?.component) {
        case "DecisionPanel":
            return "security";
        case "SchedulingPanel":
            return "calendar";
        case "DataTable":
            return "payment";
        case "StatusSummary":
            return "ci";
        case "ReviewPanel":
            return "review";
        case "CommentPanel":
            return "comment";
        case "Timeline":
            return item.symbol === "package_2" ? "delivery" : "ci";
        default:
            return /security|sign|login/.test(kind) ? "security" : /payment|bill|card/.test(kind) ? "payment" : "";
        }
    }

    function shortAge(iso: string): string {
        const t = Kit.timeOf(iso);
        if (!t)
            return "";
        const m = Math.max(0, Math.floor((NotifDockState.now - t) / 60000));
        return m < 1 ? qsTr("now") : m < 60 ? `${m}m` : m < 1440 ? `${Math.floor(m / 60)}h` : `${Math.floor(m / 1440)}d`;
    }

    implicitHeight: panelHeight

    Keys.onUpPressed: step(-1)
    Keys.onDownPressed: step(1)
    Keys.onLeftPressed: later()
    Keys.onRightPressed: markRead()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_R) {
            event.accepted = true;
            markRead();
        }
    }
    Keys.onEscapePressed: screenState.notifDock = false

    // Each time it is shown it starts as a newly made sheet did: the first
    // item (or the pinned one), no search, the All filter, the list and the
    // detail at the top, and the keyboard on it.
    function opened(): void {
        NotifDockState.deckOpen = true;
        searching = false;
        search.text = "";
        query = "";
        lane = "all";
        tightUnits = ({});
        finishFade();
        selectedKey = NotifDockState.pinned || "";
        detailKey = selected?.unit ?? "";
        listView.positionViewAtBeginning();
        card.toTop();
        if (card.content?.showDetails)
            card.content.showDetails = false;
        forceActiveFocus();
    }

    function closed(): void {
        // A change waiting on the cross-fade still happens.
        finishFade();
        NotifDockState.deckOpen = false;
        if (searching) {
            searching = false;
            search.text = "";
            query = "";
            NotifDockState.typing = false;
        }
    }

    onShownChanged: shown ? opened() : closed()

    Component.onCompleted: {
        NotifDockState.registerCard("__panel", root);
        // Built now (the sheet is made in the background), not on opening.
        detailKey = selected?.unit ?? "";
        if (shown)
            opened();
    }
    Component.onDestruction: {
        NotifDockState.forget(root);
        if (shown)
            closed();
    }

    Connections {
        function onFrameSwapped(): void {
            if (--root.framesToWait > 0)
                return;
            if (root.fadePhase === "capture") {
                root.runPending();
            } else if (root.fadePhase === "reveal") {
                root.fadePhase = "";
                ghostFade.restart();
            }
        }

        target: root.Window.window
        enabled: root.fadePhase === "capture" || root.fadePhase === "reveal"
    }

    // If no frame comes (hidden meanwhile), the change still runs.
    Timer {
        id: ghostGuard

        interval: 100
        onTriggered: {
            if (root.fadePhase === "capture")
                root.runPending();
        }
    }

    // The list's own animation (displaced/move: Anim, DefaultSpatial), then
    // the detail.
    Timer {
        id: detailTimer

        interval: Tokens.anim.durations.expressiveDefaultSpatial + 50
        onTriggered: root.revealDetail()
    }

    Connections {
        // An item's action completed it: gone, and the next one shows.
        function onCompleted(unit: string): void {
            // Already out of the list (Mark read hid it at once; this is
            // Junco's answer coming back): nothing to do, so the detail isn't
            // held again.
            if (!root.list.some(u => u.unit === unit))
                return;
            root.crossFade(() => {
                const target = NotifDockState.unitOf(unit);
                const index = root.list.findIndex(u => u.unit === unit);
                if (target)
                    NotifDockState.hide(target.items);
                root.select(Math.max(0, index));
            });
        }

        function onPinnedChanged(): void {
            if (NotifDockState.pinned)
                root.selectedKey = NotifDockState.pinned;
        }

        function onTypingChanged(): void {
            if (!NotifDockState.typing && !root.searching)
                root.forceActiveFocus();
        }

        target: NotifDockState
    }

    // The drag handle.
    StyledRect {
        anchors.top: parent.top
        anchors.topMargin: NotifDockState.px(Tokens.padding.medium)
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: NotifDockState.px(36)
        implicitHeight: NotifDockState.px(4)
        radius: NotifDockState.px(2)
        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.4)
    }

    // Tabs per source, then search and the filter.
    RowLayout {
        id: top

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: NotifDockState.px(Tokens.padding.large + 12)
        anchors.leftMargin: NotifDockState.px(Tokens.padding.large + 8)
        anchors.rightMargin: NotifDockState.px(Tokens.padding.large + 8)
        spacing: NotifDockState.px(Tokens.spacing.small)

        // Tabs per source; they scroll sideways when there are many.
        ListView {
            id: tabs

            Layout.fillWidth: true
            implicitHeight: root.controlHeight
            orientation: ListView.Horizontal
            spacing: NotifDockState.px(Tokens.spacing.small)

            add: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    from: 0
                    to: 1
                }
            }

            remove: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 0
                }
            }

            displaced: Transition {
                Anim {
                    property: "x"
                }
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 1
                }
            }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width

            model: ScriptModel {
                values: ["all", ...NotifDockState.sources.map(s => s.source)]
            }

            delegate: StyledRect {
                id: tab

                required property string modelData

                readonly property bool active: NotifDockState.view === modelData
                readonly property var info: NotifDockState.sources.find(s => s.source === modelData) ?? null
                readonly property var first: info?.units[0]?.items[0] ?? null
                readonly property int count: modelData === "all" ? NotifDockState.units.length : (info?.units.length ?? 0)

                implicitWidth: tabRow.implicitWidth + NotifDockState.px(Tokens.padding.large) * 2
                implicitHeight: root.controlHeight
                radius: NotifDockState.px(Tokens.rounding.full)
                color: active ? Colours.palette.m3secondaryContainer : "transparent"

                StateLayer {
                    radius: NotifDockState.px(Tokens.rounding.full)
                    color: tab.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    onClicked: NotifDockState.view = tab.modelData
                }

                Row {
                    id: tabRow

                    anchors.centerIn: parent
                    spacing: NotifDockState.px(Tokens.spacing.small)

                    SourceBadge {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tab.modelData !== "all"
                        size: NotifDockState.px(26)
                        color: "transparent"
                        icon: tab.first?.icon ?? ""
                        symbol: tab.first?.symbol ?? "inbox"
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData === "all" ? qsTr("All") : tab.modelData
                        font: NotifDockState.font(Tokens.font.title.builders.small.weight(tab.active ? Font.DemiBold : Font.Medium))
                        color: tab.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    }

                    StyledRect {
                        anchors.verticalCenter: parent.verticalCenter
                        // At least two digits wide, so a count ticking 9 to 10
                        // (or back) doesn't move the tabs.
                        implicitWidth: Math.max(implicitHeight, Math.max(countText.implicitWidth, twoDigits.width) + NotifDockState.px(12))
                        implicitHeight: NotifDockState.px(22)
                        radius: NotifDockState.px(Tokens.rounding.full)
                        color: tab.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3surfaceContainerHighest

                        TextMetrics {
                            id: twoDigits

                            font: countText.font
                            text: "88"
                        }

                        StyledText {
                            id: countText

                            anchors.centerIn: parent
                            text: tab.count
                            font: NotifDockState.font(Tokens.font.label.builders.medium.weight(Font.Bold))
                            color: tab.active ? Colours.palette.m3secondaryContainer : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        // Search: types into the list's filter (the keyboard is the dock's
        // while it's open).
        StyledRect {
            visible: root.searching
            implicitWidth: NotifDockState.px(260)
            implicitHeight: root.controlHeight
            radius: NotifDockState.px(Tokens.rounding.full)
            color: Colours.palette.m3surfaceContainerHigh

            T.TextField {
                id: search

                anchors.fill: parent
                anchors.leftMargin: NotifDockState.px(Tokens.padding.large)
                anchors.rightMargin: NotifDockState.px(Tokens.padding.large)
                verticalAlignment: TextInput.AlignVCenter
                color: Colours.palette.m3onSurface
                font: NotifDockState.font(Tokens.font.body.builders.medium)
                onTextChanged: root.query = text
                Keys.onEscapePressed: root.stopSearch()
                Keys.onUpPressed: root.step(-1)
                Keys.onDownPressed: root.step(1)
            }

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: NotifDockState.px(Tokens.padding.large)
                visible: !search.text
                text: qsTr("Search")
                font: NotifDockState.font(Tokens.font.body.builders.medium)
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        IconButton {
            type: IconButton.Text
            icon: root.searching ? "close" : "search"
            font: NotifDockState.font(Tokens.font.icon.builders.medium)
            padding: NotifDockState.pad(Tokens.padding.extraSmall / 2, label.implicitHeight)
            onClicked: {
                if (root.searching) {
                    root.stopSearch();
                } else {
                    root.searching = true;
                    NotifDockState.typing = true;
                    Qt.callLater(() => search.forceActiveFocus());
                }
            }
        }

        IconTextButton {
            type: TextButton.Text
            icon: "filter_list"
            text: root.lane === "actions" ? qsTr("Actions") : root.lane === "updates" ? qsTr("Updates") : qsTr("All")
            font: NotifDockState.font(Tokens.font.label.builders.large)
            horizontalPadding: NotifDockState.px(Tokens.padding.medium)
            verticalPadding: NotifDockState.pad(Tokens.padding.small, Math.max(label.implicitHeight, iconLabel.implicitHeight))
            inactiveOnColour: Colours.palette.m3onSurfaceVariant
            onClicked: root.lane = root.lane === "all" ? "actions" : root.lane === "actions" ? "updates" : "all"
        }
    }

    RowLayout {
        id: body

        anchors.top: top.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: NotifDockState.px(Tokens.spacing.large)
        anchors.bottomMargin: NotifDockState.px(Tokens.padding.large + 4)
        anchors.leftMargin: NotifDockState.px(Tokens.padding.large + 4)
        anchors.rightMargin: NotifDockState.px(Tokens.padding.large + 4)
        spacing: NotifDockState.px(Tokens.spacing.large)
        visible: root.list.length > 0

        ListView {
            id: listView

            Layout.preferredWidth: root.listWidth
            Layout.fillHeight: true
            clip: true
            spacing: NotifDockState.px(4)
            boundsBehavior: Flickable.StopAtBounds
            Component.onCompleted: NotifDockState.registerCard("__list", listView)
            Component.onDestruction: NotifDockState.forget(listView)

            // Rows: the one that goes fades, the rows below slide up into
            // its place; Later's move to the back slides (the launcher
            // list's transitions and tokens).
            add: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    from: 0
                    to: 1
                }
            }

            remove: Transition {
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 0
                }
            }

            move: Transition {
                Anim {
                    property: "y"
                }
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 1
                }
            }

            displaced: Transition {
                Anim {
                    property: "y"
                }
                Anim {
                    type: Anim.DefaultEffects
                    property: "opacity"
                    to: 1
                }
            }

            model: ScriptModel {
                values: root.list.map(u => u.unit)
            }

            delegate: Item {
                id: row

                required property string modelData

                readonly property var unit: NotifDockState.unitOf(modelData)
                readonly property var item: unit?.items[0] ?? null
                readonly property bool active: root.selected?.unit === modelData

                width: ListView.view.width
                height: NotifDockState.px(80)

                StyledRect {
                    anchors.fill: parent
                    radius: NotifDockState.px(Tokens.rounding.large + 12)
                    color: row.active ? Colours.palette.m3secondaryContainer : "transparent"
                }

                StateLayer {
                    radius: NotifDockState.px(Tokens.rounding.large + 12)
                    color: row.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    onClicked: root.selectedKey = row.modelData
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: NotifDockState.px(Tokens.padding.large)
                    anchors.rightMargin: NotifDockState.px(Tokens.padding.large)
                    spacing: NotifDockState.px(Tokens.spacing.large)

                    StyledRect {
                        implicitWidth: NotifDockState.px(48)
                        implicitHeight: NotifDockState.px(48)
                        radius: NotifDockState.px(Tokens.rounding.full)
                        color: row.active ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.12) : Colours.palette.m3surfaceContainerHighest

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.iconOf(row.item)
                            color: row.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fontStyle: NotifDockState.font(Tokens.font.icon.builders.small.size(17))
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: NotifDockState.px(2)

                        StyledText {
                            Layout.fillWidth: true
                            text: row.item?.kind || row.unit?.label || ""
                            elide: Text.ElideRight
                            font: NotifDockState.font(Tokens.font.title.builders.small.weight(Font.DemiBold))
                            color: row.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: row.item?.title ?? ""
                            elide: Text.ElideRight
                            font: NotifDockState.font(Tokens.font.body.builders.medium)
                            color: row.active ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8) : Colours.palette.m3onSurfaceVariant
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: NotifDockState.px(16)
                        text: root.shortAge(row.item?.updated ?? "")
                        font: NotifDockState.font(Tokens.font.label.builders.large)
                        color: row.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        // The detail: one item.
        StyledRect {
            id: pane

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: NotifDockState.px(Tokens.rounding.large + 12)
            color: Colours.palette.m3surfaceContainer

            Component.onCompleted: NotifDockState.registerCard("__detail", pane)
            Component.onDestruction: NotifDockState.forget(pane)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: NotifDockState.px(Tokens.padding.large + 2)
                spacing: NotifDockState.px(Tokens.spacing.medium)

                // Where it's from, what kind, how long ago.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: NotifDockState.px(Tokens.spacing.medium)

                    SourceBadge {
                        size: NotifDockState.px(44)
                        radius: NotifDockState.px(Tokens.rounding.full)
                        icon: root.item?.icon ?? ""
                        symbol: root.item?.symbol ?? "inbox"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: root.item?.source ?? ""
                            font: NotifDockState.font(Tokens.font.title.builders.small.weight(Font.DemiBold))
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: [root.item?.kind ?? "", Kit.age(root.item?.updated ?? "", NotifDockState.now)].filter(s => s).join(" · ")
                            elide: Text.ElideRight
                            font: NotifDockState.font(Tokens.font.body.builders.small)
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    TextButton {
                        id: detailsButton

                        visible: !!card.content?.detailsContent
                        type: TextButton.Text
                        text: card.content?.showDetails ? qsTr("Less") : qsTr("Details")
                        font: NotifDockState.font(Tokens.font.label.builders.large)
                        horizontalPadding: NotifDockState.px(Tokens.padding.medium)
                        verticalPadding: NotifDockState.pad(Tokens.padding.small, label.implicitHeight)
                        onClicked: card.content.showDetails = !card.content.showDetails
                        Component.onCompleted: NotifDockState.registerButton("__sheet|details", detailsButton)
                        Component.onDestruction: NotifDockState.forget(detailsButton)
                    }

                    IconButton {
                        visible: !!root.item?.deckActions?.openJunco
                        type: IconButton.Text
                        icon: "open_in_new"
                        font: NotifDockState.font(Tokens.font.icon.builders.medium)
                        padding: NotifDockState.pad(Tokens.padding.extraSmall / 2, label.implicitHeight)
                        onClicked: NotifDockState.openInJunco(root.selected)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: NotifDockState.px(Tokens.spacing.extraLarge)

                    ItemCard {
                        id: card

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        flat: true
                        unitKey: root.detailKey
                        Component.onCompleted: NotifDockState.registerCard("__detailcard", card)
                        Component.onDestruction: NotifDockState.forget(card)
                        onScrollsChanged: tightCheck.restart()
                    }

                    // An item that has to scroll beside the illustration gets
                    // it out of the way (wider, its text wraps onto fewer
                    // lines). Decided once per item, after its layout has
                    // settled, so hiding it can't bring it straight back.
                    Timer {
                        id: tightCheck

                        interval: 60
                        onTriggered: {
                            const unit = root.detailKey;
                            if (unit && illustration.visible && card.scrolls)
                                root.tightUnits = Object.assign({}, root.tightUnits, {
                                    [unit]: true
                                });
                        }
                    }

                    // Smaller than the rest (NotifDockState.pxi), and hidden
                    // when space is tight: it must leave the item at least
                    // px(560) (420 px at dockScale 1) beside it, and the item
                    // must fit its height beside it (tightUnits).
                    Illustration {
                        id: illustration

                        readonly property real roomBeside: pane.width - 2 * NotifDockState.px(Tokens.padding.large + 8) - NotifDockState.px(Tokens.spacing.extraLarge) - implicitWidth

                        Layout.alignment: Qt.AlignTop
                        visible: roomBeside >= NotifDockState.px(560) && intent !== "" && !root.tightUnits[root.detailKey]
                        intent: root.intentOf(root.item)
                        good: Kit.section(root.item, "status")?.state === "passed"
                        Component.onCompleted: NotifDockState.registerCard("__illustration", illustration)
                        Component.onDestruction: NotifDockState.forget(illustration)
                    }
                }

                // The way back to the source, and the moves.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: NotifDockState.px(Tokens.spacing.small)

                    Link {
                        Layout.fillWidth: true
                        Layout.maximumWidth: implicitWidth
                        item: root.item
                        text: root.item?.original ? qsTr("View original email") : ""
                        url: root.item?.original?.url ?? ""
                        icon: "mail"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconTextButton {
                        id: laterButton

                        type: TextButton.Tonal
                        isRound: true
                        icon: "schedule"
                        text: qsTr("Later")
                        font: NotifDockState.font(Tokens.font.label.builders.large)
                        horizontalPadding: NotifDockState.px(Tokens.padding.large)
                        verticalPadding: NotifDockState.pad(Tokens.padding.small + 2, Math.max(label.implicitHeight, iconLabel.implicitHeight))
                        onClicked: root.later()
                        Component.onCompleted: NotifDockState.registerButton("__deck|later", laterButton)
                        Component.onDestruction: NotifDockState.forget(laterButton)
                    }

                    IconTextButton {
                        id: readButton

                        type: TextButton.Tonal
                        isRound: true
                        icon: "done_all"
                        text: qsTr("Mark read")
                        font: NotifDockState.font(Tokens.font.label.builders.large)
                        horizontalPadding: NotifDockState.px(Tokens.padding.large)
                        verticalPadding: NotifDockState.pad(Tokens.padding.small + 2, Math.max(label.implicitHeight, iconLabel.implicitHeight))
                        onClicked: root.markRead()
                        Component.onCompleted: NotifDockState.registerButton("__deck|read", readButton)
                        Component.onDestruction: NotifDockState.forget(readButton)
                    }
                }
            }
        }
    }

    // Nothing left (in this tab, or for this search).
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.list.length === 0
        spacing: NotifDockState.px(Tokens.spacing.medium)

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: NotifDockState.px(84)
            implicitHeight: NotifDockState.px(84)
            radius: NotifDockState.px(Tokens.rounding.full)
            color: Colours.palette.m3secondaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: root.query ? "search_off" : "done_all"
                color: Colours.palette.m3onSecondaryContainer
                fontStyle: NotifDockState.font(Tokens.font.icon.builders.small.size(30))
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.query ? qsTr("Nothing matches") : qsTr("All caught up")
            font: NotifDockState.font(Tokens.font.title.builders.large.weight(Font.DemiBold))
        }
    }

    // The detail pane's still for the cross-fade (crossFade above).
    ShaderEffectSource {
        id: ghost

        x: body.x + pane.x
        y: body.y + pane.y
        width: pane.width
        height: pane.height
        sourceItem: pane
        live: false
        hideSource: false
        opacity: 0
        visible: opacity > 0

        Anim {
            id: ghostFade

            target: ghost
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
    }
}
