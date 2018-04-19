local test_env = require("spec.util.test_env")

test_env.unload_luarocks()
local fs = require("luarocks.fs")
local lfs = require("lfs")
local is_win = test_env.TEST_TARGET_OS == "windows"

describe("Luarocks fs test #whitebox #w_fs", function()
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
         tmpfile = os.tmpname()
         local fd = assert(io.open(tmpfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         assert.same(true, fs.is_file(tmpfile))
      end)

      it("returns false when the argument does not exist", function()
         assert.same(false, fs.is_file("/nonexistent"))
      end)

      it("returns false when the argument exists but is not a file", function()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         assert.truthy(fs.is_dir(tmpdir))
      end)

      it("returns false when the argument is a file", function()
         tmpfile = os.tmpname()
         local fd = assert(io.open(tmpfile, "w"))
         assert(fd:write("foo"))
         fd:close()
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
         tmpfile = os.tmpname()
         local fd = assert(io.open(tmpfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         assert.truthy(fs.exists(tmpfile))
      end)

      it("returns true when the argument is a directory", function()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         assert.truthy(fs.change_dir(tmpdir))
         if is_win then
            assert.same(tmpdir, fs.current_dir())
         else
            assert.same(lfs.attributes(tmpdir).ino, lfs.attributes(lfs.currentdir()).ino)
         end
      end)

      it("returns false and does nothing when the argument is a file", function()
         tmpfile = os.tmpname()
         local fd = assert(io.open(tmpfile, "w"))
         assert(fd:write("foo"))
         fd:close()
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         assert.truthy(fs.change_dir(tmpdir))
         local success = fs.change_dir_to_root()
         if not is_win then
            assert.truthy(success)
         end
         assert.same("/", fs.current_dir())
      end)

      it("returns false and does nothing if the current directory is not valid #unix", function()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         assert.truthy(fs.make_dir(tmpdir))
         assert.same("directory", lfs.attributes(tmpdir, "mode"))
      end)

      it("returns true and creates the directory path specified by the argument", function()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         intdir = "/internaldir"
         local dirpath = tmpdir .. intdir
         assert.truthy(fs.make_dir(dirpath))
         assert.same("directory", lfs.attributes(tmpdir, "mode"))
         assert.same("directory", lfs.attributes(dirpath, "mode"))
      end)

      it("returns false and does nothing if the argument is not valid (file in the path)", function()
         tmpfile = os.tmpname()
         local fd = assert(io.open(tmpfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         intdir = "/internaldir"
         local dirpath = tmpfile .. intdir
         assert.falsy(fs.make_dir(dirpath))
      end)

      it("returns false and does nothing if the argument already exists", function()
         tmpfile = os.tmpname()
         local fd = assert(io.open(tmpfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         assert.falsy(fs.make_dir(tmpfile))
      end)
   end)

   local exists_file = function(path)
      local ok, err, code = os.rename(path, path)
      if not ok and code == 13 then
         return true
      end
      return ok
   end

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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         fs.remove_dir_if_empty(tmpdir)
         assert.falsy(exists_file(tmpdir))
      end)

      it("does nothing if the directory specified by the argument is not empty", function()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         tmpfile = "/internalfile"
         local filepath = tmpdir .. tmpfile
         lfs.touch(filepath)
         local fd = assert(io.open(filepath, "w"))
         assert(fd:write("foo"))
         fd:close()
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         fs.remove_dir_tree_if_empty(tmpdir)
         assert.falsy(exists_file(tmpdir))
      end)

      it("does nothing if the directory path specified by the argument is not empty", function()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         intdir = "/internaldir"
         local dirpath = tmpdir .. intdir
         lfs.mkdir(dirpath)
         tmpfile = "/internalfile"
         local filepath = dirpath .. tmpfile
         lfs.touch(filepath)
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
         srcfile = os.tmpname()
         local fd = assert(io.open(srcfile, "w"))
         local srccontent = "foo"
         assert(fd:write(srccontent))
         fd:close()
         dstfile = os.tmpname()
         os.remove(dstfile)
         assert.truthy(fs.copy(srcfile, dstfile, nil))
         fd = assert(io.open(dstfile, "r"))
         local dstcontent = fd:read("*a")
         assert.same(srccontent, dstcontent)
         if not is_win then
            assert.same(lfs.attributes(srcfile, "permissions"), lfs.attributes(dstfile, "permissions"))
         end
      end)

      it("returns true and copies contents of the source file to the destination file with custom permissions", function()
         srcfile = os.tmpname()
         local fd = assert(io.open(srcfile, "w"))
         local srccontent = "foo"
         assert(fd:write(srccontent))
         fd:close()
         dstfile = os.tmpname()
         os.remove(dstfile)
         assert.truthy(fs.copy(srcfile, dstfile, "755"))
         fd = assert(io.open(dstfile, "r"))
         local dstcontent = fd:read("*a")
         assert.same(srccontent, dstcontent)
         if not is_win then
            assert.same("rwxr-xr-x", lfs.attributes(dstfile, "permissions"))
         end
      end)

      it("returns false and does nothing if the source file does not exist", function()
         srcfile = os.tmpname()
         os.remove(srcfile)
         dstfile = os.tmpname()
         os.remove(dstfile)
         assert.falsy(fs.copy(srcfile, dstfile, nil))
         assert.falsy(exists_file(dstfile))
      end)

      it("returns false and does nothing if the source file doesn't have the proper permissions #unix", function()
         srcfile = os.tmpname()
         local fd = assert(io.open(srcfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         assert(fs.chmod(srcfile, "333"))
         dstfile = os.tmpname()
         os.remove(dstfile)
         assert.falsy(fs.copy(srcfile, dstfile, nil))
         assert.falsy(exists_file(dstfile))
      end)

      it("returns false and does nothing if the destination file directory doesn't have the proper permissions #unix", function()
         srcfile = os.tmpname()
         local fd = assert(io.open(srcfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         assert(fs.chmod(tmpdir, "666"))
         dstfile = tmpdir .. "/dstfile"
         assert.falsy(fs.copy(srcfile, dstfile, nil))
         assert(fs.chmod(tmpdir, "777"))
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
         srcdir = os.tmpname()
         os.remove(srcdir)
         lfs.mkdir(srcdir)
         srcintdir = srcdir .. "/internaldir"
         lfs.mkdir(srcintdir)
         srcfile = srcintdir .. "/internalfile"
         lfs.touch(srcfile)
         local fd = assert(io.open(srcfile, "w"))
         assert(fd:write("foo"))
         fd:close()
         dstdir = os.tmpname()
         os.remove(dstdir)
      end

      it("returns true and copies the contents (with their permissions) of the source dir to the destination dir", function()
         create_dir_tree()
         assert.truthy(fs.copy_contents(srcdir, dstdir, nil))
         assert.truthy(exists_file(dstdir))
         dstintdir = dstdir .. "/internaldir"
         assert.truthy(exists_file(dstintdir))
         dstfile = dstdir .. "/internaldir/internalfile"
         local fd = assert(io.open(dstfile, "r"))
         local dstfilecontent = fd:read("*a")
         assert.same("foo", dstfilecontent)
         if not is_win then
            assert.same(lfs.attributes(srcfile, "permissions"), lfs.attributes(dstfile, "permissions"))
         end
      end)

      it("returns true and copies the contents of the source dir to the destination dir with custom permissions", function()
         create_dir_tree()
         assert.truthy(fs.copy_contents(srcdir, dstdir, "755"))
         assert.truthy(exists_file(dstdir))
         dstintdir = dstdir .. "/internaldir"
         assert.truthy(exists_file(dstintdir))
         dstfile = dstdir .. "/internaldir/internalfile"
         local fd = assert(io.open(dstfile, "r"))
         local dstfilecontent = fd:read("*a")
         assert.same("foo", dstfilecontent)
         if not is_win then
            assert.same("rwxr-xr-x", lfs.attributes(dstfile, "permissions"))
         end
      end)

      it("returns false and does nothing if the source dir doesn't exist", function()
         srcdir = os.tmpname()
         os.remove(srcdir)
         dstdir = os.tmpname()
         os.remove(dstdir)
         assert.falsy(fs.copy_contents(srcdir, dstdir, nil))
         assert.falsy(exists_file(dstdir))
      end)

      it("returns false if the source argument is a file", function()
         srcdir = os.tmpname()
         local fd = assert(io.open(srcdir, "w"))
         assert(fd:write("foo"))
         fd:close()
         dstdir = os.tmpname()
         os.remove(dstdir)
         assert.falsy(fs.copy_contents(srcdir, dstdir, nil))
         assert.falsy(exists_file(dstdir))
      end)

      it("returns false and does nothing if the source dir doesn't have the proper permissions #unix", function()
         create_dir_tree()
         assert(fs.chmod(srcdir, "333"))
         assert.falsy(fs.copy_contents(srcdir, dstdir, nil))
         assert.falsy(exists_file(dstdir))
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
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         tmpintdir = tmpdir .. "/internaldir"
         lfs.mkdir(tmpintdir)
         tmpfile1 = tmpdir .. "/internalfile1"
         lfs.touch(tmpfile1)
         local fd = assert(io.open(tmpfile1, "w"))
         assert(fd:write("foo"))
         fd:close()
         tmpfile2 = tmpintdir .. "/internalfile2"
         lfs.touch(tmpfile2)
         fd = assert(io.open(tmpfile2, "w"))
         assert(fd:write("foo"))
         fd:close()
      end

      it("deletes the file specified by the argument", function()
         tmpfile1 = os.tmpname()
         tmpfile2 = os.tmpname()
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

      it("does nothing if the parent directory of the argument doesn't have the proper permissions #unix", function()
         create_dir_tree()
         assert(fs.chmod(tmpdir, "000"))
         fs.delete(tmpfile1)
         fs.delete(tmpfile2)
         fs.delete(tmpintdir)
         assert.truthy(exists_file(tmpfile2))
         assert.truthy(exists_file(tmpintdir))
         assert.truthy(exists_file(tmpfile1))
         assert.truthy(exists_file(tmpdir))
      end)
   end)
end)
