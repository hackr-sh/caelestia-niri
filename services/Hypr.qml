pragma Singleton

import qs.components.misc
import qs.config
import Caelestia
import Caelestia.Internal
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel?.wayland?.activated ? Hyprland.activeToplevel : null
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: isNiriRunning() ? niriActiveWorkspace : (focusedWorkspace?.id ?? 1)

    readonly property HyprKeyboard keyboard: extras.devices.keyboards.find(kb => kb.main) ?? null
    readonly property bool capsLock: keyboard?.capsLock ?? false
    readonly property bool numLock: keyboard?.numLock ?? false
    readonly property string defaultKbLayout: keyboard?.layout.split(",")[0] ?? "??"
    readonly property string kbLayoutFull: keyboard?.activeKeymap ?? "Unknown"
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? "??"
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property bool hadKeyboard

    signal configReloaded

    function dispatch(request: string): void {
        console.log("Dispatch request:", request, "Niri detected:", niriDetected);
        
        // Always try niri first if detected, otherwise try hyprland
        if (niriDetected) {
            console.log("Using niri dispatch for:", request);
            dispatchNiri(request);
        } else {
            console.log("Using hyprland dispatch for:", request);
            // Try to use Hyprland, but if it fails, try niri as fallback
            try {
                Hyprland.dispatch(request);
            } catch (e) {
                console.log("Hyprland dispatch failed, trying niri as fallback:", e);
                dispatchNiri(request);
            }
        }
    }

    property bool niriDetected: false
    property var niriWorkspaces: []
    property int niriActiveWorkspace: 1
    
    signal niriDetectionChanged(bool detected)
    signal niriWorkspacesUpdated()
    
    // Dynamic workspace count based on niri or hyprland
    readonly property int workspaceCount: {
        if (isNiriRunning()) {
            return niriWorkspaces.length;
        } else {
            return workspaces?.values?.length ?? 5;
        }
    }
    
    function isNiriRunning(): bool {
        return niriDetected;
    }
    
    function forceNiriDetection(): void {
        console.log("Manually forcing niri detection");
        const wasDetected = niriDetected;
        niriDetected = true;
        if (wasDetected !== niriDetected) {
            niriDetectionChanged(niriDetected);
        }
        // Fetch workspaces when niri is detected
        fetchNiriWorkspaces();
    }
    
    function fetchNiriWorkspaces(): void {
        if (!niriDetected) return;
        
        // Use the actual workspace data from niri
        const workspaces = Niri.workspaces;

        workspaces.forEach(ws => {
            ws.is_active = (ws.id === Niri.activeWsId);
            ws.is_focused = (ws.id === Niri.activeWsId);
        });
        
        niriWorkspaces = workspaces;
        
        // Find the active workspace
        const activeWs = workspaces.find(w => w.is_active);
        if (activeWs) {
            niriActiveWorkspace = activeWs.id;
        }
        
        niriWorkspacesUpdated();
    }

    function dispatchNiri(request: string): void {
        console.log("Dispatching niri command:", request);
        
        // Parse the request and convert to niri commands
        if (request.startsWith("workspace ")) {
            const workspaceId = request.split(" ")[1];
            console.log("Workspace switch request:", workspaceId);
            
            if (workspaceId.startsWith("r")) {
                // Relative workspace switching - use niri command
                const direction = workspaceId.includes("+") ? 1 : -1;
                const amount = parseInt(workspaceId.replace(/[r+-]/g, ""));
                console.log("Relative workspace switch:", direction, amount);
                if (amount > 0) {
                    niriCommand(`action focus-workspace-${direction > 0 ? "down" : "up"}`);
                } else {
                    niriCommand(`action focus-workspace-${direction > 0 ? "down" : "up"}`);
                }
            } else {
                // Absolute workspace switching - use direct niri switching
                const wsId = parseInt(workspaceId);
                console.log("Absolute workspace switch to:", wsId);
                if (wsId > 0) {
                    switchToNiriWorkspace(wsId);
                }
            }
        } else if (request === "togglespecialworkspace special") {
            niriCommand("action toggle-overview");
        } else if (request.startsWith("togglespecialworkspace ")) {
            const specialName = request.split(" ")[1];
            niriCommand("action toggle-overview");
        }
    }

    function niriCommand(command: string): void {
        console.log("Executing niri command:", command);
        
        // Parse the command to extract the action
        const parts = command.split(" ");
        const action = parts[1]; // Skip "action"
        const args = parts.slice(2);
        
        // Build the niri command
        const niriArgs = ["niri", "msg", "action", action];
        if (args.length > 0) {
            niriArgs.push(...args);
        }
        
        console.log("Niri command args:", niriArgs);
        
        // Execute the command using Quickshell.execDetached
        try {
            Quickshell.execDetached(niriArgs);
            console.log("Niri command executed successfully");
        } catch (error) {
            console.error("Niri command failed:", error);
        }
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function reloadDynamicConfs(): void {
        extras.batchMessage(["keyword bindlni ,Caps_Lock,global,caelestia:refreshDevices", "keyword bindlni ,Num_Lock,global,caelestia:refreshDevices"]);
    }

    Component.onCompleted: {
        reloadDynamicConfs();
        
        // Check if we're running under niri by checking environment variables
        if (Quickshell.env("NIRI_SOCKET")) {
            console.log("Detected niri environment via NIRI_SOCKET, forcing niri detection");
            forceNiriDetection();
        } else if (Quickshell.env("WAYLAND_DISPLAY") && !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) {
            console.log("Detected niri environment via Wayland display, forcing niri detection");
            forceNiriDetection();
        } else {
            console.log("No niri environment detected, checking via command");
        }
        
        // Check for niri availability periodically
        detectionTimer.start();
    }
    
    // Timer for niri detection and workspace refresh
    Timer {
        id: detectionTimer
        interval: 1000 // Check every 1 second
        repeat: true
        onTriggered: {
            if (niriDetected) {
                fetchNiriWorkspaces();
            }
        }
    }

    onCapsLockChanged: {
        if (!Config.utilities.toasts.capsLockChanged)
            return;

        if (capsLock)
            Toaster.toast(qsTr("Caps lock enabled"), qsTr("Caps lock is currently enabled"), "keyboard_capslock_badge");
        else
            Toaster.toast(qsTr("Caps lock disabled"), qsTr("Caps lock is currently disabled"), "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!Config.utilities.toasts.numLockChanged)
            return;

        if (numLock)
            Toaster.toast(qsTr("Num lock enabled"), qsTr("Num lock is currently enabled"), "looks_one");
        else
            Toaster.toast(qsTr("Num lock disabled"), qsTr("Num lock is currently disabled"), "timer_1");
    }

    onKbLayoutFullChanged: {
        if (hadKeyboard && Config.utilities.toasts.kbLayoutChanged)
            Toaster.toast(qsTr("Keyboard layout changed"), qsTr("Layout changed to: %1").arg(kbLayoutFull), "keyboard");

        hadKeyboard = !!keyboard;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (n === "configreloaded") {
                root.configReloaded();
                root.reloadDynamicConfs();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }
    }

    FileView {
        id: kbLayoutFile

        path: Quickshell.env("CAELESTIA_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                const lines = layoutMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                const lines = variantMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
        }
    }

    IpcHandler {
        target: "hypr"

        function refreshDevices(): void {
            extras.refreshDevices();
        }
    }

    CustomShortcut {
        name: "refreshDevices"
        description: "Reload devices"
        onPressed: extras.refreshDevices()
        onReleased: extras.refreshDevices()
    }

    HyprExtras {
        id: extras
    }
}
