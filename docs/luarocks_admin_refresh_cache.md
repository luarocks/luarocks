# luarocks-admin refresh cache

Refresh local cache of a remote rocks server.

## Usage

`luarocks-admin refresh-cache [--from=<server>]`

The flag `--from` indicates which server to use. If not given, the default
server set in the `upload_server` variable from the [configuration
files](config_file_format.md) is used instead. You need to either explicitly
pass a full URL to `--from` or configure an upload server in your
configuration file prior to using the `refresh-cache` command.

## Examples

### Basic example

Refresh the cache of your main upload server:

```
luarocks-admin refresh-cache
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

you can specify which cache to refresh with the `--from` flag:

```
luarocks-admin refresh-cache --from=dev
```
