--- LuaRocks public programmatic API, version 3.0
local luarocks = {}

local cfg = require("luarocks.core.cfg")
local list = require("luarocks.cmd.list")

--- Obtain version of LuaRocks and its API.
-- @return (string, string) Full version of this LuaRocks instance
-- (in "x.y.z" format for releases, or "dev" for a checkout of
-- in-development code), and the API version, in "x.y" format.
function luarocks.version()
   return cfg.program_version, cfg.program_series
end

--- Return 1
function luarocks.test_func()
	return 1
end

--- Print the list of installed rocks
local list = require("luarocks.cmd.list")
flags = {}
function luarocks.list(flags)
       list.command(flags)
end


return luarocks
