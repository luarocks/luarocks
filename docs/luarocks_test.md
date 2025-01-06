# luarocks test

Run the test suite for the Lua project in the current directory.

## Usage

`luarocks test [-h] [--test-type <type>] [<rockspec>] [<args>] ...`

If the first argument is a rockspec, it will use it to determine the
parameters for running tests; otherwise, it will attempt to detect the
rockspec.

Any additional arguments are forwarded to the test suite. To make sure that
test suite flags are not interpreted as LuaRocks flags, use `--` to separate
LuaRocks arguments from test suite arguments.

### Arguments

* `rockspec` - Project rockspec.
* `args` - Test suite arguments.

### Options

* `--test-type <type>` - Specify the test suite type manually if it was not
  specified in the rockspec and it could not be auto-detected.

## Test types

There are two test types that ship by default with LuaRocks: `busted` and
`command`. They can be specified explicitly in a rockspec in the `test.type`
field. Custom test types can be loaded using the `test_dependencies` field; a
dependency can declare a new test type by adding a module in the
`luarocks.test.*` namespace; it can then be used as a test type in the
rockspec.

### `busted` test type

You can enable the `busted` test type adding a top-level `test` table in a
rockspec and setting its `type` to `busted`. The `busted` type can be
auto-detected if the project's source contains a configuration file called
`.busted`, so if a project has that file `luarocks test` can be used to launch
Busted even if it doesn't have a `test` section in the rockspec. 

Here's an example of a `busted` test section, also using the `flags` option to
pass extra flags to Busted, and using per-platform overrides.

```
test = {
   type = "busted",
   platforms = {
      windows = {
         flags = { "--exclude-tags=ssh,git,unix" }
      },
      unix = {
         flags = { "--exclude-tags=ssh,git" }
      }
   }
}
```

### `command` test type

You can enable the `command` test type adding a top-level `test` table in a
rockspec and setting its `type` to `command`. The `command` type can be
auto-detected if the project's source contains a file called `test.lua` at the
root of the source tree, so if a project has that file `luarocks test` can be
used to run it using the default Lua interpreter even if it doesn't have a
`test` section in the rockspec.

The `test` block for a `command` test type can take either a `script`
argument, which is a Lua script to be launched using the configured Lua
interpreter, or a `command` argument, which is a command to be launched
directly on a shell. Both can take additional arguments via the `flags` array
entry.

Here is an example using a script:

```
test = {
   type = "command",
   script = "tests/test_all.lua",
}
```

And here is an example using a command:

```
test = {
   type = "command",
   command = "make test",
}
```

## Invocation example

In the following example, assume a project uses Busted as its test tool. The
current directory contains the source code of a Lua project with a rockspec in
its root, this will run Busted, pass any additional arguments specified in the
`test.flags` field of the rockspec, plus the `--exclude-tags=ssh` argument
given explicitly via the command-line:

```
luarocks test -- --exclude-tags=ssh
```
