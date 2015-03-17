--- Configuration for LuaRocks.
-- Tries to load the user's configuration file and
-- defines defaults for unset values. See the
-- <a href="http://luarocks.org/en/Config_file_format">config
-- file format documentation</a> for details.
--
-- End-users shouldn't edit this file. They can override any defaults
-- set in this file using their system-wide $LUAROCKS_SYSCONFIG file
-- (see luarocks.site_config) or their user-specific configuration file
-- (~/.luarocks/config.lua on Unix or %APPDATA%/luarocks/config.lua on
-- Windows).

local rawset, next, table, pairs, require, io, os, setmetatable, pcall, ipairs, package, tonumber, type, assert, _VERSION =
      rawset, next, table, pairs, require, io, os, setmetatable, pcall, ipairs, package, tonumber, type, assert, _VERSION

--module("luarocks.cfg")
local cfg = {}
package.loaded["luarocks.cfg"] = cfg

local util = require("luarocks.util")

cfg.lua_version = _VERSION:sub(5)
local version_suffix = cfg.lua_version:gsub("%.", "_")

-- Load site-local global configurations
local ok, site_config = pcall(require, "luarocks.site_config_"..version_suffix)
if not ok then
   ok, site_config = pcall(require, "luarocks.site_config")
end
if not ok then
   io.stderr:write("Site-local luarocks/site_config.lua file not found. Incomplete installation?\n")
   site_config = {}
end

cfg.site_config = site_config

cfg.program_version = "2.2.1"
cfg.program_series = "2.2"
cfg.major_version = (cfg.program_version:match("([^.]%.[^.])")) or cfg.program_series

local persist = require("luarocks.persist")

cfg.errorcodes = setmetatable({
   OK = 0,
   UNSPECIFIED = 1,
   PERMISSIONDENIED = 2,
   CONFIGFILE = 3,
   CRASH = 99
},{
   __index = function(t, key)
      local val = rawget(t, key)
      if not val then
         error("'"..tostring(key).."' is not a valid errorcode", 2)
      end
      return val
   end
})


local popen_ok, popen_result = pcall(io.popen, "")
if popen_ok then
   if popen_result then
      popen_result:close()
   end
else
   io.stderr:write("Your version of Lua does not support io.popen,\n")
   io.stderr:write("which is required by LuaRocks. Please check your Lua installation.\n")
   os.exit(cfg.errorcodes.UNSPECIFIED)
end

-- System detection:

local detected = {}
local system,proc

-- A proper installation of LuaRocks will hardcode the system
-- and proc values with site_config.LUAROCKS_UNAME_S and site_config.LUAROCKS_UNAME_M,
-- so that this detection does not run every time. When it is
-- performed, we use the Unix way to identify the system,
-- even on Windows (assuming UnxUtils or Cygwin).
system = site_config.LUAROCKS_UNAME_S or io.popen("uname -s"):read("*l")
proc = site_config.LUAROCKS_UNAME_M or io.popen("uname -m"):read("*l")
if proc:match("i[%d]86") then
   proc = "x86"
elseif proc:match("amd64") or proc:match("x86_64") then
   proc = "x86_64"
elseif proc:match("Power Macintosh") then
   proc = "powerpc"
end

if system == "FreeBSD" then
   detected.unix = true
   detected.freebsd = true
   detected.bsd = true
elseif system == "OpenBSD" then
   detected.unix = true
   detected.openbsd = true
   detected.bsd = true
elseif system == "NetBSD" then
   detected.unix = true
   detected.netbsd = true
   detected.bsd = true
elseif system == "Darwin" then
   detected.unix = true
   detected.macosx = true
   detected.bsd = true
elseif system == "Linux" then
   detected.unix = true
   detected.linux = true
elseif system == "SunOS" then
   detected.unix = true
   detected.solaris = true
elseif system and system:match("^CYGWIN") then
   detected.unix = true
   detected.cygwin = true
elseif system and system:match("^Windows") then
   detected.windows = true
elseif system and system:match("^MINGW") then
   detected.windows = true
   detected.mingw32 = true
else
   detected.unix = true
   -- Fall back to Unix in unknown systems.
end

-- Path configuration:

local sys_config_file, home_config_file
local sys_config_dir, home_config_dir
local sys_config_ok, home_config_ok = false, false
local extra_luarocks_module_dir
sys_config_dir = site_config.LUAROCKS_SYSCONFDIR
if detected.windows then
   cfg.home = os.getenv("APPDATA") or "c:"
   sys_config_dir = sys_config_dir or "c:/luarocks"
   home_config_dir = cfg.home.."/luarocks"
   cfg.home_tree = cfg.home.."/luarocks/"
