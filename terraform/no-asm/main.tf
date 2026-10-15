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

data "aws_s3_bucket" "golden_images" {
  bucket = "oracle-golden-images-terraform"
}

locals {
  ebs_volumes = {
    u01_binaries = { size = 50, device = "/dev/sdb", tag = "Oracle-u01-Binaries" }
    u02_logs     = { size = 10, device = "/dev/sdc", tag = "Oracle-u02-logs" }
    u03_mirr     = { size = 10, device = "/dev/sdd", tag = "Oracle-u03-mirr" }
    u04_archive  = { size = 20, device = "/dev/sde", tag = "Oracle-u04-archive" }
    u05_pdb1     = { size = 10, device = "/dev/sdf", tag = "Oracle-u04-pdb1" }
    u06_pdb2     = { size = 10, device = "/dev/sdg", tag = "Oracle-u05-pdb2" }
    u07_pdb3     = { size = 10, device = "/dev/sdh", tag = "Oracle-u06-pdb3" }
  }
}

resource "aws_s3_bucket" "oracle_test_backups" {
  bucket              = "oracle-test-backups-terraform"
  force_destroy       = true
  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "oracle_test_backups_versioning" {
  bucket = aws_s3_bucket.oracle_test_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "oracle_test_backups_worm" {
  depends_on = [aws_s3_bucket_versioning.oracle_test_backups_versioning]
  bucket     = aws_s3_bucket.oracle_test_backups.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 1
    }
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "oracle_ec2_s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
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
        Sid    = "ListBothBuckets"
        Action = ["s3:ListBucket"]
        Effect = "Allow"
        Resource = [
          data.aws_s3_bucket.golden_images.arn,
          aws_s3_bucket.oracle_test_backups.arn
        ]
      },
      {
        Sid      = "ReadOnlyGoldenImages"
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.golden_images.arn}/*"]
      },
      {
        Sid      = "ReadWriteWormBackups"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.oracle_test_backups.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "oracle_ec2_s3_profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_security_group" "oracle_ssh_sg" {
  name        = "oracle_ssh_sg"
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
  ami                    = "ami-0ed4536c42a475e85"
  instance_type          = "r6a.2xlarge"
  key_name               = "oracle"
  vpc_security_group_ids = [aws_security_group.oracle_ssh_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_profile.name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "Oracle-19c-NonASM"
  }
}

resource "aws_ebs_volume" "oracle_volumes" {
  for_each          = local.ebs_volumes
  availability_zone = aws_instance.oracle_db.availability_zone
  size              = each.value.size
  type              = "gp3"

  tags = {
    Name = each.value.tag
  }
}

resource "aws_volume_attachment" "oracle_attachments" {
  for_each    = local.ebs_volumes
  device_name = each.value.device
  volume_id   = aws_ebs_volume.oracle_volumes[each.key].id
  instance_id = aws_instance.oracle_db.id
}

output "db_public_ip" {
  value = aws_instance.oracle_db.public_ip
}
