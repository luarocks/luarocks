codes = true

ignore = {
   "6..",
   "542",
   "212",
   "213",
   "421/ok",
   "421/err",
   "421/errcode",
   "411/ok",
   "411/err",
   "411/errcode",
   "113/unpack",
   "211/require",
   "211/ok",
   "211/err",
   "211/errcode",
   "431/ok",
   "431/err",
   "431/errcode",
   "311/ok",
   "311/err",
   "311/errcode",
   "143/table.unpack",
}

exclude_files = {
   "src/luarocks/vendor/**/*.lua",
}

include_files = {
   "src/luarocks/**/*.lua"
}

unused_secondaries = false
