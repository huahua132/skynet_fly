# Locate Lua library
# This module defines
#  LUAJIT_FOUND, if false, do not try to link to Lua
#  LUAJIT_LIBRARIES
#  LUAJIT_INCLUDE_DIRS, where to find lua.h
#
# Note that the expected include convention is
#  #include "lua.h"
# and not
#  #include <lua/lua.h>
# This is because, the lua location is not standardized and may exist
# in locations other than lua/

#=============================================================================
# Copyright 2007-2009 Kitware, Inc.
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distributed this file outside of CMake, substitute the full
#  License text for the above reference.)
#
# ################
# 2010 - modified for cronkite to find luajit instead of lua, as it was before.
#

FIND_PATH(LUAJIT_INCLUDE_DIRS lua.h
    PATHS
        /usr/local/include/luajit-2.0
        /usr/local/include/luajit2.0
        /usr/local/include/luajit-2.1
        /usr/local/include/luajit2.1
        /usr/local/include/luajit
        /usr/include/luajit-2.0
        /usr/include/luajit2.0
        /usr/include/luajit-2.1
        /usr/include/luajit2.1
        /usr/include/luajit
        /opt/include/luajit-2.0
        /opt/include/luajit2.0
        /opt/include/luajit-2.1
        /opt/include/luajit2.1
        /opt/include/luajit
    NO_DEFAULT_PATH
)

FIND_LIBRARY(LUAJIT_LIBRARY
    NAMES luajit-51 luajit-5.1 luajit
    HINTS $ENV{LUAJIT_ROOT_DIR}
    PATH_SUFFIXES lib64 lib
    PATHS
        ~/Library/Frameworks
        /Library/Frameworks
        /usr/local
        /usr
        /sw
        /opt/local
        /opt/csw
        /opt
)

IF(LUAJIT_LIBRARY)
    # include the math library for Unix
    IF(UNIX AND NOT APPLE)
        FIND_LIBRARY(LUAJIT_MATH_LIBRARY m)
        SET(LUAJIT_LIBRARIES "${LUAJIT_LIBRARY};${LUAJIT_MATH_LIBRARY}"
            CACHE STRING "Lua Libraries")
        # For Windows and Mac, don't need to explicitly include the math library
    ELSE()
        SET(LUAJIT_LIBRARIES "${LUAJIT_LIBRARY}" CACHE STRING "Lua Libraries")
    ENDIF()
    SET(LUA_INCLUDE_DIRS ${LUAJIT_INCLUDE_DIRS})
    SET(LUA_LIBRARIES ${LUAJIT_LIBRARIES})
    SET(LUA_VERSION_MAJOR  "5")
    SET(LUA_VERSION_MINOR "1")
    SET(LUAJIT_FOUND ON)
ELSE()
    SET(LUAJIT_FOUND OFF)
ENDIF()

INCLUDE(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LUAJIT_FOUND to TRUE if
# all listed variables are TRUE
FIND_PACKAGE_HANDLE_STANDARD_ARGS(LuaJIT DEFAULT_MSG
    LUAJIT_LIBRARIES LUAJIT_INCLUDE_DIRS)

MARK_AS_ADVANCED(LUAJIT_INCLUDE_DIRS LUAJIT_LIBRARIES LUAJIT_LIBRARY
    LUAJIT_MATH_LIBRARY)
