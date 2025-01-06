# LuaRocks through a proxy

LuaRocks performs network access through either helper applications (typically
`curl` on macOS, or `wget` on other platforms), or using built-in modules
LuaSocket and LuaSec. All of them use the same method to configure proxies:
the `http_proxy`, `https_proxy` and `ftp_proxy` environment variables.

## Environment variable example

On Unix systems, you can set the `http_proxy` environment variable like
this:

    export http_proxy=http://server:1234

On Windows systems, the command syntax is:

    set http_proxy=http://server:1234

## Git

If you are behind a firewall that blocks the `git://` protocol, you may
configure your Git to use HTTPS instead. The solution is to tell Git to always
use HTTPS instead of `git://` by running the following command:

    git config --global url."https://".insteadOf git://

This adds the following to your `~/.gitconfig`:

    [url "https://"]
       insteadOf = git://

## External references

* [curl manpage](http://www.hmug.org/man/1/curl.php)
* ["How to use wget through proxy"](http://blog.taragana.com/index.php/archive/how-to-use-wget-through-proxy/)
* ["Tell git to use https instead of git protocol"](http://jgoodall.me/posts/2013/05/29/git-use-https)
