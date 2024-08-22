local type_manifest = {}




local type_check = require("luarocks.type_check")

local manifest_formats = type_check.declare_schemas({
   ["3.0"] = {
      fields = {
         repository = {
            _mandatory = true,

            _any = {

               _any = {

                  _any = {
                     fields = {
                        arch = { _type = "string", _mandatory = true },
                        modules = { _any = { _type = "string" } },
                        commands = { _any = { _type = "string" } },
                        dependencies = { _any = { _type = "string" } },

                     },
                  },
               },
            },
         },
         modules = {
            _mandatory = true,

            _any = {

               _any = { _type = "string" },
            },
         },
         commands = {
            _mandatory = true,

            _any = {

               _any = { _type = "string" },
            },
         },
         dependencies = {

            _any = {

               _any = {

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
                                 },
                              },
                           },
                        },
                     },
                  },
               },
            },
         },
      },
   },
})







function type_manifest.check(manifest, globals)
   local format = manifest_formats["3.0"]
   local ok, err = type_check.check_undeclared_globals(globals, format)
   if not ok then return nil, err end
   return type_check.type_check_table("3.0", manifest, format, "")
end

return type_manifest
