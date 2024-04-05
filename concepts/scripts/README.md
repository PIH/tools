# Scripts for OpenMRS concept dictionary

## Groovy scripts

These can be run within OpenMRS using the Groovy module:

#### change_capitalized_concept_names.groovy

Clean up capitalized concept name to "Smart case", but avoid known acronyms (ie.  HIV, SIDA, TB, etc)

#### change-concept-source.groovy

Change the name, description, and uuid for a concept source.  This cannot be done from the OpenMRS UI.

#### copy_concept_names_fr_to_ht.groovy

Copy all French diagnosis concept names to Haitian Kreyol.  This code works when there's a superset of diagnosis sets.

#### delete_concept_maps.groovy

Delete all the mappings for a specified concept source name (ie. 'local').

#### delete_concept_source.groovy

Delete a concept source (by concept_source_id) when there were no mappings.

#### delete_concept_terms.groovy

Delete concept terms for a specified concept source.

#### show_concepts_without_diagnosis_class.groovy

Find all concepts in a diagnosis concept set which do NOT have a concept class of 'diagnosis'.



## MySQL scripts

These are run directly on the OpenMRS database:

#### add-CIEL-map-AAA-concepts.sql

Add CIEL mappings to all concepts that have uuids with trailing AAA's and currently missing mappings.  This covers cases where CIEL mappings were removed or somehow are missing.

#### add-map-openmrs1.6.sql

Create concept maps for PIH with concept_id (ie.  'PIH: 123') (works on OpenMRS 1.6)

#### add-name-and-id-maps.sql

Add mappings and terms for "golden" concept dictionary (ie. Rwanda).  Adds concept_id terms/maps (ie. 'Rwanda: 123') and preferred name term/maps (ie. 'Rwanda:  Malaria')

#### change-map-types.sql

Update map types (ie.  NARROWER-THAN) to correct one (ie.  'SAME-AS') for "golden" dictionary mappings (CIEL, RWANDA, and PIH)

#### check-CIEL-mappings.sql

List CIEL mappings when the uuids does NOT with trailing AAAAA

#### generate-unused-concept-list.sql

Generate intermediate tables with unused concepts

#### list-all-diagnoses.sql

(updated 2021) List all diagnoses, symptoms, findings, etc. (chief complaints) with ICD10 code, English, French, and Haitian Kreyol names from concepts server

#### list-concepts-with-unmatched-pih-mapping.sql

List concepts that have a different concept id from the PIH numeric mapping

#### list-hum-diagnoses.sql

List all the HUM diagnoses, symptoms, findings, etc. (chief complaints) with ICD10 code, English, French, and Haitian Kreyol names

#### set-concept-tables-userid.sql

Set user_id for any concept tables where users (creator, changed_by, retired_by, voided) are missing from the user table.

#### set-preferred-name.sql

Sets preferred name from fully specified if there is no preferred name.  NOTE:  This is only for English ('en'), but could work on other locales.

#### show-CIEL-map-AAA-concepts.sql

Show all concepts and names with uuids of xxxAAAAAAAAAAAAAAAAAA and CIEL mappings  

#### show-concept-table-users-1.6.sql

Show all users who have created, changed, retired or voided concepts.

#### show-concept-table-users-1.9.sql

Show all users who have created, changed, retired, or voided concepts

#### show-concept-table-without-users.sql

Show "users" who have created, changed, retired, or voided concepts BUT are not in the users table.

#### show-concepts-without-preferred-name.sql

Show concepts where there is no preferred concept name

#### show-dupe-maps.sql

Show concept_ids for one term mapped onto multiple concepts.  This checks that PIH, CIEL, AMPATH and other dictionary mappings are not used on multiple concepts.  That would be incorrect.  A concept reference term (ie. 'PIH:12' or 'PIH:Anemia') should only be mapped onto *ONE* concept.

#### show-map-types.sql

Show map type (ie.  NARROWER-THAN) on PIH source.  It should be 'SAME-AS' for dictionary mappings (CIEL, RWANDA, and PIH)

#### show-patient-program-without-users.sql

Show "users" who have created, changed, retired, or voided patient programs but *not* in the users table.
