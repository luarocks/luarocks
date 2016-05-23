local install = require( "luarocks.install")

local test_enviroment = require( "new_test/test_enviroment")
describe( 'basic test', function()
	it('trivial_test', function()
		test_enviroment.run()
		assert.are.same(1,1)
	end)
end)