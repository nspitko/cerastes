cmake_minimum_required(VERSION 3.10)

set(TARGET_NAME cerastes)
set(TARGET_EXT .hdll)

project(${TARGET_NAME})

file(GLOB SOURCES "*.cpp")
#file(GLOB LIB_SOURCES "lib/*.cpp" "lib/glad/src/*.c")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(${TARGET_NAME}${TARGET_EXT} SHARED ${SOURCES} ${LIB_SOURCES})

set_target_properties(${TARGET_NAME}${TARGET_EXT}
    PROPERTIES
    PREFIX ""
    OUTPUT_NAME ${TARGET_NAME}
    SUFFIX ${TARGET_EXT}
)

# glfw
#add_subdirectory(lib/glfw/)
#include_directories(lib/glfw/include)
#include_directories(lib/glad/include)

IF (WIN32)
	target_include_directories(${TARGET_NAME}${TARGET_EXT} PUBLIC $ENV{HASHLINKPATH}/include lib/ )
	#target_link_libraries(${TARGET_NAME}${TARGET_EXT} $ENV{HASHLINKPATH}/libhl.lib glfw ${GLFW_LIBRARIES})
	target_link_libraries(${TARGET_NAME}${TARGET_EXT} $ENV{HASHLINKPATH}/libhl.lib)
ELSEIF (APPLE)
	find_library(APPLICATION_SERVICES_FRAMEWORK ApplicationServices REQUIRED)
	set(HLPATH /usr/local/opt/hashlink/libexec)
	target_include_directories(${TARGET_NAME}${TARGET_EXT} PUBLIC ${HLPATH}/include)
	target_link_libraries(${TARGET_NAME}${TARGET_EXT} ${HLPATH}/lib/libhl.dylib ${APPLICATION_SERVICES_FRAMEWORK})
ELSE()
	target_link_libraries(${TARGET_NAME}${TARGET_EXT} hl)
ENDIF()

add_custom_command(TARGET ${TARGET_NAME}${TARGET_EXT} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${TARGET_NAME}${TARGET_EXT}> ../..
)
