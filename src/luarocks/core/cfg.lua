
--- Configuration for LuaRocks.
-- Tries to load the user's configuration file and
-- defines defaults for unset values. See the
-- <a href="http://luarocks.org/en/Config_file_format">config
-- file format documentation</a> for details.
--
-- End-users shouldn't edit this file. They can override any defaults
-- set in this file using their system-wide or user-specific configuration
-- files. Run `luarocks` with no arguments to see the locations of
-- these files in your platform.

local table, pairs, require, os, pcall, ipairs, package, type, assert =
      table, pairs, require, os, pcall, ipairs, package, type, assert

local util = require("luarocks.core.util")
local persist = require("luarocks.core.persist")
local sysdetect = require("luarocks.core.sysdetect")
local vers = require("luarocks.core.vers")

--------------------------------------------------------------------------------

local program_version = "dev"
local program_series = "3.0"
local major_version = (program_version:match("([^.]%.[^.])")) or program_series

local is_windows = package.config:sub(1,1) == "\\"

-- Set order for platform overrides.
-- More general platform identifiers should be listed first,
-- more specific ones later.
local platform_order = {
   -- Unixes
   "unix",
   "bsd",
   "solaris",
   "netbsd",
   "openbsd",
   "freebsd",
   "linux",
   "macosx",
   "cygwin",
   "msys",
   "haiku",
   -- Windows
   "windows",
   "win32",
   "mingw32",
   "msys2_mingw_w64",
}

local function detect_sysconfdir()
   if not debug then
      return
   end
   local src = debug.getinfo(1, "S").source:gsub("\\", "/"):gsub("/+", "/")
   if src:sub(1, 1) == "@" then
      src = src:sub(2)
   end
   local basedir = src:match("^(.*)/luarocks/core/cfg.lua$")
   if not basedir then
      return
   end
   -- If installed in a Unix-like tree, use a Unix-like sysconfdir
   local installdir = basedir:match("^(.*)/share/lua/[^/]*$")
   if installdir then
      if installdir == "/usr" then
         return "/etc/luarocks"
      end
      return installdir .. "/etc/luarocks"
   end
   -- Otherwise, use base directory of sources
   return basedir
end

local load_config_file
do
   -- Create global environment for the config files;
   local function env_for_config_file(cfg, platforms)
      local e
      e = {
         home = cfg.home,
         lua_version = cfg.lua_version,
         platforms = util.make_shallow_copy(platforms),
         processor = cfg.target_cpu,   -- remains for compat reasons
         target_cpu = cfg.target_cpu,  -- replaces `processor`
         os_getenv = os.getenv,
         variables = cfg.variables or {},
         dump_env = function()
            -- debug function, calling it from a config file will show all
            -- available globals to that config file
            print(util.show_table(e, "global environment"))
         end,
      }
      return e
   end

   -- Merge values from config files read into the `cfg` table
   local function merge_overrides(cfg, overrides)
      -- remove some stuff we do not want to integrate
      overrides.os_getenv = nil
      overrides.dump_env = nil
      -- remove tables to be copied verbatim instead of deeply merged
      if overrides.rocks_trees   then cfg.rocks_trees   = nil end
      if overrides.rocks_servers then cfg.rocks_servers = nil end
      -- perform actual merge
      util.deep_merge(cfg, overrides)
   end

   local function update_platforms(platforms, overrides)
      if overrides[1] then
         for k, _ in pairs(platforms) do
            platforms[k] = nil
         end
         for _, v in ipairs(overrides) do
            platforms[v] = true
         end
         -- set some fallback default in case the user provides an incomplete configuration.
         -- LuaRocks expects a set of defaults to be available.
         if not (platforms.unix or platforms.windows) then
            platforms[is_windows and "windows" or "unix"] = true
         end
      end
   end

   -- Load config file and merge its contents into the `cfg` module table.
   -- @return filepath of successfully loaded file or nil if it failed
   load_config_file = function(cfg, platforms, filepath)
      local result, err, errcode = persist.load_into_table(filepath, env_for_config_file(cfg, platforms))
      if (not result) and errcode ~= "open" then
         -- errcode is either "load" or "run"; bad config file, so error out
         return nil, err, "config"
      end
      if result then
         -- success in loading and running, merge contents and exit
         update_platforms(platforms, result.platforms)
         result.platforms = nil
         merge_overrides(cfg, result)
         return filepath
      end
      return nil -- nothing was loaded
   end
