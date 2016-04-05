#!/usr/local/bin/perl -w
=head1 LICENCE
Copyright 2015 EMBL - European Bioinformatics Institute (EMBL-EBI)
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
        http://www.apache.org/licenses/LICENSE-2.0
        Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
=head1 NAME
list4imsr.pl
=head1 SYNOPSIS
=cut

#
#  Get the list of strains for EMMA the IMSR.
#
#  Usage:
#     list4imsr.pl (no arguments) ... gives the full usage
#
#  Comments to: Jitka Sengerova <jitka@ebi.ac.uk>
#  Started: September, 2004
#
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
sub usage {
    print << "END_OF_HELP";

  Usage:   list2imsr.pl [options]

   where options are:

      -u <user>   ... user allowed to access and change EMMA database
                      (default: taken from the CFG.pl file)
      -p <passwd> ... password to access and change EMMA database
                      (default: taken from the CFG.pl file)
      -s <dbase>  ... database to access
                      (default: taken from the CFG.pl file)

      -f <filename>   file to store the result (optional, by default
                      the name of the file is:  em_yyyy_mm_dd.dat)

      -v ... verbose mode
      -h ... display this help

END_OF_HELP
}

# -----------------------------------------------------------------------------
# Initialize...
# -----------------------------------------------------------------------------
use vars qw( $VERSION $Revision $verbose );
use vars qw( $opt_v $opt_h $opt_u $opt_p $opt_s $opt_f );
use strict;

BEGIN {
    $VERSION = do { my @r = (q$Revision: 1.18 $ =~ /\d+/g); sprintf "%d.%-02d", @r };
    $Revision = q$Id: list4imsr.pl,v 1.18 2007/06/11 22:38:20 butler Exp $;
    my $_lib;
    ($_lib = $0) =~ s|/[^/]+$||;
    unshift @INC, $_lib;

	
## load configuration
eval { require "CFG.pl" } || die "Configuration file 'CFG.pl' was not found.\n";

}

use Getopt::Std;            # access to the command line
use DBI;                    # access to the database
use Data::Dumper;           # just for debugging

# -----------------------------------------------------------------------------
# Main program
# -----------------------------------------------------------------------------
#if ( $ARGV[0] eq "") {
#    &usage;
#    exit;
#}
#Use of uninitialized value in string eq at ./list4imsr.pl line 61.
# ???

# --- process the command line
getopts ('u:p:s:f:hv');
if ( $opt_h ) {
    &usage;
    exit;
}

my $user    = ( $opt_u ? $opt_u : $dbCfg::USER);
my $passwd  = ( $opt_p ? $opt_p : $dbCfg::PASSWD);
my $dbase   = ( $opt_p ? $opt_p : $dbCfg::DATABASE);
my $verbose = ( $opt_v ? $opt_v : 0 );

my $timestamp = `date`; chop $timestamp;
print "\n" . $timestamp . "\n";

# --- establish a connection to a database
my $dbh = DBI->connect($CFG::DSN, $CFG::USER, $CFG::PASSWD, 
{InactiveDestroy => 1, RaiseError => 1, PrintError => 1, AutoCommit => 0}
);

