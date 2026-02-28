//ANALYZE  JOB  (ACCT),'INCIDENT ANALYSIS',CLASS=A,MSGCLASS=X,
//             MSGLEVEL=(1,1),NOTIFY=&SYSUID
//*
//* JOB: INCIDENT-ANALYZER
//* DESC: Analyze mainframe abend incidents and generate report
//* OWNER: HERC01
//* SCHEDULE: ON-DEMAND
//*
//STEP010  EXEC PGM=INCIDENT-ANALYZER
//STEPLIB  DD   DSN=HERC01.LOADLIB,DISP=SHR
//INCFILE  DD   DSN=HERC01.INCIDENTS.EXPORT,DISP=SHR,
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=8000)
//RPTFILE  DD   DSN=HERC01.INCIDENTS.REPORT,DISP=(NEW,CATLG,DELETE),
//             SPACE=(TRK,(5,5)),
//             DCB=(RECFM=FBA,LRECL=133,BLKSIZE=13300)
//JSONOUT  DD   DSN=HERC01.INCIDENTS.JSON,DISP=(NEW,CATLG,DELETE),
//             SPACE=(TRK,(5,5)),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=20000)
//SYSOUT   DD   SYSOUT=*
//SYSPRINT DD   SYSOUT=*
//*
//* JCL EXPLANATION:
//* JOB card: defines job name, account, class, output class
//* EXEC PGM=: runs compiled COBOL program
//* STEPLIB DD: library containing the load module (compiled program)
//* INCFILE DD: input dataset (CSV exported from DB2)
//* RPTFILE DD: output report dataset (NEW=create, CATLG=catalog it)
//* DCB: Data Control Block - defines record format
//*   RECFM=FB = Fixed Block records
//*   LRECL=133 = Logical Record Length (132 chars + carriage control)
//*   BLKSIZE = physical block size (multiple of LRECL)

