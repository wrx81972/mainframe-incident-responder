# z/OS Abend Incident Playbook

**Project:** mainframe-incident-responder
**Author:** Paweł Janik
**Purpose:** Structured incident resolution guide for common z/OS abend codes.
Modeled after real IBM mainframe operational runbooks used in production environments.

> **What is an abend?**
> ABnormal END — the z/OS equivalent of a crash. Every abend has a code that identifies
> the exact cause. Unlike Linux segfaults, z/OS abend codes are highly specific and
> standardized across all IBM mainframe systems worldwide.

## How to Read an Abend Code

Abend codes follow two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| `Sxxx` | `S0C4` | **System abend** — raised by z/OS itself (hardware or OS protection) |
| `Uxxx` | `U4038` | **User abend** — raised by application code (`ABEND SVC`) |

The letter after `S` is always `0` for protection/data exceptions, or a letter for
storage/I/O exceptions. The last digit(s) identify the exact sub-type.

**Where to find abend info after a job fails:**

1. Open SPOOL in ISPF (`S` from main menu)
2. Find your JOB name → status `ABEND`
3. Look for `IEAxxx` or `IECxxx` message in SYSPRINT
4. The abend code appears next to `ABEND=Sxxx`

## INCIDENT-001 — S0C4: Protection Exception

### What is it?

S0C4 is the most common abend on z/OS. It occurs when a program attempts to
**read from or write to a memory address it does not own**.

On z/OS, every region of memory has a **storage key** (0–15). A program running
under key 8 cannot touch memory owned by key 0 (the operating system). When it
tries — the hardware raises a Protection Exception immediately.

**Linux equivalent:** `Segmentation fault (SIGSEGV)`

### When does it occur?

- **NULL pointer dereference** — using an uninitialized address (hex `00000000`)
- **Wrong base register** — COBOL/Assembler uses the wrong register as a memory base
- **Bad USING statement** — DSECT mapped to wrong area of storage
- **Off-by-one in pointer arithmetic** — writing one byte past the end of a buffer
- **Freed storage** — accessing a `FREEMAIN`'d area that z/OS already reclaimed

### How to debug

**Step 1 — Read the dump header**
In SYSMDUMP or SYSUDUMP, find:
```
COMPLETION CODE  SYSTEM=0C4
PSW AT TIME OF ERROR = 078D1000  004519F0
```
The second PSW word (`004519F0`) is the **failing instruction address**.

**Step 2 — Identify the failing instruction.
Cross-reference the PSW address with your load module map (link-edit listing).
This tells you exactly which COBOL statement or Assembler instruction caused the abend.

**Step 3 — Check the failing address**
```
DATA AT PSW  00 000000  (zeros = NULL pointer)
```
If the failing address is `00000000` → classic NULL dereference.
If it's an odd address like `FFFF0000` → pointer corruption or uninitialized variable.

**Step 4 — Examine registers R0–R15**
```
GR 0-7   00000000 004519F0 00451C8A 00000000 ...
GR 8-15  00000001 00000000 004519F8 00000004 ...
```
R1 usually holds the parameter list address.
R14 is the return address (where the call came from).
R15 is the entry point of the called routine.

### How to fix

**In COBOL:**
```cobol
* WRONG — using uninitialized pointer
MOVE WS-ADDRESS TO ADDRESS OF MY-STRUCT   *> WS-ADDRESS is spaces!
MOVE MY-STRUCT-FIELD TO WS-OUTPUT         *> S0C4 here

* CORRECT — initialize before use
MOVE LOW-VALUES TO WS-ADDRESS
MOVE LENGTH OF MY-STRUCT TO WS-LENGTH
ALLOCATE WS-LENGTH CHARACTERS INITIALIZED RETURNING WS-ADDRESS
```

**In Assembler:**
```asm
; WRONG — R3 never loaded, used as base
   L    R4,0(R3)       ; S0C4 — R3=0x00000000

; CORRECT — load base register first
   LA   R3,WORKAREA    ; load address of work area
   L    R4,0(R3)       ; now safe
```

**Checklist:**
- [ ] Check all `USING` statements match actual storage layout
- [ ] Verify `BALR R12,0` / `BASR R12,0` establishes correct base
- [ ] Add `NUMERIC` class test before arithmetic on input fields
- [ ] Initialize all pointer variables before use
- [ ] Check `CALL` parameter list — correct number and types?

**IBM Reference:** `IEA194I`, z/OS MVS System Codes manual, code `0C4`

---

## INCIDENT-002 — S0C7: Data Exception

### What is it?

