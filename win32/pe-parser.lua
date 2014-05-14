---------------------------------------------------------------------------------------
-- Lua module to parse a Portable Executable (.exe , .dll, etc.) file and extract metadata.
--
-- Version 0.1, [copyright (c) 2013 - Thijs Schreijer](http://www.thijsschreijer.nl)
-- @name pe-parser
-- @class module

local M = {}

--- Table with named constants/flag-constants.
-- Named elements can be looked up by their name in the `const` table. The sub tables are index by value.
-- For flag fields the name is extended with `_flags`.
-- @usage -- lookup descriptive name for the myobj.Magic value
-- local desc = pe.const.Magic(myobj.Magic)
-- 
-- -- get list of flag names, indexed by flag values, for the Characteristics field
-- local flag_list = pe.const.Characteristics_flags
M.const = {
  Magic = {
    ["10b"] = "PE32",
    ["20b"] = "PE32+",
  },
  Machine = {
    ["0"] = "IMAGE_FILE_MACHINE_UNKNOWN",
    ["1d3"] = "IMAGE_FILE_MACHINE_AM33",
    ["8664"] = "IMAGE_FILE_MACHINE_AMD64",
    ["1c0"] = "IMAGE_FILE_MACHINE_ARM",
    ["1c4"] = "IMAGE_FILE_MACHINE_ARMNT",
    ["aa64"] = "IMAGE_FILE_MACHINE_ARM64",
    ["ebc"] = "IMAGE_FILE_MACHINE_EBC",
    ["14c"] = "IMAGE_FILE_MACHINE_I386",
    ["200"] = "IMAGE_FILE_MACHINE_IA64",
    ["9041"] = "IMAGE_FILE_MACHINE_M32R",
    ["266"] = "IMAGE_FILE_MACHINE_MIPS16",
    ["366"] = "IMAGE_FILE_MACHINE_MIPSFPU",
    ["466"] = "IMAGE_FILE_MACHINE_MIPSFPU16",
    ["1f0"] = "IMAGE_FILE_MACHINE_POWERPC",
    ["1f1"] = "IMAGE_FILE_MACHINE_POWERPCFP",
    ["166"] = "IMAGE_FILE_MACHINE_R4000",
    ["1a2"] = "IMAGE_FILE_MACHINE_SH3",
    ["1a3"] = "IMAGE_FILE_MACHINE_SH3DSP",
    ["1a6"] = "IMAGE_FILE_MACHINE_SH4",
    ["1a8"] = "IMAGE_FILE_MACHINE_SH5",
    ["1c2"] = "IMAGE_FILE_MACHINE_THUMB",
    ["169"] = "IMAGE_FILE_MACHINE_WCEMIPSV2",
  },
  Characteristics_flags = {
    ["1"] = "IMAGE_FILE_RELOCS_STRIPPED",
    ["2"] = "IMAGE_FILE_EXECUTABLE_IMAGE",
    ["4"] = "IMAGE_FILE_LINE_NUMS_STRIPPED",
    ["8"] = "IMAGE_FILE_LOCAL_SYMS_STRIPPED",
    ["10"] = "IMAGE_FILE_AGGRESSIVE_WS_TRIM",
    ["20"] = "IMAGE_FILE_LARGE_ADDRESS_AWARE",
    ["40"] = "Reserved for future use",
    ["80"] = "IMAGE_FILE_BYTES_REVERSED_LO",
    ["100"] = "IMAGE_FILE_32BIT_MACHINE",
    ["200"] = "IMAGE_FILE_DEBUG_STRIPPED",
    ["400"] = "IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP",
    ["800"] = "IMAGE_FILE_NET_RUN_FROM_SWAP",
    ["1000"] = "IMAGE_FILE_SYSTEM",
    ["2000"] = "IMAGE_FILE_DLL",
    ["4000"] = "IMAGE_FILE_UP_SYSTEM_ONLY",
    ["8000"] = "IMAGE_FILE_BYTES_REVERSED_HI",
  },
  Subsystem = {
    ["0"] = "IMAGE_SUBSYSTEM_UNKNOWN",
    ["1"] = "IMAGE_SUBSYSTEM_NATIVE",
    ["2"] = "IMAGE_SUBSYSTEM_WINDOWS_GUI",
    ["3"] = "IMAGE_SUBSYSTEM_WINDOWS_CUI",
    ["7"] = "IMAGE_SUBSYSTEM_POSIX_CUI",
    ["9"] = "IMAGE_SUBSYSTEM_WINDOWS_CE_GUI",
    ["a"] = "IMAGE_SUBSYSTEM_EFI_APPLICATION",
    ["b"] = "IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER",
    ["c"] = "IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER",
    ["d"] = "IMAGE_SUBSYSTEM_EFI_ROM",
    ["e"] = "IMAGE_SUBSYSTEM_XBOX",
  },
  DllCharacteristics_flags = {
    ["40"] = "IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE",
    ["80"] = "IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY",
    ["100"] = "IMAGE_DLL_CHARACTERISTICS_NX_COMPAT",
    ["200"] = "IMAGE_DLLCHARACTERISTICS_NO_ISOLATION",
    ["400"] = "IMAGE_DLLCHARACTERISTICS_NO_SEH",
    ["800"] = "IMAGE_DLLCHARACTERISTICS_NO_BIND",
    ["2000"] = "IMAGE_DLLCHARACTERISTICS_WDM_DRIVER",
    ["8000"] = "IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE",
  },
  Sections = {
    Characteristics_flags = {
      ["8"] = "IMAGE_SCN_TYPE_NO_PAD",
      ["20"] = "IMAGE_SCN_CNT_CODE",
      ["40"] = "IMAGE_SCN_CNT_INITIALIZED_DATA",
      ["80"] = "IMAGE_SCN_CNT_UNINITIALIZED_ DATA",
      ["100"] = "IMAGE_SCN_LNK_OTHER",
      ["200"] = "IMAGE_SCN_LNK_INFO",
      ["800"] = "IMAGE_SCN_LNK_REMOVE",
      ["1000"] = "IMAGE_SCN_LNK_COMDAT",
      ["8000"] = "IMAGE_SCN_GPREL",
      ["20000"] = "IMAGE_SCN_MEM_PURGEABLE",
      ["20000"] = "IMAGE_SCN_MEM_16BIT",
      ["40000"] = "IMAGE_SCN_MEM_LOCKED",
      ["80000"] = "IMAGE_SCN_MEM_PRELOAD",
      ["100000"] = "IMAGE_SCN_ALIGN_1BYTES",
      ["200000"] = "IMAGE_SCN_ALIGN_2BYTES",
      ["300000"] = "IMAGE_SCN_ALIGN_4BYTES",
      ["400000"] = "IMAGE_SCN_ALIGN_8BYTES",
      ["500000"] = "IMAGE_SCN_ALIGN_16BYTES",
      ["600000"] = "IMAGE_SCN_ALIGN_32BYTES",
      ["700000"] = "IMAGE_SCN_ALIGN_64BYTES",
      ["800000"] = "IMAGE_SCN_ALIGN_128BYTES",
      ["900000"] = "IMAGE_SCN_ALIGN_256BYTES",
      ["a00000"] = "IMAGE_SCN_ALIGN_512BYTES",
      ["b00000"] = "IMAGE_SCN_ALIGN_1024BYTES",
      ["c00000"] = "IMAGE_SCN_ALIGN_2048BYTES",
      ["d00000"] = "IMAGE_SCN_ALIGN_4096BYTES",
      ["e00000"] = "IMAGE_SCN_ALIGN_8192BYTES",
      ["1000000"] = "IMAGE_SCN_LNK_NRELOC_OVFL",
      ["2000000"] = "IMAGE_SCN_MEM_DISCARDABLE",
      ["4000000"] = "IMAGE_SCN_MEM_NOT_CACHED",
      ["8000000"] = "IMAGE_SCN_MEM_NOT_PAGED",
      ["10000000"] = "IMAGE_SCN_MEM_SHARED",
      ["20000000"] = "IMAGE_SCN_MEM_EXECUTE",
      ["40000000"] = "IMAGE_SCN_MEM_READ",
      ["80000000"] = "IMAGE_SCN_MEM_WRITE",
    },
  },
  
}


--- convert integer to HEX representation
-- @param IN the number to convert to hex
-- @param len the size to return, any result smaller will be prefixed by "0"s
-- @return string containing hex representation
function M.toHex(IN, len)
    local B,K,OUT,I,D=16,"0123456789abcdef","",0
    while IN>0 do
        I=I+1
        IN,D=math.floor(IN/B),math.fmod(IN,B)+1
        OUT=string.sub(K,D,D)..OUT
    end
    len = len or string.len(OUT)
    if len<1 then len = 1 end
    return (string.rep("0",len) .. OUT):sub(-len,-1)
end

--- convert HEX to integer
-- @param IN the string to convert to dec
-- @return number in dec format
function M.toDec(IN)
  assert(type(IN)=="string")
  local OUT = 0
  IN = IN:lower()
  while #IN > 0 do
    local b = string.find("0123456789abcdef",IN:sub(1,1))
    OUT = OUT * 16 + (b-1)
    IN = IN:sub(2,-1)
  end
  return OUT
end

local function get_int(str)
  -- convert a byte-sequence to an integer
  assert(str)
  local r = 0
  for i = #str, 1, -1 do
    r = r*256 + string.byte(str,i,i)
  end
  return r
end

local function get_hex(str)
  -- convert a byte-sequence to a hex string
  assert(str)
  local r = ""
  for i = #str, 1, -1 do
    r = r .. M.toHex(string.byte(str,i,i),2)
  end
  while (#r > 1) and (r:sub(1,1) == "0") do
    r = r:sub(2, -1)
  end
  return r
end

local function get_list(list, f, add_to)
  -- list: list of tables with 'size' and 'name' and is_str
  -- f: file to read from
  -- add_to: table to add results to (optional)
  local r = add_to or {}
  for i, t in ipairs(list) do
    assert(r[t.name] == nil, "Value for '"..t.name.."' already set")
    local val,err = f:read(t.size)  -- read specified size in bytes
    val = val or "\0"    
    if t.is_str then   -- entry is marked as a string value, read as such
      for i = 1, #val do
        if val:sub(i,i) == "\0" then
          r[t.name] = val:sub(1,i-1)
          break
        end
      end
      r[t.name] = r[t.name] or val
    else  -- entry not marked, so always read as hex value
      r[t.name] = get_hex(val)
    end
  end
  return r
end

--- Calculates the fileoffset of a given RVA.
-- This function is also available as a method on the parsed output table
-- @param obj a parsed object (return value from `parse`)
-- @param RVA an RVA value to convert to a fileoffset (either number or hex-string)
-- @return fileoffset of the given RVA (number)
M.get_fileoffset = function(obj, RVA)
  -- given an object with a section table, and an RVA, it returns
  -- the fileoffset for the data
  if type(RVA)=="string" then RVA = M.toDec(RVA) end
  local section
  for i, s in ipairs(obj.Sections) do
    if M.toDec(s.VirtualAddress) <= RVA and M.toDec(s.VirtualAddress) + M.toDec(s.VirtualSize) >= RVA then
      section = s
      break
    end
  end
  if not section then return nil, "No match RVA with Section list, RVA out of bounds" end
  return RVA - M.toDec(section.VirtualAddress) + M.toDec(section.PointerToRawData)
end

local function readstring(f)
  -- reads a null-terminated string from the current file posistion
  local name = ""
  while true do
    local c = f:read(1)
    if c == "\0" then break end
    name = name .. c
  end
  return name
end

--- Parses a file and extracts the information.
-- All numbers are delivered as "string" types containing hex values, see `toHex` and `toDec` conversion functions.
-- @return table with data, or nil + error
-- @usage local pe = require("pe-parser")
-- local obj = pe.parse("c:\lua\lua.exe")
-- obj:dump()
M.parse = function(target)
  
  local list = {    -- list of known architectures
    [332]   = "x86",       -- IMAGE_FILE_MACHINE_I386
    [512]   = "x86_64",    -- IMAGE_FILE_MACHINE_IA64
    [34404] = "x86_64",    -- IMAGE_FILE_MACHINE_AMD64
  }
  
  local f, err = io.open(target, "rb")
  if not f then return nil, err end
  
  local MZ = f:read(2)
  if MZ ~= "MZ" then
    f:close()
    return nil, "Not a valid image"
  end
  
  f:seek("set", 60)                    -- position of PE header position
  local peoffset = get_int(f:read(4))  -- read position of PE header
  
  f:seek("set", peoffset)              -- move to position of PE header
  local out = get_list({
        { size = 4,
          name = "PEheader",
          is_str = true },
        { size = 2,
          name = "Machine" },
        { size = 2,
          name = "NumberOfSections"},
        { size = 4,
          name = "TimeDateStamp" },
        { size = 4,
          name = "PointerToSymbolTable"},
        { size = 4,
          name = "NumberOfSymbols"},
        { size = 2,
          name = "SizeOfOptionalHeader"},
        { size = 2,
          name = "Characteristics"},
      }, f)
  
  if out.PEheader ~= "PE" then
    f:close()
    return nil, "Invalid PE header"
  end
  out.PEheader = nil  -- remove it, has no value
  out.dump = M.dump  -- export dump function as a method
  
  if M.toDec(out.SizeOfOptionalHeader) > 0 then
    -- parse optional header; standard
    get_list({
        { size = 2,
          name = "Magic" },
        { size = 1,
          name = "MajorLinkerVersion"},
        { size = 1,
          name = "MinorLinkerVersion"},
        { size = 4,
          name = "SizeOfCode"},
        { size = 4,
          name = "SizeOfInitializedData"},
        { size = 4,
          name = "SizeOfUninitializedData"},
        { size = 4,
          name = "AddressOfEntryPoint"},
        { size = 4,
          name = "BaseOfCode"},
      }, f, out)
    local plus = (out.Magic == "20b")
    if not plus then -- plain PE32, not PE32+
      get_list({
          { size = 4,
            name = "BaseOfData" },
        }, f, out)
    end
    -- parse optional header; windows-fields
    local plussize = 4
    if plus then plussize = 8 end
    get_list({
        { size = plussize,
          name = "ImageBase"},
        { size = 4,
          name = "SectionAlignment"},
        { size = 4,
          name = "FileAlignment"},
        { size = 2,
          name = "MajorOperatingSystemVersion"},
        { size = 2,
          name = "MinorOperatingSystemVersion"},
        { size = 2,
          name = "MajorImageVersion"},
        { size = 2,
          name = "MinorImageVersion"},
        { size = 2,
          name = "MajorSubsystemVersion"},
        { size = 2,
          name = "MinorSubsystemVersion"},
        { size = 4,
          name = "Win32VersionValue"},
        { size = 4,
          name = "SizeOfImage"},
        { size = 4,
          name = "SizeOfHeaders"},
        { size = 4,
          name = "CheckSum"},
        { size = 2,
          name = "Subsystem"},
        { size = 2,
          name = "DllCharacteristics"},
        { size = plussize,
          name = "SizeOfStackReserve"},
        { size = plussize,
          name = "SizeOfStackCommit"},
        { size = plussize,
          name = "SizeOfHeapReserve"},
        { size = plussize,
          name = "SizeOfHeapCommit"},
        { size = 4,
          name = "LoaderFlags"},
        { size = 4,
          name = "NumberOfRvaAndSizes"},
      }, f, out)
    -- Read data directory entries
    for i = 1, M.toDec(out.NumberOfRvaAndSizes) do
      out.DataDirectory = out.DataDirectory or {}
      out.DataDirectory[i] = get_list({
          { size = 4,
            name = "VirtualAddress"},
          { size = 4,
            name = "Size"},
        }, f)
    end
    for i, name in ipairs{"ExportTable", "ImportTable", "ResourceTable",
        "ExceptionTable", "CertificateTable", "BaseRelocationTable",
        "Debug", "Architecture", "GlobalPtr", "TLSTable",
        "LoadConfigTable", "BoundImport", "IAT",
        "DelayImportDescriptor", "CLRRuntimeHeader", "Reserved"} do
      out.DataDirectory[name] = out.DataDirectory[i]
      if out.DataDirectory[name] then out.DataDirectory[name].name = name end
    end
  end
  
  -- parse section table
  for i = 1, M.toDec(out.NumberOfSections) do
    out.Sections = out.Sections or {}
    out.Sections[i] = get_list({
        { size = 8,
          name = "Name",
          is_str = true},
        { size = 4,
          name = "VirtualSize"},
        { size = 4,
          name = "VirtualAddress"},
        { size = 4,
          name = "SizeOfRawData"},
        { size = 4,
          name = "PointerToRawData"},
        { size = 4,
          name = "PointerToRelocations"},
        { size = 4,
          name = "PointerToLinenumbers"},
        { size = 2,
          name = "NumberOfRelocations"},
        { size = 2,
          name = "NumberOfLinenumbers"},
        { size = 4,
          name = "Characteristics"},
      }, f)
  end
  -- we now have section data, so add RVA convertion method
  out.get_fileoffset = M.get_fileoffset
  
  -- get the import table
  f:seek("set", out:get_fileoffset(out.DataDirectory.ImportTable.VirtualAddress))
  local done = false
  local cnt = 1
  while not done do
    local dll = get_list({
          { size = 4,
            name = "ImportLookupTableRVA"},
          { size = 4,
            name = "TimeDateStamp"},
          { size = 4,
            name = "ForwarderChain"},
          { size = 4,
            name = "NameRVA"},
          { size = 4,
            name = "ImportAddressTableRVA"},
        }, f)
    if M.toDec(dll.NameRVA) == 0 then
      -- this is the final NULL entry, so we're done
      done = true
    else
      -- store the import entry
      out.DataDirectory.ImportTable[cnt] = dll
      cnt = cnt + 1
    end
  end
  -- resolve imported DLL names
  for i, dll in ipairs(out.DataDirectory.ImportTable) do
    f:seek("set", out:get_fileoffset(dll.NameRVA))
    dll.Name = readstring(f)
  end
  
  f:close()
  return out
end

-- pad a string (prefix) to a specific length
local function pad(str, l, chr)
  chr = chr or " "
  l = l or 0
  return string.rep(chr,l-#str)..str
end

--- Dumps the output parsed.
-- This function is also available as a method on the parsed output table
M.dump = function(obj)
  local l = 0
  for k,v in pairs(obj) do if #k > l then l = #k end end
  
  for k,v in pairs(obj) do
    if (M.const[k] and type(v)=="string") then
      -- look up named value    
      print(k..string.rep(" ", l - #k + 1)..": "..M.const[k][v])
    elseif M.const[k.."_flags"] then
      -- flags should be listed
      print(k..string.rep(" ", l - #k + 1)..": "..v.." (flag field)")
    else
      -- regular values
      if type(v) == "number" then
        print(k..string.rep(" ", l - #k + 1)..": "..v.." (dec)")
      else
        if (type(v)=="string") and (k ~= "DataDirectory") and (k ~= "Sections") then
          print(k..string.rep(" ", l - #k + 1)..": "..v)
        end
      end
    end
  end
  
  if obj.DataDirectory then
    print("DataDirectory (RVA, size):")
    for i, v in ipairs(obj.DataDirectory) do
      print("   Entry "..M.toHex(i-1).." "..pad(v.VirtualAddress,8,"0").." "..pad(v.Size,8,"0").." "..v.name)
    end
  end
  
  if obj.Sections then
    print("Sections:")
    print("idx name     RVA      VSize    Offset   RawSize")
    for i, v in ipairs(obj.Sections) do
      print("  "..i.." "..v.Name.. string.rep(" ",9-#v.Name)..pad(v.VirtualAddress,8,"0").." "..pad(v.VirtualSize,8,"0").." "..pad(v.PointerToRawData,8,"0").." "..pad(v.SizeOfRawData,8,"0"))
    end
  end
  
  print("Imports:")
  for i, dll in ipairs(obj.DataDirectory.ImportTable) do
    print("   "..dll.Name)
  end
end

--- Checks the msvcrt dll the binary was linked against.
-- Mixing and matching dlls only works when they all are using the same runtime, if
-- not unexpected errors will probably occur.
-- Checks the binary provided and then traverses all imported dlls to find the msvcrt
-- used (it will only look for the dlls in the same directory).
-- @param infile binary file to check
-- @return msvcrt name (uppercase, without extension) + file where the reference was found, or nil + error
function M.msvcrt(infile) 
  local path, file = infile:match("(.+)\\(.+)$")
  if not path then
    path = ""
    file = infile
  else
    path=path .. "\\"
  end
  local obj, err = M.parse(path..file)
  if not obj then return obj, err end
  
  for i, dll in ipairs(obj.DataDirectory.ImportTable) do
    dll = dll.Name:upper()
	  local result = dll:match('(MSVCR%d*)%.DLL')
	  if not result then
	    result = dll:match('(MSVCRT)%.DLL')
	  end
    -- success, found it return name + binary where it was found
    if result then return result, infile end
  end
  
  -- not found, so traverse all imported dll's
  for i, dll in ipairs(obj.DataDirectory.ImportTable) do
    local rt, ref = M.msvcrt(path..dll.Name)
    if rt then 
      return rt, ref  -- found it
    end
  end

  return nil, "No msvcrt found"
end

return M