else
   cfg.home = os.getenv("HOME") or ""
   sys_config_dir = sys_config_dir or "/etc/luarocks"
   home_config_dir = cfg.home.."/.luarocks"
   cfg.home_tree = cfg.home.."/.luarocks/"
end

cfg.variables = {}
cfg.rocks_trees = {}

sys_config_file = site_config.LUAROCKS_SYSCONFIG or sys_config_dir.."/config-"..cfg.lua_version..".lua"
local err, errcode
sys_config_ok, err, errcode = persist.load_into_table(sys_config_file, cfg)

if (not sys_config_ok) and errcode ~= "run" then
   sys_config_file = sys_config_dir.."/config.lua"
   sys_config_ok, err, errcode = persist.load_into_table(sys_config_file, cfg)
end
if (not sys_config_ok) and errcode ~= "open" then
   io.stderr:write(err.."\n")
   os.exit(cfg.errorcodes.CONFIGFILE)
end

if not site_config.LUAROCKS_FORCE_CONFIG then
   local home_overrides, err, errcode
   home_config_file = os.getenv("LUAROCKS_CONFIG_" .. version_suffix) or os.getenv("LUAROCKS_CONFIG")
   if home_config_file then
      home_overrides, err, errcode = persist.load_into_table(home_config_file, { home = cfg.home, lua_version = cfg.lua_version })
   else
      home_config_file = home_config_dir.."/config-"..cfg.lua_version..".lua"
      home_overrides, err, errcode = persist.load_into_table(home_config_file, { home = cfg.home, lua_version = cfg.lua_version })
      if (not home_overrides) and (not errcode == "run") then
         home_config_file = home_config_dir.."/config.lua"
         home_overrides, err, errcode = persist.load_into_table(home_config_file, { home = cfg.home, lua_version = cfg.lua_version })
      end
   end
   if home_overrides then
      home_config_ok = true
      if home_overrides.rocks_trees then
         cfg.rocks_trees = nil
      end
      if home_overrides.rocks_servers then
         cfg.rocks_servers = nil
      end
      util.deep_merge(cfg, home_overrides)
   else
      home_config_ok = home_overrides
      if errcode ~= "open" then
         io.stderr:write(err.."\n")
         os.exit(cfg.errorcodes.CONFIGFILE)
      end
   end
end

if not next(cfg.rocks_trees) then
   if cfg.home_tree then
      table.insert(cfg.rocks_trees, { name = "user", root = cfg.home_tree } )
   end
   if site_config.LUAROCKS_ROCKS_TREE then
      table.insert(cfg.rocks_trees, { name = "system", root = site_config.LUAROCKS_ROCKS_TREE } )
   end
end

-- Configure defaults:

local defaults = {

   local_by_default = false,
   use_extensions = false,
   accept_unknown_fields = false,
   fs_use_modules = true,
   hooks_enabled = true,
   deps_mode = "one",
   check_certificates = false,

   lua_modules_path = "/share/lua/"..cfg.lua_version,
   lib_modules_path = "/lib/lua/"..cfg.lua_version,
   rocks_subdir = site_config.LUAROCKS_ROCKS_SUBDIR or "/lib/luarocks/rocks",

   arch = "unknown",
   lib_extension = "unknown",
   obj_extension = "unknown",

   rocks_servers = {
      {
        "https://rocks.moonscript.org",
        "https://raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/master/",
        "http://luafr.org/moonrocks/",
        "http://luarocks.logiceditor.com/rocks",
      }
   },
   disabled_servers = {},
   
   upload = {
      server = "https://rocks.moonscript.org",
      tool_version = "1.0.0",
      api_version = "1",
   },

   lua_extension = "lua",
   lua_interpreter = site_config.LUA_INTERPRETER or "lua",
   downloader = site_config.LUAROCKS_DOWNLOADER or "wget",
   md5checker = site_config.LUAROCKS_MD5CHECKER or "md5sum",
   connection_timeout = 30,  -- 0 = no timeout

   variables = {
      MAKE = "make",
      CC = "cc",
      LD = "ld",

      CVS = "cvs",
      GIT = "git",
      SSCM = "sscm",
      SVN = "svn",
      HG = "hg",

      RSYNC = "rsync",
      WGET = "wget",
      SCP = "scp",
      CURL = "curl",

      PWD = "pwd",
      MKDIR = "mkdir",
      RMDIR = "rmdir",
      CP = "cp",
      LS = "ls",
      RM = "rm",
      FIND = "find",
      TEST = "test",
      CHMOD = "chmod",

      ZIP = "zip",
      UNZIP = "unzip -n",
      GUNZIP = "gunzip",
      BUNZIP2 = "bunzip2",
      TAR = "tar",

      MD5SUM = "md5sum",
      OPENSSL = "openssl",
      MD5 = "md5",
      STAT = "stat",

      CMAKE = "cmake",
      SEVENZ = "7z",

      RSYNCFLAGS = "--exclude=.git -Oavz",
      STATFLAG = "-c '%a'",
      CURLNOCERTFLAG = "",
      WGETNOCERTFLAG = "",
   },

   external_deps_subdirs = site_config.LUAROCKS_EXTERNAL_DEPS_SUBDIRS or {
      bin = "bin",
      lib = "lib",
      include = "include"
   },
   runtime_external_deps_subdirs = site_config.LUAROCKS_RUNTIME_EXTERNAL_DEPS_SUBDIRS or {
      bin = "bin",
      lib = "lib",
      include = "include"
   },

   rocks_provided = {}
}

