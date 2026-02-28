#!/usr/bin/env python3
"""
app.py - Mainframe Incident Responder Dashboard
Flask + Plotly web dashboard consuming COBOL-generated JSON
Run: python3 integration/python/app.py
Open: http://localhost:5000
"""
from flask import Flask, render_template, jsonify
import sqlite3
import json
import subprocess
import os

app = Flask(__name__, template_folder='templates')
DB_PATH = "data/incidents.db"

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/api/incidents')
def api_incidents():
    conn = get_db()
    rows = conn.execute("""
        SELECT i.*, j.OWNER, j.CLASS
        FROM INCIDENTS i
        LEFT JOIN JOBS j ON i.JOB_ID = j.JOB_ID
        ORDER BY i.PRIORITY, i.TIMESTAMP DESC
    """).fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])

@app.route('/api/stats')
def api_stats():
    conn = get_db()
    
    abend_counts = conn.execute("""
        SELECT ABEND_CODE, COUNT(*) as count
        FROM INCIDENTS GROUP BY ABEND_CODE ORDER BY count DESC
    """).fetchall()
    
    priority_counts = conn.execute("""
        SELECT PRIORITY, COUNT(*) as count
        FROM INCIDENTS GROUP BY PRIORITY
    """).fetchall()
    
    status_counts = conn.execute("""
        SELECT STATUS, COUNT(*) as count
        FROM INCIDENTS GROUP BY STATUS
    """).fetchall()
    
    timeline = conn.execute("""
        SELECT substr(TIMESTAMP,1,10) as date, COUNT(*) as count
        FROM INCIDENTS
        GROUP BY date ORDER BY date
    """).fetchall()
    
    conn.close()
    return jsonify({
        "abend_counts": [dict(r) for r in abend_counts],
        "priority_counts": [dict(r) for r in priority_counts],
        "status_counts": [dict(r) for r in status_counts],
        "timeline": [dict(r) for r in timeline]
    })

@app.route('/api/playbook')
def api_playbook():
    conn = get_db()
    rows = conn.execute("SELECT * FROM RESOLUTIONS").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])

@app.route('/api/run-analyzer', methods=['POST'])
def run_analyzer():
    """Trigger COBOL analyzer pipeline"""
    try:
        subprocess.run(['python3', 'integration/python/export-db.py'], check=True)
        result = subprocess.run(['./incident-analyzer'], capture_output=True, text=True)
        return jsonify({"status": "ok", "output": result.stdout})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

