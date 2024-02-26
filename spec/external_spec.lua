local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths

describe("luarocks external commands #integration", function()
   lazy_setup(function()
      test_env.setup_specs()
      test_env.mock_server_init()
   end)

   lazy_teardown(function()
      test_env.mock_server_done()
   end)

   it("installs a legacy external command", function()
      local rockspec = testing_paths.fixtures_dir .. "/legacyexternalcommand-0.1-1.rockspec"
      assert.is_truthy(run.luarocks_bool("build " .. rockspec))
      assert.is.truthy(run.luarocks("show legacyexternalcommand"))
      local output = run.luarocks("legacyexternalcommand")
      assert.match("Argument missing", output)
      output = run.luarocks("legacyexternalcommand foo")
      assert.match("ARG1\tfoo", output)
      assert.match("ARG2\tnil", output)
      output = run.luarocks("legacyexternalcommand foo bar")
      assert.match("ARG1\tfoo", output)
      assert.match("ARG2\tbar", output)
      output = run.luarocks("legacyexternalcommand foo bar bla")
      assert.match("ARG1\tfoo", output)
      assert.match("ARG2\tbar", output)
   end)
end)