S0C7 occurs when the CPU attempts a **decimal arithmetic operation on a field
that does not contain valid packed-decimal data**.

On z/OS, COBOL `PIC 9` fields with `USAGE COMP-3` (packed decimal) store numbers
in a special binary-coded format. If the field contains spaces, alphabetic characters,
or garbage — any arithmetic on it raises S0C7.

**Linux equivalent:** closest is `SIGFPE` (floating point exception), but more
specifically it's like doing `int x = int("abc")` without validation.

### When does it occur?

- Reading a numeric field from a file that contains spaces or non-digits
- Forgetting to initialize a `PIC 9` field before arithmetic (`ADD`, `COMPUTE`, etc.)
- Moving alphabetic data into a numeric field via incorrect MOVE
- File input with wrong record layout (field offsets shifted by one byte)
- DB2 `NULL` value moved into a `NOT NULL` numeric host variable

### How to debug

**Step 1 — Find the failing field**
In the dump, z/OS shows the instruction that failed:
```
COMPLETION CODE  SYSTEM=0C7
OPERAND 1  ADDRESS=004521A0  DATA=40404040404040C0
```
`40` = EBCDIC space, `C0` = invalid packed digit. This is the bad field.

**Step 2 — Map the address to your DATA DIVISION**
Using the COBOL compile listing (SYSPRINT), find which `WORKING-STORAGE` or
`FILE SECTION` field maps to address `004521A0`.

**Step 3 — Trace where the field was last written**
Search your code for every `MOVE ... TO that-field` and every `READ` that
populates the surrounding record.

### How to fix

```cobol
* WRONG — no validation before arithmetic
READ INPUT-FILE INTO WS-RECORD
ADD WS-AMOUNT TO WS-TOTAL         *> S0C7 if WS-AMOUNT = spaces

* CORRECT — validate before use
READ INPUT-FILE INTO WS-RECORD
IF WS-AMOUNT IS NUMERIC
    ADD WS-AMOUNT TO WS-TOTAL
ELSE
    MOVE ZEROS TO WS-AMOUNT
    ADD 1 TO WS-BAD-RECORDS
    DISPLAY "S0C7 RISK: non-numeric AMOUNT in job " JOB-NAME
END-IF
```

**Preventive pattern — initialize all working storage:**
```cobol
PROCEDURE DIVISION.
MAIN-PARA.
    INITIALIZE WORKING-STORAGE-GROUP
```

**Checklist:**
- [ ] Add `IS NUMERIC` test before every arithmetic on input-sourced fields
- [ ] Use `INITIALIZE` on record areas before `READ ... INTO`
- [ ] Check file record layout — is LRECL correct? Are field offsets right?
- [ ] For DB2: use null indicators (`WS-NULL-IND`) for nullable numeric columns
- [ ] Verify `COMP-3` / `BINARY` field definitions match actual data format

**IBM Reference:** `IEA194I`, z/OS MVS System Codes manual, code `0C7`

---

## INCIDENT-003 — S322: Time Limit Exceeded

### What is it?

S322 means a batch job **consumed more CPU time than its JCL `TIME=` parameter
allowed**. z/OS tracks CPU consumption per job step and terminates the step when
the limit is reached.

This is a **resource protection mechanism**, not a hardware fault. z/OS deliberately
kills the job to prevent one runaway batch job from starving others on the system.

**Linux equivalent:** `SIGXCPU` (process exceeded CPU time limit set by `ulimit -t`)

### When does it occur?

- **Infinite loop** — `PERFORM UNTIL` condition never becomes true
- **Missing loop exit** — forgot `AT END` clause on file READ
- **Unexpected data volume** — job processes 10x more records than expected
- **Performance regression** — inefficient SQL added (full table scan instead of index)
- **`TIME=` too low** — job was fine but JCL parameter was set too conservatively
- **Deadlock wait** — job waiting for a locked DB2 resource

### How to debug

**Step 1 — Check SYSOUT for last activity**
```
STEP010  ELAPSED TIME = 00:05:00  CPU TIME = 00:04:58
IEF272I STEP010 - STEP WAS NOT EXECUTED  [ABEND=S322]
```
High CPU time close to elapsed → genuine infinite loop.
Low CPU but high elapsed → waiting (I/O, lock, dataset contention).

**Step 2 — Find last DISPLAY or checkpoint**
Add progress `DISPLAY` statements every N records to narrow down where the loop is stuck:
```cobol
IF RECORD-COUNT > 0 AND FUNCTION MOD(RECORD-COUNT, 10000) = 0
    DISPLAY "CHECKPOINT: processed " RECORD-COUNT " records"
END-IF
```

