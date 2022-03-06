local test_env = require("spec.util.test_env")
local git_repo = require("spec.util.git_repo")

test_env.unload_luarocks()
test_env.setup_specs()
local cfg = require("luarocks.core.cfg")
local fetch = require("luarocks.fetch")
local fs = require("luarocks.fs")
local path = require("luarocks.path")
local rockspecs = require("luarocks.rockspecs")
local lfs = require("lfs")
local get_tmp_path = test_env.get_tmp_path
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

describe("luarocks fetch #unit #mock", function()
   local are_same_files = function(file1, file2)
      return file1 == file2 or lfs.attributes(file1).ino == lfs.attributes(file2).ino
   end

   local runner

   setup(function()
      cfg.init()
      fs.init()
      test_env.mock_server_init()

      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
      runner.tick = true
   end)

   teardown(function()
      test_env.mock_server_done()

      runner.shutdown()
   end)

   describe("fetch.fetch_url", function()

      it("fetches the url argument and returns the absolute path of the fetched file", function()
         local fetchedfile, err = fetch.fetch_url("http://localhost:8080/file/a_rock.lua")
         assert(fetchedfile, err)
         assert.truthy(are_same_files(fetchedfile, lfs.currentdir() .. "/a_rock.lua"))
         local fd = assert(io.open(fetchedfile, "r"))
         local fetchedcontent = assert(fd:read("*a"))
         fd:close()
         fd = assert(io.open(testing_paths.fixtures_dir .. "/a_rock.lua", "r"))
         local filecontent = assert(fd:read("*a"))
         fd:close()
         assert.same(fetchedcontent, filecontent)
         os.remove(fetchedfile)
      end)

      it("returns the absolute path of the filename argument if the url represents a file", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test.lua", "return {}", finally)

            fs.change_dir(tmpdir)
            local file, err = fetch.fetch_url("file://test.lua")
            assert.truthy(file, err)
            assert.truthy(are_same_files(file, lfs.currentdir() .. "/test.lua"))
            fs.pop_dir()
         end, finally)
      end)

      it("fails if local path is invalid and returns a helpful hint for relative paths", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("test.lua", "return {}", finally)

            local ok, err = fetch.fetch_url("file://boo.lua")
            assert.falsy(ok)
            assert.match("note that given path in rockspec is not absolute: file://boo.lua", err)
         end, finally)
      end)

      it("returns false and does nothing if the url argument contains a nonexistent file", function()
         assert.falsy(fetch.fetch_url("http://localhost:8080/file/nonexistent"))
      end)

      it("returns false and does nothing if the url argument is invalid", function()
         assert.falsy(fetch.fetch_url("invalid://url", "file"))
      end)
   end)

   describe("fetch.fetch_url_at_temp_dir", function()
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

      it("returns the absolute path and the parent directory of the file specified by the url", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         tmpfile = tmpdir .. "/tmpfile"
         local fd = assert(io.open(tmpfile, "w"))
         local pathname, dirname = fetch.fetch_url_at_temp_dir("file://" .. tmpfile, "test")
         assert.truthy(are_same_files(tmpfile, pathname))
         assert.truthy(are_same_files(tmpdir, dirname))
      end)

      it("returns true and fetches the url into a temporary dir", function()
         local fetchedfile, tmpdir = fetch.fetch_url_at_temp_dir("http://localhost:8080/file/a_rock.lua", "test")
         assert(fetchedfile, tmpdir)
         assert.truthy(are_same_files(fetchedfile, tmpdir .. "/a_rock.lua"))
         local fd = assert(io.open(fetchedfile, "r"))
         local fetchedcontent = assert(fd:read("*a"))
         fd:close()
         fd = assert(io.open(testing_paths.fixtures_dir .. "/a_rock.lua", "r"))
         local filecontent = assert(fd:read("*a"))
         fd:close()
         assert.same(fetchedcontent, filecontent)
      end)

      it("returns true and fetches the url into a temporary dir with custom filename", function()
         local fetchedfile, tmpdir = fetch.fetch_url_at_temp_dir("http://localhost:8080/file/a_rock.lua", "test", "my_a_rock.lua")
         assert(fetchedfile, tmpdir)
         assert.truthy(are_same_files(fetchedfile, tmpdir .. "/my_a_rock.lua"))
         assert.truthy(string.find(tmpdir, "test"))
         local fd = assert(io.open(fetchedfile, "r"))
         local fetchedcontent = assert(fd:read("*a"))
         fd:close()
         fd = assert(io.open(testing_paths.fixtures_dir .. "/a_rock.lua", "r"))
         local filecontent = assert(fd:read("*a"))
         fd:close()
         assert.same(fetchedcontent, filecontent)
      end)

      it("returns false and does nothing if the file specified in the url is nonexistent", function()
         assert.falsy(fetch.fetch_url_at_temp_dir("file://nonexistent", "test"))
         assert.falsy(fetch.fetch_url_at_temp_dir("http://localhost:8080/file/nonexistent", "test"))
      end)

      it("returns false and does nothing if the url is invalid", function()
         assert.falsy(fetch.fetch_url_at_temp_dir("url://invalid", "test"))
      end)
   end)

   describe("fetch.find_base_dir", function()
      it("extracts the archive given by the file argument and returns the inferred and the actual root directory in the archive", function()
         local url = "http://localhost:8080/file/an_upstream_tarball-0.1.tar.gz"
         local file, tmpdir = assert(fetch.fetch_url_at_temp_dir(url, "test"))
         local inferreddir, founddir = fetch.find_base_dir(file, tmpdir, url)
         assert.truthy(are_same_files(inferreddir, founddir))
         assert.truthy(lfs.attributes(tmpdir .. "/" .. founddir))
      end)

      it("extracts the archive given by the file argument with given base directory and returns the inferred and the actual root directory in the archive", function()
         local url = "http://localhost:8080/file/an_upstream_tarball-0.1.tar.gz"
         local file, tmpdir = assert(fetch.fetch_url_at_temp_dir(url, "test"))
         local inferreddir, founddir = fetch.find_base_dir(file, tmpdir, url, "basedir")
         assert.truthy(are_same_files(inferreddir, "basedir"))
         assert.truthy(are_same_files(founddir, "an_upstream_tarball-0.1"))
         assert.truthy(lfs.attributes(tmpdir .. "/" .. founddir))
      end)

      it("returns false and does nothing if the temporary directory doesn't exist", function()
         assert.falsy(fetch.find_base_dir("file", "nonexistent", "url"))
      end)
   end)

   describe("fetch.fetch_and_unpack_rock", function()
      local tmpdir

      after_each(function()
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)

      it("unpacks the rock file from the url and returns its resulting temporary parent directory", function()
         tmpdir = fetch.fetch_and_unpack_rock("http://localhost:8080/file/a_rock-1.0-1.src.rock")
         assert.truthy(string.find(tmpdir, "a_rock%-1%.0%-1"))
         assert.truthy(lfs.attributes(tmpdir .. "/a_rock-1.0-1.rockspec"))
         assert.truthy(lfs.attributes(tmpdir .. "/a_rock.lua"))
      end)

      it("unpacks the rock file from the url with custom unpacking directory", function()
         tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         local resultingdir = fetch.fetch_and_unpack_rock("http://localhost:8080/file/a_rock-1.0-1.src.rock", tmpdir)
         assert.truthy(are_same_files(resultingdir, tmpdir))
         assert.truthy(lfs.attributes(resultingdir .. "/a_rock-1.0-1.rockspec"))
         assert.truthy(lfs.attributes(resultingdir .. "/a_rock.lua"))
      end)

      it("does nothing if the url doesn't represent a rock file", function()
         assert.falsy(pcall(fetch.fetch_and_unpack_rock, "http://localhost:8080/file/a_rock.lua"))
      end)

      it("does nothing if the rock file url is invalid", function()
         assert.falsy(pcall(fetch.fetch_and_unpack_rock, "url://invalid"))
      end)

      it("does nothing if the rock file url represents a nonexistent file", function()
         assert.falsy(pcall(fetch.fetch_and_unpack_rock, "url://invalid"))
         assert.falsy(pcall(fetch.fetch_and_unpack_rock, "http://localhost:8080/file/nonexistent"))
      end)
   end)

   describe("fetch.load_local_rockspec", function()
      local tmpdir
      local olddir

      before_each(function()
         tmpdir = get_tmp_path()
         olddir = lfs.currentdir()
         lfs.mkdir(tmpdir)
         lfs.chdir(tmpdir)
         fs.change_dir(tmpdir)
      end)

      after_each(function()
         if olddir then
            lfs.chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("returns a table representing the rockspec from the given file skipping some checks if the quick argument is enabled", function()
         local rockspec = fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec", true)
         assert.same(rockspec.name, "a_rock")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.source.url, "http://localhost:8080/file/a_rock.lua")
         assert.same(rockspec.description, { summary = "An example rockspec" })

         write_file("missing_mandatory_field-1.0-1.rockspec", [[
            package="missing_mandatory_field"
            version="1.0-1"
            source = {
               url = "http://example.com/foo.tar.gz"
            }
         ]], finally)
         rockspec = fetch.load_local_rockspec("missing_mandatory_field-1.0-1.rockspec", true)
         assert.same(rockspec.name, "missing_mandatory_field")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.source.url, "http://example.com/foo.tar.gz")

         write_file("unknown_field-1.0-1.rockspec", [[
            package="unknown_field"
            version="1.0-1"
            source = {
               url = "http://example.com/foo.tar.gz"
            }
            unknown="foo"
         ]], finally)
         rockspec = fetch.load_local_rockspec("unknown_field-1.0-1.rockspec", true)
         assert.same(rockspec.name, "unknown_field")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.source.url, "http://example.com/foo.tar.gz")

         -- The previous calls fail if the detailed checking is done
         path.use_tree(testing_paths.testing_tree)
         assert.falsy(fetch.load_local_rockspec("missing_mandatory_field-1.0-1.rockspec"))
         assert.falsy(fetch.load_local_rockspec("unknown_field-1.0-1.rockspec"))
      end)

      it("returns a table representing the rockspec from the given file", function()
         path.use_tree(testing_paths.testing_tree)
         local rockspec = fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec")
         assert.same(rockspec.name, "a_rock")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.description, { summary = "An example rockspec" })
         assert.same(rockspec.source.url, "http://localhost:8080/file/a_rock.lua")
      end)

      it("returns false if the rockspec in invalid", function()
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/invalid_say-1.3-1.rockspec"))
      end)

      it("returns false if the rockspec version is not supported", function()
         assert.falsy(fetch.load_local_rockspec("invalid_version.rockspec"))
      end)

      it("returns false if the rockspec doesn't pass the type checking", function()
         write_file("type_mismatch_string-1.0-1.rockspec", [[
            package="type_mismatch_version"
            version=1.0
         ]], finally)
         assert.falsy(fetch.load_local_rockspec("type_mismatch_string-1.0-1.rockspec"))
      end)

      it("returns false if the rockspec file name is not right", function()
         write_file("invalid_rockspec_name.rockspec", [[
            package="invalid_rockspec_name"
            version="1.0-1"
            source = {
               url = "http://example.com/foo.tar.gz"
            }
            build = {

            }
         ]], finally)
         assert.falsy(fetch.load_local_rockspec("invalid_rockspec_name.rockspec"))
      end)

      it("returns false if the version in the rockspec file name doesn't match the version declared in the rockspec", function()
         write_file("inconsistent_versions-1.0-1.rockspec", [[
            package="inconsistent_versions"
            version="1.0-2"
            source = {
               url = "http://example.com/foo.tar.gz"
            }
            build = {

            }
         ]], finally)
         assert.falsy(fetch.load_local_rockspec("inconsistent_versions-1.0-1.rockspec"))
      end)
   end)

   describe("fetch.load_rockspec", function()
      it("returns a table containing the requested rockspec by downloading it into a temporary directory", function()
         path.use_tree(testing_paths.testing_tree)
         local rockspec = fetch.load_rockspec("http://localhost:8080/file/a_rock-1.0-1.rockspec")
         assert.same(rockspec.name, "a_rock")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.description, { summary = "An example rockspec" })
         assert.same(rockspec.source.url, "http://localhost:8080/file/a_rock.lua")
         rockspec = fetch.load_rockspec(testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec")
         assert.same(rockspec.name, "a_rock")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.description, { summary = "An example rockspec" })
         assert.same(rockspec.source.url, "http://localhost:8080/file/a_rock.lua")
      end)

      it("returns a table containing the requested rockspec by downloading it into a given directory", function()
         local tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)

         path.use_tree(testing_paths.testing_tree)
         local rockspec = fetch.load_rockspec("http://localhost:8080/file/a_rock-1.0-1.rockspec", tmpdir)
         assert.same(rockspec.name, "a_rock")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.description, { summary = "An example rockspec" })
         assert.same(rockspec.source.url, "http://localhost:8080/file/a_rock.lua")
         assert.truthy(lfs.attributes(tmpdir .. "/a_rock-1.0-1.rockspec"))

         lfs.rmdir(tmpdir)
      end)

      it("returns false if the given download directory doesn't exist", function()
         assert.falsy(fetch.load_rockspec("http://localhost:8080/file/a_rock-1.0-1.rockspec", "nonexistent"))
      end)

      it("returns false if the given filename is not a valid rockspec name", function()
         assert.falsy(fetch.load_rockspec("http://localhost:8080/file/a_rock.lua"))
      end)
   end)

   describe("fetch.get_sources", function()
      local tmpdir
      local olddir

      before_each(function()
         tmpdir = get_tmp_path()
         olddir = lfs.currentdir()
         lfs.mkdir(tmpdir)
         lfs.chdir(tmpdir)
         fs.change_dir(tmpdir)
      end)

      after_each(function()
         if olddir then
            lfs.chdir(olddir)
            if tmpdir then
               lfs.rmdir(tmpdir)
            end
         end
      end)

      it("downloads the sources for building a rock and returns the resulting source filename and its parent directory", function()
         local rockspec = assert(fetch.load_rockspec("http://localhost:8080/file/a_rock-1.0-1.rockspec"))
         local file, dir = fetch.get_sources(rockspec, false)
         assert.truthy(are_same_files(dir .. "/a_rock.lua", file))
      end)

      it("downloads the sources for building a rock into a given directory and returns the resulting source filename and its parent directory", function()
         local tmpdir = get_tmp_path()
         lfs.mkdir(tmpdir)
         local rockspec = assert(fetch.load_rockspec("http://localhost:8080/file/a_rock-1.0-1.rockspec"))
         local file, dir = fetch.get_sources(rockspec, false, tmpdir)
         assert.truthy(are_same_files(tmpdir, dir))
         assert.truthy(are_same_files(dir .. "/a_rock.lua", file))
         lfs.rmdir(tmpdir)
      end)

      it("downloads the sources for building a rock, extracts the downloaded tarball and returns the resulting source filename and its parent directory", function()
         local rockspec = assert(fetch.load_rockspec("http://localhost:8080/file/busted_project-0.1-1.rockspec"))
         local file, dir = fetch.get_sources(rockspec, true)
         assert.truthy(are_same_files(dir .. "/busted_project-0.1.tar.gz", file))
         assert.truthy(lfs.attributes(dir .. "/busted_project"))
         assert.truthy(lfs.attributes(dir .. "/busted_project/sum.lua"))
         assert.truthy(lfs.attributes(dir .. "/busted_project/spec/sum_spec.lua"))
      end)

      it("returns false and does nothing if the destination directory doesn't exist", function()
         local rockspec = assert(fetch.load_rockspec("http://localhost:8080/file/a_rock-1.0-1.rockspec"))
         assert.falsy(fetch.get_sources(rockspec, false, "nonexistent"))
      end)

      it("returns false and does nothing if the rockspec source url is invalid", function()
         write_file("invalid_url-1.0-1.rockspec", [[
            package="invalid_url"
            version="1.0-1"
            source = {
               url = "http://localhost:8080/file/nonexistent"
            }
            build = {

            }
         ]], finally)
         local rockspec = assert(fetch.load_rockspec("invalid_url-1.0-1.rockspec"))
         assert.falsy(fetch.get_sources(rockspec, false))
      end)

      it("returns false and does nothing if the downloaded rockspec has an invalid md5 checksum", function()
         write_file("invalid_checksum-1.0-1.rockspec", [[
            package="invalid_checksum"
            version="1.0-1"
            source = {
               url = "http://localhost:8080/file/a_rock.lua",
               md5 = "invalid"
            }
            build = {

            }
         ]], finally)
         local rockspec = assert(fetch.load_rockspec("invalid_checksum-1.0-1.rockspec"))
         assert.falsy(fetch.get_sources(rockspec, false))
      end)
   end)

   describe("fetch_sources #unix #git", function()
      local git

      setup(function()
         git = git_repo.start()
      end)

      teardown(function()
         if git then
            git:stop()
         end
      end)

      it("from #git", function()
         local rockspec, err = rockspecs.from_persisted_table("testrock-dev-1.rockspec", {
            rockspec_format = "3.0",
            package = "testrock",
            version = "dev-1",
            source = {
               url = "git://localhost/testrock",
            },
         }, nil)
         assert.falsy(err)
         local pathname, tmpdir = fetch.fetch_sources(rockspec, false)
         assert.are.same("testrock", pathname)
         assert.match("luarocks_testrock%-dev%-1%-", tmpdir)
         assert.match("^%d%d%d%d%d%d%d%d.%d%d%d%d%d%d.%x+$", tostring(rockspec.source.identifier))
      end)
   end)

end)
