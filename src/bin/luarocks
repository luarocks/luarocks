#!/usr/bin/env lua

-- Load cfg first so that the loader knows it is running inside LuaRocks
local cfg = require("luarocks.core.cfg")

local loader = require("luarocks.loader")
local cmd = require("luarocks.cmd")

local description = "LuaRocks main command-line interface"

local commands = {
   init = "luarocks.cmd.init",
   pack = "luarocks.cmd.pack",
   unpack = "luarocks.cmd.unpack",
   build = "luarocks.cmd.build",
   install = "luarocks.cmd.install",
   search = "luarocks.cmd.search",
   list = "luarocks.cmd.list",
   remove = "luarocks.cmd.remove",
   make = "luarocks.cmd.make",
   download = "luarocks.cmd.download",
   path = "luarocks.cmd.path",
   show = "luarocks.cmd.show",
   new_version = "luarocks.cmd.new_version",
   lint = "luarocks.cmd.lint",
   write_rockspec = "luarocks.cmd.write_rockspec",
   purge = "luarocks.cmd.purge",
   doc = "luarocks.cmd.doc",
   upload = "luarocks.cmd.upload",
   config = "luarocks.cmd.config",
   which = "luarocks.cmd.which",
   test = "luarocks.cmd.test",
}

cmd.run_command(description, commands, "luarocks.cmd.external", ...)
