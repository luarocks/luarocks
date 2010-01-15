
--- Path and filename handling functions.
-- All paths are configured in this module, making it a single
-- point where the layout of the local installation is defined in LuaRocks.
module("luarocks.path", package.seeall)

local dir = require("luarocks.dir")
local cfg = require("luarocks.cfg")

--- Infer rockspec filename from a rock filename.
-- @param rock_name string: Pathname of a rock file.
-- @return string: Filename of the rockspec, without path.
function rockspec_name_from_rock(rock_name)
   assert(type(rock_name) == "string")
   local base_name = dir.base_name(rock_name)
   return base_name:match("(.*)%.[^.]*.rock") .. ".rockspec"
end

function rocks_dir(repo)
  if type(repo) == "string" then
    return dir.path(repo, "lib", "luarocks", "rocks")
  else
    assert(type(repo) == "table")
    return repo.rocks_dir or dir.path(repo.root, "lib", "luarocks", "rocks")
  end
end

function deploy_bin_dir(repo)
  if type(repo) == "string" then
    return dir.path(repo, "bin")
  else
    assert(type(repo) == "table")
    return repo.bin_dir or dir.path(repo.root, "bin")
  end
end

function deploy_lua_dir(repo)
  if type(repo) == "string" then
    return dir.path(repo, "share", "lua", "5.1")
  else
    assert(type(repo) == "table")
    return repo.lua_dir or dir.path(repo.root, "share", "lua", "5.1")
  end
end

function deploy_lib_dir(repo)
  if type(repo) == "string" then
    return dir.path(repo, "lib", "lua", "5.1")
  else
    assert(type(repo) == "table")
    return repo.lib_dir or dir.path(repo.root, "lib", "lua", "5.1")
  end
end

function manifest_file(repo)
  if type(repo) == "string" then
    return dir.path(repo, "lib", "luarocks", "rocks", "manifest")
  else
    assert(type(repo) == "table")
    return (repo.rocks_dir and dir.path(repo.rocks_dir, "manifest")) or dir.path(repo.root, "lib", "luarocks", "rocks", "manifest")
  end
end

--- Get the repository directory for all versions of a package.
-- @param name string: The package name. 
-- @return string: The resulting path -- does not guarantee that
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- the package (and by extension, the path) exists.
function versions_dir(name, repo)
   assert(type(name) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name)
end

--- Get the local installation directory (prefix) for a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function install_dir(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version)
end

--- Get the local filename of the rockspec of an installed rock.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the file) exists.
function rockspec_file(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version, name.."-"..version..".rockspec")
end

--- Get the local filename of the rock_manifest file of an installed rock.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the file) exists.
function rock_manifest_file(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version, "rock_manifest")
end

--- Get the local installation directory for C libraries of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function lib_dir(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version, "lib")
end

--- Get the local installation directory for Lua modules of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function lua_dir(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version, "lua")
end

--- Get the local installation directory for documentation of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function doc_dir(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version, "doc")
end

--- Get the local installation directory for configuration files of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function conf_dir(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version, "conf")
end

--- Get the local installation directory for command-line scripts
-- of a package.
-- @param name string: The package name. 
-- @param version string: The package version.
-- @param rocks_dir string or nil: If given, specifies the local repository to use.
-- @return string: The resulting path -- does not guarantee that
-- the package (and by extension, the path) exists.
function bin_dir(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or cfg.root_dir
   return dir.path(rocks_dir(repo), name, version, "bin")
end

--- Extract name, version and arch of a rock filename.
-- @param rock_file string: pathname of a rock
-- @return (string, string, string) or nil: name, version and arch
-- of rock, or nil if name could not be parsed
function parse_rock_name(rock_file)
   assert(type(rock_file) == "string")
   return dir.base_name(rock_file):match("(.*)-([^-]+-%d+)%.([^.]+)%.rock$")
end

--- Extract name and version of a rockspec filename.
-- @param rockspec_file string: pathname of a rockspec
-- @return (string, string) or nil: name and version
-- of rockspec, or nil if name could not be parsed
function parse_rockspec_name(rockspec_file)
   assert(type(rockspec_file) == "string")
   return dir.base_name(rockspec_file):match("(.*)-([^-]+-%d+)%.(rockspec)")
end

--- Make a rockspec or rock URL.
-- @param pathname string: Base URL or pathname.
-- @param name string: Package name.
-- @param version string: Package version.
-- @param arch string: Architecture identifier, or "rockspec" or "installed".
-- @return string: A URL or pathname following LuaRocks naming conventions.
function make_url(pathname, name, version, arch)
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
function path_to_module(file)
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
function module_to_path(mod)
   assert(type(mod) == "string")
   return (mod:gsub("[^.]*$", ""):gsub("%.", dir.separator))
end

--- Set up path-related variables for a given rock.
-- Create a "variables" table in the rockspec table, containing
-- adjusted variables according to the configuration file.
-- @param rockspec table: The rockspec table.
function configure_paths(rockspec)
   assert(type(rockspec) == "table")
   local vars = {}
   for k,v in pairs(cfg.variables) do
      vars[k] = v
   end
   local name, version = rockspec.name, rockspec.version
   vars.PREFIX = install_dir(name, version)
   vars.LUADIR = lua_dir(name, version)
   vars.LIBDIR = lib_dir(name, version)
   vars.CONFDIR = conf_dir(name, version)
   vars.BINDIR = bin_dir(name, version)
   vars.DOCDIR = doc_dir(name, version)
   rockspec.variables = vars
end

function versioned_name(file, prefix, name, version)
   assert(type(file) == "string")
   assert(type(name) == "string")
   assert(type(version) == "string")

   local rest = file:sub(#prefix+1):gsub("^/*", "")
   local name_version = (name.."_"..version):gsub("%-", "_"):gsub("%.", "_")
   return dir.path(prefix, name_version.."-"..rest)
end
