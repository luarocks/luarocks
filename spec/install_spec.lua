local install = require("luarocks.install")
local test_enviroment = require( "new_test/test_enviroment")

local test_utils = test_enviroment.main(arg)

describe( 'basic test', function()
	it('trivial_test', function()
		test_enviroment.reset_environment(test_utils.testing_paths, test_utils.md5sums)
		print("EXECUTING TEST")
		test_enviroment.execute_bool("luarocks path --bin", false, test_utils.testing_env_variables)
		assert.are.same(1,1)
	end)
end)