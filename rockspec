package = "LuaRocks"
local VER = "2.2.0"
local REV = "1"
version = VER.."-"..REV

description = {
   summary = "A deployment and management system for Lua modules.",
   detailed = [[
      LuaRocks allows you to install Lua modules as self-contained
      packages called "rocks", which also contain version dependency
      information. This information is used both during installation,
      so that when one rock is requested all rocks it depends on are
      installed as well, and at run time, so that when a module is
      required, the correct version is loaded. LuaRocks supports both
      local and remote repositories, and multiple local rocks trees. 
   ]],
   license = "MIT/X11",
   homepage = "http://www.luarocks.org",
   maintainer = "Hisham Muhammad"
}

dependencies = {
   "lua >= 5.1"
}

source = {
   url = "http://luarocks.org/releases/luarocks-"..VER..".tar.gz",
}

build = {
   type = "make",
   install_target = "install_rock",
   build_pass=false,
   install_variables = {
      BINDIR="$(BINDIR)",
      LUADIR="$(LUADIR)"
   }
}
