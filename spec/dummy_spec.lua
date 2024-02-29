-- Dummy test file for including files with 0% coverage in the luacov report

local test_env = require("spec.util.test_env")
local testing_paths = test_env.testing_paths

test_env.setup_specs()
local runner = require("luacov.runner")
runner.init(testing_paths.testrun_dir .. "/luacov.config")

require("luarocks.build.cmake")
require("luarocks.build.command")
require("luarocks.tools.tar")
require("luarocks.fetch.cvs")
require("luarocks.fetch.git_file")
require("luarocks.fetch.git_https")
require("luarocks.fetch.git_ssh")
require("luarocks.fetch.hg_http")
require("luarocks.fetch.hg_https")
require("luarocks.fetch.hg_ssh")
require("luarocks.fetch.hg")
require("luarocks.fetch.sscm")
require("luarocks.fetch.svn")

runner.save_stats()