**Step 3 — Review PERFORM loop termination**
```cobol
* DANGEROUS — what if WS-EOF never becomes 'Y'?
PERFORM UNTIL WS-EOF = 'Y'
    READ INPUT-FILE
    ...
END-PERFORM

* SAFE — always check AT END
READ INPUT-FILE
    AT END MOVE 'Y' TO WS-EOF
    NOT AT END PERFORM PROCESS-RECORD
END-READ
```

### How to fix

**Option A — Fix the loop:**
```cobol
PERFORM READ-RECORD-PARA
PERFORM UNTIL WS-EOF = 'Y'
    PERFORM PROCESS-RECORD-PARA
    PERFORM READ-RECORD-PARA
END-PERFORM

READ-RECORD-PARA.
    READ MY-FILE
        AT END     MOVE 'Y' TO WS-EOF
        NOT AT END CONTINUE
    END-READ.
```

**Option B — Increase TIME in JCL (temporary workaround):**
```jcl
//STEP010 EXEC PGM=MYPROG,TIME=(5,0)
```

**Checklist:**
- [ ] Every `PERFORM UNTIL` has a guaranteed exit condition
- [ ] Every `READ` has `AT END` that sets the EOF flag
- [ ] DB2 queries have index coverage — check `EXPLAIN` output
- [ ] `TIME=` parameter is realistic for current data volume
- [ ] Add record count checkpoints for long-running batch

**IBM Reference:** `IEF272I`, z/OS JCL Reference `TIME parameter`, MVS System Codes `322`

---

## INCIDENT-004 — B37: Out of Space on DASD

### What is it?

B37 means a **dataset ran out of disk space** (DASD — Direct Access Storage Device).
z/OS pre-allocates space for datasets in JCL. When a program writes more data than
allocated — and secondary extents are exhausted — z/OS raises B37.

**Related codes:**
- `D37` — primary space allocation exhausted (no secondary extents defined)
- `E37` — maximum number of extents (255) reached
- `B37` — secondary extents exhausted

### When does it occur?

- Batch job processing more records than expected (data growth)
- Spool overflow — SYSOUT dataset too small for large job output
- PDS (library) full — too many members, needs compression
- Incorrect `SPACE=(TRK,(5,5))` — primary/secondary too small
- Runaway job writing output in a loop

### How to debug

**Step 1 — Find the DD that ran out of space**
```
IEC032I B37-04,IGG019XA,STEP010,OUTFILE,SYS001,1234,HERC01.OUTPUT.DATA
```
The message shows exactly which DD statement caused the abend.

**Step 2 — Check current allocation**  
In ISPF `3.2` (Dataset utility) → list dataset → check `USED TRACKS` vs `ALLOCATED`.

**Step 3 — Estimate correct size**  
```
records x LRECL / track_capacity = tracks needed
example: 100,000 records x 133 bytes / 56,664 bytes/track = ~235 tracks
```

### How to fix

**Fix JCL SPACE parameter:**
```jcl
* WRONG — too small for production volume
//OUTFILE DD  DSN=HERC01.OUTPUT.DATA,DISP=(NEW,CATLG),
//            SPACE=(TRK,(5,5))

* CORRECT — generous allocation with realistic secondary
//OUTFILE DD  DSN=HERC01.OUTPUT.DATA,DISP=(NEW,CATLG),
//            SPACE=(CYL,(10,5)),
//            DCB=(RECFM=FB,LRECL=133,BLKSIZE=13300)
```

**For PDS compression:**
```jcl
//COMPRESS EXEC PGM=IEBCOPY
//SYSPRINT DD SYSOUT=*
//INDD     DD DSN=HERC01.MY.LIBRARY,DISP=SHR
//OUTDD    DD DSN=HERC01.MY.LIBRARY,DISP=SHR
//SYSIN    DD *
  COPY INDD=INDD,OUTDD=OUTDD
/*
```

**Checklist:**
- [ ] Review `SPACE=` allocation against realistic data volume
- [ ] Use `CYL` instead of `TRK` for large datasets
- [ ] Add `RLSE` subparameter to release unused space
- [ ] For SYSOUT: use `FREE=CLOSE` and `OUTLIM=` to prevent spool explosion
- [ ] Periodically compress PDS libraries with IEBCOPY

**IBM Reference:** `IEC032I`, z/OS DFSMS Using Data Sets, MVS System Codes `B37/D37/E37`

## INCIDENT-005 — S806: Program Not Found

### What is it?

S806 means z/OS **could not find and load the program** named in `PGM=` on the
`EXEC` statement (or named in a COBOL `CALL` statement).

