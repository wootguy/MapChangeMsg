cmake_minimum_required(VERSION 3.6)

project(MapChangeMsg)

set(SOURCE_FILES
	src/main.cpp
)

add_library(${PROJECT_NAME} SHARED)
add_subdirectory(mmlib)
mmlib_default_setup()
