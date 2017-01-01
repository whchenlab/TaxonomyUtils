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
require "$dirname/../taxonomy_utils.pl";

use DBI;

my $MyDB        =  'biosql';
my $dbuser      =  'wchen';
my $dbpass      =  'mylonelyboy';
my $host        =  '127.0.0.1';

my $dbh         = DBI->connect("dbi:mysql:$MyDB:$host",$dbuser, $dbpass ,{PrintError=>0,RaiseError=>1}) or die "Can't connect to mysql database: $DBI::errstr\n";


my $arrref = &taxon_name_to_taxonomy_ID( "Bergeriella", $dbh );

print Dumper $arrref;
print "\n";
