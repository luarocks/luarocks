
--- LuaRocks-specific path handling functions.
-- All paths are configured in this module, making it a single
-- point where the layout of the local installation is defined in LuaRocks.
local path = {}

local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")

--- Infer rockspec filename from a rock filename.
-- @param rock_name string: Pathname of a rock file.
-- @return string: Filename of the rockspec, without path.
function path.rockspec_name_from_rock(rock_name)
   assert(type(rock_name) == "string")
   local base_name = dir.base_name(rock_name)
   return base_name:match("(.*)%.[^.]*.rock") .. ".rockspec"
end

function path.rocks_dir(tree)
   if type(tree) == "string" then
      return dir.path(tree, cfg.rocks_subdir)
   else
      assert(type(tree) == "table")
      return tree.rocks_dir or dir.path(tree.root, cfg.rocks_subdir)
   end
end

function path.root_dir(rocks_dir)
   assert(type(rocks_dir) == "string")
   return rocks_dir:match("(.*)" .. util.matchquote(cfg.rocks_subdir) .. ".*$")
end

function path.rocks_tree_to_string(tree)
   if type(tree) == "string" then
      return tree
   else
      assert(type(tree) == "table")
      return tree.root
   end
end

function path.deploy_bin_dir(tree)
   if type(tree) == "string" then
      return dir.path(tree, "bin")
   else
      assert(type(tree) == "table")
      return tree.bin_dir or dir.path(tree.root, "bin")
   end
end

function path.deploy_lua_dir(tree)
   if type(tree) == "string" then
      return dir.path(tree, cfg.lua_modules_path)
   else
      assert(type(tree) == "table")
      return tree.lua_dir or dir.path(tree.root, cfg.lua_modules_path)
   end
end

function path.deploy_lib_dir(tree)
   if type(tree) == "string" then
      return dir.path(tree, cfg.lib_modules_path)
   else
      assert(type(tree) == "table")
      return tree.lib_dir or dir.path(tree.root, cfg.lib_modules_path)
   end
end

function path.manifest_file(tree)
   if type(tree) == "string" then
      return dir.path(tree, cfg.rocks_subdir, "manifest")
   else
      assert(type(tree) == "table")
      return (tree.rocks_dir and dir.path(tree.rocks_dir, "manifest")) or dir.path(tree.root, cfg.rocks_subdir, "manifest")
   end
end

--- Get the directory for all versions of a package in a tree.
-- @param name string: The package name. 
-- @return string: The resulting path -- does not guarantee that
-- @param tree string or nil: If given, specifies the local tree to use.
-- the package (and by extension, the path) exists.
function path.versions_dir(name, tree)
   assert(type(name) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name)
end

--- Get the local installation directory (prefix) for a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function path.install_dir(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version)
end

--- Get the local filename of the rockspec of an installed rock.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the file) exists.
function path.rockspec_file(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version, name.."-"..version..".rockspec")
end

--- Get the local filename of the rock_manifest file of an installed rock.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the file) exists.
function path.rock_manifest_file(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version, "rock_manifest")
end

--- Get the local installation directory for C libraries of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function path.lib_dir(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version, "lib")
end

--- Get the local installation directory for Lua modules of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function path.lua_dir(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version, "lua")
end

--- Get the local installation directory for documentation of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function path.doc_dir(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version, "doc")
end

--- Get the local installation directory for configuration files of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function path.conf_dir(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version, "conf")
end

--- Get the local installation directory for command-line scripts
-- of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param tree string or nil: If given, specifies the local tree to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function path.bin_dir(name, version, tree)
   assert(type(name) == "string")
   assert(type(version) == "string")
   tree = tree or cfg.root_dir
   return dir.path(path.rocks_dir(tree), name, version, "bin")
end

--- Extract name, version and arch of a rock filename,
-- or name, version and "rockspec" from a rockspec name.
-- @param file_name string: pathname of a rock or rockspec
-- @return (string, string, string) or nil: name, version and arch
-- or nil if name could not be parsed
function path.parse_name(file_name)
   assert(type(file_name) == "string")
   if file_name:match("%.rock$") then
      return dir.base_name(file_name):match("(.*)-([^-]+-%d+)%.([^.]+)%.rock$")
   else
      return dir.base_name(file_name):match("(.*)-([^-]+-%d+)%.(rockspec)")
   end
end

--- Make a rockspec or rock URL.
-- @param pathname string: Base URL or pathname.
-- @param name string: Package name.
-- @param version string: Package version.
-- @param arch string: Architecture identifier, or "rockspec" or "installed".
-- @return string: A URL or pathname following LuaRocks naming conventions.
function path.make_url(pathname, name, version, arch)
   assert(type(pathname) == "string")
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(arch) == "string")

   local filename = name.."-"..version
   if arch == "installed" then
      filename = dir.path(name, version, filename..".rockspec")
   elseif arch == "rockspec" then
      filename = filename..".rockspec"
   else
      filename = filename.."."..arch..".rock"
   end
   return dir.path(pathname, filename)
end

--- Convert a pathname to a module identifier.
-- In Unix, for example, a path "foo/bar/baz.lua" is converted to
-- "foo.bar.baz"; "bla/init.lua" returns "bla"; "foo.so" returns "foo".
-- @param file string: Pathname of module
-- @return string: The module identifier, or nil if given path is
-- not a conformant module path (the function does not check if the
-- path actually exists).
function path.path_to_module(file)
   assert(type(file) == "string")

   local name = file:match("(.*)%."..cfg.lua_extension.."$")
   if name then
      name = name:gsub(dir.separator, ".")
      local init = name:match("(.*)%.init$")
      if init then
         name = init
      end
   else
      name = file:match("(.*)%."..cfg.lib_extension.."$")
      if name then
         name = name:gsub(dir.separator, ".")
      end
   end
   if not name then name = file end
   name = name:gsub("^%.+", ""):gsub("%.+$", "")
   return name
