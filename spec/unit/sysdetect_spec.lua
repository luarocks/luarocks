
local sysdetect = require("luarocks.core.sysdetect")
local lfs = require("lfs")

describe("luarocks.core.sysdetect #unix #unit", function()

   lazy_setup(function()
      os.execute([=[
         [ -e binary-samples ] || {
            git clone --depth=1 https://github.com/hishamhm/binary-samples
            ( cd binary-samples && git pull )
         }
      ]=])
   end)

   local files = {
      ["."] = "ignore",
      [".."] = "ignore",
      ["README.md"] = "ignore",
      [".git"] = "ignore",
      ["MIT_LICENSE"] = "ignore",
      ["anti-disassembler"] = "ignore",
      ["elf-Linux-lib-x64.so"] = "ignore",
      ["elf-Linux-lib-x86.so"] = "ignore",

      ["elf-Linux-x64-bash"] = {"linux", "x86_64"},
      ["elf-Linux-ia64-bash"] = {"linux", "ia_64"},
      ["MachO-OSX-ppc-and-i386-bash"] = {"macosx", "x86"},
      ["MachO-OSX-ppc-openssl-1.0.1h"] = {"macosx", "ppc"},
      ["MachO-iOS-armv7-armv7s-arm64-Helloworld"] = {"macosx", "arm"},
      ["pe-Windows-x64-cmd"] = {"windows", "x86_64"},
      ["MachO-iOS-armv7s-Helloworld"] = {"macosx", "arm"},
      ["elf-Linux-SparcV8-bash"] = {"linux", "sparcv8"},
      ["elf-HPUX-ia64-bash"] = {"hpux", "ia_64"},
      ["MachO-OSX-x64-ls"] = {"macosx", "x86_64"},
      ["pe-Windows-ARMv7-Thumb2LE-HelloWorld"] = {"windows", "armv7l"},
      ["elf-ARMv6-static-gofmt"] = {"sysv", "arm"},
      ["elf-Linux-s390-bash"] = {"linux", "s390"},
      ["elf-Linux-Alpha-bash"] = {"linux", "alpha"},
      ["elf-Linux-hppa-bash"] = {"linux", "hppa"},
      ["elf-Linux-x86_64-static-sln"] = {"linux", "x86_64"},
      ["elf-Linux-Mips4-bash"] = {"linux", "mips"},
      ["elf-ARMv6-dynamic-go"] = {"linux", "arm"},
      ["elf-Linux-SuperH4-bash"] = {"linux", "superh"},
      ["elf-Linux-x86-bash"] = {"linux", "x86"},
      ["elf-Linux-PowerPC-bash"] = {"linux", "ppc"},
      ["libSystem.B.dylib"] = {"macosx", "x86_64"},
      ["MachO-iOS-arm1176JZFS-bash"] = {"macosx", "arm"},
      ["pe-Windows-x86-cmd"] = {"windows", "x86"},
      ["elf-Linux-ARMv7-ls"] = {"linux", "arm"},
      ["elf-Linux-ARM64-bash"] = {"linux", "aarch64"},
      ["MachO-OSX-x86-ls"] = {"macosx", "x86"},
      ["elf-solaris-sparc-ls"] = {"solaris", "sparc"},
      ["elf-solaris-x86-ls"] = {"solaris", "x86"},
      ["pe-mingw32-strip.exe"] = {"windows", "x86"},
      ["elf-OpenBSD-x86_64-sh"] = {"openbsd", "x86_64"},
      ["elf-NetBSD-x86_64-echo"] = {"netbsd", "x86_64"},
      ["elf-FreeBSD-x86_64-echo"] = {"freebsd", "x86_64"},
      ["elf-Haiku-GCC2-ls"] = {"haiku", "x86"},
      ["elf-Haiku-GCC7-WebPositive"] = {"haiku", "x86"},
      ["pe-cygwin-ls.exe"] = {"cygwin", "x86"},
      ["elf-DragonFly-x86_64-less"] = {"dragonfly", "x86_64"},

   }

   describe("detect_file", function()
      it("detects system and processor", function()
         for f in lfs.dir("binary-samples") do
            if files[f] ~= "ignore" then
               assert.table(files[f], "unknown binary " .. f)
               local expected_s, expected_p = files[f][1], files[f][2]
               local s, p = sysdetect.detect_file("binary-samples/" .. f)
               assert.same(expected_s, s, "bad system for " .. f)
               assert.same(expected_p, p, "bad processor for " .. f)
            end
         end
      end)
   end)
end)
