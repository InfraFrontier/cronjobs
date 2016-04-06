#!/bin/csh -f
# Prepare update file for IMSR
# and ftp it to the IMSR servr

# For testing send to ed
set HOST = 
set USER =
set PASS = 
set FILE = `date '+em_%Y_%m_%d.dat'`
set LOC = 
set INTLOC = 
#
# --- setup PROJECT_HOME variable
#
if ( ! $?PROJECT_HOME) set PROJECT_HOME = ${HOME}/internal

cd R E P L A C E  W I T H  S C R I P T  L O C A T I O N

perl list4imsr.pl -f ${LOC}/${FILE}

cd $LOC
# echo "Send $FILE to IMSR manually"
# OR
ftp  -n  $HOST << EOFTP
user $USER $PASS
asc
put $FILE
quit
EOFTP
cp $FILE $INTLOC/IMSR_latest.dat
# Deletes em_* files older than 90 days
/usr/bin/find . -name "em_*" -mtime +90 -exec rm {} \;

