local test_env = require("spec.util.test_env")
local get_tmp_path = test_env.get_tmp_path
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

local lfs = require("lfs")
local fs = require("luarocks.fs")
local cfg = require("luarocks.core.cfg")
local patch = require("luarocks.tools.patch")
local zip_ok, zip = pcall(require, "luarocks.tools.zip")
local tar = require("luarocks.tools.tar")

-- ensures fs and lfs are synchronized.
-- do not use either on its own in this module.
local function change_dir(dir)
   lfs.chdir(dir)
   fs.change_dir(dir)
end

local function setup_temp_dir_for_test()
   local olddir = lfs.currentdir()
   local tmpdir = get_tmp_path()
   lfs.mkdir(tmpdir)
   change_dir(tmpdir)
   return tmpdir, olddir
end

local function teardown_temp_dir_for_test(tmpdir, olddir)
   if olddir then
      change_dir(olddir)
      if tmpdir then
         fs.delete(tmpdir)
      end
   end
end

local lao =
[[The Nameless is the origin of Heaven and Earth;
The named is the mother of all things.

Therefore let there always be non-being,
  so we may see their subtlety,
And let there always be being,
  so we may see their outcome.
The two are the same,
But after they are produced,
  they have different names.
They both may be called deep and profound.
Deeper and more profound,
The door of all subtleties!]]

local tzu =
[[The Way that can be told of is not the eternal Way;
The name that can be named is not the eternal name.
The Nameless is the origin of Heaven and Earth;
The Named is the mother of all things.
Therefore let there always be non-being,
  so we may see their subtlety,
And let there always be being,
  so we may see their outcome.
The two are the same,
But after they are produced,
  they have different names.]]

local valid_patch1 =
[[--- lao	2002-02-21 23:30:39.942229878 -0800
+++ tzu	2002-02-21 23:30:50.442260588 -0800
@@ -1,7 +1,6 @@
-The Way that can be told of is not the eternal Way;
-The name that can be named is not the eternal name.
 The Nameless is the origin of Heaven and Earth;
-The Named is the mother of all things.
+The named is the mother of all things.
+
 Therefore let there always be non-being,
   so we may see their subtlety,
 And let there always be being,
@@ -9,3 +8,6 @@
 The two are the same,
 But after they are produced,
   they have different names.
+They both may be called deep and profound.
+Deeper and more profound,
+The door of all subtleties!]]

local valid_patch2 =
[[--- /dev/null	1969-02-21 23:30:39.942229878 -0800
+++ tzu	2002-02-21 23:30:50.442260588 -0800
@@ -1,7 +1,6 @@
-The Way that can be told of is not the eternal Way;
-The name that can be named is not the eternal name.
 The Nameless is the origin of Heaven and Earth;
-The Named is the mother of all things.
+The named is the mother of all things.
+
 Therefore let there always be non-being,
   so we may see their subtlety,
 And let there always be being,
@@ -9,3 +8,6 @@
 The two are the same,
 But after they are produced,
   they have different names.
+They both may be called deep and profound.
+Deeper and more profound,
+The door of all subtleties!]]

local invalid_patch1 =
[[--- lao	2002-02-21 23:30:39.942229878 -0800
+++ tzu	2002-02-21 23:30:50.442260588 -0800
@@ -1,7 +1,6 @@
-The Way that can be told of is not the eternal Way;
-The name that can be named is not the eternal name.
 The Nameless is the origin of Heaven and Earth;
-The Named is the mother of all things.
--- Extra
+The named is the mother of all things.
+
 Therefore let there always be non-being,
   so we may see their subtlety,
 And let there always be being,
--- Extra
@@ -9,3 +8,7 @@
 The two are the same,
 But after they are produced,
   they have different names.
+They both may be called deep and profound.
+Deeper and more profound,
+The door of all subtleties!]]

