WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
SET SQLBLANKLINES ON VERIFY OFF FEEDBACK OFF PAGESIZE 50 LINESIZE 160 TRIMSPOOL ON

ALTER SESSION SET CONTAINER = &1;

COLUMN seq_id FORMAT 999999 HEADING "SEQ_ID"
COLUMN beat_utc_str FORMAT A20 HEADING "BEAT_UTC"
COLUMN recorded_scn FORMAT 999999999999 HEADING "RECORDED_SCN"
COLUMN prev_short FORMAT A18 HEADING "PREV_HASH (16B)"
COLUMN curr_short FORMAT A18 HEADING "CURR_HASH (16B)"

SELECT seq_id,
       TO_CHAR(beat_utc, 'YYYY-MM-DD HH24:MI:SS') AS beat_utc_str,
       recorded_scn,
       SUBSTR(prev_hash, 1, 16) || '..' AS prev_short,
       SUBSTR(curr_hash, 1, 16) || '..' AS curr_short
  FROM (
       SELECT seq_id, beat_utc, recorded_scn, prev_hash, curr_hash
         FROM system.pitr_canary_ledger
        ORDER BY seq_id DESC
  )
 WHERE ROWNUM <= &2
 ORDER BY seq_id ASC;

EXIT SUCCESS;
