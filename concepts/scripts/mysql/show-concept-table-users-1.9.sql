-- Show all users who have created, changed, retired, or voided concepts

-- Works in OpenMRS 1.9

select distinct(u.user_id), username, system_id from users u
where u.user_id in (select creator from concept)
 or u.user_id in (select changed_by from concept)
 or u.user_id in (select retired_by from concept)
 or u.user_id in (select retired_by from concept_answer) 
 or u.user_id in (select creator from concept_class)
 or u.user_id in (select retired_by from concept_class)
 or u.user_id in (select creator from concept_datatype)
 or u.user_id in (select changed_by from concept_description)
 or u.user_id in (select creator from concept_description)
 or u.user_id in (select creator from concept_name)
 or u.user_id in (select voided_by from concept_name)
 or u.user_id in (select creator from concept_set)
 or u.user_id in (select creator from concept_reference_source)
 or u.user_id in (select retired_by from concept_reference_source)
 or u.user_id in (select creator from concept_reference_map)
 or u.user_id in (select changed_by from concept_reference_map)
 or u.user_id in (select creator from concept_reference_term)
 or u.user_id in (select changed_by from concept_reference_term)
 or u.user_id in (select retired_by from concept_reference_term)
 or u.user_id in (select creator from concept_reference_term_map)
 or u.user_id in (select changed_by from concept_reference_term_map)
 or u.user_id in (select creator from concept_map_type)
 or u.user_id in (select changed_by from concept_map_type)
 or u.user_id in (select retired_by from concept_map_type)
 or u.user_id in (select creator from concept_name_tag)
 or u.user_id in (select voided_by from concept_name_tag);