local invalid_patch2 =
[[--- lao	2002-02-21 23:30:39.942229878 -0800
+++   tzu	2002-02-21 23:30:50.442260588 -0800
@@ -1,7 +1,6 @@
-The Way that can be told of is not the eternal Way;
-The name that can be named is not the eternal name.
 The Nameless is the origin of Heaven and Earth;
-The Named is the mother of all things.
+The named is the mother of all things.
+
 Therefore let there always be non-being,
   so we may see their subtlety,
 And let there always be being,
@@ -9,3 +8,6 @@
 The two are the same,
 But after they are produced,
   they have different names.
+They both may be called deep and profound.
+Deeper and more profound,
? ...
+The door of all subtleties!]]

local invalid_patch3 =
[[---     lao	2002-02-21 23:30:39.942229878 -0800
+++ tzu	2002-02-21 23:30:50.442260588 -0800
@@ -1,7 +1,6 @@
-The Way that can be told of is not the eternal Way;
-The name that can be named is not the eternal name.
 The Nameless is the origin of Heaven and Earth;
-The Named is the mother of all things.
+The named is the mother of all things.
+
 Therefore let there always be non-being,
   so we may see their subtlety,
 And let there always be being,
@@ -9,3 +8,6 @@
 The two are the same,
 But after they are produced,
   they have different names.
+They both may be called deep and profound.
+Deeper and more profound,
? ...
+The door of all subtleties!]]

