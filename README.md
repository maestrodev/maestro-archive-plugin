maestro-archive-plugin
====================

A Maestro Plugin that allows creation of zip/tar.gz archives

Task
----

/archive/archive

Task Parameters
---------------

* "Path"

  The location on disk where the file(s) to be archived are located
  This can either be a single value, or an array.

* "Destination"

  Destination directory to create archive file

* "Filename"

  Destination filename (without extension)

* "Type"

  Default: "targz"

  Type of archive to create.  Currently the following values are supported: zip (.zip file), targz (.tar.gz file)
