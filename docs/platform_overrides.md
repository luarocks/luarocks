# Platform overrides

To specify platform-specific information in rockspecs, one should use the
`platforms` field of top-level tables.

In top-level tables, a field `platforms` is treated specially. If present,
it may contain a table containing sub-tables representing different platforms.
For example, `build.platforms.unix`, if present, as the name implies, would
be a table containing specifics for building on Unix systems.

The contents of platform tables override the contents of the top-level table
where `platforms` is located. For example, in a Linux system, an entry
`build.platforms.linux.foo` will override `build.foo`. Tables are
scanned deeply, so if `build.foo` is a table, the contents of
`build.platforms.linux.foo` will add to or replace the contents of
`build.foo`, instead of just replacing the entire table. Therefore, you
don't need to rewrite the entire `build` section in a platform table, only
the fields should change.


