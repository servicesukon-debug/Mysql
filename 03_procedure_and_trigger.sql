-- CPU4:103 | Individual Part C SQL | Petter Junior
-- Run after 01_schema.sql, 01b_sample_data.sql and 02_individual_queries.sql.
USE crownfield_eye_hospital;

-- FEATURE 5: Stored procedure with an IN parameter
-- Question: For a named medicine, which patients and visits include it?
DROP PROCEDURE IF EXISTS sp_medicine_usage_pj;
DELIMITER //
CREATE PROCEDURE sp_medicine_usage_pj(IN p_medicine VARCHAR(120))
BEGIN
    SELECT p.PatientID, p.FullName, a.AppointmentDateTime,
           m.MedicineName, r.Dose, r.Route, r.Frequency, r.Duration
    FROM prescription AS r
    INNER JOIN medicines AS m ON m.MedicineID = r.MedicineID
    INNER JOIN appointments AS a ON a.AppointmentID = r.AppointmentID
    INNER JOIN patients AS p ON p.PatientID = a.PatientID
    WHERE m.MedicineName = p_medicine
    ORDER BY a.AppointmentDateTime, p.PatientID;
END//
DELIMITER ;

-- Test separately:
-- CALL sp_medicine_usage_pj('Latanoprost');

-- FEATURE 6: Trigger enforcing a business rule
-- Business rule: this prototype does not allow weekend appointments.
DROP TRIGGER IF EXISTS trg_no_weekend_appointments_pj;
DELIMITER //
CREATE TRIGGER trg_no_weekend_appointments_pj
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    IF DAYOFWEEK(NEW.AppointmentDateTime) IN (1, 7) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Weekend appointments are not permitted';
    END IF;
END//
DELIMITER ;

-- TEST A (permitted weekday, 10 Nov 2026 is Tuesday): execute, inspect success,
-- then ROLLBACK so the demonstration row is not retained.
-- START TRANSACTION;
-- INSERT INTO appointments
--   (PatientID, ClinicianID, ClinicID, AppointmentDateTime, Notes)
-- VALUES ('OP013', 11, 1, '2026-11-10 10:00:00', 'Petter trigger permitted test');
-- SELECT * FROM appointments WHERE Notes = 'Petter trigger permitted test';
-- ROLLBACK;

-- TEST B (blocked Saturday, 14 Nov 2026): execute the INSERT on its own.
-- Expect SQLSTATE 45000 and the message above. Then explicitly ROLLBACK.
-- START TRANSACTION;
-- INSERT INTO appointments
--   (PatientID, ClinicianID, ClinicID, AppointmentDateTime, Notes)
-- VALUES ('OP013', 11, 1, '2026-11-14 10:00:00', 'Petter trigger blocked test');
-- ROLLBACK;