if detected.windows then
   local full_prefix = site_config.LUAROCKS_PREFIX.."\\"..cfg.major_version
   extra_luarocks_module_dir = full_prefix.."\\lua\\?.lua"

   home_config_file = home_config_file and home_config_file:gsub("\\","/")
   defaults.fs_use_modules = false
   defaults.arch = "win32-"..proc
   defaults.platforms = {"win32", "windows" }
   defaults.lib_extension = "dll"
   defaults.external_lib_extension = "dll"
   defaults.obj_extension = "obj"
   defaults.external_deps_dirs = { "c:/external/" }
   defaults.variables.LUA_BINDIR = site_config.LUA_BINDIR and site_config.LUA_BINDIR:gsub("\\", "/") or "c:/lua"..cfg.lua_version.."/bin"
   defaults.variables.LUA_INCDIR = site_config.LUA_INCDIR and site_config.LUA_INCDIR:gsub("\\", "/") or "c:/lua"..cfg.lua_version.."/include"
   defaults.variables.LUA_LIBDIR = site_config.LUA_LIBDIR and site_config.LUA_LIBDIR:gsub("\\", "/") or "c:/lua"..cfg.lua_version.."/lib"
   defaults.cmake_generator = "MinGW Makefiles"
   defaults.makefile = "Makefile.win"
   defaults.variables.MAKE = "nmake"
   defaults.variables.CC = "cl"
   defaults.variables.RC = "rc"
   defaults.variables.WRAPPER = full_prefix.."\\rclauncher.c"
   defaults.variables.LD = "link"
   defaults.variables.MT = "mt"
   defaults.variables.LUALIB = "lua"..cfg.lua_version..".lib"
   defaults.variables.CFLAGS = "/MD /O2"
   defaults.variables.LIBFLAG = "/dll"

   local bins = { "SEVENZ", "CP", "FIND", "LS", "MD5SUM",
      "MKDIR", "MV", "PWD", "RMDIR", "TEST", "UNAME", "WGET" }
   for _, var in ipairs(bins) do
      if defaults.variables[var] then
         defaults.variables[var] = full_prefix.."\\tools\\"..defaults.variables[var]
      end
   end

   defaults.external_deps_patterns = {
      bin = { "?.exe", "?.bat" },
      lib = { "?.lib", "?.dll", "lib?.dll" },
      include = { "?.h" }
   }
   defaults.runtime_external_deps_patterns = {
      bin = { "?.exe", "?.bat" },
      lib = { "?.dll", "lib?.dll" },
      include = { "?.h" }
   }
   defaults.export_path = "SET PATH=%s"
   defaults.export_path_separator = ";"
   defaults.export_lua_path = "SET LUA_PATH=%s"
   defaults.export_lua_cpath = "SET LUA_CPATH=%s"
   defaults.wrapper_suffix = ".bat"

   local localappdata = os.getenv("LOCALAPPDATA")
   if not localappdata then
      -- for Windows versions below Vista
      localappdata = os.getenv("USERPROFILE").."/Local Settings/Application Data"
   end
   defaults.local_cache = localappdata.."/LuaRocks/Cache"
   defaults.web_browser = "start"
end