describe("Luarocks patch test #unit", function()
   local runner

   lazy_setup(function()
      cfg.init()
      fs.init()
      lfs.currentdir(fs.current_dir())
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

   describe("patch.read_patch", function()
      it("returns a table with the patch file info and the result of parsing the file", function()
         local t, result

         write_file("test.patch", valid_patch1, finally)
         t, result = patch.read_patch("test.patch")
         assert.truthy(result)
         assert.truthy(t)

         write_file("test.patch", invalid_patch1, finally)
         t, result = patch.read_patch("test.patch")
         assert.falsy(result)
         assert.truthy(t)

         write_file("test.patch", invalid_patch2, finally)
         t, result = patch.read_patch("test.patch")
         assert.falsy(result)
         assert.truthy(t)

         write_file("test.patch", invalid_patch3, finally)
         t, result = patch.read_patch("test.patch")
         assert.falsy(result)
         assert.truthy(t)
      end)
   end)

   describe("patch.apply_patch", function()
      local tmpdir
      local olddir

      before_each(function()
         tmpdir, olddir = setup_temp_dir_for_test()

         write_file("lao", tzu, finally)
         write_file("tzu", lao, finally)
      end)

      after_each(function()
         teardown_temp_dir_for_test(tmpdir, olddir)
      end)

      it("applies the given patch and returns the result of patching", function()
         write_file("test.patch", valid_patch1, finally)
         local p = patch.read_patch("test.patch")
         local result = patch.apply_patch(p)
         assert.truthy(result)
      end)

      it("applies the given patch with custom arguments and returns the result of patching", function()
         write_file("test.patch", valid_patch2, finally)
         local p = patch.read_patch("test.patch")
         local result = patch.apply_patch(p, nil, true)
         assert.truthy(result)
      end)

      it("fails if the patch file is invalid", function()
         write_file("test.patch", invalid_patch1, finally)
         local p, all_ok = patch.read_patch("test.patch")
         assert.falsy(all_ok)
      end)

      it("returns false if the files from the patch doesn't exist", function()
         os.remove("lao")
         os.remove("tzu")

         write_file("test.patch", valid_patch1, finally)
         local p = patch.read_patch("test.patch")
         local result = patch.apply_patch(p)
         assert.falsy(result)
      end)

      it("returns false if the target file was already patched", function()
         write_file("test.patch", valid_patch1, finally)
         local p = patch.read_patch("test.patch")
         local result = patch.apply_patch(p)
         assert.truthy(result)

         result = patch.apply_patch(p)
         assert.falsy(result)
      end)
   end)
end)

describe("luarocks.tools.tar", function()
   local runner

   lazy_setup(function()
      cfg.init()
      fs.init()
      lfs.currentdir(fs.current_dir())
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

   -- Build the 512-byte header block of a POSIX tar entry (regular file).
   -- The checksum is not verified for regular files by tar.untar.
   local function make_tar_entry(name, data)
      local header = name:sub(1, 100)
         .. string.rep("\0", 100 - math.min(100, #name))
         .. ("%07o\0"):format(0644)
         .. string.rep("\0", 8)   -- uid
         .. string.rep("\0", 8)   -- gid
         .. ("%011o\0"):format(#data)
         .. string.rep("\0", 12)  -- mtime
         .. string.rep(" ", 8)   -- checksum (unused for typeflag "0")
         .. "0"                  -- typeflag: regular file
         .. string.rep("\0", 100) -- linkname
         .. "ustar\0"           -- magic
         .. "00"                -- version
         .. string.rep("\0", 512 - 265)
      return header .. data .. string.rep("\0", (512 - #data % 512) % 512)
   end

   describe("tar.untar", function()
      local tmpdir
      local olddir

      before_each(function()
         tmpdir, olddir = setup_temp_dir_for_test()
      end)

      after_each(function()
         teardown_temp_dir_for_test(tmpdir, olddir)
      end)

      it("extracts a valid archive", function()
         write_file("valid.tar", make_tar_entry("file1.txt", "content1"), finally)
         local ok, err = tar.untar("valid.tar", ".")
         assert.truthy(ok, err)
         local fd = assert(io.open("file1.txt", "r"))
         assert.same("content1", fd:read("*a"))
         fd:close()
      end)

      it("rejects archives with entries escaping the destination directory", function()
         fs.make_dir("outside")
         -- target must not exist before: a vulnerable untar would create it
         assert.falsy(io.open("outside/evil.txt", "r"))

         write_file("evil.tar", make_tar_entry("../evil.txt", "evil content"), finally)
         local ok, err = tar.untar("evil.tar", ".")
         assert.falsy(ok)
         assert.match("escapes the destination directory", err)
         assert.falsy(io.open("outside/evil.txt", "r"))
      end)
   end)
end)

describe("luarocks.tools.zip", function()
   local runner

   lazy_setup(function()
      cfg.init()
      fs.init()
      lfs.currentdir(fs.current_dir())
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)

   lazy_teardown(function()
      runner.save_stats()
   end)

   if zip_ok then
      describe("zip.unzip", function()
         local tmpdir
         local olddir

         before_each(function()
            tmpdir, olddir = setup_temp_dir_for_test()
         end)

         after_each(function()
            teardown_temp_dir_for_test(tmpdir, olddir)
         end)

         it("extracts a valid archive", function()
            write_file("file1.txt", "content1", finally)
            assert.truthy(zip.zip("archive.zip", "file1.txt"))
            os.remove("file1.txt")

            local ok, err = zip.unzip("archive.zip")
            assert.truthy(ok, err)
            assert.truthy(io.open("file1.txt", "r"))
         end)

         it("rejects archives with entries escaping the extraction directory", function()
            fs.make_dir("outside")
            write_file("outside/evil-src.txt", "evil content", finally)

            fs.make_dir("ext")
            change_dir("ext")
            assert.truthy(zip.zip("evil.zip", "../outside/evil-src.txt"))
            -- remove the source: a vulnerable unzip would recreate it outside "ext"
            os.remove("../outside/evil-src.txt")
            assert.falsy(io.open("../outside/evil-src.txt", "r"))

            local ok, err = zip.unzip("evil.zip")
            assert.falsy(ok)
            assert.match("escapes the extraction directory", err)
            assert.falsy(io.open("../outside/evil-src.txt", "r"))
         end)
      end)
   else
      it("skips zip.unzip tests (lua-zlib not available)", function()
         -- no-op
      end)
   end
end)
