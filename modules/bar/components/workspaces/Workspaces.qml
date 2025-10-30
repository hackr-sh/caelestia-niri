pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

StyledClippingRect {
    id: root

    required property ShellScreen screen

    readonly property bool onSpecial: (Config.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace.name !== ""
    readonly property int activeWsId: Niri.activeWsId

    readonly property var occupied: {
        Niri.workspaces.reduce((acc, curr) => {
            acc[curr.idx] = curr.active_window_id !== null;
            return acc;
        }, {})
    }
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Niri.workspaces.length) * Niri.workspaces.length

    property real blur: onSpecial ? 1 : 0

    implicitWidth: layout.implicitWidth + Appearance.padding.small * 2
    implicitHeight: Config.bar.sizes.innerWidth

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            active: Config.bar.workspaces.occupiedBg
            asynchronous: true

            anchors.fill: parent
            anchors.margins: Appearance.padding.small

            sourceComponent: OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Math.floor(Appearance.spacing.small / 2)

            Repeater {
                id: workspaces

                model: Niri.workspaces

                Workspace {
                    activeWsId: Niri.activeWsId;
                    occupied: root.occupied;
                    groupOffset: root.groupOffset
                }
            }
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: Config.bar.workspaces.activeIndicator
            asynchronous: true

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = layout.childAt(event.x, event.y).ws;
                if (Niri.activeWsId !== ws) {
                    Niri.niriCommand(`focus-workspace ${ws}`);
                }
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent
        anchors.margins: Appearance.padding.small

        active: opacity > 0
        asynchronous: true

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on blur {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }
}
