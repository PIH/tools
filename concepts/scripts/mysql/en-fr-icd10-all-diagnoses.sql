select 
       cs.concept_id,
       crt.code,
       fr.name,
       en.name
  from concept_set cs

inner join concept as c
   on cs.concept_id = c.concept_id
  and c.retired = 0

inner join concept_name as en
   on cs.concept_id = en.concept_id
  and en.locale = 'en'
  and en.locale_preferred = 1
  and en.voided = 0

inner join concept_name as fr
   on cs.concept_id = fr.concept_id
  and fr.locale = 'fr'
  and fr.locale_preferred = 1
  and fr.voided = 0

inner join concept_reference_map as crm
   on cs.concept_id = crm.concept_id

inner join concept_reference_term as crt
   on crm.concept_reference_term_id = crt.concept_reference_term_id
  and crt.concept_source_id =  3

 where cs.concept_set = 7936

 order by crt.code;