end

local platform_sets = {
   freebsd = { unix = true, bsd = true, freebsd = true },
   openbsd = { unix = true, bsd = true, openbsd = true },
   solaris = { unix = true, solaris = true },
   windows = { windows = true, win32 = true },
   cygwin = { unix = true, cygwin = true },
   macosx = { unix = true, bsd = true, macosx = true, macos = true },
   netbsd = { unix = true, bsd = true, netbsd = true },
   haiku = { unix = true, haiku = true },
   linux = { unix = true, linux = true },
   mingw = { windows = true, win32 = true, mingw32 = true, mingw = true },
   msys = { unix = true, cygwin = true, msys = true },
   msys2_mingw_w64 = { windows = true, win32 = true, mingw32 = true, mingw = true, msys = true, msys2_mingw_w64 = true },
}

local function make_platforms(system)
   -- fallback to Unix in unknown systems
   return platform_sets[system] or { unix = true }
end

--------------------------------------------------------------------------------

local function make_defaults(lua_version, target_cpu, platforms, home)

   -- Configure defaults:
   local defaults = {

      lua_interpreter = "lua",
      local_by_default = false,
      accept_unknown_fields = false,
      fs_use_modules = true,
      hooks_enabled = true,
      deps_mode = "one",
      no_manifest = false,
      check_certificates = false,

      cache_timeout = 60,
      cache_fail_timeout = 86400,

      lua_modules_path = "/share/lua/"..lua_version,
      lib_modules_path = "/lib/lua/"..lua_version,
      rocks_subdir = "/lib/luarocks/rocks-"..lua_version,

      arch = "unknown",
      lib_extension = "unknown",
      obj_extension = "unknown",
      link_lua_explicitly = false,

      rocks_servers = {
         {
           "https://luarocks.org",
           "https://raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/master/",
           "https://luafr.org/luarocks/",
           "http://luarocks.logiceditor.com/rocks",
         }
      },
      disabled_servers = {},

      upload = {
         server = "https://luarocks.org",
         tool_version = "1.0.0",
         api_version = "1",
      },

      lua_extension = "lua",
      connection_timeout = 30,  -- 0 = no timeout

      variables = {
         MAKE = "make",
         CC = "cc",
         LD = "ld",
         AR = "ar",
         RANLIB = "ranlib",

         CVS = "cvs",
         GIT = "git",
         SSCM = "sscm",
         SVN = "svn",
         HG = "hg",

         GPG = "gpg",

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
         CHMOD = "chmod",
         ICACLS = "icacls",
         MKTEMP = "mktemp",

         ZIP = "zip",
         UNZIP = "unzip -n",
         GUNZIP = "gunzip",
         BUNZIP2 = "bunzip2",
         TAR = "tar",

         MD5SUM = "md5sum",
         OPENSSL = "openssl",
         MD5 = "md5",
         TOUCH = "touch",

         CMAKE = "cmake",
         SEVENZ = "7z",

         RSYNCFLAGS = "--exclude=.git -Oavz",
         CURLNOCERTFLAG = "",
         WGETNOCERTFLAG = "",
      },

      external_deps_subdirs = {
         bin = "bin",
         lib = "lib",
         include = "include"
      },
      runtime_external_deps_subdirs = {
         bin = "bin",
         lib = "lib",
         include = "include"
      },
   }

   if platforms.windows then

      defaults.arch = "win32-"..target_cpu
      defaults.lib_extension = "dll"
      defaults.external_lib_extension = "dll"
      defaults.static_lib_extension = "lib"
      defaults.obj_extension = "obj"
      defaults.external_deps_dirs = { "c:/external/", "c:/windows/system32" }

      defaults.makefile = "Makefile.win"
      defaults.variables.MAKE = "nmake"
      defaults.variables.CC = "cl"
      defaults.variables.RC = "rc"
      defaults.variables.LD = "link"
      defaults.variables.MT = "mt"
      defaults.variables.AR = "lib"
      defaults.variables.LUALIB = "lua"..lua_version..".lib"
      defaults.variables.CFLAGS = "/nologo /MD /O2"
      defaults.variables.LIBFLAG = "/nologo /dll"

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
      defaults.export_path_separator = ";"
      defaults.wrapper_suffix = ".bat"

      local localappdata = os.getenv("LOCALAPPDATA")
      if not localappdata then
         -- for Windows versions below Vista
         localappdata = (os.getenv("USERPROFILE") or "c:/Users/All Users").."/Local Settings/Application Data"
      end
      defaults.local_cache = localappdata.."/LuaRocks/Cache"
      defaults.web_browser = "start"

      defaults.external_deps_subdirs.lib = { "", "lib", "bin" }
      defaults.runtime_external_deps_subdirs.lib = { "", "lib", "bin" }
      defaults.link_lua_explicitly = true
      defaults.fs_use_modules = false
   end

   if platforms.mingw32 then
      defaults.obj_extension = "o"
      defaults.static_lib_extension = "a"
      defaults.external_deps_dirs = { "c:/external/", "c:/mingw", "c:/windows/system32" }
      defaults.cmake_generator = "MinGW Makefiles"
      defaults.variables.MAKE = "mingw32-make"
      defaults.variables.CC = "mingw32-gcc"
      defaults.variables.RC = "windres"
      defaults.variables.LD = "mingw32-gcc"
      defaults.variables.AR = "ar"
      defaults.variables.RANLIB = "ranlib"
      defaults.variables.CFLAGS = "-O2"
      defaults.variables.LIBFLAG = "-shared"
      defaults.makefile = "Makefile"
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
      defaults.link_lua_explicitly = true
   end

   if platforms.unix then
      defaults.lib_extension = "so"
      defaults.static_lib_extension = "a"
      defaults.external_lib_extension = "so"
      defaults.obj_extension = "o"
      defaults.external_deps_dirs = { "/usr/local", "/usr", "/" }
      defaults.variables.CFLAGS = "-O2"
      defaults.cmake_generator = "Unix Makefiles"
      defaults.variables.CC = "gcc"
      defaults.variables.LD = "gcc"
      defaults.gcc_rpath = true
      defaults.variables.LIBFLAG = "-shared"
      defaults.variables.TEST = "test"

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
      defaults.export_path_separator = ":"
      defaults.wrapper_suffix = ""
      local xdg_cache_home = os.getenv("XDG_CACHE_HOME") or home.."/.cache"
      defaults.local_cache = xdg_cache_home.."/luarocks"
      if not defaults.variables.CFLAGS:match("-fPIC") then
         defaults.variables.CFLAGS = defaults.variables.CFLAGS.." -fPIC"
      end
      defaults.web_browser = "xdg-open"
   end

   if platforms.cygwin then
      defaults.lib_extension = "so" -- can be overridden in the config file for mingw builds
      defaults.arch = "cygwin-"..target_cpu
      defaults.cmake_generator = "Unix Makefiles"
      defaults.variables.CC = "echo -llua | xargs gcc"
      defaults.variables.LD = "echo -llua | xargs gcc"
      defaults.variables.LIBFLAG = "-shared"
      defaults.link_lua_explicitly = true
   end

   if platforms.msys then
      -- msys is basically cygwin made out of mingw, meaning the subsytem is unixish
      -- enough, yet we can freely mix with native win32
      defaults.external_deps_patterns = {
         bin = { "?.exe", "?.bat", "?" },
         lib = { "lib?.so", "lib?.so.*", "lib?.dll.a", "?.dll.a",
                 "lib?.a", "lib?.dll", "?.dll", "?.lib" },
         include = { "?.h" }
      }
      defaults.runtime_external_deps_patterns = {
         bin = { "?.exe", "?.bat" },
         lib = { "lib?.so", "?.dll", "lib?.dll" },
         include = { "?.h" }
      }
      if platforms.mingw then
         -- MSYS2 can build Windows programs that depend on
         -- msys-2.0.dll (based on Cygwin) but MSYS2 is also designed
         -- for building native Windows programs by MinGW. These
         -- programs don't depend on msys-2.0.dll.
         local pipe = io.popen("cygpath --windows %MINGW_PREFIX%")
         local mingw_prefix = pipe:read("*l")
         pipe:close()
         defaults.external_deps_dirs = { mingw_prefix, "c:/windows/system32" }
         defaults.makefile = "Makefile"
         defaults.cmake_generator = "MSYS Makefiles"
         defaults.local_cache = home.."/.cache/luarocks"
         defaults.variables.MAKE = "make"
         defaults.variables.CC = "gcc"
         defaults.variables.RC = "windres"
         defaults.variables.LD = "gcc"
         defaults.variables.MT = nil
         defaults.variables.AR = "ar"
         defaults.variables.RANLIB = "ranlib"
         defaults.variables.LUALIB = "liblua"..lua_version..".dll.a"
         defaults.variables.CFLAGS = "-O2 -fPIC"
         defaults.variables.LIBFLAG = "-shared"
      end
   end

   if platforms.bsd then
      defaults.variables.MAKE = "gmake"
   end

   if platforms.macosx then
      defaults.variables.MAKE = "make"
      defaults.external_lib_extension = "dylib"
      defaults.arch = "macosx-"..target_cpu
      defaults.variables.LIBFLAG = "-bundle -undefined dynamic_lookup -all_load"
      local version = util.popen_read("sw_vers -productVersion")
      if not (version:match("^%d+%.%d+%.%d+$") or version:match("^%d+%.%d+$")) then
         version = "10.3"
      end
      version = vers.parse_version(version)
      if version >= vers.parse_version("10.10") then
         version = vers.parse_version("10.8")
      elseif version >= vers.parse_version("10.5") then
         version = vers.parse_version("10.5")
      else
         defaults.gcc_rpath = false
      end
      defaults.variables.CC = "env MACOSX_DEPLOYMENT_TARGET="..tostring(version).." gcc"
      defaults.variables.LD = "env MACOSX_DEPLOYMENT_TARGET="..tostring(version).." gcc"
      defaults.web_browser = "open"
   end

   if platforms.linux then
      defaults.arch = "linux-"..target_cpu

      local gcc_arch = util.popen_read("gcc -print-multiarch 2>/dev/null")
      if gcc_arch and gcc_arch ~= "" then
         defaults.external_deps_subdirs.lib = { "lib", "lib/" .. gcc_arch, "lib64" }
         defaults.runtime_external_deps_subdirs.lib = { "lib", "lib/" .. gcc_arch, "lib64" }
      else
         defaults.external_deps_subdirs.lib = { "lib", "lib64" }
         defaults.runtime_external_deps_subdirs.lib = { "lib", "lib64" }
      end
   end

   if platforms.freebsd then
      defaults.arch = "freebsd-"..target_cpu
      defaults.gcc_rpath = false
      defaults.variables.CC = os.getenv("CC") or "cc"
      defaults.variables.CFLAGS = os.getenv("CFLAGS") or defaults.variables.CFLAGS
      defaults.variables.LD = defaults.variables.CC
      defaults.variables.LIBFLAG = (os.getenv("LDFLAGS") or "").." -shared"
   end

   if platforms.openbsd then
      defaults.arch = "openbsd-"..target_cpu
      defaults.gcc_rpath = false
      defaults.variables.CC = os.getenv("CC") or "cc"
      defaults.variables.CFLAGS = os.getenv("CFLAGS") or defaults.variables.CFLAGS
      defaults.variables.LD = defaults.variables.CC
      defaults.variables.LIBFLAG = (os.getenv("LDFLAGS") or "").." -shared"
   end

   if platforms.netbsd then
      defaults.arch = "netbsd-"..target_cpu
   end

   if platforms.solaris then
      defaults.arch = "solaris-"..target_cpu
      --defaults.platforms = {"unix", "solaris"}
      defaults.variables.MAKE = "gmake"
   end

   -- Expose some more values detected by LuaRocks for use by rockspec authors.
   defaults.variables.LIB_EXTENSION = defaults.lib_extension
   defaults.variables.OBJ_EXTENSION = defaults.obj_extension

   return defaults
