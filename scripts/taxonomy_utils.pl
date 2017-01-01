#!/usr/bin/perl -w
use strict;
use Data::Dumper;


####################################################
### -- taxon name to taxonID --
## -- input : NCBI taxon ID, case sensitive --
## -- output : array of taxonomy records: [ [taxon_name, ncbi_taxon_id, rank], [] ...  ] ;
sub taxon_name_to_taxonomy_ID {
    my ( $taxon_name, $dbh ) = @_;

    ## -- get current species by ncbi taxid --
    my $sth=$dbh->prepare( "select t1.name, t2.ncbi_taxon_id, t2.node_rank from taxon_name as t1, taxon as t2 where t1.name = ? and t2.taxon_id = t1.taxon_id;" );
    $sth->bind_param( 1, $taxon_name ); ## taxon_id
    $sth->execute();

    ## -- get results --
    my $arrref = $sth->fetchall_arrayref();
    $sth->finish();
    return $arrref;
}


## -- nucleotide or proten accession id to ncbi taxonomy_id --
sub accession_to_taxonomy_ID {
    my ( $accession, $db_optional, $debug_mode ) = @_;
    $db_optional = defined $db_optional ? $db_optional : 'nucleotide';
    $debug_mode = defined $debug_mode ? $debug_mode : 0;

    ## remove version number from accession, i.e. NC_017502.1 ==> NC_017502
    ($accession) = $accession =~ /(\w+)/;

    ## -- get taxonomy --
    use LWP::Simple;
    my $xml = get( "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=nucleotide&db=taxonomy&id=" . $accession );

    ## -- parse retrieved results
    use XML::Simple;
    my $xml_obj = XMLin( $xml );

    my $taxonomy_id = 0;
    my $obj = $$xml_obj{LinkSet}{LinkSetDb}{Link};
    if( ref( $obj ) eq 'HASH' ){
        $taxonomy_id = $$obj{Id};
    } elsif ( ref($obj) eq 'ARRAY' ){
        $taxonomy_id = $$obj[-1]{Id};
    }

    return $taxonomy_id;
}


###############################################################
## -- PATH to ROOT simpler bioperl version ... using remote NCBI service ; a bit slower ...
## -- bioperl version;
## -- input: a taxID --
## -- output: a list of taxIDs from current species to the root of the tree --
## --   output columns: idx ncbi_taxon_id sci_name rank parent_ncbi_taxon_id
## -- created July 25, 2016;
sub path_to_root_bioperl_best {
    my ( $query_ncbi_taxid ) = @_;

    use Bio::DB::Taxonomy;
    my $db = Bio::DB::Taxonomy->new(-source => 'entrez');
    my @aResults = ();

    my $idx = 0;
    ## -- get current species by ncbi taxid --
    my $taxon = $db->get_taxon(-taxonid => $query_ncbi_taxid);
    $idx ++;
    push @aResults, [ $idx, $taxon->ncbi_taxid(), $taxon->scientific_name(), $taxon->rank(), $taxon->parent_taxon_id() ];

    ## -- get parental taxons all the way to the root  --
    use Bio::Tree::Tree;
    my $tree_functions = Bio::Tree::Tree->new();
    my @lineage = $tree_functions->get_lineage_nodes($taxon);
    foreach my $node ( reverse @lineage ){
        $idx ++;
        push @aResults, [ $idx, $node->ncbi_taxid(), $node->scientific_name(), $node->rank(), $node->parent_taxon_id() ];
    }

    return @aResults;
}

