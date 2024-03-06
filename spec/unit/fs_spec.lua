local test_env = require("spec.util.test_env")

test_env.setup_specs()
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local cfg = require("luarocks.core.cfg")
local lfs = require("lfs")
local is_win = test_env.TEST_TARGET_OS == "windows"
local posix_ok = pcall(require, "posix")
local testing_paths = test_env.testing_paths
local get_tmp_path = test_env.get_tmp_path
local write_file = test_env.write_file
local P = test_env.P

-- A chdir that works in both full and minimal mode, setting
-- both the real process current dir and the LuaRocks internal stack in minimal mode
local function chdir(d)
   lfs.chdir(d)
   fs.change_dir(d)
end

describe("luarocks.fs #unit", function()
   local exists_file = function(path)
      local ok, err, code = os.rename(path, path)
      if not ok and code == 13 then
         return true
      end
      return ok
   end

   local create_file = function(path, content)
      local fd = assert(io.open(path, "w"))
      if not content then
         content = "foo"
      end
      assert(fd:write(content))
      fd:close()
   end

   local make_unreadable = function(path)
      if is_win then
         fs.execute("icacls " .. fs.Q(path) .. " /inheritance:d /deny \"%USERNAME%\":(R)")
      else
         fs.execute("chmod -r " .. fs.Q(path))
      end
   end

   local make_unwritable = function(path)
      if is_win then
         fs.execute("icacls " .. fs.Q(path) .. " /inheritance:d /deny \"%USERNAME%\":(W,M)")
      else
         fs.execute("chmod -w " .. fs.Q(path))
      end
   end

   local make_unexecutable = function(path)
      if is_win then
         fs.execute("icacls " .. fs.Q(path) .. " /inheritance:d /deny \"%USERNAME%\":(X)")
      else
         fs.execute("chmod -x " .. fs.Q(path))
      end
   end

   local runner

   lazy_setup(function()
      cfg.init()
      fs.init()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

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

   describe("fs.absolute_name", function()
      it("unchanged if already absolute", function()
         if is_win then
            assert.are.same(P"c:\\foo\\bar", fs.absolute_name("\"c:\\foo\\bar\""))
            assert.are.same(P"c:\\foo\\bar", fs.absolute_name("c:\\foo\\bar"))
            assert.are.same(P"d:\\foo\\bar", fs.absolute_name("d:\\foo\\bar"))
            assert.are.same(P"\\foo\\bar", fs.absolute_name("\\foo\\bar"))
         else
            assert.are.same(P"/foo/bar", fs.absolute_name("/foo/bar"))
         end
      end)

      it("converts to absolute if relative", function()
         local cur = fs.current_dir()
         if is_win then
            assert.are.same(P(cur .. "/foo\\bar"), fs.absolute_name("\"foo\\bar\""))
            assert.are.same(P(cur .. "/foo\\bar"), fs.absolute_name("foo\\bar"))
         else
            assert.are.same(P(cur .. "/foo/bar"), fs.absolute_name("foo/bar"))
         end
      end)

      it("converts a relative to specified base if given", function()
         if is_win then
            assert.are.same(P"c:\\bla/foo\\bar", fs.absolute_name("\"foo\\bar\"", "c:\\bla"))
            assert.are.same(P"c:\\bla/foo\\bar", fs.absolute_name("foo/bar", "c:\\bla"))
            assert.are.same(P"c:\\bla/foo\\bar", fs.absolute_name("foo\\bar", "c:\\bla\\"))
         else
            assert.are.same(P"/bla/foo/bar", fs.absolute_name("foo/bar", "/bla"))
            assert.are.same(P"/bla/foo/bar", fs.absolute_name("foo/bar", "/bla/"))
         end
      end)
   end)

   describe("fs.execute_string", function()
      local tmpdir

      after_each(function()
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("returns the status code and runs the command given in the argument", function()
         tmpdir = get_tmp_path()
         assert.truthy(fs.execute_string("mkdir " .. fs.Q(tmpdir)))
         assert.truthy(fs.is_dir(tmpdir))
         assert.falsy(fs.execute_string("invalidcommand"))
      end)
   end)

   describe("fs.dir_iterator", function()
      local tmpfile1
      local tmpfile2
      local tmpdir
      local intdir

      after_each(function()
         if tmpfile1 then
            os.remove(tmpfile1)
            tmpfile1 = nil
         end
         if tmpfile2 then
            os.remove(tmpfile2)
            tmpfile2 = nil
         end
         if intdir then
            lfs.rmdir(intdir)
            intdir = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("yields all files and directories in the directory given as argument during the iterations", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         tmpfile1 = tmpdir .. "/file1"
         create_file(tmpfile1)
         tmpfile2 = tmpdir .. "/file2"
         create_file(tmpfile2)
         intdir = tmpdir .. "/intdir"
         lfs.mkdir(intdir)
         local dirTable = {}
         local dirCount = 0
         local crt = coroutine.create(fs.dir_iterator)
         while coroutine.status(crt) ~= "dead" do
            local ok, val = coroutine.resume(crt, tmpdir)
            if ok and val ~= nil then
               dirTable[val] = true
               dirCount = dirCount + 1
            end
         end
         assert.same(dirCount, 3)
         assert.is_not.same(dirTable["file1"], nil)
         assert.is_not.same(dirTable["file2"], nil)
         assert.is_not.same(dirTable["intdir"], nil)
         dirCount = 0
         crt = coroutine.create(fs.dir_iterator)
         while coroutine.status(crt) ~= "dead" do
            local ok, val = coroutine.resume(crt, intdir)
            if ok and val ~= nil then
               dirCount = dirCount + 1
            end
         end
         assert.same(dirCount, 0)
      end)

      it("does nothing if the argument is a file", function()
         tmpfile1 = get_tmp_path()
         create_file(tmpfile1)
         local crt = coroutine.create(fs.dir_iterator)
         while coroutine.status(crt) ~= "dead" do
            local ok, val = coroutine.resume(crt, tmpfile1)
            assert.falsy(ok and res)
         end
      end)

      it("does nothing if the argument is invalid", function()
         local crt = coroutine.create(fs.dir_iterator)
         while coroutine.status(crt) ~= "dead" do
            local ok, val = coroutine.resume(crt, "/nonexistent")
            assert.falsy(ok and res)
         end
      end)
   end)

   describe("fs.is_writable", function()
      local tmpfile
      local tmpdir

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

      it("returns true if the file given as argument is writable", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         assert.truthy(fs.is_writable(tmpfile))
      end)

      it("returns true if the directory given as argument is writable", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.is_writable(tmpdir))
         tmpfile = tmpdir .. "/internalfile"
         create_file(tmpfile)
         make_unwritable(tmpfile)
         assert.truthy(fs.is_writable(tmpdir))
      end)

      it("returns false if the file given as argument is not writable", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         make_unwritable(tmpfile)
         assert.falsy(fs.is_writable(tmpfile))
      end)

      it("returns false if the directory given as argument is not writable", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         make_unwritable(tmpdir)
         assert.falsy(fs.is_writable(tmpdir))
      end)

      it("returns false if the file or directory given as argument does not exist", function()
         assert.falsy(fs.is_writable("/nonexistent"))
      end)
   end)

   describe("fs.set_time #unix", function()
      local tmpfile
      local tmpdir
      local intdir

      after_each(function()
         if tmpfile then
            os.remove(tmpfile)
            tmpfile = nil
         end
         if intdir then
            os.remove(intdir)
            intdir = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("returns true and modifies the access time of the file given as argument", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         local newtime = os.time() - 100
         assert.truthy(fs.set_time(tmpfile, newtime))
         assert.same(lfs.attributes(tmpfile, "access"), newtime)
         assert.same(lfs.attributes(tmpfile, "modification"), newtime)
      end)

      it("returns true and modifies the access time of the directory given as argument", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         tmpfile = tmpdir .. "/internalfile"
         create_file(tmpfile)
         local newtime = os.time() - 100
         assert.truthy(fs.set_time(tmpdir, newtime))
         assert.same(lfs.attributes(tmpdir, "access"), newtime)
         assert.same(lfs.attributes(tmpdir, "modification"), newtime)
         assert.is_not.same(lfs.attributes(tmpfile, "access"), newtime)
         assert.is_not.same(lfs.attributes(tmpfile, "modification"), newtime)
      end)

      it("returns false and does nothing if the file or directory given as arguments doesn't exist", function()
         assert.falsy(fs.set_time("/nonexistent"))
      end)
   end)

   describe("fs.set_permissions", function()
      local readfile
      local execfile
      local tmpdir

      after_each(function()
         if readfile then
            os.remove(readfile)
            readfile = nil
         end
         if execfile then
            os.remove(execfile)
            execfile = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("returns true and sets the permissions of the argument accordingly", function()
         readfile = get_tmp_path()
         create_file(readfile)
         make_unreadable(readfile)
         assert.falsy(io.open(readfile, "r"))
         assert.truthy(fs.set_permissions(readfile, "read", "user"))
         assert.truthy(io.open(readfile, "r"))

         if is_win then
            execfile = get_tmp_path() .. ".exe"
            create_file(execfile)
         else
            execfile = get_tmp_path() .. ".sh"
            create_file(execfile, "#!/bin/bash")
         end
         make_unexecutable(execfile)
         local fd = assert(io.popen(execfile .. " 2>&1"))
         local result = assert(fd:read("*a"))
         assert.truthy(result:match("denied"))
         fd:close()
         assert.truthy(fs.set_permissions(execfile, "exec", "user"))
         fd = assert(io.popen(execfile .. " 2>&1"))
         result = assert(fd:read("*a"))
         assert.falsy(result:match("denied"))
         fd:close()

         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         make_unexecutable(tmpdir)
         fd = assert(io.popen("cd " .. fs.Q(tmpdir) .. " 2>&1"))
         result = assert(fd:read("*a"))
         assert.truthy(result:match("denied") or result:match("can't cd"))
         fd:close()
         assert.truthy(fs.set_permissions(tmpdir, "exec", "user"))
         fd = assert(io.popen("cd " .. fs.Q(tmpdir) .. " 2>&1"))
         result = assert(fd:read("*a"))
         assert.falsy(result:match("denied") or result:match("can't cd"))
         fd:close()
      end)

      it("returns false and does nothing if the argument is nonexistent", function()
         assert.falsy(fs.set_permissions("/nonexistent", "read", "user"))
      end)
   end)

   describe("fs.is_file", function()
      local tmpfile
      local tmpdir

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

      it("returns true when the argument is a file", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         assert.same(true, fs.is_file(tmpfile))
      end)

      it("returns false when the argument does not exist", function()
         assert.same(false, fs.is_file("/nonexistent"))
      end)

      it("returns false when the argument exists but is not a file", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.same(false, fs.is_file("/nonexistent"))
      end)

      it("#unix returns false when the argument is a symlink to a directory", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         local linkname = tmpdir .. "/symlink"
         finally(function() os.remove(linkname) end)
         lfs.link(tmpdir, linkname, true)
         assert.falsy(fs.is_file(linkname))
      end)

      it("#unix returns true when the argument is a symlink to a file", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         local linkname = tmpfile .. "_symlink"
         finally(function() os.remove(linkname) end)
         lfs.link(tmpfile, linkname, true)
         assert.truthy(fs.is_file(linkname))
      end)
   end)

   describe("fs.is_dir", function()
      local tmpfile
      local tmpdir

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

      it("returns true when the argument is a directory", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.is_dir(tmpdir))
      end)

      it("returns false when the argument is a file", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         assert.falsy(fs.is_dir(tmpfile))
      end)

      it("#unix returns true when the argument is a symlink to a directory", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         local linkname = tmpdir .. "/symlink"
         finally(function() os.remove(linkname) end)
         lfs.link(tmpdir, linkname, true)
         assert.truthy(fs.is_dir(linkname))
      end)

      it("#unix returns false when the argument is a symlink to a file", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         local linkname = tmpfile .. "_symlink"
         finally(function() os.remove(linkname) end)
         lfs.link(tmpfile, linkname, true)
         assert.falsy(fs.is_dir(linkname))
      end)

      it("returns false when the argument does not exist", function()
         assert.falsy(fs.is_dir("/nonexistent"))
      end)
   end)

   describe("fs.exists", function()
      local tmpfile
      local tmpdir

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

      it("returns true when the argument is a file", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         assert.truthy(fs.exists(tmpfile))
      end)

      it("returns true when the argument is a directory", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.exists(tmpdir))
      end)

      it("returns false when the argument does not exist", function()
         assert.falsy(fs.exists("/nonexistent"))
      end)
   end)

   describe("fs.current_dir", function()
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
      end)

      after_each(function()
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
         if olddir then
            chdir(olddir)
            olddir = nil
         end
      end)

      it("returns the current working directory", function()
         local currentdir = lfs.currentdir()
         assert.same(currentdir, fs.current_dir())
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.change_dir(tmpdir))
         if is_win then
            assert.same(tmpdir, fs.current_dir())
         else
            assert.same(lfs.attributes(tmpdir).ino, lfs.attributes((fs.current_dir())).ino)
         end
      end)
   end)

   describe("fs.change_dir", function()
      local tmpfile
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
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
         if olddir then
            chdir(olddir)
            olddir = nil
         end
      end)

      it("returns true and changes the current working directory if the argument is a directory", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.change_dir(tmpdir))
         if is_win then
            assert.same(tmpdir, fs.current_dir())
         else
            assert.same(lfs.attributes(tmpdir).ino, lfs.attributes(fs.current_dir()).ino)
         end
      end)

      it("returns false and does nothing when the argument is a file", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         assert.falsy(fs.change_dir(tmpfile))
         assert.same(olddir, lfs.currentdir())
      end)

      it("returns false and does nothing when the argument does not exist", function()
         assert.falsy(fs.change_dir("/nonexistent"))
         assert.same(olddir, lfs.currentdir())
      end)
   end)

   describe("fs.change_dir_to_root", function()
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
      end)

      after_each(function()
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
         if olddir then
            chdir(olddir)
         end
      end)

      it("returns true and changes the current directory to root if the current directory is valid", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.change_dir(tmpdir))
         assert.truthy(fs.change_dir_to_root())
         if is_win then
            local curr_dir = fs.current_dir()
            assert.truthy(curr_dir == "C:\\" or curr_dir == P"/")
         else
            assert.same(P"/", fs.current_dir())
         end
      end)

      it("returns false and does nothing if the current directory is not valid #unix", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         chdir(tmpdir)
         lfs.rmdir(tmpdir)
         assert.falsy(fs.change_dir_to_root())
         assert.is_not.same("/", lfs.currentdir())
      end)
   end)

   describe("fs.pop_dir", function()
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
      end)

      after_each(function()
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
         if olddir then
            chdir(olddir)
         end
      end)

      it("returns true and changes the current directory to the previous one in the dir stack if the dir stack is not empty", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.change_dir(tmpdir))
         assert.truthy(fs.pop_dir())
         assert.same(olddir, lfs.currentdir())
      end)
   end)

   describe("fs.make_dir", function()
      local tmpfile
      local tmpdir
      local intdir

      after_each(function()
         if tmpfile then
            os.remove(tmpfile)
            tmpfile = nil
         end
         if intdir then
            lfs.rmdir(intdir)
            intdir = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("returns true and creates the directory specified by the argument", function()
         tmpdir = get_tmp_path()
         assert.truthy(fs.make_dir(tmpdir))
         assert.same("directory", lfs.attributes(tmpdir, "mode"))
      end)

      it("returns true and creates the directory path specified by the argument", function()
         tmpdir = get_tmp_path()
         intdir = "/internaldir"
         local dirpath = tmpdir .. intdir
         assert.truthy(fs.make_dir(dirpath))
         assert.same("directory", lfs.attributes(tmpdir, "mode"))
         assert.same("directory", lfs.attributes(dirpath, "mode"))
      end)

      it("returns false and does nothing if the argument is not valid (file in the path)", function()
         tmpfile = get_tmp_path()
         local fd = assert(io.open(tmpfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         intdir = "/internaldir"
         local dirpath = tmpfile .. intdir
         assert.falsy(fs.make_dir(dirpath))
      end)

      it("returns false and does nothing if the argument already exists", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile)
         assert.falsy(fs.make_dir(tmpfile))
      end)
   end)

   describe("fs.remove_dir_if_empty", function()
      local tmpfile
      local tmpdir

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

      it("removes the directory specified by the argument if it is empty", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         fs.remove_dir_if_empty(tmpdir)
         assert.falsy(exists_file(tmpdir))
      end)

      it("does nothing if the directory specified by the argument is not empty", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         tmpfile = "/internalfile"
         local filepath = tmpdir .. tmpfile
         create_file(filepath)
         fs.remove_dir_if_empty(tmpdir)
         assert.truthy(exists_file(tmpdir))
      end)
   end)

   describe("fs.remove_dir_tree_if_empty", function()
      local tmpfile
      local tmpdir
      local intdir

      after_each(function()
         if tmpfile then
            os.remove(tmpfile)
            tmpfile = nil
         end
         if intdir then
            lfs.rmdir(intdir)
            intdir = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("removes the directory path specified by the argument if it is empty", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         fs.remove_dir_tree_if_empty(tmpdir)
         assert.falsy(exists_file(tmpdir))
      end)

      it("does nothing if the directory path specified by the argument is not empty", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         intdir = "/internaldir"
         local dirpath = tmpdir .. intdir
         lfs.mkdir(dirpath)
         tmpfile = "/internalfile"
         local filepath = dirpath .. tmpfile
         fs.remove_dir_tree_if_empty(tmpdir)
         assert.truthy(exists_file(dirpath))
         assert.truthy(exists_file(tmpdir))
      end)
   end)

   describe("fs.list_dir", function()
      local intfile1
      local intfile2
      local intdir
      local tmpdir

      before_each(function()
         if intfile1 then
            os.remove(intfile1)
            intfile1 = nil
         end
         if intfile2 then
            os.remove(intfile2)
            intfile2 = nil
         end
         if intdir then
            lfs.rmdir(intdir)
            intdir = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("returns a table with the contents of the given directory", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         intfile1 = tmpdir .. "/intfile1"
         create_file(intfile1)
         intdir = tmpdir .. "/intdir"
         lfs.mkdir(intdir)
         intfile2 = intdir .. "/intfile2"
         create_file(intfile2)
         local result = fs.list_dir(tmpdir)
         assert.same(#result, 2)
         assert.truthy(result[1] == "intfile1" or result[1] == "intdir")
         assert.truthy(result[2] == "intfile1" or result[2] == "intdir")
         assert.is_not.same(result[1], result[2])
      end)

      it("returns an empty table if the argument is a file", function()
         intfile1 = get_tmp_path()
         create_file(intfile1)
         local result = fs.list_dir(intfile1)
         assert.same(#result, 0)
      end)

      it("does nothing if the argument is nonexistent", function()
         assert.same(fs.list_dir("/nonexistent"), {})
      end)

      it("does nothing if the argument doesn't have the proper permissions", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         make_unreadable(tmpdir)
         assert.same(fs.list_dir(tmpdir), {})
      end)
   end)

   describe("fs.copy", function()
      local srcfile
      local dstfile
      local tmpdir

      after_each(function()
         if srcfile then
            os.remove(srcfile)
            srcfile = nil
         end
         if dstfile then
            os.remove(dstfile)
            dstfile = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("returns true and copies the contents and the permissions of the source file to the destination file", function()
         srcfile = get_tmp_path()
         create_file(srcfile, srccontent)
         dstfile = get_tmp_path()
         assert.truthy(fs.copy(srcfile, dstfile))
         local fd = assert(io.open(dstfile, "r"))
         local dstcontent = fd:read("*a")
         assert.same("foo", dstcontent)
         if posix_ok then
            assert.same(lfs.attributes(srcfile, "permissions"), lfs.attributes(dstfile, "permissions"))
         end
      end)

      it("returns true and copies contents of the source file to the destination file with custom permissions", function()
         srcfile = get_tmp_path()
         create_file(srcfile, srccontent)
         dstfile = get_tmp_path()
         assert.truthy(fs.copy(srcfile, dstfile, "exec"))
         local fd = assert(io.open(dstfile, "r"))
         local dstcontent = fd:read("*a")
         assert.same("foo", dstcontent)
      end)

      it("returns false and does nothing if the source file does not exist", function()
         srcfile = get_tmp_path()
         dstfile = get_tmp_path()
         local ok, err = fs.copy(srcfile, dstfile, nil)
         assert.falsy(ok)
         assert.not_match("are the same file", err)
         assert.falsy(exists_file(dstfile))
      end)

      it("returns false and does nothing if the source file doesn't have the proper permissions", function()
         srcfile = get_tmp_path()
         create_file(srcfile)
         make_unreadable(srcfile)
         dstfile = get_tmp_path()
         assert.falsy(fs.copy(srcfile, dstfile, nil))
         assert.falsy(exists_file(dstfile))
      end)

      it("returns false and does nothing if the destination file directory doesn't have the proper permissions", function()
         srcfile = get_tmp_path()
         create_file(srcfile)
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         make_unwritable(tmpdir)
         dstfile = tmpdir .. "/dstfile"
         assert.falsy(fs.copy(srcfile, dstfile, nil))
         assert(fs.set_permissions(tmpdir, "exec", "all"))
         assert.falsy(exists_file(dstfile))
      end)
   end)

   describe("fs.copy_contents", function()
      local srcfile
      local dstfile
      local srcintdir
      local dstintdir
      local srcdir
      local dstdir

      after_each(function()
         if srcfile then
            os.remove(srcfile)
            srcfile = nil
         end
         if dstfile then
            os.remove(dstfile)
            dstfile = nil
         end
         if srcintdir then
            lfs.rmdir(srcintdir)
            srcintdir = nil
         end
         if dstintdir then
            lfs.rmdir(dstintdir)
            dstintdir = nil
         end
         if srcdir then
            lfs.rmdir(srcdir)
            srcdir = nil
         end
         if dstdir then
            lfs.rmdir(dstdir)
            dstdir = nil
         end
      end)

      local create_dir_tree = function()
         srcdir = get_tmp_path()
         lfs.mkdir(srcdir)
         srcintdir = srcdir .. "/internaldir"
         lfs.mkdir(srcintdir)
         srcfile = srcintdir .. "/internalfile"
         create_file(srcfile)
         dstdir = get_tmp_path()
      end

      it("returns true and copies the contents (with their permissions) of the source dir to the destination dir", function()
         create_dir_tree()
         assert.truthy(fs.copy_contents(srcdir, dstdir))
         assert.truthy(exists_file(dstdir))
         dstintdir = dstdir .. "/internaldir"
         assert.truthy(exists_file(dstintdir))
         dstfile = dstdir .. "/internaldir/internalfile"
         local fd = assert(io.open(dstfile, "r"))
         local dstfilecontent = fd:read("*a")
         assert.same("foo", dstfilecontent)
         if posix_ok then
            assert.same(lfs.attributes(srcfile, "permissions"), lfs.attributes(dstfile, "permissions"))
         end
      end)

      it("returns true and copies the contents of the source dir to the destination dir with custom permissions", function()
         create_dir_tree()
         assert.truthy(fs.copy_contents(srcdir, dstdir, "read"))
         assert.truthy(exists_file(dstdir))
         dstintdir = dstdir .. "/internaldir"
         assert.truthy(exists_file(dstintdir))
         dstfile = dstdir .. "/internaldir/internalfile"
         local fd = assert(io.open(dstfile, "r"))
         local dstfilecontent = fd:read("*a")
         assert.same("foo", dstfilecontent)
      end)

      it("returns false and does nothing if the source dir doesn't exist", function()
         srcdir = get_tmp_path()
         dstdir = get_tmp_path()
         assert.falsy(fs.copy_contents(srcdir, dstdir))
         assert.falsy(exists_file(dstdir))
      end)

      it("returns false if the source argument is a file", function()
         srcdir = get_tmp_path()
         create_file(srcdir)
         dstdir = get_tmp_path()
         assert.falsy(fs.copy_contents(srcdir, dstdir))
         assert.falsy(exists_file(dstdir))
      end)

      it("returns false and does nothing if the source dir doesn't have the proper permissions", function()
         create_dir_tree()
         make_unreadable(srcdir)
         assert.falsy(fs.copy_contents(srcdir, dstdir))
         assert.falsy(exists_file(dstdir .. "/internaldir"))
         assert.falsy(exists_file(dstdir .. "/internalfile"))
      end)
   end)

   describe("fs.find", function()
      local tmpdir
      local intdir
      local intfile1
      local intfile2

      after_each(function()
         if intfile1 then
            os.remove(intfile1)
            intfile1 = nil
         end
         if intfile2 then
            os.remove(intfile2)
            intfile2 = nil
         end
         if intdir then
            lfs.rmdir(intdir)
            intdir = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      local create_dir_tree = function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         intfile1 = tmpdir .. "/intfile1"
         create_file(intfile1)
         intdir = tmpdir .. "/intdir"
         lfs.mkdir(intdir)
         intfile2 = intdir .. "/intfile2"
         create_file(intfile2)
      end

      it("returns a table of all the contents in the directory given as argument", function()
         create_dir_tree()
         local contents = {}
         local count = 0
         for _, file in pairs(fs.find(tmpdir)) do
            contents[file] = true
            count = count + 1
         end
         assert.same(count, 3)
         assert.is_not.same(contents[tmpdir], true)
         assert.same(contents[P"intfile1"], true)
         assert.same(contents[P"intdir"], true)
         assert.same(contents[P"intdir/intfile2"], true)
      end)

      it("uses the current working directory if the argument is nil", function()
         create_dir_tree()
         local olddir = fs.current_dir()
         fs.change_dir(intdir)
         local contents = {}
         local count = 0
         for _, file in pairs(fs.find()) do
            contents[file] = true
            count = count + 1
         end
         assert.same(count, 1)
         assert.is_not.same(contents["intfile1"], true)
         assert.is_not.same(contents["intdir"], true)
         assert.same(contents["intfile2"], true)
         fs.change_dir(olddir)
      end)

      it("returns an empty table if the argument is nonexistent", function()
         local contents = fs.find("/nonexistent")
         local count = 0
         for _, file in pairs(contents) do
            count = count + 1
         end
         assert.same(count, 0)
      end)

      it("returns an empty table if the argument is a file", function()
         intfile1 = get_tmp_path()
         create_file(intfile1)
         local contents = fs.find(intfile1)
         local count = 0
         for _, file in pairs(contents) do
            count = count + 1
         end
         assert.same(count, 0)
      end)

      it("does nothing if the argument doesn't have the proper permissions", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         make_unreadable(tmpdir)
         assert.same(fs.find(tmpdir), {})
      end)
   end)

   describe("fs.move", function()
      local srcfile
      local dstfile
      local tmpdir

      after_each(function()
         if srcfile then
            os.remove(srcfile)
            srcfile = nil
         end
         if dstfile then
            os.remove(dstfile)
            dstfile = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir  = nil
         end
      end)

      it("returns true and moves the source (together with its permissions) to the destination", function()
         srcfile = get_tmp_path()
         create_file(srcfile)
         dstfile = get_tmp_path()
         local oldperms = lfs.attributes(srcfile, "permissions")
         assert.truthy(fs.move(srcfile, dstfile))
         assert.truthy(fs.exists(dstfile))
         assert.falsy(fs.exists(srcfile))
         local fd = assert(io.open(dstfile, "r"))
         local dstcontents = assert(fd:read("*a"))
         assert.same(dstcontents, "foo")
         if posix_ok then
            assert.same(oldperms, lfs.attributes(dstfile, "permissions"))
         end
      end)

      it("returns true and moves the source (with custom permissions) to the destination", function()
         srcfile = get_tmp_path()
         create_file(srcfile)
         dstfile = get_tmp_path()
         assert.truthy(fs.move(srcfile, dstfile, "read"))
         assert.truthy(fs.exists(dstfile))
         assert.falsy(fs.exists(srcfile))
         local fd = assert(io.open(dstfile, "r"))
         local dstcontents = assert(fd:read("*a"))
         assert.same(dstcontents, "foo")
      end)

      it("returns false and does nothing if the source doesn't exist", function()
         dstfile = get_tmp_path()
         assert.falsy(fs.move("/nonexistent", dstfile))
         assert.falsy(fs.exists(dstfile))
      end)

      it("returns false and does nothing if the destination already exists", function()
         srcfile = get_tmp_path()
         create_file(srcfile)
         dstfile = get_tmp_path()
         create_file(dstfile, "bar")
         assert.falsy(fs.move(srcfile, dstfile))
         assert.truthy(fs.exists(srcfile))
         local fd = assert(io.open(dstfile, "r"))
         local dstcontents = assert(fd:read("*a"))
         assert.same(dstcontents, "bar")
      end)

      it("returns false and does nothing if the destination path doesn't have the proper permissions", function()
         srcfile = get_tmp_path()
         create_file(srcfile)
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         make_unwritable(tmpdir)
         assert.falsy(fs.move(srcfile, tmpdir .. "/dstfile"))
         assert.falsy(fs.exists(tmpdir .. "/dstfile"))
      end)
   end)

   describe("fs.is_lua", function()
      local tmpfile

      after_each(function()
         if tmpfile then
            os.remove(tmpfile)
            tmpfile = nil
         end
      end)

      it("returns true if the argument is a valid lua script", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile, "print(\"foo\")")
         assert.truthy(fs.is_lua(tmpfile))
      end)

      it("returns true if the argument is a valid lua script with shebang", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile, "#!/usr/bin/env lua\n\nprint(\"foo\")")
         assert.truthy(fs.is_lua(tmpfile))
      end)

      it("returns false if the argument is not a valid lua script", function()
         tmpfile = os.tmpname()
         create_file(tmpfile)
         assert.falsy(fs.is_lua(tmpfile))
      end)

      it("returns false if the argument is a valid lua script but doesn't have the proper permissions", function()
         tmpfile = get_tmp_path()
         create_file(tmpfile, "print(\"foo\")")
         make_unreadable(tmpfile)
         assert.falsy(fs.is_lua(tmpfile))
      end)
   end)

   describe("fs.delete", function()
      local tmpfile1
      local tmpfile2
      local tmpintdir
      local tmpdir

      after_each(function()
         if tmpfile1 then
            os.remove(tmpfile1)
            tmpfile1 = nil
         end
         if tmpfile2 then
            os.remove(tmpfile2)
            tmpfile2 = nil
         end
         if tmpintdir then
            lfs.rmdir(tmpintdir)
            tmpintdir = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      local create_dir_tree = function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         tmpintdir = tmpdir .. "/internaldir"
         lfs.mkdir(tmpintdir)
         tmpfile1 = tmpdir .. "/internalfile1"
         create_file(tmpfile1)
         tmpfile2 = tmpdir .. "/internalfile2"
         create_file(tmpfile2)
      end

      it("deletes the file specified by the argument", function()
         tmpfile1 = get_tmp_path()
         tmpfile2 = get_tmp_path()
         fs.delete(tmpfile1)
         fs.delete(tmpfile2)
         assert.falsy(exists_file(tmpfile1))
         assert.falsy(exists_file(tmpfile2))
      end)

      it("deletes the contents of the directory specified by the argument", function()
         create_dir_tree()
         fs.delete(tmpdir)
         assert.falsy(exists_file(tmpfile2))
         assert.falsy(exists_file(tmpintdir))
         assert.falsy(exists_file(tmpfile1))
         assert.falsy(exists_file(tmpdir))
      end)
   end)

   describe("fs.zip", function()
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         chdir(tmpdir)

         write_file("file1", "content1", finally)
         write_file("file2", "content2", finally)
         lfs.mkdir("dir")
         write_file("dir/file3", "content3", finally)
      end)

      after_each(function()
         if olddir then
            chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir .. "/dir")
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("returns true and creates a zip archive of the given files", function()
         assert.truthy(fs.zip("archive.zip", "file1", "file2", "dir"))
         assert.truthy(exists_file("archive.zip"))
      end)

      it("returns false and does nothing if the files specified in the arguments are invalid", function()
         assert.falsy(fs.zip("archive.zip", "nonexistent"))
         assert.falsy(exists_file("nonexistent"))
      end)
   end)

   describe("fs.bunzip2", function()

      it("uncompresses a .bz2 file", function()
         local input = testing_paths.fixtures_dir .. "/abc.bz2"
         local output = os.tmpname()
         assert.truthy(fs.bunzip2(input, output))
         local fd = io.open(output, "r")
         local content = fd:read("*a")
         fd:close()
         assert.same(300000, #content)
         local abc = ("a"):rep(100000)..("b"):rep(100000)..("c"):rep(100000)
         assert.same(abc, content)
      end)

   end)

   describe("fs.unzip", function()
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         chdir(tmpdir)

         write_file("file1", "content1", finally)
         write_file("file2", "content2", finally)
         lfs.mkdir("dir")
         write_file("dir/file3", "content3", finally)
      end)

      after_each(function()
         if olddir then
            chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir .. "/dir")
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("returns true and unzips the given zip archive", function()
         assert.truthy(fs.zip("archive.zip", "file1", "file2", "dir"))
         os.remove("file1")
         os.remove("file2")
         lfs.rmdir("dir")

         assert.truthy(fs.unzip("archive.zip"))
         assert.truthy(exists_file("file1"))
         assert.truthy(exists_file("file2"))
         assert.truthy(exists_file("dir/file3"))

         local fd

         fd = assert(io.open("file1", "r"))
         assert.same(fd:read("*a"), "content1")
         fd:close()

         fd = assert(io.open("file2", "r"))
         assert.same(fd:read("*a"), "content2")
         fd:close()

         fd = assert(io.open("dir/file3", "r"))
         assert.same(fd:read("*a"), "content3")
         fd:close()
      end)

      it("does nothing if the given archive is invalid", function()
         assert.falsy(fs.unzip("archive.zip"))
      end)
   end)

   describe("fs.wrap_script", function()
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         chdir(tmpdir)
      end)

      after_each(function()
         if olddir then
            chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("produces a wrapper for a Lua script", function()
         write_file("my_script", "io.write('Hello ' .. arg[1])", finally)
         path.use_tree(testing_paths.testing_tree)
         local wrapper_name = fs.absolute_name("wrapper") .. test_env.wrapper_extension
         fs.wrap_script("my_script", wrapper_name, "one", nil, nil, "World")
         local pd = assert(io.popen(wrapper_name))
         local data = pd:read("*a")
         pd:close()
         assert.same("Hello World", data)
      end)
   end)

   describe("fs.copy_binary", function()
      local tmpdir
      local olddir

      before_each(function()
         olddir = lfs.currentdir()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         chdir(tmpdir)

         write_file("test.exe", "", finally)
      end)

      after_each(function()
         if olddir then
            chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("returns true and copies the given binary file to the file specified in the dest argument", function()
         assert.truthy(fs.copy_binary("test.exe", lfs.currentdir() .. "/copy.exe"))
         assert.truthy(exists_file("copy.exe"))
         if is_win then
            assert.truthy(exists_file("test.lua"))
            local fd = assert(io.open("test.lua", "r"))
            local content = assert(fd:read("*a"))
            assert.truthy(content:find("package.path", 1, true))
            assert.truthy(content:find("package.cpath", 1, true))
            fd:close()
         end
      end)

      it("returns false and does nothing if the source file is invalid", function()
         assert.falsy(fs.copy_binary("invalid.exe", "copy.exe"))
      end)
   end)

   describe("fs.modules", function()
      local tmpdir
      local olddir
      local oldpath

      before_each(function()
         olddir = lfs.currentdir()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         chdir(tmpdir)
         lfs.mkdir("lib")
         write_file("lib/module1.lua", "", finally)
         write_file("lib/module2.lua", "", finally)
         write_file("lib/module1.LuA", "", finally)
         write_file("lib/non_lua", "", finally)
         lfs.mkdir("lib/internal")
         write_file("lib/internal/module11.lua", "",  finally)
         write_file("lib/internal/module22.lua", "", finally)

         oldpath = package.path
         package.path = package.path .. tmpdir .. "/?.lua;"
      end)

      after_each(function()
         if olddir then
            chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir .. "/lib/internal")
               lfs.rmdir(tmpdir .. "/lib")
               lfs.rmdir(tmpdir)
            end
         end
         if oldpath then
            package.path = oldpath
         end
      end)

      it("returns a table of the lua modules at a specific require path", function()
         local result

         result = fs.modules("lib")
         assert.same(#result, 2)
         assert.truthy(result[1] == "module1" or result[2] == "module1")
         assert.truthy(result[1] == "module2" or result[2] == "module2")

         result = fs.modules("lib.internal")
         assert.same(#result, 2)
         assert.truthy(result[1] == "module11" or result[2] == "module11")
         assert.truthy(result[1] == "module22" or result[2] == "module22")
      end)

      it("returns an empty table if the modules couldn't be found in package.path", function()
         package.path = ""
         assert.same(fs.modules("lib"), {})
      end)
   end)

   describe("#unix fs._unix_rwx_to_number", function()

      it("converts permissions in rwx notation to numeric ones", function()
         assert.same(tonumber("0644", 8), fs._unix_rwx_to_number("rw-r--r--"))
         assert.same(tonumber("0755", 8), fs._unix_rwx_to_number("rwxr-xr-x"))
         assert.same(tonumber("0000", 8), fs._unix_rwx_to_number("---------"))
         assert.same(tonumber("0777", 8), fs._unix_rwx_to_number("rwxrwxrwx"))
         assert.same(tonumber("0700", 8), fs._unix_rwx_to_number("rwx------"))
         assert.same(tonumber("0600", 8), fs._unix_rwx_to_number("rw-------"))
      end)

      it("produces a negated mask if asked to", function()
         assert.same(tonumber("0133", 8), fs._unix_rwx_to_number("rw-r--r--", true))
         assert.same(tonumber("0022", 8), fs._unix_rwx_to_number("rwxr-xr-x", true))
         assert.same(tonumber("0777", 8), fs._unix_rwx_to_number("---------", true))
         assert.same(tonumber("0000", 8), fs._unix_rwx_to_number("rwxrwxrwx", true))
         assert.same(tonumber("0077", 8), fs._unix_rwx_to_number("rwx------", true))
         assert.same(tonumber("0177", 8), fs._unix_rwx_to_number("rw-------", true))
      end)
   end)

   describe("fs.execute_env", function()
      local tmpname
      local tmplua
      local LUA = "lua"

      local function readfile(pathname)
         local file = assert(io.open(pathname, "rb"))
         local data = file:read "*a"
         file:close()
         return data
      end

      lazy_setup(function()
         tmpname = os.tmpname()

         tmplua = os.tmpname()
         local f = assert(io.open(tmplua, 'wb'))
         f:write [[
            local out = io.open((...), 'wb')
            out:write(os.getenv 'FOO')
            out:close()
         ]]
         f:close()
         LUA = test_env.testing_paths.lua
      end)

      after_each(function()
         os.remove(tmpname)
      end)

      lazy_teardown(function()
         os.remove(tmpname)
      end)

      it("passes variables w/o spaces correctly", function()
         fs.execute_env({
            FOO = "BAR",
         }, LUA, tmplua, tmpname)
         local data = readfile(tmpname)
         assert.same("BAR", data)
      end)

      it("passes variables w/ spaces correctly", function()
         fs.execute_env({
            FOO = "BAR with spaces",
         }, LUA, tmplua, tmpname)
         local data = readfile(tmpname)
         assert.same("BAR with spaces", data)
      end)
   end)

end)
