local config = {}

local persist = require("luarocks.persist")

local cfg_skip: {string: boolean} = {
   errorcodes = true,
   flags = true,
   platforms = true,
   root_dir = true,
   upload_servers = true,
}

local type PersistableTable = require("luarocks.core.types.persist").PersistableTable

function config.should_skip(k: string, v: any): boolean
   return v is function or cfg_skip[k]
end

local function cleanup(tbl: PersistableTable): PersistableTable
   local copy = {}
   for k, v in pairs(tbl) do
      if not (k is string and config.should_skip(k, v)) then
         copy[k] = v
      end
   end
   return copy
end

function config.get_config_for_display(cfg: PersistableTable): PersistableTable
   return cleanup(cfg)
end

function config.to_string(cfg: PersistableTable): string, string
   local cleancfg: PersistableTable = config.get_config_for_display(cfg)
   return persist.save_from_table_to_string(cleancfg)
end

return config
