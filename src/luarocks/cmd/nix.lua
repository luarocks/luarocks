-- Most likely you want to run this from
-- <nixpkgs>/maintainers/scripts/update-luarocks-packages
-- rockspec format available at
-- https://github.com/luarocks/luarocks/wiki/Rockspec-format
-- luarocks 3 introduced many things:
-- https://github.com/luarocks/luarocks/blob/master/CHANGELOG.md#new-build-system
-- this should be converted to an addon
-- https://github.com/luarocks/luarocks/wiki/Addon-author's-guide
-- needs at least one json library, for instance luaPackages.cjson
local nix = {}

local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local cfg = require("luarocks.core.cfg")
local queries = require("luarocks.queries")
local dir = require("luarocks.dir")
local search = require("luarocks.search")

local _

---@class (exact) RockspecSource
---@field ref? string Name of the dependency
---@field tag? string
---@field url string
---@field branch? string

-- Copy of util.popen_read in src/luarocks/core/util.lua
-- but one that returns status too
-- os.execute return result
local function popen_read(cmd, spec)
   local dir_sep = package.config:sub(1, 1)
   local tmpfile = (dir_sep == "\\")
                   and (os.getenv("TMP") .. "/luarocks-" .. tostring(math.floor(math.random() * 10000)))
                   or os.tmpname()
   local res = { os.execute(cmd .. " > " .. tmpfile) }
   local fd = io.open(tmpfile, "rb")
   if not fd then
      os.remove(tmpfile)
      return ""
   end
   local out = fd:read(spec or "*l")
   fd:close()
   os.remove(tmpfile)
   if #res == 1 then
      -- lua5.1 's os.execute just returns status
      return res, out or ""
   else
      -- assume lua >= 5.2 => returns (success, exit_type, exit_code)
      return res[3], out or ""
   end
end


-- new flags must be added to util.lua
-- ..util.deps_mode_help()
-- nix.help_arguments = "[--maintainers] {<rockspec>|<rock>|<name> [<version>]}"
function nix.add_to_parser(parser)
   local cmd = parser:command("nix", [[
Generates a nix derivation from a luarocks package.
If the argument is a .rockspec or a .rock, this generates a nix derivation matching the rockspec,
otherwise the program searches luarocks.org with the argument as the package name.

--maintainers set package meta.maintainers
]], util.see_also())
   :summary("Converts a rock/rockspec to a nix package")

   cmd:argument("name", "Rockspec for the rock to build.")
      :args("?")
   cmd:argument("version", "Rock(spec) version.")
      :args("?")

   cmd:option("--maintainers", "comma separated list of nix maintainers")
end

-- look at how it's done in fs.lua
local function debug(...)
   if cfg.verbose then
      print("nix:", ...)
   end
end

-- attempts to convert spec.description.license
-- to spdx id (see <nixpkgs>/lib/licenses.nix)
--- @param license string License straight from rockspec
--- @return string quoted license
local function convert2nixLicense(license)
   assert (license ~= nil)
   return util.LQ(license)
end

---@param url string The url to get checksum for
local function checksum_unpack(url)
   local r = io.popen("nix-prefetch-url --unpack "..url)
   local checksum = r:read()
   return checksum
end


--- @return string|nil   Checksum or nil in case of error
--- @return string    fetcher name or error description
local function checksum_and_file(url)
   -- TODO download the src.rock unpack it and get the hash around it ?

   -- redirect stderr to a tempfile
   -- Note: This logic is posix-only
   local tmpfile = os.tmpname()
   local r = io.popen("nix-prefetch-url "..url.." 2>"..tmpfile)

   -- checksum is on stdout
   local checksum = r:read()
   -- path is on stderr
   local fetched_path = ""
   local fd = io.open(tmpfile, "rb")
   if fd then
      local stderr = fd:read("*a")
      _, _, fetched_path = string.find(stderr, "^path is '(.+)'\n$")
   end
   os.remove(tmpfile)

   if not fetched_path or fetched_path == "" then
      util.printerr("Failed to get path from nix-prefetch-url")
      return nil, "Failed to get path from nix-prefetch-url"
   end
   debug("Prefetched path:", fetched_path)

   local f = io.popen("file "..fetched_path)
   local file_out = f:read()
   local _, _, desc = string.find(file_out, "^"..util.matchquote(fetched_path)..": (.*)$")
   if not desc then
      util.printerr("Failed to run 'file' on prefetched path")
      return nil, "Failed to run 'file' on prefetched path"
   end

   if string.find(desc, "^Zip archive data") then
      return checksum, "fetchzip"
   end
   if string.find(desc, "^gzip compressed data") then
      return checksum, "fetchurl"
   end
   return checksum, "fetchurl"
