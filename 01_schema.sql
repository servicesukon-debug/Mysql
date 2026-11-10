-- =====================================================================
-- CPU4:103 Introduction to Database  |  Crownfield Eye Hospital
-- File 01_schema.sql  -  Part B physical schema (DDL)
-- Group : Iulian Mucuta, Petter Junior, Marilene Dukaj
-- Author of this file : Iulian Mucuta  (group schema, agreed in Workbench)
-- Tested on : MySQL Community Server 9.7 (CHECK constraints need 8.0.16+)
-- Run order : 01_schema.sql -> 01b_sample_data.sql -> 02 -> 03 -> 04
-- =====================================================================
-- The logical design is the group's nine-table Workbench model
-- (patients, clinicians, specialties, clinics, appointments, Diagnosis,
-- medicines, prescription, FollowUp) plus one extra table, UserAccounts,
-- added for Part D (hashed passwords and role mapping).
-- =====================================================================
-- !!! WARNING: the first statement DROPS the existing database and all
-- !!! its data.  Back up first:
-- !!!   mysqldump -u root -p crownfield_eye_hospital > backup.sql
-- =====================================================================

DROP DATABASE IF EXISTS crownfield_eye_hospital;
CREATE DATABASE crownfield_eye_hospital
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE crownfield_eye_hospital;

