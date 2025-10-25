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
    readonly property var workspaces: ({ values: [] })
    readonly property var monitors: ({ values: [] })

    readonly property var activeToplevel: null
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
        
        // Try to execute niri command using Process
        const process = Qt.createQmlObject(`
            import QtQuick
            Process {
                id: process
                command: ["niri", "msg", "${command}"]
                onFinished: {
                    console.log("Niri command executed successfully:", "${command}")
                    process.destroy()
                }
                onError: {
                    console.error("Niri command failed:", "${command}", error)
                    // Fallback: try alternative command format
                    process.command = ["niri", "msg", "workspace", "${command}"]
                    process.start()
                }
            }
        `, root);
        process.start();
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

    Component.onCompleted: {
        // Initialize niri-specific setup
        console.log("Niri service initialized");
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
