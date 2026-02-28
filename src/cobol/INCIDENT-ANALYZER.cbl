      *============================================================
      * INCIDENT-ANALYZER.CBL
      * Mainframe Incident Analysis System
      * Analyzes abend incidents from DB2 (SQLite-compatible)
      * Generates priority report and incident playbook entries
      *
      * Compile: cobc -x INCIDENT-ANALYZER.cbl -o incident-analyzer
      * Run:     ./incident-analyzer
      *============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. INCIDENT-ANALYZER.
       AUTHOR. PAWEŁ-JANIK.
       DATE-WRITTEN. 2026-02-28.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. LINUX.
       OBJECT-COMPUTER. LINUX.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      * Plik wejsciowy: dump incydentow z bazy (eksport CSV)
           SELECT INCIDENT-FILE
               ASSIGN TO "data/incidents-export.csv"
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

      * Plik wyjsciowy: raport priorytetowy
           SELECT REPORT-FILE
               ASSIGN TO "data/incident-report.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-REPORT-STATUS.

      * Plik wyjsciowy: JSON dla dashboardu Python
           SELECT JSON-FILE
               ASSIGN TO "data/incidents.json"
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-JSON-STATUS.

       DATA DIVISION.
       FILE SECTION.

      * Definicja rekordu pliku wejsciowego (CSV format)
       FD INCIDENT-FILE.
       01 INCIDENT-RECORD.
           05 IR-INC-ID          PIC 9(5).        *> ID incydentu
           05 FILLER             PIC X.           *> separator ","
           05 IR-JOB-NAME        PIC X(8).        *> nazwa joba
           05 FILLER             PIC X.
           05 IR-ABEND-CODE      PIC X(4).        *> np. S0C4
           05 FILLER             PIC X.
           05 IR-ABEND-TYPE      PIC X(6).        *> SYSTEM/USER
           05 FILLER             PIC X.
           05 IR-STEP-NAME       PIC X(8).        *> krok JCL
           05 FILLER             PIC X.
           05 IR-TIMESTAMP       PIC X(19).       *> YYYY-MM-DD HH:MM:SS
           05 FILLER             PIC X.
           05 IR-PRIORITY        PIC 9.           *> 1-4
           05 FILLER             PIC X.
           05 IR-STATUS          PIC X(11).       *> OPEN/IN_PROGRESS/RESOLVED

      * Definicja linii raportu
       FD REPORT-FILE.
       01 REPORT-LINE            PIC X(132).

      * Definicja linii JSON
       FD JSON-FILE.
       01 JSON-LINE              PIC X(200).

       WORKING-STORAGE SECTION.

      *-------------------------------------------------------------
      * Zmienne statusu plikow
      *-------------------------------------------------------------
       01 WS-DASH-LINE
           PIC X(65) VALUE ALL '-'.
      *-------------------------------------------------------------
      * Zmienne statusu plikow
      *-------------------------------------------------------------
       01 WS-FILE-STATUS         PIC XX VALUE SPACES.
       01 WS-REPORT-STATUS       PIC XX VALUE SPACES.
       01 WS-JSON-STATUS         PIC XX VALUE SPACES.
       01 WS-EOF                 PIC X VALUE 'N'.

      *-------------------------------------------------------------
      * Liczniki i statystyki
      *-------------------------------------------------------------
       01 WS-COUNTERS.
           05 WS-TOTAL-COUNT     PIC 9(5) VALUE 0.
           05 WS-P1-COUNT        PIC 9(5) VALUE 0.   *> Krytyczne
           05 WS-P2-COUNT        PIC 9(5) VALUE 0.   *> Wysokie
           05 WS-P3-COUNT        PIC 9(5) VALUE 0.   *> Normalne
           05 WS-P4-COUNT        PIC 9(5) VALUE 0.   *> Niskie
           05 WS-OPEN-COUNT      PIC 9(5) VALUE 0.
           05 WS-INPROG-COUNT    PIC 9(5) VALUE 0.
           05 WS-RESOLV-COUNT    PIC 9(5) VALUE 0.
           05 WS-S0C4-COUNT      PIC 9(5) VALUE 0.
           05 WS-S0C7-COUNT      PIC 9(5) VALUE 0.
           05 WS-S322-COUNT      PIC 9(5) VALUE 0.
           05 WS-B37-COUNT       PIC 9(5) VALUE 0.
           05 WS-S806-COUNT      PIC 9(5) VALUE 0.
           05 WS-OTHER-COUNT     PIC 9(5) VALUE 0.

      *-------------------------------------------------------------
      * Zmienna do formatowania liczb w raporcie
      *-------------------------------------------------------------
       01 WS-DISP-COUNT          PIC ZZZ9.

      *-------------------------------------------------------------
      * Linie raportu (preformatowane)
      *-------------------------------------------------------------
       01 WS-SEPARATOR
           PIC X(65) VALUE ALL '='.
       01 WS-BLANK-LINE
           PIC X(1) VALUE SPACES.

       01 WS-HEADER-LINE.
           05 FILLER PIC X(5)  VALUE 'INCID'.
           05 FILLER PIC X(2)  VALUE '  '.
           05 FILLER PIC X(8)  VALUE 'JOB     '.
           05 FILLER PIC X(2)  VALUE '  '.
           05 FILLER PIC X(4)  VALUE 'ABND'.
           05 FILLER PIC X(2)  VALUE '  '.
           05 FILLER PIC X(8)  VALUE 'STEP    '.
           05 FILLER PIC X(2)  VALUE '  '.
           05 FILLER PIC X(1)  VALUE 'P'.
           05 FILLER PIC X(2)  VALUE '  '.
           05 FILLER PIC X(11) VALUE 'STATUS     '.
           05 FILLER PIC X(2)  VALUE '  '.
           05 FILLER PIC X(19) VALUE 'TIMESTAMP          '.

       01 WS-DETAIL-LINE.
           05 WL-INC-ID          PIC Z(4)9.
           05 FILLER             PIC X(2)  VALUE SPACES.
           05 WL-JOB-NAME        PIC X(8).
           05 FILLER             PIC X(2)  VALUE SPACES.
           05 WL-ABEND-CODE      PIC X(4).
           05 FILLER             PIC X(2)  VALUE SPACES.
           05 WL-STEP-NAME       PIC X(8).
           05 FILLER             PIC X(2)  VALUE SPACES.
           05 WL-PRIORITY        PIC 9.
           05 FILLER             PIC X(2)  VALUE SPACES.
           05 WL-STATUS          PIC X(11).
           05 FILLER             PIC X(2)  VALUE SPACES.
           05 WL-TIMESTAMP       PIC X(19).

      *-------------------------------------------------------------
      * Linia JSON (do bufora)
      *-------------------------------------------------------------
       01 WS-JSON-RECORD.
           05 FILLER         PIC X(4)  VALUE '  {"'.
           05 WJ-INC-ID      PIC 9(5).
           05 FILLER         PIC X(12) VALUE '","job":"'.
           05 WJ-JOB         PIC X(8).
           05 FILLER         PIC X(12) VALUE '","abend":"'.
           05 WJ-ABEND       PIC X(4).
           05 FILLER         PIC X(14) VALUE '","priority":'.
           05 WJ-PRIORITY    PIC 9.
           05 FILLER         PIC X(12) VALUE ',"status":"'.
           05 WJ-STATUS      PIC X(11).
           05 FILLER         PIC X(13) VALUE '","timestamp"'.
           05 FILLER         PIC X(3)  VALUE ':"'.
           05 WJ-TIMESTAMP   PIC X(19).
           05 FILLER         PIC X(2)  VALUE '"}'.

       01 WS-JSON-COMMA      PIC X VALUE ','.
       01 WS-FIRST-JSON      PIC X VALUE 'Y'.

       PROCEDURE DIVISION.

      *=============================================================
       MAIN-PARA.
      *=============================================================
           PERFORM INITIALIZE-PARA
           PERFORM OPEN-FILES-PARA
           PERFORM WRITE-REPORT-HEADER
           PERFORM WRITE-JSON-HEADER

           PERFORM READ-FIRST-RECORD
           PERFORM UNTIL WS-EOF = 'Y'
               PERFORM PROCESS-RECORD-PARA
               PERFORM READ-NEXT-RECORD
           END-PERFORM

           PERFORM WRITE-REPORT-SUMMARY
           PERFORM WRITE-JSON-FOOTER
           PERFORM CLOSE-FILES-PARA

           DISPLAY "==================================================="
           DISPLAY "INCIDENT ANALYZER - PROCESSING COMPLETE"
           DISPLAY "Total incidents processed: " WS-TOTAL-COUNT
           DISPLAY "Report written to: data/incident-report.txt"
           DISPLAY "JSON written to:   data/incidents.json"
           DISPLAY "==================================================="

           STOP RUN.

      *=============================================================
       INITIALIZE-PARA.
      *=============================================================
           INITIALIZE WS-COUNTERS
           MOVE 'N' TO WS-EOF
           MOVE 'Y' TO WS-FIRST-JSON.

      *=============================================================
       OPEN-FILES-PARA.
      *=============================================================
           OPEN INPUT  INCIDENT-FILE
           OPEN OUTPUT REPORT-FILE
           OPEN OUTPUT JSON-FILE
           IF WS-FILE-STATUS NOT = "00"
               DISPLAY "ERROR: Cannot open INCIDENT-FILE. Status: "
                       WS-FILE-STATUS
                       DISPLAY "Run: python3 integration/python/"
                       DISPLAY "export-db.py first"
               STOP RUN
           END-IF.

      *=============================================================
       WRITE-REPORT-HEADER.
      *=============================================================
           WRITE REPORT-LINE FROM WS-SEPARATOR
           WRITE REPORT-LINE FROM
               "   MAINFRAME INCIDENT ANALYSIS REPORT"
           WRITE REPORT-LINE FROM
               "   z/OS Abend Analysis System v1.0"
           WRITE REPORT-LINE FROM WS-SEPARATOR
           WRITE REPORT-LINE FROM WS-BLANK-LINE
           WRITE REPORT-LINE FROM "   INCIDENT DETAIL:"
           WRITE REPORT-LINE FROM WS-BLANK-LINE
           WRITE REPORT-LINE FROM WS-HEADER-LINE
           WRITE REPORT-LINE FROM WS-DASH-LINE.

      *=============================================================
       WRITE-JSON-HEADER.
      *=============================================================
           WRITE JSON-LINE FROM '{"incidents":['
           MOVE 'Y' TO WS-FIRST-JSON.

      *=============================================================
       READ-FIRST-RECORD.
      *=============================================================
           READ INCIDENT-FILE
               AT END MOVE 'Y' TO WS-EOF
           END-READ.

      *=============================================================
       READ-NEXT-RECORD.
      *=============================================================
           READ INCIDENT-FILE
               AT END MOVE 'Y' TO WS-EOF
           END-READ.

      *=============================================================
       PROCESS-RECORD-PARA.
      * Glowna logika: przetworz jeden rekord incydentu
      *=============================================================
           ADD 1 TO WS-TOTAL-COUNT

      * Licznik priorytetow
           EVALUATE IR-PRIORITY
               WHEN 1  ADD 1 TO WS-P1-COUNT
               WHEN 2  ADD 1 TO WS-P2-COUNT
               WHEN 3  ADD 1 TO WS-P3-COUNT
               WHEN 4  ADD 1 TO WS-P4-COUNT
           END-EVALUATE

      * Licznik statusow
           EVALUATE TRUE
               WHEN IR-STATUS(1:4) = 'OPEN'
                   ADD 1 TO WS-OPEN-COUNT
               WHEN IR-STATUS(1:11) = 'IN_PROGRESS'
                   ADD 1 TO WS-INPROG-COUNT
               WHEN IR-STATUS(1:8) = 'RESOLVED'
                   ADD 1 TO WS-RESOLV-COUNT
           END-EVALUATE

      * Licznik abend kodow
           EVALUATE IR-ABEND-CODE
               WHEN 'S0C4'   ADD 1 TO WS-S0C4-COUNT
               WHEN 'S0C7'   ADD 1 TO WS-S0C7-COUNT
               WHEN 'S322'   ADD 1 TO WS-S322-COUNT
               WHEN 'B37 '   ADD 1 TO WS-B37-COUNT
               WHEN 'S806'   ADD 1 TO WS-S806-COUNT
               WHEN OTHER    ADD 1 TO WS-OTHER-COUNT
           END-EVALUATE

      * Zapisz linie do raportu tekstowego
           MOVE IR-INC-ID     TO WL-INC-ID
           MOVE IR-JOB-NAME   TO WL-JOB-NAME
           MOVE IR-ABEND-CODE TO WL-ABEND-CODE
           MOVE IR-STEP-NAME  TO WL-STEP-NAME
           MOVE IR-PRIORITY   TO WL-PRIORITY
           MOVE IR-STATUS     TO WL-STATUS
           MOVE IR-TIMESTAMP  TO WL-TIMESTAMP
           WRITE REPORT-LINE FROM WS-DETAIL-LINE

      * Zapisz rekord do JSON (dla dashboardu Python)
           IF WS-FIRST-JSON = 'N'
               WRITE JSON-LINE FROM WS-JSON-COMMA
           END-IF
           MOVE IR-INC-ID     TO WJ-INC-ID
           MOVE IR-JOB-NAME   TO WJ-JOB
           MOVE IR-ABEND-CODE TO WJ-ABEND
           MOVE IR-PRIORITY   TO WJ-PRIORITY
           MOVE IR-STATUS     TO WJ-STATUS
           MOVE IR-TIMESTAMP  TO WJ-TIMESTAMP
           WRITE JSON-LINE FROM WS-JSON-RECORD
           MOVE 'N' TO WS-FIRST-JSON.

      *=============================================================
       WRITE-REPORT-SUMMARY.
      * Sekcja podsumowania statystycznego raportu
      *=============================================================
           WRITE REPORT-LINE FROM WS-DASH-LINE
           WRITE REPORT-LINE FROM WS-BLANK-LINE
           WRITE REPORT-LINE FROM "   SUMMARY STATISTICS:"
           WRITE REPORT-LINE FROM WS-BLANK-LINE

           MOVE WS-TOTAL-COUNT TO WS-DISP-COUNT
           STRING "   Total incidents:     "
               DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE
               INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE

           WRITE REPORT-LINE FROM WS-BLANK-LINE
           WRITE REPORT-LINE FROM "   BY PRIORITY:"
           MOVE WS-P1-COUNT TO WS-DISP-COUNT
           STRING "   [P1] Critical:  " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-P2-COUNT TO WS-DISP-COUNT
           STRING "   [P2] High:      " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-P3-COUNT TO WS-DISP-COUNT
           STRING "   [P3] Normal:    " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-P4-COUNT TO WS-DISP-COUNT
           STRING "   [P4] Low:       " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE

           WRITE REPORT-LINE FROM WS-BLANK-LINE
           WRITE REPORT-LINE FROM "   BY ABEND CODE:"
           MOVE WS-S0C4-COUNT TO WS-DISP-COUNT
           STRING "   S0C4 (Memory):  " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-S0C7-COUNT TO WS-DISP-COUNT
           STRING "   S0C7 (Data):    " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-S322-COUNT TO WS-DISP-COUNT
           STRING "   S322 (Timeout): " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-B37-COUNT  TO WS-DISP-COUNT
           STRING "   B37  (Space):   " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-S806-COUNT TO WS-DISP-COUNT
           STRING "   S806 (NotFound):" DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE

           WRITE REPORT-LINE FROM WS-BLANK-LINE
           WRITE REPORT-LINE FROM "   BY STATUS:"
           MOVE WS-OPEN-COUNT TO WS-DISP-COUNT
           STRING "   OPEN:           " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-INPROG-COUNT TO WS-DISP-COUNT
           STRING "   IN_PROGRESS:    " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE
           MOVE WS-RESOLV-COUNT TO WS-DISP-COUNT
           STRING "   RESOLVED:       " DELIMITED SIZE
               WS-DISP-COUNT DELIMITED SIZE INTO REPORT-LINE
           WRITE REPORT-LINE FROM REPORT-LINE

           WRITE REPORT-LINE FROM WS-BLANK-LINE
           WRITE REPORT-LINE FROM WS-SEPARATOR.

      *=============================================================
       WRITE-JSON-FOOTER.
      *=============================================================
           WRITE JSON-LINE FROM
               '],"generated_by":"INCIDENT-ANALYZER.CBL"}'.

      *=============================================================
       CLOSE-FILES-PARA.
      *=============================================================
           CLOSE INCIDENT-FILE
           CLOSE REPORT-FILE
           CLOSE JSON-FILE.

