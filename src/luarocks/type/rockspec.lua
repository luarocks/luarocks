local type_rockspec = {}

local type_check = require("luarocks.type_check")

type_rockspec.rockspec_format = "3.0"

local string_1 = type_check.string_1
local mandatory_string_1 = type_check.mandatory_string_1

local string_3 = { _type = "string", _version = "3.0" }
local list_of_strings_3 = { _any = string_3, _version = "3.0" }

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
      labels = list_of_strings_3,
      issues_url = string_3,
   },
   dependencies = {
      platforms = {}, -- recursively defined below
      _any = {
         _type = "string",
         _name = "a valid dependency string",
         _patterns = {
            ["1.0"] = "%s*([a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)",
            ["3.0"] = "%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)",
         },
      },
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

type_rockspec.order = {"rockspec_format", "package", "version", 
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

--- Type check a rockspec table.
-- Verify the correctness of elements from a 
-- rockspec table, reporting on unknown fields and type
-- mismatches.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_rockspec.check(rockspec, globals)
   assert(type(rockspec) == "table")
   if not rockspec.rockspec_format then
      rockspec.rockspec_format = "1.0"
   end
   local ok, err = type_check.check_undeclared_globals(globals, rockspec_types)
   if ok then
      ok, err = type_check.type_check_table(rockspec.rockspec_format, rockspec, rockspec_types, "")
   end
   if ok then
      return true
   end
   return nil, err .. " (rockspec format " .. rockspec.rockspec_format .. ")"
end

return type_rockspec
