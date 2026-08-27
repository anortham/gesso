cmake_minimum_required(VERSION 3.16)

project(gesso-setup)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMFindQmlModule)

find_package(Qt6 REQUIRED COMPONENTS
  Core
  Gui
  Qml
  Quick
  QuickControls2
)
find_package(KF6 REQUIRED COMPONENTS Kirigami)

ecm_find_qmlmodule(org.kde.kirigami REQUIRED)

qt_add_executable(gesso-setup
  main.cpp
  GessoCli.cpp
  GessoCli.hpp
)

qt_add_resources(gesso-setup gesso_setup_qml
  PREFIX /
  FILES
    qml/Main.qml
    qml/ThemePage.qml
)

target_link_libraries(gesso-setup PRIVATE
  Qt6::Core
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::QuickControls2
  KF6::Kirigami
)

install(TARGETS gesso-setup ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
