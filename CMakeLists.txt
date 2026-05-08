cmake_minimum_required(VERSION 3.21)
project(openshark VERSION 0.1.0 LANGUAGES CXX)

# std::format floating-point to_chars requires macOS 13.3+; Homebrew Qt built for 14.0+
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "" FORCE)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2 Charts QuickDialogs2)
qt_standard_project_setup(REQUIRES 6.5)

find_library(PCAP_LIBRARY pcap REQUIRED)
find_path(PCAP_INCLUDE_DIR pcap.h REQUIRED
    HINTS "${CMAKE_OSX_SYSROOT}/usr/include")

set(SOURCES
    src/main.cpp
    src/AppController.cpp
    src/capture/PacketCapture.cpp
    src/capture/RingBuffer.cpp
    src/capture/PcapFileIO.cpp
    src/dissect/PacketDissector.cpp
    src/models/PacketListModel.cpp
    src/models/InterfaceListModel.cpp
    src/models/NetworkMapModel.cpp
    src/models/StatsModel.cpp
)

set(APP_ICON_MACOS "${CMAKE_CURRENT_SOURCE_DIR}/assets/AppIcon.icns")
set_source_files_properties(${APP_ICON_MACOS} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")

qt_add_executable(openshark ${SOURCES} ${APP_ICON_MACOS})

set_source_files_properties(qml/theme/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(openshark
    URI OpenShark
    VERSION 1.0
    QML_FILES
        qml/main.qml
        qml/theme/Theme.qml
        qml/components/TeslaButton.qml
        qml/components/TeslaCard.qml
        qml/components/StatusStrip.qml
        qml/components/NavBar.qml
        qml/components/ProtocolBadge.qml
        qml/components/PlaceholderPage.qml
        qml/components/PacketRow.qml
        qml/components/DetailPanel.qml
        qml/components/HexView.qml
        qml/components/SettingsRow.qml
        qml/components/StatBigNumber.qml
        qml/components/StreamView.qml
        qml/pages/LivePage.qml
        qml/pages/MapPage.qml
        qml/pages/StatsPage.qml
        qml/pages/CapturesPage.qml
        qml/pages/SettingsPage.qml
)

target_include_directories(openshark PRIVATE src ${PCAP_INCLUDE_DIR})

target_link_libraries(openshark PRIVATE
    Qt6::Core Qt6::Quick Qt6::QuickControls2 Qt6::Charts Qt6::QuickDialogs2
    ${PCAP_LIBRARY}
)

set_target_properties(openshark PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME            "OpenShark"
    MACOSX_BUNDLE_BUNDLE_VERSION         ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING   ${PROJECT_VERSION}
    MACOSX_BUNDLE_GUI_IDENTIFIER         "com.openshark.app"
    MACOSX_BUNDLE_ICON_FILE              "AppIcon"
    RESOURCE                             "${APP_ICON_MACOS}"
)
