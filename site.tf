#########################################################
          ######VARIABLES###########
########################################################

variable "aws_access_key_id" {
  type = "string"
}
variable "aws_secret_access_key" {
  type = "string"
}
variable "REGION" {
  type = "string"
  default = "ap-south-1"
}
variable "AMI" {
  type = "string"
  default = "ami-b46f48db"
}
variable "KEYNAME" {
  type = "string"
  default = "bharath-coreos"
}
variable "AZ" {
  type = "string"
  default = "ap-south-1a"
}

variable "bucket_name" {
  type = "string"
}



######################################################################################

provider "aws" {
  access_key = "${var.aws_access_key_id}",
  secret_key = "${var.aws_secret_access_key}",
  region = "${var.REGION}"
}




data "template_file" "user_data" {
  template = <<EOC
#!/bin/bash
var=$(curl http://169.254.169.254/latest/meta-data/hostname)
echo "PUBLIC IP = $(curl http://169.254.169.254/latest/meta-data/public-ipv4)" >> $var
echo "INSTANCE ID = $(curl http://169.254.169.254/latest/meta-data/instance-id)" >> $var
echo "HOSTNAME = $(curl http://169.254.169.254/latest/meta-data/hostname)" >> $var
echo "LOCAL IP = $(curl http://169.254.169.254/latest/meta-data/local-ipv4)" >> $var
aws s3 cp $var s3://$${BUCKET}/
EOC
  vars {
    BUCKET = "${var.bucket_name}"
  }

}


resource "aws_launch_template" "infra-launch" {
  name_prefix = "infra-launch"
  image_id = "${var.AMI}"
  instance_type = "t2.micro"
  key_name  = "${var.KEYNAME}"
  iam_instance_profile = {
    name = "${aws_iam_instance_profile.ec2_instance_profile.id}"
  }
  user_data = "${base64encode(data.template_file.user_data.rendered)}"
}

resource "aws_autoscaling_group" "infra-auto" {
  availability_zones = ["${var.AZ}"]
  desired_capacity = 1
  max_size = 1
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "EC2"
  launch_template = {
    id = "${aws_launch_template.infra-launch.id}"
    version = "$$Latest"
  }
}

resource "aws_s3_bucket" "infra-bucket" {
  bucket = "${var.bucket_name}"
  acl    = "private"

  tags {
    Name        = "Infra Bucket"
  }
}

resource "aws_iam_role" "ec2_iam_role" {
  name = "ec2_iam_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_instance_profile" "ec2_instance_profile" {
	    name = "ec2_instance_profile"
	    role = "ec2_iam_role"
	}


resource "aws_iam_role_policy" "ec2_iam_role_policy" {
  name = "ec2_iam_role_policy"
  role = "${aws_iam_role.ec2_iam_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${var.bucket_name}"]
	    },
      {
	      "Effect": "Allow",
	      "Action": [
	        "s3:PutObject",
	        "s3:GetObject",
          "s3:DeleteObject"
	      ],
	      "Resource": ["arn:aws:s3:::${var.bucket_name}/*"]
      }
	  ]
	}
EOF
}
