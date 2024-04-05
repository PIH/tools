select '|',
     cs.concept_id as ConceptID, '|',
     crt.code as ICD10, '|',     
     en.name as English, '|',
     fr.name as French, '|', 
     es.name as Spanish, '|',
     specialty.name as Department
  from concept_set cs

left join concept as c
   on cs.concept_id = c.concept_id
  and c.retired = 0

left join concept_name as es
   on cs.concept_id = es.concept_id
  and es.locale = 'es'
  and es.concept_name_type = 'FULLY_SPECIFIED'
  and es.voided = 0

left join concept_name as fr
   on cs.concept_id = fr.concept_id
  and fr.locale = 'fr'
  and fr.concept_name_type = 'FULLY_SPECIFIED'
  and fr.voided = 0

left join concept_name as en
   on cs.concept_id = en.concept_id
  and en.locale = 'en'
  and en.concept_name_type = 'FULLY_SPECIFIED'
  and en.voided = 0

inner join concept_name as specialty
   on cs.concept_set = specialty.concept_id
  and specialty.locale = 'en'
  and specialty.concept_name_type = 'FULLY_SPECIFIED'
  and specialty.voided = 0

inner join concept_reference_map as crm
  on cs.concept_id = crm.concept_id

inner join concept_reference_term as crt
  on crm.concept_reference_term_id = crt.concept_reference_term_id
 and crt.concept_source_id =  3

 where cs.concept_set IN (select concept_id from concept_set where concept_set = 7912)

 group by cs.concept_id
 order by crt.code;
