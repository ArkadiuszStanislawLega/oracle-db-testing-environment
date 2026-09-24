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
#Ulotny koszyk na testowe backupy (znika przy destroy)
resource "aws_s3_bucket" "oracle_test_backups" {
  bucket        = "oracle-test-backups-terraform" 
  force_destroy = true
}

# ================= IAM =================
resource "aws_iam_role" "ec2_s3_role" {
  name = "oracle_ec2_s3_role"
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

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "oracle_s3_access_policy"
  role = aws_iam_role.ec2_s3_role.id
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

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "oracle_ec2_s3_profile"
  role = aws_iam_role.ec2_s3_role.name
}
# =======================================

resource "aws_security_group" "oracle_ssh_sg" {
  name        = "oracle_ssh_sg"
  description = "Zezwol na ruch SSH i Oracle z zewnatrz"

  # Reguła dla SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NOWA reguła dla SQL Developera / Oracle Net Listener
  ingress {
    description = "Oracle SQL Developer"
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Podmień na swoje IP dla większego bezpieczeństwa
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "oracle_db" {
  ami           = "ami-0ed4536c42a475e85"
  instance_type = "r6a.2xlarge"
  key_name      = "oracle" 
  vpc_security_group_ids = [aws_security_group.oracle_ssh_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Oracle-19c-NonASM"
  }
}

resource "aws_ebs_volume" "u01_binaries" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 50
  type              = "gp3"
  tags = { Name = "Oracle-u01-Binaries" }
}

resource "aws_ebs_volume" "u02_pdb1" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = { Name = "Oracle-u02-pdb1" }
}

resource "aws_ebs_volume" "u03_pdb2" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = { Name = "Oracle-u03-pdb1" }
}

resource "aws_ebs_volume" "u04_pdb3" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = { Name = "Oracle-u04-pdb3" }
}

resource "aws_ebs_volume" "u05_fra" {
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = 10
  type              = "gp3"
  tags = { Name = "Oracle-u05-FRA" }
}

resource "aws_volume_attachment" "attach_u01" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.u01_binaries.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_volume_attachment" "attach_u02" {
  device_name = "/dev/sdc"
  volume_id   = aws_ebs_volume.u02_pdb1.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_volume_attachment" "attach_u03" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.u03_pdb2.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_volume_attachment" "attach_u04" {
  device_name = "/dev/sde"
  volume_id   = aws_ebs_volume.u04_pdb3.id
  instance_id = aws_instance.oracle_db.id
}

resource "aws_volume_attachment" "attach_u05" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.u05_fra.id
  instance_id = aws_instance.oracle_db.id
}

