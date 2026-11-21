#
# Loads the pre-compiled FFmpeg static libraries for macOS on Apple silicon.
#
# The archive is the LizardByte build-deps release below. It is kept in
# third-party/ffmpeg so that a build needs no download. Set
# FFMPEG_PREPARED_BINARIES to use another extracted FFmpeg instead.
#
include_guard(GLOBAL)

set(FFMPEG_RELEASE_TAG "v2026.724.203728")
set(FFMPEG_ARCHIVE "${CMAKE_SOURCE_DIR}/third-party/ffmpeg/Darwin-arm64-ffmpeg.tar.gz")

if(NOT DEFINED FFMPEG_PREPARED_BINARIES)
    set(FFMPEG_EXTRACT_DIR "${CMAKE_BINARY_DIR}/_deps")
    set(FFMPEG_PREPARED_BINARIES "${FFMPEG_EXTRACT_DIR}/ffmpeg")

    if(NOT EXISTS "${FFMPEG_PREPARED_BINARIES}/lib/libavcodec.a")
        if(NOT EXISTS "${FFMPEG_ARCHIVE}")
            message(FATAL_ERROR "Missing ${FFMPEG_ARCHIVE}. Download Darwin-arm64-ffmpeg.tar.gz from "
                    "https://github.com/LizardByte/build-deps/releases/tag/${FFMPEG_RELEASE_TAG}")
        endif()
        message(STATUS "Extracting FFmpeg ${FFMPEG_RELEASE_TAG} to ${FFMPEG_EXTRACT_DIR}")
        file(ARCHIVE_EXTRACT INPUT "${FFMPEG_ARCHIVE}" DESTINATION "${FFMPEG_EXTRACT_DIR}")  # cmake-lint: disable=E1126
        if(NOT EXISTS "${FFMPEG_PREPARED_BINARIES}/lib/libavcodec.a")
            message(FATAL_ERROR "FFmpeg extraction failed or unexpected directory structure")
        endif()
    endif()
endif()
message(STATUS "Using FFmpeg at ${FFMPEG_PREPARED_BINARIES}")

set(FFMPEG_LIBRARIES
    "${FFMPEG_PREPARED_BINARIES}/lib/libavcodec.a"
    "${FFMPEG_PREPARED_BINARIES}/lib/libswscale.a"
    "${FFMPEG_PREPARED_BINARIES}/lib/libavutil.a"
    "${FFMPEG_PREPARED_BINARIES}/lib/libcbs.a"
)
foreach(optional_library SvtAv1Enc x264 x265 hdr10plus)
    if(EXISTS "${FFMPEG_PREPARED_BINARIES}/lib/lib${optional_library}.a")
        list(APPEND FFMPEG_LIBRARIES "${FFMPEG_PREPARED_BINARIES}/lib/lib${optional_library}.a")
    endif()
endforeach()

set(FFMPEG_INCLUDE_DIRS "${FFMPEG_PREPARED_BINARIES}/include")
