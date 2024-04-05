-- Table temp_all_concepts has all the used concepts
--  including all possible concept_answers to used questions

-- ----------------------------------------------------------
-- PREFACE:  Dump table before deleting anything 
-- ----------------------------------------------------------
-- mysqldump -uroot -p -e --single-transaction -q -r"/home/ball/openmrs-backup.sql" openmrs 

-- ----------------------------------------------------------
-- Unique for haiti mdr migration:  
--		Change concept_map for unloved mdrtb concepts
-- ----------------------------------------------------------
-- For haitimdr migration
update global_property 
   set property_value = 'false' 
 where property = 'sync.mandatory';
 
-- ----------------------------------------------------------
-- PART I:  Build temp tables with used concepts
-- ----------------------------------------------------------
DROP TABLE IF EXISTS `temp_all_concepts`;
select "Creating temp_all_concept table with all concepts" as "Action";
create table temp_all_concepts (concept_id int(11), keep int(1), source char(12));
insert into temp_all_concepts (concept_id, keep)
  select concept_id, '0' from concept;

-- SPECIFIC IDs FOR HAITI MDR TB MIGRATION
select "Add concept_ids from forms but without any obs" as "Action";
-- Haiti MDR-TB ddb and rdv forms
-- update temp_all_concepts
--  set keep = '1', source = 'htmlform'
--  where concept_id IN (1296,1340,1475,1618,2320,2722,3058,5002,6338,6351,6358,6375,6366,6403);

select "Add mdrtb module concept_ids" as "Action";   		   
update temp_all_concepts 
  set keep = '1', source = 'mdrtbmap' 
  where concept_id IN (select distinct(cm.concept_id) from concept_map cm
    where cm.source = 1);

select "Add obs concept_ids to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'obs' 
  where concept_id IN (select distinct(o.concept_id) from obs o);

select "Add obs valued_coded to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'obs-coded' 
  where concept_id IN (select distinct(o.value_coded) from obs o);

-- TBD:  Should we remove unused drugs?
select "Add drug concept_id to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'drug' 
  where concept_id IN (select distinct(d.concept_id) from drug d);
  
-- Don't bother with field, since only used with InfoPath

select "Add orders concept_id to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'orders' 
  where concept_id IN (select distinct(o.concept_id) from orders o);

select "Add orders discontinued_reason to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'orders stop' 
  where concept_id IN (select distinct(o.discontinued_reason) from orders o);

select "Add program concept_id to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'program' 
  where concept_id IN (select distinct(p.concept_id) from program p);

select "Add workflow concept_id to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'workflow' 
  where concept_id IN (select distinct(pw.concept_id) from program_workflow pw);

select "Add state concept_id to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'state' 
  where concept_id IN (select distinct(pws.concept_id) from program_workflow_state pws);

select "Add person_attribute_type.foreign key to temp_all_concepts table" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'person attr' 
  where concept_id IN (select distinct(pat.foreign_key) from person_attribute_type pat);


-- ----------------------------------------------------------
-- PART II:  Build temp tables with used answers
-- ----------------------------------------------------------
/* Try this minimalism  */
select "Create temp_concept_answer table for necessary concept_ids" as "Action";
DROP TABLE IF EXISTS `temp_concept_answer`;
create table temp_concept_answer 
	(concept_answer_id int(11), concept_id int(11), answer_concept int(11),
	source char(12), keep int(1) );
insert into temp_concept_answer   
   select concept_answer_id, concept_id, answer_concept, 'none', '0' from concept_answer ;

-- Set keep for used questions
select "Set keep on temp_concept_answer table from obs, etc" as "Action";
update temp_concept_answer
	set keep = '1', source = 'question'
	where concept_id IN (select distinct(concept_id) from temp_all_concepts where keep = '1');
	 
-- Set keep for used answers, but ignore yes, no and unknown
DROP TABLE IF EXISTS `temp_concept_answer_yesno`;
create table temp_concept_answer_yesno 
	(concept_answer_id int(11), concept_id int(11), answer_concept int(11),
	source char(12), keep int(1) );

