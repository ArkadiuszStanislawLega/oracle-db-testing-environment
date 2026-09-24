terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# Ulotny koszyk na testowe backupy
resource "aws_s3_bucket" "oracle_test_backups" {
  bucket        = "oracle-test-backups-terraform-asm" 
  force_destroy = true
}

# ================= IAM =================
resource "aws_iam_role" "ec2_s3_role_asm" {
  name = "oracle_ec2_s3_role_asm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_access_policy_asm" {
  name = "oracle_s3_access_policy_asm"
  role = aws_iam_role.ec2_s3_role_asm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.oracle_test_backups.arn,            
          "${aws_s3_bucket.oracle_test_backups.arn}/*",
          "arn:aws:s3:::oracle-golden-images-terraform",  
          "arn:aws:s3:::oracle-golden-images-terraform/*" 
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_profile_asm" {
  name = "oracle_ec2_s3_profile_asm"
  role = aws_iam_role.ec2_s3_role_asm.name
}
# =======================================

resource "aws_security_group" "oracle_ssh_sg_asm" {
  name        = "oracle_ssh_sg_asm"
  description = "Zezwol na ruch SSH i Oracle z zewnatrz"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Oracle SQL Developer"
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "oracle_db" {
  ami                    = "ami-06a887bca591498b2"
  instance_type          = "r6a.2xlarge"
  key_name               = "oracle" 
  vpc_security_group_ids = [aws_security_group.oracle_ssh_sg_asm.id]
  
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_profile_asm.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Oracle-19c-ASM"
  }
}

# ================= DYSKI =================

resource "aws_ebs_volume" "u01_binaries" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 50
  type              = "gp3"
  tags = {
    Name = "Oracle-LVM-Binaries"
  }
}

resource "aws_volume_attachment" "attach_u01" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.u01_binaries.id
  instance_id = aws_instance.oracle_db.id
}

# --- LVM: Logi i zrzuty zewnetrzne (10GB) ---
resource "aws_ebs_volume" "u02_logs" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = {
    Name = "Oracle-LVM-Logs"
  }
}

resource "aws_volume_attachment" "attach_u02" {
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.u02_logs.id
  instance_id = aws_instance.oracle_db.id
}

# --- ASM: +DATA (4 x 10GB) ---
resource "aws_ebs_volume" "asm_data_1" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = {
    Name = "Oracle-ASM-DATA-1"
  }
}

resource "aws_volume_attachment" "attach_data_1" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.asm_data_1.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_ebs_volume" "asm_data_2" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = {
    Name = "Oracle-ASM-DATA-2"
  }
}

resource "aws_volume_attachment" "attach_data_2" {
  device_name = "/dev/sdi"
  volume_id   = aws_ebs_volume.asm_data_2.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_ebs_volume" "asm_data_3" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = {
    Name = "Oracle-ASM-DATA-3"
  }
}

resource "aws_volume_attachment" "attach_data_3" {
  device_name = "/dev/sdj"
  volume_id   = aws_ebs_volume.asm_data_3.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_ebs_volume" "asm_data_4" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = {
    Name = "Oracle-ASM-DATA-4"
  }
}

resource "aws_volume_attachment" "attach_data_4" {
  device_name = "/dev/sdk"
  volume_id   = aws_ebs_volume.asm_data_4.id
  instance_id = aws_instance.oracle_db.id
}

# --- ASM: +RECOVERY (2 x 5GB) ---
resource "aws_ebs_volume" "asm_rec_1" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 5
  type              = "gp3"
  tags = {
    Name = "Oracle-ASM-REC-1"
  }
}

resource "aws_volume_attachment" "attach_rec_1" {
  device_name = "/dev/sdl"
  volume_id   = aws_ebs_volume.asm_rec_1.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_ebs_volume" "asm_rec_2" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 5
  type              = "gp3"
  tags = {
    Name = "Oracle-ASM-REC-2"
  }
}

resource "aws_volume_attachment" "attach_rec_2" {
  device_name = "/dev/sdm"
  volume_id   = aws_ebs_volume.asm_rec_2.id
  instance_id = aws_instance.oracle_db.id
}
