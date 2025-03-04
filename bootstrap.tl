#!/usr/bin/env -S -- tl run

local PLATFORM = arg[1] or "unix"

local lfs = require("lfs")

local dependencies = {
   "md5",
   "lua-zlib",
   "lua-bz2",
   "luafilesystem",
   "luasocket",
   "luasec",
   "miniposix",
}

local c_module_exceptions: {string:{string}} = {
   ["ssl"] = { "ssl.core", "ssl.context", "ssl.x509", "ssl.config" },
}

local rockspec_locations: {string:string} = {
   ["md5"] = "vendor/md5/rockspec/md5-1.2-1.rockspec",
   ["lua-zlib"] = "vendor/lua-zlib/lua-zlib-1.1-0.rockspec",
   ["lua-bz2"] = "vendor/lua-bz2/lua-bz2-0.2.1-1.rockspec",
   ["luafilesystem"] = "vendor/luafilesystem/luafilesystem-scm-1.rockspec",
   ["luasocket"] = "vendor/luasocket/luasocket-scm-3.rockspec",
   ["luasec"] = "vendor/luasec/luasec-1.3.2-1.rockspec",
   ["miniposix"] = "vendor/miniposix/miniposix-dev-1.rockspec",
}

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local hexdump: function(string): string
do
   local numtab = {}
   for i = 0, 255 do
     numtab[string.char(i)] = ("%-3d,"):format(i)
   end
   hexdump = function(str: string): string
      return (str:gsub(".", numtab):gsub(("."):rep(80), "%0\n"))
   end
end

local function apply_template(template: string, variables: {string:string}): string
   return (template:gsub("$%(([^)]*)%)", variables))
end

