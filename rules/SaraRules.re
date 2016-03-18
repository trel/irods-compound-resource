# iRODS Rules for SURFsara
# The rules are specific for SURFsara. They are developed for SURFsara as part of EUDAT development.
# The rules are provided as is without any warranty.
# copyright SURFsara 2016

# set the default resource to eudat
acSetRescSchemeForCreate {
        on ($objPath like "/vzSARA1/eudat/*") {
            msiSetDefaultResc("eudat","preferred");
        }
}

acSetRescSchemeForRepl {
        on ($objPath like "/vzSARA1/eudat/*") {
            msiSetDefaultResc("eudat","preferred");
        }
}

acSetRescSchemeForCreate {msiSetDefaultResc("eudat","preferred"); }
acSetRescSchemeForRepl {msiSetDefaultResc("eudat","preferred"); }

# on put action
# if the name of the resource group is "eudat" replicate it to eudatPnfs in a delayed function
# include destination filepath "eudatCache" only. A replication should not be done twice.
# eudatCache is local disk cache
# eudatPnfs is dCache
acPostProcForPut {
        #ON($rescName like "eudat" && $filePath like "/eudatCache/Vault/*" ) {
        ON($filePath like "/eudatCache/Vault/*" ) {
                # writeLine("serverLog","Execute command to replicate $objPath to eudatPnfs using eudat, because of put");
                delay("<PLUSET>1m</PLUSET><EF>1h DOUBLE UNTIL SUCCESS OR 6 TIMES</EF>") {
                        #writeLine("serverLog","filePath: $filePath");
                        *CompoundRescName="eudat"
                        *CacheRescName   ="*CompoundRescName;eudatCache";
                        *ArchiveRescName ="*CompoundRescName;eudatPnfs";
                        writeLine("serverLog","Execute command to replicate (in resource *CompoundRescName) $objPath ($filePath) to *ArchiveRescName, because of put");
                        msisync_to_archive("*CacheRescName", $filePath, $objPath );
                }
        }
}

# on replicate action. (replicate within zone between resources)
# if the name of the resource group is "eudat" replicate it to eudatPnfs in a delayed function
# include destination filepath "eudatCache" only. A replication should not be done twice.
# eudatCache is local disk cache
# eudatPnfs is dCache
acPostProcForRepl {
        #ON($rescName like "eudat" && $filePath like "/eudatCache/Vault/*" ) {
        ON($filePath like "/eudatCache/Vault/*" ) {
                # writeLine("serverLog","Execute command to replicate $objPath to eudatPnfs using eudat, because of replication");
                delay("<PLUSET>1m</PLUSET><EF>1h DOUBLE UNTIL SUCCESS OR 6 TIMES</EF>") {
                        #writeLine("serverLog","filePath: $filePath");
                        *CompoundRescName="eudat"
                        *CacheRescName   ="*CompoundRescName;eudatCache";
                        *ArchiveRescName ="*CompoundRescName;eudatPnfs";
                        writeLine("serverLog","Execute command to replicate (in resource *CompoundRescName) $objPath ($filePath) to *ArchiveRescName, because of replication");
                        msisync_to_archive("*CacheRescName", $filePath, $objPath );
                }
        }
 }

# on copy action.
# if the name of the resource group is "eudat" replicate it to eudatPnfs in a delayed function
# include destination filepath "eudatCache" only. A replication should not be done twice.
# eudatCache is local disk cache
# eudatPnfs is dCache
acPostProcForCopy {
        #ON($rescName like "eudat" && $filePath like "/eudatCache/Vault/*" ) {
        ON($filePath like "/eudatCache/Vault/*" ) {
                # writeLine("serverLog","Execute command to replicate $objPath to eudatPnfs using eudat, because of copy");
                delay("<PLUSET>1m</PLUSET><EF>1h DOUBLE UNTIL SUCCESS OR 6 TIMES</EF>") {
                        #writeLine("serverLog","filePath: $filePath");
                        *CompoundRescName="eudat"
                        *CacheRescName   ="*CompoundRescName;eudatCache";
                        *ArchiveRescName ="*CompoundRescName;eudatPnfs";
                        writeLine("serverLog","Execute command to replicate (in resource *CompoundRescName) $objPath ($filePath) to *ArchiveRescName, because of copy");
                        msisync_to_archive("*CacheRescName", $filePath, $objPath );
                }
        }
 }

