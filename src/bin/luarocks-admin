#!/usr/bin/env lua

-- Load cfg first so that luarocks.loader knows it is running inside LuaRocks
local cfg = require("luarocks.core.cfg")

local loader = require("luarocks.loader")
local cmd = require("luarocks.cmd")

local description = "LuaRocks repository administration interface"

local commands = {
   make_manifest = "luarocks.admin.cmd.make_manifest",
   add = "luarocks.admin.cmd.add",
   remove = "luarocks.admin.cmd.remove",
   refresh_cache = "luarocks.admin.cmd.refresh_cache",
}

cmd.run_command(description, commands, "luarocks.admin.cmd.external", ...)