local function reindent_c(input: string): string
   local out = {}
   local indent = 0
   local previous_is_blank = true
   for line in input:gmatch("([^\n]*)") do
      line = line:match("^[ \t]*(.-)[ \t]*$")

      local is_blank = (#line == 0)
      local do_print =
         (not is_blank) or
         (not previous_is_blank and indent == 0)

      if line:match("^[})]") then
         indent = indent - 1
         if indent < 0 then indent = 0 end
      end
      if do_print then
         table.insert(out, string.rep("   ", indent))
         table.insert(out, line)
         table.insert(out, "\n")
      end
      if line:match("[{(]$") then
         indent = indent + 1
      end

      previous_is_blank = is_blank
   end
   return table.concat(out)
end

local function sortedpairs<K, V>(tbl: {K: V}): function(): (K, V)
   local keys = {}
   for k, _ in pairs(tbl) do
      table.insert(keys, k)
   end
   table.sort(keys, function(a: K, b: K): boolean
      if a is integer and not b is integer then
         return true
      elseif not a is integer and b is integer then
         return false
      end
      return (a as integer) < (b as integer)
   end)
   local i = 1
   return function(): (K, V)
      local key = keys[i]
      i = i + 1
      return key, tbl[key]
   end
end

local function mkdir_p(dirname: string)
   local a, b = dirname:match("(.*)/(.*)")
   if a and b then
      mkdir_p(a)
   end
   lfs.mkdir(dirname)
end

local function dirname(filename: string): string
   return (filename:gsub("[^/]*$", ""))
end

local function write_template(filename: string, template: string, variables: {string:string})
   local fd = assert(io.open(filename, "wb"))
   local text = apply_template(template, variables)
   if filename:match("%.[ch]$") then
      text = reindent_c(text)
   end
   fd:write(text)
   fd:close()
end

local function find_files(dir_name: string): (function(): string)
   local iter_stack: {lfs.DirObj} = {}
   local dir_stack: {string} = { dir_name }
   local iter, dd = lfs.dir(dir_name)
   return function(): string
      while true do
         local s = iter(dd)
         if s ~= "." and s ~= ".." then
            if not s then
               if #iter_stack == 0 then
                  return nil
               end
               table.remove(dir_stack)
               dd = table.remove(iter_stack)
            else
               local d = dir_stack[#dir_stack]
               local pathname = d .. "/" .. s, "mode"
               if lfs.attributes(pathname, "mode") ~= "directory" then
                  return pathname
               else
                  table.insert(iter_stack, dd)
                  iter, dd = lfs.dir(pathname)
                  table.insert(dir_stack, pathname)
               end
            end
         end
      end
   end
end

--------------------------------------------------------------------------------
-- Collect data based on rockspecs in vendor/
--------------------------------------------------------------------------------

local record BuildEntry
   sources: {string}
   incdirs: {string}
   defines: {string}
end

local record Data
   record LuaEntry
      dep: string
      mod: string
      source: string

      h_file: string
      length: integer
   end
   record CEntry
      dep: string
      mod: string
      build: BuildEntry

      a_file: string
   end

   luas: {LuaEntry}
   cs: {CEntry}
end

local function add_lua(data: Data, dep: string, mod: string, source: string)
   table.insert(data.luas, { dep = dep, mod = mod, source = source })
end

local function add_c(data: Data, dep: string, mod: string, build: BuildEntry)
   table.insert(data.cs, { dep = dep, mod = mod, build = build })
end

local record Rockspec
   record Build
      record Install
         lua: {(string | integer): string}
      end

      type: string
      modules: {string: (string | BuildEntry)}
      install: Install
      platforms: {string: Build}
   end

   build: Build
end

local function load_rockspec(dep: string, rockspec_filename: string): Rockspec
   local rockspec: Rockspec = {}
   local fd = io.open(rockspec_filename)
   local source = fd:read("*a")
   fd:close()
   local chunk = assert(load(source, dep, "t", rockspec as {any:any}))
   chunk()
   return rockspec
end

local function process_build_entry(data: Data, dep: string, mod: string, modt: string|BuildEntry)
   if modt is string then
      if modt:match("lua$") then
         add_lua(data, dep, mod, "vendor/" .. dep .. "/" .. modt)
      else
         add_c(data, dep, mod, { sources = { modt } })
      end
   elseif modt is BuildEntry then
      add_c(data, dep, mod, modt)
   end
end

local function process_build_modules(data: Data, dep: string, entries: {string: (string|BuildEntry)})
   for mod, modt in sortedpairs(entries) do
      process_build_entry(data, dep, mod, modt)
   end
end

local function process_build_install(data: Data, dep: string, entries: {(string|integer): string})
   for mod, modt in sortedpairs(entries) do
      if mod is integer then
         assert(modt is string)
         mod = modt:gsub("^src/", ""):gsub("^lua/", ""):gsub("%.[^.]*$", ""):gsub("/", ".")
      end
      assert(mod is string)

      process_build_entry(data, dep, mod, modt)
   end
end

local function process_build(data: Data, dep: string, build: Rockspec.Build)
   if build.modules then
      process_build_modules(data, dep, build.modules)
   end
   if build.install and build.install.lua then
      process_build_install(data, dep, build.install.lua)
   end
end

local function process(data: Data, dep: string, rockspec_filename: string)
   local rockspec = load_rockspec(dep, rockspec_filename)

   assert(rockspec.build.type == "builtin")

   if rockspec.build.modules or rockspec.build.install then
      process_build(data, dep, rockspec.build)
   end

   if rockspec.build.platforms then
      if rockspec.build.platforms[PLATFORM] then
         process_build(data, dep, rockspec.build.platforms[PLATFORM])
      end
   end
end

--------------------------------------------------------------------------------
-- Generate entries for Makefile-based build
--------------------------------------------------------------------------------

local function global_name(mod: string): string
   return "luarocks_gen_" .. mod:gsub("%.", "_")
end

local function generate(input_filename: string, entry: Data.LuaEntry): string
   local fd = assert(io.open(input_filename, "rb"))
   local content = fd:read("*a"):gsub("^#![^\n]+\n", "")
   fd:close()

   entry.length = #content

   return apply_template([[
      /* automatically generated by bootstrap.tl */

      static const unsigned char $(global)[] = {
         $(code)
      };
   ]], {
      global = global_name(entry.mod),
      code = hexdump(content),
   })
end

local function generate_all_luas(luas: {Data.LuaEntry})
   for _, entry in ipairs(luas) do
      local filename = "gen/lua/" .. entry.mod:gsub("%.", "/") .. ".h"
      mkdir_p(dirname(filename))

      local fd = assert(io.open(filename, "wb"))
      fd:write(reindent_c(generate(entry.source, entry)))
      entry.h_file = filename
      fd:close()
   end

   local includes = {}
   local array = {}
   for _, entry in ipairs(luas) do
      table.insert(includes, ("#include \"%s\""):format(entry.h_file))
      table.insert(array, apply_template([[
         {
            .module_name = "$(mod)",
            .source_name = "$(source)",
            .length = $(length),
            .code = $(global),
         },
      ]], {
         mod = entry.mod,
         dep = entry.dep,
         source = entry.source,
         length = tostring(entry.length),
         global = global_name(entry.mod),
      }))
   end

   table.insert(array, apply_template([[
      {
         .module_name = NULL,
         .source_name = NULL,
         .length = 0,
         .code = NULL,
      },
   ]], {}))

   write_template("gen/gen.h", [[
      /* automatically generated by bootstrap.tl */

      $(includes)

      static const Gen GEN[] = {
         $(array)
      };
   ]], {
      array = table.concat(array, "\n"),
      includes = table.concat(includes, "\n"),
   })
end

local function get_flag_list(flag: string, entries: {string}, parent: string): string
   local out = {}
   for _, entry in ipairs(entries) do
      table.insert(out, flag .. " " .. parent .. entry)
   end
   return table.concat(out, " ")
end

local function generate_makefile_entry(entry: Data.CEntry, seen: {string:boolean}, dirs: {string:boolean}): string
   local out = {}
   assert(entry.build.sources)

   local incdirs = ""
   if entry.build.incdirs then
      incdirs = get_flag_list("-I", entry.build.incdirs, "vendor/" .. entry.dep .. "/")
   end
   local defines = ""
   if entry.build.defines then
      defines = get_flag_list("-D", entry.build.defines, "")
   end

   local objects = {}
   for _, f in ipairs(entry.build.sources) do
      local file = "vendor/" .. entry.dep .. "/" .. f
      local obj_file = "target/objects/" .. entry.dep .. "/" .. file:gsub("%.c$", ".o")
      table.insert(objects, obj_file)

      if not seen[file] then
         local d = dirname(obj_file)
         if not dirs[d] then
            dirs[d] = true
         end

         -- the pipe indicates an order-only prerequisite
         -- (https://www.gnu.org/software/make/manual/make.html#Prerequisite-Types)
         table.insert(out, ("%s: %s | %s"):format(obj_file, file, d))
         table.insert(out, ("\t$(CC) -c -o %s %s %s %s"):format(obj_file, file, incdirs, defines))
         seen[file] = true
      end
   end

   local a_file = "target/libraries/" .. entry.mod:gsub("%.", "/") .. ".a"
   entry.a_file = a_file

   local d = dirname(a_file)
   if not dirs[d] then
      dirs[d] = true
   end

   local object_list = table.concat(objects, " ")
   table.insert(out, ("%s: %s | %s"):format(a_file, object_list, d))
   --table.insert(out, ("\t$(MKDIR) -p %s"):format(dirname(a_file)))
   table.insert(out, ("\t$(AR) rcu %s %s"):format(a_file, object_list))
   table.insert(out, "")

   return table.concat(out, "\n")
end

local function process_c_entry(mod: string, externs: {string}, declares: {string})
   if c_module_exceptions[mod] then
      for _, m in ipairs(c_module_exceptions[mod]) do
         process_c_entry(m, externs, declares)
      end
      return
   end

   local cfunc = "luaopen_" .. mod:gsub("%.", "_")

   table.insert(externs, ("extern int %s(lua_State* L);"):format(cfunc))

   table.insert(declares, ("lua_pushcfunction(L, %s);"):format(cfunc))
   table.insert(declares, ("lua_setfield(L, -2, \"%s\");"):format(mod))
end

local makefile_vendor_template = [[
# automatically generated by bootstrap.tl

VENDOR_LIBS = $(a_files)

$(entries)

]]

local function generate_all_cs(cs: {Data.CEntry})
   local seen = {}
   local dirs = {}

   local entries = {}
   for _, entry in ipairs(cs) do
      table.insert(entries, generate_makefile_entry(entry, seen, dirs))
   end

   table.insert(entries, "")
   for d, _ in sortedpairs(dirs) do
      table.insert(entries, ("%s:"):format(d))
      table.insert(entries, ("\t$(MKDIR) -p %s"):format(d))
   end

   local a_files = {}
   for _, entry in ipairs(cs) do
      table.insert(a_files, entry.a_file)
   end

   write_template("Makefile.vendor", makefile_vendor_template, {
      entries = table.concat(entries, "\n"),
      a_files = table.concat(a_files, " "),
   })

   local externs = {}
   local declares = {}
   for _, entry in ipairs(cs) do
      process_c_entry(entry.mod, externs, declares)
   end

   write_template("gen/libraries.h", [[
      /* automatically generated by bootstrap.tl */

      $(externs)

      static void declare_libraries(lua_State* L) {
         lua_getglobal(L, "package");                     /* package */
         lua_getfield(L, -1, "preload");                  /* package package.preload */
         $(declares)
         lua_settop(L, 0);                                /* */
      }
   ]], {
      externs = table.concat(externs, "\n"),
      declares = table.concat(declares, "\n"),
   })
end

local function generate_main_h()
   local fd = assert(io.open("gen/main.h", "wb"))
   fd:write(reindent_c(generate("src/bin/luarocks", {
      mod = "main"
   })))
   fd:close()
end

--------------------------------------------------------------------------------
-- Main operation
--------------------------------------------------------------------------------

local data: Data = {
   luas = {},
   cs = {},
}

for file in find_files("src") do
   if file:match("%.lua$") then
      table.insert(data.luas, {
         dep = "luarocks",
         mod = file:gsub("^src/(.*).lua", "%1"):gsub("/", "."),
         source = file,
      })
   end
end

for _, dep in ipairs(dependencies) do
   print(dep)
   process(data, dep, rockspec_locations[dep])
end

generate_all_luas(data.luas)
generate_all_cs(data.cs)
generate_main_h()