z/OS searches for load modules (compiled programs) in a specific library search
order. If the module is not found in any searched library — S806.

**Linux equivalent:** `command not found` or `error while loading shared libraries`

### When does it occur?

- Program name misspelled in `PGM=` or COBOL `CALL 'PROGNAME'`
- Program was not link-edited (compiled but not placed in a load library)
- `STEPLIB` DD missing from JCL — z/OS only searches system libraries
- Load module in wrong library
- Program deleted or renamed, JCL not updated
- Case sensitivity — `MYPROG` != `Myprog` on z/OS (always uppercase for PGM names)

### How to debug

**Step 1 — Read the S806 message:**
```
IEA306I ABEND806-U,COMP=S806,PARM=00000100
IEF450I PAYROLL  STEP010 - ABEND DURING EXECUTION  SYSTEM=806
```

**Step 2 — Verify program name**  
In ISPF `3.4` → enter `HERC01.LOADLIB` → list members → confirm program exists.

**Step 3 — Check library search order**
z/OS searches in this order:
1. `STEPLIB` DD in current step
2. `JOBLIB` DD at job level
3. `LINKLIST` (system libraries, e.g. `SYS1.LINKLIB`)

### How to fix

**Fix 1 — Add STEPLIB pointing to correct load library:**
```jcl
//STEP010  EXEC PGM=PAYROLL
//STEPLIB  DD   DSN=HERC01.LOADLIB,DISP=SHR
//SYSOUT   DD   SYSOUT=*
```

**Fix 2 — Recompile and link-edit the program:**
```jcl
//COMPILE  EXEC PGM=IGYCRCTL,PARM='OBJECT,NODECK'
//SYSLIN   DD   DSN=&&OBJSET,DISP=(NEW,PASS)
//SYSIN    DD   DSN=HERC01.SOURCE(PAYROLL),DISP=SHR
//
//LKED     EXEC PGM=IEWL,PARM='LIST,MAP,RENT'
//SYSLIN   DD   DSN=&&OBJSET,DISP=(OLD,DELETE)
//SYSLMOD  DD   DSN=HERC01.LOADLIB(PAYROLL),DISP=SHR
//SYSPRINT DD   SYSOUT=*
```

**Fix 3 — For COBOL dynamic CALL:**
```cobol
CALL 'MEMDIAG' USING WS-ADDRESS WS-RETURN-CODE
    ON EXCEPTION
        DISPLAY "S806 risk: MEMDIAG module not found"
        MOVE 8 TO WS-RETURN-CODE
END-CALL
```

**Checklist:**
- [ ] Verify `PGM=` name matches member name in load library (8 chars, uppercase)
- [ ] Confirm `STEPLIB` DD points to correct library and `DISP=SHR`
- [ ] Rerun compile + link-edit if source was changed
- [ ] For COBOL `CALL`: use `ON EXCEPTION` handler
- [ ] After moving to new environment: verify all load libraries are catalogued

**IBM Reference:** `IEA306I`, z/OS MVS System Codes `806`, z/OS JCL Reference `STEPLIB DD` 

## Quick Reference Card

| Code  | Name                   | Linux analog       | First thing to check                                      |
|-------|------------------------|--------------------|-----------------------------------------------------------|
| S0C4  | Protection Exception   | SIGSEGV            | PSW address → failing instruction; is address 00000000?  |
| S0C7  | Data Exception         | SIGFPE             | Which numeric field contains non-numeric data?            |
| S322  | Time Exceeded          | SIGXCPU            | Is there an infinite loop? Check PERFORM UNTIL exit       |
| B37   | Out of DASD Space      | Disk full          | Which DD ran out? Increase SPACE= in JCL                  |
| S806  | Program Not Found      | command not found  | Is STEPLIB DD present? Is module in the library?          |

## Debugging Tools Reference

| Tool       | Purpose                          | How to invoke                          |
|------------|----------------------------------|----------------------------------------|
| IPCS       | Interactive dump analysis        | `IPCS` from ISPF option 7              |
| SDSF       | Spool Display and Search         | `SDSF` or ISPF option S                |
| IEBCOPY    | PDS compress / copy              | JCL utility                            |
| IDCAMS     | Dataset management (VSAM)        | JCL utility, REPRO, DEFINE             |
| AMBLIST    | List load module contents        | PGM=AMBLIST — shows linked modules     |
| IGYCRCTL   | COBOL compiler                   | EXEC PGM=IGYCRCTL                      |
| IEWL       | Linkage editor                   | EXEC PGM=IEWL                          |

