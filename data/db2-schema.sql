-- ============================================================
-- MAINFRAME INCIDENT RESPONDER - DB2 Schema
-- Compatible with: IBM DB2 for z/OS, SQLite (local dev)
-- ============================================================

-- Tabela jobów mainframe (odpowiednik procesów)
CREATE TABLE IF NOT EXISTS JOBS (
    JOB_NAME    TEXT        NOT NULL,     -- Nazwa joba (max 8 znaków - standard MVS)
    JOB_ID      TEXT        PRIMARY KEY,  -- ID joba np. JOB00142
    OWNER       TEXT        NOT NULL,     -- Użytkownik TSO który submitował
    CLASS       TEXT        DEFAULT 'A',  -- Klasa joba (kolejka: A=batch, B=test)
    STATUS      TEXT        DEFAULT 'ACTIVE',
    SUBMIT_TIME TEXT        NOT NULL,
    END_TIME    TEXT
);

-- Tabela incydentów (abendów i błędów)
CREATE TABLE IF NOT EXISTS INCIDENTS (
    INC_ID      INTEGER     PRIMARY KEY AUTOINCREMENT,
    JOB_NAME    TEXT        NOT NULL,
    JOB_ID      TEXT        REFERENCES JOBS(JOB_ID),
    ABEND_CODE  TEXT        NOT NULL,     -- np. S0C4, S0C7, S322, B37
    ABEND_TYPE  TEXT        NOT NULL,     -- SYSTEM lub USER
    STEP_NAME   TEXT,                     -- Krok JCL w którym nastąpił abend
    TIMESTAMP   TEXT        NOT NULL,
    PRIORITY    INTEGER     DEFAULT 3,    -- 1=Krytyczny, 2=Wysoki, 3=Normalny, 4=Niski
    STATUS      TEXT        DEFAULT 'OPEN',   -- OPEN/IN_PROGRESS/RESOLVED
    NOTES       TEXT
);

-- Tabela memory dumpów (do modułu Assembler)
CREATE TABLE IF NOT EXISTS MEMORY_DUMPS (
    DUMP_ID     INTEGER     PRIMARY KEY AUTOINCREMENT,
    INC_ID      INTEGER     REFERENCES INCIDENTS(INC_ID),
    DUMP_TYPE   TEXT        NOT NULL,     -- ABEND/SNAP/SYSMDUMP
    PSW_ADDR    TEXT,                     -- Adres PSW w momencie abend (hex)
    FAILING_ADDR TEXT,                    -- Adres który spowodował S0C4
    REG_DUMP    TEXT,                     -- Zrzut rejestrów R0-R15 (JSON)
    DUMP_SIZE   INTEGER,                  -- Rozmiar dumpa w KB
    ANALYZED    INTEGER     DEFAULT 0,    -- 0=nie/1=tak
    CREATED_AT  TEXT        NOT NULL
);

-- Tabela rozwiązań (playbook)
CREATE TABLE IF NOT EXISTS RESOLUTIONS (
    RES_ID      INTEGER     PRIMARY KEY AUTOINCREMENT,
    ABEND_CODE  TEXT        NOT NULL,
    CAUSE       TEXT        NOT NULL,
    SOLUTION    TEXT        NOT NULL,
    REFERENCE   TEXT        -- IBM dokumentacja, np. "IEA194I"
);

