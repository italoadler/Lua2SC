PROJECT(random C)
cmake_minimum_required(VERSION 2.8)

add_definitions(-DLUA_BUILD_AS_DLL -DLUA_LIB)
INCLUDE_DIRECTORIES(${LUA_INCLUDE_DIR})

ADD_LIBRARY(random SHARED random.c lrandom.c)
set_target_properties(random PROPERTIES PREFIX "")
TARGET_LINK_LIBRARIES(random ${LUA_LIBRARY})

INSTALL (TARGETS random RUNTIME DESTINATION luabin)