end

-- Check if the package url matches a mirror url
-- @param repo: a string
-- @return table: A table where keys are package names
local function check_url_against_mirror(url, mirror)
   local dirname = dir.dir_name(url)
   -- local inspect = require'inspect'
   -- print(inspect.inspect(mirror))
   if mirror == dirname then
      local basename = dir.base_name(url)
      local final_url = "mirror://luarocks/"..basename
      return true, final_url
   end
   return false, _
end

-- Generate nix code using fetchurl
-- Detects if the server is in the list of possible mirrors
-- in which case it uses the special nixpkgs uris mirror://luarocks
-- @return (fetcher, src) a tuple of (fetcher attribute: string, generated nix 'src': string),
local function gen_src_from_basic_url(url)
   assert(type(url) == "string")

   local checksum, fetcher = checksum_and_file(url)
   if fetcher == "fetchzip" then
      checksum = checksum_unpack(url)
   end

   local final_url = url

   for _, repo in ipairs(cfg.rocks_servers) do
      debug("REPO", repo)
      local repo_l = repo
      if type(repo) == "string" then
         repo_l = { repo }
      end
      for _, mirror in ipairs(repo_l) do
         local res, url2 = check_url_against_mirror(final_url, mirror)
         if res then
            final_url = url2
            break
         end
      end
   end

   local src = fetcher..[[ {
    url    = "]]..final_url..[[";
    sha256 = ]]..util.LQ(checksum)..[[;
  }]]
   return fetcher, src

end

-- Generate nix code to fetch from a git repository
-- TODO we could check a specific branch with --rev
--- @param src RockspecSource attribute "src" of the rockspec
--- @return string The nix code for source
local function gen_src_from_git_url(src)

   -- deal with  git://github.com/antirez/lua-cmsgpack.git for instance
   -- local cmd = "nix-prefetch-git --fetch-submodules --quiet "..src.url
   local cmd = "nurl --indent 2 "..src.url
   local ref = src.ref or src.tag or src.branch
   if ref then
      cmd = cmd.." "..ref
   end

   debug(cmd)
   local status, generatedSrc = popen_read(cmd, "*a")

   if status ~= 0 or (generatedSrc and generatedSrc == "") then
      util.printerr("Call to "..cmd.." failed with status: "..tostring(status))
   end

   return generatedSrc or ""
end

-- converts url to nix "src"
-- while waiting for a program capable to generate the nix code for us
-- @param source dict: the rockspec spec.source, contains "tag", branch etc
-- @return dependency, src
local function url2src(src)

   assert (type(src) == "table")

   -- logic inspired from rockspecs.from_persisted_table
   local protocol, pathname = dir.split_url(src.url)
   debug("Generating src for protocol:"..protocol.." to "..pathname)
   if dir.is_basic_protocol(protocol) then
      return gen_src_from_basic_url(src.url)
   end

   if protocol == "git" or protocol == "git+https" then
      local normalized_url = "https://"..pathname
      src.url = normalized_url
      local nix_json = gen_src_from_git_url(src)
      if nix_json == "" then
         return nil, nil
      end
      local nix_src = nix_json
      -- TODO get first returned element
      local fetcher = string.match(nix_src, "^(%w+)")

      return fetcher, nix_src
   end

   if protocol == "file" then
      return nil, pathname
   end

   util.printerr("Unsupported protocol "..protocol)
   assert(false) -- unsupported protocol
end


