cmake_minimum_required(VERSION 3.20)
project(WinMerge VERSION 0.1.0 LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

# macOS deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum macOS version")

# xdiff library (from WinMerge Externals)
set(XDIFF_DIR "${CMAKE_SOURCE_DIR}/../Externals/xdiff")
add_library(xdiff STATIC
    ${XDIFF_DIR}/xdiffi.c
    ${XDIFF_DIR}/xemit.c
    ${XDIFF_DIR}/xhistogram.c
    ${XDIFF_DIR}/xmerge.c
    ${XDIFF_DIR}/xnone.c
    ${XDIFF_DIR}/xpatience.c
    ${XDIFF_DIR}/xprepare.c
    ${XDIFF_DIR}/xutils.c
)
target_include_directories(xdiff PUBLIC ${XDIFF_DIR})

# Core diff engine library (cross-platform C++)
add_library(diffcore STATIC
    src/core/DiffEngine.cpp
    src/core/FileOperations.cpp
)
target_include_directories(diffcore PUBLIC src/core)
target_link_libraries(diffcore PUBLIC xdiff)

# macOS application
set(MACOSX_BUNDLE_GUI_IDENTIFIER "org.winmerge.WinMerge")
set(MACOSX_BUNDLE_BUNDLE_NAME "WinMerge")
set(MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}")
set(MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}")

set(APP_SOURCES
    src/ui/main.mm
    src/ui/AppDelegate.mm
    src/ui/DiffViewController.mm
    src/ui/DiffTextView.mm
)

add_executable(WinMerge MACOSX_BUNDLE ${APP_SOURCES})

target_link_libraries(WinMerge PRIVATE
    diffcore
    "-framework Cocoa"
    "-framework UniformTypeIdentifiers"
)

set_target_properties(WinMerge PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/resources/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_SOURCE_DIR}/resources/WinMerge.entitlements"
)
