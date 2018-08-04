## install NCBI taxonomy via BioSQL
1. download from https://github.com/biosql/biosql
2. run download taxonomy from NCBI and load it into database 'biosql' (_*make sure the database exists*_):
```
perl scripts/load_ncbi_taxonomy.pl \
    --dbname biosql --driver mysql --dbuser dbuser \
    --download true --dbpass xxx --allow_truncate
```

or download it via the following link, mv it to a taxdata folder, unzip it.
```
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
mkdir -p taxdata
mv taxdump.tar.gz taxdata/
tar -zxvf taxdata/tardump.tar.gz

perl scripts/load_ncbi_taxonomy.pl \
    --dbname biosql --driver mysql --dbuser dbuser \
    --dbpass xxx --allow_truncate
```

## scripts
### make flat taxon table
parameters
```
perl scripts/make_flat_taxon_table.pl -dbpass xxx -o output_mysql_table
```
this script assembles major rank information for an internal / leaf taxon and write it to output_mysql_table
here is the table structure:
```sql
CREATE TABLE `taxon2majorranks` (
  `taxon_id` int(10) NOT NULL,
  `ncbi_taxon_id` int(10) NOT NULL,
  `is_major_rank` BOOLEAN NOT NULL DEFAULT 0,
  `closest_major_rank_taxon_id` int(10) NOT NULL,
  `superkindom_taxon_id` int(10),
  `kindom_taxon_id` int(10),
  `phylum_taxon_id` int(10),
  `class_taxon_id` int(10),
  `order_taxon_id` int(10),
  `family_taxon_id` int(10),
  `genus_taxon_id` int(10),
  `species_taxon_id` int(10),
  PRIMARY KEY (`taxon_id`),
  UNIQUE KEY `ncbi_taxon_id` (`ncbi_taxon_id`),
  KEY `superkindom_taxon_id` (`superkindom_taxon_id`)
);
```

### path to root
input: ncbi taxonomy ID, such as 9606 (for human) and 10090 (for mouse)
output: parent nodes along the NCBI taxonomy tree all the way to the root.
```
perl scripts/path_to_root.pl -i 9606 -dbpass xxx
```

example output:
```
idx	ncbi_taxon_id   sci_name	rank	parent_taxon_id
1	10090	Mus musculus	species	663600
2	862507	Mus	subgenus	8313
3	10088	Mus	genus	20548
4	39107	Murinae	subfamily	8296
5	10066	Muridae	family	283793
6	337687	Muroidea	no rank	15923
7	33553	Sciurognathi	suborder	8236
8	9989	Rodentia	order	262436
9	314147	Glires	no rank	262435
10	314146	Euarchontoglires	superorder	1138860
11	1437010	Boreoeutheria	no rank	7694
12	9347	Eutheria	no rank	15430
13	32525	Theria	no rank	21915
14	40674	Mammalia	class	15429
15	32524	Amniota	no rank	15428
16	32523	Tetrapoda	no rank	1056738
17	1338369	Dipnotetrapodomorpha	no rank	6800
18	8287	Sarcopterygii	no rank	89261
19	117571	Euteleostomi	no rank	89260
20	117570	Teleostomi	no rank	6394
21	7776	Gnathostomata	no rank	6374
22	7742	Vertebrata	no rank	64724
23	89593	Craniata	subphylum	6345
24	7711	Chordata	phylum	15886
25	33511	Deuterostomia	no rank	15702
26	33213	Bilateria	no rank	5021
27	6072	Eumetazoa	no rank	15700
28	33208	Metazoa	kingdom	15660
29	33154	Opisthokonta	no rank	2293
30	2759	Eukaryota	superkingdom	101684
31	131567	cellular organisms	no rank	128
32	1	root	no rank	128
```

### taxon name to taxon ID converter
input : a text file contains a list of NCBI taxon names, one per line; trailing ';' will be removed

output : a list of valid taxon names and corresponding NCBI taxon IDs, one pair per line;

**other parameters:**
```
perl scripts/taxon_name_to_taxID.pl
--------------------------------------------------------------------------------------------------
           version : 1.0 by Weihua Chen; last modified : Jan 02, 2017
--------------------------------------------------------------------------------------------------
   USAGE: perl scripts/taxon_name_to_taxID.pl
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

     [note]
       taxon names like 'Candidatus_Accumulibacter' will be reformated as 'Candidatus Accumulibacter'
--------------------------------------------------------------------------------------------------
```

**command to run Ni's task:**
```
perl ~/development/GithubRepos/TaxonomyUtils/scripts/taxon_name_to_taxID.pl \
    -i taxonomy\ on\ genus\ level.txt  \
    -o taxonomy_on_genus_level_valided_chen.lst  \
    -log taxonomy_on_genus_level_invalide.txt \
    -target bacteria,archaea
```

### tree iterator
This script takes a NCBI taxonomy tree as input, iterates its leaf nodes and groups the latter into subgroups according to the user-supplied taxonomy level, e.g. family, order, class, or phylum. For example, a user-supplied taxonomy level 'order' means that leaf nodes should be grouped into subgroups according to the 'order' that they belong.

Based on these results, users can choose to either print the members of the subgroups, or make pairwise pairs within each subgroups.

**parameters**

```shell
--------------------------------------------------------------------------------------------------
    		version : 1.0 by Weihua Chen; last modified : Jan 5, 2017
--------------------------------------------------------------------------------------------------
    USAGE: perl /Users/wchen/development/GithubRepos/TaxonomyUtils/scripts/tree_iterator.pl
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
--------------------------------------------------------------------------------------------------
```

**shell command to for Ni's task**
```
perl /Users/wchen/development/GithubRepos/TaxonomyUtils/scripts/tree_iterator.pl \
    -i ../the_tree/Zcbk36n2u-F0h-k9klTbyg_newick_1400_species.txt \
    -l order \
    -t pairwise \
    -o 1400_species_group_by_order_pairwise.txt
```
