-- Show all concepts and names with uuids of xxxAAAAAAAAAAAAAAAAAA
-- and CIEL mappings   

-- Works on OpenMRS 1.9+

select c.concept_id, cmt.name 
  from concept c, concept_reference_map crm, 
          concept_reference_term crt, concept_map_type cmt 
where c.uuid like '%AAAA' 
   and c.concept_id = crm.concept_id 
   and crm.concept_reference_term_id = crt.concept_reference_term_id 
   and crm.concept_map_type_id = cmt.concept_map_type_id
   and crt.concept_source_id IN 
      (select concept_source_id from concept_reference_source where name like 'CIEL');

