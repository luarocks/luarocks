# luarocks-admin add

Add a rock or rockspec to a rocks server.

## Usage

`luarocks-admin add [--server=<server>] [--no-refresh] [--index] {<rockspec>|<rock>}...`

Arguments may be local rockspecs or rock files. The flag `--server` indicates
which server to use. If not given, the default server set in the
`upload_server` variable from the [configuration file](config_file_format.md)
is used instead. You need to either explicitly pass a full URL to `--server`
or configure an upload server in your configuration file prior to using the
`add` command.

Flags:

* `--no-refresh` - The local cache should not be refreshed prior to generation of the updated manifest.
* `--index` - Produce an `index.html` file for the manifest. This flag is automatically set if an `index.html` file already exists.

## Examples

### Basic example

Add a rockspec to your default configured upload server:

```
luarocks-admin add lpeg-0.9-1.rockspec
```

### Handling multiple repositories

Assuming your `~/.luarocks/config.lua` file looks like this:

```lua
upload_server = "main"
upload_servers = {
   main = {
      http = "www.example.com/repos/main",
      sftp = "myuser@example.com/var/www/repos/main"
   },
   dev = {
      http = "www.example.com/repos/devel-rocks",
      sftp = "myuser@example.com/var/www/repos/devel-rocks"
   },
}
```

you can specify which repository to use with the `--server` flag:

```
luarocks-admin add --server=dev my_rock-scm-1.rockspec
```
