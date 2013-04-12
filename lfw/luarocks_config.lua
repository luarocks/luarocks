local LFW_ROOT = config.LFW_ROOT
rocks_servers = {
   [[http://luarocks.org/repositories/rocks]]
}
rocks_trees = {
   { root = LFW_ROOT, rocks_dir = LFW_ROOT..[[\rocks]],
     bin_dir = LFW_ROOT, lua_dir = LFW_ROOT..[[\lua]],
     lib_dir = LFW_ROOT..[[\clibs]] }
}
variables.WRAPPER = LFW_ROOT..[[\rclauncher.c]]
