import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vacaplan 1.0

// Accordion-style field: header with value + chevron, tapping it reveals a
// grid of pill options (and optionally a search box). Used for
// Comunidad/Provincia/Municipio in onboarding.
ColumnLayout {
    id: root
    property string label: ""
    property string value: ""
    property string placeholder: "Elige una opción"
    property var options: []
    property bool open: false
    property bool searchable: false
    property string query: ""
    property string searchPlaceholder: "Busca..."
    property string hintText: ""
    signal toggled()
    signal optionPicked(string option)
    signal queryEdited(string text)
    signal expanded()

    spacing: 0

    Rectangle {
        id: card
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        implicitHeight: headerCol.implicitHeight + 8
        radius: 20
        color: Style.surface
        border.color: root.open ? Style.primary : Style.divider
        border.width: root.open ? 1.5 : 1

        Behavior on border.color { ColorAnimation { duration: Style.animationTime } }

        ColumnLayout {
            id: headerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 0

            Button {
                opacity: pressed ? 0.6 : 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
                Layout.fillWidth: true
                implicitHeight: 54
                background: Rectangle { color: "transparent" }
                contentItem: RowLayout {
                    spacing: 12
                    ColumnLayout {
                        Layout.leftMargin: 12
                        spacing: 4
                        Text {
                            text: root.label
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.letterSpacing: 0.4
                            color: Style.textSecondary
                        }
                        Text {
                            text: root.value.length > 0 ? root.value : root.placeholder
                            font.family: Style.fontFamily
                            font.pixelSize: 15
                            font.weight: root.value.length > 0 ? Font.Bold : Font.Normal
                            color: root.value.length > 0 ? Style.text : "#9AA6AA"
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Image {
                        Layout.rightMargin: 12
                        source: Style.icon("chevron-right")
                        width: 18; height: 18
                        sourceSize: Qt.size(18, 18)
                        rotation: root.open ? 90 : 0
                        opacity: root.open ? 1 : 0.55
                        Behavior on rotation { NumberAnimation { duration: 200 } }
                    }
                }
                onClicked: root.toggled()
            }

            Loader {
                id: expandLoader
                Layout.fillWidth: true
                active: root.open
                visible: active
                onLoaded: Qt.callLater(function () { root.expanded() })
                sourceComponent: Component {
                    ColumnLayout {
                        id: expandCol
                        Layout.fillWidth: true
                        spacing: 8
                        property bool revealed: false
                        opacity: revealed ? 1 : 0
                        y: revealed ? 0 : 10
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                        Component.onCompleted: revealed = true

                        TextField {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            visible: root.searchable
                            text: root.query
                            placeholderText: root.searchPlaceholder
                            font.family: Style.fontFamily
                            onTextEdited: root.queryEdited(text)
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            spacing: 8

                            Repeater {
                                model: root.options
                                delegate: Button {
                                    required property string modelData
                                    implicitHeight: 34
                                    implicitWidth: optLabel.implicitWidth + 26
                                    background: Rectangle {
                                        radius: 999
                                        color: modelData === root.value ? Style.primary : Style.background
                                        border.color: modelData === root.value ? Style.primary : Style.divider
                                        border.width: 1
                                    }
                                    contentItem: Text {
                                        id: optLabel
                                        text: modelData
                                        font.family: Style.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: modelData === root.value ? "white" : Style.text
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: root.optionPicked(modelData)
                                }
                            }
                        }

                        Text {
                            visible: root.hintText.length > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            text: root.hintText
                            font.family: Style.fontFamily
                            font.pixelSize: 12
                            color: Style.textSecondary
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.preferredHeight: 8 }
                    }
                }
            }
        }
    }
}
