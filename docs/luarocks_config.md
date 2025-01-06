# luarocks config

Query information about the LuaRocks configuration.

# Usage

```
luarocks config (<key> | <key> <value> --scope=<scope> | <key> --unset --scope=<scope> | )
```

When given a configuration key, it prints the value of that key
according to the currently active configuration (taking into account
all config files and any command-line flags passed)

Examples:

* `luarocks config lua_interpreter`
* `luarocks config variables.LUA_INCDIR`
* `luarocks config lua_version`

When given a configuration key and a value,
it overwrites the config file (see the --scope option below to determine which)
and replaces the value of the given key with the given value.

* `lua_dir` is a special key as it checks for a valid Lua installation
  (equivalent to --lua-dir) and sets several keys at once.
* `lua_version` is a special key as it changes the default Lua version
  used by LuaRocks commands (equivalent to passing --lua-version). 

Examples:

* `luarocks config variables.OPENSSL_DIR /usr/local/openssl`
* `luarocks config lua_dir /usr/local`
* `luarocks config lua_version 5.3`

When given a configuration key and --unset,
it overwrites the config file (see the --scope option below to determine which)
and deletes that key from the file.

Example: `luarocks config variables.OPENSSL_DIR --unset`

When given no arguments, it prints the entire currently active
configuration, resulting from reading the config files from
all scopes.

Example: `luarocks config`

## Options

```
--scope=<scope>   The scope indicates which config file should be rewritten.
                   Accepted values are "system", "user" or "project".
                   * Using a wrapper created with `luarocks init`,
                     the default is "project".
                   * Using --local (or when `local_by_default` is `true`),
                     the default is "user".
                   * Otherwise, the default is "system".

--json           Output as JSON
```
