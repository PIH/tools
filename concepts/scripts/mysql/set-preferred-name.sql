-- Sets preferred name from fully specified if there is no preferred name
-- NOTE:  This is only for English ('en'), but could work on other locales.

-- Runs on OpenMRS 1.9+

-- Customize these variables
-- - concept_name.locale = 'en'

update concept_name
  set locale_preferred = 1
where concept_id IN 
        (select concept_id from temp_names where done = 0)
   and concept_name_type like 'FULLY_SPECIFIED'
   and voided = 0
   and locale='en'
   and locale_preferred = 0;