--- @param deps_array object[] array of dependencies
--- @return string[] dependency list of nixified names,
--- @return string[] list of associated constraints,
--- @return string[] list of associated nix derivations for constraints
local function load_dependencies(deps_array)
   local dependencies = {}
   local cons = {}
   local constraintInputs = {}
   debug("loading dependencies from")
   debug(util.show_table(deps_array))

   for _, dep in ipairs(deps_array)
   do
      debug(dep)
      local entry = nix.convert_pkg_name_to_nix(dep.name)
      if entry == "lua" and dep.constraints then

         for _, c in ipairs(dep.constraints)
         do
            local constraint_str = nil

            if c.op == ">=" then
               constraint_str = "luaOlder "..util.LQ(tostring(c.version))
               constraintInputs["luaOlder"] = 1
            elseif c.op == "==" then
               constraint_str = "lua.luaversion != "..util.LQ(tostring(c.version))
               constraintInputs["lua"] = 1
            elseif c.op == ">" then
               constraint_str = "luaOlder "..util.LQ(tostring(c.version))
               constraintInputs["luaOlder"] = 1
            elseif c.op == "<" then
               constraint_str = "luaAtLeast "..util.LQ(tostring(c.version))
               constraintInputs["luaAtLeast"] = 1
            end
            if constraint_str then
               cons[#cons+1] = constraint_str
            end

         end
      else -- we dont add lua to propagated inputs
         dependencies[entry] = true
      end
   end
   return dependencies, cons, constraintInputs
end


-- TODO take into account external_dependencies
-- @param spec table
-- @param rock_url
-- @param rockspec_url Rockspecs are not easy to find in project repos, so we need to reference the luarocks one
-- @param rockspec_relpath path towards the rockspec from within the repository (should this be a directory ?)
-- @param rock_file if nil, will be fetched from url
-- @param manual_overrides a table of custom nix settings like "maintainers"
local function convert_spec2nix(spec, rockspec_relpath, rockspec_url, manual_overrides)
   assert ( spec )
   -- print("SPEC TABLE")
   -- print(util.show_table(spec))

   local lua_constraints_str = ""
   local maintainers_str = ""
   local long_desc_str = ""
   local call_package_inputs = { buildLuarocksPackage=1 }

   if manual_overrides["maintainers"] then
      maintainers_str = "    maintainers = with lib.maintainers; [ "..manual_overrides["maintainers"].." ];\n"
   end

   if spec.description.detailed then
      long_desc_str = "    longDescription = ''"..spec.description.detailed.."'';\n"
   end

   local dependencies, lua_constraints, constraintInputs = load_dependencies(spec.dependencies.queries)
   local native_deps, _, _ = load_dependencies(spec.build_dependencies.queries)
   util.deep_merge(call_package_inputs, constraintInputs)

   -- TODO to map lua dependencies to nix ones,
   -- try heuristics with nix-locate or manual table ?
   -- local external_deps = ""
   -- if spec.external_dependencies then
   --    external_deps = "# override to account for external deps"
   -- end

   if #lua_constraints > 0 then
      -- with lua
      lua_constraints_str =  "  disabled = "..table.concat(lua_constraints,' || ')..";\n"
   end

   -- if only a rockspec than translate the way to fetch the sources
   local sources
   local rockspec_str = ""
   local fetchDeps, src_str
   if rockspec_url then
     -- sources = "src = "..gen_src_from_basic_url(rock_url)..";"
     fetchDeps, src_str = url2src({ url = rockspec_url})
     rockspec_str = [[  knownRockspec = (]]..src_str..[[).outPath;]]
     if fetchDeps ~= nil then
      call_package_inputs[fetchDeps]=2
     end

   end

   -- we have to embed the valid rockspec since most repos dont contain
   -- valid rockspecs in the repo for a specific revision (the rockspec is
   -- manually updated before being uploaded to luarocks.org)
   fetchDeps, src_str = url2src(spec.source)
   sources = "src = "..src_str..";\n"
   assert (fetchDeps ~= nil)
   call_package_inputs[fetchDeps]=2

   if spec.build and spec.build.type then
      local build_type = spec.build.type
      if build_type == "cmake" then
         native_deps["cmake"] = true
      end
   end



   util.deep_merge(call_package_inputs, dependencies)
   util.deep_merge(call_package_inputs, native_deps)

   local native_build_inputs_str = ""
   native_deps = util.keys(native_deps)
   if #native_deps > 0 then
      table.sort(native_deps)
      native_build_inputs_str = "  nativeBuildInputs = [ "..table.concat(native_deps, " ").." ];\n"
   end

   local propagated_build_inputs_str = ""
   dependencies = util.keys(dependencies)
   if #dependencies > 0 then
      table.sort(dependencies)
      propagated_build_inputs_str = "  propagatedBuildInputs = [ "..table.concat(dependencies, " ").." ];\n"
   end

   -- if spec.test and spec.test.type then
   --    local test_type = spec.test.type
   --    if test_type == "busted" then
   --      checkInputs = table.concat(checkInputs, ", ")
   --    end
   -- end

   -- introduced in rockspec format 3
   local checkInputsStr = ""
   local checkInputs, _ = load_dependencies(spec.test_dependencies.queries)
   if #checkInputs > 0 then
      checkInputsStr = "  checkInputs = [ "..table.concat(checkInputs, " ").." ];\n"
      util.deep_merge(call_package_inputs, checkInputs)
   end
   local license_str = ""
   if spec.description.license then
      license_str = [[    license.fullName = ]]..convert2nixLicense(spec.description.license)..";\n"
   end


   if rockspec_relpath ~= nil and rockspec_relpath ~= "." and rockspec_relpath ~= "" then
      rockspec_str = [[  rockspecDir = "]]..rockspec_relpath..[[";
]]
   end


   -- should be able to do without 'rec'
   -- we have to quote the urls because some finish with the bookmark '#' which fails with nix
   local call_package_input_names = util.keys(call_package_inputs)
   table.sort(call_package_input_names)

   local call_package_str = table.concat(call_package_input_names, ", ")
   local header = [[
{ ]]..call_package_str..[[ }:
buildLuarocksPackage {
  pname = ]]..util.LQ(spec.name)..[[;
  version = ]]..util.LQ(spec.version)..[[;
]]..rockspec_str..[[

  ]]..sources..[[

]]..lua_constraints_str..[[
]]..native_build_inputs_str..[[
]]..propagated_build_inputs_str..[[
]]..checkInputsStr..[[

  meta = {
    homepage = ]]..util.LQ(spec.description.homepage or spec.source.url)..[[;
]]..maintainers_str..[[
]]..license_str..[[
    description = ]]..util.LQ(spec.description.summary or "No summary")..[[;
]]..long_desc_str..[[
  };
}]]

   return header
end

--- @param name string
-- @return (spec, url, )
local function run_query (name, version)

   -- "src" to fetch only sources
   -- see arch_to_table for, any delimiter will do
   local arch = "rockspec" -- look only for rockspecs, use "src|rockspec" to search both
   local query = queries.new(name, nil, version, false, arch)
   local url, search_err = search.find_suitable_rock(query)
   if not url then
       util.printerr("can't find suitable rockspec for '"..name.."'")
       return nil, search_err
   end
   debug('found url '..url)

   -- local rockspec_file = "unset path"
   local fetched_file, tmp_dirname, errcode = fetch.fetch_url_at_temp_dir(url, "luarocks-"..name)
   if not fetched_file then
      return nil, "Could not fetch file: " .. tmp_dirname, errcode
   end

   return url, fetched_file
end

-- Converts lua package name to nix package name
-- replaces dot with underscores
function nix.convert_pkg_name_to_nix(name)

   -- % works as an escape character
   local res, _ = name:gsub("%.", "-")
   return res
end



--- Driver function for "nix" command.
-- we need to have both the rock and the rockspec
-- @param name string: A local or remote rockspec or rock file.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number may
-- also be given.
-- @param maintainers string: the maintainer names, e.g. "teto vyc"
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function nix.command(args)
   local name = args.name
   local version = args.version
   local maintainers = args.maintainers
   local spec, msg, err
   local rockspec_relpath = nil

   if type(name) ~= "string" then
       return nil, "Expects package name as first argument. "..util.see_help("nix")
   end
   local rock_url
   local rockspec_name, rockspec_version
    -- assert(type(version) == "string" or not version)

   if name:match(".*%.rock$")  then
      spec, msg = fetch.fetch_and_unpack_rock(name, nil)
      if not spec then
          return false, msg
      end
   elseif name:match(".*%.rockspec$") then
      local rockspec_filename = name
      spec, err = fetch.load_rockspec(rockspec_filename)
      if not spec then
         return nil, err
      end
   else
      -- assume it's just a name
      rockspec_name = name
      rockspec_version = version
      local url, res1 = run_query (rockspec_name, rockspec_version)
      if not url then
         return false, res1
      end

      local rockspec_file
      local fetched_file = res1

         rock_url = url
      --    -- here we are not sure it's actually a rock
      --    local dir_name, err, errcode = fetch.fetch_and_unpack_rock(fetched_file)
      --    if not dir_name then
      --       util.printerr("can't fetch and unpack "..name)
      --       return nil, err, errcode
      --    end
      --    rockspec_file = path.rockspec_name_from_rock(fetched_file)
      --    rockspec_file = dir_name.."/"..rockspec_file
      -- else
         -- it's a rockspec
         rockspec_file = fetched_file
         -- rockspec_url = url
      -- end

      spec, err = fetch.load_local_rockspec(rockspec_file, nil)
      if not spec then
         return nil, err
      end
   end

   local nix_overrides = {
      maintainers = maintainers
   }
   local derivation, err = convert_spec2nix(spec, rockspec_relpath, rock_url, nix_overrides)
   if derivation then
     print(derivation)
   end
   return derivation, err
end

return nix
