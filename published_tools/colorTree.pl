use strict;
use Bio::TreeIO;
use Bio::TreeIO::newick;
use Bio::TreeIO::nexus;
use Bio::TreeIO::nhx;
use Bio::Tree::Statistics;
use Bio::Tree::Node;
use Bio::Tree::Tree;

############################################################
# this program add custermed contents to a tree file (in newick format)
# and save modified tree into a dentro format, which can be open and 
# viewed by program DentroScope
# the following items can be custermed:
# line color, fill color, lable color, label fill color (background color)
# by Weihua Chen, HHU Duesseldorf
# last modified : March 30, 2009
############################################################

use Getopt::Long;
my %opts=();
GetOptions(\%opts,"i:s","o:s","c:s","f:s");

if (!$opts{i} or !$opts{o} or !$opts{c}){
    print "----------------------------------------------------------------------
    
    ColorTree v1.1 By Weihua Chen
    
    USAGE: $0
        -i input tree file 
        -c custom configure file
        -o output tree file, in dentro format
      [optional]
        -f tree format 'newick|nexus', default = 'newick'
----------------------------------------------------------------------\n";
    exit;
}
### >>> 1 load configuration file
my %hCustom = ();
&load_configuration_file($opts{c},\%hCustom);

### >>> 2 load tree file
my $intree = $opts{i};
my $treeFormat = defined $opts{f} ? $opts{f} : 'newick';
die "Tree format should be one of the 'newick|nexus'!!\nexiting...\n" if($treeFormat !~ /newick|nexus/);
my $treeio = new Bio::TreeIO(-format => $treeFormat, -file => $intree);
my $tree_serial = 0;

### some global variables
my %hNodes = ();
my %hLeafNodeConfig = ();

