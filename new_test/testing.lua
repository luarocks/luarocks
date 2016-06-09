#!/usr/bin/env lua
local test_env = require("./test_environment")

local rocks = {"/luacov-coveralls-0.1.1-1.src.rock",
   "/luasec-0.6-1.rockspec",
   "/luacov-0.11.0-1.rockspec",
   "/luacov-0.11.0-1.src.rock",
   "/luasocket-3.0rc1-1.src.rock",
   "/luasocket-3.0rc1-1.rockspec",
   "/luafilesystem-1.6.3-1.src.rock",
   "/luabitop-1.0.2-1.rockspec",
   "/luabitop-1.0.2-1.src.rock",
   "/luadoc-3.0.1-1.src.rock",
   "/lualogging-1.3.0-1.src.rock",
   "/stdlib-41.0.0-1.src.rock"
}

test_env.main(rocks)