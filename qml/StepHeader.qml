import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vacaplan 1.0

// Fixed header (outside the scroll) shared by the 3 onboarding steps:
// step label, progress bar, and an action link on the right
// ("Reiniciar" on step 1, "Atrás" on 2 and 3).
RowLayout {
    id: root
    property int step: 1
    property int totalSteps: 3
    property string linkText: qsTr("Atrás")
    signal linkClicked()
    signal settingsClicked()

    Layout.fillWidth: true
    Layout.leftMargin: Style.mediumMargin
    Layout.rightMargin: Style.mediumMargin
    Layout.topMargin: Style.mediumSpace
    Layout.bottomMargin: 10
    spacing: 10

    Text {
        text: qsTr("PASO %1 DE %2").arg(root.step).arg(root.totalSteps)
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.4
        color: Style.textSecondary
    }
    StepIndicator { Layout.fillWidth: true; currentStep: root.step; steps: root.totalSteps }
    Button {
        opacity: pressed ? 0.6 : 1.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        id: settingsButton
        implicitWidth: 30
        implicitHeight: 30
        background: Rectangle {
            radius: 999
            color: settingsButton.pressed ? Style.divider : "transparent"
        }
        contentItem: Image {
            anchors.centerIn: parent
            source: Style.icon("settings")
            width: 15; height: 15
            sourceSize: Qt.size(15, 15)
        }
        onClicked: root.settingsClicked()
    }
    Button {
        opacity: pressed ? 0.6 : 1.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        id: linkButton
        implicitHeight: 34
        leftPadding: 10
        rightPadding: 10
        topPadding: 6
        bottomPadding: 6
        background: Rectangle {
            radius: 999
            color: linkButton.pressed ? Style.divider : "transparent"
        }
        contentItem: Text {
            text: root.linkText
            font.family: Style.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: linkButton.pressed ? Style.text : Style.textSecondary
        }
        onClicked: root.linkClicked()
    }
}
