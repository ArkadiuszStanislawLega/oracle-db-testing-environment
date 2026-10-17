WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
SET DEFINE OFF SQLBLANKLINES ON VERIFY OFF FEEDBACK OFF HEADING OFF PAGESIZE 0 LINESIZE 300 TRIMSPOOL ON SERVEROUTPUT ON

ALTER SESSION SET CONTAINER = CDB$ROOT;

DECLARE
    c_target_bytes CONSTANT NUMBER := 512 * 1048576;
    c_primary_dir  CONSTANT VARCHAR2(128 BYTE) := '/u02/oradata/TESTCDB';
    c_mirror_dir   CONSTANT VARCHAR2(128 BYTE) := '/u03/oradata/TESTCDB';
    v_exists       NUMBER;
    v_status       VARCHAR2(30 BYTE);
    v_bytes        NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists FROM v$log WHERE group# = 4;
    IF v_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER DATABASE ADD LOGFILE GROUP 4 ('''
            || c_primary_dir || '/redo04.log'', '''
            || c_mirror_dir  || '/redo04_mirror.log'') SIZE 512M REUSE';
    END IF;

    FOR r_grp IN (SELECT group# FROM v$log ORDER BY group#) LOOP
        SELECT status, bytes INTO v_status, v_bytes FROM v$log WHERE group# = r_grp.group#;

        IF v_bytes < c_target_bytes THEN
            WHILE v_status IN ('CURRENT', 'ACTIVE') LOOP
                IF v_status = 'CURRENT' THEN
                    EXECUTE IMMEDIATE 'ALTER SYSTEM SWITCH LOGFILE';
                END IF;
                EXECUTE IMMEDIATE 'ALTER SYSTEM CHECKPOINT';
                SELECT status INTO v_status FROM v$log WHERE group# = r_grp.group#;
            END LOOP;

            EXECUTE IMMEDIATE 'ALTER DATABASE DROP LOGFILE GROUP ' || r_grp.group#;

            EXECUTE IMMEDIATE 'ALTER DATABASE ADD LOGFILE GROUP ' || r_grp.group# || ' ('''
                || c_primary_dir || '/redo0' || r_grp.group# || '.log'', '''
                || c_mirror_dir  || '/redo0' || r_grp.group# || '_mirror.log'') SIZE 512M REUSE';
        END IF;
    END LOOP;

    dbms_output.put_line('REDO_RESIZE_OK|GROUPS=4|SIZE_MB=512');
END;
/

EXIT SUCCESS;
