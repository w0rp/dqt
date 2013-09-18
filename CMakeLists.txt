project(smoke_cwrapper)

cmake_minimum_required(VERSION 2.8)

find_package(Smoke REQUIRED)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${SMOKE_CMAKE_MODULE_DIR}")

include_directories(${CMAKE_CURRENT_SOURCE_DIR} ${SMOKE_INCLUDE_DIR})

set(LIB_TYPE SHARED)

set(SOURCE
    ${SOURCE}
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/smoke_cwrapper.cpp
)

set(HEADERS
   ${HEADERS}
   ${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/smoke_cwrapper.h
)

add_library(smoke_cwrapper ${LIB_TYPE}
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/smoke_cwrapper.cpp
)

find_library(SMOKE_BASE_LIB_NAMES
    NAMES smokebase
    PATHS "${SMOKE_INSTALL_PREFIX}/lib"
)

find_library(SMOKE_QTCORE_LIB_NAMES
    NAMES smokeqtcore
    PATHS "${SMOKE_INSTALL_PREFIX}/lib"
)

find_library(SMOKE_QTGUI_LIB_NAMES
    NAMES smokeqtgui
    PATHS "${SMOKE_INSTALL_PREFIX}/lib"
)

target_link_libraries(smoke_cwrapper
    ${SMOKE_BASE_LIB_NAMES}
    ${SMOKE_QTCORE_LIB_NAMES}
    ${SMOKE_QTGUI_LIB_NAMES}
)
