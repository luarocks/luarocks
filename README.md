This is LuaRocks, a deployment and management system for Lua modules.

Main website: [luarocks.org](http://www.luarocks.org)

LuaRocks allows you to install Lua modules as self-contained packages called [*rocks*][1],
which also contain version [dependency][2] information. This information is used both during installation,
so that when one rock is requested all rocks it depends on are installed as well, and at run time,
so that when a module is required, the correct version is loaded. LuaRocks supports both local and
[remote][3] repositories, and multiple local rocks trees. You can [download][4] and install LuaRocks
on [Unix][5] and [Windows][6].

LuaRocks is free software and uses the same [license][7] as Lua 5.1.

[1]: http://luarocks.org/en/Types_of_rocks
[2]: http://luarocks.org/en/Dependencies
[3]: http://luarocks.org/en/Rocks_repositories
[4]: http://luarocks.org/en/Download
[5]: http://luarocks.org/en/Installation_instructions_for_Unix
[6]: http://luarocks.org/en/Installation_instructions_for_Windows
[7]: http://luarocks.org/en/License
