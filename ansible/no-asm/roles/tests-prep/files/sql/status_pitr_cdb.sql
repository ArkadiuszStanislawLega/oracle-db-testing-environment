WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
SET DEFINE OFF SQLBLANKLINES ON VERIFY OFF FEEDBACK OFF PAGESIZE 100 LINESIZE 180 TRIMSPOOL ON

ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT === 1. MULTITENANT PITR CANARY TOPOLOGY STATUS ===
COLUMN con_id FORMAT 999 HEADING "ID"
COLUMN pdb_name FORMAT A12 HEADING "PDB_NAME"
COLUMN open_mode FORMAT A12 HEADING "OPEN_MODE"
COLUMN ts_name FORMAT A16 HEADING "TABLESPACE"
COLUMN mb_size FORMAT 99999 HEADING "SIZE_MB"
COLUMN tab_status FORMAT A12 HEADING "LEDGER_TAB"
COLUMN file_name FORMAT A58 HEADING "DATAFILE_PATH"

SELECT p.con_id,
       p.name AS pdb_name,
       p.open_mode,
       NVL(df.tablespace_name, 'MISSING') AS ts_name,
       NVL(ROUND(df.bytes / 1048576), 0) AS mb_size,
       NVL(t.status, 'MISSING') AS tab_status,
       NVL(df.file_name, 'NONE') AS file_name
  FROM v$pdbs p
  LEFT JOIN cdb_data_files df
    ON p.con_id = df.con_id
   AND df.tablespace_name = 'TS_PITR_CANARY'
  LEFT JOIN cdb_tables t
    ON p.con_id = t.con_id
   AND t.owner = 'SYSTEM'
   AND t.table_name = 'PITR_CANARY_LEDGER'
 WHERE p.con_id > 2
 ORDER BY p.con_id;

PROMPT
PROMPT === 2. ONLINE REDO LOG GROUPS AND MULTIPLEXING STATUS ===
COLUMN group# FORMAT 999 HEADING "GRP"
COLUMN thread# FORMAT 999 HEADING "THR"
COLUMN sequence# FORMAT 999999 HEADING "SEQ#"
COLUMN redo_mb FORMAT 99999 HEADING "SIZE_MB"
COLUMN members FORMAT 999 HEADING "MEM"
COLUMN status FORMAT A12 HEADING "STATUS"
COLUMN member_paths FORMAT A85 HEADING "REDO_MEMBER_PATHS"

SELECT l.group#,
       l.thread#,
       l.sequence#,
       ROUND(l.bytes / 1048576) AS redo_mb,
       l.members,
       l.status,
       LISTAGG(f.member, ' | ') WITHIN GROUP (ORDER BY f.member) AS member_paths
  FROM v$log l
  JOIN v$logfile f ON l.group# = f.group#
 GROUP BY l.group#, l.thread#, l.sequence#, l.bytes, l.members, l.status
 ORDER BY l.group#;

EXIT SUCCESS;
