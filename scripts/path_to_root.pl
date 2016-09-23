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
my $last_modified = 'July 18, 2016';

## *********************************************
## ** GET opts **
## *********************************************
use Getopt::Long;
my %opts=();
GetOptions(\%opts,"i:s","d:s", "dbpass:s", "dbuser:s", "host:s");

if (!$opts{i} or !$opts{dbpass}){
    print "--------------------------------------------------------------------------------------------------
    \t\tversion : $ver by Weihua Chen; last modified : $last_modified
--------------------------------------------------------------------------------------------------
    USAGE: perl $0
        -i input ncbi taxonID
        -dbpass database password
      [optional]
        -dbuser wchen
        -host localhost
--------------------------------------------------------------------------------------------------\n";
    exit;
}
use DBI;
my $MyDB        = defined $opts{d} ? $opts{d} : 'biosql';
my $dbuser      = defined $opts{dbuser} ? $opts{dbuser} : 'wchen';
my $dbpass      = $opts{dbpass};
my $host        = defined $opts{host} ? $opts{host} : 'localhost';

print join("\t", qw(idx ncbi_taxon_id sci_name rank parent_ncbi_taxon_id)),"\n";
#print "---- use bioperl module ----\n";
#my @arr = &path_to_root_bioperl( $opts{i});
#foreach my $arrref (@arr){
#    print join("\t", @{$arrref}), "\n";
#}


print "---- use local db ----\n";
my @arr = &path_to_root( $opts{i}, $MyDB, $dbuser, $dbpass, $host );
foreach my $arrref (@arr){
    print join("\t", @{$arrref}), "\n";
}


#print "---- use other bioperl modules 2 ----\n";
#@arr = &path_to_root_bioperl_best( $opts{i} );
#foreach my $arrref (@arr){
#    print join("\t", @{$arrref}), "\n";
#}

