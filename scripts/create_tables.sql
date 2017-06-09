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
