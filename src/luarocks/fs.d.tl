local type Args = require("luarocks.core.types.args").Args

local record fs
   verbose: function(): FILE | boolean, string, integer
   load_fns: function(fs_table: FsTable, inits: {any:any}): function
   load_platform_fns: function(patt: any, inits: {any:any}): string
   init: function
   change_dir_to_root: function
   record FsTable
   end
   -- util
   is_dir: function(dir: string): boolean
   dir: function(dir?: string): function(): string
   make_dir: function(string): boolean, string
   is_file: function(file: string): boolean
   current_dir: function(): string
   list_dir: function(?string): {string}
   delete: function(string): boolean, string
   -- signing
   is_tool_available: function(string, string): string, string
   execute: function(...: string): boolean, string, string
   make_temp_dir: function(string): string, string
   change_dir: function(string): boolean, string
   pop_dir: function(): boolean
   -- api
   which_tool: function(string): string
   tmpname: function(): string
   execute_string: function(string): boolean
   Q: function(string): string
   download: function(string, string, ?boolean): string, string, string, boolean
   set_permissions: function(string, string, string)
   -- patch
   absolute_name: function(string, ?string): string
   -- tar
   set_time: function(string, number)
   set_time: function(string, os.DateTable)
   -- zip
   find: function(?string): {string}
   filter_file: function(function, string, string): boolean, string
   -- fetch
   file_age: function(string): number
   exists: function(string): boolean
   record Lock
      free: function()
   end
   lock_access: function(string, ?boolean): Lock, string
   unlock_access: function(Lock)
   copy: function(string, string, ?string): boolean, string
   unpack_archive: function(string): boolean, string
   unzip: function(string): boolean, string
   check_md5: function(string, string): boolean, string
   -- git
   command_at: function(string, string, ?boolean): string
   -- repos
   is_actual_binary: function(string): boolean
   remove_dir_tree_if_empty: function(string)
   wrap_script: function(string, string, string, string, string): boolean, string
   is_lua: function(string): boolean
   copy_binary: function(string, string): boolean, string
   move: function(string, string, perms?: string): boolean, string
   -- writer
   replace_file: function(string, string): boolean, string
   get_md5: function(string): string, string
   -- build
   apply_patch: function(string, string, boolean): boolean, string
   copy_contents: function(string, string): boolean, string
   remove_dir_if_empty: function(string)
   -- command
   execute_env: function({any: any}, string, ...:string): boolean
   -- pack
   zip: function(string, ...:string): boolean, string
   -- cmd
   is_superuser: function(): boolean
   modules: function(string): {string}
   system_cache_dir: function(): string
   check_command_permissions: function(Args): boolean, string
   -- cmd config
   is_writable: function(string): boolean
   browser: function(string): boolean
   -- cmd write_rockspec
   quiet_stderr: function(string): string
   -- cmd innit
   wrap_script: function(string, string, string, ...:string): boolean, string
   export_cmd: function(string, string): string
end

return fs