if detected.mingw32 then
   defaults.platforms = { "win32", "mingw32", "windows" }
   defaults.obj_extension = "o"
   defaults.cmake_generator = "MinGW Makefiles"
   defaults.variables.MAKE = "mingw32-make"
   defaults.variables.CC = "mingw32-gcc"
   defaults.variables.RC = "windres"
   defaults.variables.LD = "mingw32-gcc"
   defaults.variables.CFLAGS = "-O2"
   defaults.variables.LIBFLAG = "-shared"
   defaults.external_deps_patterns = {
      bin = { "?.exe", "?.bat" },
      -- mingw lookup list from http://stackoverflow.com/a/15853231/1793220
      -- ...should we keep ?.lib at the end? It's not in the above list.
      lib = { "lib?.dll.a", "?.dll.a", "lib?.a", "cyg?.dll", "lib?.dll", "?.dll", "?.lib" },
      include = { "?.h" }
   }
   defaults.runtime_external_deps_patterns = {
      bin = { "?.exe", "?.bat" },
      lib = { "cyg?.dll", "?.dll", "lib?.dll" },
      include = { "?.h" }
   }

end

if detected.unix then
   defaults.lib_extension = "so"
   defaults.external_lib_extension = "so"
   defaults.obj_extension = "o"
   defaults.external_deps_dirs = { "/usr/local", "/usr" }
   defaults.variables.LUA_BINDIR = site_config.LUA_BINDIR or "/usr/local/bin"
   defaults.variables.LUA_INCDIR = site_config.LUA_INCDIR or "/usr/local/include"
   defaults.variables.LUA_LIBDIR = site_config.LUA_LIBDIR or "/usr/local/lib"
   defaults.variables.CFLAGS = "-O2"
   defaults.cmake_generator = "Unix Makefiles"
   defaults.platforms = { "unix" }
   defaults.variables.CC = "gcc"
   defaults.variables.LD = "gcc"
   defaults.gcc_rpath = true
   defaults.variables.LIBFLAG = "-shared"
   defaults.external_deps_patterns = {
      bin = { "?" },
      lib = { "lib?.a", "lib?.so", "lib?.so.*" },
      include = { "?.h" }
   }
   defaults.runtime_external_deps_patterns = {
      bin = { "?" },
      lib = { "lib?.so", "lib?.so.*" },
      include = { "?.h" }
   }
   defaults.export_path = "export PATH='%s'"
   defaults.export_path_separator = ":"
   defaults.export_lua_path = "export LUA_PATH='%s'"
   defaults.export_lua_cpath = "export LUA_CPATH='%s'"
   defaults.wrapper_suffix = ""
   defaults.local_cache = cfg.home.."/.cache/luarocks"
   if not defaults.variables.CFLAGS:match("-fPIC") then
      defaults.variables.CFLAGS = defaults.variables.CFLAGS.." -fPIC"
   end
   defaults.web_browser = "xdg-open"
end

if detected.cygwin then
   defaults.lib_extension = "so" -- can be overridden in the config file for mingw builds
   defaults.arch = "cygwin-"..proc
   defaults.platforms = {"unix", "cygwin"}
   defaults.cmake_generator = "Unix Makefiles"
   defaults.variables.CC = "echo -llua | xargs gcc"
   defaults.variables.LD = "echo -llua | xargs gcc"
   defaults.variables.LIBFLAG = "-shared"
end

if detected.bsd then
   defaults.variables.MAKE = "gmake"
   defaults.variables.STATFLAG = "-f '%OLp'"
end

if detected.macosx then
   defaults.variables.MAKE = "make"
   defaults.external_lib_extension = "dylib"
   defaults.arch = "macosx-"..proc
   defaults.platforms = {"unix", "bsd", "macosx"}
   defaults.variables.LIBFLAG = "-bundle -undefined dynamic_lookup -all_load"
   defaults.variables.STAT = "/usr/bin/stat"
   defaults.variables.STATFLAG = "-f '%A'"
   local version = io.popen("sw_vers -productVersion"):read("*l")
   version = tonumber(version and version:match("^[^.]+%.([^.]+)")) or 3
   if version >= 10 then
      version = 8
   elseif version >= 5 then
	  version = 5
   else
      defaults.gcc_rpath = false
   end
   defaults.variables.CC = "export MACOSX_DEPLOYMENT_TARGET=10."..version.."; gcc"
   defaults.variables.LD = "export MACOSX_DEPLOYMENT_TARGET=10."..version.."; gcc"
   defaults.web_browser = "open"
end

if detected.linux then
   defaults.arch = "linux-"..proc
   defaults.platforms = {"unix", "linux"}
end

if detected.freebsd then
   defaults.arch = "freebsd-"..proc
   defaults.platforms = {"unix", "bsd", "freebsd"}
   defaults.gcc_rpath = false
   defaults.variables.CC = "cc"
   defaults.variables.LD = "cc"
end

if detected.openbsd then
   defaults.arch = "openbsd-"..proc
   defaults.platforms = {"unix", "bsd", "openbsd"}
