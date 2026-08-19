import QtQuick
import QtQuick.Layouts
import Vacaplan 1.0

RowLayout {
    id: root
    property int steps: 3
    property int currentStep: 1 // 1-based
    spacing: 5

    Repeater {
        model: root.steps
        delegate: Rectangle {
            required property int index
            Layout.fillWidth: true
            Layout.preferredWidth: 34
            height: 4
            radius: 99
            color: (index + 1) <= root.currentStep ? Style.primary : Style.divider

            Behavior on color {
                ColorAnimation { duration: Style.animationTime }
            }
        }
    }
}
