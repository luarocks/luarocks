local quick = {}

local dir_sep = package.config:sub(1, 1)

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local fs = require("luarocks.fs")
cfg.init()
fs.init()

local function parse_cmd(line)
   local cmd, arg = line:match("%s*([A-Z_]+):%s*(.*)%s*$")
   return cmd, arg
end

local function is_blank(line)
   return not not line:match("^%s*$")
end

local function is_hr(line)
   return not not line:match("^%-%-%-%-%-")
end

local function parse(filename)
   local fd = assert(io.open(filename, "r"))
   local input = assert(fd:read("*a"))
   fd:close()

   local tests = {}

   local cur_line = 0
   local cur_test
   local cur_op
   local cur_block
   local cur_block_name
   local stack = { "start" }

   local function start_test(arg)
      cur_test = {
         name = arg,
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

   local function bool_arg(cmd, cur_block, field, arg)
      if arg ~= "true" and arg ~= "false" then
         fail(cmd .. " argument must be 'true' or 'false'")
      end
      cur_block[field] = (arg == "true")
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
         if fn == "url" then
            value = expand_vars(fnarg)
            value = value:gsub("\\", "/")
         elseif fn == "path" then
            value = expand_vars(fnarg)
            value = value:gsub("[/\\]", dir_sep)
         else
            value = test_env.testing_paths[var]
                    or test_env.env_variables[var]
                    or test_env[var]
                    or ""
         end

         return value
      end))
   end

   for line in input:gmatch("[^\n]*") do
      cur_line = cur_line + 1

      local state = stack[#stack]
      if state == "start" then
         local cmd, arg = parse_cmd(line)
         if cmd == "TEST" then
            start_test(arg)
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
               file = dir.normalize(arg),
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "NOT_EXISTS" then
            cur_op = {
               op = "NOT_EXISTS",
               file = dir.normalize(arg),
            }
            table.insert(cur_test.ops, cur_op)
         elseif cmd == "MKDIR" then
            cur_op = {
               op = "MKDIR",
               file = dir.normalize(arg),
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
         elseif cmd == "STDERR" then
            if not cur_op or cur_op.op ~= "RUN" then
               fail("STDERR must be given in the context of a RUN")
            end
            if cur_op.stderr then
               fail("STDERR was already declared")
            end

            cur_op.stderr = {
               data = {}
            }
            cur_block = cur_op.stderr
            cur_block_name = "STDERR"
            table.insert(stack, "block start")
         elseif cmd == "STDOUT" then
            if not cur_op or cur_op.op ~= "RUN" then
               fail("STDOUT must be given in the context of a RUN")
            end
            if cur_op.stdout then
               fail("STDOUT was already declared")
            end

            cur_op.stdout = {
               data = {}
            }
            cur_block = cur_op.stdout
            cur_block_name = "STDOUT"
            table.insert(stack, "block start")
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
      t.name = t.name .. " #unit"

      local code = {}
      local function write(...)
         table.insert(code, table.concat({...}))
      end

      write([=[ local test_env = require("spec.util.test_env") ]=])
      write([=[ local lfs = require("lfs") ]=])
      write([=[ local fs = require("lfs") ]=])
      write([=[ local luarocks_cmd = test_env.execute_helper(test_env.Q(test_env.testing_paths.lua) .. " " .. test_env.testing_paths.src_dir .. "/bin/luarocks", false, test_env.env_variables):sub(1, -5) ]=])
      write([=[ local luarocks_admin_cmd = test_env.execute_helper(test_env.Q(test_env.testing_paths.lua) .. " " .. test_env.testing_paths.src_dir .. "/bin/luarocks-admin", false, test_env.env_variables):sub(1, -5) ]=])

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
      for _, op in ipairs(t.ops) do
         if op.op == "FILE" then
            write([=[ test_env.write_file("]=], op.name, [=[", [=====[ ]=])
            for _, line in ipairs(op.data) do
               write(line)
            end
            write([=[ ]=====], finally) ]=])
         elseif op.op == "EXISTS" then
            write(([=[ assert.truthy(lfs.attributes(%q)) ]=]):format(op.file))
         elseif op.op == "NOT_EXISTS" then
            write(([=[ assert.falsy(lfs.attributes(%q)) ]=]):format(op.file))
         elseif op.op == "MKDIR" then
            local bits = {}
            if op.file:sub(1, 1) == dir_sep then bits[1] = "" end
            for p in op.file:gmatch("[^" .. dir_sep .. "]+") do
               table.insert(bits, p)
               write(([=[ lfs.mkdir(%q) ]=]):format(table.concat(bits, dir_sep)))
            end
            write(([=[ assert.truthy((lfs.attributes(%q) or {}).mode == "directory", error_message(%d, "MKDIR failed: " .. %q)) ]=]):format(op.file, op.line, op.file))
         elseif op.op == "RUN" then
            local cmd_helper = cmd_helpers[op.program] or op.program
            local redirs = " 1>stdout.txt 2>stderr.txt "
            write(([=[ local ok, _, code = os.execute(%s .. " " .. %q .. %q) ]=]):format(cmd_helper, op.args, redirs))
            write([=[ if type(ok) == "number" then code = (ok >= 256 and ok / 256 or ok) end ]=])

            write([=[ local fd_stderr = assert(io.open("stderr.txt", "r")) ]=])
            write([=[ local stderr_data = fd_stderr:read("*a") ]=])
            write([=[ fd_stderr:close() ]=])

            write([=[ if stderr_data:match("please report") then ]=])
            write(([=[ assert(false, error_message(%d, "RUN crashed: ", stderr_data)) ]=]):format(op.line))
            write([=[ end ]=])

            if op.stdout then
               write([=[ local fd_stdout = assert(io.open("stdout.txt", "r")) ]=])
               write([=[ local stdout_data = fd_stdout:read("*a") ]=])
               write([=[ fd_stdout:close() ]=])

               write([=[ do ]=])
               write([=[ local block_at = 1 ]=])
               write([=[ local s, e, line ]=])
               for i, line in ipairs(op.stdout.data) do
                  write(([=[ line = %q ]=]):format(line))
                  write(([=[ s, e = string.find(stdout_data, line, block_at, true) ]=]))
                  write(([=[ assert(s, error_message(%d, "STDOUT did not match: " .. line, stdout_data)) ]=]):format(op.stdout.start + i))
                  write(([=[ block_at = e + 1 ]=]):format(i))
               end
               write([=[ end ]=])
            end

            if op.stderr then
               write([=[ do ]=])
               write([=[ local block_at = 1 ]=])
               write([=[ local s, e, line ]=])
               for i, line in ipairs(op.stderr.data) do
                  write(([=[ line = %q ]=]):format(line))
                  write(([=[ s, e = string.find(stderr_data, line, block_at, true) ]=]))
                  write(([=[ assert(s, error_message(%d, "STDERR did not match: " .. line, stderr_data)) ]=]):format(op.stderr.start + i))
                  write(([=[ block_at = e + 1 ]=]):format(i))
               end
               write([=[ end ]=])
            end

            if op.exit then
               write(([=[ assert.same(%d, code, error_message(%d, "EXIT did not match: " .. %d, stderr_data)) ]=]):format(op.exit, op.exit_line, op.exit))
            end
         end
      end
      write([=[ end) ]=])
      write([=[ end ]=])

      local program = table.concat(code, "\n")
      local chunk = assert(load(program, "@" .. filename .. ": test " .. tn, "t", env or _ENV))
      if env and setfenv then
         setfenv(chunk, env)
      end
      t.fn = chunk()
   end

   return tests
end

return quick
