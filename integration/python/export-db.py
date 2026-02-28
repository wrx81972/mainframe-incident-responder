#!/usr/bin/env python3
"""
export-db.py - Eksportuje dane z SQLite do CSV dla COBOL
Uruchom PRZED INCIDENT-ANALYZER.cbl
"""
import sqlite3
import csv

DB_PATH = "data/incidents.db"
CSV_PATH = "data/incidents-export.csv"

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

cursor.execute("""
    SELECT 
        INC_ID,
        JOB_NAME,
        ABEND_CODE,
        ABEND_TYPE,
        COALESCE(STEP_NAME, 'UNKNOWN '),
        TIMESTAMP,
        PRIORITY,
        STATUS
    FROM INCIDENTS
    ORDER BY PRIORITY, TIMESTAMP
""")

rows = cursor.fetchall()
conn.close()

with open(CSV_PATH, 'w', newline='') as f:
    for row in rows:
        inc_id    = str(row[0]).zfill(5)
        job_name  = str(row[1]).ljust(8)[:8]
        abend     = str(row[2]).ljust(4)[:4]
        atype     = str(row[3]).ljust(6)[:6]
        step      = str(row[4]).ljust(8)[:8]
        timestamp = str(row[5]).ljust(19)[:19]
        priority  = str(row[6])
        status    = str(row[7]).ljust(11)[:11]
        
        line = f"{inc_id},{job_name},{abend},{atype},{step},{timestamp},{priority},{status}"
        f.write(line + '\n')

print(f"Exported {len(rows)} incidents to {CSV_PATH}")

