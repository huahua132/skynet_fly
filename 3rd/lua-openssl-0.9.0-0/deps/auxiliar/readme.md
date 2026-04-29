# lua-auxiliar

## Introduce

The origin auxiliar is part of [luasocket](https://github.com/diegonehab/luasocket), it's a general purpose class implemention lib for userdata with metatable.

```
/*=========================================================================*\
* Auxiliar routines for class hierarchy manipulation
* LuaSocket toolkit (but completely independent of other LuaSocket modules)
*
* A LuaSocket class is a name associated with Lua metatables. A LuaSocket
* group is a name associated with a class. A class can belong to any number
* of groups. This module provides the functionality to:
*
*   - create new classes
*   - add classes to groups
*   - set the class of objects
*   - check if an object belongs to a given class or group
*   - get the userdata associated to objects
*   - print objects in a pretty way
*
* LuaSocket class names follow the convention <module>{<class>}. Modules
* can define any number of classes and groups. The module tcp.c, for
* example, defines the classes tcp{master}, tcp{client} and tcp{server} and
* the groups tcp{client,server} and tcp{any}. Module functions can then
* perform type-checking on their arguments by either class or group.
*
* LuaSocket metatables define the __index metamethod as being a table. This
* table has one field for each method supported by the class, and a field
* "class" with the class name.
*
* The mapping from class name to the corresponding metatable and the
* reverse mapping are done using lauxlib.
\*=========================================================================*/
```

## Update

I do minimual change, and add a few APIs for [lui](https://github.com/zhaozg/lui) and [lua-openssl](https://github.com/zhaozg/lua-openssl).
TODO more

## License
```text
LuaSocket 3.0 license
Copyright © 2004-2018 Diego Nehab

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```
