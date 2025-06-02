local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local load = _tl_compat and _tl_compat.load or load; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string
local persist = {}


local json = require("luarocks.vendor.dkjson")









function persist.run_file(filename, env)
   local fd, open_err = io.open(filename)
   if not fd then
      return nil, open_err, "open"
   end
   local str, read_err = fd:read("*a")
   fd:close()
   if not str then
      return nil, read_err, "open"
   end
   str = str:gsub("^#![^\n]*\n", "")
   local chunk, ran, err
   chunk, err = load(str, filename, "t", env)
   if chunk then
      ran, err = pcall(chunk)
   end
   if not chunk then
      return nil, "Error loading file: " .. tostring(err), "load"
   end
   if not ran then
      return nil, "Error running file: " .. tostring(err), "run"
   end
   return true, err
end











function persist.load_into_table(filename, tbl)

   local result = tbl or {}
   local globals = {}
   local globals_mt = {
      __index = function(_, k)
         globals[k] = true
      end,
   }
   local save_mt = getmetatable(result)
   setmetatable(result, globals_mt)

   local ok, err, errcode = persist.run_file(filename, result)

   setmetatable(result, save_mt)

   if not ok then
      return nil, tostring(err), errcode
   end
   return result, globals
end











function persist.load_json_into_table(filename)
   local fd, open_err = io.open(filename)
   if not fd then
      return nil, open_err, "open"
   end
   local str, read_err = fd:read("*a")
   fd:close()
   if not str then
      return nil, read_err, "open"
   end
   local manifest, _, err = json.decode(str)
   if not manifest then
      return nil, "Failed decode manifest: " .. err, "load"
   end

   return manifest, {}
end

return persist