# This rule replicates in a compound resource *CompoundRescName.
# it replicates files from cache to archive. Only if it is needed.
#
# Written by Robert Verkerk of SURFsara
#
# usage example: irule replicateDiskCache "*Collection=/vzSARA1%*CompoundRescName=eudat"  ruleExecOut
#
# input parameters are:
# - *Collection=/vzSARA1			# the collection/zone
# - *CompoundRescName=eudat			# the compound resource to be replicated in
#
# This rule can be seen with:
#	iqstat
#       iqstat -l
# the parameters can be seen than in a file like: /var/lib/irods/iRODS/server/config/packedRei/rei.rods.813503809
#
replicateDiskCache {
#	delay("<PLUSET>30s</PLUSET><EF>24h</EF>") {
		writeLine("serverLog","Start : The collection *Collection in compound resource *CompoundRescName is being replicated");
		*ArchiveRescName="";
		*CacheRescName="";
		*RescTypeName="";
		# define cache and archive resource from compound resource
		foreach ( *ROW in SELECT RESC_NAME, RESC_TYPE_NAME, RESC_CHILDREN WHERE RESC_NAME like '*CompoundRescName') {
			*RC =*ROW.RESC_CHILDREN;
			*RescTypeName =*ROW.RESC_TYPE_NAME;
			if ( *ROW.RESC_TYPE_NAME == "compound" ) {
				*STRL = trimr( *RC, ";"); 
				*STRR = triml( *RC, ";"); 
				#writeLine("serverLog","string left: *STRL string right: *STRR");
				if ( *STRL like regex "*{cache}" ) {
					*CacheRescName   ="*CompoundRescName;*STRL";
					*ArchiveRescName ="*CompoundRescName;*STRR";
				} else {
					*CacheRescName   ="*CompoundRescName;*STRR";
					*ArchiveRescName ="*CompoundRescName;*STRL";
				}
				*CacheRescName   = trimr(*CacheRescName , "{");
                                *ArchiveRescName = trimr (*ArchiveRescName , "{");
			}
		}
		if ( *RescTypeName == "compound" ) {
			writeLine("serverLog","replicating in *CompoundRescName from *CacheRescName to *ArchiveRescName");
			foreach ( *ROW in SELECT DATA_NAME, COLL_NAME, DATA_PATH, order(DATA_CREATE_TIME) WHERE DATA_RESC_HIER = '*CacheRescName' AND COLL_NAME like '*Collection%') {
				*D = *ROW.DATA_NAME;
				*C = *ROW.COLL_NAME;
        	        	foreach ( *ROW in SELECT count(DATA_NAME) WHERE DATA_RESC_HIER = '*ArchiveRescName' AND COLL_NAME like '*C' and DATA_NAME like '*D') {
               		         	*ArchiveCount = double(*ROW.DATA_NAME);
                		}
				if ( *ArchiveCount  == 0 ) {
					# no copy in archive. So replicate
					*P = *ROW.DATA_PATH
					writeLine("serverLog","*C/*D with cache data path *P is to be replicated to *ArchiveRescName");
					delay("<PLUSET>1m</PLUSET>") {
						*err = errormsg(
							msisync_to_archive("*CacheRescName","*P","*C/*D" ),*msg );
						if( 0 != *err ) {
							writeLine( "serverLog", "Error - [*msg], *err" );
						} else {
							writeLine( "serverLog", "*C/*D is replicated to *ArchiveRescName" );
						}
					}
				}
			}
		} else {
			writeLine("serverLog","The *CompoundRescName is NOT a compound resource!!");
		}
		writeLine("serverLog","Finish: The collection *Collection in compound resource *CompoundRescName is replicated");
#	}
}


