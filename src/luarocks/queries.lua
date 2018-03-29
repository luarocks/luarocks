
local queries = {}

local vers = require("luarocks.vers")
local cfg = require("luarocks.core.cfg")

local safer = require("safer")

--- Convert the arch field of a query table to table format.
-- @param input string, table or nil
local function arch_to_table(input)
   if type(input) == "table" then
      return input
   elseif type(input) == "string" then
      local arch = {}
      for a in input:gmatch("[%w_-]+") do
         arch[a] = true
      end
      return arch
   else
      local arch = {}
      arch["src"] = true
      arch["all"] = true
      arch["rockspec"] = true
      arch["installed"] = true
      arch[cfg.arch] = true
      return arch
   end
end

-- Split name and namespace of a package name.
-- @param name a name that may be in "namespace/name" format
-- @return string, string? - name and optionally a namespace
local function split_namespace(name)
   local p1, p2 = name:match("^([^/]+)/([^/]+)$") 
   if p1 then
      return p2, p1
   end
   return name
end

--- Prepare a query in dependency table format.
-- @param name string: The query name.
-- @param version string or nil: 
-- @param substring boolean: match substrings of the name
-- (default is false, match full name)
-- @param arch string: a string with pipe-separated accepted arch values
-- @param operator string: operator for version matching (default is "==")
-- @return table: A query in table format
function queries.new(name, version, substring, arch, operator)
   assert(type(name) == "string")
   assert(type(version) == "string" or not version)
   assert(type(substring) == "boolean" or not substring)
   assert(type(arch) == "string" or not arch)
   assert(type(operator) == "string" or not operator)
   
   operator = operator or "=="

   local namespace
   name, namespace = split_namespace(name)
   
   local query = {
      name = name,
      namespace = namespace,
      constraints = {},
      substring = substring,
      arch = arch_to_table(arch),
   }
   if version then
      table.insert(query.constraints, { op = operator, version = vers.parse_version(version)})
   end
   return safer.readonly(query)
end

-- Query for all packages
-- @param arch string (optional)
function queries.all(arch)
   assert(type(arch) == "string" or not arch)

   return queries.new("", nil, true, arch)
end

function queries.from_constraints(name, constraints)
   local namespace
   name, namespace = split_namespace(name)
   local query = {
      name = name,
      namespace = namespace,
      constraints = constraints,
      substring = false,
      arch = arch_to_table(nil),
   }
   return safer.readonly(query)
end

return queries
