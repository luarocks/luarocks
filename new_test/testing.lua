#!/usr/bin/env lua
local test_enviroment = require("new_test/test_enviroment")

print(arg[1])
-- test_utils = test_enviroment.main(arg)
test_enviroment.execute_bool("busted")
