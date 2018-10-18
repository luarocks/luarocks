local lint_api = {}

local cfg = require("luarocks.core.cfg")
local config_api = require("luarocks.api.config") 
local download = require("luarocks.download")
local fetch = require("luarocks.fetch")

function lint_api.lint(filename, tree)
   config_api.set_rock_tree(tree)

   if not filename:match(".rockspec$") then
      local err
      filename, err = download.download("rockspec", filename:lower())
      if not filename then
         return nil, err
      end
   end

   local rockspec, err = fetch.load_local_rockspec(filename)
   if not rockspec then
      return nil, "Failed loading rockspec: " .. err
   end

   local ok = true
   
   -- This should have been done in the type checker, 
   -- but it would break compatibility of other commands.
   -- Making 'lint' alone be stricter shouldn't be a problem,
   -- because extra-strict checks is what lint-type commands
   -- are all about.
   if not rockspec.description.license then
      cfg.log("error", "Rockspec has no license field.")
      ok = false
   end

   return ok or nil, filename .. " failed consistency checks."
end

return lint_api
