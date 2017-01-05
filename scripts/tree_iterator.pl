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
my $last_modified   = 'Jan 5, 2017';

## *********************************************
## ** GET opts **
## *********************************************
use Getopt::Long;
my %opts=();
GetOptions(\%opts,"i:s","d:s", "dbpass:s", "dbuser:s", "host:s", "o:s", "t:s", "l:s");

if (!$opts{i} or !$opts{l} or !$opts{t} or !$opts{o}){
    print "--------------------------------------------------------------------------------------------------
    \t\tversion : $ver by Weihua Chen; last modified : $last_modified
--------------------------------------------------------------------------------------------------
    USAGE: perl $0
        -i input tree file in newick format; only the first tree will be processed ...
        -l taxonomy level by which leaf-nodes to be groupped, for example family
        -t task to perform, for example:
            list : list leaf species names and corresponding taxIDs
            pairwise : list all possible pairs within each group
        -o output file
      [optional]
        -dbuser database user name, default is wchen
        -host database host, default is localhost
        -dbpass database password, default is xxx
        -d database, default is biosql
--------------------------------------------------------------------------------------------------\n";
    exit;
}
########################################################################
##### -- database configurations --
use DBI;
my $MyDB        = defined $opts{d}      ? $opts{d}      : 'biosql';
my $dbuser      = defined $opts{dbuser} ? $opts{dbuser} : 'wchen';
my $dbpass      = defined $opts{dbpass} ? $opts{dbpass} : 'mylonelyboy';
my $host        = defined $opts{host}   ? $opts{host}   : 'localhost';

my $dbh = DBI->connect("dbi:mysql:$MyDB:$host",$dbuser, $dbpass ,{PrintError=>0,RaiseError=>1}) or die "Can't connect to mysql database: $DBI::errstr\n";
my $sth_get_taxid_and_rank_by_name = $dbh->prepare( "select t2.ncbi_taxon_id, t2.node_rank from taxon_name as t1, taxon as t2 where t1.name = ? and t2.taxon_id = t1.taxon_id limit 1;" );

########################################################################
##### -- other global parameters --
my $infile      = $opts{i};
my $task        = lc $opts{t};
my $tax_level   = lc $opts{l};
my $outfile     = $opts{o};

my %hValidTasks = ( 'list' => 1, 'pairwise' => 1 );
if( !exists $hValidTasks{ $task } ){
    print STDERR "\tinvalid task name, default will be used !!\n";
    $task = 'list';
}

## -- load necessary modules --
use Bio::TreeIO;
use Bio::TreeIO::newick;
use Bio::TreeIO::nexus;
use Bio::TreeIO::nhx;
use Bio::Tree::Statistics;
use Bio::Tree::Node;
use Bio::Tree::Tree;

########################################################################
##### -- process input file, assign leaf nodes into distinct groups --
my $treeFormat  = 'newick';
my $treeio      = new Bio::TreeIO(-format => $treeFormat, -file => $infile);
my $tree        = $treeio->next_tree(); ## only load the first tree

my %hGroup2Leafs            = (); ## -- $hash{ $group_name }{ $leaf_node } ++;
my %hTaxonNames             = (); ## keep tracking valid target groups -- $hash{ $taxon_name } = ( $taxon_id, $rank );

## -- iterate all leaf nodes --
foreach my $leaf_node ( $tree->get_leaf_nodes() ){
    ## -- keep tracking its ancestor until the target taxon or the root is reached ...
    my $found = 0;
    my $p_node = $leaf_node->ancestor();
    while( !$found and $p_node ){
        ## --
        my $pid = $p_node->id();

        if( defined $pid ){
            if( !exists $hTaxonNames{ $pid } ){
                $sth_get_taxid_and_rank_by_name->bind_param(1, $pid);
                $sth_get_taxid_and_rank_by_name->execute();
                my ( $ncbi_taxon_id, $ncbi_rank ) = ( 0, 'na' );
                while( my ($current_taxon_id, $current_rank) = $sth_get_taxid_and_rank_by_name->fetchrow_array() ){
                    $ncbi_taxon_id  = $current_taxon_id;
                    $ncbi_rank      = lc $current_rank;
                }

                ## -- --
                $hTaxonNames{ $pid } = [ $ncbi_taxon_id, $ncbi_rank ];
            }

            ## --
            my ( $taxid, $rank ) = @{$hTaxonNames{ $pid }};
            if( $rank eq $tax_level  ){
                $hGroup2Leafs{ $pid }{ $leaf_node->id } ++;
                $found = 1;
            }
        }
        ## --
        $p_node = $p_node->ancestor();
    }
}


my $groups_with_one_member = 0;
my $total_groups = scalar keys %hGroup2Leafs;
###################################################################
#### output file --
open OUT, ">$outfile" or die;
if( $task eq 'list' ){
    print OUT join("\t", qw(tax_group leaf_node)), "\n";
} else {
    print OUT join("\t", qw(tax_group leaf_node1 leaf_node2)), "\n";
}
while( my ( $group, $refhash ) = each %hGroup2Leafs ){
    my @aLeafs = sort keys %{$refhash};
    $groups_with_one_member ++ if( scalar @aLeafs == 1 );

    if ( $task eq 'list' ){
        foreach my $leaf ( @aLeafs ){
            print OUT join("\t", $group, $leaf ), "\n";
        }
    } elsif ( $task eq 'pairwise' ){
        for( my $i = 0; $i < @aLeafs; $i ++){
            for( my $j = $i + 1; $j < @aLeafs; $j ++){
                print OUT join("\t", $group, $aLeafs[$i], $aLeafs[$j] ), "\n";
            }
        }
    }
}
close OUT;


###################################################################
### --- print out some statistitical information --
print STDERR "---------------------------------------------\n";
print STDERR "\tin total $total_groups groups obtained \n";
print STDERR "\t\tin which $groups_with_one_member groups contain only one member each ...\n\n";
