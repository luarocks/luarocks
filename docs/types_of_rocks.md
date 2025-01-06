# Types of rocks

A **rock** is a bundle containing a specification file (called a "rockspec")
and files providing Lua modules.

A **[rockspec](rockspec_format.md)** is a Lua file containing a series of
assignments to variables that provide various information about the rock, such
as description metadata, dependency relations and build rules. Rocks are
created from rockspecs.

When packed, a rock is an archive file in ZIP format, with the .rock filename
extension. When installed, a rock is unpacked into a directory in the local
rocks repository.

There are several types of rocks, and when packed they are identified by their
filename extensions. These are:

* Source rocks (`.src.rock`): these contain the rockspec and the source code
  for the Lua modules provided by the rock. When installing a source rock, the
  source code needs to be compiled.

* Binary rocks (`_.system-arch_.rock`: `.linux-x86.rock,
  .macosx-powerpc.rock`): these contain the rockspec and modules in compiled
  form. Modules written in Lua may be in source .lua format, but modules
  compiled as C dynamic libraries are compiled to their platform-specific
  format.

* Pure-Lua rocks (`.all.rock`): these contain the rockspec and the Lua modules
  they provide in .lua format. These rocks are directly installable without a
  compilation stage and are platform-independent.


