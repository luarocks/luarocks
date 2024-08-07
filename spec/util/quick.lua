local quick = {}

local dir_sep = package.config:sub(1, 1)

local cfg, dir, fs, versions
local initialized = false

local function initialize()
   if initialized then
      return
   end
   initialized = true

   cfg = require("luarocks.core.cfg")
   dir = require("luarocks.dir")
   fs = require("luarocks.fs")
   versions = require("spec.util.versions")
   cfg.init()
   fs.init()
end

local function native_slash(pathname)
   return (pathname:gsub("[/\\]", dir_sep))
end

local function parse_cmd(line)
   local cmd, arg = line:match("^%s*([A-Z_]+):%s*(.*)%s*$")
   return cmd, arg
end

local function is_blank(line)
   return not not line:match("^%s*$")
end

local function is_hr(line)
   return not not line:match("^%-%-%-%-%-")
end

local function parse(filename)
   local fd = assert(io.open(filename, "rb"))
   local input = assert(fd:read("*a"))
   fd:close()

   initialize()

   local tests = {}

   local cur_line = 0
   local cur_suite = ""
   local cur_test
   local cur_op
   local cur_block
   local cur_block_name
   local stack = { "start" }

   local function start_test(arg)
      cur_test = {
         name = cur_suite .. arg,
         ops = {},
      }
      cur_op = nil
      table.insert(tests, cur_test)
      table.insert(stack, "test")
   end

   local function fail(msg)
      io.stderr:write("Error reading " .. filename .. ":" .. cur_line .. ": " .. msg .. "\n")
      os.exit(1)
   end

   local function bool_arg(cmd, cur, field, arg)
      if arg ~= "true" and arg ~= "false" then
         fail(cmd .. " argument must be 'true' or 'false'")
      end
      cur[field] = (arg == "true")
   end

   local function block_start_arg(cmd, cur, field)
      if not cur or cur.op ~= "RUN" then
         fail(cmd .. " must be given in the context of a RUN")
      end
      if cur[field] then
         fail(cmd .. " was already declared")
      end

      cur[field] = {
         data = {}
      }
      cur_block = cur[field]
      cur_block_name = cmd
      table.insert(stack, "block start")
   end

   local test_env = require("spec.util.test_env")
   local function expand_vars(line)
      if not line then
         return nil
      end
      return (line:gsub("%%%b{}", function(var)
         var = var:sub(3, -2)
         local fn, fnarg = var:match("^%s*([a-z_]+)%s*%(%s*([^)]+)%s*%)%s*$")

         local value
         if var == "tmpdir" then
            value = "%{tmpdir}"
         elseif var == "url(%{tmpdir})" then
            value = "%{url(%{tmpdir})}"
         elseif fn == "url" then
            value = expand_vars(fnarg)
            value = value:gsub("\\", "/")
         elseif fn == "path" then
            value = expand_vars(fnarg)
            value = value:gsub("[/\\]", dir_sep)
         elseif fn == "version" then
            value = versions[fnarg:lower()] or ""
         elseif fn == "version_" then
            value = (versions[fnarg:lower()] or ""):gsub("[%.%-]", "_")
         else
            value = test_env.testing_paths[var]
                    or test_env.env_variables[var]
                    or test_env[var]
                    or ""
         end

         return value
      end))
   end

   if input:sub(#input, #input) ~= "\n" then
      input = input .. "\n"
   end

   for line in input:gmatch("([^\r\n]*)\r?\n?") do
      cur_line = cur_line + 1

      local state = stack[#stack]
      if state == "start" then
         local cmd, arg = parse_cmd(line)
         if cmd == "TEST" then
            start_test(arg)
         elseif cmd == "SUITE" then
            cur_suite = arg .. ": "
         elseif cmd then
            fail("expected TEST, got " .. cmd)
         elseif is_blank(line) then
            -- skip blank lines and arbitrary text,
            -- which is interpreted as a comment
         end
      elseif state == "test" then
         local cmd, arg = parse_cmd(line)
         arg = expand_vars(arg)
         if cmd == "FILE" then
            cur_op = {
               op = "FILE",
               name = arg,
               data = {},
            }
            table.insert(cur_test.ops, cur_op)
            cur_block = cur_op
            cur_block_name = "FILE"
            table.insert(stack, "block start")
         elseif cmd == "FILE_CONTENTS" then
            cur_op = {
               op = "FILE_CONTENTS",
               name = arg,
               data = {},
            }
            table.insert(cur_test.ops, cur_op)
            cur_block = cur_op
            cur_block_name = "FILE_CONTENTS"
            table.insert(stack, "block start")
         elseif cmd == "RUN" then
            local program, args = arg:match("([^ ]+)%s*(.*)$")
            if not program then
               fail("expected a program argument in RUN")
            end

            cur_op = {
               op = "RUN",
               exit = 0,
               exit_line = cur_line,
               line = cur_line,
               program = program,
               args = args,
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "EXISTS" then
            cur_op = {
               op = "EXISTS",
               name = dir.normalize(arg),
               line = cur_line,
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "NOT_EXISTS" then
            cur_op = {
               op = "NOT_EXISTS",
               name = dir.normalize(arg),
               line = cur_line,
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "MKDIR" then
            cur_op = {
               op = "MKDIR",
               name = dir.normalize(arg),
               line = cur_line,
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "RMDIR" then
            cur_op = {
               op = "RMDIR",
               name = dir.normalize(arg),
               line = cur_line,
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "RM" then
            cur_op = {
               op = "RM",
               name = dir.normalize(arg),
               line = cur_line,
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "EXIT" then
            if not cur_op or cur_op.op ~= "RUN" then
               fail("EXIT must be given in the context of a RUN")
            end

            local code = tonumber(arg)
            if not code and not (code >= 0 and code <= 128) then
               fail("EXIT code must be a number in the range 0-128, got " .. arg)
            end

            cur_op.exit = code
            cur_op.exit_line = cur_line
         elseif cmd == "VERBOSE" then
            if not cur_op or cur_op.op ~= "RUN" then
               fail("VERBOSE must be given in the context of a RUN")
            end

            bool_arg("VERBOSE", cur_op, "verbose", arg)
         elseif cmd == "STDERR" then
            block_start_arg("STDERR", cur_op, "stderr")
         elseif cmd == "NOT_STDERR" then
            block_start_arg("NOT_STDERR", cur_op, "not_stderr")
         elseif cmd == "STDOUT" then
            block_start_arg("STDOUT", cur_op, "stdout")
         elseif cmd == "NOT_STDOUT" then
            block_start_arg("NOT_STDOUT", cur_op, "not_stdout")
         elseif cmd == "PENDING" then
            bool_arg("PENDING", cur_test, "pending", arg)
         elseif cmd == "TEST" then
            table.remove(stack)
            start_test(arg)
         elseif cmd then
            fail("expected a command, got " .. cmd)
         else
            -- skip blank lines and arbitrary text,
            -- which is interpreted as a comment
         end
      elseif state == "block start" then
         local cmd, arg = parse_cmd(line)
         if is_blank(line) then
            -- skip
         elseif is_hr(line) then
            stack[#stack] = "block data"
            cur_block.start = cur_line
         elseif cmd == "PLAIN" then
            bool_arg("PLAIN", cur_block, "plain", arg)
         else
            fail("expected '-----' to start " .. cur_block_name .. " block")
         end
      elseif state == "block data" then
         if is_hr(line) then
            cur_block = nil
            table.remove(stack)
         else
            if not cur_block.plain then
               line = expand_vars(line)
            end
            table.insert(cur_block.data, line)
         end
      end
   end

   return tests
end

local function check_output(write, block, block_name, data_var)
   if block then
      local is_positive = not block_name:match("NOT")
      local err_msg = is_positive and "did not match" or "did match unwanted output"

      write([=[ do ]=])
      write([=[ local block_at = 1 ]=])
      write([=[ local s, e, line, ok ]=])
      for i, line in ipairs(block.data) do
         write(([=[ line = %q ]=]):format(line))
         write(([=[ s, e = string.find(%s, line, block_at, true) ]=]):format(data_var))
         write(is_positive and ([=[ ok = s; if e then block_at = e + 1 end ]=]):format(i)
                           or  ([=[ ok = not s ]=]))
         write(([=[ assert(ok, error_message(%d, "%s %s: " .. line, %s)) ]=]):format(block.start + i, block_name, err_msg, data_var))
      end
      write([=[ end ]=])
   end
end

function quick.compile(filename, env)
   local tests = parse(filename)

--   local dev_null = (package.config:sub(1, 1) == "/")
--                    and "/dev/null"
--                    or "NUL"

   local cmd_helpers = {
      ["luarocks"] = "luarocks_cmd",
      ["luarocks-admin"] = "luarocks_admin_cmd",
   }

   for tn, t in ipairs(tests) do
      local code = {}
      local function write(...)
         table.insert(code, table.concat({...}))
      end

      write(([=[  ]=]))
      write(([=[ -- **************************************** ]=]))
      write(([=[ -- %s ]=]):format(t.name))
      write(([=[ -- **************************************** ]=]))
      write(([=[  ]=]))

      write([=[ local test_env = require("spec.util.test_env") ]=])
      write([=[ local lfs = require("lfs") ]=])
      write([=[ local fs = require("lfs") ]=])
      write([=[ local dir_sep = package.config:sub(1, 1) ]=])
      write([=[ local coverage = " -e \"require('luacov.runner')([[" .. test_env.testing_paths.testrun_dir .. dir_sep .. "luacov.config]])\" " ]=])
      write([=[ local luarocks_cmd = test_env.execute_helper(test_env.Q(test_env.testing_paths.lua) .. coverage .. " " .. test_env.testing_paths.src_dir .. "/bin/luarocks", false, test_env.env_variables):sub(1, -5) ]=])
      write([=[ local luarocks_admin_cmd = test_env.execute_helper(test_env.Q(test_env.testing_paths.lua) .. coverage .. " " .. test_env.testing_paths.src_dir .. "/bin/luarocks-admin", false, test_env.env_variables):sub(1, -5) ]=])

      write([=[ local function make_dir(dirname) ]=])
      write([=[    local bits = {} ]=])
      write([=[    if dirname:sub(1, 1) == dir_sep then bits[1] = "" end ]=])
      write([=[    local ok, err ]=])
      write([=[    for p in dirname:gmatch("[^" .. dir_sep .. "]+") do ]=])
      write([=[       table.insert(bits, p) ]=])
      write([=[       ok, err = lfs.mkdir(table.concat(bits, dir_sep)) ]=])
      write([=[    end ]=])
      write([=[    local exists = (lfs.attributes(dirname) or {}).mode == "directory" ]=])
      write([=[    return exists, (not exists) and err ]=])
      write([=[ end ]=])

      write(([=[ local function error_message(line, msg, input) ]=]))
      write(([=[    local out = {"\n\n", %q, ":", line, ": ", msg} ]=]):format(filename))
      write(([=[    if input then ]=]))
      write(([=[       if input:match("\n") then ]=]))
      write(([=[          table.insert(out, "\n") ]=]))
      write(([=[          table.insert(out, ("-"):rep(40)) ]=]))
      write(([=[          table.insert(out, "\n") ]=]))
      write(([=[          table.insert(out, input) ]=]))
      write(([=[          table.insert(out, ("-"):rep(40)) ]=]))
      write(([=[          table.insert(out, "\n") ]=]))
      write(([=[       else ]=]))
      write(([=[          table.insert(out, ": ") ]=]))
      write(([=[          table.insert(out, input) ]=]))
      write(([=[       end ]=]))
      write(([=[    end ]=]))
      write(([=[    return table.concat(out) ]=]))
      write(([=[ end ]=]))

      write([=[ return function() ]=])
      write([=[ test_env.run_in_tmp(function(tmpdir) ]=])
      write([=[    local function handle_tmpdir(s) ]=])
      write([=[       return (s:gsub("%%{url%(%%{tmpdir}%)}", (tmpdir:gsub("\\", "/")))         ]=])
      write([=[                :gsub("%%{tmpdir}",        (tmpdir:gsub("[\\/]", dir_sep)))) ]=])
      write([=[    end ]=])
      write([=[ local ok, err ]=])
      for _, op in ipairs(t.ops) do
         if op.name then
            op.name = native_slash(op.name)
            write(([=[ local name = handle_tmpdir(%q) ]=]):format(op.name))
         end
         if op.op == "FILE" then
            if op.name:match("[\\/]") then
               write(([=[ make_dir(handle_tmpdir(%q)) ]=]):format(dir.dir_name(op.name)))
            end
            write([=[ test_env.write_file(name, handle_tmpdir([=====[ ]=])
            for _, line in ipairs(op.data) do
               write(line)
            end
            write([=[ ]=====]), finally) ]=])
         elseif op.op == "EXISTS" then
            write(([=[ ok, err = lfs.attributes(name) ]=]))
            write(([=[ assert.truthy(ok, error_message(%d, "EXISTS failed: " .. name .. " - " .. (err or "") )) ]=]):format(op.line))
         elseif op.op == "NOT_EXISTS" then
            write(([=[ assert.falsy(lfs.attributes(name), error_message(%d, "NOT_EXISTS failed: " .. name .. " exists" )) ]=]):format(op.line))
         elseif op.op == "MKDIR" then
            write(([=[ ok, err = make_dir(name) ]=]))
            write(([=[ assert.truthy((lfs.attributes(name) or {}).mode == "directory", error_message(%d, "MKDIR failed: " .. name .. " - " .. (err or "") )) ]=]):format(op.line))
         elseif op.op == "RMDIR" then
            write(([=[ ok, err = test_env.remove_dir(name) ]=]))
            write(([=[ assert.falsy((lfs.attributes(name) or {}).mode == "directory", error_message(%d, "MKDIR failed: " .. name .. " - " .. (err or "") )) ]=]):format(op.line))
         elseif op.op == "RM" then
            write(([=[ ok, err = os.remove(name) ]=]))
            write(([=[ assert.falsy((lfs.attributes(name) or {}).mode == "file", error_message(%d, "RM failed: " .. name .. " - " .. (err or "") )) ]=]):format(op.line))
         elseif op.op == "FILE_CONTENTS" then
            write(([=[ do ]=]))
            write(([=[ local fd_file = assert(io.open(name, "rb")) ]=]))
            write(([=[ local file_data = fd_file:read("*a") ]=]))
            write(([=[ fd_file:close() ]=]))
            write([=[ local block_at = 1 ]=])
            write([=[ local s, e, line ]=])
            for i, line in ipairs(op.data) do
               write(([=[ line = %q ]=]):format(line))
               write(([=[ s, e = string.find(file_data, line, 1, true) ]=]))
               write(([=[ assert(s, error_message(%d, "FILE_CONTENTS " .. name .. " did not match: " .. line, file_data)) ]=]):format(op.start + i))
               write(([=[ block_at = e + 1 ]=]):format(i))
            end
            write([=[ end ]=])
         elseif op.op == "RUN" then
            local cmd_helper = cmd_helpers[op.program] or ("%q"):format(op.program)
            local redirs = " 1>stdout.txt 2>stderr.txt "
            write(([=[ local ok, _, code = os.execute(%s .. " " .. %q .. %q) ]=]):format(cmd_helper, op.args, redirs))
            write([=[ if type(ok) == "number" then code = (ok >= 256 and ok / 256 or ok) end ]=])

            write([=[ local fd_stderr = assert(io.open("stderr.txt", "rb")) ]=])
            write([=[ local stderr_data = fd_stderr:read("*a") ]=])
            write([=[ fd_stderr:close() ]=])

            write([=[ if stderr_data:match("please report") then ]=])
            write(([=[ assert(false, error_message(%d, "RUN crashed: ", stderr_data)) ]=]):format(op.line))
            write([=[ end ]=])

            if op.stdout or op.not_stdout or op.verbose then
               write([=[ local fd_stdout = assert(io.open("stdout.txt", "rb")) ]=])
               write([=[ local stdout_data = fd_stdout:read("*a") ]=])
               write([=[ fd_stdout:close() ]=])
            end

            if op.verbose then
               write([=[ print() ]=])
               write([=[ print("STDOUT: --" .. ("-"):rep(70)) ]=])
               write([=[ print(stdout_data) ]=])
               write([=[ print("STDERR: --" .. ("-"):rep(70)) ]=])
               write([=[ print(stderr_data) ]=])
               write([=[ print(("-"):rep(80)) ]=])
               write([=[ print() ]=])
            end

            check_output(write, op.stdout, "STDOUT", "stdout_data")
            check_output(write, op.stderr, "STDERR", "stderr_data")

            check_output(write, op.not_stdout, "NOT_STDOUT", "stdout_data")
            check_output(write, op.not_stderr, "NOT_STDERR", "stderr_data")

            if op.exit then
               write(([=[ assert.same(%d, code, error_message(%d, "EXIT did not match: " .. %d, stderr_data)) ]=]):format(op.exit, op.exit_line, op.exit))
            end
         end
      end
      write([=[ end, finally) ]=])
      write([=[ end ]=])

      local program = table.concat(code, "\n")
      local chunk = assert(load(program, "@" .. filename .. ":[TEST " .. tn .. "]", "t", env or _ENV))
      if env and setfenv then
         setfenv(chunk, env)
      end
      t.fn = chunk()
   end

   return tests
end

return quick
