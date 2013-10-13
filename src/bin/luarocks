#!/usr/bin/env lua

local command_line = require("luarocks.command_line")

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
commands.path = require("luarocks.path")
commands.show = require("luarocks.show")
commands.new_version = require("luarocks.new_version")
commands.lint = require("luarocks.lint")
commands.write_rockspec = require("luarocks.write_rockspec")
commands.purge = require("luarocks.purge")

command_line.run_command(...)
