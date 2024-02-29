local test_env = require("spec.util.test_env")
local run = test_env.run

test_env.setup_specs()

describe("luarocks.loader", function()
   describe("#unit", function()
      it("starts", function()
         assert(run.lua_bool([[-e "require 'luarocks.loader'; print(package.loaded['luarocks.loaded'])"]]))
      end)

      describe("which", function()
         it("finds modules using package.path", function()
            assert(run.lua_bool([[-e "loader = require 'luarocks.loader'; local x,y,z,p = loader.which('luarocks.loader', 'p'); assert(p == 'p')"]]))
         end)
      end)
   end)
end)
