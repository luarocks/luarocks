local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run

describe("Basic tests #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   it("--version", function()
      assert.is_true(run.luarocks_bool("--version"))
   end)

   it("unknown command", function()
      assert.is_false(run.luarocks_bool("unknown_command"))
   end)

   it("arguments fail", function()
      assert.is_false(run.luarocks_bool("--porcelain=invalid"))
      assert.is_false(run.luarocks_bool("--invalid-flag"))
      assert.is_false(run.luarocks_bool("--server"))
      assert.is_false(run.luarocks_bool("--server --porcelain"))
      assert.is_false(run.luarocks_bool("--invalid-flag=abc"))
      assert.is_false(run.luarocks_bool("invalid=5"))
   end)

   it("executing from not existing directory #unix", function()
      local main_path = lfs.currentdir()
      assert.is_true(lfs.mkdir("idontexist"))
      assert.is_true(lfs.chdir("idontexist"))
      local delete_path = lfs.currentdir()
      assert.is_true(os.remove(delete_path))

      local output = run.luarocks("")
      assert.is.falsy(output:find("the Lua package manager"))
      assert.is_true(lfs.chdir(main_path))

      output = run.luarocks("")
      assert.is.truthy(output:find("the Lua package manager"))
   end)

   it("--timeout", function()
      assert.is.truthy(run.luarocks("--timeout=10"))
   end)

   it("--timeout invalid", function()
      assert.is_false(run.luarocks_bool("--timeout=abc"))
   end)

   it("--only-server", function()
      assert.is.truthy(run.luarocks("--only-server=testing"))
   end)

end)
