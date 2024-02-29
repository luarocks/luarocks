
local rockspecs = require("luarocks.rockspecs")
local cfg = require("luarocks.core.cfg")
local test_env = require("spec.util.test_env")
local lfs = require("lfs")

describe("luarocks.rockspecs #unit", function()

   lazy_setup(function()
      cfg.init()
   end)

   it("auto adds a build dependency for non-vendored build types", function()
      local filename = "test-1.0-1.rockspec"
      local rockspec = {
         package = "test",
         source = {
            url = "",
         },
         build = {
            type = "foo"
         },
      }
      local globals = {}
      local quick = true

      local out = rockspecs.from_persisted_table(filename, rockspec, globals, quick)

      assert(rockspec == out)
      assert.same(rockspec.build_dependencies, {
         { name = "luarocks-build-foo", constraints = {} },
      })
   end)

   it("does not add a build dependency for non-vendored build type if it's already ther", function()
      local filename = "test-1.0-1.rockspec"
      local rockspec = {
         package = "test",
         source = {
            url = "",
         },
         build_dependencies = {
            "luarocks-build-cpp >= 1.0",
         },
         build = {
            type = "cpp"
         },
      }
      local globals = {}
      local quick = true

      local out = rockspecs.from_persisted_table(filename, rockspec, globals, quick)

      assert(rockspec == out)

      assert.same(rockspec.build_dependencies, {
         { name = "luarocks-build-cpp", constraints = { { op = ">=", version = { string = "1.0", 1, 0 } } } },
      })
   end)

   it("does not add a build dependency for 'none' build type", function()
      local filename = "test-1.0-1.rockspec"
      local rockspec = {
         package = "test",
         source = {
            url = "",
         },
         build = {
            type = "none"
         },
      }
      local globals = {}
      local quick = true

      local out = rockspecs.from_persisted_table(filename, rockspec, globals, quick)

      assert(rockspec == out)
      assert.same(rockspec.build_dependencies, {})
   end)

   it("does not add a build dependency for 'module' build type", function()
      local filename = "test-1.0-1.rockspec"
      local rockspec = {
         package = "test",
         source = {
            url = "",
         },
         build = {
            type = "none"
         },
      }
      local globals = {}
      local quick = true

      local out = rockspecs.from_persisted_table(filename, rockspec, globals, quick)

      assert(rockspec == out)
      assert.same(rockspec.build_dependencies, {})
   end)

   for d in lfs.dir(test_env.testing_paths.src_dir .. "/luarocks/build") do
      local name = d:match("(.*)%.lua")
      if name then
         it("does not add a build dependency for vendored '" .. name .. "' type", function()
            local filename = "test-1.0-1.rockspec"
            local rockspec = {
               package = "test",
               source = {
                  url = "",
               },
               build = {
                  type = name
               },
            }
            local globals = {}
            local quick = true

            local out = rockspecs.from_persisted_table(filename, rockspec, globals, quick)

            assert(rockspec == out)
            assert.same(rockspec.build_dependencies, {})
         end)
      end
   end

end)
