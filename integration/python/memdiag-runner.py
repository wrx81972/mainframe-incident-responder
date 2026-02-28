#!/usr/bin/env python3
"""
memdiag-runner.py - Python wrapper dla modułu Assembler MEMDIAG
Symuluje COBOL CALL 'MEMDIAG' pattern
Czyta memory dumpy z DB2 i uruchamia analizę
"""
import sqlite3
import subprocess
import json

DB_PATH = "data/incidents.db"

def analyze_memory_dumps():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT d.DUMP_ID, d.INC_ID, d.PSW_ADDR, d.FAILING_ADDR, 
               d.REG_DUMP, d.DUMP_SIZE, i.ABEND_CODE, i.JOB_NAME
        FROM MEMORY_DUMPS d
        JOIN INCIDENTS i ON d.INC_ID = i.INC_ID
        WHERE d.ANALYZED = 0
    """)
    
    dumps = cursor.fetchall()
    results = []
    
    for dump in dumps:
        dump_id, inc_id, psw_addr, failing_addr, reg_dump_json, dump_size, abend_code, job_name = dump
        
        print(f"\n{'='*50}")
        print(f"MEMDIAG Analysis - Job: {job_name} | Abend: {abend_code}")
        print(f"Dump ID: {dump_id} | Incident: {inc_id}")
        print(f"PSW at time of abend: 0x{psw_addr}")
        print(f"Failing address:      0x{failing_addr}")
        
        # Parsuj register dump
        if reg_dump_json:
            regs = json.loads(reg_dump_json)
            print("\nRegister dump (z/OS R0-R15 style):")
            for reg, val in regs.items():
                print(f"  {reg}: 0x{val}")
        
        # Analiza abend code
        print(f"\nAnalysis:")
        if abend_code == 'S0C4':
            print("  CAUSE: Protection Exception")
            print(f"  Failing addr 0x{failing_addr} - access violation")
            if failing_addr and int(failing_addr, 16) == 0:
                print("  DIAGNOSIS: NULL pointer dereference (addr=0x0)")
                print("  LIKELY FIX: Check USING statement and base register setup")
            else:
                print("  DIAGNOSIS: Invalid storage access")
                print("  LIKELY FIX: Check pointer arithmetic and MOVE statements")
        elif abend_code == 'S0C7':
            print("  CAUSE: Data Exception")
            print("  DIAGNOSIS: Non-numeric data in numeric field")
            print("  LIKELY FIX: Add MOVE ZEROS before arithmetic, validate input")
        
        cursor.execute("UPDATE MEMORY_DUMPS SET ANALYZED=1 WHERE DUMP_ID=?", (dump_id,))
        results.append({"dump_id": dump_id, "abend": abend_code, "status": "analyzed"})
    
    conn.commit()
    conn.close()
    
    if not dumps:
        print("No unanalyzed memory dumps found.")
    
    return results

if __name__ == "__main__":
    print("MEMDIAG Runner - Memory Dump Analyzer")
    print("Simulating COBOL CALL 'MEMDIAG' pattern\n")
    results = analyze_memory_dumps()
    print(f"\nAnalyzed {len(results)} dump(s)")

