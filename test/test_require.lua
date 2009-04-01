#!/usr/bin/env lua

local luarocks = require("luarocks.require")

luarocks.set_context("cgilua", "cvs-2")

print(package.path)

print(package.cpath)

local socket = require("socket")
if not socket then os.exit(1) end
print(socket, socket._VERSION)

local socket2 = require("socket")
if not socket2 then os.exit(1) end
print(socket2, socket2._VERSION)

local mime = require("mime")
if not mime then os.exit(1) end
print(mime, mime._VERSION)

local socket = require("lfs")
if not lfs then os.exit(1) end
print(lfs, lfs._VERSION)
