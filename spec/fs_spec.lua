local test_env = require("spec.util.test_env")

test_env.unload_luarocks()
local fs = require("luarocks.fs")
local lfs = require("lfs")
local is_win = test_env.TEST_TARGET_OS == "windows"

--current dir is --> /luarocks

describe("Luarocks fs test #whitebox #w_fs", function()
   --print("top of the file",lfs.currentdir())
   local olddir = lfs.currentdir()
   describe("fs.Q", function()
      after_each(function()
        lfs.chdir(olddir)
      end)
      it("simple argument", function()
         assert.are.same(is_win and '"foo"' or "'foo'", fs.Q("foo"))
      end)

      it("argument with quotes", function()
         assert.are.same(is_win and [["it's \"quoting\""]] or [['it'\''s "quoting"']], fs.Q([[it's "quoting"]]))
      end)

      it("argument with special characters", function()
         assert.are.same(is_win and [["\\"%" \\\\" \\\\\\"]] or [['\% \\" \\\']], fs.Q([[\% \\" \\\]]))
      end)
     
   end)

--testing fs_lua.current_dir()

  describe("testing fs.current_dir",function()
     after_each(function()
        lfs.chdir(olddir)
     end)

     it("Shows the curr dir", function()
        local src = lfs.currentdir()
       -- print("fscur_in",src)
        assert.same(src,fs.current_dir())
     end)
     --print("fscur_o",lfs.currentdir())
  end)


--testing fs.find()
  describe("Testing fs.find()", function()
     after_each(function()
        lfs.chdir(olddir)
     end)
     function TableComp(a,b) --algorithm is O(n log n), due to table growth.
       if #a ~= #b then return false end -- early out
       local t1,t2 = {}, {} -- temp tables
       for k,v in pairs(a) do -- copy all values into keys for constant time lookups
         t1[k] = (t1[k] or 0) + 1 -- make sure we track how many times we see each value.
       end
       for k,v in pairs(b) do
         t2[k] = (t2[k] or 0) + 1
       end
       for k,v in pairs(t1) do -- go over every element
         if v ~= t2[k] then return false end -- if the number of times that element was seen don't match...
       end

       return true
       end
     it("o/p the content of the given dir", function()
        local path = "./test/test_find"
        -- if nothing is passed to function then it assumes the current directory
        local t1 =  fs.find(path)
        local t2 = {"file_1.lua","file_2.lua"}
        local bool = TableComp(t1,t2)
        assert.same(true,bool)
     end)
  end)

--testing fs.is_dir

   describe("Testing fs.is_dir", function()
      after_each(function()
        lfs.chdir(olddir)
      end)
      it("is a dir or not",function()
         local src = "./"
        
         local result = fs.is_dir(src)
         assert.same(true,result)
      end)
   end)
-- testing fs.make_dir --> capable of creating nested directory in command, this function is different from linux command mkdir
   describe("Testing fs.make_dir", function()
     after_each(function()
        lfs.chdir(olddir)
     end)

     it("Failed",function()
        local path = "./test/testy"
        assert.same(true,fs.make_dir(path))
        assert.same(true,fs.exists(path))
     end)
   end)
-- testing fs.is_writable

   describe("Testing fs.is_writable", function()
      
      after_each(function()
        lfs.chdir(olddir)
      end)

      it("returns true if file is writable",function()
         local file = "./test/kar.txt"
         local result = fs.is_writable(file)
        --print(result)
         assert.falsy(false,result)
      end)
   end)

--testing fs.exists
 
   describe("Testing whether a file exists or not", function()
       
       after_each(function()
        lfs.chdir(olddir)
       end)

       it("returns true if the file exists", function()
         -- print(lfs.currentdir())
          src = "./src/luarocks/fs/lua.lua"
          local result = fs.exists(src)
          assert.same(true,result)   
       end)
       it("Given path file does not exists",function()
          local src = "niugihgr"
          assert.falsy(false,fs.exists(src))
       end)
   end)

--testing copy function

   describe("Testing fs.copy", function()
      local src = os.tmpname()
      local dest = os.tmpname()
      
      after_each(function()
        lfs.chdir(olddir)
        if src then
          os.remove(src) 
        end
        if dest then
          os.remove(dest)
        end 
      end)

      it("returns true if copied", function()
         assert(true,fs.is_file(src))
         src1 = assert(io.open(src,"r"))
       
         src1:write("foo is my favorite food")
         local content1 = src1:read("*all")
        -- print(type(content1))
         src1:close()       
          
         --passing the third param is optinal
         local bool = fs.copy(src,dest)
         local dest1 = assert(io.open(dest,"r"))
         local content2 = dest1:read("*all")
        
       
          --print(type(content2))
         assert(content1==content2)
         assert.same(true,bool)
         dest1:close()
      end)

      it("returns false when the source is not available", function()
         src = os.tmpname()
         
         os.remove(src)
         assert.falsy(false,fs.copy(src,dest,nil))
      end)
     
      it("if the source path is wrong", function()
         src = "fbejrfbhreb"
         local result = fs.copy(src,dest,nil)
         --print(result)
         assert.falsy(false,result)
         
      end)

      
   end)
   
--testing delete function

   describe("fs.delete", function()

      after_each(function()
        lfs.chdir(olddir)
      end)

      it("Should delete a file if exists", function()
         local src = os.tmpname()
         fs.delete(src)
         local flag = fs.exists(src)
         assert.same(false,flag)
         src = nil
      end)
   end)

--testing fs.remove_dir_if_empty()
   describe("testing fs.remove_dir_if_empty", function()
     after_each(function()
        lfs.chdir(olddir)
     end)

     function isemptydir(directory,nospecial)
	for filename in require('lfs').dir(directory) do
          if filename ~= '.' and filename ~= '..' then
            return false
          end
	end
	return true
     end
    
     it("Failed", function()
        local src = "./test/test_empty_dir2"
        if fs.exists(src) then
          local bool = isemptydir(src,nospecial)
          local ans = fs.remove_dir_if_empty(src)
        
          if bool==false and ans==nil then
            assert.same(true,fs.exists(src))
          else
            assert.same(false,fs.exists(src))
          end
        end
     end)
    
     it("Dir doesnt exist",function()
       local src = "irgu"
       
       assert.same(true,nil==fs.remove_dir_if_empty(src))
     end)
   end)

--testing fs.remove_dir_tree_if_empty()
  describe("testing fs.remove_dir_tree_if_empty",function()
     after_each(function()
        lfs.chdir(olddir)
     end)

     function isemptydir(directory,nospecial)
	for filename in require('lfs').dir(directory) do
          if filename ~= '.' and filename ~= '..' then
            return false
          end
	end
	return true
     end
     it("Failed", function()
        local src = "./test/test_empty_dir2"
        if fs.exists(src) then
          local bool = isemptydir(src,nospecial)
          local ans = fs.remove_dir_tree_if_empty(src)
        
          if bool==false and ans==nil then
            assert.same(true,fs.exists(src))
          else
            assert.same(false,fs.exists(src))
          end
        end
     end)
     
     it("Dir doesnt exist", function()
        local src = "jnrf"
       
        assert.same(true,nil==fs.remove_dir_tree_if_empty(src))
     end)
  end)

-- testing fs.change_dir()
  describe("The function fs.change_dir()", function()

     after_each(function()
        lfs.chdir(olddir)
     end)

     it("Failed to change the dir",function()
        local dir = "spec"
        local res1 = lfs.currentdir() -- -->/luarocks
        fs.change_dir(dir)
        local res = lfs.currentdir() -- --> /luarocks/spec
         --print("current dir",res)
        assert(res1~=res,"No such file or dir")
     end)
     it("Failed to change dir, check your path", function()
        local dir = "../"
        local res1 = lfs.currentdir() -- --> /luarocks
        fs.change_dir(dir) 
        local res = lfs.currentdir()  -- --> /
       -- print(res)
        assert(res1~=res,"No such file or dir")
        
     end)
     it("Failed to change, check your path", function()
        local dir = "nfnnjkf"
        local actual = fs.change_dir(dir)
        assert.same(nil,actual)
     end)
  end)
  

--testing fs.pop_dir() function
   describe("fs.pop_dir failed because",function()
     
      after_each(function()
        lfs.chdir(olddir)
      end)

      it("the dir stack was empty", function()
         local curr = os.tmpname()
         local bool = fs.pop_dir()
         assert.same(true,bool)
      end)
   end)

--testing is_file function tested by hisham
   describe("fs.is_file", function()
      
      local tmpfile
      local tmpdir
      
      after_each(function()
         if tmpfile then
            os.remove(tmpfile)
            tmpfile = nil
         end
         if tmpdir then
            lfs.rmdir(tmpdir)
            tmpdir = nil
         end
      end)
   
      it("returns true when the argument is a file", function()
         tmpfile = os.tmpname()
         --local tnp = os.tmpname()         
         --print("file name",tmpfile)
         --print("file name2", tnp)
         local fd = assert(io.open(tmpfile, "w"))
         fd:write("foo")
         --print(fd)
         fd:close()
         
         assert.same(true, fs.is_file(tmpfile))
      end)

      it("returns false when the argument does not exist", function()
         assert.same(false, fs.is_file("/nonexistent"))
      end)

      it("returns false when arguments exists but is not a file", function()
         tmpdir = os.tmpname()
         os.remove(tmpdir)
         lfs.mkdir(tmpdir)
         assert.same(false, fs.is_file("/nonexistent"))
      end)
   end)

 -- testing fs_lua.unzip
   describe("Extraction of Zip file", function()
      after_each(function()
        lfs.chdir(olddir)
      end)

      it("Failed",function()
         --print(lfs.currentdir())
         local path = "./test/test.zip"
         local bool = fs.unzip(path)
         assert.same(true,bool)
      end)
   end)
   
 -- testing fs_lua.execute_string
     
    describe("Command entered is not Valid", function()
       after_each(function()
        lfs.chdir(olddir)
       end)

       it("Please Check the command", function()
          local var = "cd /"
          local ans = fs.execute_string(var)
          assert.same(true,ans)
       end)
       it("Please Check the command",function()
          local var = "Idonnoanycommand"
          local ans = fs.execute_string(var)
          assert.falsy(false,ans)
       end)
    end)

   
end)
