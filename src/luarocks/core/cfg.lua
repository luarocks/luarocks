
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

local next, table, pairs, require, os, pcall, ipairs, package, tonumber, type, assert =
      next, table, pairs, require, os, pcall, ipairs, package, tonumber, type, assert

local util = require("luarocks.core.util")
local persist = require("luarocks.core.persist")
local sysdetect = require("luarocks.core.sysdetect")

--------------------------------------------------------------------------------

local program_version = "3.1.3"
local program_series = "3.1"
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
}

local function detect_sysconfdir()
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

local function set_confdirs(cfg, platforms, hardcoded_sysconfdir)
   local sysconfdir = os.getenv("LUAROCKS_SYSCONFDIR") or hardcoded_sysconfdir
   if platforms.windows then
      cfg.home = os.getenv("APPDATA") or "c:"
      cfg.home_tree = cfg.home.."/luarocks"
      cfg.homeconfdir = cfg.home_tree
      cfg.sysconfdir = sysconfdir or ((os.getenv("PROGRAMFILES") or "c:") .. "/luarocks")
   else
      if not sysconfdir then
         sysconfdir = detect_sysconfdir()
      end
      cfg.home = os.getenv("HOME") or ""
      cfg.home_tree = (os.getenv("USER") ~= "root") and cfg.home.."/.luarocks"
      cfg.homeconfdir = cfg.home.."/.luarocks"
      cfg.sysconfdir = sysconfdir or "/etc/luarocks"
   end
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
      check_certificates = false,

      cache_timeout = 60,
      cache_fail_timeout = 86400,
      version_check_on_fail = true,

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
           "http://luafr.org/moonrocks/",
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
      defaults.local_cache = home.."/.cache/luarocks"
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
      version = tonumber(version and version:match("^[^.]+%.([^.]+)")) or 3
      if version >= 10 then
         version = 8
      elseif version >= 5 then
         version = 5
      else
         defaults.gcc_rpath = false
      end
      defaults.variables.CC = "env MACOSX_DEPLOYMENT_TARGET=10."..version.." gcc"
      defaults.variables.LD = "env MACOSX_DEPLOYMENT_TARGET=10."..version.." gcc"
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
      defaults.variables.CC = "cc"
      defaults.variables.LD = "cc"
   end

   if platforms.openbsd then
      defaults.arch = "openbsd-"..target_cpu
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

local function make_rocks_provided(lua_version, luajit_version)
   local rocks_provided = {}
   local rocks_provided_3_0 = {}

   rocks_provided["lua"] = lua_version.."-1"

   if lua_version == "5.2" or lua_version == "5.3" then
      rocks_provided["bit32"] = lua_version.."-1"
   end

   if lua_version == "5.3" or lua_version == "5.4" then
      rocks_provided["utf8"] = lua_version.."-1"
   end

   if luajit_version then
      rocks_provided["luabitop"] = luajit_version.."-1"
      rocks_provided_3_0["luajit"] = luajit_version.."-1"
   end

   return rocks_provided, rocks_provided_3_0
end

local function use_defaults(cfg, defaults)

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
   util.deep_merge_under(defaults.rocks_provided_3_0, cfg.rocks_provided)

   util.deep_merge_under(cfg, defaults)

   -- FIXME get rid of this
   if not cfg.check_certificates then
      cfg.variables.CURLNOCERTFLAG = "-k"
      cfg.variables.WGETNOCERTFLAG = "--no-check-certificate"
   end
end

--------------------------------------------------------------------------------

local cfg = {}

