
local variables = {}

-- Expand variables in the format $foo or ${foo} according
-- to the variables table.
local function expand_variables(str)
   return str:gsub("%$({?)([A-Za-z0-9_]+)(}?)", function(o, v, c)
      return #o <= #c and (variables[v] or "") .. (#o < #c and c or "")
   end)
end

-- @param cmd command to run
-- @param envtable optional table of temporary environment variables
local function run(cmd, envtable)
   cmd = expand_variables(cmd)
   local env = {}
   for var, val in pairs(envtable) do
      table.insert(env, var.."='"..expand_variables(val).."' ")
   end
   local code = os.execute(table.concat(env)..cmd)
   return (code == 0 or code == true)
end

local function cd_run(dir, cmd, envtable)
   return run("cd "..dir.." && "..cmd, envtable)
end

local function run_get_contents(cmd)
end

local function mkdir(dirname)
   cmd = expand_variables(dirname)
   -- TODO
end

local function rm_rf(...)
   -- TODO
end

local function mv(src, dst)
   -- TODO
end

local function exists(filename)
   filename = expand_variables(filename)
   -- TODO
end

local function glob(patt)
   -- TODO
end

local function rm(...)
   for _, filename in ipairs {...} do
      filename = expand_variables(filename)
      -- TODO
   end
   return true
end

local function file_set_contents(filename, contents)
   filename = expand_variables(filename)

   local fd, err = io.open(filename, "w")
   if not fd then return nil, err end
   fd:write(contents)
   fd:close()
   return true
end

local function need_luasocket()
   -- TODO
end

