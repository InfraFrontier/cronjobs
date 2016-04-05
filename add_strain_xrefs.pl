#!/usr/bin/perl -w
=head1 LICENCE
Copyright 2015 EMBL - European Bioinformatics Institute (EMBL-EBI)
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
        http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
=head1 NAME
add_strain_xrefs.pl
=head1 SYNOPSIS
=cut

use strict;
use warnings;
use DBI;

my (%input_data,%output_data);


## load configuration
eval { require "CFG.pl" } ||
die "Configuration file 'CFG.pl' was not found.\n";
my $dbh = DBI->connect(
$CFG::DSN, $CFG::USER, $CFG::PASSWD,
{
	InactiveDestroy => 1, RaiseError => 1, PrintError => 1}
 );

# excludes EUCOMM centres and LEX/DEL, Martin Hrabe, Lluis and Yann

my $sql = "set session group_concat_max_len = 10240";
my $sth = $dbh->prepare($sql);
$sth->execute;

$sql = "update strains set mutation_xref = null";
$sth = $dbh->prepare($sql);
$sth->execute;
$sql = "update strains set owner_xref = null";
$sth = $dbh->prepare($sql);
$sth->execute;



$sql = "select group_concat(emma_id) from strains, people where per_id_per=id_per and per_id_per not in (1196,8137,8,7858,8374,8579,8597,9060,8560,7786,7787) and str_access not in ('R','N','C') and str_status not in ('ACCD','EVAL','RJCTD','TNA') group by per_id_per having count(*) > 1 order by emma_id";
$sth = $dbh->prepare($sql);
$sth->execute;

while (my @results = $sth->fetchrow_array){
    my @emma_ids = split(/,/,$results[0]);
    my $i = 1;
    my $max = @emma_ids;
    foreach my $emma_id(@emma_ids){
	my @xrefs = (@emma_ids[0..$i-2],@emma_ids[$i..$max-1]);
	my $owner_xref;
	foreach my $xref(@xrefs){
	    $owner_xref .= "<a href=\"http://www.emmanet.org/mutant_types.php?keyword=$xref\" target=\"_blank\">$xref</a>, ", 
	}
	chop $owner_xref;
	chop $owner_xref;
	my $sql2 = "UPDATE strains SET owner_xref = '$owner_xref' WHERE emma_id='$emma_id'";
	my $sth2 = $dbh->prepare($sql2);
	
	$sth2->execute;
	$i++;
    }
}

$sql = "select group_concat(emma_id) from strains s, mutations_strains ms, mutations m, alleles a where id_str=ms.str_id_str and id=mut_id and id_allel=alls_id_allel and alls_form != 'NOD' and str_access not in ('R','N','C') and str_status not in ('ACCD','EVAL','RJCTD','TNA') group by alls_id_allel having count(id_str) > 1 order by emma_id";
$sth = $dbh->prepare($sql);
$sth->execute;

while (my @results = $sth->fetchrow_array){
    my @emma_ids = split(/,/,$results[0]);
    my $i = 1;
    my $max = @emma_ids;
    foreach my $emma_id(@emma_ids){
        my @xrefs = (@emma_ids[0..$i-2],@emma_ids[$i..$max-1]);
        my $mutation_xref;
        foreach my $xref(@xrefs){
            $mutation_xref .= "<a href=\"http://www.emmanet.org/mutant_types.php?keyword=$xref\"  target=\"_blank\">$xref</a>, ",
        }
        chop $mutation_xref;
        chop $mutation_xref;
        my $sql2 = "UPDATE strains SET mutation_xref = '$mutation_xref' WHERE emma_id='$emma_id'";
        my $sth2 = $dbh->prepare($sql2);
        #print $sql2."\n";
        $sth2->execute;                                                                                                      
        $i++;
    }
}
