local type r = require("luarocks.core.types.rockspec")
local type Test = r.Test

local record testrunner
    record TestRunner
        detect_type: function(): boolean
        run_tests: function(Test, {string}): boolean, string
     end
end
return testrunner