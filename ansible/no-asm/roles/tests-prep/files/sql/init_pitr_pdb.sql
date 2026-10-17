WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
SET SQLBLANKLINES ON VERIFY OFF FEEDBACK OFF HEADING OFF PAGESIZE 0 LINESIZE 300 TRIMSPOOL ON

ALTER SESSION SET CONTAINER = &1;

DECLARE
    v_ts_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_ts_exists FROM dba_tablespaces WHERE tablespace_name = 'TS_PITR_CANARY';
    IF v_ts_exists = 0 THEN
        EXECUTE IMMEDIATE 'CREATE TABLESPACE ts_pitr_canary DATAFILE ''&2/pitr_canary01.dbf'' SIZE 256M REUSE AUTOEXTEND ON NEXT 64M MAXSIZE 4G';
    END IF;
END;
/

ALTER USER system QUOTA UNLIMITED ON ts_pitr_canary;

DECLARE
    v_tab_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_tab_exists FROM dba_tables WHERE owner = 'SYSTEM' AND table_name = 'PITR_CANARY_LEDGER';
    IF v_tab_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE system.pitr_canary_ledger PURGE';
    END IF;
END;
/

CREATE TABLE system.pitr_canary_ledger (
    seq_id        NUMBER               NOT NULL,
    pdb_name      VARCHAR2(30 BYTE)    NOT NULL,
    beat_utc      TIMESTAMP(0)         NOT NULL,
    recorded_scn  NUMBER               NOT NULL,
    prev_hash     VARCHAR2(64 BYTE)    NOT NULL,
    curr_hash     VARCHAR2(64 BYTE)    NOT NULL,
    io_payload    VARCHAR2(4000 BYTE)  NOT NULL,
    CONSTRAINT pk_pitr_canary PRIMARY KEY (seq_id)
) SEGMENT CREATION IMMEDIATE PCTFREE 10 TABLESPACE ts_pitr_canary;

SELECT 'INIT_OK|' || UPPER('&1')
       || '|TS=' || (SELECT COUNT(*) FROM dba_tablespaces WHERE tablespace_name = 'TS_PITR_CANARY')
       || '|TAB=' || (SELECT COUNT(*) FROM dba_tables WHERE owner = 'SYSTEM' AND table_name = 'PITR_CANARY_LEDGER')
  FROM dual;

EXIT SUCCESS;
