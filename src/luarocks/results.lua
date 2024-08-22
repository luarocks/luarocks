local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local string = _tl_compat and _tl_compat.string or string; local results = {}


local vers = require("luarocks.core.vers")
local util = require("luarocks.util")


local result = require("luarocks.core.types.result")


local result_mt = {}

result_mt.__index = result.Result

function results.new(name, version, repo, arch, namespace)

   assert(not name:match("/"))


   if not namespace then
      name, namespace = util.split_namespace(name)
   end

   local self = {
      name = name,
      version = version,
      namespace = namespace,
      arch = arch,
      repo = repo,
   }

   return setmetatable(self, result_mt)
end








local function match_name(query, name)
   if query.substring then
      return name:find(query.name, 0, true) and true or false
   else
      return name == query.name
   end
end




function result.Result:satisfies(query)
   return match_name(query, self.name) and
   (query.arch[self.arch] or query.arch["any"]) and
   ((not query.namespace) or (query.namespace == self.namespace)) and
   (vers.match_constraints(vers.parse_version(self.version), query.constraints))
end

return results
