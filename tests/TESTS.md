# Testing

The following document descibes how to perform some tests to see if the compound
 resource works as desired. For SURFsara a delayed copy to the compound resource
 is desired. This is setup in the rules and is tested.
The resource `eudat` is a composable resource with a cache and compound resource.

It uses a `iput` and `irepl` example to test 2 cases.

1. testing iput as the rods user

        iput -R eudat <filename> <eudat_filename>
        ils -l <eudat_filename>
        iqstat -a
        sleep 120
        iqstat -a
        ils -l <eudat_filename>
        less /var/log/irods/univMSSInterface.log
        less /var/lib/irods/iRODS/server/log/rodsLog.<year>.<month>.<day>
        less /var/lib/irods/iRODS/server/log/reLog.<year>.<month>.<day>
        irm <eudat_filename>
        ils <eudat_filename>
        less /var/log/irods/univMSSInterface.log
        less /var/lib/irods/iRODS/server/log/rodsLog.<year>.<month>.<day>

2. testing irepl as the rods user

        iput -R demoResc <filename> <eudat_filename>
        irepl -R eudat <eudat_filename>
        ils -l <eudat_filename>
        iqstat -a
        sleep 120
        iqstat -a
        ils -l <eudat_filename>
        less /var/log/irods/univMSSInterface.log
        less /var/lib/irods/iRODS/server/log/rodsLog.<year>.<month>.<day>
        less /var/lib/irods/iRODS/server/log/reLog.<year>.<month>.<day>
        irm <eudat_filename>
        ils <eudat_filenam>
        less /var/log/irods/univMSSInterface.log
        less /var/lib/irods/iRODS/server/log/rodsLog.<year>.<month>.<day>
