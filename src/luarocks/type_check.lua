
local type_check = {}

local cfg = require("luarocks.core.cfg")
local vers = require("luarocks.core.vers")
local require = nil
--------------------------------------------------------------------------------

type_check.string_1 = { _type = "string" }
type_check.number_1 = { _type = "number" }
type_check.mandatory_string_1 = { _type = "string", _mandatory = true }

local function check_version(version, typetbl, context)
   local typetbl_version = typetbl._version or "1.0"
   if vers.compare_versions(typetbl_version, version) then
      if context == "" then
         return nil, "Invalid rockspec_format version number in rockspec? Please fix rockspec accordingly."
      else
         return nil, context.." is not supported in rockspec format "..version.." (requires version "..typetbl_version.."), please fix the rockspec_format field accordingly."
      end
   end
   return true
end

--- Type check an object.
-- The object is compared against an archetypical value
-- matching the expected type -- the actual values don't matter,
-- only their types. Tables are type checked recursively.
-- @param version string: The version of the item.
-- @param item any: The object being checked.
-- @param typetbl any: The type-checking table for the object.
-- @param context string: A string indicating the "context" where the
-- error occurred (the full table path), for error messages.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
-- @see type_check_table
local function type_check_item(version, item, typetbl, context)
   assert(type(version) == "string")

   if typetbl._version and typetbl._version ~= "1.0" then
      local ok, err = check_version(version, typetbl, context)
      if not ok then
         return nil, err
      end
   end
   
   local item_type = type(item) or "nil"
   local expected_type = typetbl._type or "table"
   
   if expected_type == "number" then
      if not tonumber(item) then
         return nil, "Type mismatch on field "..context..": expected a number"
      end
   elseif expected_type == "string" then
      if item_type ~= "string" then
         return nil, "Type mismatch on field "..context..": expected a string, got "..item_type
      end
      local pattern = (typetbl._patterns and typetbl._patterns[version]) or typetbl._pattern
      if pattern then
         if not item:match("^"..pattern.."$") then
            local what = typetbl._name or ("'"..pattern.."'")
            return nil, "Type mismatch on field "..context..": invalid value '"..item.."' does not match " .. what
         end
      end
   elseif expected_type == "table" then
      if item_type ~= expected_type then
         return nil, "Type mismatch on field "..context..": expected a table"
      else
         return type_check.type_check_table(version, item, typetbl, context)
      end
   elseif item_type ~= expected_type then
      return nil, "Type mismatch on field "..context..": expected "..expected_type
   end
   return true
end

local function mkfield(context, field)
   if context == "" then
      return tostring(field)
   elseif type(field) == "string" then
      return context.."."..field
   else
      return context.."["..tostring(field).."]"
   end
end

--- Type check the contents of a table.
-- The table's contents are compared against a reference table,
-- which contains the recognized fields, with archetypical values
-- matching the expected types -- the actual values of items in the
-- reference table don't matter, only their types (ie, for field x
-- in tbl that is correctly typed, type(tbl.x) == type(types.x)).
-- If the reference table contains a field called MORE, then
-- unknown fields in the checked table are accepted.
-- If it contains a field called ANY, then its type will be 
-- used to check any unknown fields. If a field is prefixed
-- with MUST_, it is mandatory; its absence from the table is
-- a type error.
-- Tables are type checked recursively.
-- @param version string: The version of tbl.
-- @param tbl table: The table to be type checked.
-- @param typetbl table: The type-checking table, containing
-- values for recognized fields in the checked table.
-- @param context string: A string indicating the "context" where the
-- error occurred (such as the name of the table the item is a part of),
-- to be used by error messages.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_check.type_check_table(version, tbl, typetbl, context)
   assert(type(version) == "string")
   assert(type(tbl) == "table")
   assert(type(typetbl) == "table")
   
   local ok, err = check_version(version, typetbl, context)
   if not ok then
      return nil, err
   end
   
   for k, v in pairs(tbl) do
      local t = typetbl[k] or typetbl._any
      if t then 
         local ok, err = type_check_item(version, v, t, mkfield(context, k))
         if not ok then return nil, err end
      elseif typetbl._more then
         -- Accept unknown field
      else
         if not cfg.accept_unknown_fields then
            return nil, "Unknown field "..k
         end
      end
   end
   for k, v in pairs(typetbl) do
      if k:sub(1,1) ~= "_" and v._mandatory then
         if not tbl[k] then
            return nil, "Mandatory field "..mkfield(context, k).." is missing."
         end
      end
   end
   return true
end

function type_check.check_undeclared_globals(globals, typetbl)
   local undeclared = {}
   for glob, _ in pairs(globals) do
      if not (typetbl[glob] or typetbl["MUST_"..glob]) then
         table.insert(undeclared, glob)
      end
   end
   if #undeclared == 1 then
      return nil, "Unknown variable: "..undeclared[1]
   elseif #undeclared > 1 then
      return nil, "Unknown variables: "..table.concat(undeclared, ", ")
   end
   return true
end

return type_check