# This rule purge a cache resource *CacheRescName if the total size of this resource is 
# greater than *MaxSpAlwdTBs terabytes. The purge will be stopped once the requirement is met.
# The purge will occur on the collection *Collection and all its subcollections.
# The oldest copies in the cache will be cleared first.
# In the current setting, a single copy of the files will be kept. Hence, if a single copy
# exists only in *CacheRescName and not elsewhere, it won't be removed.
#
# Written by Jean-Yves Nief of CCIN2P3 and copyright assigned to Data Intensive Cyberinfrastructure Foundation
# Updated by Robert Verkerk of SURFsara. Used new quering technices and selection of data use dot notation.
#
# usage example: irule purgeDiskCache "*Collection=/vzSARA1%*CacheRescName=eudat;eudatCache%*MaxSpAlwdTBstring=23"  ruleExecOut
#
# input parameters are:
# - *Collection=/vzSARA1		# the collection/zone
# - *CacheRescName=eudat;eudatCache	# the cache resource to be purged
# - *MaxSpAlwdTBstring=23		# an input string which contains the size when to purge, this will be converted to an int.
#
# This rule can be seen with:
#	iqstat
#       iqstat -l
# the parameters can be seen than in a file like: /var/lib/irods/iRODS/server/config/packedRei/rei.rods.813503809

purgeDiskCache {
	delay("<PLUSET>30s</PLUSET><EF>30m</EF>") {
		writeLine("serverLog","Start : The collection *Collection in cache resource *CacheRescName is being trimmed to *MaxSpAlwdTBstring T");
		# convert a input string to a integer
		*MaxSpAlwdTBs = int(*MaxSpAlwdTBstring);
		# writeLine("serverLog","cache resource is *CacheRescName ");
		foreach ( *ROW in SELECT sum(DATA_SIZE) WHERE DATA_RESC_HIER = '*CacheRescName' AND COLL_NAME like '*Collection%') {
			*usedSpace = double(*ROW.DATA_SIZE);
		}
		#writeLine("serverLog","The cache resource: *CacheRescName has *usedSpace bytes ");
		*MaxSpAlwd = *MaxSpAlwdTBs * 1024^4;
		# start test
		#*MaxSpAlwd = 1024; #for testing purposes size is 1024
		# end test
		if ( *usedSpace > *MaxSpAlwd ) {
			writeLine("serverLog","the used space *usedSpace > max allowed space *MaxSpAlwd ");
			foreach ( *ROW in SELECT DATA_NAME, COLL_NAME, DATA_REPL_NUM, DATA_SIZE, order(DATA_CREATE_TIME) WHERE DATA_RESC_HIER = '*CacheRescName' AND COLL_NAME like '*Collection%') {
				*D = *ROW.DATA_NAME;
				*C = *ROW.COLL_NAME;
				*R = *ROW.DATA_REPL_NUM;
				*S = *ROW.DATA_SIZE;
				#writeLine("serverLog","*C/*D with data size:*S and replica number:*R on *CacheRescName is to be purged");
				msiDataObjTrim("*C/*D","null","*R","1","1",*status);
				#writeLine("serverLog","*C/*D on *CacheRescName has been purged with status: *status");
				# if the trim is NOT performed the status is 0
				# if the trim is performed the status is 1
				if ( *status == 1 ) { 
					*usedSpace = *usedSpace - double(*S);
					writeLine("serverLog","*C/*D on *CacheRescName has been purged with status: *status");
					writeLine("serverLog","The disk space used is: *usedSpace");
				}
				if ( *usedSpace < *MaxSpAlwd ) then {
					writeLine("serverLog","the used space *usedSpace < max allowed space *MaxSpAlwd ");
					break;
				}
			}
		}
		writeLine("serverLog","Finish: The collection *Collection in cache resource *CacheRescName is trimmed to *MaxSpAlwdTBstring T ");
	}
}


