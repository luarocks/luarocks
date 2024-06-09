local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table











local table, pairs, require, os, pcall, ipairs, package, type, assert = 
table, pairs, require, os, pcall, ipairs, package, type, assert

local dir = require("luarocks.core.dir")
local util = require("luarocks.core.util")
local persist = require("luarocks.core.persist")
local sysdetect = require("luarocks.core.sysdetect")
local vers = require("luarocks.core.vers")

local cfg = {}





local program_version = "dev"

local is_windows = package.config:sub(1, 1) == "\\"




local platform_order = {

   "unix",
   "bsd",
   "solaris",
   "netbsd",
   "openbsd",
   "freebsd",
   "dragonfly",
   "linux",
   "macosx",
   "cygwin",
   "msys",
   "haiku",

   "windows",
   "win32",
   "mingw",
   "mingw32",
   "msys2_mingw_w64",
}












local function detect_sysconfdir()
   if not debug then
      return
   end
   local src = debug.getinfo(1, "S").source
   if not src then
      return
   end
   src = dir.normalize(src)
   if src:sub(1, 1) == "@" then
      src = src:sub(2)
   end
   local basedir = src:match("^(.*)[\\/]luarocks[\\/]core[\\/]cfg.lua$")
   if not basedir then
      return
   end

   local installdir = basedir:match("^(.*)[\\/]share[\\/]lua[\\/][^/]*$")
   if installdir then
      if installdir == "/usr" then
         return "/etc/luarocks"
      end
      return dir.path(installdir, "etc", "luarocks")
   end

   return basedir
end


do

   local function env_for_config_file(cfg, platforms)
      local platforms_copy = {}
      for k, v in pairs(platforms) do
         platforms_copy[k] = v
      end

      local e
      e = {
         home = cfg.home,
         lua_version = cfg.lua_version,
         platforms = platforms_copy,
         processor = cfg.target_cpu,
         target_cpu = cfg.target_cpu,
         os_getenv = os.getenv,
         variables = cfg.variables or {},
         dump_env = function()


            print(util.show_table(e, "global environment"))
         end,
      }
      return e
   end


   local function merge_overrides(cfg, overrides)

      overrides.os_getenv = nil
      overrides.dump_env = nil

      if overrides.rocks_trees then cfg.rocks_trees = nil end
      if overrides.rocks_servers then cfg.rocks_servers = nil end

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


         if not (platforms.unix or platforms.windows) then
            platforms[is_windows and "windows" or "unix"] = true
         end
      end
   end



   local load_config_file = function(cfg, platforms, filepath)
      local result, err, errcode = persist.load_into_table(filepath, env_for_config_file(cfg, platforms))
      if (not result) and errcode ~= "open" then

         return nil, err, "config"
      end
      if result then

         update_platforms(platforms, result.platforms)
         result.platforms = nil
         merge_overrides(cfg, result)
         return filepath
      end
      return nil
   end
end