local tests = {

   test_version = function() return run "$luarocks --version" end,
   fail_unknown_command = function() return run "$luarocks unknown_command" end,
   fail_arg_boolean_parameter = function() return run "$luarocks --porcelain=invalid" end,
   fail_arg_boolean_unknown = function() return run "$luarocks --invalid-flag" end,
   fail_arg_string_no_parameter = function() return run "$luarocks --server" end,
   fail_arg_string_followed_by_flag = function() return run "$luarocks --server --porcelain" end,
   fail_arg_string_unknown = function() return run "$luarocks --invalid-flag=abc" end,
   test_empty_list = function() return run "$luarocks list" end,
   fail_sysconfig_err = function()
      mkdir "$testing_lrprefix/etc/luarocks"
      file_set_contents("$testing_lrprefix/etc/luarocks/config.lua", "aoeui")
      return run "$luarocks list"
         and rm "$testing_lrprefix/etc/luarocks/config.lua"
   end,
   fail_sysconfig_default_err = function()
      mkdir "$testing_lrprefix/etc/luarocks"
      file_set_contents("$testing_lrprefix/etc/luarocks/config-$luashortversion.lua", "aoeui")
      return run "$luarocks list"
         and rm "$testing_lrprefix/etc/luarocks/config-$luashortversion.lua"
   end,
   fail_build_noarg = function() return run "$luarocks build" end,
   fail_download_noarg = function() return run "$luarocks download" end,
   fail_install_noarg = function() return run "$luarocks install" end,
   fail_lint_noarg = function() return run "$luarocks lint" end,
   fail_search_noarg = function() return run "$luarocks search" end,
   fail_show_noarg = function() return run "$luarocks show" end,
   fail_unpack_noarg = function() return run "$luarocks unpack" end,
   fail_upload_noarg = function() return run "$luarocks upload" end,
   fail_remove_noarg = function() return run "$luarocks remove" end,
   fail_doc_noarg = function() return run "$luarocks doc" end,
   fail_new_version_noarg = function() return run "$luarocks new_version" end,
   fail_write_rockspec_noarg = function() return run "$luarocks write_rockspec" end,
   fail_build_invalid = function() return run "$luarocks build invalid" end,
   fail_download_invalid = function() return run "$luarocks download invalid" end,
   fail_install_invalid = function() return run "$luarocks install invalid" end,
   fail_lint_invalid = function() return run "$luarocks lint invalid" end,
   fail_show_invalid = function() return run "$luarocks show invalid" end,
   fail_new_version_invalid = function() return run "$luarocks new_version invalid" end,
   test_list_invalidtree = function() return run "$luarocks --tree=/some/invalid/tree list" end,
   fail_inexistent_dir = function()
      -- Unix only?
      return run "mkdir idontexist; cd idontexist; rmdir ../idontexist; $luarocks; err=$?; cd ..; return $err"
   end,
   fail_make_norockspec = function() return run "$luarocks make" end,
   fail_build_permissions = function() return run "$luarocks build --tree=/usr lpeg" end,
   fail_build_permissions_parent = function() return run "$luarocks build --tree=/usr/invalid lpeg" end,
   test_build_verbose = function() return run "$luarocks build --verbose lpeg" end,
   fail_build_blank_arg = function() return run "$luarocks build --tree="" lpeg" end,
   test_build_withpatch = function() need_luasocket(); return run "$luarocks build luadoc" end,
   test_build_diffversion = function() return run "$luarocks build luacov ${version_luacov}" end,
   test_build_command = function() return run "$luarocks build stdlib" end,
   test_build_install_bin = function() return run "$luarocks build luarepl" end,
   test_build_nohttps = function()
      need_luasocket()
      return run "$luarocks download --rockspec validate-args ${verrev_validate_args}"
         and run "$luarocks build ./validate-args-${version_validate_args}-1.rockspec"
         and rm "./validate-args-${version_validate_args}-1.rockspec"
   end,
   test_build_https = function()
      need_luasocket()
      return run "$luarocks download --rockspec validate-args ${verrev_validate_args}"
         and run "$luarocks install luasec"
         and run "$luarocks build ./validate-args-${verrev_validate_args}.rockspec"
         and rm "./validate-args-${verrev_validate_args}.rockspec"
   end,
   test_build_supported_platforms = function() return run "$luarocks build lpty" end,
   test_build_only_deps_rockspec = function()
      return run "$luarocks download --rockspec lxsh ${verrev_lxsh}"
         and run "$luarocks build ./lxsh-${verrev_lxsh}.rockspec --only-deps"
         and (not run "$luarocks show lxsh")
   end,
   test_build_only_deps_src_rock = function()
      return run "$luarocks download --source lxsh ${verrev_lxsh}"
         and run "$luarocks build ./lxsh-${verrev_lxsh}.src.rock --only-deps"
         and (not run "$luarocks show lxsh")
   end,
   test_build_only_deps = function() return run "$luarocks build luasec --only-deps" and (not run "$luarocks show luasec") end,
   test_install_only_deps = function() return run "$luarocks install lxsh ${verrev_lxsh} --only-deps" and (not run "$luarocks show lxsh") end,
   fail_build_missing_external = function() return run '$luarocks build "$testing_dir/testfiles/missing_external-0.1-1.rockspec" INEXISTENT_INCDIR="/invalid/dir"' end,
   fail_build_invalidpatch = function()
      need_luasocket()
      return run '$luarocks build "$testing_dir/testfiles/invalid_patch-0.1-1.rockspec"'
   end,
   test_build_deps_partial_match = function() return run "$luarocks build lmathx" end,
   test_build_show_downloads = function()
      return run("$luarocks build alien", { LUAROCKS_CONFIG="$testing_dir/testing_config_show_downloads.lua" })
   end,
   test_download_all = function()
      return run "$luarocks download --all validate-args"
         and rm(glob("validate-args-*"))
   end,
   test_download_rockspecversion = function()
      return run "$luarocks download --rockspec validate-args ${verrev_validate_args}"
         and rm(glob("validate-args-*"))
   end,
   test_help = function() return run "$luarocks help" end,
   fail_help_invalid = function() return run "$luarocks help invalid" end,
   test_install_binaryrock = function()
      return run "$luarocks build --pack-binary-rock cprint"
         and run "$luarocks install ./cprint-${verrev_cprint}.${platform}.rock"
         and rm "./cprint-${verrev_cprint}.${platform}.rock"
   end,
   test_install_with_bin = function() return run "$luarocks install wsapi" end,
   fail_install_notazipfile = function() return run '$luarocks install "$testing_dir/testfiles/not_a_zipfile-1.0-1.src.rock"' end,
   fail_install_invalidpatch = function()
      need_luasocket()
      return run '$luarocks install "$testing_dir/testfiles/invalid_patch-0.1-1.rockspec"'
   end,
   fail_install_invalid_filename = function() return run '$luarocks install "invalid.rock"' end,
   fail_install_invalid_arch = function() return run '$luarocks install "foo-1.0-1.impossible-x86.rock"' end,
   test_install_reinstall = function()
      return run '$luarocks install "$testing_cache/luasocket-$verrev_luasocket.$platform.rock"'
         and run '$luarocks install --deps-mode=none "$testing_cache/luasocket-$verrev_luasocket.$platform.rock"'
   end,
   fail_local_root = function() return run("$luarocks install --local luasocket", { USER="root" }) end,
   test_site_config = function()
      mv("../src/luarocks/site_config.lua", "../src/luarocks/site_config.lua.tmp")
      local ok = run "$luarocks"
      mv("../src/luarocks/site_config.lua.tmp", "../src/luarocks/site_config.lua")
      return ok
   end,
   test_lint_ok = function()
      return run "$luarocks download --rockspec validate-args ${verrev_validate_args}"
         and run "$luarocks lint ./validate-args-${verrev_validate_args}.rockspec"
         and rm "./validate-args-${verrev_validate_args}.rockspec"
   end,
   fail_lint_type_mismatch_string = function() return run '$luarocks lint "$testing_dir/testfiles/type_mismatch_string-1.0-1.rockspec"' end,
   fail_lint_type_mismatch_version = function() return run '$luarocks lint "$testing_dir/testfiles/type_mismatch_version-1.0-1.rockspec"' end,
   fail_lint_type_mismatch_table = function() return run '$luarocks lint "$testing_dir/testfiles/type_mismatch_table-1.0-1.rockspec"' end,
   test_list = function() return run "$luarocks list" end,
   test_list_porcelain = function() return run "$luarocks list --porcelain" end,
   test_make_with_rockspec = function()
      return rm_rf "./luasocket-${verrev_luasocket}"
         and run "$luarocks download --source luasocket"
         and run "$luarocks unpack ./luasocket-${verrev_luasocket}.src.rock"
         and cd_run("luasocket-${verrev_luasocket}/${srcdir_luasocket}", "$luarocks make luasocket-${verrev_luasocket}.rockspec")
         and rm_rf "./luasocket-${verrev_luasocket}"
   end,
   test_make_default_rockspec = function()
      return rm_rf "./lxsh-${verrev_lxsh}"
         and run "$luarocks download --source lxsh ${verrev_lxsh}"
         and run "$luarocks unpack ./lxsh-${verrev_lxsh}.src.rock"
         and cd_run("lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1", "$luarocks make")
         and rm_rf "./lxsh-${verrev_lxsh}"
   end,
   test_make_pack_binary_rock = function()
      return rm_rf "./lxsh-${verrev_lxsh}"
         and run "$luarocks download --source lxsh ${verrev_lxsh}"
         and run "$luarocks unpack ./lxsh-${verrev_lxsh}.src.rock"
         and cd_run("lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1", "$luarocks make --deps-mode=none --pack-binary-rock")
         and exists "lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1/lxsh-${verrev_lxsh}.all.rock"
         and rm_rf "./lxsh-${verrev_lxsh}"
   end,
   fail_make_which_rockspec = function()
      rm_rf "./luasocket-${verrev_luasocket}"
      run "$luarocks download --source luasocket"
      run "$luarocks unpack ./luasocket-${verrev_luasocket}.src.rock"
      local ok = cd_run("luasocket-${verrev_luasocket}/${srcdir_luasocket}", "$luarocks make")
      rm_rf "./luasocket-${verrev_luasocket}"
      return ok
   end,
   test_new_version = function()
      return run "$luarocks download --rockspec luacov ${version_luacov}"
         and run "$luarocks new_version ./luacov-${version_luacov}-1.rockspec 0.2"
         and rm(glob("./luacov-0.*"))
   end,
   test_new_version_url = function()
      return run "$luarocks download --rockspec abelhas 1.0"
         and run "$luarocks new_version ./abelhas-1.0-1.rockspec 1.1 https://github.com/downloads/ittner/abelhas/abelhas-1.1.tar.gz"
         and rm(glob("./abelhas-*"))
   end,
   test_pack = function()
      return run "$luarocks list"
         and run "$luarocks pack luacov"
         and rm(glob("./luacov-*.rock"))
   end,
   test_pack_src = function()
      return run "$luarocks install luasec"
         and run "$luarocks download --rockspec luasocket"
         and run "$luarocks pack ./luasocket-${verrev_luasocket}.rockspec"
         and rm(glob("./luasocket-${version_luasocket}-*.rock"))
   end,
   test_path = function() return run "$luarocks path --bin" end,
   test_path_lr_path = function() return run "$luarocks path --lr-path" end,
   test_path_lr_cpath = function() return run "$luarocks path --lr-cpath" end,
   test_path_lr_bin = function() return run "$luarocks path --lr-bin" end,
   fail_purge_missing_tree = function() return run '$luarocks purge --tree="$testing_tree"' end,
   test_purge = function() return run '$luarocks purge --tree="$testing_sys_tree"' end,
   test_remove = function()
      return run "$luarocks build abelhas ${version_abelhas}"
         and run "$luarocks remove abelhas ${version_abelhas}"
   end,
   test_remove_force = function()
      need_luasocket()
      return run "$luarocks build lualogging"
         and run "$luarocks remove --force luasocket"
   end,
   fail_remove_deps = function()
      need_luasocket()
      return run "$luarocks build lualogging"
         and run "$luarocks remove luasocket"
   end,
   fail_remove_missing = function() return run "$luarocks remove missing_rock" end,
   fail_remove_invalid_name = function() return run "$luarocks remove invalid.rock" end,
   test_search_found = function() return run "$luarocks search zlib" end,
   test_search_missing = function() return run "$luarocks search missing_rock" end,
   test_show = function() return run "$luarocks show luacov" end,
   test_show_modules = function() return run "$luarocks show --modules luacov" end,
   test_show_home = function() return run "$luarocks show --home luacov" end,
   test_show_depends = function()
      need_luasocket()
      return run "$luarocks install luasec"
         and run "$luarocks show luasec"
   end,
   test_show_oldversion = function()
      return run "$luarocks install luacov ${version_luacov}"
         and run "$luarocks show luacov ${version_luacov}"
   end,
   test_unpack_download = function()
      return rm_rf "./cprint-${verrev_cprint}"
         and run "$luarocks unpack cprint"
         and rm_rf "./cprint-${verrev_cprint}"
   end,
   test_unpack_src = function()
      return rm_rf "./cprint-${verrev_cprint}"
         and run "$luarocks download --source cprint"
         and run "$luarocks unpack ./cprint-${verrev_cprint}.src.rock"
         and rm_rf "./cprint-${verrev_cprint}"
   end,
   test_unpack_rockspec = function()
      return rm_rf "./cprint-${verrev_cprint}"
         and run "$luarocks download --rockspec cprint"
         and run "$luarocks unpack ./cprint-${verrev_cprint}.rockspec"
         and rm_rf "./cprint-${verrev_cprint}"
   end,
   test_unpack_binary = function()
      return rm_rf "./cprint-${verrev_cprint}"
         and run "$luarocks build cprint"
         and run "$luarocks pack cprint"
         and run "$luarocks unpack ./cprint-${verrev_cprint}.${platform}.rock"
         and rm_rf "./cprint-${verrev_cprint}"
   end,
   fail_unpack_invalidpatch = function() 
      need_luasocket()
      return run '$luarocks unpack "$testing_dir/testfiles/invalid_patch-0.1-1.rockspec"'
   end,
   fail_unpack_invalidrockspec = function()
      need_luasocket()
      return run '$luarocks unpack "invalid.rockspec"'
   end,
   fail_upload_invalidrockspec = function() return run '$luarocks upload "invalid.rockspec"' end,
   fail_upload_invalidkey = function() return run '$luarocks upload --api-key="invalid" "invalid.rockspec"' end,
   test_admin_help = function() return run "$luarocks_admin help" end,
   test_admin_make_manifest = function() return run "$luarocks_admin make_manifest" end,
   test_admin_add_rsync = function() return run '$luarocks_admin --server=testing add "$testing_server/luasocket-${verrev_luasocket}.src.rock"' end,
   test_admin_add_sftp = function()
      return run("$luarocks_admin --server=testing add ./luasocket-${verrev_luasocket}.src.rock", { LUAROCKS_CONFIG="$testing_dir/testing_config_sftp.lua" })
   end,
   fail_admin_add_missing = function() return run "$luarocks_admin --server=testing add" end,
   fail_admin_invalidserver = function() return run '$luarocks_admin --server=invalid add "$testing_server/luasocket-${verrev_luasocket}.src.rock"' end,
   fail_admin_invalidrock = function() return run "$luarocks_admin --server=testing add invalid" end,
   test_admin_refresh_cache = function() return run "$luarocks_admin --server=testing refresh_cache" end,
   test_admin_remove = function() return run "$luarocks_admin --server=testing remove luasocket-${verrev_luasocket}.src.rock" end,
   fail_admin_remove_missing = function() return run "$luarocks_admin --server=testing remove" end,
   fail_deps_mode_invalid_arg = function() return run "$luarocks remove luacov --deps-mode" end,

   test_deps_mode_one = function()
      return run '$luarocks build --tree="system" lpeg'
         and run '$luarocks list'
         and run '$luarocks build --deps-mode=one --tree="$testing_tree" lxsh'
         and run_get_contents '$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg' ~= ""
   end,
   test_deps_mode_order = function()
      return run '$luarocks build --tree="system" lpeg'
         and run '$luarocks build --deps-mode=order --tree="$testing_tree" lxsh'
         and run '$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg'
         and run_get_contents '$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg' == ""
   end,
   test_deps_mode_order_sys = function()
      return run '$luarocks build --tree="$testing_tree" lpeg'
         and run '$luarocks build --deps-mode=order --tree="$testing_sys_tree" lxsh'
         and run_get_contents '$luarocks_noecho list --tree="$testing_sys_tree" --porcelain lpeg' ~= ""
   end,
   test_deps_mode_all_sys = function()
      return run '$luarocks build --tree="$testing_tree" lpeg'
         and run '$luarocks build --deps-mode=all --tree="$testing_sys_tree" lxsh'
         and run_get_contents '$luarocks_noecho list --tree="$testing_sys_tree" --porcelain lpeg' == ""
   end,

   test_deps_mode_none = function()
      return run '$luarocks build --tree="$testing_tree" --deps-mode=none lxsh'
         and run_get_contents '$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg' == ""
   end,
   test_deps_mode_nodeps_alias = function()
      return run '$luarocks build --tree="$testing_tree" --nodeps lxsh'
         and run_get_contents '$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg' == ""
   end,
   test_deps_mode_make_order = function()
      local ok = run '$luarocks build --tree="$testing_sys_tree" lpeg'
         and rm_rf "./lxsh-${verrev_lxsh}"
         and run "$luarocks download --source lxsh ${verrev_lxsh}"
         and run "$luarocks unpack ./lxsh-${verrev_lxsh}.src.rock"
         and cd_run("lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1", '$luarocks make --tree="$testing_tree" --deps-mode=order')
      if not ok then
         return false
      end
      local found = run_get_contents '$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg'
      rm_rf "./lxsh-${verrev_lxsh}"
      return found == ""
   end,
   test_deps_mode_make_order_sys = function()
      local ok = run '$luarocks build --tree="$testing_tree" lpeg'
         and rm_rf "./lxsh-${verrev_lxsh}"
         and run "$luarocks download --source lxsh ${verrev_lxsh}"
         and run "$luarocks unpack ./lxsh-${verrev_lxsh}.src.rock"
         and cd_run("lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1", '$luarocks make --tree="$testing_sys_tree" --deps-mode=order')
      if not ok then
         return false
      end
      local found = run_get_contents '$luarocks_noecho list --tree="$testing_sys_tree" --porcelain lpeg'
      rm_rf "./lxsh-${verrev_lxsh}"
      return found ~= ""
   end,   
   test_write_rockspec = function() return run "$luarocks write_rockspec git://github.com/keplerproject/luarocks" end,
   test_write_rockspec_lib = function() return run '$luarocks write_rockspec git://github.com/mbalmer/luafcgi --lib=fcgi --license="3-clause BSD" --lua-version=5.1,5.2' end,
   test_write_rockspec_fullargs = function() return run '$luarocks write_rockspec git://github.com/keplerproject/luarocks --lua-version=5.1,5.2 --license="MIT/X11" --homepage="http://www.luarocks.org" --summary="A package manager for Lua modules"' end,
   fail_write_rockspec_args = function() return run "$luarocks write_rockspec invalid" end,
   fail_write_rockspec_args_url = function() return run "$luarocks write_rockspec http://example.com/invalid.zip" end,
   test_write_rockspec_http = function() return run "$luarocks write_rockspec http://luarocks.org/releases/luarocks-2.1.0.tar.gz --lua-version=5.1" end,
   test_write_rockspec_basedir = function() return run "$luarocks write_rockspec https://github.com/downloads/Olivine-Labs/luassert/luassert-1.2.tar.gz --lua-version=5.1" end,
   test_doc = function()
      return run "$luarocks install luarepl"
         and run "$luarocks doc luarepl"
   end,
   
}
