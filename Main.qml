import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Vacaplan 1.0

ApplicationWindow {
    id: root
    width: 420
    height: 800
    visible: true
    title: "Vacaplan"

    DataCenter {
        id: dataCenter
    }

    HolidayProvider {
        id: holidayProvider
    }

    StackView {
        id: stackView
        anchors.fill: parent
        background: Rectangle { color: Style.background }

        function goToLocationPage() {
            stackView.clear()
            stackView.push(Qt.resolvedUrl("qml/OnboardingLocationPage.qml"), {
                dataCenter: dataCenter,
                holidayProvider: holidayProvider
            })
        }

        function goToHome() {
            stackView.clear()
            stackView.push(Qt.resolvedUrl("qml/HomePage.qml"), {
                dataCenter: dataCenter,
                holidayProvider: holidayProvider
            })
        }
    }

    Connections {
        target: stackView.currentItem
        ignoreUnknownSignals: true
        function onLocationConfirmed() {
            stackView.push(Qt.resolvedUrl("qml/OnboardingVacationDaysPage.qml"), {
                dataCenter: dataCenter
            })
        }
        function onDaysConfirmed() {
            stackView.push(Qt.resolvedUrl("qml/OnboardingUsedDaysPage.qml"), {
                dataCenter: dataCenter,
                holidayProvider: holidayProvider
            })
        }
        function onFinished() {
            stackView.goToHome()
        }
        function onBack() {
            stackView.pop()
        }
        function onRestartOnboarding() {
            stackView.goToLocationPage()
        }
    }

    Component.onCompleted: {
        stackView.push(Qt.resolvedUrl("qml/OnboardingUsedDaysPage.qml"), {
            dataCenter: dataCenter, holidayProvider: holidayProvider, picking: true
        })
    }
}
