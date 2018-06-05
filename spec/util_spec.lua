local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths
local env_variables = test_env.env_variables

describe("Basic tests #integration", function()

   before_each(function()
      test_env.setup_specs()
   end)

   it("LuaRocks version", function()
      assert.is_true(run.luarocks_bool("--version"))
   end)

   it("LuaRocks unknown command", function()
      assert.is_false(run.luarocks_bool("unknown_command"))
   end)

   it("LuaRocks arguments fail", function()
      assert.is_false(run.luarocks_bool("--porcelain=invalid"))
      assert.is_false(run.luarocks_bool("--invalid-flag"))
      assert.is_false(run.luarocks_bool("--server"))
      assert.is_false(run.luarocks_bool("--server --porcelain"))
      assert.is_false(run.luarocks_bool("--invalid-flag=abc"))
      assert.is_false(run.luarocks_bool("invalid=5"))
   end)

   it("LuaRocks execute from not existing directory #unix", function()
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

   it("LuaRocks timeout", function()
      assert.is.truthy(run.luarocks("--timeout=10"))
   end)
   
   it("LuaRocks timeout invalid", function()
      assert.is_false(run.luarocks_bool("--timeout=abc"))
   end)

   it("LuaRocks only server=testing", function()
      assert.is.truthy(run.luarocks("--only-server=testing"))
   end)

   it("#only LuaRocks test site config", function()
      local scname = testing_paths.src_dir .. "/luarocks/core/site_config_"..test_env.lua_version:gsub("%.", "_")..".lua"
   
      assert.is.truthy(os.rename(scname, scname..".tmp"))
      assert.is.falsy(lfs.attributes(scname))
      assert.is.truthy(lfs.attributes(scname..".tmp"))

      assert.is.truthy(run.luarocks(""))
      
      assert.is.truthy(os.rename(scname..".tmp", scname))
      assert.is.falsy(lfs.attributes(scname..".tmp"))
      assert.is.truthy(lfs.attributes(scname))
   end)

end)

test_env.unload_luarocks()
local util = require("luarocks.util")

describe("Luarocks util test #unit", function()
   local runner
   
   setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)
   
   teardown(function()
      runner.shutdown()
   end)
   
   describe("util.sortedpairs", function()
      local function collect(iter, state, var)
         local collected = {}

         while true do
            local returns = {iter(state, var)}

            if returns[1] == nil then
               return collected
            else
               table.insert(collected, returns)
               var = returns[1]
            end
         end
      end

      it("default sort", function()
         assert.are.same({}, collect(util.sortedpairs({})))
         assert.are.same({
            {1, "v1"},
            {2, "v2"},
            {3, "v3"},
            {"bar", "v5"},
            {"foo", "v4"}
         }, collect(util.sortedpairs({"v1", "v2", "v3", foo = "v4", bar = "v5"})))
      end)

      it("sort by function", function()
         local function compare(a, b) return a > b end
         assert.are.same({}, collect(util.sortedpairs({}, compare)))
         assert.are.same({
            {3, "v3"},
            {2, "v2"},
            {1, "v1"}
         }, collect(util.sortedpairs({"v1", "v2", "v3"}, compare)))
      end)

      it("sort by priority table", function()
         assert.are.same({}, collect(util.sortedpairs({}, {"k1", "k2"})))
         assert.are.same({
            {"k3", "v3"},
            {"k2", "v2", {"sub order"}},
            {"k1", "v1"},
            {"k4", "v4"},
            {"k5", "v5"},
         }, collect(util.sortedpairs({
            k1 = "v1", k2 = "v2", k3 = "v3", k4 = "v4", k5 = "v5"
         }, {"k3", {"k2", {"sub order"}}, "k1"})))
      end)
   end)
end)
