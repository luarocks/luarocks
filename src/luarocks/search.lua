local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local search = {}

local dir = require("luarocks.dir")
local path = require("luarocks.path")
local manif = require("luarocks.manif")
local vers = require("luarocks.core.vers")
local cfg = require("luarocks.core.cfg")
local util = require("luarocks.util")
local queries = require("luarocks.queries")
local results = require("luarocks.results")












function search.store_result(result_tree, result)

   local name = result.name
   local version = result.version

   if not result_tree[name] then result_tree[name] = {} end
   if not result_tree[name][version] then result_tree[name][version] = {} end
   table.insert(result_tree[name][version], {
      arch = result.arch,
      repo = result.repo,
      namespace = result.namespace,
   })
end










local function store_if_match(result_tree, result, query)

   if result:satisfies(query) then
      search.store_result(result_tree, result)
   end
end










function search.disk_search(repo, query, result_tree)

   local fs = require("luarocks.fs")

   if not result_tree then
      result_tree = {}
   end

   for name in fs.dir(repo) do
      local pathname = dir.path(repo, name)
      local rname, rversion, rarch = path.parse_name(name)

      if rname and (pathname:match(".rockspec$") or pathname:match(".rock$")) then
         local result = results.new(rname, rversion, repo, rarch)
         store_if_match(result_tree, result, query)
      elseif fs.is_dir(pathname) then
         for version in fs.dir(pathname) do
            if version:match("-%d+$") then
               local namespace = path.read_namespace(name, version, repo)
               local result = results.new(name, version, repo, "installed", namespace)
               store_if_match(result_tree, result, query)
            end
         end
      end
   end
   return result_tree
end











local function manifest_search(result_tree, repo, query, lua_version, is_local)


   if (not is_local) and query.namespace then
      repo = repo .. "/manifests/" .. query.namespace
   end

   local manifest, err, errcode = manif.load_manifest(repo, lua_version, not is_local)
   if not manifest then
      return nil, err, errcode
   end
   for name, versions in pairs(manifest.repository) do
      for version, items in pairs(versions) do
         local namespace = is_local and path.read_namespace(name, version, repo) or query.namespace
         for _, item in ipairs(items) do
            local result = results.new(name, version, repo, item.arch, namespace)
            store_if_match(result_tree, result, query)
         end
      end
   end
   return true
end

local function remote_manifest_search(result_tree, repo, query, lua_version)
   return manifest_search(result_tree, repo, query, lua_version, false)
end

function search.local_manifest_search(result_tree, repo, query, lua_version)
   return manifest_search(result_tree, repo, query, lua_version, true)
end







function search.search_repos(query, lua_version)

   local result_tree = {}
   local repo = {}
   for _, repostr in ipairs(cfg.rocks_servers) do
      if type(repostr) == "string" then
         repo = { repostr }
      else
         repo = repostr
      end
      for _, mirror in ipairs(repo) do
         if not cfg.disabled_servers[mirror] then
            local protocol, pathname = dir.split_url(mirror)
            if protocol == "file" then
               mirror = pathname
            end
            local ok, err, errcode = remote_manifest_search(result_tree, mirror, query, lua_version)
            if errcode == "network" then
               cfg.disabled_servers[mirror] = true
            end
            if ok then
               break
            else
               util.warning("Failed searching manifest: " .. err)
               if errcode == "downloader" then
                  break
               end
            end
         end
      end
   end

   local provided_repo = "provided by VM or rocks_provided"
   for name, version in pairs(util.get_rocks_provided()) do
      local result = results.new(name, version, provided_repo, "installed")
      store_if_match(result_tree, result, query)
   end
   return result_tree
end







