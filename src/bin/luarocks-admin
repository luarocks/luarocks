#!/usr/bin/env lua

-- this should be loaded first.
local cfg = require("luarocks.cfg")

local loader = require("luarocks.loader")
local command_line = require("luarocks.command_line")

program_description = "LuaRocks repository administration interface"

commands = {
   help = "luarocks.help",
   make_manifest = "luarocks.make_manifest",
   add = "luarocks.add",
   remove = "luarocks.admin_remove",
   refresh_cache = "luarocks.refresh_cache",
}

command_line.run_command(...)
