-- Show concepts where there is no preferred concept name
-- This is written for English ('en') but could be modified

-- Script for OpenMRS 1.9+

-- Customize these variables
-- - concept_name.locale = 'en'

select concept_id as id,name,locale,locale_preferred as prefer,
          concept_name_type as type from concept_name cname 
where concept_id not IN 
  (select cn.concept_id from concept_name cn 
    where locale_preferred = 1 and locale = 'en' and voided = 0) 
   and cname.concept_name_type like 'FULLY_SPECIFIED'
   and voided = 0
   and locale='en';