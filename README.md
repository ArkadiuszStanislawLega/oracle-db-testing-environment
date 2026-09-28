# oracle-db-testing-environment

Test automation for Oracle databases 19c on AWS – CDB + ASM + S3.

Setting up the infrastructure for Oracle database testing involves creating an S3 bucket for backups and an S3 bucket for installation and recovery files (including test data files).

When the infrastructure is deleted, the backup bucket is removed, whereas the bucket containing installation files remains. If it is no longer needed, you must delete it manually via the AWS Console.

# The Ansible files execute tasks for the complete configuration of the environment:
- creating LVM,
- creating users,
- creating directories,
- installing Grid,
- configuring Grid,
- installing and configuring the database,
- configuring logs,
- configuring RMAN.

# Order of operations
- terraform S3
- terraform ASM or NO-ASM
- Ansible ASM/01 or NO-ASM/01
- connect and start testing via ssh to host, or sqldeveloper 

# ASM 

## Structure 

- u01 - binaries 
- u02 - logs 
- u03 - s3 backup 
- +DATA - 4 disks
- +RECOVERY - 2 disks

# NO-ASM

## Structure 

- u01 - binaries
- u02 - logs + CDB files
- u03 - s3 backup 
- u04 - mirrors 
- u05 - pdb1 
- u06 - pdb2 
- u07 - pdb3 

Ansible using example
```shell
ansible-playbook  -i "{ip-address}," -u ec2-user --private-key ~/oracle.pem 01_os_setup.yml
```

