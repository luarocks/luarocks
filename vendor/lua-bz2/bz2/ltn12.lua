local _M = {}
local bz2 = require("bz2")

_M.filter = {}
_M.source = {}
_M.sink = {}

local function buildProcessor(filter, err)
	if not filter then
		return nil, err
	end
	return function(chunk)
		if not filter then
			return nil, "closed"
		end
		-- Skip empty chunks due to unexpected 'flushing'
		if chunk and #chunk == 0 then
			return ""
		end
		-- On nil, update closes the stream out as ltn12 expects
		local ret, err = filter:update(chunk)
		if not chunk then
			filter:close()
			filter = nil
		end
		if not ret then
			return nil, err
		end
		return ret
	end

end

function _M.filter.compress(blockSize100k, verbosity, workFactor)
	return buildProcessor(bz2.initCompress(blockSize100k, verbosity, workFactor))
end

function _M.filter.decompress(verbosity, small)
	return buildProcessor(bz2.initDecompress(verbosity, small))
end

function _M.sink.file(name, blockSize100k, verbosity, workFactor)
	local writer, err = bz2.openWrite(name, blockSize100k, verbosity, workFactor)
	if not writer then
		return nil, err
	end
	return function(data)
		if not writer then
			return nil, "closed"
		end
		if not data then
			writer:close()
			writer = nil
			return
		end
		if #data == 0 then
			return 1
		end
		local ret, err = writer:write(data)
		if not ret then
			return nil, err
		end
		return 1
	end
end

function _M.source.file(name, verbosity, small)
	local reader, err = bz2.openRead(name, verbosity, small)
	if not reader then	
		return nil, err
	end
	return function()
		if not reader then
			return
		end
		local ret, err = reader:read(true)
		if ret and #ret == 0 then
			reader:close()
			reader = nil
			return
		end
		if not ret then
			return nil, err
		end
		if err then
			reader:close()
			reader = nil
		end
		return ret
	end
end

return _M
