local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local type = type; local config = {}

local persist = require("luarocks.persist")

local cfg_skip = {
   errorcodes = true,
   flags = true,
   platforms = true,
   root_dir = true,
   upload_servers = true,
}



function config.should_skip(k, v)
   return type(v) == "function" or cfg_skip[k]
end

local function cleanup(tbl)
   local copy = {}
   for k, v in pairs(tbl) do
      if not (type(k) == "string" and config.should_skip(k, v)) then
         copy[k] = v
      end
   end
   return copy
end

function config.get_config_for_display(cfg)
   return cleanup(cfg)
end

function config.to_string(cfg)
   local cleancfg = config.get_config_for_display(cfg)
   return persist.save_from_table_to_string(cleancfg)
end

return config
