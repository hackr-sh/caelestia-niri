pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

Row {
    id: root

    property color colour: Colours.palette.m3tertiary

    spacing: Appearance.spacing.small

    StyledText {
        id: dateText

        anchors.verticalCenter: parent.verticalCenter

        verticalAlignment: StyledText.AlignVCenter
        text: Time.format("dd/MM/yy")
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour
    }

    Loader {
        anchors.verticalCenter: parent.verticalCenter

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

        anchors.verticalCenter: parent.verticalCenter

        verticalAlignment: StyledText.AlignVCenter
        text: Time.format("hh:mm:ss")
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: root.colour
    }
}
