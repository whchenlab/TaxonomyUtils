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
my $ver             = '1.0';
my $created_on      = 'May 15, 2017';
$ver                = '2.0';
my $last_modified   = 'June 15, 2017';
my $note            = "modified from 'internal_node_to_all_descendents.pl'"; ## while, not really --

## *********************************************
## ** GET opts **
## *********************************************
use Getopt::Long;
my %opts=();
GetOptions(\%opts,"i:s","d:s", "o:s", "dbpass:s", "dbuser:s", "host:s");

if ( !$opts{ dbpass } or !$opts{ o } ){
    print "--------------------------------------------------------------------------------------------------
    \t\tcreated by Weihua Chen, on $created_on
    \t\tversion : $ver; last modified : $last_modified
--------------------------------------------------------------------------------------------------
    USAGE: perl $0
        -dbpass database password
        -o mysql table to write final results to; NOTE: this table should exist, all its contents will be removed ...

      [optional]
        -dbuser wchen
        -host localhost
        -d database, default is 'biosql'
        -i input ncbi taxonID, should be a non-species NCBI taxon ID， default (ncbi_taxon_id) = 1 ## root --

      [NOTE]
        the following two table should exist in your database, otherwise pls consult section 'install NCBI taxonomy via BioSQL'
        of our README file
            taxon
            taxon_name

        -- some ncbi_taxon_id, taxon_id of selected taxons --
        select t1.ncbi_taxon_id, t1.taxon_id, t2.name from  taxon as t1, taxon_name as t2 where t2.taxon_id = t1.taxon_id
            and t1.node_rank = 'superkingdom' and t2.name_class = 'scientific name';
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
my $dbtable     = $opts{o}; ## -- target table --

## -- major ranks to keep --
my %hMajorRanks = ( "Root" => 1, "kingdom" => 1, "phylum" => 1, "class" => 1, "order" => 1, "family" => 1, "genus" => 1, "species" => 1 );

my $query_ncbi_taxid = $opts{ i }; ## please note this has to be a NCBI tax ID --
my $dbh = DBI->connect("dbi:mysql:$MyDB:$host",$dbuser, $dbpass ,{PrintError=>0,RaiseError=>1}) or die "Can't connect to mysql database: $DBI::errstr\n";

#################################################################
##  --- check if user-input NCBI taxon ID is not a species ---
#################################################################
## -- get current scientific name and taxon_id by ncbi taxon id --
my $my_taxon_id    = 0;
my $sth=$dbh->prepare( "select t1.node_rank, t2.name, t1.ncbi_taxon_id, t2.taxon_id  from taxon as t1, taxon_name as t2 where t1.ncbi_taxon_id = ? and t2.name_class = 'scientific name' and t1.taxon_id = t2.taxon_id" );
$sth->bind_param( 1, $query_ncbi_taxid ); ## taxon_id
$sth->execute();
while( my ( $rank, $sciname, $ncbi_taxon_id, $taxon_id ) = $sth->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
    $my_taxon_id = $taxon_id;
    print STDERR "\n\tyour input ($query_ncbi_taxid) correspond to $sciname, with rank: $rank and taxon id: $my_taxon_id ... \n\n";
}

#################################################################
##  --- get all descendents of the user-input taxonomy ---
##  --- and write result to table 
#################################################################
## -- first, truncate target table --
$dbh->execute( "truncate  $dbtable" );

## -- prepare to insert --
my $insert = $dbh->prepare( "insert into $dbtable () VALUES (?,?,?,?,?,?,?,?,?,?,?,?)" ); ## 11 columns in total --

## -- then, get all descendents of current interner node --
&get_all_descendents_and_insert_into_table( $my_taxon_id, $query_ncbi_taxid, 1, $my_taxon_id );

#################################################################
##  ---  a recursive function  ---
#################################################################
## -- created May 15, 2017 --;
## -- input:
##          + taxon ID (not NCBI taxon ID, please note the difference),
##          + ncbi taxon id
##          + is major rank
##          + @aCurrentRankTaxons 
sub get_all_descendents_and_insert_into_table {
    my ( $query_taxon_id, $query_ncbi_taxon_id, $query_is_major_rank, @aCurrentRankTaxons ) = @_;

    ## -- do query --
    my $sth_get_direct_descendent = $dbh->prepare( "select t2.name as sci_name, t1.node_rank as rank, t1.ncbi_taxon_id, t1.taxon_id, t1.parent_taxon_id, t2.name_class  from taxon as t1, taxon_name as t2 where t1.taxon_id = t2.taxon_id and t2.name_class = 'scientific name' and t1.parent_taxon_id = ?" );
    $sth_get_direct_descendent->bind_param( 1, $query_taxon_id ); ## taxon_id
    $sth_get_direct_descendent->execute();
    
    my $flag = 0; ## here flag indicate how many daughtor node there are;
    while( my ( $sciname, $rank, $current_ncbi_taxon_id, $current_taxon_id, $parent_taxon_id ) = $sth_get_direct_descendent->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
        if( defined $current_taxon_id ){
            $flag ++;
            
            ## -- check if major rank --
            my $is_major_rank = 0;
            if( exists $hMajorRanks{ $rank } ){
                push @aCurrentRankTaxons, $current_taxon_id;
                $is_major_rank = 1;
            }
            
            ## -- insert into database --
            $insert->bind_param( 1, $current_taxon_id ); ## taxon_id
            $insert->bind_param( 2, $current_ncbi_taxon_id ); ## ncbi_taxon_id
            $insert->bind_param( 3, $is_major_rank ); ## is_major_rank
            $insert->bind_param( 4, 1 ); ## is_internal_node, is NOT species node --
            $insert->bind_param( 5, $aCurrentRankTaxons[-1] ); ## closest_major_rank_taxon_id
            $insert->bind_param( 6, defined $aCurrentRankTaxons[1] ? $aCurrentRankTaxons[1] : NULL ); ## kindom_taxon_id
            $insert->bind_param( 7, defined $aCurrentRankTaxons[2] ? $aCurrentRankTaxons[2] : NULL ); ## phylum_taxon_id
            $insert->bind_param( 8, defined $aCurrentRankTaxons[3] ? $aCurrentRankTaxons[3] : NULL ); ## class_taxon_id
            $insert->bind_param( 9, defined $aCurrentRankTaxons[4] ? $aCurrentRankTaxons[4] : NULL ); ## order_taxon_id
            $insert->bind_param(10, defined $aCurrentRankTaxons[5] ? $aCurrentRankTaxons[5] : NULL ); ## family_taxon_id
            $insert->bind_param(11, defined $aCurrentRankTaxons[6] ? $aCurrentRankTaxons[6] : NULL ); ## genus_taxon_id
            $insert->bind_param(12, defined $aCurrentRankTaxons[7] ? $aCurrentRankTaxons[7] : NULL ); ## species_taxon_id
            $insert->execute();
            
            ## -- get daughter nodes --
            &get_all_descendents_and_insert_into_table( $current_taxon_id, $current_ncbi_taxon_id, $is_major_rank, @aCurrentRankTaxons );
        }
    }
    
    ## -- if current species does not have any daughter nodes??? --
    if( !$flag ){
        ## -- insert into database --
        $insert->bind_param( 1, $query_taxon_id ); ## taxon_id
        $insert->bind_param( 2, $query_ncbi_taxon_id ); ## ncbi_taxon_id
        $insert->bind_param( 3, $query_is_major_rank ); ## is_major_rank
        $insert->bind_param( 4, 1 ); ## is_internal_node, is NOT species node --
        $insert->bind_param( 5, $aCurrentRankTaxons[-1] ); ## closest_major_rank_taxon_id
        $insert->bind_param( 6, defined $aCurrentRankTaxons[1] ? $aCurrentRankTaxons[1] : NULL ); ## kindom_taxon_id
        $insert->bind_param( 7, defined $aCurrentRankTaxons[2] ? $aCurrentRankTaxons[2] : NULL ); ## phylum_taxon_id
        $insert->bind_param( 8, defined $aCurrentRankTaxons[3] ? $aCurrentRankTaxons[3] : NULL ); ## class_taxon_id
        $insert->bind_param( 9, defined $aCurrentRankTaxons[4] ? $aCurrentRankTaxons[4] : NULL ); ## order_taxon_id
        $insert->bind_param(10, defined $aCurrentRankTaxons[5] ? $aCurrentRankTaxons[5] : NULL ); ## family_taxon_id
        $insert->bind_param(11, defined $aCurrentRankTaxons[6] ? $aCurrentRankTaxons[6] : NULL ); ## genus_taxon_id
        $insert->bind_param(12, defined $aCurrentRankTaxons[7] ? $aCurrentRankTaxons[7] : NULL ); ## species_taxon_id
        $insert->execute();
    }
}
