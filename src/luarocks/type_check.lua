--- Type-checking functions.
-- Functions and definitions for doing a basic lint check on files
-- loaded by LuaRocks.
local type_check = {}
package.loaded["luarocks.type_check"] = type_check

local cfg = require("luarocks.cfg")
local deps = require("luarocks.deps")

type_check.rockspec_format = "1.1"

local string_1 = { _type = "string" }
local number_1 = { _type = "number" }
local mandatory_string_1 = { _type = "string", _mandatory = true }

-- Syntax for type-checking tables:
--
-- A type-checking table describes typing data for a value.
-- Any key starting with an underscore has a special meaning:
-- _type (string) is the Lua type of the value. Default is "table".
-- _version (string) is the minimum rockspec_version that supports this value. Default is "1.0".
-- _mandatory (boolean) indicates if the value is a mandatory key in its container table. Default is false.
-- For "string" types only:
--    _pattern (string) is the string-matching pattern, valid for string types only. Default is ".*".
-- For "table" types only:
--    _any (table) is the type-checking table for unspecified keys, recursively checked.
--    _more (boolean) indicates that the table accepts unspecified keys and does not type-check them.
--    Any other string keys that don't start with an underscore represent known keys and are type-checking tables, recursively checked.

local rockspec_types = {
   rockspec_format = string_1,
   package = mandatory_string_1,
   version = { _type = "string", _pattern = "[%w.]+-[%d]+", _mandatory = true },
   description = {
      summary = string_1,
      detailed = string_1,
      homepage = string_1,
      license = string_1,
      maintainer = string_1,
   },
   dependencies = {
      platforms = {}, -- recursively defined below
      _any = string_1,
   },
   supported_platforms = {
      _any = string_1,
   },
   external_dependencies = {
      platforms = {}, -- recursively defined below
      _any = {
         program = string_1,
         header = string_1,
         library = string_1,
      }
   },
   source = {
      _mandatory = true,
      platforms = {}, -- recursively defined below
      url = mandatory_string_1,
      md5 = string_1,
      file = string_1,
      dir = string_1,
      tag = string_1,
      branch = string_1,
      module = string_1,
      cvs_tag = string_1,
      cvs_module = string_1,
   },
   build = {
      platforms = {}, -- recursively defined below
      type = string_1,
      install = {
         lua = {
            _more = true
         },
         lib = {
            _more = true
         },
         conf = {
            _more = true
         },
         bin = {
            _more = true
         }
      },
      copy_directories = {
         _any = string_1,
      },
      _more = true,
      _mandatory = true
   },
   hooks = {
      platforms = {}, -- recursively defined below
      post_install = string_1,
   },
   deploy = {
      _version = "1.1",
      wrap_bin_scripts = { _type = "boolean", _version = "1.1" },
   }
}

type_check.rockspec_order = {"rockspec_format", "package", "version", 
   { "source", { "url", "tag", "branch", "md5" } },
   { "description", {"summary", "detailed", "homepage", "license" } },
   "supported_platforms", "dependencies", "external_dependencies",
   { "build", {"type", "modules", "copy_directories", "platforms"} },
   "hooks"}

rockspec_types.build.platforms._any = rockspec_types.build
rockspec_types.dependencies.platforms._any = rockspec_types.dependencies
rockspec_types.external_dependencies.platforms._any = rockspec_types.external_dependencies
rockspec_types.source.platforms._any = rockspec_types.source
rockspec_types.hooks.platforms._any = rockspec_types.hooks

local manifest_types = {
   repository = {
      _mandatory = true,
      -- packages
      _any = {
         -- versions
         _any = {
            -- items
            _any = {
               arch = mandatory_string_1,
               modules = { _any = string_1 },
               commands = { _any = string_1 },
               dependencies = { _any = string_1 },
               -- TODO: to be extended with more metadata.
            }
         }
      }
   },
   modules = {
      _mandatory = true,
      -- modules
      _any = {
         -- providers
         _any = string_1
      }
   },
   commands = {
      _mandatory = true,
      -- modules
      _any = {
         -- commands
         _any = string_1
      }
   },
   dependencies = {
      -- each module
      _any = {
         -- each version
         _any = {
            -- each dependency
            _any = {
               name = string_1,
               constraints = {
                  _any = {
                     no_upgrade = { _type = "boolean" },
                     op = string_1,
                     version = {
                        string = string_1,
                        _any = number_1,
                     }
                  }
               }
            }
         }
      }
   }
}

local function check_version(version, typetbl, context)
   local typetbl_version = typetbl._version or "1.0"
   if deps.compare_versions(typetbl_version, version) then
      if context == "" then
         return nil, "Invalid rockspec_format version number in rockspec? Please fix rockspec accordingly."
      else
         return nil, context.." is not supported in rockspec format "..version.." (requires version "..typetbl_version.."), please fix the rockspec_format field accordingly."
      end
   end
   return true
end

local type_check_table

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
   
   local ok, err = check_version(version, typetbl, context)
   if not ok then
      return nil, err
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
      if typetbl._pattern then
         if not item:match("^"..typetbl._pattern.."$") then
            return nil, "Type mismatch on field "..context..": invalid value "..item.." does not match '"..typetbl._pattern.."'"
         end
      end
   elseif expected_type == "table" then
      if item_type ~= expected_type then
         return nil, "Type mismatch on field "..context..": expected a table"
      else
         return type_check_table(version, item, typetbl, context)
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
type_check_table = function(version, tbl, typetbl, context)
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

local function check_undeclared_globals(globals, typetbl)
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

--- Type check a rockspec table.
-- Verify the correctness of elements from a 
-- rockspec table, reporting on unknown fields and type
-- mismatches.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_check.type_check_rockspec(rockspec, globals)
   assert(type(rockspec) == "table")
   if not rockspec.rockspec_format then
      rockspec.rockspec_format = "1.0"
   end
   local ok, err = check_undeclared_globals(globals, rockspec_types)
   if not ok then return nil, err end
   return type_check_table(rockspec.rockspec_format, rockspec, rockspec_types, "")
end

--- Type check a manifest table.
-- Verify the correctness of elements from a 
-- manifest table, reporting on unknown fields and type
-- mismatches.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_check.type_check_manifest(manifest, globals)
   assert(type(manifest) == "table")
   local ok, err = check_undeclared_globals(globals, manifest_types)
   if not ok then return nil, err end
   return type_check_table("1.0", manifest, manifest_types, "")
end

return type_check
