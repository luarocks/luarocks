package = 'validate-args'
version = '1.5.4-1'
source = {{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{++{
  url = "https://bitbucket.org/djerius/validate.args/downloads/validate-args-1.5.4.tar.gz"
}

description = {
   summary = "Function argument validation",
   detailed = [[
	 validate.args is a Lua module that provides a framework for
	 validation of arguments to Lua functions as well as complex data
	 structures. The included validate.inplace module provides "live"
	 validation during assignment of values to elements in tables. ]],
   license = "GPL-3",

}

dependencies = {
   "lua >= 5.1"
}

build = {

   type = "builtin",

   modules = {
      ["validate.args"] = "validate/args.lua",
      ["validate.inplace"] = "validate/inplace.lua",
   },

   copy_directories = {
   "doc", "tests"
   }

}
