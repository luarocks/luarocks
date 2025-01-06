local lfs = require("lfs")

local args = {...}

if not args[1] then
   print("missing argument: <dirname>")
   os.exit(1)
end

local dirname = args[1]

local function path(filename: string): string
   return dirname .. "/" .. filename
end

local function process_md(filename: string)
   local data = assert(io.open(path(filename))):read("*a")
   local missing = {}
   for link in data:gmatch("%]%(([^)]*%.md)[^)]*%)") do
      if not lfs.attributes(path(link)) then
         table.insert(missing, { at = filename, link = link })
      end
   end
   
   if #missing == 0 then
      return
   end
   
   print("Broken links:")

   for _, link in ipairs(missing) do
      print("* At " .. link.at .. " : " .. link.link)
   end

   os.exit(1)
end 

local function check_index(filename: string, all_pages: {string: boolean})
   local data = assert(io.open(path(filename))):read("*a")
   for link in data:gmatch("%]%(([^)]*%.md)[^)]*%)") do
      all_pages[link] = nil
   end
   
   if not next(all_pages) then
      return
   end
   
   local missing = {}
   for k, _ in pairs(all_pages) do
      table.insert(missing, k)
   end
   table.sort(missing)
   
   print("Pages not referenced in index:")

   for _, page in ipairs(missing) do
      print("* " .. page)
   end

   os.exit(1)
end 

local all_pages = {}
for f in lfs.dir(args[1]) do
   if f:match("%.md$") then
      process_md(f)
      all_pages[f] = true
   end
end

check_index("index.md", all_pages)

print("All ok!")

