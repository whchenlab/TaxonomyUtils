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
my $last_modified = 'May 15, 2017';

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
        -i input ncbi taxonID, should be a non-species NCBI taxon ID
        -dbpass database password
      [optional]
        -dbuser wchen
        -host localhost
        -d database, default is 'biosql'
      [NOTE]
        the following two table should exist in your database, otherwise pls consult section 'install NCBI taxonomy via BioSQL'
        of our README file
            taxon
            taxon_name

        -- some ncbi_taxon_id, taxon_id of selected taxons --
        select t1.ncbi_taxon_id, t1.taxon_id, t2.name from  taxon as t1, taxon_name as t2 where t2.taxon_id = t1.taxon_id and t1.node_rank = 'superkingdom' and t2.name_class = 'scientific name';
            +---------------+----------+-----------+
            | ncbi_taxon_id | taxon_id | name      |
            +---------------+----------+-----------+
            |             2 |      129 | Bacteria  |
            |          2157 |     1830 | Archaea   |
            |          2759 |     2293 | Eukaryota |
            |         10239 |     8438 | Viruses   |
            |         12884 |    10094 | Viroids   | -- Viroids only infect plants --
            +---------------+----------+-----------+
--------------------------------------------------------------------------------------------------\n";
    exit;
}

#################################################################
##  --- global parameters ---
#################################################################
use DBI;
my $MyDB        = defined $opts{d} ? $opts{d} : 'biosql';
my $dbuser      = defined $opts{dbuser} ? $opts{dbuser} : 'wchen';
my $dbpass      = $opts{dbpass};
my $host        = defined $opts{host} ? $opts{host} : 'localhost';

my $query_ncbi_taxid = $opts{ i }; ## please note this has to be a NCBI tax ID --
my $dbh = DBI->connect("dbi:mysql:$MyDB:$host",$dbuser, $dbpass ,{PrintError=>0,RaiseError=>1}) or die "Can't connect to mysql database: $DBI::errstr\n";

#################################################################
##  --- check if user-input NCBI taxon ID is not a species ---
#################################################################
## -- get current scientific name and taxon_id by ncbi taxon id --
my %hTaxID2Info = (); ## --  sci_name                        | ncbi_taxon_id | rank    | parent_taxon_id | taxon_id | name_class

my $my_taxon_id    = 0;
my $sth=$dbh->prepare( "select t1.node_rank, t2.name, t1.ncbi_taxon_id, t2.taxon_id  from taxon as t1, taxon_name as t2 where t1.ncbi_taxon_id = ? and t2.name_class = 'scientific name' and t1.taxon_id = t2.taxon_id" );
$sth->bind_param( 1, $query_ncbi_taxid ); ## taxon_id
$sth->execute();
while( my ( $rank, $sciname, $ncbi_taxon_id, $taxon_id ) = $sth->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
    $my_taxon_id = $taxon_id;
    print STDERR "\n\tyour input ($query_ncbi_taxid) correspond to $sciname, with rank: $rank and taxon id: $my_taxon_id ... \n\n";

    $hTaxID2Info{ $my_taxon_id } = [ $sciname, $rank, $ncbi_taxon_id, $taxon_id, -1 ];
}

#################################################################
##  --- get all descendents of the user-input taxonomy ---
#################################################################

&get_all_descendents( $my_taxon_id, \%hTaxID2Info );

#################################################################
##  --- write to STDOUT ---
#################################################################
print join("\t", qw(sci_name rank ncbi_taxon_id taxon_id parent_taxon_id name_class)), "\n";
while( my ( $taxon_id, $refarray ) = each %hTaxID2Info ){
    print join("\t", @{$refarray} ), "\n";
}

#################################################################
##  ---  a recursive function  ---
#################################################################
## -- created May 15, 2017 --;
## -- input:
##          + taxon ID (not NCBI taxon ID, please note the difference),
##          + reference to hash, to save search results
##          + reference to database search handle --
sub get_all_descendents {
    my ( $query_taxon_id, $hrTaxID2Info ) = @_;

    ## -- do query --
    my $sth_get_direct_descendent = $dbh->prepare( "select t2.name as sci_name, t1.node_rank as rank, t1.ncbi_taxon_id, t1.taxon_id, t1.parent_taxon_id, t2.name_class  from taxon as t1, taxon_name as t2 where t1.taxon_id = t2.taxon_id and t2.name_class = 'scientific name' and t1.parent_taxon_id = ?" );
    $sth_get_direct_descendent->bind_param( 1, $query_taxon_id ); ## taxon_id
    $sth_get_direct_descendent->execute();
    while( my ( $sciname, $rank, $current_ncbi_taxon_id, $current_taxon_id, $parent_taxon_id ) = $sth_get_direct_descendent->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
        if( defined $current_taxon_id ){
            if( !exists $$hrTaxID2Info{ $current_taxon_id } ){
                $$hrTaxID2Info{ $current_taxon_id } = [ $sciname, $rank, $current_ncbi_taxon_id, $current_taxon_id, $parent_taxon_id ];

                &get_all_descendents( $current_taxon_id, $hrTaxID2Info );
            }
        }
    }
}
