-- Show concept_ids for one term mapped onto multiple concepts
-- This is used for checking that PIH, CIEL, AMPATH and other
-- dictionary mappings are not used on multiple concepts.  
-- That would be incorrect.

select crm.concept_reference_term_id, 
          min(crm.concept_id) as id1, crt.code as term, 
          max(crm.concept_id) as id2, crt.code as term2, 
          count(*) dupes
  from concept_reference_map crm, concept_reference_term crt
where crm.concept_reference_term_id = crt.concept_reference_term_id  
    and crt.concept_source_id IN 
        (select concept_source_id from concept_reference_source 
          where name like 'AMPATH')
  group by crm.concept_reference_term_id   
having dupes > 1  
order by id1;

