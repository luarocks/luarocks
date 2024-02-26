local test_env = require("spec.util.test_env")

local lfs = require("lfs")
local testing_paths = test_env.testing_paths
local get_tmp_path = test_env.get_tmp_path

describe("luarocks.fs #integration", function()

   local fs

   describe("fs.download #mock", function()
      local tmpfile
      local tmpdir

      lazy_setup(function()
         test_env.setup_specs(nil, "mock")
         local cfg = require("luarocks.core.cfg")
         fs = require("luarocks.fs")
         cfg.init()
         fs.init()
         test_env.mock_server_init()
      end)

      lazy_teardown(function()
         test_env.mock_server_done()
      end)

      after_each(function()
         if tmpfile then
            os.remove(tmpfile)
            tmpfile = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("returns true and fetches the url argument into the specified filename", function()
         tmpfile = get_tmp_path()
         assert.truthy(fs.download("http://localhost:8080/file/a_rock.lua", tmpfile))
         local fd = assert(io.open(tmpfile, "r"))
         local downloadcontent = assert(fd:read("*a"))
         fd:close()
         fd = assert(io.open(testing_paths.fixtures_dir .. "/a_rock.lua", "r"))
         local originalcontent = assert(fd:read("*a"))
         fd:close()
         assert.same(downloadcontent, originalcontent)
      end)

      it("returns true and fetches the url argument into a file whose name matches the basename of the url if the filename argument is not given", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         fs.change_dir(tmpdir)
         assert.truthy(fs.download("http://localhost:8080/file/a_rock.lua"))
         tmpfile = tmpdir .. "/a_rock.lua"
         local fd = assert(io.open(tmpfile, "r"))
         local downloadcontent = assert(fd:read("*a"))
         fd:close()
         fd = assert(io.open(testing_paths.fixtures_dir .. "/a_rock.lua", "r"))
         local originalcontent = assert(fd:read("*a"))
         fd:close()
         assert.same(downloadcontent, originalcontent)
         fs.pop_dir()
      end)

      it("returns false and does nothing if the url argument contains a nonexistent file", function()
         tmpfile = get_tmp_path()
         assert.falsy(fs.download("http://localhost:8080/file/nonexistent", tmpfile))
      end)

      it("returns false and does nothing if the url argument is invalid", function()
         assert.falsy(fs.download("invalidurl"))
      end)
   end)
end)
