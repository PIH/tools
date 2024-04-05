-- Update map types (ie.  NARROWER-THAN) to correct one 
-- (ie.  'SAME-AS') for dictionary mappings (CIEL, RWANDA,
-- and PIH)

-- NOTE:  In this example, concept_map_type_id = 1 (SAME-AS)

-- Script for OpenMRS 1.9+

update concept_reference_map
  set concept_map_type_id = 1
where concept_reference_term_id IN 
  (select concept_reference_term_id
     from concept_reference_term
   where concept_source_id IN
       (select concept_source_id from concept_reference_source
        where name like 'PIH'))
   and concept_map_type_id = 2 ;

