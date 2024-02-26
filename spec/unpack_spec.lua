local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

local extra_rocks = {
   "/cprint-${CPRINT}.src.rock",
   "/cprint-${CPRINT}.rockspec",
   "/luazip-1.2.4-1.rockspec"
}

describe("luarocks unpack #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   describe("basic fail tests", function()
      it("with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("unpack"))
      end)

      it("with invalid rockspec", function()
         assert.is_false(run.luarocks_bool("unpack invalid.rockspec"))
      end)

      it("with invalid patch", function()
         assert.is_false(run.luarocks_bool("unpack " .. testing_paths.fixtures_dir .. "/invalid_patch-0.1-1.rockspec"))
      end)
   end)

   describe("more complex tests", function()
      it("download", function()
         assert.is_true(run.luarocks_bool("unpack cprint"))
         test_env.remove_dir("cprint-${CPRINT}")
      end)

      it("src", function()
         assert.is_true(run.luarocks_bool("download --source cprint"))
         assert.is_true(run.luarocks_bool("unpack cprint-${CPRINT}.src.rock"))
         os.remove("cprint-${CPRINT}.src.rock")
         test_env.remove_dir("cprint-${CPRINT}")
      end)

      it("src", function()
         assert.is_true(run.luarocks_bool("download --rockspec cprint"))
         assert.is_true(run.luarocks_bool("unpack cprint-${CPRINT}.rockspec"))
         os.remove("cprint-${CPRINT}.rockspec")
         os.remove("lua-cprint")
         test_env.remove_dir("cprint-${CPRINT}")
      end)

      -- #595 luarocks unpack of a git:// rockspec fails to copy the rockspec
      it("git:// rockspec", function()
         assert.is_true(run.luarocks_bool("download --rockspec luazip"))
         assert.is_true(run.luarocks_bool("unpack luazip-1.2.4-1.rockspec"))
         assert.is_truthy(lfs.attributes("luazip-1.2.4-1/luazip/luazip-1.2.4-1.rockspec"))
         test_env.remove_dir("luazip-1.2.4-1")
      end)

      it("binary", function()
         assert.is_true(run.luarocks_bool("build cprint"))
         assert.is_true(run.luarocks_bool("pack cprint"))
         assert.is_true(run.luarocks_bool("unpack cprint-${CPRINT}." .. test_env.platform .. ".rock"))
         test_env.remove_dir("cprint-${CPRINT}")
         os.remove("cprint-${CPRINT}." .. test_env.platform .. ".rock")
      end)
   end)
end)
