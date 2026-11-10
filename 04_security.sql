-- CPU4:103 | Individual Part D Security and Transactions | Petter Junior
-- Run after 01_schema.sql, 01b_sample_data.sql, 02 and 03.
-- Execute as a MySQL account with CREATE USER, CREATE ROLE and GRANT privileges.
USE crownfield_eye_hospital;

-- D1.1 Create four least-privilege roles (PJ prefix identifies this implementation).
CREATE ROLE IF NOT EXISTS 'pj_admin', 'pj_doctor', 'pj_receptionist', 'pj_patient';

-- Administrator: administer this database.
GRANT ALL PRIVILEGES ON crownfield_eye_hospital.* TO 'pj_admin';

-- Doctor: read relevant clinical/lookup data; write clinical outcomes only.
GRANT SELECT ON crownfield_eye_hospital.patients TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.clinicians TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.specialties TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.clinics TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.appointments TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.Diagnosis TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.medicines TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.prescription TO 'pj_doctor';
GRANT SELECT ON crownfield_eye_hospital.FollowUp TO 'pj_doctor';
GRANT INSERT, UPDATE ON crownfield_eye_hospital.Diagnosis TO 'pj_doctor';
GRANT INSERT, UPDATE ON crownfield_eye_hospital.prescription TO 'pj_doctor';
GRANT INSERT, UPDATE ON crownfield_eye_hospital.FollowUp TO 'pj_doctor';

-- Receptionist: manage demographic and appointment administration only.
GRANT SELECT, INSERT, UPDATE ON crownfield_eye_hospital.patients TO 'pj_receptionist';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye_hospital.appointments TO 'pj_receptionist';
GRANT SELECT ON crownfield_eye_hospital.clinics TO 'pj_receptionist';
GRANT SELECT ON crownfield_eye_hospital.clinicians TO 'pj_receptionist';

-- Patient: SELECT on the filtered view only; no base-table grants.
-- USER() retains the authenticated login identity inside this definer view.
CREATE OR REPLACE
SQL SECURITY DEFINER VIEW vw_my_patient_record_pj AS
SELECT p.PatientID, p.FullName, p.Postcode,
       a.AppointmentID, a.AppointmentDateTime, a.Notes,
       (SELECT GROUP_CONCAT(d.Diagnosisname ORDER BY d.Diagnosisname SEPARATOR '; ')
        FROM Diagnosis AS d
        WHERE d.AppointmentID = a.AppointmentID) AS Diagnoses,
       (SELECT GROUP_CONCAT(
                   CONCAT(m.MedicineName, ' (', r.Dose, '; ', r.Route, '; ',
                          r.Frequency, '; ', r.Duration, ')')
                   ORDER BY m.MedicineName SEPARATOR ' | ')
        FROM prescription AS r
        JOIN medicines AS m ON m.MedicineID = r.MedicineID
        WHERE r.AppointmentID = a.AppointmentID) AS PrescribedItems,
       f.DueDate AS FollowUpDueDate, f.Priority AS FollowUpPriority,
       f.Status AS FollowUpStatus
FROM UserAccounts AS ua
JOIN patients AS p ON p.PatientID = ua.PatientID
JOIN appointments AS a ON a.PatientID = p.PatientID
LEFT JOIN FollowUp AS f ON f.AppointmentID = a.AppointmentID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1)
  AND ua.Role = 'Patient';

GRANT SELECT ON crownfield_eye_hospital.vw_my_patient_record_pj TO 'pj_patient';

-- D1.2 Create test logins. These are DEMONSTRATION credentials only.
-- Change them for your own local testing; never reuse real passwords.
CREATE USER IF NOT EXISTS 'pj_admin_test'@'localhost' IDENTIFIED BY 'DemoOnly_Admin_2026!';
CREATE USER IF NOT EXISTS 'pj_doctor_test'@'localhost' IDENTIFIED BY 'DemoOnly_Doctor_2026!';
CREATE USER IF NOT EXISTS 'pj_reception_test'@'localhost' IDENTIFIED BY 'DemoOnly_Reception_2026!';
CREATE USER IF NOT EXISTS 'op001.amina'@'localhost' IDENTIFIED BY 'DemoOnly_Amina_2026!';
CREATE USER IF NOT EXISTS 'op002.daniel'@'localhost' IDENTIFIED BY 'DemoOnly_Daniel_2026!';

