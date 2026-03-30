local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type
local type_check = { TableSchema = {} }
















local cfg = require("luarocks.core.cfg")
local fun = require("luarocks.fun")
local util = require("luarocks.util")
local vers = require("luarocks.core.vers")






type_check.MAGIC_PLATFORMS = {}

do
   local function fill_in_version(tbl, version)

      if not tbl.fields then
         return
      end

      for _, v in pairs(tbl.fields) do
         if type(v) == "table" then
            if v._version == nil then
               v._version = version
            end
            fill_in_version(v)
         end
      end
   end

   local function expand_magic_platforms(tbl)
      for k, v in pairs(tbl.fields) do
         if v == type_check.MAGIC_PLATFORMS then
            tbl.fields[k] = {
               _any = util.deep_copy(tbl),
            }
            tbl.fields[k]._any.fields[k] = nil
            expand_magic_platforms(v)
         end
      end
   end






   function type_check.declare_schemas(inputs)
      local schemas = {}
      local parent_version

      local versions = fun.reverse_in(fun.sort_in(util.keys(inputs), vers.compare_versions))

      for _, version in ipairs(versions) do
         local schema = inputs[version]
         if parent_version then
            local copy = util.deep_copy(schemas[parent_version])
            util.deep_merge(copy, schema)
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



local function check_version(version, typetbl, context)
   local typetbl_version = typetbl._version or "1.0"
   if vers.compare_versions(typetbl_version, version) then
      if context == "" then
         return nil, "Invalid rockspec_format version number in rockspec? Please fix rockspec accordingly."
      else
         return nil, context .. " is not supported in rockspec format " .. version .. " (requires version " .. typetbl_version .. "), please fix the rockspec_format field accordingly."
      end
   end
   return true
end















local function type_check_item(version, item, typetbl, context)

   if typetbl._version and typetbl._version ~= "1.0" then
      local ok, err = check_version(version, typetbl, context)
      if not ok then
         return nil, err
      end
   end

   local expected_type = typetbl._type or "table"

   if expected_type == "number" then
      if not tonumber(item) then
         return nil, "Type mismatch on field " .. context .. ": expected a number"
      end
   elseif expected_type == "string" then
      if not (type(item) == "string") then
         return nil, "Type mismatch on field " .. context .. ": expected a string, got " .. type(item)
      end
      local pattern = typetbl._pattern
      if pattern then
         if not item:match("^" .. pattern .. "$") then
            local what = typetbl._name or ("'" .. pattern .. "'")
            return nil, "Type mismatch on field " .. context .. ": invalid value '" .. item .. "' does not match " .. what
         end
      end
   elseif expected_type == "table" then
      if not (type(item) == "table") then
         return nil, "Type mismatch on field " .. context .. ": expected a table"
      else
         return type_check.type_check_table(version, item, typetbl, context)
      end
   elseif type(item) ~= expected_type then
      return nil, "Type mismatch on field " .. context .. ": expected " .. expected_type
   end
   return true
end

local function mkfield(context, field)
   if context == "" then
      return tostring(field)
   elseif type(field) == "string" then
      return context .. "." .. field
   else
      return context .. "[" .. tostring(field) .. "]"
   end
end























function type_check.type_check_table(version, tbl, typetbl, context)

   local ok, err = check_version(version, typetbl, context)
   if not ok then
      return nil, err
   end

   if not typetbl.fields then

      return true
   end

   for k, v in pairs(tbl) do
      local t = typetbl.fields[tostring(k)] or typetbl._any
      if t then
         ok, err = type_check_item(version, v, t, mkfield(context, k))
         if not ok then return nil, err end
      elseif typetbl._more then

      else
         if not cfg.accept_unknown_fields then
            return nil, "Unknown field " .. tostring(k)
         end
      end
   end

   for k, v in pairs(typetbl.fields) do
      if k:sub(1, 1) ~= "_" and v._mandatory then
         if not tbl[k] then
            return nil, "Mandatory field " .. mkfield(context, k) .. " is missing."
         end
      end
   end
   return true
end

function type_check.check_undeclared_globals(globals, typetbl)
   local undeclared = {}
   for glob, _ in pairs(globals) do
      if not (typetbl.fields[glob] or typetbl.fields["MUST_" .. glob]) then
         table.insert(undeclared, glob)
      end
   end
   if #undeclared == 1 then
      return nil, "Unknown variable: " .. undeclared[1]
   elseif #undeclared > 1 then
      return nil, "Unknown variables: " .. table.concat(undeclared, ", ")
   end
   return true
end

return type_check
