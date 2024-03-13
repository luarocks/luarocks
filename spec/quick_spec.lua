local lfs = require("lfs")
local test_env = require("spec.util.test_env")
local quick = require("spec.util.quick")

describe("quick tests: #quick", function()
   before_each(function()
      test_env.setup_specs()
   end)

   local spec_quick = test_env.testing_paths.spec_dir .. "/quick"
   for f in lfs.dir(spec_quick) do
      if f:match("%.q$") then
         local tests = quick.compile(spec_quick .. "/" .. f, getfenv and getfenv() or _ENV)
         for _, t in ipairs(tests) do
            if not t.pending then
               it(t.name, t.fn)
            end
         end
      end
   end
end)

