local record type_manifest
end

local type Manifest = require("luarocks.core.types.manifest").Manifest

local type_check = require("luarocks.type_check")

local manifest_formats = type_check.declare_schemas({
   ["3.0"] = {
      fields = {
         repository = {
            _mandatory = true,
            -- packages
            _any = {
               -- versions
               _any = {
                  -- items
                  _any = {
                     fields = {
                        arch = { _type = "string", _mandatory = true },
                        modules = { _any = { _type = "string" } },
                        commands = { _any = { _type = "string" } },
                        dependencies = { _any = { _type = "string" } },
                        -- TODO: to be extended with more metadata.
                     }
                  }
               }
            }
         },
         modules = {
            _mandatory = true,
            -- modules
            _any = {
               -- providers
               _any = { _type = "string" }
            }
         },
         commands = {
            _mandatory = true,
            -- modules
            _any = {
               -- commands
               _any = { _type = "string" }
            }
         },
         dependencies = {
            -- each module
            _any = {
               -- each version
               _any = {
                  -- each dependency
                  _any = {
                     fields = {
                        name = { _type = "string" },
                        namespace = { _type = "string" },
                        constraints = {
                           _any = {
                              fields = {
                                 no_upgrade = { _type = "boolean" },
                                 op = { _type = "string" },
                                 version = {
                                    fields = {
                                       string = { _type = "string" },
                                    },
                                    _any = { _type = "number" },
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
})

--- Type check a manifest table.
-- Verify the correctness of elements from a
-- manifest table, reporting on unknown fields and type
-- mismatches.
-- @return boolean or (nil, string): true if type checking
-- succeeded, or nil and an error message if it failed.
function type_manifest.check(manifest: Manifest, globals: {string: any}): boolean, string
   local format = manifest_formats["3.0"]
   local ok, err = type_check.check_undeclared_globals(globals, format)
   if not ok then return nil, err end
   return type_check.type_check_table("3.0", manifest as {any: any}, format, "")
end

return type_manifest