--- Initializes the LuaRocks configuration for variables, paths
-- and OS detection.
-- @param detected table containing information detected about the 
-- environment. All fields below are optional:
-- * lua_version (in x.y format, e.g. "5.3")
-- * luajit_version (complete, e.g. "2.1.0-beta3")
-- * lua_bindir (e.g. "/usr/local/bin")
-- * lua_incdir (e.g. "/usr/local/include/lua5.3/")
-- * lua_libdir(e.g. "/usr/local/lib")
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

   local lua_version = detected.lua_version or hardcoded.LUA_VERSION or _VERSION:sub(5)
   local luajit_version = detected.luajit_version or hardcoded.LUAJIT_VERSION or (jit and jit.version:sub(8))
   local lua_interpreter = detected.lua_interpreter or hardcoded.LUA_INTERPRETER or (arg and arg[-1] and arg[-1]:gsub(".*[\\/]", "")) or (is_windows and "lua.exe" or "lua")
   local lua_bindir = detected.lua_bindir or hardcoded.LUA_BINDIR or (arg and arg[-1] and arg[-1]:gsub("[\\/][^\\/]+$", ""))
   local lua_incdir = detected.lua_incdir or hardcoded.LUA_INCDIR
   local lua_libdir = detected.lua_libdir or hardcoded.LUA_LIBDIR
   local lua_dir = detected.lua_dir or hardcoded.LUA_DIR or (lua_bindir and lua_bindir:gsub("[\\/]bin$", ""))
   local project_dir = detected.project_dir
   
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

   cfg.lua_version = lua_version
   cfg.luajit_version = luajit_version
   cfg.lua_interpreter = lua_interpreter

   cfg.variables = {
      LUA_DIR = lua_dir,
      LUA_BINDIR = lua_bindir,
      LUA_INCDIR = lua_incdir,
      LUA_LIBDIR = lua_libdir,
   }

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
         local fd = io.open("/bin/sh", "r")
         if fd then
            fd:close()
            system = "msys"
         else
            system = "mingw"
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
   do
      set_confdirs(cfg, platforms, hardcoded.SYSCONFDIR)
      local name = "config-"..cfg.lua_version..".lua"
      sys_config_file = (cfg.sysconfdir .. "/" .. name):gsub("\\", "/")
      home_config_file = (cfg.homeconfdir .. "/" .. name):gsub("\\", "/")
      if project_dir then
         project_config_file = project_dir .. "/.luarocks/" .. name
      end
   end

   -- Load system configuration file
   local sys_config_ok, err = load_config_file(cfg, platforms, sys_config_file)
   if err then
      return nil, err, "config"
   end

   -- Load user configuration file (if allowed)
   local home_config_ok
   local project_config_ok
   if not hardcoded.FORCE_CONFIG then
      local env_var   = "LUAROCKS_CONFIG_" .. lua_version:gsub("%.", "_")
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

      -- try the alternative defaults if there was no environment specified file or it didn't work
      if not home_config_ok then
         home_config_ok, err = load_config_file(cfg, platforms, home_config_file)
         if err then
            return nil, err, "config"
         end
      end

      -- finally, use the project-specific config file if any
      if project_dir then
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

   -- Settings detected or given via the CLI (i.e. --lua-dir) take precedence over config files:
   cfg.project_dir = detected.project_dir
   cfg.lua_version = detected.lua_version or cfg.lua_version
   cfg.luajit_version = detected.luajit_version or cfg.luajit_version
   cfg.lua_interpreter = detected.lua_interpreter or cfg.lua_interpreter
   cfg.variables.LUA_BINDIR = detected.lua_bindir or cfg.variables.LUA_BINDIR or lua_bindir
   cfg.variables.LUA_INCDIR = detected.lua_incdir or cfg.variables.LUA_INCDIR or lua_incdir
   cfg.variables.LUA_LIBDIR = detected.lua_libdir or cfg.variables.LUA_LIBDIR or lua_libdir
   cfg.variables.LUA_DIR = detected.lua_dir or cfg.variables.LUA_DIR or lua_dir

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

   local defaults = make_defaults(lua_version, processor, platforms, cfg.home)

   if platforms.windows and hardcoded.WIN_TOOLS then
      local tools = { "SEVENZ", "CP", "FIND", "LS", "MD5SUM", "PWD", "RMDIR", "WGET", "MKDIR" }
      for _, tool in ipairs(tools) do
         defaults.variables[tool] = '"' .. hardcoded.WIN_TOOLS .. "/" .. defaults.variables[tool] .. '.exe"'
      end
   else
      defaults.fs_use_modules = true
   end

   defaults.rocks_provided, defaults.rocks_provided_3_0 = make_rocks_provided(lua_version, luajit_version)
   use_defaults(cfg, defaults)

   cfg.variables.LUA = cfg.variables.LUA or (cfg.variables.LUA_BINDIR and (cfg.variables.LUA_BINDIR .. "/" .. cfg.lua_interpreter):gsub("//", "/"))
   cfg.user_agent = "LuaRocks/"..cfg.program_version.." "..cfg.arch

   cfg.config_files = {
      project = project_dir and {
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
      package.path = util.cleanup_path(package.path .. ";" .. lr_path, ";", lua_version)
      package.cpath = util.cleanup_path(package.cpath .. ";" .. lr_cpath, ";", lua_version)
   end

   --- Check if platform was detected
   -- @param name string: The platform name to check.
   -- @return boolean: true if LuaRocks is currently running on queried platform.
   function cfg.is_platform(name)
      assert(type(name) == "string")
      return platforms[name]
   end

   function cfg.each_platform()
      local i = 0
      return function()
         local p
         repeat
            i = i + 1
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
