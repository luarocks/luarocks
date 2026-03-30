
local record upload
   record Response
      module: string
      is_new: boolean
      module_url: boolean
      manifests: {string}
      record version
         id: string
      end
   end
end

local signing = require("luarocks.signing")
local util = require("luarocks.util")
local fetch = require("luarocks.fetch")
local pack = require("luarocks.pack")
local cfg = require("luarocks.core.cfg")
local Api = require("luarocks.upload.api")

local type Response = upload.Response

local type Parser = require("luarocks.vendor.argparse").Parser

local type Args = require("luarocks.core.types.args").Args
local type Rockspec = require("luarocks.core.types.rockspec").Rockspec

function upload.add_to_parser(parser: Parser)
   local cmd = parser:command("upload", "Pack a source rock file (.src.rock extension) "..
      "and upload it and the rockspec to the public rocks repository.", util.see_also())
      :summary("Upload a rockspec to the public rocks repository.")

   cmd:argument("rockspec", "Rockspec for the rock to upload.")
   cmd:argument("src_rock", "A corresponding .src.rock file; if not given it will be generated.")
      :args("?")

   cmd:flag("--skip-pack", "Do not pack and send source rock.")
   cmd:option("--api-key", "Pass an API key. It will be stored for subsequent uses.")
      :argname("<key>")
   cmd:option("--temp-key", "Use the given a temporary API key in this "..
      "invocation only. It will not be stored.")
      :argname("<key>")
   cmd:flag("--force", "Replace existing rockspec if the same revision of a "..
      "module already exists. This should be used only in case of upload "..
      "mistakes: when updating a rockspec, increment the revision number "..
      "instead.")
   cmd:flag("--sign", "Upload a signature file alongside each file as well.")
   cmd:flag("--debug"):hidden(true)
end

local function is_dev_version(version: string): string
   return version:match("^dev") or version:match("^scm")
end

function upload.command(args: Args): boolean, string, string
   local api, err = Api.new(args)
   if not api then
      return nil, err
   end
   if cfg.verbose then
      api.debug = true
   end

   local rockspec: Rockspec
   local errcode: string
   rockspec, err, errcode = fetch.load_rockspec(args.rockspec)
   if err then
      return nil, err, errcode
   end

   util.printout("Sending " .. tostring(args.rockspec) .. " ...")
   local res: Response
   res, err = api:method("check_rockspec", {
      package = rockspec.package,
      version = rockspec.version
   }) as (Response, string)
   if not res then return nil, err end

   if not res.module then
      util.printout("Will create new module (" .. tostring(rockspec.package) .. ")")
   end
   if res.version and not args.force then
      return nil, "Revision "..rockspec.version.." already exists on the server. "..util.see_help("upload")
   end

   local sigfname: string
   local rock_sigfname: string

   if args.sign then
      sigfname, err = signing.sign_file(args.rockspec)
      if err then
         return nil, "Failed signing rockspec: " .. err
      end
      util.printout("Signed rockspec: "..sigfname)
   end

   local rock_fname: string
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
      util.printout("Signed packed rock: "..rock_sigfname)
   end

   local multipart = require("luarocks.upload.multipart")

   res, err = api:method("upload", nil, {
     rockspec_file = multipart.new_file(args.rockspec),
     rockspec_sig = sigfname and multipart.new_file(sigfname),
   }) as (Response, string)
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
      }) as (Response, string)
      if not res then return nil, err end
   end

   util.printout()
   util.printout("Done: " .. tostring(module_url))
   util.printout()
   return true
end

return upload