###############################################################
## -- PATH to ROOT BIOPERL version ... using remote NCBI service ; a bit slower ...
## -- bioperl version;
## -- input: a taxID --
## -- output: a list of taxIDs from current species to the root of the tree --
## --   output columns: idx ncbi_taxon_id sci_name rank parent_ncbi_taxon_id
## -- created July 25, 2016;
sub path_to_root_bioperl {
    my ( $query_ncbi_taxid ) = @_;

    use Bio::DB::Taxonomy;
    my $db = Bio::DB::Taxonomy->new(-source => 'entrez');
    my @aResults = ();

    my $idx = 0;
    ## -- get current species by ncbi taxid --
    my $taxon = $db->get_taxon(-taxonid => $query_ncbi_taxid);
    $idx ++;
    push @aResults, [ $idx, $query_ncbi_taxid, $taxon->scientific_name(), $taxon->rank(), $taxon->parent_taxon_id() ];
    my $parent_taxon_id = $taxon->parent_taxon_id();

    ## -- get parental species by internal taxid --
    if( $parent_taxon_id > 0 ){
        while(1){

            $idx ++;

            my $retrieved_count = 0;
            my $exit = 0;

            my $current_taxon = $db->get_taxon(-taxonid => $parent_taxon_id);
            my $current_parent_taxon_id = $current_taxon->parent_taxon_id();

                if( defined $current_parent_taxon_id ){
                    $retrieved_count ++;
                    push @aResults, [ $idx, $parent_taxon_id, $current_taxon->scientific_name(), $current_taxon->rank(), $current_taxon->parent_taxon_id() ];

                    $exit ++ if( $current_taxon->scientific_name() eq 'root' );
                    $parent_taxon_id = $current_parent_taxon_id;
            }

            if( $retrieved_count <= 0 or $exit > 0 ){
                last; ## exit the loop;
            }
        }
    }

    return @aResults;
}



## -- created July 25, 2016 --;
## path to root using local DATABASE: biosql, faster ...
## -- input: a taxID --
## -- output: a list of taxIDs from current species to the root of the tree --
## --   output columns: idx ncbi_taxon_id sci_name rank parent_ncbi_taxon_id
## -- non-bioperl version --
sub path_to_root {
    my ( $query_ncbi_taxid, $dbh ) = @_;

    my @aResults = ();

    my $idx = 0;
    ## -- get current species by ncbi taxid --
    my $sth=$dbh->prepare( "SELECT t1.name, t2.node_rank, t2.parent_taxon_id, t3.ncbi_taxon_id as parent_ncbi_taxon_id FROM taxon as t2, taxon_name as t1, taxon as t3 where t2.taxon_id = t1.taxon_id AND t1.name_class='scientific name' AND t2.ncbi_taxon_id=? AND t3.taxon_id = t2.parent_taxon_id;" );
    my $query_internal_taxid = 0;
    $sth->bind_param( 1, $query_ncbi_taxid ); ## taxon_id
    $sth->execute();
    while( my ($sciname, $rank, $parent_taxon_id, $parent_ncbi_taxon_id) = $sth->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
        if( defined $parent_taxon_id ){
            $idx ++;
            push @aResults, [$idx, $query_ncbi_taxid, $sciname, $rank, $parent_ncbi_taxon_id];

            $query_internal_taxid = $parent_taxon_id; ##
        }
    }

    ## -- get parental species by internal taxid --
    my $sth_internal=$dbh->prepare( "SELECT t1.name, t2.ncbi_taxon_id, t2.node_rank, t2.parent_taxon_id, t3.ncbi_taxon_id as parent_ncbi_taxon_id FROM taxon as t2, taxon_name as t1, taxon as t3 where t2.taxon_id = t1.taxon_id AND t1.name_class='scientific name' AND t2.taxon_id=? AND t3.taxon_id = t2.parent_taxon_id;" );
    if( $query_internal_taxid > 0 ){
        while(1){
            $sth_internal->bind_param( 1, $query_internal_taxid ); ## taxon_id
            $sth_internal->execute();

            $idx ++;

            my $retrieved_count = 0;
            my $exit = 0;
            while( my ($sciname,  $ncbi_taxon_id, $rank, $parent_taxon_id, $parent_ncbi_taxon_id) = $sth_internal->fetchrow_array() ){ ## sciname, rank, taxid, parent_taxon_id
                if( defined $parent_taxon_id ){
                    $retrieved_count ++;
                    push @aResults, [$idx, $ncbi_taxon_id, $sciname, $rank, $parent_ncbi_taxon_id];

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

1;  ## -- --
