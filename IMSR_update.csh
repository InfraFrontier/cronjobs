#!/bin/csh -f
# Prepare update file for IMSR
# and ftp it to the IMSR servr
#LICENCE
#Copyright 2015 EMBL - European Bioinformatics Institute (EMBL-EBI)
#Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
#       http://www.apache.org/licenses/LICENSE-2.0#        Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
#NAME
#IMSR_update.csh
#SYNOPSIS
#Required to run list4imsr.pl. See message for credential below and for line 24
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

