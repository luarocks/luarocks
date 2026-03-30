# Creating a local LuaRocks server

This Docker based example shows how to create a local LuaRocks
server. This can be used to serve private rocks, or only curated rocks.

The rocks directory is "./rocks" (manifest file will be generated here, so
it only needs to contain the rock and rockspec files).
The server will be available at http://localhost:8080

Use LuaRocks with the following flag;

    --server http://localhost:8080

To ONLY use this server (a fully curated approach), use the following flag;

    --only-server http://localhost:8080


## Example script:
```bash
#!/usr/bin/env bash

# default rocks directory is "./rocks"
ROCKSDIR=$(pwd)/rocks
mkdir -p "$ROCKSDIR"

# generate a manifest file
docker run --rm -v "$ROCKSDIR":/rocks \
    akorn/luarocks:lua5.1-alpine \
    luarocks-admin make_manifest /rocks

# start nginx to serve rocks
docker run --rm --name luarocks-server \
    -v "$ROCKSDIR":/usr/share/nginx/html:ro \
    -p 8080:80 nginx
```