my $outTreeFile = ($opts{o} =~ /dendro$/) ? $opts{o} : $opts{o}.'.dendro'; # check the name of outfile
open OUT, ">$outTreeFile" or die;
print OUT '#DENDROSCOPE',"\n";
while(my $tree =  $treeio->next_tree){
    $tree_serial ++;
    my $size = $tree->number_nodes;
    my @nodes = $tree->get_nodes; ## -- also include internal nodes --
    
    # convert tree_obj to a string
    my $tree_string = '';
    open (my $fake_fh, "+<", \$tree_string);
    my $out = new Bio::TreeIO(-fh=>$fake_fh, -format=>'newick');
    $out->write_tree($tree);
    ## -- NOTE: this part could simply done by the following code:
    ## -- $tree_string = $tree->as_text('newick');
    
    print OUT '{TREE \'Tree',$tree_serial,'\'',"\n",$tree_string,'}',"\n",'{GRAPHVIEW',"\n","nnodes=",$size," nedges=",$size-1,"\n";
    
    ### >>> 3 get node and configuration
    my $node_serial = 0;
    my $depth_max = 0;
    
    %hNodes = ();
    %hLeafNodeConfig = ();
    for(my $i = 1; $i <= @nodes; $i ++){
        my $node = $nodes[$i-1];
        my $node_depth = 0; # depth stands for Hierarchical distance (level) between current node to its most distal leaf
        &depth_calculation($node,0,\$node_depth);
        $depth_max = ($depth_max < $node_depth) ? $node_depth : $depth_max;
        
        my $internal_id = $node->internal_id; # represents edge id
        $hNodes{'internal_id'}{$internal_id}{serial} = $i;
        $hNodes{'internal_id'}{$internal_id}{depth} = $node_depth;
        
        $hNodes{'serial_id'}{$i}{depth} = $node_depth;
        $hNodes{'serial_id'}{$i}{'internal_id'} = $internal_id;
        
        if (defined $node->id and ($node->id =~ /\S+/)){
            $hNodes{'serial_id'}{$i}{id} = $node->id; # note, when node->is_Leaf == TRUE, node->id stands for gene/ sequence id
                                                      # when node->is_Leaf == FALSE, node->id stands for bootstrap score
        }
        
        if ($node_depth == 0){ # if leaf node
            $node_serial ++;
            $hNodes{'internal_id'}{$internal_id}{id} = $node->id;
            $hNodes{'internal_id'}{$internal_id}{Y} = $node_serial;
            
            ### get leaf configuration, indluding node color, backgroud color and line-width
            my $node_id = $node->id;
            
            while(my ($type, $refhash_top) = each %hCustom){
                $type = uc $type;
                while(my ($config, $refhash) = each %{$refhash_top}){
                    foreach my $item (keys %{$refhash}){
                        if ($type eq 'PREFIX'){
                            if ($node_id =~/^$item/){
                                $hLeafNodeConfig{$config}{$i} = $$refhash{$item};
                                last;
                            }                            
                        }elsif($type eq 'COMPLETE'){
                            if ($node_id eq $item){
                                $hLeafNodeConfig{$config}{$i} = $$refhash{$item};
                                last;
                            }   
                        }elsif($type eq 'SURFIX' or $type eq 'SUFFIX'){
                            if ($node_id =~ /$item$/){
                                $hLeafNodeConfig{$config}{$i} = $$refhash{$item};
                                last;
                            }  
                        }elsif($type eq 'CONTAIN'){
                            if ($node_id =~ /$item/){
                                $hLeafNodeConfig{$config}{$i} = $$refhash{$item};
                                last;
                            } 
                        }
                    }
                }
            }
        }
        
        ### get ancestor node depth, used for edge position
        if (defined $node->ancestor()){
            my $ancestor_internal_id = $node->ancestor()->internal_id;
            $hNodes{'internal_id'}{$internal_id}{'ancestor_depth'} = $hNodes{'internal_id'}{$ancestor_internal_id}{depth};
        }
    } # end of for each node
    
    ### >>> 4 get edge configuration
    #print "height of root_node = ", $tree->get_root_node()->height(),"\n";
    #print "total branch length = ", $tree->total_branch_length(),"\n";
    #print "leaf node count : ",$node_serial,"\n";
    #print "max depth : ", $depth_max,"\n";
    
    my %hEdgeConfig = ();
    my %hY = ();
    foreach my $node (@nodes){
        my $internal_id = $node->internal_id();
        my $serial_id = $hNodes{'internal_id'}{$internal_id}{serial};
        
        &get_edgeColor($node,\%hEdgeConfig) if (!exists $hEdgeConfig{fg}{$internal_id});
        &get_edgeLinewidth($node,\%hEdgeConfig) if (!exists $hEdgeConfig{lw}{$internal_id});
        &get_internal_node_coordinates($node,\%hY) if (!exists $hY{$serial_id});
    }

    ### >>> 5 print out nodes    
    print OUT "nodes\n";
    
    my ($pre_fgColor,$current_fgColor, $pre_bgColor, $current_bgColor, $pre_lineWidth, $current_lineWideth) = ();
    foreach my $serial (sort{$a<=>$b} keys %hY){
        if (exists $hLeafNodeConfig{fg}{$serial}){
            $current_fgColor = $hLeafNodeConfig{fg}{$serial};
        }else{
            $current_fgColor = '0 0 0';
        }
        
        if (exists $hLeafNodeConfig{bg}{$serial}){
            $current_bgColor = $hLeafNodeConfig{bg}{$serial};
        }else{
            $current_bgColor = '255 255 255';
        }
        
        my $x_coordinate = $hNodes{'serial_id'}{$serial}{depth} == 0 ? 0 : '-'.$hNodes{'serial_id'}{$serial}{depth}.'.0';
        my $y_coordinate = ($serial == 1) ? $hY{$serial} + 0.5 : $hY{$serial};
        if ($y_coordinate !~ /\./){
            $y_coordinate .='.0';
        }
        print OUT $serial,':';
        print OUT ' nh=2 nw=2 fg=0 0 0 bg=0 0 0 w=1 sh=0' if ($serial == 1);
        print OUT ' x=',$x_coordinate,' y=',$y_coordinate;
        print OUT ' lc=',$current_fgColor if ($current_fgColor ne $pre_fgColor);
        print OUT ' lk=',$current_bgColor if ($current_bgColor ne $pre_bgColor);
        
        print OUT ' ll=7' if ($serial == 2);
        print OUT ' lx=0 ly=0 ll=3 lv=1' if ($serial == 1);
        
        if (exists $hNodes{'serial_id'}{$serial}{id}){
            print OUT ' lb=\'',$hNodes{'serial_id'}{$serial}{id},'\'';
        }
        print OUT ";\n";
        
        $pre_fgColor = $current_fgColor;
        $pre_bgColor = $current_bgColor;
    }
    
    ### >>> 6 print out edges
    print OUT "edges\n";
    ($pre_fgColor,$current_fgColor, $pre_lineWidth, $current_lineWideth) = ();
    my $first_edge = 1;
    foreach my $internal_id (sort{$a<=>$b} keys %{$hNodes{'internal_id'}}){
        my $serial_id = $hNodes{'internal_id'}{$internal_id}{serial};
        if($serial_id > 1){
            if (exists $hEdgeConfig{fg}{$internal_id}){
                $current_fgColor = $hEdgeConfig{fg}{$internal_id};
            }else{
                $current_fgColor = '0 0 0';
            }
            
            if (exists $hEdgeConfig{lw}{$internal_id}){
                $current_lineWideth = $hEdgeConfig{lw}{$internal_id};
            }else{
                $current_lineWideth = 1;
            }
            
            print OUT $serial_id-1,':';
            print OUT ' fg=',$current_fgColor if ($current_fgColor ne $pre_fgColor);
            print OUT ' w=',$current_lineWideth if ($current_lineWideth != $pre_lineWidth);
            print OUT ' sh=1' if($first_edge);
            
            my $x = '-'.$hNodes{'internal_id'}{$internal_id}{'ancestor_depth'}.'.0';
            my $y = ($hY{$serial_id} =~ /\./) ? $hY{$serial_id} : $hY{$serial_id}.'.0';
            
            print OUT ' ip= < ',$x,' ',$y,'>';
            print OUT ' dr=1 lc=0 0 0 lx=0 ly=0 ll=11 lv=1' if ($first_edge);
            print OUT ";\n";
            $first_edge = 0;
            
            $pre_fgColor=$current_fgColor;
            $pre_lineWidth = $current_lineWideth
        }
    }
    
    #print "leaf node count : ",$node_serial,"\n";
    #print "max depth : ", $depth_max,"\n";
    #
    my $x_scale = 800/$depth_max;
    
    ####### NOTE
    # yscale indicates how many pixs each leaf-node should take, for example, in this program, the font size is 11, so yscale equals 12 is perfect
    #   for the plot. However, for extra large trees, this constant value may be not good
    
    print OUT '}',"\n";
    print OUT "{DENDRO
root=1
drawer=RectangularCladogram
toscale=false
radiallabels=false
collapsed=0
trans=angle:0.0 scaleX:$x_scale scaleY:11 flipH:0 flipV:0 leftMargin:100 rightMargin:100 topMargin:100 bottomMargin:100;
}
";
}
close OUT;

