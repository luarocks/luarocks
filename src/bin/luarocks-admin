#!/usr/bin/env lua

-- this should be loaded first.
local cfg = require("luarocks.core.cfg")

local loader = require("luarocks.loader")
local command_line = require("luarocks.command_line")

program_description = "LuaRocks repository administration interface"

commands = {
   help = "luarocks.cmd.help",
   make_manifest = "luarocks.admin.cmd.make_manifest",
   add = "luarocks.admin.cmd.add",
   remove = "luarocks.admin.cmd.remove",
   refresh_cache = "luarocks.admin.cmd.refresh_cache",
}

command_line.run_command(...)
