-- List CIEL mappings when the uuids does NOT with trailing AAAAA    

-- Works on OpenMRS 1.9+

select c.concept_id
  from concept_reference_map crm, concept_reference_term crt,
              concept c
 where crm.concept_reference_term_id = crt.concept_reference_term_id
      and c.concept_id = crm.concept_id 
     and c.uuid not like '%AAAA'
      and crt.concept_source_id IN 
     (select concept_source_id from concept_reference_source 
      where name like 'CIEL');

