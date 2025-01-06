# Hosting binary rocks

At the moment, LuaRocks.org hosts only rockspecs and src.rock files, and not
binary rocks. But you can host your own repository of binary rocks at any
static HTTP server (for example, Github Pages).

Suppose you want to host a binary rock for a rock of yours named `my_rock`:

Step 1: build your rocks with `luarocks build my_rock`. This will compile your
rocks locally in your system. After a successful build, you should see them
installed with `luarocks list`.

Step 2: create binary rocks from using `luarocks pack my_rock`. This will
create a binary rock file, named after your operating system and processor,
for example, `my_rock-1.0-1-macosx-x86_64.rock`. Note that this binary is
dependent on library versions of your own machine. This is more of an issue in
some operating systems than others (Linux binaries are very picky with library
dependencies, so it's helpful to build binaries on older distros for greater
compatibility.)

Step 2.5: if your rock has dependencies, repeat step 2 for them as well.

Step 3: create a new directory `my_dir`, copy your rock binary into it (and
possibly your rockspec and src.rock as well, for a nice one-stop-shop of your
rock) and run `luarocks-admin make-manifest my_dir`. This will create files
named `manifest-*` in it, which turn this directory into a working LuaRocks
server. You can even use it locally: `luarocks install --server=my_dir
my_rock` should work!

Step 4: upload the contents of `my_dir`, manifest files and rocks, into a HTTP
server and use its URL as the argument of `--server`. For example, if you
uploaded it into `http://example.com/binary-rock/manifest-5.3` and
`http://example.com/binary-rock/my-rock-1.0-1-macosx-x86_64.rock`, then using
`luarocks install --server=http://example.com/binary-rock my_rock` should
fetch the manifest, read it, find the rock name, download it and install it.

Note that in a repo that contains both binary and source rocks, running
`luarocks install http://example.com/binary-rock my_rock` will download and
install the binary rock, and  `luarocks build http://example.com/binary-rock
my_rock` will download, compile and install the source rock.

