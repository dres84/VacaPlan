import QtQuick
import QtQuick.Controls
import Vacaplan 1.0

Button {
    id: control

    implicitHeight: 44
    implicitWidth: Math.max(120, contentItem.implicitWidth + 36)

    background: Rectangle {
        radius: Style.mediumRadius
        color: "transparent"
        border.color: control.pressed ? Style.primaryPressed : Style.divider
        border.width: 1
    }

    contentItem: Text {
        text: control.text
        font.pixelSize: Style.body
        color: Style.textSecondary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