# --- prepare the statement to get the strain list from the database
#     strains.str_access = 'P'
#
my ($selStrains, $selState);
# --- oracle/mysql division may not be needed - no differences
#

    $selStrains = $dbh->prepare ("
        SELECT strains.id_str, strains.emma_id, strains.name, strains.str_type,
	           alleles.mgi_ref, alleles.alls_form, alleles.name, 
               mutations.main_type, genes.chromosome,
	           genes.mgi_ref, genes.symbol, genes.name,
	           mutations.sub_type
          FROM strains, mutations_strains, mutations, alleles, genes
         WHERE strains.id_str = mutations_strains.str_id_str
           AND mutations_strains.mut_id=mutations.id
           AND mutations.alls_id_allel = alleles.id_allel
           AND alleles.gen_id_gene = genes.id_gene
           AND ((strains.str_access = 'P' AND strains.str_status = 'ARCHD') OR (strains.str_access='P' AND strains.str_status IN ('ARRD','ARING','ARCHD') AND (strains.name like '%EUCOMM%' OR strains.name like '%not yet%')))
      ORDER BY emma_id
                             ");
    $selState = $dbh->prepare ("
        SELECT code FROM cv_availabilities cv, availabilities_strains a
         WHERE cv.id=a.avail_id AND to_distr = 1 AND str_id_str = ?
                             ");

$selStrains->execute ();

# --- create the name of the file
my $file;
if ( $opt_f ) {
    $file = $opt_f;
} else {
    #     Get the a ll the values for current time 
    my ($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time) ;
    $Year += 1900;
    $Month += 1;
    $Month = '0' . $Month if ( $Month < 10 );
    $Day   = '0' . $Day   if ( $Day   < 10 );
    $file = 'em_' . $Year . '_' . $Month. '_' . $Day . '.dat';
}

my $state;   # -- availability not included in the main select

open (FILE, "> $file") || die "Can't open the file $file.";
while (my @strain = $selStrains->fetchrow_array) {
    print "Strain: " . $strain[0] . "\n" if $verbose;
    # -- cleaning ...
    foreach (@strain) {
        if ( defined $_ ) {
	    # -- remove leading and trailing spaces
	    s/^\s*//;
	    s/\s*$//;
	    # -- remove leading and trailing doublequotes
	    s/^\"*//;
	    s/\"*$//;
	    # --- replace the <sup> with < and </sup> with > in the names
	    #     of the strains, alleles and genes
	    s/\<sup\>/\</ig;
	    s/\<\/sup\>/\>/ig;
	    s/{/\</ig;
	    s/}/\>/ig;
	    # --- make the field empty if 'unknown', '?', 'N/A', '-', '/'
	    s/^Unknown\sat\spresent$//;
	    s/^N\/A$//;
	    s/^\?$//;
	    s/^\-$//;
	    s/^\/$//;
	} else {    # --- initialize if undefined
	    $_ = '';
	}
    }

    # --- ammend the elements of the row to suit IMSR rules
    my ($strain_id, $id, $designation, $strType, $mgiAllele, $symbolAllele, $nameAllele, $mutType, $chromosome, $mgiGene, $symbolGene, $nameGene, $mutSubType) = @strain;

    # -- map the mutation type
    # TM/gene trap (EMMA)             -> GT (IMSR)
    # TM/knock-out (EMMA)             -> TM (IMSR)
    # TM/knock-in (EMMA)              -> TM (IMSR)
    # TM/point mutation (EMMA)        -> TM (IMSR)
    # TM/conditional mutation (EMMA)  -> TM (IMSR)
    # (TM/other targeted (EMMA)       -> TM (IMSR))
    # TG (EMMA)                       -> TG (IMSR)
    # CH/Insertion (EMMA)             -> INS (IMSR)
    # CH/Inversion (EMMA)             -> INV (IMSR)
    # CH/Deletion (EMMA)              -> DEL (IMSR)
    # CH/Duplication (EMMA)           -> DP (IMSR)
    # CH/Trasposition (EMMA)          -> TP (IMSR)
    # CH/Translocation                -> CH (IMSR)  
    #         (this 'cos EMMA does not distinguish between 'Robertsonian 
    #          translocation' and 'reciprocal translocation' as IMSR)
    #         (these CH mappings above are based on my understanding that IMSR 
    #          'chr. abberation' can be consider a synonym of EMMA's ' chr.  anomaly')
    # IN (chemical) (EMMA)            -> CI (IMSR)
    # IN (radiation) (EMMA)           -> RAD (IMSR)
    # CG (EMMA)                       -> OTH (IMSR)
    # XX (EMMA)                       -> OTH (IMSR)
    # IMSR - no equivalent in EMMA 
    # RB	 Robertsonian translocation
    # TL	 reciprocal translocation
    SWITCH: {
	if ( $mutType eq 'SP' ) { $mutType = 'SM'; last SWITCH; }
	if ( $mutType eq 'TM' ) {
	    $mutType = ( defined $mutSubType && $mutSubType eq 'GT' ? 'GT' : 'TM' );
	    last SWITCH;
	}
	if ( $mutType eq 'IN' ) {
	    $mutType = ( defined $mutSubType && $mutSubType eq 'CH' ? 'CI' : 'RAD' );
	    last SWITCH;
	}
	if ( $mutType eq 'TG' ) { $mutType = 'TG'; last SWITCH; }
	if ( $mutType eq 'CH' ) {
	    SWITCH: { 
		if ( defined $mutSubType && $mutSubType eq 'TRL' ) { $mutType = 'TP'; last SWITCH; }
		if ( defined $mutSubType && $mutSubType eq 'INS' ) { $mutType = 'INS'; last SWITCH; }
		if ( defined $mutSubType && $mutSubType eq 'INV' ) { $mutType = 'INV'; last SWITCH; }
		if ( defined $mutSubType && $mutSubType eq 'DEL' ) { $mutType = 'DEL'; last SWITCH; }
		if ( defined $mutSubType && $mutSubType eq 'DUP' ) { $mutType = 'DP'; last SWITCH; }
	    }
	    last SWITCH;
	}
	if ( $mutType eq 'CG' ) { $mutType = 'OTH'; $strType = 'CON'; last SWITCH; }
	if ( $mutType eq 'XX' ) { $mutType = 'OTH'; last SWITCH; }
    }
    # --- fill the chromosome with 'UN' if not defined
    $chromosome = ( defined $chromosome ? $chromosome : 'UN' );
    # --- fill the strType with 'UN' if not defined
    $strType = ( defined $strType ? $strType : 'UN' );
    # --- prepend MGI: to the mgi references
    $mgiAllele = 'MGI:' . $mgiAllele if defined $mgiAllele;    # allele
    $mgiGene   = 'MGI:' . $mgiGene if defined $mgiGene;        # gene

    # --- get the state (availability of the strain processed)
    # --- get just the number to update the right record
   # my $strain_id = $id;
    #$strain_id =~ s/^(EM:)?0*//; 
    $selState->execute($strain_id);
    $state = '';
    while (my @avail = $selState->fetchrow_array) {
	$state .= ',' if ((length($state) > 0) && $avail[0] ne 'R');
	# -- map the availability
	# EMMA                                           IMSR
	# L   Live mice                                  -> LM    live mouse
	# E   Frozen embryos                             -> EM
	# S   Frozen sperm                               -> SP
	# O   Frozen ovaries                             -> OV
	# C   Frozen ES cells                            -> ES
	# R  Mice rederived from frozen embryos         -> EM

        SWITCH: {
	    if ( $avail[0] eq 'L' )  { $state .= 'LM'; last SWITCH; }
	    if ( $avail[0] eq 'E' )  { $state .= 'EM'; last SWITCH; }
	    if ( $avail[0] eq 'S' )  { $state .= 'SP'; last SWITCH; }
	    if ( $avail[0] eq 'O' )  { $state .= 'OV'; last SWITCH; }
	    if ( $avail[0] eq 'C' )  { $state .= 'ES'; last SWITCH; }
	    #if ( $avail[0] eq 'R' )  { $state .= 'LM'; last SWITCH; }

	}
    }
    $state = 'EM' if ($state eq '');# to deal with lines like EM:2000 where only value is R
    # --- put the record for IMSR into the array
    my @strain4imsr = ($id, $designation, $strType, $state, $mgiAllele, $symbolAllele, $nameAllele, $mutType, $chromosome, $mgiGene, $symbolGene, $nameGene);

    print Data::Dumper->Dump ( [@strain4imsr], ["Strain4imsr"] ) if $verbose;
    print FILE join ("\t", @strain4imsr) . "\n";
}
close (FILE);
$selStrains->finish();
$selState->finish();
$dbh->disconnect();

__END__

