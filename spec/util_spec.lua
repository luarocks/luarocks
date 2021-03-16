local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

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

test_env.unload_luarocks()
local util = require("luarocks.util")
local core_util = require("luarocks.core.util")

describe("luarocks.util #unit", function()
   local runner

   setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
      runner.tick = true
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

   describe("core.util.show_table", function()
      it("returns a pretty-printed string containing the representation of the given table", function()
         local result

         local t1 = {1, 2, 3}
         result = core_util.show_table(t1)
         assert.truthy(result:find("[1] = 1", 1, true))
         assert.truthy(result:find("[2] = 2", 1, true))
         assert.truthy(result:find("[3] = 3", 1, true))

         local t2 = {a = 1, b = 2, c = 3}
         result = core_util.show_table(t2)
         assert.truthy(result:find("[\"a\"] = 1", 1, true))
         assert.truthy(result:find("[\"b\"] = 2", 1, true))
         assert.truthy(result:find("[\"c\"] = 3", 1, true))

         local t3 = {a = 1, b = "2", c = {3}}
         result = core_util.show_table(t3)
         assert.truthy(result:find("[\"a\"] = 1", 1, true))
         assert.truthy(result:find("[\"b\"] = \"2\"", 1, true))
         assert.truthy(result:find("[\"c\"] = {", 1, true))
         assert.truthy(result:find("[1] = 3", 1, true))

         local t4 = {a = 1, b = {c = 2, d = {e = "4"}}}
         result = core_util.show_table(t4)
         assert.truthy(result:find("[\"a\"] = 1", 1, true))
         assert.truthy(result:find("[\"b\"] = {", 1, true))
         assert.truthy(result:find("[\"c\"] = 2", 1, true))
         assert.truthy(result:find("[\"d\"] = {", 1, true))
         assert.truthy(result:find("[\"e\"] = \"4\"", 1, true))
      end)
   end)

   describe("core.util.cleanup_path", function()
     it("does not change order of existing items of prepended path", function()
        local sys_path = '/usr/local/bin;/usr/bin'
        local lr_path = '/home/user/.luarocks/bin;/usr/bin'
        local path = lr_path .. ';' .. sys_path

        local result = core_util.cleanup_path(path, ';', '5.3', false)
        assert.are.equal('/home/user/.luarocks/bin;/usr/local/bin;/usr/bin', result)
     end)

     it("does not change order of existing items of appended path", function()
        local sys_path = '/usr/local/bin;/usr/bin'
        local lr_path = '/home/user/.luarocks/bin;/usr/bin'
        local path = sys_path .. ';' .. lr_path

        local result = core_util.cleanup_path(path, ';', '5.3', true)
        assert.are.equal('/usr/local/bin;/usr/bin;/home/user/.luarocks/bin', result)
     end)

     it("rewrites versions that do not match the provided version", function()
        local expected = 'a/b/lua/5.3/?.lua;a/b/c/lua/5.3/?.lua'
        local result = core_util.cleanup_path('a/b/lua/5.2/?.lua;a/b/c/lua/5.3/?.lua', ';', '5.3')
        assert.are.equal(expected, result)
     end)

     it("does not rewrite versions for which the provided version is a substring", function()
        local expected = 'a/b/lua/5.3/?.lua;a/b/c/lua/5.3.4/?.lua'
        local result = core_util.cleanup_path('a/b/lua/5.2/?.lua;a/b/c/lua/5.3.4/?.lua', ';', '5.3')
        assert.are.equal(expected, result)
     end)
   end)
end)
