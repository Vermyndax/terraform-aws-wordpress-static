# Terraform module to set up a self-contained Wordpress installation and a full S3 publishing pipeline. See README.md for usage.
# Author: Jason Miller (jmiller@red-abstract.com)

# TODO: Add CloudWatch rule to automatically trigger build
# TODO: Encrypt boot volume on the EC2 instance
# TODO: Encrypt the EFS share
# TODO: Add method/code to manually trigger build (API gateway?)
# TODO: Add more parameterization to CloudFront
# TODO: Add lifecycle policies to S3 buckets
# TODO: Implement tagging module and rolling the tags down

terraform {
  required_version = ">= 0.12.2" # Looks like some interpolation requires 0.12. Sorry. Heh.
}

locals {
  name_prefix        = "${var.name_prefix != "" ? var.name_prefix : var.deployment_name}"
  site_tld_shortname = "${replace(var.site_tld, ".", "")}"
}

data "aws_ami" "latest_ubuntu_1804" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# S3 bucket for website, public hosting
resource "aws_s3_bucket" "main_site" {
  bucket = "${var.site_tld}"
  region = "${var.site_region}"

  policy = <<EOF
{
  "Id": "bucket_policy_site",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "s3_bucket_policy_website",
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${var.site_tld}/*",
      "Principal": {
          "AWS":"*"
        },
      "Condition": {
        "StringEquals": {
          "aws:UserAgent": "${var.site_secret}"
        }
      }
    }
  ]
}
EOF

  website {
    index_document = "${var.root_page_object}"
    error_document = "${var.error_page_object}"
  }

  # tags {
  # }
  # force_destroy = true
}

# S3 bucket for www redirect (optional)
resource "aws_s3_bucket" "site_www_redirect" {
  count = "${var.create_www_redirect_bucket == "true" ? 1 : 0}"
  bucket = "www.${var.site_tld}"
  region = "${var.site_region}"
  acl = "private"

  website {
    redirect_all_requests_to = "${var.site_tld}"
  }

  tags = {
    Website-redirect = "${var.site_tld}"
  }
}

# S3 bucket for website artifacts
resource "aws_s3_bucket" "site_artifacts" {
  bucket = "${var.site_tld}-code-artifacts"
  region = "${var.site_region}"
  acl = "private"

  tags = {
    Website-artifacts = "${var.site_tld}"
  }
}

# S3 bucket for CloudFront logging
resource "aws_s3_bucket" "site_cloudfront_logs" {
  bucket = "${var.site_tld}-cloudfront-logs"
  region = "${var.site_region}"
  acl = "private"
}

# Should give a parameter to create
# CloudFront should accept a parameter for S3 logging bucket and if it doesn't exist, then create one

# IAM roles for CodeCommit/CodeDeploy
resource "aws_iam_role" "codepipeline_iam_role" {
  name_prefix = "${local.name_prefix}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name_prefix = "${local.name_prefix}"
  role        = "${aws_iam_role.codepipeline_iam_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "codecommit:*"
      ],
      "Resource": [
        "${aws_s3_bucket.site_artifacts.arn}",
        "${aws_s3_bucket.site_artifacts.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codecommit:ListRepositories"
      ],
      "Resource": "*"
    },
    {
      "Action": [
        "kms:DescribeKey",
        "kms:GenerateDataKey*",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:Decrypt"
      ],
      "Resource": "${aws_kms_key.codepipeline_kms_key.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.sns_topic.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role" "wordpress_server_iam_role" {
  name_prefix = "${local.name_prefix}"
  path = "/"

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

resource "aws_iam_instance_profile" "wordpress_server_iam_instance_profile" {
  name_prefix = "${local.name_prefix}"
  role        = "${aws_iam_role.wordpress_server_iam_role.name}"
}

# resource "aws_instance" "wordpress_server" {
#   name_prefix = "${local.name_prefix}"
# }

resource "aws_security_group" "wordpress_security_group" {
  name_prefix = "${local.name_prefix}"
  # TODO: Respect the ingress rules in variables
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_efs_file_system" "wordpress_efs_share" {
#   name_prefix = "${local.name_prefix}"
# }

# resource "aws_efs_mount_target" "wordpress_mount_target" {
#   name_prefix = "${local.name_prefix}"
# }

resource "aws_elb" "wordpress_elb" {
  name_prefix                 = "${local.name_prefix}"
  security_groups             = ["${aws_security_group.wordpress_security_group.id}"]
  availability_zones          = ["${var.availability_zone_1}", "${var.availability_zone_2}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:80/"
  }
  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = "80"
    instance_protocol  = "http"
    ssl_certificate_id = "${var.acm_site_certificate_arn}"
  }
}

resource "aws_launch_template" "wordpress_launch_template" {
  name_prefix   = "${local.name_prefix}"
  image_id      = "${data.aws_ami.latest_ubuntu_1804.id}"
  instance_type = "${var.wordpress_instance_type}"
  # TODO: Add automation to install Wordpress
  user_data = <<EOF
#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
EOF
}

resource "aws_autoscaling_group" "wordpress_autoscaling_group" {
  name_prefix = "${local.name_prefix}"
  min_size = "1"
  max_size = "1"
  launch_template = "${aws_launch_template.wordpress_launch_template.id}"
  load_balancers = ["${aws_elb.wordpress_elb.name}"]
  availability_zones = ["${var.availability_zone_1}", "${var.availability_zone_2}"]
}

resource "aws_kms_key" "codepipeline_kms_key" {
  name_prefix = "${local.name_prefix}"
  count = "${var.codepipeline_kms_key_arn == "" ? 1 : 0}"
  description = "KMS key to encrypt CodePipeline and S3 artifact bucket at rest for ${var.site_tld}"
  deletion_window_in_days = 30
  enable_key_rotation = "true"
}

resource "aws_kms_alias" "codepipeline_kms_key_name" {
  count = "${var.codepipeline_kms_key_arn == "" ? 1 : 0}"
  name = "alias/codepipeline-${local.site_tld_shortname}"
  target_key_id = "${aws_kms_key.codepipeline_kms_key.key_id}"
}

# CodeBuild IAM Permissions
resource "aws_iam_role" "codebuild_assume_role" {
  name_prefix = "${local.name_prefix}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name_prefix = "${local.name_prefix}"
  role        = "${aws_iam_role.codebuild_assume_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
       "s3:PutObject",
       "s3:GetObject",
       "s3:GetObjectVersion",
       "s3:GetBucketVersioning"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
          "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.site_artifacts.arn}",
        "${aws_s3_bucket.site_artifacts.arn}/*",
        "${aws_s3_bucket.main_site.arn}",
        "${aws_s3_bucket.main_site.arn}/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "codebuild:*"
      ],
      "Resource": [
        "${aws_codebuild_project.build_project.id}"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "kms:DescribeKey",
        "kms:GenerateDataKey*",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:Decrypt"
      ],
      "Resource": "${aws_kms_key.codepipeline_kms_key.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.sns_topic.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "cloudfront:CreateInvalidation"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "build_project" {
  name_prefix = "${local.name_prefix}"
  description = "The CodeBuild build project for ${local.site_codecommit_repo_name}"
  service_role = "${aws_iam_role.codebuild_assume_role.arn}"
  build_timeout = "${var.build_timeout}"
  encryption_key = "${aws_kms_key.codepipeline_kms_key.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "${var.build_compute_type}"
    image = "${var.build_image}"
    type = "LINUX_CONTAINER"
    privileged_mode = "${var.build_privileged_override}"
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "${var.package_buildspec}"
  }
}

resource "aws_codebuild_project" "test_project" {
  name_prefix = "${local.name_prefix}"
  description = "The CodeBuild test project for ${local.site_codecommit_repo_name}"
  service_role = "${aws_iam_role.codebuild_assume_role.arn}"
  build_timeout = "${var.build_timeout}"
  encryption_key = "${aws_kms_key.codepipeline_kms_key.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "${var.test_compute_type}"
    image = "${var.test_image}"
    type = "LINUX_CONTAINER"
    privileged_mode = "${var.build_privileged_override}"
  }

  source {
    type = "CODEPIPELINE"
    # TODO: This buildspec should be static instead of using a filename variable
    buildspec = "${var.test_buildspec}"
  }
}

# CodePipeline for deployment from CodeCommit to public site
# Stages are configured in the CodePipeline object below. Add stages and referring CodeBuild projects above as necessary. Note that by default, the test stage is commented out, today.
resource "aws_codepipeline" "site_codepipeline" {
  name_prefix = "${local.name_prefix}"
  role_arn = "${aws_iam_role.codepipeline_iam_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.site_artifacts.bucket}"
    type = "S3"

    encryption_key {
      id = "${aws_kms_alias.codepipeline_kms_key_name.arn}"
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    # TODO: No source stage required here on this one?
    action {
      name = "Source"
      category = "Source"
      owner = "AWS"
      provider = "CodeCommit"
      version = "1"
      output_artifacts = ["${local.site_tld_shortname}-artifacts"]

      configuration {
        RepositoryName = "${local.site_codecommit_repo_name}"
        BranchName = "master"
      }
    }
  }

  stage {
    name = "Test"

    action {
      name = "Test"
      category = "Test"
      owner = "AWS"
      provider = "CodeBuild"
      input_artifacts = ["${local.site_tld_shortname}-artifacts"]
      output_artifacts = ["${local.site_tld_shortname}-tested"]
      version = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.test_project.name}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      input_artifacts = ["${local.site_tld_shortname}-tested"]
      output_artifacts = ["${local.site_tld_shortname}-build"]
      version = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.build_project.name}"
      }
    }
  }
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "site_cloudfront_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.main_site.website_endpoint}"
    origin_id = "origin-bucket-${var.site_tld}"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port = "80"
      https_port = "443"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    custom_header {
      name = "User-Agent"
      value = "${var.site_secret}"
    }
  }

  logging_config = {
    include_cookies = "${var.log_include_cookies}"
    bucket = "${aws_s3_bucket.site_cloudfront_logs.bucket_domain_name}"
    prefix = "${local.site_tld_shortname}-"
  }

  enabled = true
  default_root_object = "${var.root_page_object}"
  aliases = ["${var.site_tld}", "www.${var.site_tld}"]
  price_class = "${var.cloudfront_price_class}"
  retain_on_delete = true

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "origin-bucket-${var.site_tld}"

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress = true
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  viewer_certificate {
    acm_certificate_arn = "${var.acm_site_certificate_arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# SNS to support notifications for commit and build events
resource "aws_sns_topic" "sns_topic" {
  count = "${var.create_sns_topic == "true" ? 1 : 0}"
  name_prefix = "${local.name_prefix}"

  # kms_master_key_id = "alias/codepipeline-${local.site_tld_shortname}"
}

# SNS notifications for pipeline
resource "aws_cloudwatch_event_rule" "pipeline_events" {
  name_prefix = "${local.name_prefix}"
  description = "Alert on ${aws_codepipeline.site_codepipeline.name} events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codepipeline"
  ],
  "detail-type": [
    "CodePipeline Pipeline Execution State Change"
  ],
  "detail": {
    "pipeline": [
      "${aws_codepipeline.site_codepipeline.name}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = "${aws_cloudwatch_event_rule.pipeline_events.name}"
  target_id = "SendToSNS"
  arn       = "${aws_sns_topic.sns_topic.arn}"
}

resource "aws_sns_topic_policy" "default_sns_policy" {
  arn    = "${aws_sns_topic.sns_topic.arn}"
  policy = "${data.aws_iam_policy_document.sns_topic_policy.json}"
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = ["${aws_sns_topic.sns_topic.arn}"]
  }
}

# DNS entry pointing to public site - optional

resource "aws_route53_zone" "primary_site_tld" {
  count = "${var.create_public_dns_zone == "true" ? 1 : 0}"
  name  = "${var.site_tld}"
}

data "aws_route53_zone" "site_tld_selected" {
  name = "${var.site_tld}."
}

resource "aws_route53_record" "site_tld_record" {
  count   = "${var.create_public_dns_site_record == "true" ? 1 : 0}"
  zone_id = "${data.aws_route53_zone.site_tld_selected.zone_id}"
  name    = "${var.site_tld}."
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.site_cloudfront_distribution.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.site_cloudfront_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_www_record" {
  count   = "${var.create_public_dns_www_record == "true" ? 1 : 0}"
  zone_id = "${data.aws_route53_zone.site_tld_selected.zone_id}"
  name    = "www"
  type    = "CNAME"
  ttl     = "5"

  records = ["${var.site_tld}"]
}
