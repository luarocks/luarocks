local test_env = require("spec.util.test_env")

test_env.unload_luarocks()
test_env.setup_specs()
local dir = require("luarocks.dir")

describe("Luarocks dir test #unit", function()
   
   describe("dir.is_basic_protocol", function()
      it("checks whether the arguments represent a valid protocol and returns the result of the check", function()
         assert.truthy(dir.is_basic_protocol("http"))
         assert.truthy(dir.is_basic_protocol("https"))
         assert.truthy(dir.is_basic_protocol("ftp"))
         assert.truthy(dir.is_basic_protocol("file"))
         assert.falsy(dir.is_basic_protocol("file", true))
         assert.falsy(dir.is_basic_protocol("invalid"))
      end)
   end)
end)
