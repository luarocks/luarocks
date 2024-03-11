package = "lua-bz2"
version = "0.2.1-1"
source = {
   url = "git+https://github.com/hishamhm/lua-bz2.git",
   tag = "0.2.1",
}
description = {
   summary = "A Lua binding to Julian Seward's libbzip2",
   detailed = [[
      Support for reading and writing .bz2 files
      and handling streams compressed in bzip2 format.
   ]],
   homepage = "https://github.com/harningt/lua-bz2",
   license = "ISC"
}
external_dependencies = {
   BZ2 = {
      library = "bz2"
   }
}
build = {
   type = "builtin",
   modules = {
      bz2 = {
         incdirs = {
            "$(BZ2_INCDIR)"
         },
         libdirs = {
            "$(BZ2_LIBDIR)"
         },
         libraries = {
            "bz2"
         },
         sources = {
            "lbz.c",
            "lbz2_common.c",
            "lbz2_file_reader.c",
            "lbz2_file_writer.c",
            "lbz2_stream.c",
         }
      },
      ["bz2.ltn12"] = "bz2/ltn12.lua",
   }
}
