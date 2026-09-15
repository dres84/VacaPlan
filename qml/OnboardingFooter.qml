import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vacaplan 1.0

// Fixed footer (outside the scroll) shared by the 3 onboarding steps: a
// 1px top separator, always present, and the full-width pill button that
// appears (with animation) only when `buttonEnabled` is true — same as the
// rest of the onboarding blocks, nothing sits there disabled: it either
// doesn't exist yet or it's ready.
Rectangle {
    id: root
    property string text: "Continuar"
    property color baseColor: Style.primary
    property color disabledColor: Style.primaryDisabled
    property bool showIcon: true
    property bool buttonEnabled: true
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: loader.active ? (loader.item.implicitHeight + 32) : 19
    color: Style.background

    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 1
        color: Style.divider
    }

    Loader {
        id: loader
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: Style.mediumMargin
        anchors.rightMargin: Style.mediumMargin
        anchors.topMargin: 14
        active: root.buttonEnabled
        visible: active
        sourceComponent: Component {
            Button {
                opacity: pressed ? 0.6 : 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
                width: loader.width
                implicitHeight: 54
                property bool revealed: false
                opacity: revealed ? 1 : 0
                y: revealed ? 0 : 14
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                Component.onCompleted: revealed = true

                background: Rectangle { radius: 999; color: root.baseColor }
                contentItem: Item {
                    // Control forces `contentItem` to the button's full width
                    // (availableWidth), so a RowLayout placed inside it is
                    // already stretched and `Layout.alignment`/`anchors.centerIn`
                    // don't group anything — each child lands wherever the
                    // RowLayout itself distributes it. That's why the text+icon
                    // group lives in a `Row` (not a Layout) inside this filler
                    // `Item`, actually centered as one block.
                    implicitWidth: labelRow.implicitWidth
                    implicitHeight: labelRow.implicitHeight
                    Row {
                        id: labelRow
                        anchors.centerIn: parent
                        spacing: 9
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.text
                            font.family: Style.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: "white"
                        }
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.showIcon
                            source: Style.icon("chevron-right-white")
                            width: 17; height: 17
                            sourceSize: Qt.size(17, 17)
                        }
                    }
                }
                onClicked: root.clicked()
            }
        }
    }
}
