-- Add CIEL mappings to all concepts that have uuids with trailing AAA's 
--   and currently missing mappings.  
-- This covers cases where CIEL mappings were removed or somehow are missing.

-- Steps:
--  - check for concepts with uuids that end in AAAA's
--  - get the CIEL concept_id from the beginning of the uuid
--  - temporarily write CIEL concept_id into concept_reference_term.name 
--  - create CIEL mapping on concepts
--  - remove those temporary names

-- Works on OpenMRS 1.9

-- Customize these variables
-- - concept_source_id = 9
-- - creator = 1

-- Create reference terms
insert into concept_reference_term 
(code, name,concept_source_id,creator,date_created,uuid)
select trim(trailing 'A' from c.uuid) ,concept_id,9,1,now(),uuid() 
 from concept c
where c.uuid like '%AAAA'
    and trim(trailing 'A' from c.uuid) NOT IN 
       (select crt.code from concept_reference_term crt
         where crt.concept_source_id = 9);

-- Create CIEL mapping on concept with reference terms
insert into concept_reference_map
(creator,date_created,concept_id,uuid,concept_reference_term_id,concept_map_type_id)
select 1,now(),name,uuid(),concept_reference_term_id,1
   from concept_reference_term
where name is not null;

-- Remove temporary names (concept_id)
update concept_reference_term
        set name = NULL
  where name is not null;
