local test_env = require("spec.util.test_env")
local run = test_env.run
local testing_paths = test_env.testing_paths
local write_file = test_env.write_file

describe("luarocks.loader", function()

   before_each(function()
      test_env.setup_specs()
   end)

   describe("#unit", function()
      it("starts", function()
         assert(run.lua_bool([[-e "require 'luarocks.loader'; print(package.loaded['luarocks.loaded'])"]]))
      end)

      describe("which", function()
         it("finds modules using package.path", function()
            assert(run.lua_bool([[-e "loader = require 'luarocks.loader'; local x,y,z,p = loader.which('luarocks.loader', 'p'); assert(p == 'p')"]]))
         end)
      end)
   end)

   describe("#integration", function()
      it("respects version constraints", function()
         test_env.run_in_tmp(function(tmpdir)
            write_file("rock_b_01.lua", "print('ROCK B 0.1'); return {}", finally)
            write_file("rock_b-0.1-1.rockspec", [[
               package = "rock_b"
               version = "0.1-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/rock_b_01.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     rock_b = "rock_b_01.lua"
                  }
               }
            ]], finally)

            write_file("rock_b_10.lua", "print('ROCK B 1.0'); return {}", finally)
            write_file("rock_b-1.0-1.rockspec", [[
               package = "rock_b"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/rock_b_10.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     rock_b = "rock_b_10.lua"
                  }
               }
            ]], finally)

            write_file("rock_a.lua", "require('rock_b'); return {}", finally)
            write_file("rock_a-2.0-1.rockspec", [[
               package = "rock_a"
               version = "2.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/rock_a.lua"
               }
               dependencies = {
                  "rock_b < 1.0",
               }
               build = {
                  type = "builtin",
                  modules = {
                     rock_a = "rock_a.lua"
                  }
               }
            ]], finally)

            print(run.luarocks("make --server=" .. testing_paths.fixtures_dir .. "/a_repo --tree=" .. testing_paths.testing_tree .. " ./rock_b-0.1-1.rockspec"))
            print(run.luarocks("make --server=" .. testing_paths.fixtures_dir .. "/a_repo --tree=" .. testing_paths.testing_tree .. " ./rock_b-1.0-1.rockspec --keep"))
            print(run.luarocks("make --server=" .. testing_paths.fixtures_dir .. "/a_repo --tree=" .. testing_paths.testing_tree .. " ./rock_a-2.0-1.rockspec"))

            local output = run.lua([[-e "require 'luarocks.loader'; require('rock_a')"]])

            assert.matches("ROCK B 0.1", output, 1, true)
         end)
      end)
   end)
end)
