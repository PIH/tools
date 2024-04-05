-- Show map type (ie.  NARROWER-THAN) on PIH source 
-- It should be 'SAME-AS' for dictionary mappings (CIEL, RWANDA,
-- and PIH)

-- Script for OpenMRS 1.9+

-- Customize these variables
-- - concept_source_id = 'PIH'

select c.concept_id, cmt.name    
  from concept c, concept_reference_map crm,                
          concept_reference_term crt, concept_map_type cmt 
where c.concept_id = crm.concept_id
   and crm.concept_reference_term_id = crt.concept_reference_term_id
   and crm.concept_map_type_id = cmt.concept_map_type_id
   and cmt.name like 'NARROWER%'      
   and crt.concept_source_id IN
       (select concept_source_id from concept_reference_source
        where name like 'PIH') order by cmt.name;
