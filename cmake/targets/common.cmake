# common target definitions
# this file will also load platform specific macros

if(APPLE AND NOT SUNSHINE_BUILD_HOMEBREW)
    add_executable(sunshine MACOSX_BUNDLE ${SUNSHINE_TARGET_FILES})
else()
    add_executable(sunshine ${SUNSHINE_TARGET_FILES})
endif()
foreach(dep ${SUNSHINE_TARGET_DEPENDENCIES})
    add_dependencies(sunshine ${dep})  # compile these before sunshine
endforeach()

# macOS definitions
include(${CMAKE_MODULE_PATH}/targets/unix.cmake)
include(${CMAKE_MODULE_PATH}/targets/macos.cmake)

target_link_libraries(sunshine ${SUNSHINE_EXTERNAL_LIBRARIES} ${EXTRA_LIBS})
target_compile_definitions(sunshine PUBLIC ${SUNSHINE_DEFINITIONS})

target_compile_options(sunshine PRIVATE $<$<COMPILE_LANGUAGE:CXX>:${SUNSHINE_COMPILE_OPTIONS}>)
target_link_options(sunshine PRIVATE ${SUNSHINE_LINK_OPTIONS})

# Homebrew build fails the vite build if we set these environment variables
if(${SUNSHINE_BUILD_HOMEBREW})
    set(NPM_SOURCE_ASSETS_DIR "")
    set(NPM_ASSETS_DIR "")
    set(NPM_BUILD_HOMEBREW "true")
else()
    set(NPM_SOURCE_ASSETS_DIR ${SUNSHINE_SOURCE_ASSETS_DIR})
    set(NPM_ASSETS_DIR ${CMAKE_BINARY_DIR})
    set(NPM_BUILD_HOMEBREW "")
endif()

#WebUI build
find_program(NPM npm REQUIRED)

set(NPM_INSTALL_FLAGS "--ignore-scripts")
if (NPM_OFFLINE)
    set(NPM_INSTALL_FLAGS "${NPM_INSTALL_FLAGS} --offline")
endif()

add_custom_target(web-ui ALL
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMENT "Installing NPM Dependencies and Building the Web UI"
        COMMAND "${NPM}" ci ${NPM_INSTALL_FLAGS}
        COMMAND "${CMAKE_COMMAND}" -E env "SUNSHINE_BUILD_HOMEBREW=${NPM_BUILD_HOMEBREW}" "SUNSHINE_SOURCE_ASSETS_DIR=${NPM_SOURCE_ASSETS_DIR}" "SUNSHINE_ASSETS_DIR=${NPM_ASSETS_DIR}" "${NPM}" run build  # cmake-lint: disable=C0301
        COMMAND_EXPAND_LISTS
        VERBATIM)

# tests
if(BUILD_TESTS)
    add_subdirectory(tests)
endif()

# custom compile flags, must be after adding tests

if (NOT BUILD_TESTS)
    set(TEST_DIR "")
else()
    set(TEST_DIR "${CMAKE_SOURCE_DIR}/tests")
endif()

# src/upnp
set_source_files_properties("${CMAKE_SOURCE_DIR}/src/upnp.cpp"
        DIRECTORY "${CMAKE_SOURCE_DIR}" "${TEST_DIR}"
        PROPERTIES COMPILE_FLAGS -Wno-pedantic)

# src/nvhttp
string(TOUPPER "x${CMAKE_BUILD_TYPE}" BUILD_TYPE)
if(NOT "${BUILD_TYPE}" STREQUAL "XDEBUG")
    add_definitions(-DNDEBUG)
endif()
