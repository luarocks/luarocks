# luarocks init


Initialize a directory for a Lua project using LuaRocks.

The command initializes a local [rocktree](rocks_repositories.md) which you can use to install dependencies dedicated to the project (Python user may think of a virtual environment). In addition, the command creates two wrapper scripts, `lua` and `luarocks`, which can be used to interact directly with the local rocktree and use the rocks installed there. `luarocks init` will also generate a [rockspec](rockspec_format.md) using the [`write_rockspec`](luarocks_write_rockspec.md) command, and a [`.gitignore`](https://git-scm.com/docs/gitignore) file.

## Usage

`[--wrapper-dir <wrapper_dir>] [--reset] [--no-wrapper-scripts] [--no-gitignore] [...]`

Initialize a directory for a Lua project using LuaRocks.

This command calls [`write_rockspec`](luarocks_write_rockspec.md) to write a rockspec file. The arguments of [`write_rockspec`](luarocks_write_rockspec.md) are also available to [`init`](luarocks_init.md).

Arguments:
* `--wrapper-dir <wrapper_dir>` sets the location where the 'lua' and 'luarocks' wrapper scripts should be generated; if not given, the current directory is used as a default.
* `--reset` deletes any `.luarocks/config-5.x.lua` and `./lua` and generate new ones.
* `--no-wrapper-scripts` prevents the generation of `./lua` and `./luarocks` launcher scripts.
* `--no-gitignore` prevents the generation of a `.gitignore` file.


## Example

Creating an scm rockspec for a project hosted in a Git repository:

```
mkdir lua-mylogger
cd lua-mylogger
git init .
git remote add origin https://github.com/my-username/lua-mylogger
luarocks init --license EUPL-1.2 \
    --summary "My fancy logger" \
    --lua-versions "5.1,5.2,5.3,5.4,5.5" \
    --rockspec-format "3.0"\
    lua-mylogger
```

This creates the following directory structure:
```
lua-mylogger
├── .gitignore
├── lua
├── lua_modules
│   └── lib
│       └── luarocks
│           └── rocks-5.5
├── lua-mylogger-dev-1.rockspec
├── .luarocks
│   ├── config-5.5.lua
│   └── default-lua-version.lua
└── luarocks
```

