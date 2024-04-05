-- Add mappings and terms for "golden" concept dictionary (ie. Rwanda).
-- Add concept_id terms/maps (ie.  'Rwanda: 123') and preferred name term/maps 
--   (ie. 'Rwanda:  Malaria')

-- Customize these variables
-- - number of total concepts = 3478
-- - creator = 1
-- - concept_reference_source.name = 'Rwanda'

-- Works on OpenMRS 1.9

-- Create temporary table
create table temp_names (
  id INT not null auto_increment primary key,
  name varchar(255),
  concept_id int
);

-- Add english preferred name to tmp table
insert into temp_names
(concept_id, name)
select concept_id, name
from concept_name 
where locale = 'en'
and locale_preferred = 1
and voided = 0;

-- Generate concept indexing

delimiter $$

CREATE PROCEDURE addRwandaMaps()
    BEGIN
       DECLARE i INT DEFAULT 1;
   
          WHILE ( i<=3478 ) DO

            -- Add reference term with Rwanda: concept_id
            insert into concept_reference_term
                (concept_source_id,code,creator,date_created,uuid )
            values 
                ((select concept_source_id from concept_reference_source where name like 'Rwanda'),
                 (select concept_id from temp_names where id = i),
                 1,now(),uuid());  

            -- Add SAME-AS map for reference map
            insert into concept_reference_map
                (concept_id,
                 concept_reference_term_id,
                 concept_map_type_id,creator,date_created,uuid)
              values 
                ((select concept_id from temp_names where id = i),
                 (select max(concept_reference_term_id) from concept_reference_term),
                 1,1,now(),uuid()); 

            -- Add reference term with Rwanda: concept_name
            insert into concept_reference_term
                (concept_source_id,code,creator,date_created,uuid )
            values 
                ((select concept_source_id from concept_reference_source where name like 'RWANDA'),
                 (select name from temp_names where id = i),
                 1,now(),uuid());  

            -- Add SAME-AS map for reference map
            insert into concept_reference_map
                (concept_id,
                 concept_reference_term_id,
                 concept_map_type_id,creator,date_created,uuid)
              values 
                ((select concept_id from temp_names where id = i),
                 (select max(concept_reference_term_id) from concept_reference_term),
                 1,1,now(),uuid()); 

            SET i=i+1;
         END WHILE;

    END$$

delimiter ;

call addRwandaMaps();

drop procedure addRwandaMaps;

drop table temp_names;
