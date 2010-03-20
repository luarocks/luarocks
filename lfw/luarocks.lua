#!/usr/local/bin/lua

local command_line = require("luarocks.command_line")

program_name = "luarocks"
program_description = "LuaRocks main command-line interface"

commands = {}
commands.help = require("luarocks.help")
commands.pack = require("luarocks.pack")
commands.unpack = require("luarocks.unpack")
commands.build = require("luarocks.build")
commands.install = require("luarocks.install")
commands.search = require("luarocks.search")
commands.list = require("luarocks.list")
commands.remove = require("luarocks.remove")
commands.make = require("luarocks.make")
commands.download = require("luarocks.download")

command_line.run_command(...)
