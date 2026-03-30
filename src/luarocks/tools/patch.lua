local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table









local patch = { Lineends = {}, Hunk = {}, File = {}, Files = {} }































local fs = require("luarocks.fs")






local function open(filename, mode)
   return assert(io.open(fs.absolute_name(filename), mode))
end


local debugmode = false
local function dbg(_) end
local function info(_) end
local function warning(s) io.stderr:write(s .. '\n') end


local function startswith(s, s2)
   return s:sub(1, #s2) == s2
end


local function endswith(s, s2)
   return #s >= #s2 and s:sub(#s - #s2 + 1) == s2
end


local function endlstrip(s)
   return s:gsub('[\r\n]+$', '')
end


local function table_copy(t)
   local t2 = {}
   for k, v in pairs(t) do t2[k] = v end
   return t2
end

local function string_as_file(s)
   return {
      at = 0,
      str = s,
      len = #s,
      eof = false,
      read = function(self, n)
         if self.eof then return nil end
         local chunk = self.str:sub(self.at, self.at + n - 1)
         self.at = self.at + n
         if self.at > self.len then
            self.eof = true
         end
         return chunk
      end,
      close = function(self)
         self.eof = true
      end,
   }
end










local function file_lines(f)
   local CHUNK_SIZE = 1024
   local buffer = ""
   local pos_beg = 1
   return function()
      local pos, chars
      while 1 do
         pos, chars = buffer:match('()([\r\n].)', pos_beg)
         if pos or not f then
            break
         elseif f then
            local chunk = f:read(CHUNK_SIZE)
            if chunk then
               buffer = buffer:sub(pos_beg) .. chunk
               pos_beg = 1
            else
               f = nil
            end
         end
      end
      if not pos then
         pos = #buffer
      elseif chars == '\r\n' then
         pos = pos + 1
      end
      local line = buffer:sub(pos_beg, pos)
      pos_beg = pos + 1
      if #line > 0 then
         return line
      end
   end
end

local function match_linerange(line)
   local m1, m2, m3, m4 = line:match("^@@ %-(%d+),(%d+) %+(%d+),(%d+)")
   if not m1 then m1, m3, m4 = line:match("^@@ %-(%d+) %+(%d+),(%d+)") end
   if not m1 then m1, m2, m3 = line:match("^@@ %-(%d+),(%d+) %+(%d+)") end
   if not m1 then m1, m3 = line:match("^@@ %-(%d+) %+(%d+)") end
   return m1, m2, m3, m4
end

local function match_epoch(str)
   return str:match("[^0-9]1969[^0-9]") or str:match("[^0-9]1970[^0-9]")
end

function patch.read_patch(filename, data)

   local state = 'header'






   local all_ok = true
   local lineends = { lf = 0, crlf = 0, cr = 0 }
   local files = { source = {}, target = {}, epoch = {}, hunks = {}, fileends = {}, hunkends = {} }
   local nextfileno = 0
   local nexthunkno = 0



   local hunkinfo = {
      startsrc = nil, linessrc = nil, starttgt = nil, linestgt = nil,
      invalid = false, text = {},
   }
   local hunkactual = { linessrc = nil, linestgt = nil }

   info(string.format("reading patch %s", filename))

   local fp
   if data then
      fp = string_as_file(data)
   else
      fp = filename == '-' and io.stdin or open(filename, "rb")
   end
   local lineno = 0

   for line in file_lines(fp) do
      lineno = lineno + 1
      if state == 'header' then
         if startswith(line, "--- ") then
            state = 'filenames'
         end

      end
      if state == 'hunkbody' then


         if line:match("^[\r\n]*$") then

            line = " " .. line
         end


         if line:match("^[- +\\]") then

            local he = files.hunkends[nextfileno]
            if endswith(line, "\r\n") then
               he.crlf = he.crlf + 1
            elseif endswith(line, "\n") then
               he.lf = he.lf + 1
            elseif endswith(line, "\r") then
               he.cr = he.cr + 1
            end
            if startswith(line, "-") then
               hunkactual.linessrc = hunkactual.linessrc + 1
            elseif startswith(line, "+") then
               hunkactual.linestgt = hunkactual.linestgt + 1
            elseif startswith(line, "\\") then

            else
               hunkactual.linessrc = hunkactual.linessrc + 1
               hunkactual.linestgt = hunkactual.linestgt + 1
            end
            table.insert(hunkinfo.text, line)

         else
            warning(string.format("invalid hunk no.%d at %d for target file %s",
            nexthunkno, lineno, files.target[nextfileno]))

            table.insert(files.hunks[nextfileno], table_copy(hunkinfo))
            files.hunks[nextfileno][nexthunkno].invalid = true
            all_ok = false
            state = 'hunkskip'
         end


         if hunkactual.linessrc > hunkinfo.linessrc or
            hunkactual.linestgt > hunkinfo.linestgt then

            warning(string.format("extra hunk no.%d lines at %d for target %s",
            nexthunkno, lineno, files.target[nextfileno]))

            table.insert(files.hunks[nextfileno], table_copy(hunkinfo))
            files.hunks[nextfileno][nexthunkno].invalid = true
            state = 'hunkskip'
         elseif hunkinfo.linessrc == hunkactual.linessrc and
            hunkinfo.linestgt == hunkactual.linestgt then

            table.insert(files.hunks[nextfileno], table_copy(hunkinfo))
            state = 'hunkskip'


            local ends = files.hunkends[nextfileno]
            if (ends.cr ~= 0 and 1 or 0) + (ends.crlf ~= 0 and 1 or 0) +
               (ends.lf ~= 0 and 1 or 0) > 1 then

               warning(string.format("inconsistent line ends in patch hunks for %s",
               files.source[nextfileno]))
            end
         end

      end

      if state == 'hunkskip' then
         if match_linerange(line) then
            state = 'hunkhead'
         elseif startswith(line, "--- ") then
            state = 'filenames'
            if debugmode and #files.source > 0 then
               dbg(string.format("- %2d hunks for %s", #files.hunks[nextfileno],
               files.source[nextfileno]))
            end
         end

      end
      local advance
      if state == 'filenames' then
         if startswith(line, "--- ") then
            if files.source[nextfileno] then
               all_ok = false
               warning(string.format("skipping invalid patch for %s",
               files.source[nextfileno + 1]))
               table.remove(files.source, nextfileno + 1)


            end



            local match, rest = line:match("^%-%-%- ([^ \t\r\n]+)(.*)")
            if not match then
               all_ok = false
               warning(string.format("skipping invalid filename at line %d", lineno + 1))
               state = 'header'
            else
               if match_epoch(rest) then
                  files.epoch[nextfileno + 1] = true
               end
               table.insert(files.source, match)
            end
         elseif not startswith(line, "+++ ") then
            if files.source[nextfileno] then
               all_ok = false
               warning(string.format("skipping invalid patch with no target for %s",
               files.source[nextfileno + 1]))
               table.remove(files.source, nextfileno + 1)
            else

               warning("skipping invalid target patch")
            end
            state = 'header'
         else
            if files.target[nextfileno] then
               all_ok = false
               warning(string.format("skipping invalid patch - double target at line %d",
               lineno + 1))
               table.remove(files.source, nextfileno + 1)
               table.remove(files.target, nextfileno + 1)
               nextfileno = nextfileno - 1


               state = 'header'
            else



               local re_filename = "^%+%+%+ ([^ \t\r\n]+)(.*)$"
               local match, rest = line:match(re_filename)
               if not match then
                  all_ok = false
                  warning(string.format(
                  "skipping invalid patch - no target filename at line %d",
                  lineno + 1))
                  state = 'header'
               else
                  table.insert(files.target, match)
                  nextfileno = nextfileno + 1
                  if match_epoch(rest) then
                     files.epoch[nextfileno] = true
                  end
                  nexthunkno = 0
                  table.insert(files.hunks, {})
                  table.insert(files.hunkends, table_copy(lineends))
                  table.insert(files.fileends, table_copy(lineends))
                  state = 'hunkhead'
                  advance = true
               end
            end
         end

      end
      if not advance and state == 'hunkhead' then
         local m1, m2, m3, m4 = match_linerange(line)
         if not m1 then
            if not files.hunks[nextfileno - 1] then
               all_ok = false
               warning(string.format("skipping invalid patch with no hunks for file %s",
               files.target[nextfileno]))
            end
            state = 'header'
         else
            hunkinfo.startsrc = math.tointeger(m1)
            hunkinfo.linessrc = math.tointeger(m2) or 1
            hunkinfo.starttgt = math.tointeger(m3)
            hunkinfo.linestgt = math.tointeger(m4) or 1
            hunkinfo.invalid = false
            hunkinfo.text = {}

            hunkactual.linessrc = 0
            hunkactual.linestgt = 0

            state = 'hunkbody'
            nexthunkno = nexthunkno + 1
         end

      end
   end
   if state ~= 'hunkskip' then
      warning(string.format("patch file incomplete - %s", filename))
      all_ok = false
   else

      if debugmode and #files.source > 0 then
         dbg(string.format("- %2d hunks for %s", #files.hunks[nextfileno],
         files.source[nextfileno]))
      end
   end

   local sum = 0; for _, hset in ipairs(files.hunks) do sum = sum + #hset end
   info(string.format("total files: %d  total hunks: %d", #files.source, sum))
   fp:close()
   return files, all_ok
end

local function find_hunk(file, h, hno)
   for fuzz = 0, 2 do
      local lineno = h.startsrc
      for i = 0, #file do
         local found = true
         local location = lineno
         for l, hline in ipairs(h.text) do
            if l > fuzz then

               if startswith(hline, " ") or startswith(hline, "-") then
                  local line = file[lineno]
                  lineno = lineno + 1
                  if not line or #line == 0 then
                     found = false
                     break
                  end
                  if endlstrip(line) ~= endlstrip(hline:sub(2)) then
                     found = false
                     break
                  end
               end
            end
         end
         if found then
            local offset = location - h.startsrc - fuzz
            if offset ~= 0 then
               warning(string.format("Hunk %d found at offset %d%s...", hno, offset, fuzz == 0 and "" or string.format(" (fuzz %d)", fuzz)))
            end
            h.startsrc = location
            h.starttgt = h.starttgt + offset
            for _ = 1, fuzz do
               table.remove(h.text, 1)
               table.remove(h.text, #h.text)
            end
            return true
         end
         lineno = i
      end
   end
   return false
end

local function load_file(filename)
   local fp = open(filename)
   local file = {}
   local readline = file_lines(fp)
   while true do
      local line = readline()
      if not line then break end
      table.insert(file, line)
   end
   fp:close()
   return file
end

local function find_hunks(file, hunks)
   for hno, h in ipairs(hunks) do
      find_hunk(file, h, hno)
   end
end

local function check_patched(file, hunks)
   local lineno = 1
   local _, err = pcall(function()
      if #file == 0 then
         error('nomatch', 0)
      end
      for hno, h in ipairs(hunks) do

         if #file < h.starttgt then
            error('nomatch', 0)
         end
         lineno = h.starttgt
         for _, hline in ipairs(h.text) do

            if not startswith(hline, "-") and not startswith(hline, "\\") then
               local line = file[lineno]
               lineno = lineno + 1
               if #line == 0 then
                  error('nomatch', 0)
               end
               if endlstrip(line) ~= endlstrip(hline:sub(2)) then
                  warning(string.format("file is not patched - failed hunk: %d", hno))
                  error('nomatch', 0)
               end
            end
         end
      end
   end)

   return err ~= 'nomatch'
end

local function patch_hunks(srcname, tgtname, hunks)
   local src = open(srcname, "rb")
   local tgt = open(tgtname, "wb")

   local src_readline = file_lines(src)







   local srclineno = 1
   local lineends = { ['\n'] = 0, ['\r\n'] = 0, ['\r'] = 0 }
   for hno, h in ipairs(hunks) do
      dbg(string.format("processing hunk %d for file %s", hno, tgtname))

      while srclineno < h.startsrc do
         local line = src_readline()

         if endswith(line, "\r\n") then
            lineends["\r\n"] = lineends["\r\n"] + 1
         elseif endswith(line, "\n") then
            lineends["\n"] = lineends["\n"] + 1
         elseif endswith(line, "\r") then
            lineends["\r"] = lineends["\r"] + 1
         end
         tgt:write(line)
         srclineno = srclineno + 1
      end

      for _, hline in ipairs(h.text) do

         if startswith(hline, "-") or startswith(hline, "\\") then
            src_readline()
            srclineno = srclineno + 1
         else
            if not startswith(hline, "+") then
               src_readline()
               srclineno = srclineno + 1
            end
            local line2write = hline:sub(2)

            local sum = 0
            for _, v in pairs(lineends) do if v > 0 then sum = sum + 1 end end
            if sum == 1 then
               local newline
               for k, v in pairs(lineends) do if v ~= 0 then newline = k end end
               tgt:write(endlstrip(line2write) .. newline)
            else
               tgt:write(line2write)
            end
         end
      end
   end
   for line in src_readline do
      tgt:write(line)
   end
   tgt:close()
   src:close()
   return true
end

local function strip_dirs(filename, strip)
   if strip == nil then return filename end
   for _ = 1, strip do
      filename = filename:gsub("^[^/]*/", "")
   end
   return filename
end

local function write_new_file(filename, hunk)
   local fh = io.open(fs.absolute_name(filename), "wb")
   if not fh then return false end
   for _, hline in ipairs(hunk.text) do
      local c = hline:sub(1, 1)
      if c ~= "+" and c ~= "-" and c ~= " " then
         return false, "malformed patch"
      end
      fh:write(hline:sub(2))
   end
   fh:close()
   return true
end

local function patch_file(source, target, epoch, hunks, strip, create_delete)
   local create_file = false
   if create_delete then
      local is_src_epoch = epoch and #hunks == 1 and hunks[1].startsrc == 0 and hunks[1].linessrc == 0
      if is_src_epoch or source == "/dev/null" then
         info(string.format("will create %s", target))
         create_file = true
      end
   end
   if create_file then
      return write_new_file(fs.absolute_name(strip_dirs(target, strip)), hunks[1])
   end
   source = strip_dirs(source, strip)
   local f2patch = source
   if not fs.exists(f2patch) then
      f2patch = strip_dirs(target, strip)
      f2patch = fs.absolute_name(f2patch)
      if not fs.exists(f2patch) then
         warning(string.format("source/target file does not exist\n--- %s\n+++ %s",
         source, f2patch))
         return false
      end
   end
   if not fs.is_file(f2patch) then
      warning(string.format("not a file - %s", f2patch))
      return false
   end

   source = f2patch


   local file = load_file(source)
   local hunkno = 1
   local hunk = hunks[hunkno]
   local hunkfind = {}
   local validhunks = 0
   local canpatch = false
   local hunklineno
   if not file then
      return nil, "failed reading file " .. source
   end

   if create_delete then
      if epoch and #hunks == 1 and hunks[1].starttgt == 0 and hunks[1].linestgt == 0 then
         local ok = fs.delete(fs.absolute_name(source))
         if not ok then
            return false
         end
         info(string.format("successfully removed %s", source))
         return true
      end
   end

   find_hunks(file, hunks)

   local function process_line(line, lineno)
      if not hunk or lineno < hunk.startsrc then
         return false
      end
      if lineno == hunk.startsrc then
         hunkfind = {}
         for _, x in ipairs(hunk.text) do
            if x:sub(1, 1) == ' ' or x:sub(1, 1) == '-' then
               hunkfind[#hunkfind + 1] = endlstrip(x:sub(2))
            end
         end
         hunklineno = 1


      end

      if lineno < hunk.startsrc + #hunkfind - 1 then
         if endlstrip(line) == hunkfind[hunklineno] then
            hunklineno = hunklineno + 1
         else
            dbg(string.format("hunk no.%d doesn't match source file %s",
            hunkno, source))

            hunkno = hunkno + 1
            if hunkno <= #hunks then
               hunk = hunks[hunkno]
               return false
            else
               return true
            end
         end
      end

      if lineno == hunk.startsrc + #hunkfind - 1 then
         dbg(string.format("file %s hunk no.%d -- is ready to be patched",
         source, hunkno))
         hunkno = hunkno + 1
         validhunks = validhunks + 1
         if hunkno <= #hunks then
            hunk = hunks[hunkno]
         else
            if validhunks == #hunks then

               canpatch = true
               return true
            end
         end
      end
      return false
   end

   local done = false
   for lineno, line in ipairs(file) do
      done = process_line(line, lineno)
      if done then
         break
      end
   end
   if not done then
      if hunkno <= #hunks and not create_file then
         warning(string.format("premature end of source file %s at hunk %d",
         source, hunkno))
         return false
      end
   end
   if validhunks < #hunks then
      if check_patched(file, hunks) then
         warning(string.format("already patched  %s", source))
      elseif not create_file then
         warning(string.format("source file is different - %s", source))
         return false
      end
   end
   if not canpatch then
      return true
   end
   local backupname = source .. ".orig"
   if fs.exists(backupname) then
      warning(string.format("can't backup original file to %s - aborting",
      backupname))
      return false
   end
   local ok = fs.move(fs.absolute_name(source), fs.absolute_name(backupname))
   if not ok then
      warning(string.format("failed backing up %s when patching", source))
      return false
   end
   patch_hunks(backupname, source, hunks)
   info(string.format("successfully patched %s", source))
   fs.delete(fs.absolute_name(backupname))
   return true
end

function patch.apply_patch(the_patch, strip, create_delete)
   local all_ok = true
   local total = #the_patch.source
   for fileno, source in ipairs(the_patch.source) do
      local target = the_patch.target[fileno]
      local hunks = the_patch.hunks[fileno]
      local epoch = the_patch.epoch[fileno]
      info(string.format("processing %d/%d:\t %s", fileno, total, source))
      local ok = patch_file(source, target, epoch, hunks, strip, create_delete)
      all_ok = all_ok and ok
   end

   return all_ok
end

return patch
