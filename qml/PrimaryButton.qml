import QtQuick
import QtQuick.Controls
import Vacaplan 1.0

Button {
    id: control
    property color baseColor: Style.buttonPositive
    property color pressedColor: Style.buttonPositivePressed
    property color disabledColor: Style.buttonPositiveDisabled

    implicitHeight: 48
    implicitWidth: Math.max(140, contentItem.implicitWidth + 40)

    background: Rectangle {
        radius: Style.mediumRadius
        color: !control.enabled ? disabledColor
               : control.pressed ? pressedColor
               : baseColor
    }

    contentItem: Text {
        text: control.text
        font.pixelSize: Style.body
        font.bold: true
        color: control.enabled ? Style.buttonText : Style.buttonTextDisabled
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
