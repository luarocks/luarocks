package = "LuaSec"
version = "1.3.2-1"
source = {
  url = "git+https://github.com/brunoos/luasec",
  tag = "v1.3.2",
}
description = {
   summary = "A binding for OpenSSL library to provide TLS/SSL communication over LuaSocket.",
   detailed = "This version delegates to LuaSocket the TCP connection establishment between the client and server. Then LuaSec uses this connection to start a secure TLS/SSL session.",
   homepage = "https://github.com/brunoos/luasec/wiki",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1", "luasocket"
}
external_dependencies = {
   platforms = {
      unix = {
         OPENSSL = {
            header = "openssl/ssl.h",
            library = "ssl"
         }
      },
      windows = {
         OPENSSL = {
            header = "openssl/ssl.h",
         }
      },
      mingw32 = {
         OPENSSL = {
            library = "ssl",
         }
      },
   }
}
build = {
   type = "builtin",
   copy_directories = {
      "samples"
   },
   platforms = {
      unix = {
         modules = {
            ['ssl.https'] = "src/https.lua",
            ['ssl.init'] = "src/ssl.lua",
            ssl = {
               defines = {
                  "WITH_LUASOCKET", "LUASOCKET_DEBUG",
               },
               incdirs = {
                  "$(OPENSSL_INCDIR)", "src/", "src/luasocket",
               },
               libdirs = {
                  "$(OPENSSL_LIBDIR)"
               },
               libraries = {
                  "ssl", "crypto"
               },
               sources = {
                  "src/options.c", "src/config.c", "src/ec.c",
                  "src/x509.c", "src/context.c", "src/ssl.c",
                  "src/luasocket/buffer.c", "src/luasocket/io.c",
                  "src/luasocket/usocket.c" -- , "src/luasocket/timeout.c"
               }
            }
         }
      },
      windows = {
         modules = {
            ['ssl.https'] = "src/https.lua",
            ['ssl.init'] = "src/ssl.lua",
            ssl = {
               defines = {
                  "WIN32", "NDEBUG", "_WINDOWS", "_USRDLL", "LSEC_EXPORTS", "BUFFER_DEBUG", "LSEC_API=__declspec(dllexport)",
                  "WITH_LUASOCKET", "LUASOCKET_DEBUG",
                  "LUASEC_INET_NTOP", "WINVER=0x0501", "_WIN32_WINNT=0x0501", "NTDDI_VERSION=0x05010300"
               },
               libdirs = {
                  "$(OPENSSL_LIBDIR)",
                  "$(OPENSSL_BINDIR)",
               },
               libraries = {
                  "ssl", "crypto", "ws2_32"
               },
               incdirs = {
                  "$(OPENSSL_INCDIR)", "src/", "src/luasocket"
               },
               sources = {
                  "src/options.c", "src/config.c", "src/ec.c",
                  "src/x509.c", "src/context.c", "src/ssl.c",
                  "src/luasocket/buffer.c", "src/luasocket/io.c",
                  "src/luasocket/timeout.c", "src/luasocket/wsocket.c"
               },
            },
         },
      },
   }
}