GRANT 'pj_admin' TO 'pj_admin_test'@'localhost';
GRANT 'pj_doctor' TO 'pj_doctor_test'@'localhost';
GRANT 'pj_receptionist' TO 'pj_reception_test'@'localhost';
GRANT 'pj_patient' TO 'op001.amina'@'localhost';
GRANT 'pj_patient' TO 'op002.daniel'@'localhost';

SET DEFAULT ROLE ALL TO
    'pj_admin_test'@'localhost',
    'pj_doctor_test'@'localhost',
    'pj_reception_test'@'localhost',
    'op001.amina'@'localhost',
    'op002.daniel'@'localhost';

-- D1.3 Evidence: inspect privileges as root/admin.
SHOW GRANTS FOR 'pj_admin_test'@'localhost';
SHOW GRANTS FOR 'pj_doctor_test'@'localhost';
SHOW GRANTS FOR 'pj_reception_test'@'localhost';
SHOW GRANTS FOR 'op001.amina'@'localhost';
SHOW GRANTS FOR 'op002.daniel'@'localhost';

-- D1.4 Test instructions (connect as each account in a separate Workbench
-- connection; do not rely only on SET ROLE in the root session):
--
-- Receptionist: this must fail with ERROR 1142 (SELECT command denied):
-- SELECT * FROM crownfield_eye_hospital.Diagnosis;
--
-- Patient Amina: this should show only OP001's appointments.
-- SELECT * FROM crownfield_eye_hospital.vw_my_patient_record_pj;
-- This must fail (no direct base-table access):
-- SELECT * FROM crownfield_eye_hospital.patients;
--
-- Patient Daniel: this should show only OP002's appointments.
-- SELECT * FROM crownfield_eye_hospital.vw_my_patient_record_pj;
-- This must fail:
-- SELECT * FROM crownfield_eye_hospital.appointments;

-- D2. Data protection demonstration: salted SHA-256 already used in UserAccounts.
-- Demonstrate the approach without displaying or committing plaintext credentials.
SELECT Username, Salt, PasswordHash,
       CHAR_LENGTH(PasswordHash) AS HashLength
FROM UserAccounts
ORDER BY Username;
-- Explanation: SHA2(CONCAT(Salt, password), 256) produces a 256-bit (64 hex
-- character) digest. SHA-256 is for this teaching demonstration only; a real
-- application should use Argon2id or bcrypt with an appropriate work factor.

-- D3. Transaction 1: demonstrate ROLLBACK by rescheduling appointment 13
-- and its follow-up together. 13 Nov 2026 is a Friday.
SELECT AppointmentID, AppointmentDateTime FROM appointments WHERE AppointmentID = 13;
SELECT AppointmentID, DueDate FROM FollowUp WHERE AppointmentID = 13;

START TRANSACTION;
UPDATE appointments
SET AppointmentDateTime = '2026-11-13 10:00:00'
WHERE AppointmentID = 13;
UPDATE FollowUp
SET DueDate = '2026-12-10'
WHERE AppointmentID = 13;
SELECT AppointmentID, AppointmentDateTime FROM appointments WHERE AppointmentID = 13;
SELECT AppointmentID, DueDate FROM FollowUp WHERE AppointmentID = 13;
ROLLBACK;

-- Prove the original values were restored.
SELECT AppointmentID, AppointmentDateTime FROM appointments WHERE AppointmentID = 13;
SELECT AppointmentID, DueDate FROM FollowUp WHERE AppointmentID = 13;

-- D4. Transaction 2: demonstrate COMMIT with a different appointment time/date.
-- Run only after confirming the chosen slot is not already used.
SELECT AppointmentID, AppointmentDateTime FROM appointments WHERE AppointmentID = 13;
SELECT AppointmentID, DueDate FROM FollowUp WHERE AppointmentID = 13;

START TRANSACTION;
UPDATE appointments
SET AppointmentDateTime = '2026-11-13 10:30:00'
WHERE AppointmentID = 13;
UPDATE FollowUp
SET DueDate = '2026-12-11'
WHERE AppointmentID = 13;
SELECT AppointmentID, AppointmentDateTime FROM appointments WHERE AppointmentID = 13;
SELECT AppointmentID, DueDate FROM FollowUp WHERE AppointmentID = 13;
COMMIT;

-- Prove the committed values remain.
SELECT AppointmentID, AppointmentDateTime FROM appointments WHERE AppointmentID = 13;
SELECT AppointmentID, DueDate FROM FollowUp WHERE AppointmentID = 13;

-- If any statement fails part-way through either transaction, run ROLLBACK
-- explicitly before continuing. The SQL error alone does not guarantee rollback.
