# Setup

This document describes how the composable compound resource has been
setup at SURFSara.

Creating the compound resource

The data is copied into the composable resource and is first
written to the cache resource. The data is then replicated to the
archive resource via a delayed rule.

The creation of this example composable resource tree:

1. Create a cache resource

        mkdir /eudatCache/Vault
        chown rods:rods /eudatCache/Vault
        iadmin mkresc  eudatCache unixfilesystem <fqdn>:/eudatCache/Vault
        iadmin modresc eudatCache comment "eudat cache storage"

2. Create an archive resource (using univmss)

        iadmin mkresc  eudatPnfs univmss <fqdn>:/pnfs/grid.sara.nl/data/irods univMSSInterface.sh
        iadmin modresc eudatPnfs comment "eudat pnfs storage"

3. Create a compound resource

        iadmin mkresc eudat compound
        iadmin addchildtoresc eudat eudatCache cache
        iadmin addchildtoresc eudat eudatPnfs archive
        iadmin modresc eudat context "auto_repl=off"

4. Confirm new composable configuration

        ilsresc eudat
        ilsresc -l eudat
