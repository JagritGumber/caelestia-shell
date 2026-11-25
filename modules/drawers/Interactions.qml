import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts
import "../bar/TrayIntent.js" as TrayIntent

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property ScreenState screenState
    required property Panels panels
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool osdShortcutActive
    property bool utilitiesShortcutActive
    property point previousPointer: Qt.point(-1, -1)
    property double previousPointerTime
    property point trayAimOrigin: Qt.point(-1, -1)
    property string trayAimMenuName
    property real pendingPopoutY: -1
    property string pendingPopoutName

    function cancelPendingPopout(): void {
        hoverIntentTimer.stop();
        pendingPopoutY = -1;
        pendingPopoutName = "";
    }

    function scheduleHoveredPopout(y: real, name: string, delay: int): void {
        if (!name) {
            cancelPendingPopout();
            return;
        }

        const candidateChanged = pendingPopoutName !== name;
        pendingPopoutY = y;
        pendingPopoutName = name;
        hoverIntentTimer.interval = delay;
        if (candidateChanged || !hoverIntentTimer.running)
            hoverIntentTimer.restart();
    }

    function activateHoveredPopout(y: real): void {
        cancelPendingPopout();
        bar.checkPopout(y);
        if (popouts.hasCurrent && TrayIntent.isTrayMenu(popouts.currentName) && popouts.currentName !== trayAimMenuName) {
            trayAimMenuName = popouts.currentName;
            trayAimOrigin = Qt.point(mouseX, mouseY);
        }
    }

    function considerHoveredPopout(y: real, pointer: point, elapsedMs: real): void {
        const candidate = bar.popoutNameAt(y);
        if (!candidate || candidate === popouts.currentName || !TrayIntent.shouldDelayActivation(previousPointer, pointer, elapsedMs)) {
            activateHoveredPopout(y);
            return;
        }

        scheduleHoveredPopout(y, candidate, 70);
    }

    function considerCorridorSwitch(y: real): void {
        const candidate = bar.popoutNameAt(y);
        if (TrayIntent.shouldQueueCorridorSwitch(popouts.currentName, candidate, true))
            scheduleHoveredPopout(y, candidate, 180);
        else
            cancelPendingPopout();
    }

    function inTrayAimCorridor(pointer: point): bool {
        return popouts.hasCurrent && TrayIntent.shouldPreserveOpenMenu(popouts.currentName, trayAimMenuName, trayAimOrigin, pointer, {
            left: bar.implicitWidth + panels.popoutsWrapper.x,
            top: borderThickness + panels.popoutsWrapper.y,
            bottom: borderThickness + panels.popoutsWrapper.y + panels.popoutsWrapper.height
        });
    }

    function closeTransientPopout(): void {
        popouts.hasCurrent = false;
        bar.closeTray();
    }

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = root.borderThickness + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.implicitWidth + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < bar.implicitWidth + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panel.x) && withinPanelHeight(panel, x, y);
    }

    // The dock's whole panel when revealed, with the border under it: its
    // target geometry (Wrapper's panelLeft/Right/Height), not its animation,
    // and the bar's rounding as margin, as for the dashboard.
    function inDock(x: real, y: real): bool {
        const dock = panels.notifDock;
        const left = bar.implicitWidth + dock.panelLeft - Config.border.rounding;
        const right = bar.implicitWidth + dock.panelRight + Config.border.rounding;
        return x >= left && x <= right && y >= height - borderThickness - dock.panelHeight - Config.border.rounding;
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y < Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y > height - Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) - (isCorner ? Config.border.rounding : 0) && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (fullscreen)
            return;
        if (event.x < bar.implicitWidth) {
            bar.handleWheel(event.y, event.angleDelta);
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true

    Timer {
        id: hoverIntentTimer

        interval: 70
        onTriggered: {
            if (root.pendingPopoutY >= 0
                    && root.mouseX < root.bar.implicitWidth
                    && root.bar.popoutNameAt(root.pendingPopoutY) === root.pendingPopoutName)
                root.activateHoveredPopout(root.pendingPopoutY);
            else
                root.cancelPendingPopout();
        }
    }

    Timer {
        id: trayLeaveTimer

        interval: 140
        onTriggered: {
            if (!root.containsMouse)
                root.closeTransientPopout();
        }
    }

    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: {
        if (containsMouse) {
            trayLeaveTimer.stop();
            return;
        }

        panels.notifDock.pointerInPanel = false;
        panels.notifDock.pointerAtEdge = false;

        // Only hide if not activated by shortcut
        if (!osdShortcutActive) {
            screenState.osd = false;
            root.panels.osd.hovered = false;
        }

        if (!dashboardShortcutActive)
            screenState.dashboard = false;

        if (!utilitiesShortcutActive)
            screenState.utilities = false;

        const menuDepth = (popouts.current as StackView)?.depth ?? 0;
        if (TrayIntent.shouldDeferLeave(popouts.hasCurrent, popouts.currentName, menuDepth))
            trayLeaveTimer.restart();
        else if (!TrayIntent.isTrayMenu(popouts.currentName) || menuDepth <= 1)
            closeTransientPopout();

        if (Config.bar.showOnHover)
            bar.isHovered = false;

        if (Config.sidebar.showOnHover)
            screenState.sidebar = false;
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const pointer = Qt.point(x, y);
        const now = Date.now();
        const elapsedMs = previousPointerTime > 0 ? now - previousPointerTime : 0;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (fullscreen) {
            root.panels.osd.hovered = inRightPanel(panels.osdWrapper, x, y);
            return;
        }

        // The notification dock: the bottom edge along its span brings up
        // its panel after a short rest there (modules/notifdock/Wrapper.qml).
        // Leaving its panel closes it at once, as leaving the dashboard does
        // (Wrapper.pointerInPanel); set first, so crossing between the
        // panel and the edge never looks like leaving.
        const dock = panels.notifDock;
        dock.pointerInPanel = inDock(x, y);
        dock.pointerAtEdge = y >= height - Math.max(Config.border.minThickness, borderThickness) && x >= bar.implicitWidth + dock.zoneLeft && x <= bar.implicitWidth + dock.zoneRight;

        // Show bar in non-exclusive mode on hover
        if (!screenState.bar && Config.bar.showOnHover && x < bar.clampedWidth)
            bar.isHovered = true;

        // Show/hide bar on drag
        if (pressed && dragStart.x < bar.clampedWidth) {
            if (dragX > Config.bar.dragThreshold)
                screenState.bar = true;
            else if (dragX < -Config.bar.dragThreshold)
                screenState.bar = false;
        }

        if (panels.sidebar.offsetScale === 1) {
            // Show osd on hover
            const showOsd = inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                screenState.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            const showSidebar = pressed && dragStart.x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x);

            // Show sidebar on hover (top-right corner, bounded by notification panel height)
            if (Config.sidebar.showOnHover) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifications.y + panels.notifications.height + borderThickness);
                const showSidebarHover = x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar)
                    screenState.sidebar = true;
            }

            // Show/hide session on drag
            if (pressed && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    screenState.session = true;
                else if (dragX > Config.session.dragThreshold)
                    screenState.session = false;

                // Show sidebar on drag if in session area and session is nearly fully visible
                if (showSidebar && panels.session.offsetScale <= 0 && dragX < -Config.sidebar.dragThreshold)
                    screenState.sidebar = true;
            } else if (showSidebar && dragX < -Config.sidebar.dragThreshold) {
                // Show sidebar on drag if not in session area
                screenState.sidebar = true;
            }
        } else {
            const outOfSidebar = x < width - panels.sidebar.width * (1 - panels.sidebar.offsetScale);
            // Show osd on hover
            const showOsd = outOfSidebar && inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                screenState.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            // Show/hide session on drag
            if (pressed && outOfSidebar && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    screenState.session = true;
                else if (dragX > Config.session.dragThreshold)
                    screenState.session = false;
            }

            // Show/hide sidebar on hover
            if (Config.sidebar.showOnHover && !pressed) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifications.y + panels.notifications.height + borderThickness);
                const showSidebarHover = x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar) {
                    screenState.sidebar = true;
                } else {
                    const inSidebarArea = inRightPanel(panels.sidebar, x, y) || inRightPanel(panels.sessionWrapper, x, y);
                    if (!inSidebarArea)
                        screenState.sidebar = false;
                }
            }

            // Hide sidebar on drag
            if (pressed && inRightPanel(panels.sidebar, dragStart.x, 0) && dragX > Config.sidebar.dragThreshold)
                screenState.sidebar = false;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            if (!screenState.launcher && inBottomPanel(panels.launcher, x, y))
                screenState.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                screenState.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                screenState.launcher = false;
        }

        // Show dashboard on hover
        const showDashboard = Config.dashboard.showOnHover && inTopPanel(panels.dashboard, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!dashboardShortcutActive) {
            screenState.dashboard = showDashboard;
        } else if (showDashboard) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                screenState.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                screenState.dashboard = false;
        }

        // Show utilities on hover
        const showUtilities = inBottomPanel(panels.utilities, x, y, true);

        // Always update visibility based on hover if not in shortcut mode
        if (!utilitiesShortcutActive) {
            screenState.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            utilitiesShortcutActive = false;
        }

        // Show popouts on hover
        if (inTrayAimCorridor(pointer)) {
            if (x < bar.implicitWidth)
                considerCorridorSwitch(y);
            else
                cancelPendingPopout();
        } else if (x < bar.implicitWidth) {
            considerHoveredPopout(y, pointer, elapsedMs);
        } else if ((!TrayIntent.isTrayMenu(popouts.currentName) || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inLeftPanel(panels.popoutsWrapper, x, y) && !inTrayAimCorridor(pointer)) {
            cancelPendingPopout();
            closeTransientPopout();
        }

        previousPointer = pointer;
        previousPointerTime = now;
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            // If launcher is hidden, clear shortcut flags for dashboard and OSD
            if (!root.screenState.launcher) {
                root.dashboardShortcutActive = false;
                root.osdShortcutActive = false;
                root.utilitiesShortcutActive = false;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.screenState.dashboard = false;
                }
                if (!inOsdArea) {
                    root.screenState.osd = false;
                    root.panels.osd.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.screenState.dashboard) {
                // Dashboard became visible, immediately check if this should be shortcut mode
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea) {
                    root.dashboardShortcutActive = true;
                }
            } else {
                // Dashboard hidden, clear shortcut flag
                root.dashboardShortcutActive = false;
            }
        }

        function onOsdChanged() {
            if (root.screenState.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.screenState.utilities) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.utilitiesShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.utilitiesShortcutActive = false;
            }
        }

        target: root.screenState
    }
}
