# irods-compound-resource
iRODS composable compound resource description @ SURFsara

These scripts and descriptions make up the composable "compound" resource at
SURFsara.

At SURFsara the composable resource comprises of:
- cache. local disk space.
- archive. storage reachable via gridftp (dCache)

The archive storage is used via the univMSSInterface.sh driver script.

Data is always put in the cache. iRODS rules replicate data to the archive.
This way the data transfer for a user is finished once the data is in the
cache. There is also a rule to trim the cache resource to prevent filesystem
 overflow.

It has been developed as part of an EUDAT (http://eudat.eu/services/) project.

copyright 2016 SURFsara.

