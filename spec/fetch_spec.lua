local test_env = require("spec.util.test_env")
local git_repo = require("spec.util.git_repo")

test_env.unload_luarocks()
test_env.setup_specs()
local fetch = require("luarocks.fetch")
local path = require("luarocks.path")
local lfs = require("lfs")
local testing_paths = test_env.testing_paths
local get_tmp_path = test_env.get_tmp_path

describe("Luarocks fetch test #unit", function()
   local are_same_files = function(file1, file2)
      return file1 == file2 or lfs.attributes(file1).ino == lfs.attributes(file2).ino
   end
   
   local runner
   
   setup(function()
      runner = require("luacov.runner")
      runner.init(testing_paths.testrun_dir .. "/luacov.config")
   end)
   
   teardown(function()
      runner.shutdown()
   end)
   
   describe("fetch.fetch_url #mock", function()
      setup(function()
         test_env.mock_server_init()
      end)
      
      teardown(function()
         test_env.mock_server_done()
      end)
      
      it("fetches the url argument and returns the absolute path of the fetched file", function()
         local fetchedfile = fetch.fetch_url("http://localhost:8080/file/a_rock.lua")
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
         local file = fetch.fetch_url("file://a_rock.lua")
         assert.truthy(are_same_files(file, lfs.currentdir() .. "/a_rock.lua"))
      end)
      
      it("returns false and does nothing if the url argument contains a nonexistent file", function()
         assert.falsy(fetch.fetch_url("http://localhost:8080/file/nonexistent"))
      end)
      
      it("returns false and does nothing if the url argument is invalid", function()
         assert.falsy(fetch.fetch_url("invalid://url", "file"))
      end)
   end)
   
   describe("fetch.fetch_url_at_temp_dir #mock", function()
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
      
      setup(function()
         test_env.mock_server_init()
      end)
      
      teardown(function()
         test_env.mock_server_done()
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

   describe("fetch.find_base_dir #mock", function()
      setup(function()
         test_env.mock_server_init()
      end)
      
      teardown(function()
         test_env.mock_server_done()
      end)
      
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
   
   describe("fetch.fetch_and_unpack_rock #mock", function()
      local tmpdir
      
      after_each(function()
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)
      
      setup(function()
         test_env.mock_server_init()
      end)
      
      teardown(function()
         test_env.mock_server_done()
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

   describe("fetch.url_to_base_dir", function()
      assert.are.same("v0.3", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2/archive/v0.3.zip"))
      assert.are.same("lua-compat-5.2", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2.zip"))
      assert.are.same("lua-compat-5.2", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2.tar.gz"))
      assert.are.same("lua-compat-5.2", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2.tar.bz2"))
      assert.are.same("parser.moon", fetch.url_to_base_dir("git://example.com/Cirru/parser.moon"))
      assert.are.same("v0.3", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2/archive/v0.3"))
   end)
   
   describe("fetch.load_local_rockspec", function()
      it("returns a table representing the rockspec from the given file skipping some checks if the quick argument is enabled", function()
         local rockspec = fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec", true)
         assert.same(rockspec.name, "a_rock")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.source.url, "http://localhost:8080/file/a_rock.lua")
         assert.same(rockspec.description, { summary = "An example rockspec" })
         
         rockspec = fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/missing_mandatory_field-1.0-1.rockspec", true)
         assert.same(rockspec.name, "missing_mandatory_field")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.source.url, "http://example.com/foo.tar.gz")
         
         rockspec = fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/unknown_field-1.0-1.rockspec", true)
         assert.same(rockspec.name, "unknown_field")
         assert.same(rockspec.version, "1.0-1")
         assert.same(rockspec.source.url, "http://example.com/foo.tar.gz")
         
         -- The previous calls fail if the detailed checking is done
         assert.falsy(pcall(fetch.load_local_rockspec, testing_paths.fixtures_dir .. "/a_rock-1.0-1.rockspec"))
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/missing_mandatory_field-1.0-1.rockspec"))
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/unknown_field-1.0-1.rockspec"))
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
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/invalid_validate-args-1.5.4-1.rockspec"))
      end)
      
      it("returns false if the rockspec version is not supported", function()
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/invalid_version.rockspec"))
      end)
      
      it("returns false if the rockspec doesn't pass the type checking", function()
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/type_mismatch_string-1.0-1.rockspec"))
      end)
      
      it("returns false if the rockspec file name is not right", function()
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/invalid_rockspec_name.rockspec"))
      end)
      
      it("returns false if the version in the rockspec file name doesn't match the version declared in the rockspec", function()
         assert.falsy(fetch.load_local_rockspec(testing_paths.fixtures_dir .. "/inconsistent_versions-1.0-1.rockspec"))
      end)
   end)
   
   describe("fetch.load_rockspec #mock", function()
      setup(function()
         test_env.mock_server_init()
      end)
      
      teardown(function()
         test_env.mock_server_done()
      end)
      
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
   
   describe("fetch.get_sources #mock", function()
      setup(function()
         test_env.mock_server_init()
      end)
      
      teardown(function()
         test_env.mock_server_done()
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
         local rockspec = assert(fetch.load_rockspec("http://localhost:8080/file/invalid_url-1.0-1.rockspec"))
         assert.falsy(fetch.get_sources(rockspec, false))
      end)
      
      it("returns false and does nothing if the downloaded rockspec has an invalid md5 checksum", function()
         local rockspec = assert(fetch.load_rockspec("http://localhost:8080/file/invalid_checksum-1.0-1.rockspec"))
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
         local rockspec = {
            format_is_at_least = function()
               return true
            end,
            name = "testrock",
            version = "dev-1",
            source = {
               protocol = "git",
               url = "git://localhost/testrock",
            },
            variables = {
               GIT = "git",
            },
         }
         local pathname, tmpdir = fetch.fetch_sources(rockspec, false)
         assert.are.same("testrock", pathname)
         assert.match("luarocks_testrock%-dev%-1%-", tmpdir)
         assert.match("^%d%d%d%d%d%d%d%d.%d%d%d%d%d%d.%x+$", tostring(rockspec.source.identifier))
      end)
   end)

end)
