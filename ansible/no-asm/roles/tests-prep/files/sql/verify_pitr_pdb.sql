WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
SET SQLBLANKLINES ON VERIFY OFF FEEDBACK OFF HEADING OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON

ALTER SESSION SET CONTAINER = &1;

WITH chain_audit AS (
    SELECT
        seq_id,
        beat_utc,
        recorded_scn,
        prev_hash,
        curr_hash,
        LAG(curr_hash, 1, 'GENESIS_BLOCK_00000000000000000000000000000000000000000000000000') OVER (ORDER BY seq_id) AS expected_prev_hash,
        standard_hash(
            LAG(curr_hash, 1, 'GENESIS_BLOCK_00000000000000000000000000000000000000000000000000') OVER (ORDER BY seq_id)
            || ':' || seq_id || ':' || pdb_name || ':' || TO_CHAR(beat_utc, 'YYYY-MM-DD HH24:MI:SS'),
            'SHA256'
        ) AS recalculated_hash
    FROM system.pitr_canary_ledger
)
SELECT
    'AUDIT_RESULT|&1'
    || '|TOTAL_ROWS=' || COUNT(*)
    || '|MAX_SEQ=' || NVL(MAX(seq_id), 0)
    || '|BROKEN_LINKS=' || SUM(CASE WHEN prev_hash != expected_prev_hash OR curr_hash != recalculated_hash THEN 1 ELSE 0 END)
    || '|FUTURE_ROWS=' || SUM(CASE WHEN beat_utc > TO_TIMESTAMP('&2', 'YYYY-MM-DD HH24:MI:SS') THEN 1 ELSE 0 END)
    || '|LAST_UTC=' || NVL(TO_CHAR(MAX(beat_utc), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
    || '|LAST_SCN=' || NVL(MAX(recorded_scn), 0)
    || '|DRIFT_SEC=' || NVL(ROUND((CAST(TO_TIMESTAMP('&2', 'YYYY-MM-DD HH24:MI:SS') AS DATE) - CAST(MAX(beat_utc) AS DATE)) * 86400), 999999)
FROM chain_audit;

EXIT SUCCESS;
