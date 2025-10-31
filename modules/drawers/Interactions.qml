import qs.components.controls
import qs.config
import qs.modules.bar.popouts as BarPopouts
import Quickshell
import QtQuick

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property PersistentProperties visibilities
    required property Panels panels
    required property Item bar

    property point dragStart
    property bool dashboardShortcutActive
    property bool osdShortcutActive
    property bool utilitiesShortcutActive
    property bool pressingOverPopout: false

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        // Panels component has topMargin for bar, so account for that
        const panelY = Config.border.thickness + bar.implicitHeight + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = Config.border.thickness + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < Config.border.thickness + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Config.border.thickness + panel.x && withinPanelHeight(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        // Panels component has topMargin for bar, so account for that
        const panelY = Config.border.thickness + bar.implicitHeight + panel.y;
        return y < panelY + panel.height && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real): bool {
        // Panels component has topMargin for bar, so account for that
        const panelY = Config.border.thickness + bar.implicitHeight + panel.y;
        return y > panelY + panel.height - Config.border.rounding && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (event.y < bar.implicitHeight) {
            bar.handleWheel(event.x, event.angleDelta);
        }
    }

    anchors.fill: parent
    hoverEnabled: true
    propagateComposedEvents: true

    function isOverPopout(x: real, y: real): bool {
        if (!popouts.hasCurrent || popouts.isDetached)
            return false;
        // Popout x and y are relative to Panels, which is offset by:
        // - x: Config.border.thickness (left margin)  
        // - y: bar.implicitHeight + Config.border.thickness (top margin)
        // Map popout coordinates from Panels to window (parent of Interactions)
        const popoutInWindow = panels.mapToItem(parent, panels.popouts.x, panels.popouts.y);
        const popoutX = popoutInWindow.x;
        const popoutY = popoutInWindow.y;
        const inPopout = x >= popoutX && x <= popoutX + panels.popouts.width &&
                         y >= popoutY && y <= popoutY + panels.popouts.height;
        return inPopout;
    }

    acceptedButtons: Qt.AllButtons
    
    onPressed: event => {
        // Allow clicks on popout buttons to pass through
        if (isOverPopout(event.x, event.y)) {
            pressingOverPopout = true;
            // Don't accept the event so popout buttons can receive it
            event.accepted = false;
            return;
        }
        pressingOverPopout = false;
        dragStart = Qt.point(event.x, event.y);
    }
    
    onReleased: event => {
        pressingOverPopout = false;
    }
    
    onClicked: event => {
        // Don't consume clicks over popouts
        if (isOverPopout(event.x, event.y)) {
            event.accepted = false;
            return;
        }
    }
    
    onDoubleClicked: event => {
        if (isOverPopout(event.x, event.y)) {
            event.accepted = false;
        }
    }
    onContainsMouseChanged: {
        if (!containsMouse) {
            // Only hide if not activated by shortcut
            if (!osdShortcutActive) {
                visibilities.osd = false;
                root.panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive)
                visibilities.dashboard = false;

            if (!utilitiesShortcutActive)
                visibilities.utilities = false;

            // Don't close popout if we were just pressing on it
            if (!pressingOverPopout && (!popouts.currentName.startsWith("traymenu") || (popouts.current?.depth ?? 0) <= 1)) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        // Show bar in non-exclusive mode on hover
        if (!visibilities.bar && Config.bar.showOnHover && y < bar.implicitHeight)
            bar.isHovered = true;

        // Show/hide bar on drag
        if (pressed && dragStart.y < bar.implicitHeight) {
            if (dragY > Config.bar.dragThreshold)
                visibilities.bar = true;
            else if (dragY < -Config.bar.dragThreshold)
                visibilities.bar = false;
        }

        if (panels.sidebar.width === 0) {
            // Show osd on hover
            const showOsd = inRightPanel(panels.osd, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                visibilities.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            const showSidebar = pressed && dragStart.x > Config.border.thickness + panels.sidebar.x;

            // Show/hide session on drag
            if (pressed && inRightPanel(panels.session, dragStart.x, dragStart.y) && withinPanelHeight(panels.session, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;

                // Show sidebar on drag if in session area and session is nearly fully visible
                if (showSidebar && panels.session.width >= panels.session.nonAnimWidth && dragX < -Config.sidebar.dragThreshold)
                    visibilities.sidebar = true;
            } else if (showSidebar && dragX < -Config.sidebar.dragThreshold) {
                // Show sidebar on drag if not in session area
                visibilities.sidebar = true;
            }
        } else {
            const outOfSidebar = x < width - panels.sidebar.width;
            // Show osd on hover
            const showOsd = outOfSidebar && inRightPanel(panels.osd, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                visibilities.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            // Show/hide session on drag
            if (pressed && outOfSidebar && inRightPanel(panels.session, dragStart.x, dragStart.y) && withinPanelHeight(panels.session, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;
            }

            // Hide sidebar on drag
            if (pressed && inRightPanel(panels.sidebar, dragStart.x, 0) && dragX > Config.sidebar.dragThreshold)
                visibilities.sidebar = false;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            if (!visibilities.launcher && inBottomPanel(panels.launcher, x, y))
                visibilities.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                visibilities.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                visibilities.launcher = false;
        }

        // Show dashboard on hover
        const showDashboard = Config.dashboard.showOnHover && inTopPanel(panels.dashboard, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!dashboardShortcutActive) {
            visibilities.dashboard = showDashboard;
        } else if (showDashboard) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                visibilities.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                visibilities.dashboard = false;
        }

        // Show utilities on hover
        const showUtilities = inBottomPanel(panels.utilities, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!utilitiesShortcutActive) {
            visibilities.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            utilitiesShortcutActive = false;
        }

        // Show popouts on hover
        if (y < bar.implicitHeight) {
            bar.checkPopout(x);
        } else if ((!popouts.currentName.startsWith("traymenu") || (popouts.current?.depth ?? 0) <= 1)) {
            // Don't close popout if we're currently pressing on it, hovering over it, or if we're pressed
            if (!pressed && !pressingOverPopout && !isOverPopout(x, y)) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }
        }
    }

    // Monitor individual visibility changes
    Connections {
        target: root.visibilities

        function onLauncherChanged() {
            // If launcher is hidden, clear shortcut flags for dashboard and OSD
            if (!root.visibilities.launcher) {
                root.dashboardShortcutActive = false;
                root.osdShortcutActive = false;
                root.utilitiesShortcutActive = false;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.osd, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.visibilities.dashboard = false;
                }
                if (!inOsdArea) {
                    root.visibilities.osd = false;
                    root.panels.osd.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.visibilities.dashboard) {
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
            if (root.visibilities.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osd, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.visibilities.utilities) {
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
    }
}
