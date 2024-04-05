-- List all the HUM diagnoses, symptoms, findings, etc. (chief complaints)
-- with ICD10 code, English, French, and Haitian Kreyol names

-- Works on OpenMRS 1.9

-- Customize these variables
-- - concept_name.locale = fr | en | ht
-- - concept_reference_term.concept_source_id = 3 (ICD-10)
-- - concept_set.concept_set = 7912 (HUM diagnosis set of sets)

select distinct(cname.concept_id) as id,
         crt.code as ICD10,
         cname.name as English, 
	 fr.name as French
  from concept_name cname

left join concept_name as fr
   on cname.concept_id = fr.concept_id
  and fr.locale = 'fr'
  and fr.locale_preferred = 1
  and fr.voided = 0

inner join concept_reference_map as crm
   on cname.concept_id = crm.concept_id

-- Show ICD10 code
inner join concept_reference_term as crt
   on crm.concept_reference_term_id = crt.concept_reference_term_id
  and crt.concept_source_id =  3

where cname.locale_preferred = 1 
  and cname.locale = 'en'
  and cname.voided = 0
  and cname.concept_id IN
      (select cs.concept_id
         from concept_set cs
        where cs.concept_set IN 
              (select concept_id from concept_set where concept_set = 7912))
order by ICD10;
