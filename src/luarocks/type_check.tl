
local record type_check
   type_check_table: function(version: string, tbl: {any: any}, typetbl: TableSchema, context: string): boolean, string

   record TableSchema
      fields: {string: TableSchema}
      _type: string
      _name: string
      _pattern: string
      _version: string
      _more: boolean
      _mandatory: boolean
      _any: TableSchema
   end

   MAGIC_PLATFORMS: TableSchema
end

local cfg = require("luarocks.core.cfg")
local fun = require("luarocks.fun")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")

local type TableSchema = type_check.TableSchema
--------------------------------------------------------------------------------

-- A magic constant that is not used anywhere in a schema definition
-- and retains equality when the table is deep-copied.
type_check.MAGIC_PLATFORMS = {}

do
   local function fill_in_version(tbl: TableSchema, version?: string)

      if not tbl.fields then --! validation
         return
      end

      for _, v in pairs(tbl.fields) do
         if v is TableSchema then
            if v._version == nil then
               v._version = version
            end
            fill_in_version(v)
         end
      end
   end

   local function expand_magic_platforms(tbl: TableSchema)
      for k,v in pairs(tbl.fields) do
         if v == type_check.MAGIC_PLATFORMS then
            tbl.fields[k] = {
               _any = util.deep_copy(tbl as {string: any}) as TableSchema
            }
            tbl.fields[k]._any.fields[k] = nil
            expand_magic_platforms(v)
         end
      end
   end

   -- Build a table of schemas.
   -- @param versions a table where each key is a version number as a string,
   -- and the value is a schema specification. Schema versions are considered
   -- incremental: version "2.0" only needs to specify what's new/changed from
   -- version "1.0".
   function type_check.declare_schemas(inputs: {string: TableSchema}): {string : TableSchema}, {string}
      local schemas: {string: TableSchema} = {}
      local parent_version: string

      local versions = fun.reverse_in(fun.sort_in(util.keys(inputs), vers.compare_versions))

      for _, version in ipairs(versions) do
         local schema = inputs[version]
         if parent_version then
            local copy: TableSchema = util.deep_copy(schemas[parent_version] as {any: any}) as TableSchema
            util.deep_merge(copy as {any: any}, schema as {any: any})
            schema = copy
         end
         fill_in_version(schema, version)
         expand_magic_platforms(schema)
         parent_version = version
         schemas[version] = schema
      end

      return schemas, versions
   end
end

--------------------------------------------------------------------------------

local function check_version(version: string, typetbl: TableSchema, context: string): boolean, string
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
local function type_check_item(version: string, item: any, typetbl: TableSchema, context: string): boolean, string

   if typetbl._version and typetbl._version ~= "1.0" then
      local ok, err = check_version(version, typetbl, context)
      if not ok then
         return nil, err
      end
   end

   local expected_type = typetbl._type or "table"

   if expected_type == "number" then
      if not tonumber(item) then
         return nil, "Type mismatch on field "..context..": expected a number"
      end
   elseif expected_type == "string" then
      if not item is string then
         return nil, "Type mismatch on field "..context..": expected a string, got "..type(item)
      end
      local pattern = typetbl._pattern
      if pattern then
         if not item:match("^"..pattern.."$") then
            local what = typetbl._name or ("'"..pattern.."'")
            return nil, "Type mismatch on field "..context..": invalid value '"..item.."' does not match " .. what
         end
      end
   elseif expected_type == "table" then
      if not item is table then
         return nil, "Type mismatch on field "..context..": expected a table"
      else
         return type_check.type_check_table(version, item, typetbl, context)
      end
   elseif type(item) ~= expected_type then
      return nil, "Type mismatch on field "..context..": expected "..expected_type
   end
   return true
end

local function mkfield(context: string, field: any): string
   if context == "" then
      return tostring(field)
   elseif field is string then
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
function type_check.type_check_table(version: string, tbl: {any: any}, typetbl: TableSchema, context: string): boolean, string

   local ok, err = check_version(version, typetbl, context)
   if not ok then
      return nil, err
   end

   if not typetbl.fields then --! validation
      -- if there are no fields, exit the checker
      return true
   end

   for k, v in pairs(tbl) do
      local t = typetbl.fields[tostring(k)] or typetbl._any
      if t then
         ok, err = type_check_item(version, v, t, mkfield(context, k))
         if not ok then return nil, err end
      elseif typetbl._more then
         -- Accept unknown field
      else
         if not cfg.accept_unknown_fields then
            return nil, "Unknown field "..tostring(k)
         end
      end
   end

   for k, v in pairs(typetbl.fields) do
      if k:sub(1,1) ~= "_" and v._mandatory then
         if not tbl[k] then
            return nil, "Mandatory field "..mkfield(context, k).." is missing."
         end
      end
   end
   return true
end

function type_check.check_undeclared_globals(globals: {string: any}, typetbl: TableSchema): boolean, string
   local undeclared = {}
   for glob, _ in pairs(globals) do
      if not (typetbl.fields[glob] or typetbl.fields["MUST_"..glob]) then
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
