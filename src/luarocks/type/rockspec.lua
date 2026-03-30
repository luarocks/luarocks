local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local type_rockspec = {}








local type_check = require("luarocks.type_check")



type_rockspec.rockspec_format = "3.1"














local rockspec_formats, versions = type_check.declare_schemas({
   ["1.0"] = {
      fields = {
         rockspec_format = { _type = "string" },
         package = { _type = "string", _mandatory = true },
         version = { _type = "string", _pattern = "[%w.]+-[%d]+", _mandatory = true },
         description = {
            fields = {
               summary = { _type = "string" },
               detailed = { _type = "string" },
               homepage = { _type = "string" },
               license = { _type = "string" },
               maintainer = { _type = "string" },
            },
         },
         dependencies = {
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
            },
            _any = {
               _type = "string",
               _name = "a valid dependency string",
               _pattern = "%s*([a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)",
            },
         },
         supported_platforms = {
            _any = { _type = "string" },
         },
         external_dependencies = {
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
            },
            _any = {
               fields = {
                  program = { _type = "string" },
                  header = { _type = "string" },
                  library = { _type = "string" },
               },
            },
         },
         source = {
            _mandatory = true,
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
               url = { _type = "string", _mandatory = true },
               md5 = { _type = "string" },
               file = { _type = "string" },
               dir = { _type = "string" },
               tag = { _type = "string" },
               branch = { _type = "string" },
               module = { _type = "string" },
               cvs_tag = { _type = "string" },
               cvs_module = { _type = "string" },
            },
         },
         build = {
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
               type = { _type = "string" },
               install = {
                  fields = {
                     lua = {
                        _more = true,
                     },
                     lib = {
                        _more = true,
                     },
                     conf = {
                        _more = true,
                     },
                     bin = {
                        _more = true,
                     },
                  },
               },
               copy_directories = {
                  _any = { _type = "string" },
               },
            },
            _more = true,
            _mandatory = true,
         },
         hooks = {
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
               post_install = { _type = "string" },
            },
         },
      },
   },

   ["1.1"] = {
      fields = {
         deploy = {
            fields = {
               wrap_bin_scripts = { _type = "boolean" },
            },
         },
      },
   },

   ["3.0"] = {
      fields = {
         description = {
            fields = {
               labels = {
                  _any = { _type = "string" },
               },
               issues_url = { _type = "string" },
            },
         },
         dependencies = {
            _any = {
               _pattern = "%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)",
            },
         },
         build_dependencies = {
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
            },
            _any = {
               _type = "string",
               _name = "a valid dependency string",
               _pattern = "%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)",
            },
         },
         test_dependencies = {
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
            },
            _any = {
               _type = "string",
               _name = "a valid dependency string",
               _pattern = "%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)",
            },
         },
         build = {
            _mandatory = false,
         },
         test = {
            fields = {
               platforms = type_check.MAGIC_PLATFORMS,
               type = { _type = "string" },
            },
            _more = true,
         },
      },
   },

   ["3.1"] = {},

})









type_rockspec.order = {
   "rockspec_format",
   "package",
   "version",
   "source",
   "description",
   "supported_platforms",
   "dependencies",
   "build_dependencies",
   "external_dependencies",
   "build",
   "test_dependencies",
   "test",
   "hooks",
   sub_orders = {
      ["source"] = { "url", "tag", "branch", "md5" },
      ["description"] = { "summary", "detailed", "homepage", "license" },
      ["build"] = { "type", "modules", "copy_directories", "platforms" },
      ["test"] = { "type" },
   },
}

local function check_rockspec_using_version(rockspec, globals, version)
   local schema = rockspec_formats[version]
   if not schema then
      return nil, "unknown rockspec format " .. version
   end
   local ok, err = type_check.check_undeclared_globals(globals, schema)
   if ok then
      ok, err = type_check.type_check_table(version, rockspec, schema, "")
   end
   if ok then
      return true
   else
      return nil, err
   end
end







function type_rockspec.check(rockspec, globals)

   local version = rockspec.rockspec_format or "1.0"
   local ok, err = check_rockspec_using_version(rockspec, globals, version)
   if ok then
      return true
   end




   local found = false
   for _, v in ipairs(versions) do
      if not found then
         if v == version then
            found = true
         end
      else
         local v_ok = check_rockspec_using_version(rockspec, globals, v)
         if v_ok then
            return nil, err .. " (using rockspec format " .. version .. " -- " ..
            [[adding 'rockspec_format = "]] .. v .. [["' to the rockspec ]] ..
            [[will fix this)]]
         end
      end
   end

   return nil, err .. " (using rockspec format " .. version .. ")"
end

return type_rockspec