end

--- Obtain the directory name where a module should be stored.
-- For example, on Unix, "foo.bar.baz" will return "foo/bar".
-- @param mod string: A module name in Lua dot-separated format.
-- @return string: A directory name using the platform's separator.
function path.module_to_path(mod)
   assert(type(mod) == "string")
   return (mod:gsub("[^.]*$", ""):gsub("%.", dir.separator))
end

--- Set up path-related variables for a given rock.
-- Create a "variables" table in the rockspec table, containing
-- adjusted variables according to the configuration file.
-- @param rockspec table: The rockspec table.
function path.configure_paths(rockspec)
   assert(type(rockspec) == "table")
   local vars = {}
   for k,v in pairs(cfg.variables) do
      vars[k] = v
   end
   local name, version = rockspec.name, rockspec.version
   vars.PREFIX = path.install_dir(name, version)
   vars.LUADIR = path.lua_dir(name, version)
   vars.LIBDIR = path.lib_dir(name, version)
   vars.CONFDIR = path.conf_dir(name, version)
   vars.BINDIR = path.bin_dir(name, version)
   vars.DOCDIR = path.doc_dir(name, version)
   rockspec.variables = vars
end

--- Produce a versioned version of a filename.
-- @param file string: filename (must start with prefix)
-- @param prefix string: Path prefix for file
-- @param name string: Rock name
-- @param version string: Rock version
-- @return string: a pathname with the same directory parts and a versioned basename.
function path.versioned_name(file, prefix, name, version)
   assert(type(file) == "string")
   assert(type(name) == "string")
   assert(type(version) == "string")

   local rest = file:sub(#prefix+1):gsub("^/*", "")
   local name_version = (name.."_"..version):gsub("%-", "_"):gsub("%.", "_")
   return dir.path(prefix, name_version.."-"..rest)
end

function path.use_tree(tree)
   cfg.root_dir = tree
   cfg.rocks_dir = path.rocks_dir(tree)
   cfg.deploy_bin_dir = path.deploy_bin_dir(tree)
   cfg.deploy_lua_dir = path.deploy_lua_dir(tree)
   cfg.deploy_lib_dir = path.deploy_lib_dir(tree)
end

--- Apply a given function to the active rocks trees based on chosen dependency mode.
-- @param deps_mode string: Dependency mode: "one" for the current default tree,
-- "all" for all trees, "order" for all trees with priority >= the current default,
-- "none" for no trees (this function becomes a nop).
-- @param fn function: function to be applied, with the tree dir (string) as the first
-- argument and the remaining varargs of map_trees as the following arguments.
-- @return a table with all results of invocations of fn collected.
function path.map_trees(deps_mode, fn, ...)
   local result = {}
   if deps_mode == "one" then
      table.insert(result, (fn(cfg.root_dir, ...)) or 0)
   elseif deps_mode == "all" or deps_mode == "order" then
      local use = false
      if deps_mode == "all" then
         use = true
      end
      for _, tree in ipairs(cfg.rocks_trees) do
         if dir.normalize(path.rocks_tree_to_string(tree)) == dir.normalize(path.rocks_tree_to_string(cfg.root_dir)) then
            use = true
         end
         if use then
            table.insert(result, (fn(tree, ...)) or 0)
         end
      end
   end
   return result
end

local is_src_extension = { [".lua"] = true, [".tl"] = true, [".tld"] = true, [".moon"] = true }

--- Return the pathname of the file that would be loaded for a module, indexed.
-- @param file_name string: module file name as in manifest (eg. "socket/core.so")
-- @param name string: name of the package (eg. "luasocket")
-- @param version string: version number (eg. "2.0.2-1")
-- @param tree string: repository path (eg. "/usr/local")
-- @param i number: the index, 1 if version is the current default, > 1 otherwise.
-- This is done this way for use by select_module in luarocks.loader.
-- @return string: filename of the module (eg. "/usr/local/lib/lua/5.1/socket/core.so")
function path.which_i(file_name, name, version, tree, i)
   local deploy_dir
   local extension = file_name:match("%.[a-z]+$")
   if is_src_extension[extension] then
      deploy_dir = path.deploy_lua_dir(tree)
      file_name = dir.path(deploy_dir, file_name)
   else
      deploy_dir = path.deploy_lib_dir(tree)
      file_name = dir.path(deploy_dir, file_name)
   end
   if i > 1 then
      file_name = path.versioned_name(file_name, deploy_dir, name, version)
   end
   return file_name
end

--- Return the pathname of the file that would be loaded for a module, 
-- returning the versioned pathname if given version is not the default version
-- in the given manifest.
-- @param module_name string: module name (eg. "socket.core")
-- @param file_name string: module file name as in manifest (eg. "socket/core.so")
-- @param name string: name of the package (eg. "luasocket")
-- @param version string: version number (eg. "2.0.2-1")
-- @param tree string: repository path (eg. "/usr/local")
-- @param manifest table: the manifest table for the tree.
-- @return string: filename of the module (eg. "/usr/local/lib/lua/5.1/socket/core.so")
function path.which(module_name, file_name, name, version, tree, manifest)
   local versions = manifest.modules[module_name]
   assert(versions)
   for i, name_version in ipairs(versions) do
      if name_version == name.."/"..version then
         return path.which_i(file_name, name, version, tree, i):gsub("//", "/")
      end
   end
   assert(false)
end

return path
