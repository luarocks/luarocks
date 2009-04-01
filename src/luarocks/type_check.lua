
--- Type-checking functions.
-- Functions and definitions for doing a basic lint check on files
-- loaded by LuaRocks.
module("luarocks.type_check", package.seeall)

rockspec_format = "1.0"

rockspec_types = {
   rockspec_format = "string",
   MUST_package = "string",
   MUST_version = "string",
   description = {
      summary = "string",
      detailed = "string",
      homepage = "string",
      license = "string",
      maintainer = "string"
   },
   dependencies = {
      platforms = {},
      ANY = "string"
   },
   supported_platforms = {
      ANY = "string"
   },
   external_dependencies = {
      platforms = {},
      ANY = {
         program = "string",
         header = "string",
         library = "string"
      }
   },
   MUST_source = {
      platforms = {},
      MUST_url = "string",
      md5 = "string",
      file = "string",
      dir = "string",
      tag = "string",
      branch = "string",
      module = "string",
      cvs_tag = "string",
      cvs_module = "string"
   },
   build = {
      platforms = {},
      type = "string",
      install = {
         lua = {
            MORE = true
         },
         lib = {
            MORE = true
         },
         conf = {
            MORE = true
         },
         bin = {
            MORE = true
         }
      },
      copy_directories = {
         ANY = "string"
      },
      MORE = true
   },
   hooks = {
      platforms = {},
      post_install = "string"
   }
}

rockspec_types.build.platforms.ANY = rockspec_types.build
rockspec_types.dependencies.platforms.ANY = rockspec_types.dependencies
rockspec_types.external_dependencies.platforms.ANY = rockspec_types.external_dependencies
rockspec_types.MUST_source.platforms.ANY = rockspec_types.MUST_source
rockspec_types.hooks.platforms.ANY = rockspec_types.hooks

manifest_types = {
   MUST_repository = {
      -- packages
      ANY = {
         -- versions
         ANY = {
            -- items
            ANY = {
               MUST_arch = "string",
               modules = { ANY = "string" },
               commands = { ANY = "string" },
               dependencies = { ANY = "string" },
               -- TODO: to be extended with more metadata.
            }
         }
      }
   },
   MUST_modules = {
      -- modules
      ANY = {
         -- providers
         ANY = "string"
      }
   },
   MUST_commands = {
      -- modules
      ANY = {
         -- commands
         ANY = "string"
      }
   },
   dependencies = {
      -- each module
      ANY = {
         -- each version
         ANY = {
            -- each dependency
            ANY = {
               name = "string",
               constraints = {
                  ANY = {
                     no_upgrade = "boolean",
                     op = "string",
                     version = {
                        string = "string",
                        ANY = 0,
                     }
                  }
               }
            }
         }
      }
   }
}

local type_check_table

--- Type check an object.
-- The object is compared against an archetypical value
-- matching the expected type -- the actual values don't matter,
-- only their types. Tables are type checked recursively.
-- @param name any: The object name (for error messages).
-- @param item any: The object being checked.
-- @param expected any: The reference object. In case of a table,
-- its is structured as a type reference table.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
-- @see type_check_table
local function type_check_item(name, item, expected, context)
   name = tostring(name)

   local item_type = type(item)
   local expected_type = type(expected)
   if expected_type == "number" then
      if not tonumber(item) then
         return nil, "Type mismatch on field "..context..name..": expected a number"
      end
   elseif expected_type == "table" then
      if item_type ~= expected_type then
         return nil, "Type mismatch on field "..context..name..": expected a table"
      else
         return type_check_table(item, expected, context..name..".")
      end
   elseif item_type ~= expected_type then
      return nil, "Type mismatch on field "..context..name..": expected a "..expected_type
   end
   return true
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
-- @param tbl table: The table to be type checked.
-- @param types table: The reference table, containing
-- values for recognized fields in the checked table.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
type_check_table = function(tbl, types, context)
   assert(type(tbl) == "table")
   assert(type(types) == "table")
   for k, v in pairs(tbl) do
      local t = types[k] or (type(k) == "string" and types["MUST_"..k]) or types.ANY
      if t then 
         local ok, err = type_check_item(k, v, t, context)
         if not ok then return nil, err end
      elseif types.MORE then
         -- Accept unknown field
      else
         return nil, "Unknown field "..k
      end
   end
   for k, v in pairs(types) do
      local mandatory_key = k:match("^MUST_(.+)")
      if mandatory_key then
         if not tbl[mandatory_key] then
            return nil, "Mandatory field "..context..mandatory_key.." is missing."
         end
      end
   end
   return true
end

--- Type check a rockspec table.
-- Verify the correctness of elements from a 
-- rockspec table, reporting on unknown fields and type
-- mismatches.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_check_rockspec(rockspec)
   assert(type(rockspec) == "table")
   return type_check_table(rockspec, rockspec_types, "")
end

--- Type check a manifest table.
-- Verify the correctness of elements from a 
-- manifest table, reporting on unknown fields and type
-- mismatches.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_check_manifest(manifest)
   assert(type(manifest) == "table")
   return type_check_table(manifest, manifest_types, "")
end
