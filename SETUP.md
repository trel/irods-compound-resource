# Setup

This document describes how the composable compound resource has been setup at
 SURFSara.


Creating the compound resource

A compound resource uses "cache" and the "compound" resource in one
"composable" resource. The data is copied to the "composable" resource and ends
 up in the "cache" resource. The data is than replicated to the "compound"
 resource. For SURFsara a delayed copy to the compound resource is desired.
iRODS rules take care of the replication from cache to the compound resource.

The creation was done as follows:

1. Create a cache resource

        mkdir /eudatCache/Vault
        chown rods:rods /eudatCache/Vault
        iadmin mkresc  eudatCache "unixfilesystem" cache <fqdn> /eudatCache/Vault
        iadmin modresc eudatCache comment "eudat cache storage"

2. Create a compound resource

        iadmin mkresc  eudatPnfs 'univmss' compound <fqdn> /pnfs/grid.sara.nl/data/irods
        iadmin modresc eudatPnfs comment "eudat pnfs storage"
        iadmin modresc eudatPnfs context univMSSInterface.sh

3. Create a composable resource

        iadmin mkresc eudat compound
        iadmin addchildtoresc eudat eudatCache cache
        iadmin addchildtoresc eudat eudatPnfs archive
        iadmin modresc eudat context "auto_repl=off"
        ilsresc eudat
        ilsresc -l eudat



