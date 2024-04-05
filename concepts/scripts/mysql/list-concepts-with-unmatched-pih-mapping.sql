-- Show a list of all the concepts (concept_id and numeric PIH mapping code)
--  which don't match on the concepts.pih-emr.org server
-- Ellen Ball | Sept 2021

select c.concept_id, cmt.name as relationship, crt.code 
  from concept c, concept_reference_map crm,                
          concept_reference_term crt, concept_map_type cmt 
where c.concept_id = crm.concept_id
   and crt.code REGEXP '^[0-9]*$'
   and CONVERT(c.concept_id, CHAR) <> crt.code 
   and crm.concept_reference_term_id = crt.concept_reference_term_id
   and crm.concept_map_type_id = cmt.concept_map_type_id
   and cmt.name like 'SAME-AS'      
   and crt.concept_source_id IN
       (select concept_source_id from concept_reference_source
        where name like 'PIH') order by cmt.name;   