insert into temp_concept_answer_yesno   
   select concept_answer_id, concept_id, answer_concept, 'none', '0' 
   from concept_answer;
	 
-- Set keep for default
update temp_concept_answer_yesno
	set keep = '1', source = 'answer';

-- Remove save for yes, no and unknown
update temp_concept_answer_yesno
	set keep = '0', source = 'yes'
        where answer_concept = 1065;
update temp_concept_answer_yesno
	set keep = '0', source = 'no'
        where answer_concept = 1066;
update temp_concept_answer_yesno
	set keep = '0', source = 'unknown'
        where answer_concept = 1067;

-- Set keep only for used questions
update temp_concept_answer_yesno
        set keep = 1, source = 'question'
        where concept_id IN (select distinct(concept_id) from obs);

update temp_concept_answer
	set keep = '1', source = 'answer'
	where concept_id IN (select distinct(concept_id) from temp_concept_answer_yes where keep = '1');
	
update temp_concept_answer
	set keep = '1', source = 'answer'
	where answer_concept IN (select distinct(concept_id) from temp_all_concepts where keep = '1');
	   
select "Add concept question and answers to keep" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'question' 
  where concept_id IN (select distinct(tca.concept_id) from temp_concept_answer tca where tca.keep = '1');
update temp_all_concepts 
  set keep = '1', source = 'answer' 
  where concept_id IN (select distinct(tca.answer_concept) from temp_concept_answer tca where tca.keep = '1');

-- delete GOOD concept answers from temp file   
delete from temp_concept_answer
	 WHERE keep = '1';


-- ----------------------------------------------------------
-- PART III:  Build temp table with concept sets
-- ----------------------------------------------------------
select "Create temp_concept_set table" as "Action";
DROP TABLE IF EXISTS `temp_concept_set`;
create table temp_concept_set 
  (concept_set_id int(11), concept_id int(11), concept_set int(11), keep int(1));
insert into temp_concept_set
 select concept_set_id, concept_id, concept_set, '0' from concept_set ;
  
select "Set keep on temp_concept_set for used sets" as "Action"; 
update temp_concept_set tcs
	set tcs.keep = '1'
	where tcs.concept_set IN 
     	 (select distinct(tac.concept_id) from temp_all_concepts tac where tac.keep = 1);
     	 
select "Add concept set and members to keep" as "Action";
update temp_all_concepts 
  set keep = '1', source = 'set' 
  where concept_id IN (select distinct(concept_set) from temp_concept_set tcs
                        where keep = 1);
update temp_all_concepts 
  set keep = '1', source = 'set member' 
  where concept_id IN (select distinct(concept_id) from temp_concept_set tcs
                        where keep = 1);

-- delete GOOD concept sets from temp file   
delete from temp_concept_set
	 WHERE keep = '1';
  
-- -----------------------------------------------------------------
-- PART IV:  Build temp table with distinct used and unused concepts
-- -----------------------------------------------------------------
select "Create temp_concept_keeper table with distinct concept_ids" as "Action";
DROP TABLE IF EXISTS `temp_concept_keeper`;
create table temp_concept_keeper (concept_id int(11));
insert into temp_concept_keeper     
   select distinct(tac.concept_id) from temp_all_concepts tac
    where tac.keep = '1';

select "Create temp_concept_trash table with distinct concept_ids" as "Action";
DROP TABLE IF EXISTS `temp_concept_trash`;
create table temp_concept_trash (concept_id int(11));
insert into temp_concept_trash   
   select distinct(tac.concept_id) from temp_all_concepts tac
    where tac.keep = '0';

-- ----------------------------------------------------------
-- PART V:  Build temp table with concept name
-- ----------------------------------------------------------          
select "Create temp_concept_name_keeper" as "Action";
DROP TABLE IF EXISTS `temp_concept_name_keeper`;
create table temp_concept_name_keeper (concept_name_id int(11));
insert into temp_concept_name_keeper     
   select distinct(cn.concept_name_id) from concept_name cn, temp_concept_keeper ck
     where cn.concept_id = ck.concept_id;

