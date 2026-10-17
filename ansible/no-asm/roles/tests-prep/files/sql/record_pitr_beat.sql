WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
SET SQLBLANKLINES ON VERIFY OFF FEEDBACK OFF HEADING OFF PAGESIZE 0 LINESIZE 300 TRIMSPOOL ON SERVEROUTPUT ON

ALTER SESSION SET CONTAINER = &1;
ALTER SESSION SET commit_logging = IMMEDIATE;
ALTER SESSION SET commit_wait = WAIT;

DECLARE
    v_prev_seq  NUMBER := 0;
    v_prev_hash VARCHAR2(64 BYTE) := 'GENESIS_BLOCK_00000000000000000000000000000000000000000000000000';
    v_seq       NUMBER;
    v_now_utc   TIMESTAMP(0);
    v_utc_str   VARCHAR2(30 BYTE);
    v_scn       NUMBER;
    v_pdb_name  VARCHAR2(30 BYTE);
    v_curr_hash VARCHAR2(64 BYTE);
BEGIN
    LOCK TABLE system.pitr_canary_ledger IN EXCLUSIVE MODE;

    SELECT NVL(MAX(seq_id), 0) INTO v_prev_seq FROM system.pitr_canary_ledger;
    IF v_prev_seq > 0 THEN
        SELECT curr_hash INTO v_prev_hash FROM system.pitr_canary_ledger WHERE seq_id = v_prev_seq;
    END IF;

    v_seq      := v_prev_seq + 1;
    v_utc_str  := TO_CHAR(SYS_EXTRACT_UTC(SYSTIMESTAMP), 'YYYY-MM-DD HH24:MI:SS');
    v_now_utc  := TO_TIMESTAMP(v_utc_str, 'YYYY-MM-DD HH24:MI:SS');
    v_scn      := dbms_flashback.get_system_change_number;
    v_pdb_name := sys_context('USERENV', 'CON_NAME');

    SELECT RAWTOHEX(standard_hash(v_prev_hash || ':' || v_seq || ':' || v_pdb_name || ':' || v_utc_str, 'SHA256'))
      INTO v_curr_hash
      FROM dual;

    INSERT INTO system.pitr_canary_ledger (
        seq_id, pdb_name, beat_utc, recorded_scn, prev_hash, curr_hash, io_payload
    ) VALUES (
        v_seq, v_pdb_name, v_now_utc, v_scn, v_prev_hash, v_curr_hash,
        RPAD('PITR_BLOCK_CHURN_' || v_curr_hash, 4000, 'X')
    );

    COMMIT;

    dbms_output.put_line('BEAT_OK|' || v_pdb_name || '|SEQ=' || v_seq || '|UTC=' || v_utc_str || '|SCN=' || v_scn || '|SHA256=' || v_curr_hash);
END;
/

EXIT SUCCESS;
