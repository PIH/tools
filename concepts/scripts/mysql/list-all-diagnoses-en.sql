select '|',
     cs.concept_id as ConceptID, '|',
     crt.code as ICD10, '|',
     en.name as English, '|'
  from concept_set cs

left join concept as c
   on cs.concept_id = c.concept_id
  and c.retired = 0

left join concept_name as en
   on cs.concept_id = en.concept_id
  and en.locale = 'en'
  and en.concept_name_type = 'FULLY_SPECIFIED'
  and en.voided = 0

inner join concept_reference_map as crm
  on cs.concept_id = crm.concept_id

inner join concept_reference_term as crt
  on crm.concept_reference_term_id = crt.concept_reference_term_id
 and crt.concept_source_id =  3

 where cs.concept_set IN (select concept_id from concept_set where concept_set = 7912)

 group by cs.concept_id
 order by crt.code;                 