local function pick_latest_version(name, versions)
   assert(not name:match("/"))

   local vtables = {}
   for v, _ in pairs(versions) do
      table.insert(vtables, vers.parse_version(v))
   end
   table.sort(vtables)
   local version = vtables[#vtables].string
   local items = versions[version]
   if items then
      local pick = 1
      for i, item in ipairs(items) do
         if (item.arch == 'src' and items[pick].arch == 'rockspec') or
            (item.arch ~= 'src' and item.arch ~= 'rockspec') then
            pick = i
         end
      end
      return path.make_url(items[pick].repo, name, version, items[pick].arch)
   end
   return nil
end




local function supported_lua_versions(query)
   local result_tree = {}

   for lua_version in util.lua_versions() do
      if lua_version ~= cfg.lua_version then
         util.printout("Checking for Lua " .. lua_version .. "...")
         if search.search_repos(query, lua_version)[query.name] then
            table.insert(result_tree, lua_version)
         end
      end
   end

   return result_tree
end






function search.find_suitable_rock(query)

   local rocks_provided = util.get_rocks_provided()

   if rocks_provided[query.name] then

      return nil, "Rock " .. query.name .. " " .. rocks_provided[query.name] ..
      " is already provided by VM or via 'rocks_provided' in the config file.", "provided"
   end

   local result_tree = search.search_repos(query)
   local first_rock = next(result_tree)
   if not first_rock then
      return nil, "No results matching query were found for Lua " .. cfg.lua_version .. ".", "notfound"
   elseif next(result_tree, first_rock) then

      return nil, "Several rocks matched query.", "manyfound"
   else
      return pick_latest_version(query.name, result_tree[first_rock])
   end
end

function search.find_rock_checking_lua_versions(query, check_lua_versions)
   local url, err, errcode = search.find_suitable_rock(query)
   if url then
      return url
   end

   if errcode == "notfound" then
      local add
      if check_lua_versions then
         util.printout(query.name .. " not found for Lua " .. cfg.lua_version .. ".")
         util.printout("Checking if available for other Lua versions...")


         local lua_versions = supported_lua_versions(query)

         if #lua_versions ~= 0 then

            for i, lua_version in ipairs(lua_versions) do
               lua_versions[i] = "Lua " .. lua_version
            end

            local versions_message = "only " .. table.concat(lua_versions, " and ") ..
            " but not Lua " .. cfg.lua_version .. "."

            if #query.constraints == 0 then
               add = query.name .. " supports " .. versions_message
            elseif #query.constraints == 1 and query.constraints[1].op == "==" then
               local queryversion = tostring(query.constraints[1].version)
               add = query.name .. " " .. queryversion .. " supports " .. versions_message
            else
               add = "Matching " .. query.name .. " versions support " .. versions_message
            end
         else
            add = query.name .. " is not available for any Lua versions."
         end
      else
         add = "To check if it is available for other Lua versions, use --check-lua-versions."
      end
      err = err .. "\n" .. add
   end

   return nil, err
end

function search.find_src_or_rockspec(name, namespace, version, check_lua_versions)
   local query = queries.new(name, namespace, version, false, "src|rockspec")
   local url, err = search.find_rock_checking_lua_versions(query, check_lua_versions)
   if not url then
      return nil, "Could not find a result named " .. tostring(query) .. ": " .. err
   end
   return url
end




function search.print_result_tree(result_tree, porcelain)

   if porcelain then
      for packagestr, versions in util.sortedpairs(result_tree) do
         for version, repos in util.sortedpairs(versions, vers.compare_versions) do
            for _, repo in ipairs(repos) do
               local nrepo = dir.normalize(repo.repo)
               util.printout(packagestr, version, repo.arch, nrepo, repo.namespace)
            end
         end
      end
      return
   end

   for packagestr, versions in util.sortedpairs(result_tree) do
      local namespaces = {}
      for version, repos in util.sortedpairs(versions, vers.compare_versions) do
         for _, repo in ipairs(repos) do
            local key = repo.namespace or ""
            local list = namespaces[key] or {}
            namespaces[key] = list

            repo.repo = dir.normalize(repo.repo)
            table.insert(list, "   " .. version .. " (" .. repo.arch .. ") - " .. path.root_dir(repo.repo))
         end
      end
      for key, list in util.sortedpairs(namespaces) do
         util.printout(key == "" and packagestr or key .. "/" .. packagestr)
         for _, line in ipairs(list) do
            util.printout(line)
         end
         util.printout()
      end
   end
end

function search.pick_installed_rock(query, given_tree)

   local result_tree = {}
   local tree_map = {}
   local trees = cfg.rocks_trees
   if given_tree then
      trees = { given_tree }
   end
   for _, tree in ipairs(trees) do
      local rocks_dir = path.rocks_dir(tree)
      tree_map[rocks_dir] = tree
      search.local_manifest_search(result_tree, rocks_dir, query)
   end
   if not next(result_tree) then
      return nil, "cannot find package " .. tostring(query) .. "\nUse 'list' to find installed rocks."
   end

   if not result_tree[query.name] and next(result_tree, next(result_tree)) then
      local out = { "multiple installed packages match the name '" .. tostring(query) .. "':\n\n" }
      for name, _ in util.sortedpairs(result_tree) do
         table.insert(out, "   " .. name .. "\n")
      end
      table.insert(out, "\nPlease specify a single rock.\n")
      return nil, table.concat(out)
   end

   local repo_url

   local name, versions
   if result_tree[query.name] then
      name, versions = query.name, result_tree[query.name]
   else
      name, versions = util.sortedpairs(result_tree)()
   end

   local version, repositories = util.sortedpairs(versions, vers.compare_versions)()
   for _, rp in ipairs(repositories) do repo_url = rp.repo end

   local repo = tree_map[repo_url]
   return name, version, repo, repo_url
end

return search
