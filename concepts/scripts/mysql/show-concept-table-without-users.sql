-- Show "users" who have created, changed, retired
--  or voided concepts BUT are not in the users table.

-- Works in OpenMRS 1.9

select creator from concept
 where creator not in (select user_id from users)
UNION 
select changed_by from concept
 where changed_by NOT in (select user_id from users)
UNION
select retired_by from concept
 where retired_by NOT in (select user_id from users)
UNION 
 select creator from concept_answer
  where creator NOT IN (select user_id from users) 
UNION 
 select creator from concept_class 
  where creator NOT IN (select user_id from users)
UNION 
 select retired_by from concept_class
   where retired_by NOT IN (select user_id from users)
UNION 
 select creator from concept_datatype
  where creator NOT IN (select user_id from users)
UNION 
 select creator from concept_description
  where creator NOT IN (select user_id from users)
UNION 
 select changed_by from concept_description
  where changed_by NOT IN (select user_id from users)
UNION 
 select creator from concept_description
  where creator NOT IN (select user_id from users)
UNION 
 select creator from concept_name
  where creator NOT IN (select user_id from users)
UNION 
 select voided_by from concept_name
  where voided_by NOT IN (select user_id from users)
UNION 
 select creator from concept_set
  where creator NOT IN (select user_id from users)
UNION 
 select creator from concept_reference_source
  where creator NOT IN (select user_id from users)
UNION 
 select retired_by from concept_reference_source
  where retired_by NOT IN (select user_id from users)
UNION 
 select creator from concept_reference_map
  where creator NOT IN (select user_id from users)
UNION 
 select changed_by from concept_reference_map
  where changed_by NOT IN (select user_id from users)
UNION 
 select creator from concept_reference_term
  where creator NOT IN (select user_id from users)
UNION 
 select changed_by from concept_reference_term
  where changed_by NOT IN (select user_id from users)
UNION 
 select retired_by from concept_reference_term
  where retired_by NOT IN (select user_id from users)
UNION 
 select creator from concept_reference_term_map
  where creator NOT IN (select user_id from users)
UNION 
 select changed_by from concept_reference_term_map
  where changed_by NOT IN (select user_id from users)
UNION 
 select creator from concept_map_type
  where creator NOT IN (select user_id from users)
UNION 
 select changed_by from concept_map_type
  where changed_by NOT IN (select user_id from users)
UNION 
 select retired_by from concept_map_type
  where retired_by NOT IN (select user_id from users)
UNION 
 select creator from concept_name_tag
  where creator NOT IN (select user_id from users)
UNION 
 select voided_by from concept_name_tag
  where voided_by NOT IN (select user_id from users)
;