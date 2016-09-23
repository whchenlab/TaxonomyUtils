#!/usr/bin/perl -w
use strict;
use POSIX;
use Data::Dumper;
use String::Util qw(trim);
use Term::ANSIColor;
use Bio::DB::Taxonomy;

use File::Basename;
my $dirname = dirname(__FILE__);
#print STDERR "\tdir name of current BIN: $dirname \n";

## -- 载入所需的sub functions --
require "$dirname/taxonomy_utils.pl";

my $db = Bio::DB::Taxonomy->new(-source => 'entrez');

## -- GI to taxonomy --
my $gi = 71836523;
my $node = $db->get_Taxonomy_Node(-gi => $gi, -db => 'protein');
print Dumper $node, "\n";

## -- accession to taxonomy --
print "--- acc to taxnomy ----\n";
my $acc = 'NC_017502.222';
print "\tacc: $acc\n\ttaxonomy_id: ", &accession_to_taxonomy_ID( $acc ), "\n";

#my ($species,$genus,$family) =  $node->classification;
#print "family is $family\n";

use Bio::Tree::Tree;
  my $tree_functions = Bio::Tree::Tree->new();
  my @lineage = $tree_functions->get_lineage_nodes($node);
  my $lineage = $tree_functions->get_lineage_string($node);
  
  #print Dumper @lineage, "\n\n";
  

#print Dumper $node->classification;