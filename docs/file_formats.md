# File formats

These pages are the reference specification for file formats used by LuaRocks.
All files are actual Lua files, but they are loaded in a restricted
environment in which the standard Lua libraries are not available.

* [Rockspec format](rockspec_format.md) - Rockspecs are the files which
  contain rules explaining how rocks are built and installed as well as their
  dependencies and other metadata.

* [Config file format](config_file_format.md) - The specification of the
  LuaRocks configuration file format, as it takes shape.

* [Manifest file format](manifest_file_format.md) - The index file that
  describes a LuaRocks [repository](rocks_repositories.md), used by both rocks
  servers and rocks trees.

* [Rock file format](rock_file_format.md) - Reference to the .rock file
  format: the installable packages produced from
  [rockspecs](rockspec_format.md).



