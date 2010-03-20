#!/usr/local/bin/lua

local command_line = require("luarocks.command_line")

program_name = "luarocks-admin"
program_description = "LuaRocks repository administration interface"

commands = {
}

commands.help = require("luarocks.help")
commands.make_manifest = require("luarocks.make_manifest")
commands.add = require("luarocks.add")
commands.refresh_cache = require("luarocks.refresh_cache")

command_line.run_command(...)
