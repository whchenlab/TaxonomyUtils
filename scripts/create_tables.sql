-- ##########################################################
-- created tables
-- ##########################################################
drop table `bacteria_and_descendents`;
CREATE TABLE `bacteria_and_descendents` (
  `scientific_name` varchar(255) NOT NULL ,
  `node_rank` varchar(255) NOT NULL,
  `ncbi_taxon_id` int(10) NOT NULL,
  `taxon_id` int(10) NOT NULL,
  `parent_taxon_id` int(10) DEFAULT NULL,
  PRIMARY KEY (`taxon_id`),
  UNIQUE KEY `ncbi_taxon_id` (`ncbi_taxon_id`)
);


drop table `archaea_and_descendents`;
drop table `viruses_and_descendents`;
CREATE TABLE `archaea_and_descendents` LIKE `bacteria_and_descendents`;
CREATE TABLE `viruses_and_descendents` LIKE `bacteria_and_descendents`;


-- ##########################################################
-- load data into tables
-- ##########################################################
truncate table `bacteria_and_descendents`;
load data local infile "/Users/wchen/development/GithubRepos/TaxonomyUtils/scripts/bacteria_all_descendents.txt" into table `bacteria_and_descendents` fields terminated by '\t' ignore 1 lines;

truncate table `archaea_and_descendents`;
load data local infile "/Users/wchen/development/GithubRepos/TaxonomyUtils/scripts/archaea_all_descendents.txt" into table `archaea_and_descendents` fields terminated by '\t' ignore 1 lines;

truncate table `viruses_and_descendents`;
load data local infile "/Users/wchen/development/GithubRepos/TaxonomyUtils/scripts/viruses_all_descendents.txt" into table `viruses_and_descendents` fields terminated by '\t' ignore 1 lines;


-- ##########################################################
--   new table for taxon2majorranks --
-- ##########################################################
-- major rnaks are: Root, kingdom, phylum, class, order, family genus, species
drop table if exists `taxon2majorranks`;
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

-- prepare data for this table --
