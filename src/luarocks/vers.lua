
--- Dependency format handling functions.
-- Dependencies are represented in LuaRocks through strings with
-- a package name followed by a comma-separated list of constraints.
-- Each constraint consists of an operator and a version number.
-- In this string format, version numbers are represented as
-- naturally as possible, like they are used by upstream projects
-- (e.g. "2.0beta3"). Internally, LuaRocks converts them to a purely
-- numeric representation, allowing comparison following some
-- "common sense" heuristics. The precise specification of the
-- comparison criteria is the source code of this module.
local vers = {}
setmetatable(vers, { __index = require("luarocks.core.vers") })

--- Check if rockspec format version satisfies version requirement.
-- @param rockspec table: The rockspec table.
-- @param version string: required version.
-- @return boolean: true if rockspec format matches version or is newer, false otherwise.
function vers.format_is_at_least(rockspec, version)
   local rockspec_format = rockspec.rockspec_format or "1.0"
   return vers.parse_version(rockspec_format) >= vers.parse_version(version)
end

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
local function parse_constraint(input)
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

--- Convert a list of constraints from string to table format.
-- For example, a string ">= 1.0, < 2.0" is converted to a table in the format
-- {{op = ">=", version={1,0}}, {op = "<", version={2,0}}}.
-- Version tables use a metatable allowing later comparison through
-- relational operators.
-- @param input string: A list of constraints in string format.
-- @return table or nil: A table representing the same constraints,
-- or nil if the input string is invalid.
function vers.parse_constraints(input)
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

--- Convert a dependency from string to table format.
-- For example, a string "foo >= 1.0, < 2.0"
-- is converted to a table in the format
-- {name = "foo", constraints = {{op = ">=", version={1,0}},
-- {op = "<", version={2,0}}}}. Version tables use a metatable
-- allowing later comparison through relational operators.
-- @param dep string: A dependency in string format
-- as entered in rockspec files.
-- @return table or nil: A table representing the same dependency relation,
-- or nil if the input string is invalid.
function vers.parse_dep(dep)
   assert(type(dep) == "string")

   local name, rest = dep:match("^%s*([a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*(.*)")
   if not name then return nil, "failed to extract dependency name from '"..tostring(dep).."'" end
   local constraints, err = vers.parse_constraints(rest)
   if not constraints then return nil, err end
   return { name = name, constraints = constraints }
end

--- Convert a version table to a string.
-- @param v table: The version table
-- @param internal boolean or nil: Whether to display versions in their
-- internal representation format or how they were specified.
-- @return string: The dependency information pretty-printed as a string.
function vers.show_version(v, internal)
   assert(type(v) == "table")
   assert(type(internal) == "boolean" or not internal)

   return (internal
           and table.concat(v, ":")..(v.revision and tostring(v.revision) or "")
           or v.string)
end

--- Convert a dependency in table format to a string.
-- @param dep table: The dependency in table format
-- @param internal boolean or nil: Whether to display versions in their
-- internal representation format or how they were specified.
-- @return string: The dependency information pretty-printed as a string.
function vers.show_dep(dep, internal)
   assert(type(dep) == "table")
   assert(type(internal) == "boolean" or not internal)

   if #dep.constraints > 0 then
      local pretty = {}
      for _, c in ipairs(dep.constraints) do
         table.insert(pretty, c.op .. " " .. vers.show_version(c.version, internal))
      end
      return dep.name.." "..table.concat(pretty, ", ")
   else
      return dep.name
   end
end

return vers
