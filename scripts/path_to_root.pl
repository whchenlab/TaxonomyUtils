#!/usr/bin/perl -w
use strict;
use POSIX;
use Data::Dumper;
use String::Util qw(trim);
use Term::ANSIColor;

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

print join("\t", qw(idx ncbi_taxon_id sci_name rank parent_taxon_id)),"\n";
my @arr = &path_to_root( $opts{i}, $dbuser, $dbpass, $host );
foreach my $arrref (@arr){
    print join("\t", @{$arrref}), "\n";
}


###############################################################
##
sub path_to_root {
    my ( $query_ncbi_taxid, $dbuser, $dbpass, $host ) = @_;
    my $dbh         = DBI->connect("dbi:mysql:$MyDB:$host",$dbuser, $dbpass ,{PrintError=>0,RaiseError=>1}) or die "Can't connect to mysql database: $DBI::errstr\n";
    my @aResults = ();

    my $idx = 0;
    ## -- get by ncbi taxid --
    my $sth=$dbh->prepare( "SELECT taxon_name.name, taxon.node_rank, taxon.parent_taxon_id FROM taxon, taxon_name where taxon.taxon_id = taxon_name.taxon_id AND taxon_name.name_class='scientific name' AND taxon.ncbi_taxon_id=?;" );
    my $query_internal_taxid = 0;
    $sth->bind_param( 1, $query_ncbi_taxid ); ## taxon_id
    $sth->execute();
    while( my ($sciname, $rank, $parent_taxon_id) = $sth->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
        if( defined $parent_taxon_id ){
            $idx ++;
            push @aResults, [$idx, $query_ncbi_taxid, $sciname, $rank, $parent_taxon_id];

            $query_internal_taxid = $parent_taxon_id; ##
        }
    }

    ## -- get by internal taxid --
    my $sth_internal=$dbh->prepare( "SELECT taxon_name.name, taxon.ncbi_taxon_id, taxon.node_rank, taxon.parent_taxon_id FROM taxon, taxon_name where taxon.taxon_id = taxon_name.taxon_id AND taxon_name.name_class='scientific name' AND taxon.taxon_id=?;" );
    if( $query_internal_taxid > 0 ){
        while(1){
            $sth_internal->bind_param( 1, $query_internal_taxid ); ## taxon_id
            $sth_internal->execute();

            $idx ++;

            my $retrieved_count = 0;
            my $exit = 0;
            while( my ($sciname,  $ncbi_taxon_id, $rank, $parent_taxon_id) = $sth_internal->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
                if( defined $parent_taxon_id ){
                    $retrieved_count ++;
                    push @aResults, [$idx, $ncbi_taxon_id, $sciname, $rank, $parent_taxon_id];

                    $exit ++ if( $ncbi_taxon_id == 1 or $parent_taxon_id == $query_internal_taxid );
                    $query_internal_taxid = $parent_taxon_id;
                }
            }

            if( $retrieved_count <= 0 or $exit > 0 ){
                last; ## exit the loop;
            }
        }
    }


    return @aResults;
}
