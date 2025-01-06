# Manifest file format

A manifest file describes files contained in a rocks tree or server. Each
rocks tree or server has a `manifest` file in its root. Rocks servers may also
have versioned manifests (e.g. `manifest-5.1` for Lua 5.1) and compressed
manifests (e.g. `manifest-5.1.zip`). These must match the contents of the
uncompressed manifest.

Like a rockspec, a manifest file contains a Lua program setting several
globals. Three of them are mandatory:

* `repository`: a table where each key is a package name and its value is a table describing versions of the package
  hosted on a server or installed in a rocks tree.
  * `repository[package_name]`: a table where each key is a package version (including revision, e.g. `1.0.0-1`)
  and its value provides information for that version.
    * `repository[package_name][package_version]`: a list of tables containing several fields:
      * `arch`: architecture of the rock as a string. Always set to `installed` in rock tree manifests.
      * `modules` (only for rock tree manifests): a table mapping module names to paths under installation
        directory for Lua or C modules.
      * `commands` (only for rock tree manifests): a table mapping script names to paths under installation
        directory for binaries.
      * `dependencies` (only for rock tree manifests): a table mapping names of packages the rock depends on
        (perhaps indirectly) to versions of installed packages satisfying the dependency.
* `modules`: empty table in rock server manifests (may change in future releases). In rock tree manifests
  it's a table mapping module names to lists of packages and versions providing that module. Each value in the
  list is a string in `module/version` format (e.g. `foo/1.0.0-1`).
* `commands`: empty table in rock server manifests (may change in future releases). In rock tree manifests
  it's a table mapping script names to lists of packages and versions providing that script, using same
  format as `modules` table.
* `dependencies` (only for rock tree manifests): a table containing precomputed dependency information
  to be used by `luarocks.loader`. Each key is a package name.
  * `dependencies[package_name]`: A table where each key is a version (with revision) and its value describes
    dependencies of that version of the package.
    * `dependencies[package_name][package_version]`: An array of direct dependencies represented as tables
      with the following fields:
      * `name`: name of the rock that is depended on.
      * `constraints`: an array of parsed version constraints. Each constraint is represented as
        a table with fields:
        * `op`: an operator as a string (e.g. `>=`).
        * `version`: version to the right of the operator as an array of parts, e.g. `{1, 0, 0}` for `1.0.0`.
          It also contains version as a string in `string` field and may contain revision in `revision` field.
