
local upload = {}

local signing = require("luarocks.signing")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local pack = require("luarocks.pack")
local cfg = require("luarocks.core.cfg")
local Api = require("luarocks.upload.api")

upload.help_summary = "Upload a rockspec to the public rocks repository."
upload.help_arguments = "[--skip-pack] [--api-key=<key>] [--force] <rockspec>"
upload.help = [[
<rockspec>       Pack a source rock file (.src.rock extension),
                 upload rockspec and source rock to server.

--skip-pack      Do not pack and send source rock.

--api-key=<key>  Give it an API key. It will be stored for subsequent uses.

--temp-key=<key> Use the given a temporary API key in this invocation only.
                 It will not be stored.

--force          Replace existing rockspec if the same revision of
                 a module already exists. This should be used only 
                 in case of upload mistakes: when updating a rockspec,
                 increment the revision number instead.

--sign           Upload a signature file alongside each file as well.
]]

local function is_dev_version(version)
   return version:match("^dev") or version:match("^scm")
end

function upload.command(flags, fname)
   if not fname then
      return nil, "Missing rockspec. "..util.see_help("upload")
   end

   local api, err = Api.new(flags)
   if not api then
      return nil, err
   end
   if cfg.verbose then
      api.debug = true
   end

   local rockspec, err, errcode = fetch.load_rockspec(fname)
   if err then
      return nil, err, errcode
   end

   util.printout("Sending " .. tostring(fname) .. " ...")
   local res, err = api:method("check_rockspec", {
      package = rockspec.package,
      version = rockspec.version
   })
   if not res then return nil, err end
   
   if not res.module then
      util.printout("Will create new module (" .. tostring(rockspec.package) .. ")")
   end
   if res.version and not flags["force"] then
      return nil, "Revision "..rockspec.version.." already exists on the server. "..util.see_help("upload")
   end

   local sigfname
   local rock_sigfname

   if flags["sign"] then
      sigfname, err = signing.sign_file(fname)
      if err then
         return nil, "Failed signing rockspec: " .. err
      end
      util.printout("Signed rockspec: "..sigfname)
   end

   local rock_fname
   if not flags["skip-pack"] and not is_dev_version(rockspec.version) then
      util.printout("Packing " .. tostring(rockspec.package))
      rock_fname, err = pack.pack_source_rock(fname)
      if not rock_fname then
         return nil, err
      end
      if flags["sign"] then
         rock_sigfname, err = signing.sign_file(rock_fname)
         if err then
            return nil, "Failed signing rock: " .. err
         end
         util.printout("Signed packed rock: "..rock_sigfname)
      end
   end
   
   local multipart = require("luarocks.upload.multipart")

   res, err = api:method("upload", nil, {
     rockspec_file = multipart.new_file(fname),
     rockspec_sig = sigfname and multipart.new_file(sigfname),
   })
   if not res then return nil, err end
   
   if res.is_new and #res.manifests == 0 then
      util.printerr("Warning: module not added to root manifest due to name taken.")
   end
   
   local module_url = res.module_url
   
   if rock_fname then
      if (not res.version) or (not res.version.id) then
         return nil, "Invalid response from server."
      end
      util.printout(("Sending " .. tostring(rock_fname) .. " ..."))
      res, err = api:method("upload_rock/" .. ("%d"):format(res.version.id), nil, {
         rock_file = multipart.new_file(rock_fname),
         rock_sig = rock_sigfname and multipart.new_file(rock_sigfname),
      })
      if not res then return nil, err end
   end
   
   util.printout()
   util.printout("Done: " .. tostring(module_url))
   util.printout()
   return true
end

return upload
