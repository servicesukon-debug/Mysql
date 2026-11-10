-- CPU4:103 | Individual Part C SQL | Petter Junior
-- Run after 01_schema.sql and 01b_sample_data.sql.
USE crownfield_eye_hospital;

-- FEATURE 1: GROUP BY + HAVING
-- Question: Which medicines have been prescribed to at least two different patients?
SELECT m.MedicineName,
       COUNT(DISTINCT a.PatientID) AS DifferentPatients,
       COUNT(*) AS PrescriptionItems
FROM prescription AS r
JOIN medicines AS m ON m.MedicineID = r.MedicineID
JOIN appointments AS a ON a.AppointmentID = r.AppointmentID
GROUP BY m.MedicineID, m.MedicineName
HAVING COUNT(DISTINCT a.PatientID) >= 2
ORDER BY DifferentPatients DESC, m.MedicineName;

-- FEATURE 2: INNER JOIN across four tables
-- Question: What medicine items were prescribed, and to whom?
SELECT p.PatientID, p.FullName, a.AppointmentDateTime,
       m.MedicineName, r.Dose, r.Route, r.Frequency, r.Duration
FROM prescription AS r
INNER JOIN medicines AS m ON m.MedicineID = r.MedicineID
INNER JOIN appointments AS a ON a.AppointmentID = r.AppointmentID
INNER JOIN patients AS p ON p.PatientID = a.PatientID
ORDER BY a.AppointmentDateTime, p.PatientID, m.MedicineName;

-- FEATURE 3: LEFT JOIN to reveal clinics with no appointments
-- Question: Which registered clinics have not hosted an appointment?
SELECT c.ClinicID, c.ClinicName, c.Location
FROM clinics AS c
LEFT JOIN appointments AS a ON a.ClinicID = c.ClinicID
WHERE a.AppointmentID IS NULL
ORDER BY c.ClinicName;

-- FEATURE 4: Subquery
-- Question: Which patients have more appointments than the average patient?
-- The derived table includes patients with zero appointments in the average.
SELECT p.PatientID, p.FullName, COUNT(a.AppointmentID) AS AppointmentCount
FROM patients AS p
LEFT JOIN appointments AS a ON a.PatientID = p.PatientID
GROUP BY p.PatientID, p.FullName
HAVING COUNT(a.AppointmentID) >
       (SELECT AVG(patient_totals.AppointmentCount)
        FROM (
            SELECT COUNT(a2.AppointmentID) AS AppointmentCount
            FROM patients AS p2
            LEFT JOIN appointments AS a2 ON a2.PatientID = p2.PatientID
            GROUP BY p2.PatientID
        ) AS patient_totals)
ORDER BY AppointmentCount DESC, p.PatientID;
