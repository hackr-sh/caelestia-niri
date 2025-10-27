pragma Singleton

import qs.components.misc
import qs.config
import Caelestia
import Caelestia.Internal
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Properties to maintain compatibility with existing bar components
    readonly property var toplevels: ({ values: [] })
    property var workspaces: []
    property var windows: []
    readonly property var monitors: ({ values: [] })

    property var activeToplevel: null
    readonly property var focusedWorkspace: null
    readonly property var focusedMonitor: null
    readonly property int activeWsId: currentWorkspace

    // Track current workspace state
    property int currentWorkspace: 1
    property var workspaceList: []

    // Keyboard properties (simplified for niri)
    readonly property bool capsLock: false
    readonly property bool numLock: false
    readonly property string defaultKbLayout: "us"
    readonly property string kbLayoutFull: "us"
    readonly property string kbLayout: "us"
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property bool hadKeyboard: false

    signal configReloaded

    // Function to dispatch niri commands
    function dispatch(request: string): void {
        console.log("Niri dispatch:", request);
        
        // Parse the request and convert to niri commands
        if (request.startsWith("workspace ")) {
            const workspaceId = request.split(" ")[1];
            if (workspaceId.startsWith("r")) {
                // Relative workspace switching
                const direction = workspaceId.includes("+") ? 1 : -1;
                const amount = parseInt(workspaceId.replace(/[r+-]/g, ""));
                if (amount > 0) {
                    niriCommand(`workspace ${direction > 0 ? "next" : "prev"} ${amount}`);
                } else {
                    niriCommand(`workspace ${direction > 0 ? "next" : "prev"}`);
                }
            } else {
                // Absolute workspace switching
                const wsId = parseInt(workspaceId);
                if (wsId > 0) {
                    currentWorkspace = wsId;
                    niriCommand(`workspace ${workspaceId}`);
                }
            }
        } else if (request === "togglespecialworkspace special") {
            niriCommand("toggle-special-workspace");
        } else if (request.startsWith("togglespecialworkspace ")) {
            const specialName = request.split(" ")[1];
            niriCommand(`toggle-special-workspace ${specialName}`);
        }
    }

    // Function to execute niri commands
    function niriCommand(command: string): void {
        console.log("Executing niri command:", command);
        
        // Use the switch process for workspace switching
        if (command.startsWith("focus-workspace")) {
            const parts = command.split(" ");
            if (parts.length > 1) {
                const workspaceId = parts[1];
                console.log("Switching to workspace:", workspaceId);
                niriSwitchProcess.command = ["niri", "msg", "action", "focus-workspace", workspaceId];
                niriSwitchProcess.running = true;
            }
        } else {
            // For other commands, use execDetached
            try {
                Quickshell.execDetached(["niri", "msg", "action", command]);
                console.log("Niri command executed successfully");
            } catch (error) {
                console.error("Niri command failed:", error);
            }
        }
    }

    // Function to maintain compatibility
    function monitorFor(screen: ShellScreen): var {
        return {
            activeWorkspace: { id: currentWorkspace },
            lastIpcObject: {
                specialWorkspace: { name: "" }
            }
        };
    }

    // Mock function to maintain compatibility
    function reloadDynamicConfs(): void {
        // Niri doesn't have dynamic config reloading like Hyprland
        console.log("Niri: Dynamic config reloading not supported");
    }

    // Process to fetch niri workspaces
    Process {
        id: niriWorkspaceProcess
        command: ["niri", "msg", "-j", "workspaces"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                // console.log("Received niri workspace data:", JSON.stringify(JSON.parse(text), null, 2));
                try {
                    const result = JSON.parse(text);
                    workspaces = result.sort((a, b) => a.idx - b.idx);
                    
                    // Find the active workspace
                    const activeWs = result.find(w => w.is_active);
                    if (activeWs) {
                        currentWorkspace = activeWs.idx;
                    }
                } catch (e) {
                    console.error("Failed to parse niri workspaces:", e);
                }
            }
        }
    }

    Process {
        id: niriWindowsProcess
        command: ["niri", "msg", "-j", "windows"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const result = JSON.parse(text);
                windows = result;
                const _activeWindow = result.find(w => w.is_focused);
                if (_activeWindow) {
                    activeToplevel = _activeWindow;
                } else {
                    activeToplevel = null;
                }
            }
        }
    }
    
    // Process for switching workspaces
    Process {
        id: niriSwitchProcess
        running: false
    }
    
    // Timer to refresh workspace info
    Timer {
        id: niriRefreshTimer
        interval: 100 // Refresh every 100ms
        running: true
        repeat: true
        onTriggered: {
            niriWorkspaceProcess.running = true;
            niriWindowsProcess.running = true;
        }
    }

    Component.onCompleted: {
        // Initialize niri-specific setup
        console.log("Niri service initialized");
        niriWorkspaceProcess.running = true;
        niriWindowsProcess.running = true;
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

    // Mock keyboard property
    readonly property var keyboard: null

    // Mock extras for compatibility
    QtObject {
        id: extras
        
        property var options: ({})
        property var devices: ({ keyboards: [] })
        
        function refreshDevices(): void {
            console.log("Niri: Device refresh not implemented");
        }
        
        function batchMessage(messages: var): void {
            console.log("Niri: Batch message not implemented");
        }
    }

    // Mock IPC handler for compatibility
    IpcHandler {
        target: "niri"

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
}
