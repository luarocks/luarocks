local test_env = require("spec.util.test_env")
local testing_paths = test_env.testing_paths
local get_tmp_path = test_env.get_tmp_path
local write_file = test_env.write_file

test_env.unload_luarocks()
local fs = require("luarocks.fs")
local patch = package.loaded["luarocks.tools.patch"]

describe("Luarocks patch test #unit", function()
   local runner
   
   setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
      runner.tick = true
   end)
   
   teardown(function()
      runner.shutdown()
   end)
   
   describe("patch.read_patch", function()
      it("returns a table with the patch file info and the result of parsing the file", function()
         local t, result
         
         t, result = patch.read_patch(testing_paths.fixtures_dir .. "/valid_patch.patch")
         assert.truthy(result)
         
         t, result = patch.read_patch(testing_paths.fixtures_dir .. "/invalid_patch.patch")
         assert.falsy(result)
      end)
   end)
   
   describe("patch.apply_patch", function()
      local tmpdir
      local olddir
      
      before_each(function()
         tmpdir = get_tmp_path()
         olddir = lfs.currentdir()
         lfs.mkdir(tmpdir)
         lfs.chdir(tmpdir)
         
         local fd = assert(io.open(testing_paths.fixtures_dir .. "/lao"))
         local laocontent = assert(fd:read("*a"))
         fd:close()
         write_file("lao", laocontent, finally)
         
         fd = assert(io.open(testing_paths.fixtures_dir .. "/tzu"))
         local tzucontent = assert(fd:read("*a"))
         fd:close()
         write_file("tzu", tzucontent, finally)
      end)
      
      after_each(function()
         if olddir then
            lfs.chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir)
            end
         end
      end)
      
      it("applies the given patch and returns true if the patch is valid", function()
         local p = patch.read_patch(testing_paths.fixtures_dir .. "/valid_patch.patch")
         local result = patch.apply_patch(p)
         assert.truthy(result)
      end)
      
      it("returns false if the files to be patched are not valid or doesn't exist", function()
         os.remove("lao")
         os.remove("tzu")
         local p = patch.read_patch(testing_paths.fixtures_dir .. "/invalid_patch.patch")
         local result = patch.apply_patch(p)
         assert.falsy(result)
      end)
      
      it("returns false if the target file is already patched", function()
         local p = patch.read_patch(testing_paths.fixtures_dir .. "/valid_patch.patch")
         local result = patch.apply_patch(p)
         assert.truthy(result)
         
         result = patch.apply_patch(p)
         assert.falsy(result)
      end)
   end)
end)
