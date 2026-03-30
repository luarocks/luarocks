# luarocks

**luarocks** is the command-line interface for LuaRocks, the Lua package manager.

## Usage

```
luarocks [--server=<server> | --only-server=<server>] [--tree=<tree>] [--only-sources=<url>] [--deps-mode=<mode>] [<VAR>=<VALUE>]... <command> [<argument>]
```

Variables from the "variables" table of the [configuration file](config_file_format.md) can be overridden with `VAR=VALUE` assignments.

### Options

- `--server=<server>`: Fetch rocks/rockspecs from this server (takes priority over config file).
- `--only-server=<server>`: Fetch rocks/rockspecs from this server only (overrides any entries in the config file).
- `--only-sources=<url>`: Restrict downloads of sources to URLs starting with the given URL. For example, `--only-sources=https://luarocks.org` will allow LuaRocks to download sources only if the URL given in the rockspec starts with `https://luarocks.org`.
- `--tree=<tree>`: Which tree to operate on.
- `--local`: Use the tree in the user's home directory. To enable it, see [`luarocks path`](luarocks_path.md).
- `--deps-mode=<mode>`: Select dependencies mode:
  - **one**: Consider only the tree at the top of the list (possibly, the one given by the `--tree` flag, overriding all entries from `rocks_trees`).
  - **all**: Consider all trees: if a dependency is installed in any tree of the `rocks_trees` list, we have a positive match.
  - **order**: Consider only trees starting from the "current" one in the order, where the "current" is either:
    - the one at the bottom of the `rocks_trees` list,
    - or one explicitly given with `--tree`,
    - or the "home" tree if `--local` was given or `local_by_default=true` is configured (usually at the top of the list).
- `--verbose`: Display verbose output of commands executed.
- `--timeout`: Timeout on network operations, in seconds. `0` means no timeout (wait forever). Default is `30`.

---

## Supported Commands

- **[build](luarocks_build.md)**: Build/compile and install a rock.
- **[doc](luarocks_doc.md)**: Shows documentation for an installed rock.
- **[download](luarocks_download.md)**: Download a specific rock or rockspec file from a rocks server.
- **[help](luarocks_help.md)**: Help on commands.
- **[install](luarocks_install.md)**: Install a rock.
- **[lint](luarocks_lint.md)**: Check syntax of a rockspec.
- **[list](luarocks_list.md)**: Lists currently installed rocks.
- **[config](luarocks_config.md)**: Query and set the LuaRocks configuration.
- **[make](luarocks_make.md)**: Compile package in the current directory using a rockspec and install it.
- **[new_version](luarocks_new_version.md)**: Auto-write a rockspec for a new version of a rock.
- **[pack](luarocks_pack.md)**: Create a rock, packing sources or binaries.
- **[path](luarocks_path.md)**: Return the currently configured package path.
- **[purge](luarocks_purge.md)**: Remove all installed rocks from a tree.
- **[remove](luarocks_remove.md)**: Uninstall a rock.
- **[search](luarocks_search.md)**: Query the LuaRocks repositories.
- **[test](luarocks_test.md)**: Run the test suite in the current directory.
- **[show](luarocks_show.md)**: Shows information about an installed rock.
- **[unpack](luarocks_unpack.md)**: Unpack the contents of a rock.
- **[upload](luarocks_upload.md)**: Upload a rockspec to the public rocks repository.
- **[write_rockspec](luarocks_write_rockspec.md)**: Write a template for a rockspec file.

---

## Overview of the Difference Between `make`, `build`, `install`, and `pack`

| Command                                   | Description                                                                                     |
|-------------------------------------------|-------------------------------------------------------------------------------------------------|
| `luarocks install modulename`             | Downloads a binary `.rock` file and installs it to the local tree (falls back to `luarocks build modulename` behavior if a binary rock is not found). |
| `luarocks build modulename`               | Downloads a `.src.rock` or a rockspec and builds+installs it to the local tree.                 |
| `luarocks build modulename-1.0-1.linux-x86.rock` | Extracts the rockspec from the rock and builds it as if the rockspec was passed in the command-line (i.e., redownloading sources and recompiling C modules if any). |
| `luarocks build modulename-1.0-1.rockspec` | Builds+installs the rock using the given rockspec, downloading the sources.                    |
| `luarocks make modulename-1.0-1.rockspec` | Builds+installs the rock using the rockspec and the contents of your current directory (kind of like the way `make` uses a Makefile) instead of downloading sources. |
| `luarocks pack modulename`                | Grabs the rock from your local tree and packs it into a binary `.rock` file.                   |
| `luarocks pack modulename-1.0-1.rockspec` | Downloads the sources from the URL and packs it into a `.src.rock` file.                       |
