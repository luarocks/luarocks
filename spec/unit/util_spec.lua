local test_env = require("spec.util.test_env")
local testing_paths = test_env.testing_paths
local P = test_env.P

local util = require("luarocks.util")
local core_util = require("luarocks.core.util")

describe("luarocks.util #unit", function()
   local runner

   lazy_setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

   describe("util.variable_substitutions", function()
      it("replaces variables", function()
         local t = {
            ["hello"] = "$(KIND) world",
         }
         util.variable_substitutions(t, {
            ["KIND"] = "happy",
         })
         assert.are.same({
            ["hello"] = "happy world",
         }, t)
      end)

      it("missing variables are empty", function()
         local t = {
            ["hello"] = "$(KIND) world",
         }
         util.variable_substitutions(t, {
         })
         assert.are.same({
            ["hello"] = " world",
         }, t)
      end)
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
         local sys_path = P'/usr/local/bin;/usr/bin'
         local lr_path = P'/home/user/.luarocks/bin;/usr/bin'
         local path = lr_path .. ';' .. sys_path

         local result = core_util.cleanup_path(path, ';', '5.3', false)
         assert.are.equal(P'/home/user/.luarocks/bin;/usr/local/bin;/usr/bin', result)
      end)

      it("does not change order of existing items of appended path", function()
         local sys_path = P'/usr/local/bin;/usr/bin'
         local lr_path = P'/home/user/.luarocks/bin;/usr/bin'
         local path = sys_path .. ';' .. lr_path

         local result = core_util.cleanup_path(path, ';', '5.3', true)
         assert.are.equal(P'/usr/local/bin;/usr/bin;/home/user/.luarocks/bin', result)
      end)

      it("rewrites versions that do not match the provided version", function()
         local expected = P'a/b/lua/5.3/?.lua;a/b/c/lua/5.3/?.lua'
         local result = core_util.cleanup_path(P'a/b/lua/5.2/?.lua;a/b/c/lua/5.3/?.lua', ';', '5.3')
         assert.are.equal(expected, result)
      end)

      it("does not rewrite versions for which the provided version is a substring", function()
         local expected = P'a/b/lua/5.3/?.lua;a/b/c/lua/5.3.4/?.lua'
         local result = core_util.cleanup_path(P'a/b/lua/5.2/?.lua;a/b/c/lua/5.3.4/?.lua', ';', '5.3')
         assert.are.equal(expected, result)
      end)
   end)
end)
