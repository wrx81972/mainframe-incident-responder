-- Przykładowe dane testowe

INSERT INTO JOBS VALUES
('PAYROLL', 'JOB00142', 'HERC01', 'A', 'ABEND',  '2026-02-01 08:00:00', '2026-02-01 08:05:22'),
('REPORTS', 'JOB00156', 'HERC02', 'A', 'ACTIVE', '2026-02-01 09:00:00', NULL),
('BATCHUPD', 'JOB00163', 'HERC01', 'B', 'ABEND',  '2026-02-02 14:30:00', '2026-02-02 14:31:05'),
('DBMAINT', 'JOB00170', 'HERC03', 'A', 'ENDED',  '2026-02-03 02:00:00', '2026-02-03 03:15:00'),
('ACCREC',  'JOB00171', 'HERC01', 'A', 'ABEND',  '2026-02-03 10:00:00', '2026-02-03 10:00:45');

INSERT INTO INCIDENTS (JOB_NAME, JOB_ID, ABEND_CODE, ABEND_TYPE, STEP_NAME, TIMESTAMP, PRIORITY, STATUS) VALUES
('PAYROLL', 'JOB00142', 'S0C4', 'SYSTEM', 'STEP010', '2026-02-01 08:05:22', 1, 'RESOLVED'),
('PAYROLL', 'JOB00142', 'S0C7', 'SYSTEM', 'STEP010', '2026-02-01 08:05:22', 2, 'RESOLVED'),
('BATCHUPD', 'JOB00163', 'S322', 'SYSTEM', 'STEP020', '2026-02-02 14:31:05', 2, 'IN_PROGRESS'),
('ACCREC',  'JOB00171', 'B37',  'SYSTEM', 'STEP001', '2026-02-03 10:00:45', 3, 'OPEN'),
('PAYROLL', 'JOB00142', 'S0C4', 'SYSTEM', 'STEP030', '2026-02-10 08:10:00', 1, 'OPEN'),
('BATCHUPD', 'JOB00163', 'S806', 'SYSTEM', 'STEP010', '2026-02-15 14:00:00', 2, 'OPEN'),
('ACCREC',  'JOB00171', 'S0C4', 'SYSTEM', 'STEP002', '2026-02-20 10:30:00', 1, 'IN_PROGRESS');

INSERT INTO MEMORY_DUMPS (INC_ID, DUMP_TYPE, PSW_ADDR, FAILING_ADDR, REG_DUMP, DUMP_SIZE, ANALYZED, CREATED_AT) VALUES
(1, 'SYSMDUMP', '00451C8A', '00000000', '{"R0":"00000000","R1":"00451C8A","R14":"004519F0","R15":"00000004"}', 2048, 1, '2026-02-01 08:05:23'),
(5, 'ABEND',    '00452001', 'FFFF0000', '{"R0":"00000001","R1":"FFFF0000","R14":"00452000","R15":"00000008"}', 1024, 0, '2026-02-10 08:10:01');

INSERT INTO RESOLUTIONS (ABEND_CODE, CAUSE, SOLUTION, REFERENCE) VALUES
('S0C4', 'Protection exception: program tried to access memory address it does not own. Often caused by uninitialized pointer or wrong base register.', 'Check base register setup in BALR/BASR instruction. Verify USING statement. Look for LOAD/STORE to address 0x00000000.', 'IBM z/OS MVS System Codes: IEA194I'),
('S0C7', 'Data exception: arithmetic operation on non-numeric field. COBOL PIC 9 field contains spaces or non-digit characters.', 'Add MOVE ZEROS TO field before arithmetic. Check input data validation. Use NUMERIC class test.', 'IBM z/OS MVS System Codes: IEC020I'),
('S322', 'Time limit exceeded: job ran longer than allowed CPU time. JCL TIME= parameter was exceeded.', 'Increase TIME parameter in JCL. Optimize loop logic. Check for infinite loops in COBOL PERFORM.', 'IBM z/OS JCL Reference: TIME parameter'),
('B37',  'Out of space on DASD volume: dataset could not be extended. Primary/secondary allocation exhausted.', 'Increase SPACE allocation in JCL DD statement. Archive old data. Compress PDS.', 'IBM z/OS DFSMS: IEC032I'),
('S806', 'Program not found: LOAD macro failed because module is not in STEPLIB/JOBLIB or LPALST.', 'Check STEPLIB DD in JCL. Verify module name spelling. Link-edit and place in correct library.', 'IBM z/OS MVS System Codes: IEA306I');

