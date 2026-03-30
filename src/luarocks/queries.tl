
local record queries
end

local vers = require("luarocks.core.vers")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")

local query = require("luarocks.core.types.query")
local type Query = query.Query

local type Constraint = require("luarocks.core.types.version").Constraint

local query_mt: metatable<Query> = {}

query_mt.__index = query.Query

-- Fallback default value for the `arch` field, if not explicitly set.
query.Query.arch = {
   src = true,
   all = true,
   rockspec = true,
   installed = true,
   -- [cfg.arch] = true, -- this is set later
}

-- Fallback default value for the `substring` field, if not explicitly set.
query.Query.substring = false

--- Convert the arch field of a query table to table format.
-- @param input string, table or nil
local function arch_to_table(input: string | {string: boolean}): {string: boolean}
   if input is {string: boolean} then
      return input
   elseif input is string then
      local arch = {}
      for a in input:gmatch("[%w_-]+") do
         arch[a] = true
      end
      return arch
   end
end

--- Prepare a query in dependency table format.
-- @param name string: the package name.
-- @param namespace string?: the package namespace.
-- @param version string?: the package version.
-- @param substring boolean?: match substrings of the name
-- (default is false, match full name)
-- @param arch string?: a string with pipe-separated accepted arch values
-- @param operator string?: operator for version matching (default is "==")
-- @return table: A query in table format
function queries.new(name: string, namespace?: string, version?: string, substring?: boolean, arch?: string, operator?: string): Query

   operator = operator or "=="

   local self: Query = {
      name = name,
      namespace = namespace,
      constraints = {},
      substring = substring,
      arch = arch_to_table(arch),
   }
   if version then
      table.insert(self.constraints, { op = operator, version = vers.parse_version(version)})
   end

   query.Query.arch[cfg.arch] = true
   return setmetatable(self, query_mt)
end

-- Query for all packages
-- @param arch string (optional)
function queries.all(arch?: string): Query

   return queries.new("", nil, nil, true, arch)
end

do
   local parse_constraints: function(string): {Constraint}, string
   do
      local parse_constraint: function(string): Constraint, string
      do
         local operators: {string: string} = {
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
         parse_constraint = function(input: string): {string: any}, string

            local no_upgrade, op, versionstr, rest = input:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
            local _op = operators[op]
            local version = vers.parse_version(versionstr)
            if not _op then
               return nil, "Encountered bad constraint operator: '"..tostring(op).."' in '"..input.."'"
            end
            if not version then
               return nil, "Could not parse version from constraint: '"..input.."'"
            end
            return { op = _op, version = version, no_upgrade = no_upgrade=="@" and true or nil }, rest --? false instead of nil
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
      parse_constraints = function(input: string): {Constraint}, string

         local constraints, oinput = {}, input
         local constraint: Constraint
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
   function queries.from_dep_string(depstr: string): Query, string

      local ns_name, rest = depstr:match("^%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)")
      if not ns_name then
         return nil, "failed to extract dependency name from '"..depstr.."'"
      end

      ns_name = ns_name:lower()

      local constraints, err = parse_constraints(rest)
      if not constraints then
         return nil, err
      end

      local name, namespace = util.split_namespace(ns_name)

      local self = {
         name = name,
         namespace = namespace,
         constraints = constraints,
      }

      query.Query.arch[cfg.arch] = true
      return setmetatable(self, query_mt)
   end
end

function queries.from_persisted_table(tbl: Query): Query
   query.Query.arch[cfg.arch] = true
   return setmetatable(tbl, query_mt)
end

--- Build a string representation of a query package name.
-- Includes namespace, name and version, but not arch or constraints.
-- @param query table: a query table
-- @return string: a result such as `my_user/my_rock 1.0` or `my_rock`.
function query_mt.__tostring(self: Query): string
   local out = {}
   if self.namespace then
      table.insert(out, self.namespace)
      table.insert(out, "/")
   end
   table.insert(out, self.name)

   if #self.constraints > 0 then
      local pretty = {}
      for _, c in ipairs(self.constraints) do
         local v = tostring(c.version)
         if c.op == "==" then
            table.insert(pretty, v)
         else
            table.insert(pretty, c.op .. " " .. v)
         end
      end
      table.insert(out, " ")
      table.insert(out, table.concat(pretty, ", "))
   end

   return table.concat(out)
end

return queries
