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
   dir: function(dir: string): function(): string
   make_dir: function(string): boolean, string
   is_file: function(file: string): boolean
   current_dir: function(): string
   list_dir: function(string): {string}
   delete: function(string)
   -- signing
   is_tool_available: function(string, string): string, string
   execute: function(...: string): boolean --? boolean? src/luarocks/signing.tl: 27
   make_temp_dir: function(string): string, string
   change_dir: function(string): boolean, string
   pop_dir: function(): boolean
   -- api
   which_tool: function(string): string
   tmpname: function(): string
   execute_string: function(string): boolean
   Q: function(string): string
   download: function(string, string): boolean, string
   set_permissions: function(string, string, string)
end

return fs
