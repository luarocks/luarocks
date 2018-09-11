local test_env = require("spec.util.test_env")
local run = test_env.run

describe("luarocks.loader", function()
   describe("#unit", function()
      it("starts", function()
         assert(run.lua_bool([[-e "require 'luarocks.loader'; print(package.loaded['luarocks.loaded'])"]]))
      end)
   end)
end)
