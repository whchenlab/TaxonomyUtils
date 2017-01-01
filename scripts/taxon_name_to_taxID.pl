#!/usr/bin/perl -w
use strict;
use POSIX;
use Data::Dumper;
use String::Util qw(trim);
use Term::ANSIColor;
use File::Basename;
my $dirname = dirname(__FILE__);
#print STDERR "\tdir name of current BIN: $dirname \n";

## -- 载入所需的sub functions --
require "$dirname/taxonomy_utils.pl";

## *********************************************
## ** version history **
## *********************************************
my $ver = '1.0';
my $last_modified = 'Jan 01, 2017';

## *********************************************
## ** GET opts **
## *********************************************
use Getopt::Long;
my %opts=();
GetOptions(\%opts,"i:s","db:s", "dbpass:s", "dbuser:s", "host:s", "o:s", "log:s", "target:s", "debug");

if (!$opts{i} or !$opts{o} or !$opts{log}){
    print "--------------------------------------------------------------------------------------------------
    \t\tversion : $ver by Weihua Chen; last modified : $last_modified
--------------------------------------------------------------------------------------------------
    USAGE: perl $0
        -i input file contains a list of taxon names, one per line, case sensitive
        -o output ncbi taxoID result file
        -log output log file
      [optional]
        -target target taxon name, can be multiple, separated by ',', for example
            bacteria
            archaea
            bacteria,archaea
         case-insensitive, default is none
        -debug, debug mode, if true, will print additional information to screen

        -db database, default biosql
        -dbpass database password
        -dbuser wchen
        -host localhost
--------------------------------------------------------------------------------------------------\n";
    exit;
}

### ====================================================================
## -- user input parameters for database  ...
use DBI;
my $MyDB        = defined $opts{db}     ? $opts{db}     : 'biosql';
my $dbuser      = defined $opts{dbuser} ? $opts{dbuser} : 'wchen';
my $dbpass      = defined $opts{dbpass} ? $opts{dbpass} : 'mylonelyboy';
my $host        = defined $opts{host}   ? $opts{host}   : 'localhost';

my %hTargetTaxons = ();
if( defined $opts{target} ){
    foreach my $target (split(/,/, lc $opts{target})){
        chomp $target;
        $hTargetTaxons{$target} ++;
    }
}

print Dumper %hTargetTaxons;

## -- user inpout parameters for input/output --
my $infile     = $opts{i};
my $outfile    = $opts{o};
my $logfile    = $opts{log};

## ======================================================================
if( defined $opts{target} ){
    print STDERR "\t======================================================\n";
    print STDERR "\t\tonly taxons belong to '", $opts{target}, "' will be retained.\n";
    print STDERR "\t======================================================\n\n";
}


## ======================================================================
## read input taxon names --
my %hash = ();
open IN, $infile or die;
while(my $line = <IN>){
    $line =~ tr/\n\r\t //d;
    chomp $line;
    ## -- remove trailing ;, for example: Taxonname; ==> Taxonname
    if( $line =~ /;$/ ){
        chop $line;
    }
    $hash{ $line } ++;
}
close IN;

my @aTaxonNames = sort keys %hash;
print Dumper @aTaxonNames if( defined $opts{debug}) if( defined $opts{debug});

## -- db handle --
my $dbh = DBI->connect("dbi:mysql:$MyDB:$host",$dbuser, $dbpass ,{PrintError=>0,RaiseError=>1}) or die "Can't connect to mysql database: $DBI::errstr\n";
my $sth_taxon_name_to_taxoID =$dbh->prepare( "select t1.name, t2.ncbi_taxon_id, t2.node_rank from taxon_name as t1, taxon as t2 where t1.name = ? and t2.taxon_id = t1.taxon_id;" );

my $valid_entries = 0;
## -- iterate taxon names one by one --
open OUT, ">$outfile" or die;
open LOG, ">$logfile" or die;
foreach my $taxonname ( @aTaxonNames ){
    ## -- do mysql query --
    $sth_taxon_name_to_taxoID->bind_param( 1, $taxonname ); ## $taxonname
    $sth_taxon_name_to_taxoID->execute();

    ## --
    my %hTaxIDsInScope = ();
    ## -- get results --
    while( my ( $sciname, $ncbi_taxon_id, $rank )  = $sth_taxon_name_to_taxoID->fetchrow_array()){
        my $flag = 0; ## a flag show whether or not this would be removed ...
        if( defined $opts{target} ){
            my @aResults = &path_to_root( $ncbi_taxon_id, $dbh );
            #print Dumper @aResults;
            foreach my $arrref135 (@aResults){
                my $current_taxon_name = lc $$arrref135[2]; ##
                if( exists $hTargetTaxons{ $current_taxon_name } ){
                    $flag ++;
                }
            }
        }

        if( (!$flag and !defined $opts{target} ) or ($flag and defined $opts{target}) ){
            print STDERR "\tadded: $ncbi_taxon_id, flag is: $flag  \n" if( defined $opts{debug});
            $hTaxIDsInScope{ $ncbi_taxon_id } ++;
        } else {
            print LOG "\tremoved due to out of scope: $sciname, $ncbi_taxon_id, $rank => $opts{target} \n";
        }
    }

    ## --
    if( (scalar keys %hTaxIDsInScope) == 1 ){
        print OUT join("\t", $taxonname, keys %hTaxIDsInScope), "\n";
        $valid_entries ++;
    } elsif( scalar keys %hTaxIDsInScope > 1 ) {
        print LOG "\tremoved due to ambigious hits: $taxonname: ", join(",", keys %hTaxIDsInScope), " \n";
    }

    $sth_taxon_name_to_taxoID->finish();
}
close OUT;
close LOG;

print STDERR "\n=============    stats   ===============\n";
print STDERR "\ttotal: ", scalar @aTaxonNames, ", valid: " , $valid_entries, "\n";
print STDERR "\n========================================\n\n";
