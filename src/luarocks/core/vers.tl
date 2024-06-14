
local record vers
end

local util = require("luarocks.core.util") --! 
--------------------------------------------------------------------------------

local deltas = {
   dev =    120000000,
   scm =    110000000,
   cvs =    100000000,
   rc =    -1000,
   pre =   -10000,
   beta =  -100000,
   alpha = -1000000
}

local record Version
   {number} -- next version of Teal: "is {number}"

   string: string
   revision: number
end

local version_mt = { --? anything to do here
   --- Equality comparison for versions.
   -- All version numbers must be equal.
   -- If both versions have revision numbers, they must be equal;
   -- otherwise the revision number is ignored.
   -- @param v1 table: version table to compare.
   -- @param v2 table: version table to compare.
   -- @return boolean: true if they are considered equivalent.
   __eq = function(v1: Version, v2: Version): boolean
      if #v1 ~= #v2 then
         return false
      end
      for i = 1, #v1 do
         if v1[i] ~= v2[i] then
            return false
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision == v2.revision)
      end
      return true
   end,
   --- Size comparison for versions.
   -- All version numbers are compared.
   -- If both versions have revision numbers, they are compared;
   -- otherwise the revision number is ignored.
   -- @param v1 table: version table to compare.
   -- @param v2 table: version table to compare.
   -- @return boolean: true if v1 is considered lower than v2.
   __lt = function(v1: Version, v2: Version): boolean
      for i = 1, math.max(#v1, #v2) do
         local v1i, v2i = v1[i] or 0, v2[i] or 0
         if v1i ~= v2i then
            return (v1i < v2i)
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision < v2.revision)
      end
      return false
   end,
   -- @param v1 table: version table to compare.
   -- @param v2 table: version table to compare.
   -- @return boolean: true if v1 is considered lower than or equal to v2.
   __le = function(v1: Version, v2: Version): boolean
       return not (v2 < v1) -- luacheck: ignore --!
   end,
   --- Return version as a string.
   -- @param v The version table.
   -- @return The string representation.
   __tostring = function(v: Version): string
      return v.string
   end,
}

local version_cache: {string: Version} = {}
setmetatable(version_cache, {
   __mode = "kv"
})

--- Parse a version string, converting to table format.
-- A version table contains all components of the version string
-- converted to numeric format, stored in the array part of the table.
-- If the version contains a revision, it is stored numerically
-- in the 'revision' field. The original string representation of
-- the string is preserved in the 'string' field.
-- Returned version tables use a metatable
-- allowing later comparison through relational operators.
-- @param vstring string: A version number in string format.
-- @return table or nil: A version table or nil
-- if the input string contains invalid characters.
function vers.parse_version(vstring: string): Version | nil
   if not vstring then return nil end --? needed?

   local cached = version_cache[vstring]
   if cached then
      return cached
   end

   local version: Version = {}
   local i = 1

   local function add_token(number: number)
      version[i] = version[i] and version[i] + number/100000 or number
      i = i + 1
   end

   -- trim leading and trailing spaces
   local v = vstring:match("^%s*(.*)%s*$")
   version.string = v
   -- store revision separately if any
   local main, revision = v:match("(.*)%-(%d+)$")
   if revision then
      v = main
      version.revision = tonumber(revision)
   end
   while #v > 0 do
      -- extract a number
      local token, rest = v:match("^(%d+)[%.%-%_]*(.*)")
      if token then
         add_token(tonumber(token))
      else
         -- extract a word
         token, rest = v:match("^(%a+)[%.%-%_]*(.*)")
         if not token then
            util.warning("version number '"..v.."' could not be parsed.")
            version[i] = 0
            break
         end
         version[i] = deltas[token] or (token:byte() / 1000)
      end
      v = rest
   end
   setmetatable(version, version_mt)
   version_cache[vstring] = version
   return version
end

--- Utility function to compare version numbers given as strings.
-- @param a string: one version.
-- @param b string: another version.
-- @return boolean: True if a > b.
function vers.compare_versions(a: string, b: string): boolean
   if a == b then
      return false
   end
   return vers.parse_version(a) > vers.parse_version(b) --!
end

--- A more lenient check for equivalence between versions.
-- This returns true if the requested components of a version
-- match and ignore the ones that were not given. For example,
-- when requesting "2", then "2", "2.1", "2.3.5-9"... all match.
-- When requesting "2.1", then "2.1", "2.1.3" match, but "2.2"
-- doesn't.
-- @param version string or table: Version to be tested; may be
-- in string format or already parsed into a table.
-- @param requested string or table: Version requested; may be
-- in string format or already parsed into a table.
-- @return boolean: True if the tested version matches the requested
-- version, false otherwise.
local function partial_match(version_for_parse: string | table, requested_for_parce: string | table): boolean

   local version, requested: Version, Version

   if not version_for_parse is {any: any} then version = vers.parse_version(version_for_parse) end
   if not requested_for_parce is {any: any} then requested = vers.parse_version(requested_for_parce) end
   if not version is Version or not requested is Version then return false end --? needed?

   for i, ri in ipairs(requested) do
      local vi = version[i] or 0
      if ri ~= vi then return false end
   end
   if requested.revision then
      return requested.revision == version.revision
   end
   return true
end

--- Check if a version satisfies a set of constraints.
-- @param version table: A version in table format
-- @param constraints table: An array of constraints in table format.
-- @return boolean: True if version satisfies all constraints,
-- false otherwise.
function vers.match_constraints(version: Version, constraints: {any: {any: Version | string}}): boolean
   local ok = true
   setmetatable(version, version_mt)
   for _, constr in pairs(constraints) do
      if constr.version is string then --!
         constr.version = vers.parse_version(constr.version)
      end
      local constr_version, constr_op = constr.version, constr.op
      setmetatable(constr_version, version_mt)
      if     constr_op == "==" then ok = version == constr_version
      elseif constr_op == "~=" then ok = version ~= constr_version
      elseif constr_op == ">"  then ok = version >  constr_version --!
      elseif constr_op == "<"  then ok = version <  constr_version 
      elseif constr_op == ">=" then ok = version >= constr_version 
      elseif constr_op == "<=" then ok = version <= constr_version 
      elseif constr_op == "~>" then ok = partial_match(version, constr_version) --!
      end
      if not ok then break end
   end
   return ok
end

return vers
