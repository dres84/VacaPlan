import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Vacaplan 1.0

// Appearance + language picker, shared by every screen that shows a
// settings entry point — a single definition so the two never drift apart.
Item {
    id: root
    property bool open: false
    signal closed()

    visible: open
    z: 50

    Rectangle {
        anchors.fill: parent
        color: Style.scrim
        MouseArea { anchors.fill: parent; onClicked: root.closed() }
    }

    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 18
        radius: Style.heroRadius
        color: Style.surface
        implicitHeight: settingsCol.implicitHeight + 40

        ColumnLayout {
            id: settingsCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 20
            spacing: 13

            Rectangle {
                width: 44; height: 44; radius: 14
                color: Style.scopeChipBg("nacional")
                Image { anchors.centerIn: parent; source: Style.icon("settings"); width: 22; height: 22; sourceSize: Qt.size(22, 22) }
            }
            Text {
                text: qsTr("Apariencia")
                font.family: Style.fontFamily
                font.pixelSize: 20
                font.weight: Font.Bold
                font.letterSpacing: -0.4
                color: Style.text
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Elige cómo se ve Vacaplan. \"Automático\" sigue el tema del sistema.")
                font.family: Style.fontFamily
                font.pixelSize: 14
                color: Style.textSecondary
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 3
                implicitHeight: modeRow.implicitHeight + 6
                radius: 999
                color: Style.track

                RowLayout {
                    id: modeRow
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    Repeater {
                        model: [
                            { value: 0, label: qsTr("Automático") },
                            { value: 1, label: qsTr("Claro") },
                            { value: 2, label: qsTr("Oscuro") }
                        ]
                        delegate: Button {
                            id: modeButton
                            required property var modelData
                            readonly property bool active: Style.mode === modelData.value
                            opacity: pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            Layout.fillWidth: true
                            implicitHeight: 38
                            background: Rectangle {
                                radius: 999
                                color: modeButton.active ? Style.surface : "transparent"
                                layer.enabled: modeButton.active
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                            }
                            contentItem: Text {
                                text: modeButton.modelData.label
                                font.family: Style.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: modeButton.active ? Style.primaryInk : Style.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: Style.mode = modeButton.modelData.value
                        }
                    }
                }
            }

            Text {
                Layout.topMargin: 10
                text: qsTr("Idioma")
                font.family: Style.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Style.text
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("\"Automático\" sigue el idioma del sistema.")
                font.family: Style.fontFamily
                font.pixelSize: 13
                color: Style.textSecondary
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 3
                implicitHeight: languageRow.implicitHeight + 6
                radius: 999
                color: Style.track

                RowLayout {
                    id: languageRow
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    Repeater {
                        model: [
                            { value: 0, label: qsTr("Automático") },
                            { value: 1, label: "Español" },
                            { value: 2, label: "English" }
                        ]
                        delegate: Button {
                            id: languageButton
                            required property var modelData
                            readonly property bool active: LanguageManager.mode === modelData.value
                            opacity: pressed ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            Layout.fillWidth: true
                            implicitHeight: 38
                            background: Rectangle {
                                radius: 999
                                color: languageButton.active ? Style.surface : "transparent"
                                layer.enabled: languageButton.active
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Style.text; shadowOpacity: 0.12; shadowBlur: 0.3; shadowVerticalOffset: 1 }
                            }
                            contentItem: Text {
                                text: languageButton.modelData.label
                                font.family: Style.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: languageButton.active ? Style.primaryInk : Style.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: LanguageManager.mode = languageButton.modelData.value
                        }
                    }
                }
            }

            Button {
                id: doneButton
                opacity: pressed ? 0.6 : 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: 48
                background: Rectangle { radius: 999; color: Style.sunken; border.color: Style.divider; border.width: 1 }
                contentItem: Text { text: qsTr("Hecho"); font.family: Style.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Style.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.closed()
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 6
                Text {
                    text: qsTr("Diseñado por")
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    color: Style.textDisabled
                }
                Image {
                    source: "qrc:/icons/dresoft-logo.png"
                    fillMode: Image.PreserveAspectFit
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: 16 * (512 / 168)
                    sourceSize.height: 32
                }
            }
        }
    }
}
