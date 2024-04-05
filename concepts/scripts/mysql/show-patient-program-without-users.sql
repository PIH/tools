-- Show "users" who have created, changed, retired
--  or voided patient programs BUT are not in the users table.

-- Works in OpenMRS 1.9

select creator from patient_program
 where creator not in (select user_id from users)
UNION 
select changed_by from patient_program
 where changed_by NOT in (select user_id from users)
UNION
select voided_by from patient_program
 where voided_by NOT in (select user_id from users)
;