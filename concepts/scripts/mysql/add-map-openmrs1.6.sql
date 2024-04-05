-- Create concept maps for PIH with concept_id (ie.  'PIH: 123')

-- Works on OpenMRS 1.6

insert into concept_map 
  (source, source_code, creator, date_created, concept_id, uuid)
  select '5', concept_id, '7', now(), concept_id, uuid() from concept ;
