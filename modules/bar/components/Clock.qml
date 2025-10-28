pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

Column {
    id: root

    property color colour: Colours.palette.m3tertiary

    spacing: Appearance.spacing.small

    StyledText {
        id: dateText

        anchors.horizontalCenter: parent.horizontalCenter

        horizontalAlignment: StyledText.AlignHCenter
        text: Time.format("dd\nMM\nyy")
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour
    }

    Loader {
        anchors.horizontalCenter: parent.horizontalCenter

        active: Config.bar.clock.showIcon
        visible: active
        asynchronous: true

        sourceComponent: MaterialIcon {
            text: "calendar_month"
            color: root.colour
        }
    }

    StyledText {
        id: timeText

        anchors.horizontalCenter: parent.horizontalCenter

        horizontalAlignment: StyledText.AlignHCenter
        text: Time.format("hh\nmm\nss")
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour
    }
}
