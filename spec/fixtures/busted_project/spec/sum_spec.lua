
local sum = require("sum")

describe("sum", function()

   it("sums", function()
      assert.equal(2, sum.sum(1, 1))
   end)

end)
