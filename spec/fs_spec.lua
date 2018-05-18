local test_env = require("spec.util.test_env")

test_env.unload_luarocks()
local fs = require("luarocks.fs")
local lfs = require("lfs")
local is_win = test_env.TEST_TARGET_OS == "windows"
local posix_ok = pcall(require, "posix")

describe("Luarocks fs test #whitebox #w_fs", function()
   local get_tmp_path = function()
      local path = os.tmpname()
      if is_win and not path:find(":") then
         path = os.getenv("TEMP") .. path
      end
      os.remove(path)
      return path
   end

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
         fs.execute("icacls " .. fs.Q(path) .. " /deny %USERNAME%:(RD)")
      else
         fs.execute("chmod -r " .. fs.Q(path))
      end
   end

   local make_unwritable = function(path)
      if is_win then
         fs.execute("icacls " .. fs.Q(path) .. " /deny %USERNAME%:(WD,AD)")
      else
         fs.execute("chmod -w " .. fs.Q(path))
      end
   end

   local make_unexecutable = function(path)
      if is_win then
         fs.execute("icacls " .. fs.Q(path) .. " /deny %USERNAME%:(X)")
      else
         fs.execute("chmod -x " .. fs.Q(path))
      end
   end

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
         assert.falsy(pcall(fs.dir_iterator, tmpfile1))
      end)

      it("does nothing if the argument is invalid", function()
         assert.falsy(pcall(fs.dir_iterator, "/nonexistent"))
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
            lfs.chdir(olddir)
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
            assert.same(lfs.attributes(tmpdir).ino, lfs.attributes(fs.current_dir()).ino)
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
            lfs.chdir(olddir)
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
            assert.same(lfs.attributes(tmpdir).ino, lfs.attributes(lfs.currentdir()).ino)
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
            lfs.chdir(olddir)
         end
      end)

      it("returns true and changes the current directory to root if the current directory is valid", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         assert.truthy(fs.change_dir(tmpdir))
         local success = fs.change_dir_to_root()
         if not is_win then
            assert.truthy(success)
         end
         assert.same("/", fs.current_dir())
      end)

      it("returns false and does nothing if the current directory is not valid #unix", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         lfs.chdir(tmpdir)
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
            lfs.chdir(olddir)
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
         fd = assert(io.open(dstfile, "r"))
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
         fd = assert(io.open(dstfile, "r"))
         local dstcontent = fd:read("*a")
         assert.same("foo", dstcontent)
      end)

      it("returns false and does nothing if the source file does not exist", function()
         srcfile = get_tmp_path()
         dstfile = get_tmp_path()
         assert.falsy(fs.copy(srcfile, dstfile, nil))
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
end)
