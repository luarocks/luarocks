
local queries = {}

local vers = require("luarocks.core.vers")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")

local query_mt = {}

query_mt.__index = query_mt

function query_mt.type()
   return "query"
end

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

--- Prepare a query in dependency table format.
-- @param ns_name string: the package name, may contain a namespace.
-- @param version string?: the package version.
-- @param substring boolean?: match substrings of the name
-- (default is false, match full name)
-- @param arch string?: a string with pipe-separated accepted arch values
-- @param operator string?: operator for version matching (default is "==")
-- @return table: A query in table format
function queries.new(ns_name, version, substring, arch, operator)
   assert(type(ns_name) == "string")
   assert(type(version) == "string" or not version)
   assert(type(substring) == "boolean" or not substring)
   assert(type(arch) == "string" or not arch)
   assert(type(operator) == "string" or not operator)
   
   operator = operator or "=="

   local name, namespace = util.split_namespace(ns_name)
   
   local self = {
      name = name,
      namespace = namespace,
      constraints = {},
      substring = substring,
      arch = arch_to_table(arch),
   }
   if version then
      table.insert(self.constraints, { op = operator, version = vers.parse_version(version)})
   end
   return setmetatable(self, query_mt)
end

-- Query for all packages
-- @param arch string (optional)
function queries.all(arch)
   assert(type(arch) == "string" or not arch)

   return queries.new("", nil, true, arch)
end

do
   local parse_constraints
   do
      local parse_constraint
      do
         local operators = {
            ["=="] = "==",
            ["~="] = "~=",
            [">"] = ">",
            ["<"] = "<",
            [">="] = ">=",
            ["<="] = "<=",
            ["~>"] = "~>",
            -- plus some convenience translations
            [""] = "==",
            ["="] = "==",
            ["!="] = "~="
         }
         
         --- Consumes a constraint from a string, converting it to table format.
         -- For example, a string ">= 1.0, > 2.0" is converted to a table in the
         -- format {op = ">=", version={1,0}} and the rest, "> 2.0", is returned
         -- back to the caller.
         -- @param input string: A list of constraints in string format.
         -- @return (table, string) or nil: A table representing the same
         -- constraints and the string with the unused input, or nil if the
         -- input string is invalid.
         parse_constraint = function(input)
            assert(type(input) == "string")
         
            local no_upgrade, op, version, rest = input:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
            local _op = operators[op]
            version = vers.parse_version(version)
            if not _op then
               return nil, "Encountered bad constraint operator: '"..tostring(op).."' in '"..input.."'"
            end
            if not version then 
               return nil, "Could not parse version from constraint: '"..input.."'"
            end
            return { op = _op, version = version, no_upgrade = no_upgrade=="@" and true or nil }, rest
         end
      end
      
      --- Convert a list of constraints from string to table format.
      -- For example, a string ">= 1.0, < 2.0" is converted to a table in the format
      -- {{op = ">=", version={1,0}}, {op = "<", version={2,0}}}.
      -- Version tables use a metatable allowing later comparison through
      -- relational operators.
      -- @param input string: A list of constraints in string format.
      -- @return table or nil: A table representing the same constraints,
      -- or nil if the input string is invalid.
      parse_constraints = function(input)
         assert(type(input) == "string")
      
         local constraints, oinput, constraint = {}, input
         while #input > 0 do
            constraint, input = parse_constraint(input)
            if constraint then
               table.insert(constraints, constraint)
            else
               return nil, "Failed to parse constraint '"..tostring(oinput).."' with error: ".. input
            end
         end
         return constraints
      end
   end
   
   --- Prepare a query in dependency table format.
   -- @param depstr string: A dependency in string format
   -- as entered in rockspec files.
   -- @return table: A query in table format, or nil and an error message in case of errors.
   function queries.from_dep_string(depstr)
      assert(type(depstr) == "string")
   
      local ns_name, rest = depstr:match("^%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)")
      if not ns_name then
         return nil, "failed to extract dependency name from '"..depstr.."'"
      end
   
      local constraints, err = parse_constraints(rest)
      if not constraints then
         return nil, err
      end
   
      local name, namespace = util.split_namespace(ns_name)
   
      local self = {
         name = name,
         namespace = namespace,
         constraints = constraints,
         substring = false,
         arch = arch_to_table(nil),
      }
      return setmetatable(self, query_mt)
   end
end

--- Build a string representation of a query package name.
-- Includes namespace, name and version, but not arch or constraints.
-- @param query table: a query table
-- @return string: a result such as `my_user/my_rock 1.0` or `my_rock`.
function queries:__tostring()
   local out = {}
   if self.namespace then
      table.insert(out, self.namespace)
      table.insert(out, "/")
   end
   table.insert(out, self.name)

   if #self.constraints > 0 then
      local pretty = {}
      for _, c in ipairs(self.constraints) do
         if c.op == "==" then
            table.insert(pretty, tostring(c.version))
         else
            table.insert(pretty, c.op .. " " .. tostring(c.version))
         end
      end
      table.insert(out, " ")
      table.insert(out, table.concat(pretty, ", "))
   end

   return table.concat(out)
end

return queries
