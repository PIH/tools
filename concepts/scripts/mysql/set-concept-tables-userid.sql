-- Set user_id for any concept tables
-- where users (creator, changed_by, retired_by, voided)
-- are missing from the user table.

-- Works with OpenMRS 1.9

-- NOTE:  This should not happen from the UI, but
-- could happen if mysql tables are copied 
-- (with mysqldump and source).

-- Customize these variables
-- - creator = 1

update concept set creator = 1 
 where creator not in (select user_id from users);
 
update concept set changed_by = 1
 where changed_by NOT in (select user_id from users);

update concept set retired_by = 1
 where retired_by NOT in (select user_id from users);
 
 update concept_answer set creator = 1
  where creator NOT IN (select user_id from users); 
 
 update concept_class set creator = 1 
  where creator NOT IN (select user_id from users);
 
 update concept_class set retired_by = 1
   where retired_by NOT IN (select user_id from users);
 
 update concept_datatype set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_description set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_description set changed_by = 1_description
  where changed_by NOT IN (select user_id from users);
 
 update concept_name set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_name set voided_by = 1
  where voided_by NOT IN (select user_id from users);
 
 update concept_set set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_reference_source set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_reference_source set retired_by = 1
  where retired_by NOT IN (select user_id from users);
 
 update concept_reference_map set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_reference_map set changed_by = 1
  where changed_by NOT IN (select user_id from users);
 
 update concept_reference_term set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_reference_term set changed_by = 1
  where changed_by NOT IN (select user_id from users);
 
 update concept_reference_term set retired_by = 1
  where retired_by NOT IN (select user_id from users);
 
 update concept_reference_term_map set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_reference_term_map set changed_by = 1
  where changed_by NOT IN (select user_id from users);
 
 update concept_map_type set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_map_type set changed_by = 1
  where changed_by NOT IN (select user_id from users);
 
 update concept_map_type set retired_by = 1
  where retired_by NOT IN (select user_id from users);
 
 update concept_name_tag set creator = 1
  where creator NOT IN (select user_id from users);
 
 update concept_name_tag set voided_by = 1
  where voided_by NOT IN (select user_id from users);
