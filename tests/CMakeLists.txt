cmake_minimum_required(VERSION 3.13)
# https://github.com/google/oss-policies-info/blob/main/foundational-cxx-support-matrix.md#foundational-c-support

project(test_sunshine)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories("${CMAKE_SOURCE_DIR}")

enable_testing()

# Add GoogleTest directory to the project
set(GTEST_SOURCE_DIR "${CMAKE_SOURCE_DIR}/third-party/lizardbyte-common/third-party/googletest")
set(INSTALL_GTEST OFF)
set(INSTALL_GMOCK OFF)
if(NOT TARGET gtest)
    add_subdirectory("${GTEST_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/googletest")
endif()
include_directories("${GTEST_SOURCE_DIR}/googletest/include" "${GTEST_SOURCE_DIR}")

# coverage
# https://gcovr.com/en/stable/guide/compiling.html#compiler-options
option(SUNSHINE_LLVM_COVERAGE "Use LLVM source-based coverage" OFF)
if(SUNSHINE_LLVM_COVERAGE)
    add_compile_options(-fprofile-instr-generate -fcoverage-mapping -ggdb -O0)
    add_link_options(-fprofile-instr-generate)
else()
    set(CMAKE_CXX_FLAGS "-fprofile-arcs -ftest-coverage -ggdb -O0")
    set(CMAKE_C_FLAGS "-fprofile-arcs -ftest-coverage -ggdb -O0")
endif()

set(TEST_DEFINITIONS)  # list will be appended as needed

