local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local upload = { Response = { version = {} } }











local signing = require("luarocks.signing")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local pack = require("luarocks.pack")
local cfg = require("luarocks.core.cfg")
local Api = require("luarocks.upload.api")








function upload.add_to_parser(parser)
   local cmd = parser:command("upload", "Pack a source rock file (.src.rock extension) " ..
   "and upload it and the rockspec to the public rocks repository.", util.see_also()):
   summary("Upload a rockspec to the public rocks repository.")

   cmd:argument("rockspec", "Rockspec for the rock to upload.")
   cmd:argument("src_rock", "A corresponding .src.rock file; if not given it will be generated."):
   args("?")

   cmd:flag("--skip-pack", "Do not pack and send source rock.")
   cmd:option("--api-key", "Pass an API key. It will be stored for subsequent uses."):
   argname("<key>")
   cmd:option("--temp-key", "Use the given a temporary API key in this " ..
   "invocation only. It will not be stored."):
   argname("<key>")
   cmd:option("--code", "Two-factor code (or set $LUAROCKS_TFA_CODE."):
   argname("<code>")
   cmd:flag("--force", "Replace existing rockspec if the same revision of a " ..
   "module already exists. This should be used only in case of upload " ..
   "mistakes: when updating a rockspec, increment the revision number " ..
   "instead.")
   cmd:flag("--sign", "Upload a signature file alongside each file as well.")
   cmd:flag("--debug"):hidden(true)
end

local function is_dev_version(version)
   return version:match("^dev") or version:match("^scm")
end

local function prompt_tfa(api)
   util.printout("Two-factor authentication required for this account.")
   local initial = os.getenv("LUAROCKS_TFA_CODE") or api.code
   local attempts = 0
   while true do
      local code = initial
      initial = nil
      if not code then
         util.printout("Enter 2FA code: ")
         code = io.stdin:read("*l")
         if not (code and code ~= "") then
            return nil, "no code provided"
         end
      end
      local res = api:raw_method("verify_tfa", nil, {
         code = code,
      })
      if res.success and res.tfa_token then
         api.tfa_token = res.tfa_token
         util.printout("Verified.")
         return true
      end
      attempts = attempts + 1
      local err = res.errors and table.concat(res.errors, ", ") or "verification failed"
      util.printout(tostring(err))
      if attempts >= 3 then
         return nil, "two-factor verification failed after " .. tostring(attempts) .. " attempt(s)"
      end
   end
end

function upload.command(args)
   local api, err = Api.new(args)
   if not api then
      return nil, err
   end
   api.code = args.code
   api.on_tfa_required = prompt_tfa
   if cfg.verbose then
      api.debug = true
   end

   local rockspec
   local errcode
   rockspec, err, errcode = fetch.load_rockspec(args.rockspec)
   if err then
      return nil, err, errcode
   end

   util.printout("Sending " .. tostring(args.rockspec) .. " ...")
   local res
   res, err = api:method("check_rockspec", {
      package = rockspec.package,
      version = rockspec.version,
   })
   if not res then return nil, err end

   if not res.module then
      util.printout("Will create new module (" .. tostring(rockspec.package) .. ")")
   end
   if res.version and not args.force then
      return nil, "Revision " .. rockspec.version .. " already exists on the server. " .. util.see_help("upload")
   end

   local sigfname
   local rock_sigfname

   if args.sign then
      sigfname, err = signing.sign_file(args.rockspec)
      if err then
         return nil, "Failed signing rockspec: " .. err
      end
      util.printout("Signed rockspec: " .. sigfname)
   end

   local rock_fname
   if args.src_rock then
      rock_fname = args.src_rock
   elseif not args.skip_pack and not is_dev_version(rockspec.version) then
      util.printout("Packing " .. tostring(rockspec.package))
      rock_fname, err = pack.pack_source_rock(args.rockspec)
      if not rock_fname then
         return nil, err
      end
   end

   if rock_fname and args.sign then
      rock_sigfname, err = signing.sign_file(rock_fname)
      if err then
         return nil, "Failed signing rock: " .. err
      end
      util.printout("Signed packed rock: " .. rock_sigfname)
   end

   local multipart = require("luarocks.upload.multipart")

   res, err = api:method("upload", nil, {
      rockspec_file = multipart.new_file(args.rockspec),
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
      local id = math.tointeger(res.version.id)
      res, err = api:method("upload_rock/" .. ("%d"):format(id), nil, {
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
