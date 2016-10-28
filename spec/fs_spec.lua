local test_env = require("test/test_environment")

test_env.unload_luarocks()
local fs = require("luarocks.fs")
local is_win = test_env.TEST_TARGET_OS == "windows"

describe("Luarocks fs test #whitebox #w_fs", function()
   describe("fs.Q", function()
      it("simple argument", function()
         assert.are.same(is_win and '"foo"' or "'foo'", fs.Q("foo"))
      end)

      it("argument with quotes", function()
         assert.are.same(is_win and [["it's \"quoting\""]] or [['it'\''s "quoting"']], fs.Q([[it's "quoting"]]))
      end)

      it("argument with special characters", function()
         assert.are.same(is_win and [["\\"%" \\\\" \\\\\\"]] or [['\% \\" \\\']], fs.Q([[\% \\" \\\]]))
      end)
   end)
end)