local platform_sets = {
   freebsd = { unix = true, bsd = true, freebsd = true },
   openbsd = { unix = true, bsd = true, openbsd = true },
   dragonfly = { unix = true, bsd = true, dragonfly = true },
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

   return platform_sets[system] or { unix = true }
end



local function make_defaults(lua_version, target_cpu, platforms, home)


   local defaults = {

      local_by_default = false,
      accept_unknown_fields = false,
      fs_use_modules = true,
      hooks_enabled = true,
      deps_mode = "one",
      no_manifest = false,
      check_certificates = false,

      cache_timeout = 60,
      cache_fail_timeout = 86400,

      lua_modules_path = dir.path("share", "lua", lua_version),
      lib_modules_path = dir.path("lib", "lua", lua_version),
      rocks_subdir = dir.path("lib", "luarocks", "rocks-" .. lua_version),

      arch = "unknown",
      lib_extension = "unknown",
      external_lib_extension = "unknown",
      static_lib_extension = "unknown",
      obj_extension = "unknown",
      link_lua_explicitly = false,

      external_deps_dirs = {},
      external_deps_patterns = {},
      runtime_external_deps_patterns = {},

      export_path_separator = "",
      wrapper_suffix = "",


      rocks_servers = {
         {
            "https://luarocks.org",
            "https://raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/master/",
            "https://loadk.com/luarocks/",
         },
      },
      disabled_servers = {},

      upload = {
         server = "https://luarocks.org",
         tool_version = "1.0.0",
         api_version = "1",
      },

      lua_extension = "lua",
      connection_timeout = 30,

      makefile = "",
      local_cache = "",
      web_browser = "",
      cmake_generator = "",
      gcc_rpath = false,

      variables = {
         MAKE = os.getenv("MAKE") or "make",
         CC = os.getenv("CC") or "cc",
         LD = os.getenv("CC") or "ld",
         AR = os.getenv("AR") or "ar",
         RANLIB = os.getenv("RANLIB") or "ranlib",

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
         LN = "ln",
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

         RC = "",
         MT = "",
         CFLAGS = "",
         LDFLAGS = "",
         LIBFLAG = "",
         TEST = "",
      },

      external_deps_subdirs = {
         bin = "bin",
         lib = "lib",
         include = "include",
      },
      runtime_external_deps_subdirs = {
         bin = "bin",
         lib = "lib",
         include = "include",
      },
   }

   if platforms.windows then

      defaults.arch = "win32-" .. target_cpu
      defaults.lib_extension = "dll"
      defaults.external_lib_extension = "dll"
      defaults.static_lib_extension = "lib"
      defaults.obj_extension = "obj"
      defaults.external_deps_dirs = {
         dir.path("c:", "external"),
         dir.path("c:", "windows", "system32"),
      }

      defaults.makefile = "Makefile.win"
      defaults.variables.PWD = "echo %cd%"
      defaults.variables.MKDIR = "md"
      defaults.variables.MAKE = os.getenv("MAKE") or "nmake"
      defaults.variables.CC = os.getenv("CC") or "cl"
      defaults.variables.RC = os.getenv("WINDRES") or "rc"
      defaults.variables.LD = os.getenv("LINK") or "link"
      defaults.variables.MT = os.getenv("MT") or "mt"
      defaults.variables.AR = os.getenv("AR") or "lib"
      defaults.variables.CFLAGS = os.getenv("CFLAGS") or "/nologo /MD /O2"
      defaults.variables.LDFLAGS = os.getenv("LDFLAGS")
      defaults.variables.LIBFLAG = "/nologo /dll"

      defaults.external_deps_patterns = {
         bin = { "?.exe", "?.bat" },
         lib = { "?.lib", "lib?.lib", "?.dll", "lib?.dll" },
         include = { "?.h" },
      }
      defaults.runtime_external_deps_patterns = {
         bin = { "?.exe", "?.bat" },
         lib = { "?.dll", "lib?.dll" },
         include = { "?.h" },
      }
      defaults.export_path_separator = ";"
      defaults.wrapper_suffix = ".bat"

      local localappdata = os.getenv("LOCALAPPDATA")
      if not localappdata then

         localappdata = dir.path((os.getenv("USERPROFILE") or dir.path("c:", "Users", "All Users")), "Local Settings", "Application Data")
      end
      defaults.local_cache = dir.path(localappdata, "LuaRocks", "Cache")
      defaults.web_browser = "start"

      defaults.external_deps_subdirs.lib = { "lib", "", "bin" }
      defaults.runtime_external_deps_subdirs.lib = { "lib", "", "bin" }
      defaults.link_lua_explicitly = true
      defaults.fs_use_modules = false
   end

   if platforms.mingw32 then
      defaults.obj_extension = "o"
      defaults.static_lib_extension = "a"
      defaults.external_deps_dirs = {
         dir.path("c:", "external"),
         dir.path("c:", "mingw"),
         dir.path("c:", "windows", "system32"),
      }
      defaults.cmake_generator = "MinGW Makefiles"
      defaults.variables.MAKE = os.getenv("MAKE") or "mingw32-make"
      if target_cpu == "x86_64" then
         defaults.variables.CC = os.getenv("CC") or "x86_64-w64-mingw32-gcc"
         defaults.variables.LD = os.getenv("CC") or "x86_64-w64-mingw32-gcc"
      else
         defaults.variables.CC = os.getenv("CC") or "mingw32-gcc"
         defaults.variables.LD = os.getenv("CC") or "mingw32-gcc"
      end
      defaults.variables.AR = os.getenv("AR") or "ar"
      defaults.variables.RC = os.getenv("WINDRES") or "windres"
      defaults.variables.RANLIB = os.getenv("RANLIB") or "ranlib"
      defaults.variables.CFLAGS = os.getenv("CFLAGS") or "-O2"
      defaults.variables.LDFLAGS = os.getenv("LDFLAGS")
      defaults.variables.LIBFLAG = "-shared"
      defaults.makefile = "Makefile"
      defaults.external_deps_patterns = {
         bin = { "?.exe", "?.bat" },


         lib = { "lib?.dll.a", "?.dll.a", "lib?.a", "cyg?.dll", "lib?.dll", "?.dll", "?.lib" },
         include = { "?.h" },
      }
      defaults.runtime_external_deps_patterns = {
         bin = { "?.exe", "?.bat" },
         lib = { "cyg?.dll", "?.dll", "lib?.dll" },
         include = { "?.h" },
      }
      defaults.link_lua_explicitly = true
   end

   if platforms.unix then
      defaults.lib_extension = "so"
      defaults.static_lib_extension = "a"
      defaults.external_lib_extension = "so"
      defaults.obj_extension = "o"
      defaults.external_deps_dirs = { "/usr/local", "/usr", "/" }

      defaults.variables.CFLAGS = os.getenv("CFLAGS") or "-O2"


      if not defaults.variables.CFLAGS:match("-fPIC") then
         defaults.variables.CFLAGS = defaults.variables.CFLAGS .. " -fPIC"
      end

      defaults.variables.LDFLAGS = os.getenv("LDFLAGS")

      defaults.cmake_generator = "Unix Makefiles"
      defaults.variables.CC = os.getenv("CC") or "gcc"
      defaults.variables.LD = os.getenv("CC") or "gcc"
      defaults.gcc_rpath = true
      defaults.variables.LIBFLAG = "-shared"
      defaults.variables.TEST = "test"

      defaults.external_deps_patterns = {
         bin = { "?" },
         lib = { "lib?.a", "lib?.so", "lib?.so.*" },
         include = { "?.h" },
      }
      defaults.runtime_external_deps_patterns = {
         bin = { "?" },
         lib = { "lib?.so", "lib?.so.*" },
         include = { "?.h" },
      }
      defaults.export_path_separator = ":"
      defaults.wrapper_suffix = ""
      local xdg_cache_home = os.getenv("XDG_CACHE_HOME") or home .. "/.cache"
      defaults.local_cache = xdg_cache_home .. "/luarocks"
      defaults.web_browser = "xdg-open"
   end

   if platforms.cygwin then
      defaults.lib_extension = "so"
      defaults.arch = "cygwin-" .. target_cpu
      defaults.cmake_generator = "Unix Makefiles"
      defaults.variables.CC = "echo -llua | xargs " .. (os.getenv("CC") or "gcc")
      defaults.variables.LD = "echo -llua | xargs " .. (os.getenv("CC") or "gcc")
      defaults.variables.LIBFLAG = "-shared"
      defaults.link_lua_explicitly = true
   end

   if platforms.msys then


      defaults.external_deps_patterns = {
         bin = { "?.exe", "?.bat", "?" },
         lib = { "lib?.so", "lib?.so.*", "lib?.dll.a", "?.dll.a",
"lib?.a", "lib?.dll", "?.dll", "?.lib", },
         include = { "?.h" },
      }
      defaults.runtime_external_deps_patterns = {
         bin = { "?.exe", "?.bat" },
         lib = { "lib?.so", "?.dll", "lib?.dll" },
         include = { "?.h" },
      }
      if platforms.mingw then




         local pipe = io.popen("cygpath --windows %MINGW_PREFIX%")
         local mingw_prefix = pipe:read("*l")
         pipe:close()
         defaults.external_deps_dirs = {
            mingw_prefix,
            dir.path("c:", "windows", "system32"),
         }
         defaults.makefile = "Makefile"
         defaults.cmake_generator = "MSYS Makefiles"
         defaults.local_cache = dir.path(home, ".cache", "luarocks")
         defaults.variables.MAKE = os.getenv("MAKE") or "make"
         defaults.variables.CC = os.getenv("CC") or "gcc"
         defaults.variables.RC = os.getenv("WINDRES") or "windres"
         defaults.variables.LD = os.getenv("CC") or "gcc"
         defaults.variables.MT = os.getenv("MT") or nil
         defaults.variables.AR = os.getenv("AR") or "ar"
         defaults.variables.RANLIB = os.getenv("RANLIB") or "ranlib"

         defaults.variables.CFLAGS = os.getenv("CFLAGS") or "-O2 -fPIC"
         if not defaults.variables.CFLAGS:match("-fPIC") then
            defaults.variables.CFLAGS = defaults.variables.CFLAGS .. " -fPIC"
         end

         defaults.variables.LIBFLAG = "-shared"
      end
   end

   if platforms.bsd then
      defaults.variables.MAKE = "gmake"
      defaults.gcc_rpath = false
      defaults.variables.CC = os.getenv("CC") or "cc"
      defaults.variables.LD = os.getenv("CC") or defaults.variables.CC
   end

   if platforms.macosx then
      defaults.variables.MAKE = os.getenv("MAKE") or "make"
      defaults.external_lib_extension = "dylib"
      defaults.arch = "macosx-" .. target_cpu
      defaults.variables.LIBFLAG = "-bundle -undefined dynamic_lookup -all_load"
      local version = util.popen_read("sw_vers -productVersion")
      if not (version:match("^%d+%.%d+%.%d+$") or version:match("^%d+%.%d+$")) then
         version = "10.3"
      end
      version = vers.parse_version(version)
      if version >= vers.parse_version("11.0") then
         version = vers.parse_version("11.0")
      elseif version >= vers.parse_version("10.10") then
         version = vers.parse_version("10.8")
      elseif version >= vers.parse_version("10.5") then
         version = vers.parse_version("10.5")
      else
         defaults.gcc_rpath = false
      end
      defaults.variables.CC = "env MACOSX_DEPLOYMENT_TARGET=" .. tostring(version) .. " gcc"
      defaults.variables.LD = "env MACOSX_DEPLOYMENT_TARGET=" .. tostring(version) .. " gcc"
      defaults.web_browser = "open"


      local sdk_path = util.popen_read("xcrun --show-sdk-path 2>/dev/null")
      if sdk_path then
         table.insert(defaults.external_deps_dirs, sdk_path .. "/usr")
         table.insert(defaults.external_deps_patterns.lib, 1, "lib?.tbd")
         table.insert(defaults.runtime_external_deps_patterns.lib, 1, "lib?.tbd")
      end


      table.insert(defaults.external_deps_dirs, "/usr/local/opt")
      defaults.external_deps_subdirs.lib = { "lib", "" }
      defaults.runtime_external_deps_subdirs.lib = { "lib", "" }
      table.insert(defaults.external_deps_patterns.lib, 1, "/?/lib/lib?.dylib")
      table.insert(defaults.runtime_external_deps_patterns.lib, 1, "/?/lib/lib?.dylib")
   end

   if platforms.linux then
      defaults.arch = "linux-" .. target_cpu

      local gcc_arch = util.popen_read("gcc -print-multiarch 2>/dev/null")
      if gcc_arch and gcc_arch ~= "" then
         defaults.external_deps_subdirs.lib = { "lib/" .. gcc_arch, "lib64", "lib" }
         defaults.runtime_external_deps_subdirs.lib = { "lib/" .. gcc_arch, "lib64", "lib" }
      else
         defaults.external_deps_subdirs.lib = { "lib64", "lib" }
         defaults.runtime_external_deps_subdirs.lib = { "lib64", "lib" }
      end
   end

   if platforms.freebsd then
      defaults.arch = "freebsd-" .. target_cpu
   elseif platforms.dragonfly then
      defaults.arch = "dragonfly-" .. target_cpu
   elseif platforms.openbsd then
      defaults.arch = "openbsd-" .. target_cpu
   elseif platforms.netbsd then
      defaults.arch = "netbsd-" .. target_cpu
   elseif platforms.solaris then
      defaults.arch = "solaris-" .. target_cpu
      defaults.variables.MAKE = "gmake"
   end


   defaults.variables.LIB_EXTENSION = defaults.lib_extension
   defaults.variables.OBJ_EXTENSION = defaults.obj_extension

   return defaults
end

local function use_defaults(cfg, defaults)



   if not cfg.variables then
      cfg.variables = {}
   end
   for k, v in pairs(defaults.variables) do
      if not cfg.variables[k] then
         cfg.variables[k] = v
      end
   end

   util.deep_merge_under(cfg, defaults)


   if not cfg.check_certificates then
      cfg.variables.CURLNOCERTFLAG = "-k"
      cfg.variables.WGETNOCERTFLAG = "--no-check-certificate"
   end
end



local cfg = {}













function cfg.init(detected, warning)
   detected = detected or {}

   local exit_ok = true
   local exit_err = nil
   local exit_what = nil

   local hc_ok, hardcoded = pcall(require, "luarocks.core.hardcoded")
   if not hc_ok then
      hardcoded = {}
   end

   local init = cfg.init





   for k, _ in pairs(cfg) do
      cfg[k] = nil
   end

   cfg.program_version = program_version

   if hardcoded.IS_BINARY then
      cfg.is_binary = true
   end



   local hardcoded_lua = hardcoded.LUA
   local hardcoded_lua_dir = hardcoded.LUA_DIR
   local hardcoded_lua_bindir = hardcoded.LUA_BINDIR
   local hardcoded_lua_incdir = hardcoded.LUA_INCDIR
   local hardcoded_lua_libdir = hardcoded.LUA_LIBDIR
   local hardcoded_lua_version = hardcoded.LUA_VERSION or _VERSION:sub(5)



   if detected.given_lua_version or detected.given_lua_dir then
      hardcoded_lua = nil
      hardcoded_lua_dir = nil
      hardcoded_lua_bindir = nil
      hardcoded_lua_incdir = nil
      hardcoded_lua_libdir = nil
      hardcoded_lua_version = nil
   end

   cfg.lua_version = detected.lua_version or hardcoded_lua_version
   cfg.project_dir = (not hardcoded.FORCE_CONFIG) and detected.project_dir

   do
      local lua = detected.lua or hardcoded_lua
      local lua_dir = detected.lua_dir or hardcoded_lua_dir
      local lua_bindir = detected.lua_bindir or hardcoded_lua_bindir
      cfg.variables = {
         LUA = lua,
         LUA_DIR = lua_dir,
         LUA_BINDIR = lua_bindir,
         LUA_LIBDIR = hardcoded_lua_libdir,
         LUA_INCDIR = hardcoded_lua_incdir,
      }
   end

   cfg.init = init








   local system, processor = sysdetect.detect()
   if hardcoded.SYSTEM then
      system = hardcoded.SYSTEM
   end
   if hardcoded.PROCESSOR then
      processor = hardcoded.PROCESSOR
   end

   if system == "windows" then
      if os.getenv("VCINSTALLDIR") then

         system = "windows"
      else
         local msystem = os.getenv("MSYSTEM")
         if msystem == nil then
            system = "mingw"
         elseif msystem == "MSYS" then
            system = "msys"
         else

            system = "msys2_mingw_w64"
         end
      end
   end

   cfg.target_cpu = processor

   local platforms = make_platforms(system)






   local sys_config_file
   local home_config_file
   local project_config_file

   local config_file_name = "config-" .. cfg.lua_version .. ".lua"

   do
      local sysconfdir = os.getenv("LUAROCKS_SYSCONFDIR") or hardcoded.SYSCONFDIR
      if platforms.windows and not platforms.msys2_mingw_w64 then
         cfg.home = os.getenv("APPDATA") or "c:"
         cfg.home_tree = dir.path(cfg.home, "luarocks")
         cfg.sysconfdir = sysconfdir or dir.path((os.getenv("PROGRAMFILES") or "c:"), "luarocks")
      else
         cfg.home = os.getenv("HOME") or ""
         cfg.home_tree = dir.path(cfg.home, ".luarocks")
         cfg.sysconfdir = sysconfdir or detect_sysconfdir() or "/etc/luarocks"
      end
   end


   sys_config_file = dir.path(cfg.sysconfdir, config_file_name)
   local sys_config_ok, err = load_config_file(cfg, platforms, sys_config_file)
   if err then
      exit_ok, exit_err, exit_what = nil, err, "config"
   end


   local home_config_ok
   local project_config_ok
   if not hardcoded.FORCE_CONFIG then
      local env_var = "LUAROCKS_CONFIG_" .. cfg.lua_version:gsub("%.", "_")
      local env_value = os.getenv(env_var)
      if not env_value then
         env_var = "LUAROCKS_CONFIG"
         env_value = os.getenv(env_var)
      end

      if env_value then
         local env_ok, err = load_config_file(cfg, platforms, env_value)
         if err then
            exit_ok, exit_err, exit_what = nil, err, "config"
         elseif warning and not env_ok then
            warning("Warning: could not load configuration file `" .. env_value .. "` given in environment variable " .. env_var .. "\n")
         end
         if env_ok then
            home_config_ok = true
            home_config_file = env_value
         end
      end


      if platforms.unix and not home_config_ok then
         local xdg_config_home = os.getenv("XDG_CONFIG_HOME") or dir.path(cfg.home, ".config")
         cfg.homeconfdir = dir.path(xdg_config_home, "luarocks")
         home_config_file = dir.path(cfg.homeconfdir, config_file_name)
         home_config_ok, err = load_config_file(cfg, platforms, home_config_file)
         if err then
            exit_ok, exit_err, exit_what = nil, err, "config"
         end
      end


      if not home_config_ok then
         cfg.homeconfdir = cfg.home_tree
         home_config_file = dir.path(cfg.homeconfdir, config_file_name)
         home_config_ok, err = load_config_file(cfg, platforms, home_config_file)
         if err then
            exit_ok, exit_err, exit_what = nil, err, "config"
         end
      end


      if cfg.project_dir then
         project_config_file = dir.path(cfg.project_dir, ".luarocks", config_file_name)
         project_config_ok, err = load_config_file(cfg, platforms, project_config_file)
         if err then
            exit_ok, exit_err, exit_what = nil, err, "config"
         end
      end
   end


   if cfg.lua_interpreter and cfg.variables.LUA_BINDIR and not cfg.variables.LUA then
      cfg.variables.LUA = dir.path(cfg.variables.LUA_BINDIR, cfg.lua_interpreter)
   end







   cfg.project_dir = detected.given_project_dir or cfg.project_dir
   cfg.lua_version = detected.given_lua_version or cfg.lua_version
   if detected.given_lua_dir then
      cfg.variables.LUA = detected.lua
      cfg.variables.LUA_DIR = detected.given_lua_dir
      cfg.variables.LUA_BINDIR = detected.lua_bindir
      cfg.variables.LUA_LIBDIR = nil
      cfg.variables.LUA_INCDIR = nil
   end


   if cfg.rocks_trees == nil then
      cfg.rocks_trees = {}
      if cfg.home_tree then
         table.insert(cfg.rocks_trees, { name = "user", root = cfg.home_tree })
      end
      if hardcoded.PREFIX and hardcoded.PREFIX ~= cfg.home_tree then
         table.insert(cfg.rocks_trees, { name = "system", root = hardcoded.PREFIX })
      end
   end

   local defaults = make_defaults(cfg.lua_version, processor, platforms, cfg.home)

   if platforms.windows and hardcoded.WIN_TOOLS then
      local tools = { "SEVENZ", "CP", "FIND", "LS", "MD5SUM", "WGET" }
      for _, tool in ipairs(tools) do
         defaults.variables[tool] = '"' .. dir.path(hardcoded.WIN_TOOLS, defaults.variables[tool] .. '.exe') .. '"'
      end
   else
      defaults.fs_use_modules = true
   end



   if cfg.variables.LUA and not cfg.variables.LUA_BINDIR then
      cfg.variables.LUA_BINDIR = cfg.variables.LUA:match("^(.*)[\\/][^\\/]*$")
      if not cfg.variables.LUA_DIR then
         cfg.variables.LUA_DIR = cfg.variables.LUA_BINDIR:gsub("[\\/]bin$", "") or cfg.variables.LUA_BINDIR
      end
   end

   use_defaults(cfg, defaults)

   cfg.user_agent = "LuaRocks/" .. cfg.program_version .. " " .. cfg.arch

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
      nearest = project_config_ok and
      project_config_file or
      (home_config_ok and
      home_config_file or
      sys_config_file),
   }

   cfg.cache = {}






   do
      local function make_paths_from_tree(tree)
         local lua_path, lib_path, bin_path
         if type(tree) == "string" then
            lua_path = dir.path(tree, cfg.lua_modules_path)
            lib_path = dir.path(tree, cfg.lib_modules_path)
            bin_path = dir.path(tree, "bin")
         else
            lua_path = tree.lua_dir or dir.path(tree.root, cfg.lua_modules_path)
            lib_path = tree.lib_dir or dir.path(tree.root, cfg.lib_modules_path)
            bin_path = tree.bin_dir or dir.path(tree.root, "bin")
         end
         return lua_path, lib_path, bin_path
      end

      function cfg.package_paths(current)
         local new_path, new_cpath, new_bin = {}, {}, {}
         local function add_tree_to_paths(tree)
            local lua_path, lib_path, bin_path = make_paths_from_tree(tree)
            table.insert(new_path, dir.path(lua_path, "?.lua"))
            table.insert(new_path, dir.path(lua_path, "?", "init.lua"))
            table.insert(new_cpath, dir.path(lib_path, "?." .. cfg.lib_extension))
            table.insert(new_bin, bin_path)
         end
         if current then
            add_tree_to_paths(current)
         end
         for _, tree in ipairs(cfg.rocks_trees) do
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




   function cfg.is_platform(name)
      assert(type(name) == "string")
      return platforms[name]
   end


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
      for k, _ in pairs(platforms) do
         table.insert(platform_keys, k)
      end
      table.sort(platform_keys)
      return table.concat(platform_keys, ", ")
   end

   return exit_ok, exit_err, exit_what
end

return cfg
