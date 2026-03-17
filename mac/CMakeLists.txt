cmake_minimum_required(VERSION 3.20)

# This macOS port requires Apple's toolchain (Objective-C++).
if(NOT APPLE)
    message(FATAL_ERROR "The mac/ port builds only on macOS with the Apple Objective-C++ toolchain. Use the platform-appropriate build (e.g., Windows via Visual Studio) on other systems.")
endif()

# Default matches mac/VERSION; build-mac.sh passes -DWM_VERSION to override on release builds.
set(WM_VERSION "0.0.1" CACHE STRING "WinMerge macOS bundle version (semantic or timestamp format)")

# Support both semantic version (x.y.z) and timestamp (YYMMDDHHMI) formats
if(WM_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
    # Semantic version format
    project(WinMerge VERSION ${WM_VERSION} LANGUAGES C CXX OBJCXX)
elseif(WM_VERSION MATCHES "^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$")
    # Timestamp format (YYMMDDHHMI) - use as bundle version string
    # For CMake project(), we need to convert to semantic format for compatibility
    # Extract YY, MM, DD, HH, MI and create a pseudo-semantic version
    string(SUBSTRING ${WM_VERSION} 0 2 YY)
    string(SUBSTRING ${WM_VERSION} 2 2 MM)
    string(SUBSTRING ${WM_VERSION} 4 2 DD)
    # Create semantic version like YY.MMDD.HHMI for CMake project() compatibility
    string(SUBSTRING ${WM_VERSION} 4 6 MINOR_PATCH)
    project(WinMerge VERSION ${YY}.${MM}.${DD} LANGUAGES C CXX OBJCXX)
    # Override with actual timestamp for bundle version
    set(PROJECT_VERSION ${WM_VERSION})
else()
    message(FATAL_ERROR "WM_VERSION must be semantic <major>.<minor>.<patch> (e.g., 0.0.1) or timestamp YYMMDDHHMI (e.g., 2603180101)")
endif()

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

configure_file("${CMAKE_SOURCE_DIR}/resources/Info.plist.in" "${CMAKE_CURRENT_BINARY_DIR}/Info.plist" @ONLY)

set_target_properties(WinMerge PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_SOURCE_DIR}/resources/WinMerge.entitlements"
)
