terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
	dome9 ={
	  source  = "dome9/dome9"
      version = "~> 1.23.2"
	}
  }

  required_version = ">= 1.0.8"
}

provider "aws" {
  profile = "crs-cs-aws"
  region  = "us-east-1"
}

provider "dome9" {
  dome9_access_id     = "${var.dome9_access_id}"
  dome9_secret_key    = "${var.dome9_secret_key}"
}

resource "random_uuid" "test" {
}



#Create the role and setup the trust policy
resource "aws_iam_role" "dome9" {
  name               = "Dome9-Connect"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::634729597623:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${random_uuid.test.result}"
        }
      }
    }
  ]
}
EOF
}

#Create the readonly policy
resource "aws_iam_policy" "readonly-policy" {
  name        = "Dome9-readonly-policy"
  description = ""
  policy      = "${file("readonly-policy.json")}"
}

#Create the write policy
resource "aws_iam_policy" "write-policy" {
  name        = "Dome9-write-policy"
  description = ""
  policy      = "${file("write-policy.json")}"
}

#Attach 3 policies to the cross-account role
resource "aws_iam_policy_attachment" "attach-d9-read-policy" {
  name       = "attach-readonly"
  roles      = ["${aws_iam_role.dome9.name}"]
  policy_arn = "${aws_iam_policy.readonly-policy.arn}"
}

resource "aws_iam_role_policy_attachment" "attach-security-audit" {
    role       = "${aws_iam_role.dome9.name}"
    policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "attach-inspector-readonly" {
    role       = "${aws_iam_role.dome9.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonInspectorReadOnlyAccess"
}

resource "aws_iam_policy_attachment" "attach-d9-write-policy" {
  name       = "Attach-write"
  roles      = ["${aws_iam_role.dome9.name}"]
  policy_arn = "${aws_iam_policy.write-policy.arn}"
}


resource "dome9_cloudaccount_aws" "test" {
  name  = "crs-cs-aws"

  credentials  {
    arn        = "${aws_iam_role.dome9.arn}"
    secret = "${random_uuid.test.result}"
    type   = "RoleBased"
  }
 }


#Output the role ARN
output "Role_ARN" {
  value = "${aws_iam_role.dome9.arn}"
}

output "External_Id" {
  value = "${random_uuid.test.result}"
}