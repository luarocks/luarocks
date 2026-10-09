local test_env = require("spec.util.test_env")
local lfs = require("lfs")
local run = test_env.run
local testing_paths = test_env.testing_paths

local extra_rocks = {
   "/say-1.3-1.rockspec",
}

describe("luarocks download #integration", function()

   before_each(function()
      test_env.setup_specs(extra_rocks)
   end)

   it("with no flags/arguments", function()
      assert.is_false(run.luarocks_bool("download"))
   end)

   it("invalid", function()
      assert.is_false(run.luarocks_bool("download invalid"))
   end)

   it("all with delete downloaded files", function() --TODO maybe download --all more rocks
      assert.is_true(run.luarocks_bool("download --all say"))
      assert.is.truthy(lfs.attributes("say-1.3-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "say--")
   end)

   it("rockspec version", function()
      assert.is_true(run.luarocks_bool("download --rockspec say 1.3-1"))
      assert.is.truthy(lfs.attributes("say-1.3-1.rockspec"))
      test_env.remove_files(lfs.currentdir(), "say--")
   end)

   describe("#namespaces", function()
      it("retrieves namespaced rockspec", function()
         finally(function()
            os.remove("a_rock-2.0-1.rockspec")
         end)
         assert(run.luarocks_bool("download a_user/a_rock --rockspec --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(lfs.attributes("a_rock-2.0-1.rockspec"))
      end)

      it("retrieves namespaced rock", function()
         finally(function()
            os.remove("a_rock-2.0-1.src.rock")
         end)
         assert(run.luarocks_bool("download a_user/a_rock --server=" .. testing_paths.fixtures_dir .. "/a_repo" ))
         assert(lfs.attributes("a_rock-2.0-1.src.rock"))
      end)
   end)


end)

describe("HTTPS certificate validation #integration #unix", function()
   local fs, cfg
   local tmpdir, port, server_pid
   local saved_check, saved_curlflag, saved_wgetflag

   local function has_openssl()
      local ok = os.execute("openssl version >/dev/null 2>&1")
      return ok == true or ok == 0
   end

   local function start_server(dir)
      local certfile = dir .. "/cert.pem"
      local keyfile = dir .. "/key.pem"
      os.execute("openssl req -x509 -newkey rsa:2048 -keyout " .. fs.Q(keyfile) ..
         " -out " .. fs.Q(certfile) .. " -days 1 -nodes -subj /CN=localhost >/dev/null 2>&1")
      port = 40000 + (os.time() % 20000)
      local cmd = "(cd " .. fs.Q(testing_paths.fixtures_dir) ..
         " && exec openssl s_server -accept " .. port ..
         " -cert " .. fs.Q(certfile) .. " -key " .. fs.Q(keyfile) ..
         " -WWW -quiet) >/dev/null 2>&1 & echo $!"
      local h = io.popen(cmd)
      server_pid = h:read("*l")
      h:close()
      os.execute("sleep 1")
   end

   local function stop_server()
      if server_pid then
         os.execute("kill " .. server_pid .. " 2>/dev/null")
         server_pid = nil
      end
   end

   before_each(function()
      test_env.setup_specs()
      fs = require("luarocks.fs")
      cfg = require("luarocks.core.cfg")
      cfg.init()
      fs.init()
      saved_check = cfg.check_certificates
      saved_curlflag = cfg.variables.CURLNOCERTFLAG
      saved_wgetflag = cfg.variables.WGETNOCERTFLAG
      tmpdir = test_env.get_tmp_path()
      lfs.mkdir(tmpdir)
   end)

   after_each(function()
      stop_server()
      cfg.check_certificates = saved_check
      cfg.variables.CURLNOCERTFLAG = saved_curlflag
      cfg.variables.WGETNOCERTFLAG = saved_wgetflag
      fs.delete(tmpdir)
   end)

   it("rejects a self-signed certificate by default", function()
      if not has_openssl() then
         return pending("openssl not available", function() end)
      end
      start_server(tmpdir)
      cfg.check_certificates = true
      local name = fs.download("https://127.0.0.1:" .. port .. "/an_upstream_tarball-0.1.tar.gz", tmpdir .. "/out")
      assert.is_nil(name)
   end)

   it("downloads when check_certificates is disabled", function()
      if not has_openssl() then
         return pending("openssl not available", function() end)
      end
      start_server(tmpdir)
      cfg.check_certificates = false
      cfg.variables.CURLNOCERTFLAG = "-k"
      cfg.variables.WGETNOCERTFLAG = "--no-check-certificate"
      local name = fs.download("https://127.0.0.1:" .. port .. "/an_upstream_tarball-0.1.tar.gz", tmpdir .. "/out")
      assert.is_truthy(name)
   end)
end)
