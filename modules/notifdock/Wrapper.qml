pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// The notification dock at the bottom, like macOS's auto-hiding dock, for
// Junco's work items (NotifDockState). While any are open, a thin sliver
// with a plain line in his accent peeks out of the bottom border, under the
// panel's left part. Resting the pointer on the bottom edge there
// (dockRevealDelay) brings it up: the sheet (Sheet.qml) or a deck of cards,
// one at a time (Deck.qml). It hides again when the pointer leaves, but never
// while a reply is being typed, and it stays to say "All caught up" when the
// last card goes. Revealing it marks nothing. Its background is a drawer
// blob, and while it is hidden only the sliver and the border take input. It
// hides the moment the pointer leaves it, like the dashboard. No glow, halo
// or pulse: the line alone says there is work.
// While Wispr Flow's bars show along the bottom edge (its glow layer, which
// takes no input), the dock still works: the sliver's line rests so the two
// don't clash, and the open panel is drawn above the bars (ContentWindow).
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    // Set by the drawers window: a fullscreen window on this screen.
    property bool fullscreen
    // Set by drawers/Interactions.qml: the pointer is on the bottom edge,
    // between zoneLeft and zoneRight.
    property bool pointerAtEdge
    // Set by drawers/Interactions.qml: the pointer is over the panel's area
    // (with the border under it).
    property bool pointerInPanel

    // v7: the panel holds one deck of cards, centred at the bottom like a
    // dock, a little over half the screen high.
    // The sheet (layoutMode "sheet") sits in the bottom-left corner, flush
    // with the bar and the bottom border, as Caelestia's drawers sit flush
    // in theirs (utilities, mirrored, in the bottom-right). It is compact:
    // 990 x 480 px times shell.json's notifs.dockScale (NotifDockState), but
    // never wider than the room left of the utilities corner minus 60 px (so
    // it stays clear of that corner's hover zone), nor over 80% of the
    // screen high.
    readonly property bool sheet: NotifDockState.layoutMode === "sheet"
    readonly property real sheetRoom: Math.max(0, (parent?.width ?? 0) - Tokens.sizes.utilities.width - 40 - (Tokens.padding.large + 4))
    readonly property real panelWidth: sheet ? Math.min(sheetRoom, Math.round(990 * NotifDockState.dockScale)) : 680
    readonly property real panelLeft: sheet ? 0 : Math.round(((parent?.width ?? 0) - panelWidth) / 2)
    readonly property real panelRight: panelLeft + panelWidth
    readonly property real panelHeight: sheet ? Math.round(Math.min((screen?.height ?? 0) * 0.8, 480 * NotifDockState.dockScale)) : Math.round((screen?.height ?? 0) * 0.58)
    // The bottom edge that reveals it: for the sheet, only under its left
    // third (so the middle of the bottom edge never opens it by accident);
    // for the deck, its whole span.
    readonly property real leftPart: Math.round(panelWidth / 3)
    readonly property real zoneLeft: panelLeft
    readonly property real zoneRight: sheet ? panelLeft + leftPart : panelRight
    readonly property real sliverHeight: 5
    readonly property real sliverWidth: Math.min(260, 96 + 24 * NotifDockState.units.length)
    // The sliver: in the middle of the reveal zone.
    readonly property real sliverX: Math.round((zoneLeft + zoneRight - sliverWidth) / 2)

    // The focused monitor only.
    readonly property bool onFocusedMonitor: !!screen && !!Hypr.focusedMonitor && Hypr.monitorFor(screen) === Hypr.focusedMonitor
    readonly property bool blocked: !NotifDockState.enabled || Notifs.dnd || fullscreen || !onFocusedMonitor || (screenState?.launcher ?? true) || (screenState?.session ?? true)
    readonly property bool hasWork: NotifDockState.units.length > 0
    readonly property bool showSliver: hasWork && !blocked
    // The last card went while the deck was open: it stays up to say "All
    // caught up" until the pointer leaves.
    property bool caughtUp
    readonly property bool revealed: (screenState?.notifDock ?? false) && !blocked && (hasWork || caughtUp)
    readonly property bool critical: NotifDockState.critical
    // The sliver's line: his scheme's accent, primary leaning a little to
    // tertiary, as Caelestia's own accents look. Never the error colour: a
    // critical item only makes the line a little brighter.
    readonly property color accent: Qt.tint(Colours.palette.m3primary, Qt.alpha(Colours.palette.m3tertiary, 0.3))
    // Wispr's bars are up: the sliver's line rests under them.
    readonly property bool quiet: NotifDockState.bottomEdgeBusy

    property real offsetScale: showSliver || revealed ? 0 : 1
    // How far it has opened, 0 (the sliver) to 1 (the whole panel): the
    // content's opacity, so it fades with the geometry's own animation (Anim,
    // DefaultSpatial), as the dashboard's content fades with its offsetScale.
    readonly property real openProgress: Math.max(0, Math.min(1, (implicitHeight - sliverHeight) / Math.max(1, panelHeight - sliverHeight)))

    // Gone the moment the pointer is neither over the panel nor on the edge.
    function hideSoon(): void {
        if (revealed && !pointerAtEdge && !pointerInPanel && !NotifDockState.typing)
            screenState.notifDock = false;
        else if (revealed && !pointerAtEdge && !hover.hovered && !NotifDockState.typing)
            leaveTimer.restart();
    }

    onPointerInPanelChanged: {
        if (!pointerInPanel)
            hideSoon();
    }

    onHasWorkChanged: {
        if (!hasWork && (screenState?.notifDock ?? false))
            caughtUp = true;
    }

    onPointerAtEdgeChanged: {
        if (pointerAtEdge) {
            leaveTimer.stop();
            // After NotifDockState.revealDelay (50 ms by default, so a
            // pointer only touching the edge doesn't open it); at once when
            // shell.json sets dockRevealDelay to 0, as the dashboard opens.
            if (!revealed && showSliver) {
                if (NotifDockState.revealDelay > 0)
                    dwellTimer.restart();
                else
                    screenState.notifDock = true;
            }
        } else {
            dwellTimer.stop();
            hideSoon();
        }
    }

    // Shown some other way (the shortcut, IPC): it still goes when ignored.
    onRevealedChanged: {
        if (revealed && !pointerAtEdge && !hover.hovered && !NotifDockState.typing)
            idleTimer.restart();
        if (!revealed && screenState?.notifDock)
            screenState.notifDock = false;
        if (!revealed)
            caughtUp = false;
    }

    visible: offsetScale < 1
    clip: true
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    // The sliver in the reveal zone; the panel from panelLeft.
    x: revealed ? panelLeft : sliverX
    implicitWidth: revealed ? panelWidth : sliverWidth
    implicitHeight: revealed ? panelHeight : sliverHeight

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        Anim {}
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                leaveTimer.stop();
                idleTimer.stop();
            } else {
                root.hideSoon();
            }
        }
    }

    Timer {
        id: dwellTimer

        interval: NotifDockState.revealDelay
        onTriggered: {
            if (root.pointerAtEdge && root.showSliver)
                root.screenState.notifDock = true;
        }
    }

    // A grace for the hover handler only, when the pointer crosses between
    // the panel and the border; the geometry check above closes it at once.
    Timer {
        id: leaveTimer

        interval: 100
        onTriggered: {
            if (!root.pointerAtEdge && !root.pointerInPanel && !hover.hovered && !NotifDockState.typing)
                root.screenState.notifDock = false;
        }
    }

    Timer {
        id: idleTimer

        interval: 4000
        onTriggered: {
            if (!root.pointerAtEdge && !hover.hovered && !NotifDockState.typing)
                root.screenState.notifDock = false;
        }
    }

    Connections {
        // A reply box closed: hide if the pointer has gone meanwhile.
        function onTypingChanged(): void {
            if (!NotifDockState.typing)
                root.hideSoon();
        }

        target: NotifDockState
    }

    Connections {
        // The launcher shares the bottom centre; the dashboard drops over it.
        function onLauncherChanged(): void {
            if (root.screenState.launcher)
                root.screenState.notifDock = false;
        }

        function onDashboardChanged(): void {
            if (root.screenState.dashboard)
                root.screenState.notifDock = false;
        }

        target: root.screenState
    }

    // The sliver's line: a thin plain line along its top, in the accent;
    // a critical item makes it a little brighter.
    StyledRect {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 1
        implicitWidth: Math.max(0, root.sliverWidth - 44)
        implicitHeight: 2
        radius: 1
        color: root.accent
        opacity: root.revealed || root.quiet ? 0 : (root.critical ? 1 : 0.8) * (1 - root.offsetScale)

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        // The sheet is made once, in the background when the shell starts,
        // and kept: opening it costs only its animation (made on reveal, it
        // took ~300 ms in the rig before the first frame). If it is opened
        // before it is ready, it is finished at once. The deck is still made
        // when it opens.
        active: root.sheet || root.revealed || root.implicitHeight > root.sliverHeight + 1
        asynchronous: !root.revealed
        opacity: root.openProgress
        visible: opacity > 0
        sourceComponent: root.sheet ? sheetView : deckView
    }

    Component {
        id: deckView

        Deck {
            screenState: root.screenState
            implicitWidth: root.panelWidth
            panelHeight: root.panelHeight
        }
    }

    Component {
        id: sheetView

        Sheet {
            screenState: root.screenState
            shown: root.revealed
            implicitWidth: root.panelWidth
            panelHeight: root.panelHeight
        }
    }
}
