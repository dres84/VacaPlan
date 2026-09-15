import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Vacaplan 1.0

Page {
    id: root
    property var dataCenter
    signal daysConfirmed()
    signal back()

    background: Rectangle { color: Style.background }

    property int totalDays: dataCenter ? dataCenter.data.totalVacationDays : 22
    readonly property var presets: [20, 22, 23, 25]

    function setTotal(v) {
        root.totalDays = Math.max(1, Math.min(45, v))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item { Layout.preferredHeight: Style.smallSpace }

        StepHeader {
            step: 2
            linkText: "Atrás"
            onLinkClicked: root.back()
        }

        Flickable {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: pageColumn.implicitHeight
            boundsBehavior: Flickable.DragOverBounds
            interactive: contentHeight > height

            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: pageColumn
                width: root.width
                spacing: Style.mediumSpace

                // Title
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    spacing: 10

                    Image { source: Style.icon("beach-umbrella"); width: 34; height: 34; sourceSize: Qt.size(34, 34) }
                    Text {
                        text: "¿Cuántos días de vacaciones tienes?"
                        font.family: Style.fontFamily
                        font.pixelSize: 29
                        font.weight: Font.Bold
                        font.letterSpacing: -0.9
                        color: Style.text
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Los días laborables de vacaciones a los que tienes derecho cada año, según tu convenio o contrato. Sin contar festivos ni fines de semana."
                        font.family: Style.fontFamily
                        font.pixelSize: 14
                        color: Style.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Hero card: big counter + presets
                Rectangle {
                    id: heroCard
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    Layout.preferredHeight: heroContent.implicitHeight + 46
                    radius: Style.heroRadius
                    color: Style.primary
                    clip: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Style.primary
                        shadowOpacity: 0.22
                        shadowBlur: 0.6
                        shadowVerticalOffset: 8
                    }

                    Rectangle {
                        width: 132; height: 132; radius: 66
                        color: "#FFFFFF"; opacity: 0.07
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.rightMargin: -30; anchors.topMargin: -30
                    }

                    ColumnLayout {
                        id: heroContent
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Style.bigSpace
                        anchors.topMargin: 24
                        spacing: 20

                        Text {
                            text: "DÍAS AL AÑO"
                            font.family: Style.fontFamily
                            font.pixelSize: Style.caption
                            font.weight: Font.Medium
                            font.letterSpacing: 0.7
                            color: "#E8F5F4"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Button {
                                opacity: pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                implicitWidth: 46; implicitHeight: 46
                                background: Rectangle {
                                    radius: 999
                                    color: "#FFFFFF"; opacity: 0.18
                                    border.color: "#FFFFFF"; border.width: 1
                                }
                                contentItem: Image { anchors.centerIn: parent; source: Style.icon("minus-white"); width: 20; height: 20; sourceSize: Qt.size(20, 20) }
                                onClicked: root.setTotal(root.totalDays - 1)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.totalDays
                                    font.family: Style.fontFamily
                                    font.pixelSize: 72
                                    font.weight: Font.Bold
                                    font.letterSpacing: -3.2
                                    color: "white"
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "días laborables"
                                    font.family: Style.fontFamily
                                    font.pixelSize: Style.caption
                                    font.weight: Font.Medium
                                    color: "#E8F5F4"
                                }
                            }

                            Button {
                                opacity: pressed ? 0.6 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                implicitWidth: 46; implicitHeight: 46
                                background: Rectangle {
                                    radius: 999
                                    color: "#FFFFFF"; opacity: 0.18
                                    border.color: "#FFFFFF"; border.width: 1
                                }
                                contentItem: Image { anchors.centerIn: parent; source: Style.icon("plus-white"); width: 20; height: 20; sourceSize: Qt.size(20, 20) }
                                onClicked: root.setTotal(root.totalDays + 1)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: root.presets
                                delegate: Button {
                                    required property int modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 38
                                    background: Rectangle {
                                        radius: 999
                                        color: "#FFFFFF"
                                        opacity: root.totalDays === modelData ? 1 : 0.12
                                        border.color: "#FFFFFF"
                                        border.width: 1
                                    }
                                    contentItem: Text {
                                        text: String(modelData)
                                        font.family: Style.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        color: root.totalDays === modelData ? Style.primary : "#FFFFFF"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: root.setTotal(modelData)
                                }
                            }
                        }
                    }
                }

                // Info note
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.mediumMargin
                    Layout.rightMargin: Style.mediumMargin
                    Layout.preferredHeight: noteRow.implicitHeight + 30
                    radius: Style.cardRadius
                    color: Style.surface
                    border.color: Style.divider
                    border.width: 1

                    RowLayout {
                        id: noteRow
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 15
                        spacing: 11

                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            width: 32; height: 32; radius: 10
                            color: Style.scopeChipBg("regional")
                            Image {
                                anchors.centerIn: parent
                                source: Style.icon("sun")
                                width: 18; height: 18
                                sourceSize: Qt.size(18, 18)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Lo habitual en España son <b>22 días laborables</b> (30 naturales). Podrás cambiarlo después desde ajustes."
                            textFormat: Text.RichText
                            font.family: Style.fontFamily
                            font.pixelSize: 13
                            color: Style.textSecondary
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Item { Layout.preferredHeight: Style.mediumMargin }
            }
        }

        OnboardingFooter {
            text: "Continuar"
            baseColor: Style.primary
            onClicked: {
                root.dataCenter.setTotalVacationDays(root.totalDays)
                root.daysConfirmed()
            }
        }
    }
}
