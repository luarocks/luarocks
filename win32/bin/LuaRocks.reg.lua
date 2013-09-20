-- Call this file using its full path and the template file as a parameter;
--
-- C:\> lua.exe "create_reg_file.lua" "c:\luarocks\2.0\LuaRocks.reg.template"
--
-- it will strip the ".template" extension and write to that file the
-- template contents, where "<LUAROCKSPATH>" will be replaced by the path
-- to LuaRocks (including the trailing backslash)



-- Check argument
local f = (arg or {})[1]
if not f then
  print("must provide template file on command line")
  os.exit(1)
end

-- cleanup filepath, remove all double backslashes
while f:match("\\\\") do
  f =  f:gsub("\\\\", "\\")
end

-- extract path and name from argument
local p = ""
local ni = f
for i = #f, 1, -1 do
  if f:sub(i,i) == "\\" then
    ni = f:sub(i+1)
    p = f:sub(1, i)
    break
  end
end

-- create output name
local no = ni:gsub("%.template","")

-- create path substitute; escape backslash by doubles
local ps = p:gsub("\\", "\\\\")

-- read template
local fh = io.open(f)
local content = fh:read("*a")
fh:close()

-- fill template
content = content:gsub("%<LUAROCKSPATH%>", ps)

-- write destination file
fh = io.open(p..no, "w+")
fh:write(content)
fh:close()
