cmake_minimum_required(VERSION 3.21)

project(Vacaplan VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network QuickControls2 Svg)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appVacaplan
    main.cpp
)

if(ANDROID)
    configure_file(
        ${CMAKE_SOURCE_DIR}/android/src/main/AndroidManifest.xml
        ${CMAKE_BINARY_DIR}/android-build/AndroidManifest.xml
        COPYONLY
    )

    set(ANDROID_PACKAGE_NAME "com.dreSoft.vacaplan")
    set(ANDROID_APP_NAME "Vacaplan")

    set_property(TARGET appVacaplan PROPERTY QT_ANDROID_APPLICATION_CLASS "org.qtproject.qt.android.bindings.QtApplication")
    set_property(TARGET appVacaplan PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android/src/main")
endif()

set_source_files_properties(qml/Style.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(appVacaplan
    URI Vacaplan
    VERSION 1.0
    QML_FILES
        Main.qml
        qml/Style.qml
        qml/PrimaryButton.qml
        qml/SecondaryButton.qml
        qml/StepIndicator.qml
        qml/AccordionSelect.qml
        qml/StepHeader.qml
        qml/OnboardingFooter.qml
        qml/ManualHolidaysEditor.qml
        qml/OnboardingLocationPage.qml
        qml/OnboardingVacationDaysPage.qml
        qml/OnboardingUsedDaysPage.qml
        qml/HomePage.qml
    SOURCES
        datacenter.h datacenter.cpp
        holidayprovider.h holidayprovider.cpp
)

qt_add_resources(appVacaplan "icons"
    FILES
        icons/alert-circle.svg
        icons/beach-umbrella.svg
        icons/bookmark-manual.svg
        icons/calendar-check.svg
        icons/calendar-locked.svg
        icons/calendar.svg
        icons/check-circle.svg
        icons/chevron-left.svg
        icons/chevron-right.svg
        icons/chevron-right-white.svg
        icons/flag-local.svg
        icons/flag-national.svg
        icons/flag-provincial.svg
        icons/flag-region.svg
        icons/flag-spain.svg
        icons/globe.svg
        icons/globe-active.svg
        icons/location-pin.svg
        icons/minus.svg
        icons/minus-white.svg
        icons/palm-tree.svg
        icons/plane.svg
        icons/plus.svg
        icons/plus-white.svg
        icons/rotate-ccw.svg
        icons/suitcase.svg
        icons/sun.svg
        icons/sun-white.svg
)

qt_add_resources(appVacaplan "fonts"
    FILES
        fonts/DM_Sans.ttf
)

set_target_properties(appVacaplan PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appVacaplan
    PRIVATE Qt6::Quick Qt6::Network Qt6::QuickControls2 Qt6::Svg
)

include(GNUInstallDirs)
install(TARGETS appVacaplan
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

set(CMAKE_SKIP_BUILD_RPATH TRUE)