################################################################
# SUB FUNCTIONS
################################################################
sub load_configuration_file{
    my ($infile, $ref_hash) = @_;
    open IN, $infile or die;
    while(<IN>){
        chomp;
        if(/\S+/){
            next if (/^#/); #skip annotation lines
            # configuration format: ID,forground color,backgroud color,line-width
            my @arr = split(/\t/,$_);
            my $type = $arr[0];
            my $item = $arr[1];
            if (defined $arr[2] and $arr[2] =~/\d/){
                $$ref_hash{$type}{'fg'}{$item} = $arr[2];
            }
            if (defined $arr[3] and $arr[3] =~/\d/){
                $$ref_hash{$type}{'bg'}{$item} = $arr[3];
            }
            if (defined $arr[4] and $arr[4] =~/\d/){
                $$ref_hash{$type}{'lw'}{$item} = $arr[4];
            }
        }
    }
    close IN;
}

sub get_internal_node_coordinates{
    my ($node,$ref_hash) = @_;
    my $internal_id = $node->internal_id;
    my $serial_id = $hNodes{'internal_id'}{$internal_id}{serial};
    if($node->is_Leaf){
        $$ref_hash{$serial_id} = $hNodes{'internal_id'}{$internal_id}{Y};
        return $hNodes{'internal_id'}{$internal_id}{Y};
    }else{
        my ($leaf_node1,$leaf_node2) = $node->each_Descendent;
        my $leaf_node1_Y = &get_internal_node_coordinates($leaf_node1,$ref_hash);
        my $leaf_node2_Y = &get_internal_node_coordinates($leaf_node2,$ref_hash);
        
        $$ref_hash{$serial_id} = ($leaf_node1_Y + $leaf_node2_Y)/2;
        return ($leaf_node1_Y + $leaf_node2_Y)/2;
    }
}

sub get_edgeColor{
    my ($node,$ref_hash) = @_;
    my $internal_id = $node->internal_id;
    my $serial_id = $hNodes{'internal_id'}{$internal_id}{serial};
    if($node->is_Leaf){
        my $color = (exists $hLeafNodeConfig{'fg'}{$serial_id}) ? $hLeafNodeConfig{'fg'}{$serial_id} : 'black';
        $$ref_hash{fg}{$internal_id} = $color if ($color ne 'black');
        return $color;
    }else{
        my ($leaf_node1,$leaf_node2) = $node->each_Descendent;
        my $leaf_node1_color = &get_edgeColor($leaf_node1,$ref_hash);
        my $leaf_node2_color = &get_edgeColor($leaf_node2,$ref_hash);
        
        my $color = ($leaf_node1_color eq $leaf_node2_color and $leaf_node2_color ne 'black') ? $leaf_node1_color : 'black';
        $$ref_hash{fg}{$internal_id} = $color if ($color ne 'black');
        return $color;
    }
}

sub get_edgeLinewidth{
    my ($node,$ref_hash) = @_;
    my $internal_id = $node->internal_id;
    my $serial_id = $hNodes{'internal_id'}{$internal_id}{serial};
    if($node->is_Leaf){
        my $lw = (exists $hLeafNodeConfig{'lw'}{$serial_id}) ? $hLeafNodeConfig{'lw'}{$serial_id} : 1;
        $$ref_hash{lw}{$internal_id} = $lw if ($lw > 1);
        return $lw;
    }else{
        my ($leaf_node1,$leaf_node2) = $node->each_Descendent;
        my $leaf_node1_lw = &get_edgeLinewidth($leaf_node1,$ref_hash);
        my $leaf_node2_lw = &get_edgeLinewidth($leaf_node2,$ref_hash);
        
        my $lw = ($leaf_node1_lw == $leaf_node2_lw and $leaf_node1_lw > 1) ? $leaf_node2_lw : 1;
        $$ref_hash{lw}{$internal_id} = $lw if ($lw  > 1 and exists $$ref_hash{fg}{$internal_id});
        return $lw;
    }
}

sub depth_calculation{
    my ($node,$current_depth,$max_ref) = @_;
    if ($node->is_Leaf){
        $$max_ref = ($$max_ref < $current_depth) ? $current_depth : $$max_ref;
        return;
    }else{
        $current_depth++;
        foreach my $child ($node->each_Descendent()){
            &depth_calculation($child,$current_depth,$max_ref);
        }
    }    
}
