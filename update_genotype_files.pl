#!/usr/local/bin/perl -w
=head1 LICENCE
Copyright 2015 EMBL - European Bioinformatics Institute (EMBL-EBI)
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
        http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
=head1 NAME
update_genotype_files.pl
=head1 SYNOPSIS
=cut

# Author: ckchen@ebi.ac.uk

# This script checks the /nfs/panda/emma/genotype_protocols folder
# for existing protocol files and insert a row for each in 
# the emmastr.strains.genotype_file if a record is missing

use strict;
use Getopt::Long 'GetOptions';
use Net::Netrc;
use DBI;

## load configuration
eval { require "CFG.pl" } || die "Configuration file 'CFG.pl' was not found.\n";
          my $dbh = DBI->connect($CFG::DSN, $CFG::USER, $CFG::PASSWD, 
		{InactiveDestroy => 1, RaiseError => 1, PrintError => 1, AutoCommit => 0}
     );
#my $dirname = "/nfs/panda/emma/genotype_protocols";
my $dirname = "/nfs/web-hx/mouseinformatics/infrafrontier/genotype_protocols";

opendir ( DIR, $dirname ) || die "Error in opening dir $dirname\n";

my $sql = qq{UPDATE strains SET genotype_file = NULL};
my $sth = $dbh->prepare($sql);
$sth->execute;

my $insert = qq{UPDATE strains SET genotype_file = ? WHERE id_str = ?};
$sth = $dbh->prepare($insert);

while( my $filename = readdir(DIR) ){
    if ( $filename =~ /^EM*(\d+)_geno\.pdf$/ ){
	print "$filename: $1\n";
	eval {
	    $sth->execute($filename, $1);
	};
    }
}
closedir(DIR);

if ( $@ ){
    $dbh->rollback();
}
else {
    $dbh->commit;
    print "Update for new genotype files successful.....\n";
}

$dbh->disconnect();






