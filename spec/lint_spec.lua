local test_env = require("spec.util.test_env")
local run = test_env.run
local get_tmp_path = test_env.get_tmp_path
local write_file = test_env.write_file
local lfs = require("lfs")

local extra_rocks = {
   "/say-1.3-1.rockspec"
}

describe("luarocks lint #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("lint"))
   end)

   it("invalid argument", function()
      assert.is_false(run.luarocks_bool("lint invalid"))
   end)

   it("OK", function()
      assert.is_true(run.luarocks_bool("download --rockspec say 1.3-1"))
      local output = run.luarocks("lint say-1.3-1.rockspec")
      assert.are.same(output, "")
      assert.is_true(os.remove("say-1.3-1.rockspec"))
   end)

   describe("mismatch set", function()
      local tmpdir
      local olddir

      before_each(function()
         tmpdir = get_tmp_path()
         olddir = lfs.currentdir()
         lfs.mkdir(tmpdir)
         lfs.chdir(tmpdir)
      end)

      after_each(function()
         if olddir then
            lfs.chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("mismatch string", function()
         write_file("type_mismatch_string-1.0-1.rockspec", [[
            package="type_mismatch_version"
            version=1.0
         ]], finally)
         assert.is_false(run.luarocks_bool("lint type_mismatch_string-1.0-1.rockspec"))
      end)

      it("mismatch version", function()
         write_file("type_mismatch_version-1.0-1.rockspec", [[
            package="type_mismatch_version"
            version="1.0"
         ]], finally)
         assert.is_false(run.luarocks_bool("lint type_mismatch_version-1.0-1.rockspec"))
      end)

      it("mismatch table", function()
         write_file("type_mismatch_table-1.0-1.rockspec", [[
            package="type_mismatch_table"
            version="1.0-1"

            source = "not a table"
         ]], finally)
         assert.is_false(run.luarocks_bool("lint type_mismatch_table-1.0-1.rockspec"))
      end)

      it("mismatch no build table", function()
         write_file("no_build_table-1.0-1.rockspec", [[
            package = "no_build_table"
            version = "0.1-1"
            source = {
               url = "http://example.com/foo/tar.gz"
            }
            description = {
               summary = "A rockspec with no build field",
            }
            dependencies = {
               "lua >= 5.1"
            }
         ]], finally)
         assert.is_false(run.luarocks_bool("lint no_build_table-1.0-1.rockspec"))
      end)

      it("no description field", function()
         write_file("nodesc-1.0-1.rockspec", [[
            package = "nodesc"
            version = "0.1-1"
            source = {
               url = "http://example.com/foo/tar.gz"
            }
            dependencies = {
               "lua >= 5.1"
            }
         ]], finally)
         assert.is_false(run.luarocks_bool("lint nodesc-1.0-1.rockspec"))
      end)
   end)
end)
