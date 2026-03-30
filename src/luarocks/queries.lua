local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type
local queries = {}


local vers = require("luarocks.core.vers")
local util = require("luarocks.util")
local cfg = require("luarocks.core.cfg")

local query = require("luarocks.core.types.query")




local query_mt = {}

query_mt.__index = query.Query


query.Query.arch = {
   src = true,
   all = true,
   rockspec = true,
   installed = true,

}


query.Query.substring = false



local function arch_to_table(input)
   if type(input) == "table" then
      return input
   elseif type(input) == "string" then
      local arch = {}
      for a in input:gmatch("[%w_-]+") do
         arch[a] = true
      end
      return arch
   end
end










function queries.new(name, namespace, version, substring, arch, operator)

   operator = operator or "=="

   local self = {
      name = name,
      namespace = namespace,
      constraints = {},
      substring = substring,
      arch = arch_to_table(arch),
   }
   if version then
      table.insert(self.constraints, { op = operator, version = vers.parse_version(version) })
   end

   query.Query.arch[cfg.arch] = true
   return setmetatable(self, query_mt)
end



function queries.all(arch)

   return queries.new("", nil, nil, true, arch)
end

do
   local parse_constraints
   do
      local parse_constraint
      do
         local operators = {
            ["=="] = "==",
            ["~="] = "~=",
            [">"] = ">",
            ["<"] = "<",
            [">="] = ">=",
            ["<="] = "<=",
            ["~>"] = "~>",

            [""] = "==",
            ["="] = "==",
            ["!="] = "~=",
         }









         parse_constraint = function(input)

            local no_upgrade, op, versionstr, rest = input:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
            local _op = operators[op]
            local version = vers.parse_version(versionstr)
            if not _op then
               return nil, "Encountered bad constraint operator: '" .. tostring(op) .. "' in '" .. input .. "'"
            end
            if not version then
               return nil, "Could not parse version from constraint: '" .. input .. "'"
            end
            return { op = _op, version = version, no_upgrade = no_upgrade == "@" and true or nil }, rest
         end
      end









      parse_constraints = function(input)

         local constraints, oinput = {}, input
         local constraint
         while #input > 0 do
            constraint, input = parse_constraint(input)
            if constraint then
               table.insert(constraints, constraint)
            else
               return nil, "Failed to parse constraint '" .. tostring(oinput) .. "' with error: " .. input
            end
         end
         return constraints
      end
   end





   function queries.from_dep_string(depstr)

      local ns_name, rest = depstr:match("^%s*([a-zA-Z0-9%.%-%_]*/?[a-zA-Z0-9][a-zA-Z0-9%.%-%_]*)%s*([^/]*)")
      if not ns_name then
         return nil, "failed to extract dependency name from '" .. depstr .. "'"
      end

      ns_name = ns_name:lower()

      local constraints, err = parse_constraints(rest)
      if not constraints then
         return nil, err
      end

      local name, namespace = util.split_namespace(ns_name)

      local self = {
         name = name,
         namespace = namespace,
         constraints = constraints,
      }

      query.Query.arch[cfg.arch] = true
      return setmetatable(self, query_mt)
   end
end

function queries.from_persisted_table(tbl)
   query.Query.arch[cfg.arch] = true
   return setmetatable(tbl, query_mt)
end





function query_mt.__tostring(self)
   local out = {}
   if self.namespace then
      table.insert(out, self.namespace)
      table.insert(out, "/")
   end
   table.insert(out, self.name)

   if #self.constraints > 0 then
      local pretty = {}
      for _, c in ipairs(self.constraints) do
         local v = tostring(c.version)
         if c.op == "==" then
            table.insert(pretty, v)
         else
            table.insert(pretty, c.op .. " " .. v)
         end
      end
      table.insert(out, " ")
      table.insert(out, table.concat(pretty, ", "))
   end

   return table.concat(out)
end

return queries
