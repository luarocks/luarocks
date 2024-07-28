local results = {}

local vers = require("luarocks.core.vers")
local util = require("luarocks.util")

local result_mt = {}

result_mt.__index = result_mt

function result_mt.type()
   return "result"
end

function results.new(name, version, repo, arch, namespace)
   assert(type(name) == "string" and not name:match("/"))
   assert(type(version) == "string")
   assert(type(repo) == "string")
   assert(type(arch) == "string" or not arch)
   assert(type(namespace) == "string" or not namespace)

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

--- Test the name field of a query.
-- If query has a boolean field substring set to true,
-- then substring match is performed; otherwise, exact string
-- comparison is done.
-- @param query table: A query in dependency table format.
-- @param name string: A package name.
-- @return boolean: True if names match, false otherwise.
local function match_name(query, name)
   if query.substring then
      return name:find(query.name, 0, true) and true or false
   else
      return name == query.name
   end
end

--- Returns true if the result satisfies a given query.
-- @param query: a query.
-- @return boolean.
function result_mt:satisfies(query)
   assert(query:type() == "query")
   return match_name(query, self.name)
      and (query.arch[self.arch] or query.arch["any"])
      and ((not query.namespace) or (query.namespace == self.namespace))
      and vers.match_constraints(vers.parse_version(self.version), query.constraints)
end

return results
