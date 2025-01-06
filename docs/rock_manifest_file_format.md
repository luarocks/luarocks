# Rock manifest file format

The `rock_manifest` file lists the files contained in a binary rock, with the
MD5 checksum for each file.

It is a Lua file containing a single global variable definition, that defines
the variable **rock_manifest**, assigning to it a _table of file checksums_ of
the [archive file's root directory](Rock file format) (except for the
`rock_manifest` file itself).

A table of file checksums is defined as a table describing a directory, where
for each entry in the directory, there is a string key with its filename (only
the basename).

If the filename is a non-directory, the value of its key is a string with the
MD5 checksum of the file.

If the filename is a directory, the value of its key is itself a table of file
checksums of that directory.
