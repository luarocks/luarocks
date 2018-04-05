local test_env = require("spec.util.test_env")
local git_repo = require("spec.util.git_repo")

test_env.unload_luarocks()
local fetch = require("luarocks.fetch")

describe("Luarocks fetch test #whitebox #w_fetch", function()
   it("Fetch url to base dir", function()
      assert.are.same("v0.3", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2/archive/v0.3.zip"))
      assert.are.same("lua-compat-5.2", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2.zip"))
      assert.are.same("lua-compat-5.2", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2.tar.gz"))
      assert.are.same("lua-compat-5.2", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2.tar.bz2"))
      assert.are.same("parser.moon", fetch.url_to_base_dir("git://example.com/Cirru/parser.moon"))
      assert.are.same("v0.3", fetch.url_to_base_dir("https://example.com/hishamhm/lua-compat-5.2/archive/v0.3"))
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
