local type_manifest = {}

local type_check = require("luarocks.type_check")

local number_1 = type_check.number_1
local string_1 = type_check.string_1
local mandatory_string_1 = type_check.mandatory_string_1

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


--- Type check a manifest table.
-- Verify the correctness of elements from a 
-- manifest table, reporting on unknown fields and type
-- mismatches.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_manifest.check(manifest, globals)
   assert(type(manifest) == "table")
   local ok, err = type_check.check_undeclared_globals(globals, manifest_types)
   if not ok then return nil, err end
   return type_check.type_check_table("1.0", manifest, manifest_types, "")
end

return type_manifest
