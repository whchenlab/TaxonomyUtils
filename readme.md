## install NCBI taxonomy via BioSQL
1. download from https://github.com/biosql/biosql
2. run download taxonomy from NCBI and load it into database 'biosql' (make sure the database esists):
```
perl scripts/load_ncbi_taxonomy.pl \
    --dbname biosql --driver mysql --dbuser dbuser \
    --download true --dbpass xxx --allow_truncate
```

## scripts
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

**parameters to run Ni's task:**
```
perl ~/development/GithubRepos/TaxonomyUtils/scripts/taxon_name_to_taxID.pl \
    -i taxonomy\ on\ genus\ level.txt  \
    -o taxonomy_on_genus_level_valided_chen.lst  \
    -log taxonomy_on_genus_level_invalide.txt \
    -target bacteria,archaea
```