end

local function use_defaults(cfg, defaults)

   -- Populate variables with values from their 'defaults' counterparts
   -- if they were not already set by user.
   if not cfg.variables then
      cfg.variables = {}
   end
   for k,v in pairs(defaults.variables) do
      if not cfg.variables[k] then
         cfg.variables[k] = v
      end
   end

   util.deep_merge_under(cfg, defaults)

   -- FIXME get rid of this
   if not cfg.check_certificates then
      cfg.variables.CURLNOCERTFLAG = "-k"
      cfg.variables.WGETNOCERTFLAG = "--no-check-certificate"
   end
end

local function get_first_arg()
   if not arg then
      return
   end
   local first_arg = arg[0]
   local i = -1
   while arg[i] do
      first_arg = arg[i]
      i = i -1
   end
   return first_arg
end

--------------------------------------------------------------------------------

local cfg = {}

--- Initializes the LuaRocks configuration for variables, paths
-- and OS detection.
-- @param detected table containing information detected about the
-- environment. All fields below are optional:
-- * lua_version (in x.y format, e.g. "5.3")
-- * lua_bindir (e.g. "/usr/local/bin")
-- * lua_dir (e.g. "/usr/local")
-- * lua_interpreter (e.g. "lua-5.3")
-- * project_dir (a string with the path of the project directory
--   when using per-project environments, as created with `luarocks init`)
-- @param warning a logging function for warnings that takes a string
-- @return true on success; nil and an error message on failure.
function cfg.init(detected, warning)
   detected = detected or {}

   local hc_ok, hardcoded = pcall(require, "luarocks.core.hardcoded")
   if not hc_ok then
      hardcoded = {}
   end

   local init = cfg.init

   ----------------------------------------
   -- Reset the cfg table.
   ----------------------------------------

   for k, _ in pairs(cfg) do
      cfg[k] = nil
   end

   cfg.program_version = program_version
   cfg.program_series = program_series
   cfg.major_version = major_version

   if hardcoded.IS_BINARY then
      cfg.is_binary = true
   end

   -- Use detected values as defaults, overridable via config files or CLI args

   local first_arg = get_first_arg()

   cfg.lua_version = detected.lua_version or hardcoded.LUA_VERSION or _VERSION:sub(5)
   cfg.lua_interpreter = detected.lua_interpreter or hardcoded.LUA_INTERPRETER or (first_arg and first_arg:gsub(".*[\\/]", "")) or (is_windows and "lua.exe" or "lua")
   cfg.project_dir = (not hardcoded.FORCE_CONFIG) and detected.project_dir

   do
      local lua_bindir = detected.lua_bindir or hardcoded.LUA_BINDIR or (first_arg and first_arg:gsub("[\\/][^\\/]+$", ""))
      local lua_dir = detected.lua_dir or hardcoded.LUA_DIR or (lua_bindir and lua_bindir:gsub("[\\/]bin$", ""))
      cfg.variables = {
         LUA_DIR = lua_dir,
         LUA_BINDIR = lua_bindir,
         LUA_LIBDIR = hardcoded.LUA_LIBDIR,
         LUA_INCDIR = hardcoded.LUA_INCDIR,
      }
   end

   cfg.init = init

   ----------------------------------------
   -- System detection.
   ----------------------------------------

   -- A proper build of LuaRocks will hardcode the system
   -- and proc values with hardcoded.SYSTEM and hardcoded.PROCESSOR.
   -- If that is not available, we try to identify the system.
   local system, processor = sysdetect.detect()
   if hardcoded.SYSTEM then
      system = hardcoded.SYSTEM
   end
   if hardcoded.PROCESSOR then
      processor = hardcoded.PROCESSOR
   end

   if system == "windows" then
      if os.getenv("VCINSTALLDIR") then
         -- running from the Development Command prompt for VS 2017
         system = "windows"
      else
         local msystem = os.getenv("MSYSTEM")
         if msystem == nil then
            system = "mingw"
         elseif msystem == "MSYS" then
            system = "msys"
         else
            -- MINGW32 or MINGW64
            system = "msys2_mingw_w64"
         end
      end
   end

   cfg.target_cpu = processor

   local platforms = make_platforms(system)

   ----------------------------------------
   -- Platform is determined.
   -- Let's load the config files.
   ----------------------------------------

   local sys_config_file
   local home_config_file
   local project_config_file

   local config_file_name = "config-"..cfg.lua_version..".lua"

   do
      local sysconfdir = os.getenv("LUAROCKS_SYSCONFDIR") or hardcoded.SYSCONFDIR
      if platforms.windows and not platforms.msys2_mingw_w64 then
         cfg.home = os.getenv("APPDATA") or "c:"
         cfg.home_tree = cfg.home.."/luarocks"
         cfg.sysconfdir = sysconfdir or ((os.getenv("PROGRAMFILES") or "c:") .. "/luarocks")
      else
         cfg.home = os.getenv("HOME") or ""
         cfg.home_tree = cfg.home.."/.luarocks"
         cfg.sysconfdir = sysconfdir or detect_sysconfdir() or "/etc/luarocks"
      end
   end

   -- Load system configuration file
   sys_config_file = (cfg.sysconfdir .. "/" .. config_file_name):gsub("\\", "/")
   local sys_config_ok, err = load_config_file(cfg, platforms, sys_config_file)
   if err then
      return nil, err, "config"
   end

   -- Load user configuration file (if allowed)
   local home_config_ok
   local project_config_ok
   if not hardcoded.FORCE_CONFIG then
      local env_var   = "LUAROCKS_CONFIG_" .. cfg.lua_version:gsub("%.", "_")
      local env_value = os.getenv(env_var)
      if not env_value then
         env_var   = "LUAROCKS_CONFIG"
         env_value = os.getenv(env_var)
      end
      -- first try environment provided file, so we can explicitly warn when it is missing
      if env_value then
         local env_ok, err = load_config_file(cfg, platforms, env_value)
         if err then
            return nil, err, "config"
         elseif warning and not env_ok then
            warning("Warning: could not load configuration file `"..env_value.."` given in environment variable "..env_var.."\n")
         end
         if env_ok then
            home_config_ok = true
            home_config_file = env_value
         end
      end

      -- try XDG config home
      if platforms.unix and not home_config_ok then
         local xdg_config_home = os.getenv("XDG_CONFIG_HOME") or cfg.home .. "/.config"
         cfg.homeconfdir = xdg_config_home .. "/luarocks"
         home_config_file = (cfg.homeconfdir .. "/" .. config_file_name):gsub("\\", "/")
         home_config_ok, err = load_config_file(cfg, platforms, home_config_file)
         if err then
            return nil, err, "config"
         end
      end

      -- try the alternative defaults if there was no environment specified file or it didn't work
      if not home_config_ok then
         cfg.homeconfdir = cfg.home_tree
         home_config_file = (cfg.homeconfdir .. "/" .. config_file_name):gsub("\\", "/")
         home_config_ok, err = load_config_file(cfg, platforms, home_config_file)
         if err then
            return nil, err, "config"
         end
      end

      -- finally, use the project-specific config file if any
      if cfg.project_dir then
         project_config_file = cfg.project_dir .. "/.luarocks/" .. config_file_name
         project_config_ok, err = load_config_file(cfg, platforms, project_config_file)
         if err then
            return nil, err, "config"
         end
      end
   end

   ----------------------------------------
   -- Config files are loaded.
   -- Let's finish up the cfg table.
   ----------------------------------------

   -- Settings given via the CLI (i.e. --lua-dir) take precedence over config files.
   cfg.project_dir = detected.given_project_dir or cfg.project_dir
   cfg.lua_version = detected.given_lua_version or cfg.lua_version
   if detected.given_lua_dir then
      cfg.variables.LUA_DIR = detected.given_lua_dir
      cfg.variables.LUA_BINDIR = detected.lua_bindir
      cfg.variables.LUA_LIBDIR = nil
      cfg.variables.LUA_INCDIR = nil
      cfg.lua_interpreter = detected.lua_interpreter
   end

   -- Build a default list of rocks trees if not given
   if cfg.rocks_trees == nil then
      cfg.rocks_trees = {}
      if cfg.home_tree then
         table.insert(cfg.rocks_trees, { name = "user", root = cfg.home_tree } )
      end
      if hardcoded.PREFIX and hardcoded.PREFIX ~= cfg.home_tree then
         table.insert(cfg.rocks_trees, { name = "system", root = hardcoded.PREFIX } )
      end
   end

   local defaults = make_defaults(cfg.lua_version, processor, platforms, cfg.home)

   if platforms.windows and hardcoded.WIN_TOOLS then
      local tools = { "SEVENZ", "CP", "FIND", "LS", "MD5SUM", "PWD", "RMDIR", "WGET", "MKDIR" }
      for _, tool in ipairs(tools) do
         defaults.variables[tool] = '"' .. hardcoded.WIN_TOOLS .. "/" .. defaults.variables[tool] .. '.exe"'
      end
   else
      defaults.fs_use_modules = true
   end

   use_defaults(cfg, defaults)

   cfg.variables.LUA = cfg.variables.LUA or (cfg.variables.LUA_BINDIR and (cfg.variables.LUA_BINDIR .. "/" .. cfg.lua_interpreter):gsub("//", "/"))
   cfg.user_agent = "LuaRocks/"..cfg.program_version.." "..cfg.arch

   cfg.config_files = {
      project = cfg.project_dir and {
         file = project_config_file,
         found = not not project_config_ok,
      },
      system = {
         file = sys_config_file,
         found = not not sys_config_ok,
      },
      user = {
         file = home_config_file,
         found = not not home_config_ok,
      },
      nearest = project_config_ok
                and project_config_file
                or (home_config_ok
                    and home_config_file
                    or sys_config_file),
   }

   cfg.cache = {}

   ----------------------------------------
   -- Attributes of cfg are set.
   -- Let's add some methods.
   ----------------------------------------

   do
      local function make_paths_from_tree(tree)
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

      function cfg.package_paths(current)
         local new_path, new_cpath, new_bin = {}, {}, {}
         local function add_tree_to_paths(tree)
            local lua_path, lib_path, bin_path = make_paths_from_tree(tree)
            table.insert(new_path, lua_path.."/?.lua")
            table.insert(new_path, lua_path.."/?/init.lua")
            table.insert(new_cpath, lib_path.."/?."..cfg.lib_extension)
            table.insert(new_bin, bin_path)
         end
         if current then
            add_tree_to_paths(current)
         end
         for _,tree in ipairs(cfg.rocks_trees) do
            add_tree_to_paths(tree)
         end
         return table.concat(new_path, ";"), table.concat(new_cpath, ";"), table.concat(new_bin, cfg.export_path_separator)
      end
   end

   function cfg.init_package_paths()
      local lr_path, lr_cpath, lr_bin = cfg.package_paths()
      package.path = util.cleanup_path(package.path .. ";" .. lr_path, ";", cfg.lua_version, true)
      package.cpath = util.cleanup_path(package.cpath .. ";" .. lr_cpath, ";", cfg.lua_version, true)
   end

   --- Check if platform was detected
   -- @param name string: The platform name to check.
   -- @return boolean: true if LuaRocks is currently running on queried platform.
   function cfg.is_platform(name)
      assert(type(name) == "string")
      return platforms[name]
   end

   -- @param direction (optional) "least-specific-first" (default) or "most-specific-first"
   function cfg.each_platform(direction)
      direction = direction or "least-specific-first"
      local i, delta
      if direction == "least-specific-first" then
         i = 0
         delta = 1
      else
         i = #platform_order + 1
         delta = -1
      end
      return function()
         local p
         repeat
            i = i + delta
            p = platform_order[i]
         until (not p) or platforms[p]
         return p
      end
   end

   function cfg.print_platforms()
      local platform_keys = {}
      for k,_ in pairs(platforms) do
         table.insert(platform_keys, k)
      end
      table.sort(platform_keys)
      return table.concat(platform_keys, ", ")
   end

   return true
end

return cfg