-- ---------------------------------------------------------------------
-- 1. specialties  (lookup: one row per clinical specialty)
-- ---------------------------------------------------------------------
CREATE TABLE specialties (
    SpecialtyID   INT          NOT NULL AUTO_INCREMENT,
    SpecialtyName VARCHAR(45)  NOT NULL,
    PRIMARY KEY (SpecialtyID),
    CONSTRAINT uq_specialty_name UNIQUE (SpecialtyName)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 2. clinicians  (a clinician MAY have one primary specialty -> NULL allowed)
-- ---------------------------------------------------------------------
CREATE TABLE clinicians (
    ClinicianID INT          NOT NULL AUTO_INCREMENT,
    FullName    VARCHAR(100) NOT NULL,
    SpecialtyID INT          NULL,
    PRIMARY KEY (ClinicianID),
    CONSTRAINT fk_clinician_specialty
        FOREIGN KEY (SpecialtyID) REFERENCES specialties (SpecialtyID)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3. patients  (natural key OPnnn kept from the source data)
-- ---------------------------------------------------------------------
CREATE TABLE patients (
    PatientID VARCHAR(10)  NOT NULL,
    FullName  VARCHAR(100) NOT NULL,
    Postcode  VARCHAR(12)  NOT NULL,
    PRIMARY KEY (PatientID),
    CONSTRAINT chk_patient_id_format CHECK (PatientID REGEXP '^OP[0-9]{3,}$'),
    CONSTRAINT chk_patient_postcode  CHECK (CHAR_LENGTH(TRIM(Postcode)) >= 5)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 4. clinics  (physical clinic locations of the Trust)
-- ---------------------------------------------------------------------
CREATE TABLE clinics (
    ClinicID   INT          NOT NULL AUTO_INCREMENT,
    ClinicName VARCHAR(100) NOT NULL,
    Location   VARCHAR(100) NOT NULL,
    PRIMARY KEY (ClinicID),
    CONSTRAINT uq_clinic_name UNIQUE (ClinicName)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 5. appointments  (exactly one patient, one clinician, one clinic)
-- ---------------------------------------------------------------------
CREATE TABLE appointments (
    AppointmentID       INT         NOT NULL AUTO_INCREMENT,
    PatientID           VARCHAR(10) NOT NULL,
    ClinicianID         INT         NOT NULL,
    ClinicID            INT         NOT NULL,
    AppointmentDateTime DATETIME    NOT NULL,
    Notes               TEXT        NULL,
    PRIMARY KEY (AppointmentID),
    CONSTRAINT fk_appointment_patient
        FOREIGN KEY (PatientID)   REFERENCES patients (PatientID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_appointment_clinician
        FOREIGN KEY (ClinicianID) REFERENCES clinicians (ClinicianID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_appointment_clinic
        FOREIGN KEY (ClinicID)    REFERENCES clinics (ClinicID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- a clinician cannot be double-booked; a patient cannot be in two places at once
    CONSTRAINT uq_clinician_slot UNIQUE (ClinicianID, AppointmentDateTime),
    CONSTRAINT uq_patient_slot   UNIQUE (PatientID,   AppointmentDateTime),
    -- invalid / impossible dates are rejected
    CONSTRAINT chk_appointment_date CHECK (AppointmentDateTime >= '2020-01-01 00:00:00')
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 6. medicines  (lookup: one row per medicine, never stored as free text)
-- ---------------------------------------------------------------------
CREATE TABLE medicines (
    MedicineID   INT          NOT NULL AUTO_INCREMENT,
    MedicineName VARCHAR(120) NOT NULL,
    PRIMARY KEY (MedicineID),
    CONSTRAINT uq_medicine_name UNIQUE (MedicineName)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 7. prescription  (one row = one medicine item prescribed at one appointment;
--    all items of the same appointment together form that visit's prescription)
-- ---------------------------------------------------------------------
CREATE TABLE prescription (
    PrescriptionID INT         NOT NULL AUTO_INCREMENT,
    AppointmentID  INT         NOT NULL,
    MedicineID     INT         NOT NULL,
    Dose           VARCHAR(60) NOT NULL,
    Route          VARCHAR(60) NOT NULL,
    Frequency      VARCHAR(60) NOT NULL,
    Duration       VARCHAR(40) NOT NULL,
    PRIMARY KEY (PrescriptionID),
    CONSTRAINT fk_prescription_appointment
        FOREIGN KEY (AppointmentID) REFERENCES appointments (AppointmentID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_prescription_medicine
        FOREIGN KEY (MedicineID)    REFERENCES medicines (MedicineID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- the same medicine is listed only once per appointment
    CONSTRAINT uq_prescription_item UNIQUE (AppointmentID, MedicineID)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 8. Diagnosis  (one row = one diagnosis recorded at one appointment;
--    zero or many per appointment)
-- ---------------------------------------------------------------------
CREATE TABLE Diagnosis (
    DID           INT          NOT NULL AUTO_INCREMENT,
    Diagnosisname VARCHAR(100) NOT NULL,
    AppointmentID INT          NOT NULL,
    PRIMARY KEY (DID),
    CONSTRAINT fk_diagnosis_appointment
        FOREIGN KEY (AppointmentID) REFERENCES appointments (AppointmentID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT uq_diagnosis_per_visit UNIQUE (AppointmentID, Diagnosisname)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 9. FollowUp  (zero or ONE plan per appointment -> AppointmentID UNIQUE)
-- ---------------------------------------------------------------------
CREATE TABLE FollowUp (
    FollowUpID    INT         NOT NULL AUTO_INCREMENT,
    AppointmentID INT         NOT NULL,
    DueDate       DATE        NOT NULL,
    Priority      VARCHAR(10) NOT NULL DEFAULT 'Routine',
    Status        VARCHAR(12) NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (FollowUpID),
    CONSTRAINT fk_followup_appointment
        FOREIGN KEY (AppointmentID) REFERENCES appointments (AppointmentID)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

-- ALTER TABLE used (as the brief requests) to add the business-rule
-- constraints after creation: one plan per visit, controlled vocabularies.
ALTER TABLE FollowUp
    ADD CONSTRAINT uq_followup_appointment UNIQUE (AppointmentID),
    ADD CONSTRAINT chk_followup_priority
        CHECK (Priority IN ('Routine', 'High', 'Urgent')),
    ADD CONSTRAINT chk_followup_status
        CHECK (Status IN ('Pending', 'Scheduled', 'Completed', 'Cancelled'));

-- ---------------------------------------------------------------------
-- 10. UserAccounts  (Part D: login identities with SALTED SHA-256 hashes;
--     a user is optionally linked to a patient OR a clinician record)
-- ---------------------------------------------------------------------
CREATE TABLE UserAccounts (
    UserID       INT         NOT NULL AUTO_INCREMENT,
    Username     VARCHAR(50) NOT NULL,
    PasswordHash CHAR(64)    NOT NULL,          -- SHA2(CONCAT(Salt, password), 256)
    Salt         CHAR(16)    NOT NULL,
    Role         VARCHAR(20) NOT NULL,
    PatientID    VARCHAR(10) NULL,
    ClinicianID  INT         NULL,
    CreatedAt    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (UserID),
    CONSTRAINT uq_username UNIQUE (Username),
    CONSTRAINT chk_user_role
        CHECK (Role IN ('Administrator', 'Doctor', 'Receptionist', 'Patient')),
    -- a login belongs to at most one person record
    CONSTRAINT chk_user_single_link
        CHECK (NOT (PatientID IS NOT NULL AND ClinicianID IS NOT NULL))
) ENGINE = InnoDB;

-- RESTRICT (not CASCADE) because MySQL forbids CHECK constraints on columns
-- that carry a cascading referential action; an account must be removed
-- before the person record it belongs to.
ALTER TABLE UserAccounts
    ADD CONSTRAINT fk_user_patient
        FOREIGN KEY (PatientID)   REFERENCES patients (PatientID)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_user_clinician
        FOREIGN KEY (ClinicianID) REFERENCES clinicians (ClinicianID)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

-- ---------------------------------------------------------------------
-- Verification (evidence for the test log): expect 10 tables
-- ---------------------------------------------------------------------
SHOW TABLES;

SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM   information_schema.TABLE_CONSTRAINTS
WHERE  TABLE_SCHEMA = 'crownfield_eye_hospital'
ORDER  BY TABLE_NAME, CONSTRAINT_TYPE, CONSTRAINT_NAME;