end

if detected.netbsd then
   defaults.arch = "netbsd-"..proc
   defaults.platforms = {"unix", "bsd", "netbsd"}
end

if detected.solaris then
   defaults.arch = "solaris-"..proc
   defaults.platforms = {"unix", "solaris"}
   defaults.variables.MAKE = "gmake"
end

-- Expose some more values detected by LuaRocks for use by rockspec authors.
defaults.variables.LIB_EXTENSION = defaults.lib_extension
defaults.variables.OBJ_EXTENSION = defaults.obj_extension
defaults.variables.LUAROCKS_PREFIX = site_config.LUAROCKS_PREFIX
defaults.variables.LUA = site_config.LUA_DIR_SET and (defaults.variables.LUA_BINDIR.."/"..defaults.lua_interpreter) or defaults.lua_interpreter

-- Add built-in modules to rocks_provided
defaults.rocks_provided["lua"] = cfg.lua_version.."-1"

if cfg.lua_version >= "5.2" then
   -- Lua 5.2+
   defaults.rocks_provided["bit32"] = cfg.lua_version.."-1"
end

if cfg.lua_version >= "5.3" then
   -- Lua 5.3+
   defaults.rocks_provided["utf8"] = cfg.lua_version.."-1"
end

if package.loaded.jit then
   -- LuaJIT
   local lj_version = package.loaded.jit.version:match("LuaJIT (.*)"):gsub("%-","")
   --defaults.rocks_provided["luajit"] = lj_version.."-1"
   defaults.rocks_provided["luabitop"] = lj_version.."-1"
end

-- Use defaults:

-- Populate some arrays with values from their 'defaults' counterparts
-- if they were not already set by user.
for _, entry in ipairs({"variables", "rocks_provided"}) do
   if not cfg[entry] then
      cfg[entry] = {}
   end
   for k,v in pairs(defaults[entry]) do
      if not cfg[entry][k] then
         cfg[entry][k] = v
      end
   end
end

-- For values not set in the config file, use values from the 'defaults' table.
local cfg_mt = {
   __index = function(t, k)
      local default = defaults[k]
      if default then
         rawset(t, k, default)
      end
      return default
   end
}
setmetatable(cfg, cfg_mt)

if not cfg.check_certificates then
   cfg.variables.CURLNOCERTFLAG = "-k"
   cfg.variables.WGETNOCERTFLAG = "--no-check-certificate"
end

function cfg.make_paths_from_tree(tree)
   local lua_path, lib_path, bin_path
   if type(tree) == "string" then
      lua_path = tree..cfg.lua_modules_path
      lib_path = tree..cfg.lib_modules_path
      bin_path = tree.."/bin"
   else
      lua_path = tree.lua_dir or tree.root..cfg.lua_modules_path
      lib_path = tree.lib_dir or tree.root..cfg.lib_modules_path
      bin_path = tree.bin_dir or tree.root.."/bin"
   end
   return lua_path, lib_path, bin_path
end

function cfg.package_paths()
   local new_path, new_cpath, new_bin = {}, {}, {}
   for _,tree in ipairs(cfg.rocks_trees) do
      local lua_path, lib_path, bin_path = cfg.make_paths_from_tree(tree)
      table.insert(new_path, lua_path.."/?.lua")
      table.insert(new_path, lua_path.."/?/init.lua")
      table.insert(new_cpath, lib_path.."/?."..cfg.lib_extension)
      table.insert(new_bin, bin_path)
   end
   if extra_luarocks_module_dir then 
     table.insert(new_path, extra_luarocks_module_dir)
   end
   return table.concat(new_path, ";"), table.concat(new_cpath, ";"), table.concat(new_bin, cfg.export_path_separator)
end

function cfg.init_package_paths()
   local lr_path, lr_cpath, lr_bin = cfg.package_paths()
   package.path = util.remove_path_dupes(package.path .. ";" .. lr_path, ";")
   package.cpath = util.remove_path_dupes(package.cpath .. ";" .. lr_cpath, ";")
end

function cfg.which_config()
   return sys_config_file, sys_config_ok, home_config_file, home_config_ok
end

cfg.user_agent = "LuaRocks/"..cfg.program_version.." "..cfg.arch

--- Check if platform was detected
-- @param query string: The platform name to check.
-- @return boolean: true if LuaRocks is currently running on queried platform.
function cfg.is_platform(query)
   assert(type(query) == "string")

   for _, platform in ipairs(cfg.platforms) do
      if platform == query then
         return true
      end
   end
end

return cfg
