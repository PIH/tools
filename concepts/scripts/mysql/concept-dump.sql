mysqldump -uroot -p -q -e --single-transaction -r"concept-dump.sql" concepts concept concept_answer concept_class concept_complex concept_datatype concept_derived concept_description concept_map concept_name concept_name_tag concept_name_tag_map concept_numeric concept_set concept_set_derived concept_source concept_word

-- OpenMRS 2.3
mysqldump -u root --password=Admin123 --routines concepts concept concept_answer concept_attribute concept_attribute_type concept_class concept_complex concept_datatype concept_description concept_map_type concept_name concept_name_tag concept_name_tag_map concept_numeric concept_reference_map concept_reference_source concept_reference_term concept_reference_term_map concept_set concept_stop_word  > pih-concepts-db-20210426.sql

-- Not included
-- drug