# this indicates we're building tests in case sunshine needs to adjust some code or add private tests
list(APPEND TEST_DEFINITIONS SUNSHINE_TESTS)
list(APPEND TEST_DEFINITIONS SUNSHINE_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
list(APPEND TEST_DEFINITIONS SUNSHINE_TEST_BIN_DIR="${CMAKE_CURRENT_BINARY_DIR}")

# Override SUNSHINE_ASSETS_DIR to use a writable temp directory for tests
# Remove the existing definition from SUNSHINE_DEFINITIONS to avoid redefinition error
list(FILTER SUNSHINE_DEFINITIONS EXCLUDE REGEX "^SUNSHINE_ASSETS_DIR=")
list(APPEND TEST_DEFINITIONS SUNSHINE_ASSETS_DIR="${CMAKE_CURRENT_BINARY_DIR}/test_assets")

file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS
        ${CMAKE_SOURCE_DIR}/tests/*.h
        ${CMAKE_SOURCE_DIR}/tests/*.cpp)
if(SUNSHINE_ENABLE_TRAY)
    set(SUNSHINE_TRAY_TEST_ICON_SOURCE_DIR
            "${CMAKE_SOURCE_DIR}/src_assets/common/assets/web/public/images")
    set(SUNSHINE_TRAY_TEST_ICON_DESTINATION_DIR
            "${CMAKE_CURRENT_BINARY_DIR}/test_assets/web/images")
    file(MAKE_DIRECTORY "${SUNSHINE_TRAY_TEST_ICON_DESTINATION_DIR}")

    configure_file(
            "${CMAKE_SOURCE_DIR}/sunshine.svg"
            "${SUNSHINE_TRAY_TEST_ICON_DESTINATION_DIR}/logo-sunshine.svg"
            COPYONLY)


    set(SUNSHINE_TRAY_TEST_ICONS
            sunshine-locked.svg
            sunshine-playing.svg
            sunshine-pausing.svg)

    foreach(icon IN LISTS SUNSHINE_TRAY_TEST_ICONS)
        configure_file(
                "${SUNSHINE_TRAY_TEST_ICON_SOURCE_DIR}/${icon}"
                "${SUNSHINE_TRAY_TEST_ICON_DESTINATION_DIR}/${icon}"
                COPYONLY)
    endforeach()

    add_library(sunshine_tray_test_helpers STATIC
            ${CMAKE_SOURCE_DIR}/third-party/tray/tests/notification_utils.cpp
            ${CMAKE_SOURCE_DIR}/third-party/tray/tests/screenshot_utils.cpp)
    set_target_properties(sunshine_tray_test_helpers PROPERTIES
            CXX_STANDARD 17
            CXX_STANDARD_REQUIRED ON)
    target_include_directories(sunshine_tray_test_helpers PRIVATE
            ${CMAKE_SOURCE_DIR}/third-party/tray)
    target_link_libraries(sunshine_tray_test_helpers PRIVATE
            lizardbyte::common)

    find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Gui)
    find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Gui)
    set(SUNSHINE_TRAY_TEST_QT_GUI_TARGET Qt${QT_VERSION_MAJOR}::Gui)

    target_link_libraries(sunshine_tray_test_helpers PRIVATE
            ${SUNSHINE_TRAY_TEST_QT_GUI_TARGET})
    target_link_libraries(sunshine_tray_test_helpers PRIVATE
            "-framework Cocoa")
endif()
# Objective-C++ tests
file(GLOB_RECURSE MACOS_TEST_SOURCES CONFIGURE_DEPENDS
        ${CMAKE_SOURCE_DIR}/tests/*.mm)
list(APPEND TEST_SOURCES ${MACOS_TEST_SOURCES})

set(SUNSHINE_SOURCES
        ${SUNSHINE_TARGET_FILES})

# remove main.cpp from the list of sources
list(REMOVE_ITEM SUNSHINE_SOURCES ${CMAKE_SOURCE_DIR}/src/main.cpp)

add_executable(${PROJECT_NAME}
        ${TEST_SOURCES}
        ${SUNSHINE_SOURCES})

# Copy files needed for config consistency tests to build directory
# This ensures both CLI and CLion can access the same files relative to the test executable
# Using configure_file ensures files are copied when they change between builds
set(INTEGRATION_TEST_FILES
    "src/config.cpp"
    "src_assets/common/assets/web/config.html"
    "docs/configuration.md"
    "src_assets/common/assets/web/public/assets/locale/en.json"
    "src_assets/common/assets/web/configs/tabs/General.vue"
)

foreach(file ${INTEGRATION_TEST_FILES})
    configure_file(
        "${CMAKE_SOURCE_DIR}/${file}"
        "${CMAKE_CURRENT_BINARY_DIR}/${file}"
        COPYONLY
    )
endforeach()

# Copy all locale files for locale consistency tests
# Use a custom command to properly handle both adding and removing files
set(LOCALE_SRC_DIR "${CMAKE_SOURCE_DIR}/src_assets/common/assets/web/public/assets/locale")
set(LOCALE_DST_DIR "${CMAKE_CURRENT_BINARY_DIR}/src_assets/common/assets/web/public/assets/locale")
add_custom_target(sync_locale_files ALL
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${LOCALE_DST_DIR}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${LOCALE_DST_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${LOCALE_SRC_DIR}" "${LOCALE_DST_DIR}"
    COMMENT "Synchronizing locale files for tests"
    VERBATIM
)

foreach(dep ${SUNSHINE_TARGET_DEPENDENCIES})
    add_dependencies(${PROJECT_NAME} ${dep})  # compile these before sunshine
endforeach()

# Ensure locale files are synchronized before building the test executable
add_dependencies(${PROJECT_NAME} sync_locale_files)

# Build the list of libraries to link
set(TEST_LINK_LIBRARIES
    ${SUNSHINE_EXTERNAL_LIBRARIES}
    lizardbyte::test_support
    ${PLATFORM_LIBRARIES}
)

if(SUNSHINE_ENABLE_TRAY)
    list(APPEND TEST_LINK_LIBRARIES
            sunshine_tray_test_helpers)
    if(SUNSHINE_TRAY_TEST_QT_GUI_TARGET)
        list(APPEND TEST_LINK_LIBRARIES
                ${SUNSHINE_TRAY_TEST_QT_GUI_TARGET})
    endif()
endif()


target_link_libraries(${PROJECT_NAME} ${TEST_LINK_LIBRARIES})
target_compile_definitions(${PROJECT_NAME} PUBLIC ${SUNSHINE_DEFINITIONS} ${TEST_DEFINITIONS})
target_compile_options(${PROJECT_NAME} PRIVATE $<$<COMPILE_LANGUAGE:CXX>:${SUNSHINE_COMPILE_OPTIONS}>)
target_link_options(${PROJECT_NAME} PRIVATE ${SUNSHINE_LINK_OPTIONS})

