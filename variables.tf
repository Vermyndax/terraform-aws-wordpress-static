# Creation flags first

variable "site_region" {
  description = "Region in which to provision the site. Default: us-east-1"
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Optional value to prefix names in this deployment. Default is blank, which will then prefix your names with var.deployment_name instead."
  default     = ""
}

variable "wordpress_database_name" {
  description = "Name of the Wordpress database you want. Default: wordpress."
  default     = "wordpress"
}

variable "wordpress_database_username" {
  description = "User name of the Wordpress database. Required."
}

variable "wordpress_database_password" {
  description = "Password for the Wordpress database. Required."
}

variable "wordpress_database_prefix" {
  description = "Prefix for the Wordpress database tables. Default: wp_"
  default     = "wp_"
}

variable "deployment_name" {
  description = "Deployment name that will be used instead of name_prefix. If this is set (default: wordpress-static) then it will be prefixed on all resource names. We suggest you at least add the name of the project or customer here."
  default     = "wordpress-static"
}

variable "create_www_redirect_bucket" {
  description = "Defines whether or not to create a www redirect S3 bucket. Default: true"
  default     = true
}

variable "create_cloudfront_distribution" {
  description = "Defines whether or not to create a CloudFront distribution for the S3 bucket. Default: true."
  default     = true
}

variable "vpc_id" {
  description = "VPC ID to place the instance. Required."
}

variable "subnet_id" {
  description = "Subnet ID to place the instance. Required."
}

variable "availability_zone_1" {
  description = "First AZ."
  default     = "us-east-1c"
}

variable "availability_zone_2" {
  description = "Second AZ."
  default     = "us-east-1e"
}

variable "wordpress_key_pair_name" {
  description = "Name of the key pair to attach to the Wordpress instance. If you set this, it must already exist. If you leave it to the default (blank), Terraform will create a key pair and use it internally, and you won't have to manage it. That's best for everyone. Trust me."
  default     = ""
}

variable "wordpress_instance_type" {
  description = "Instance type for the Wordpress instance. Default: t2.micro"
  default     = "t2.micro"
}

variable "wordpress_security_group_ingress_default_all" {
  description = "Boolean - if set to true, then Wordpress instance will have a default ingress rule of 0.0.0.0/0."
  default     = "true"
}

variable "log_include_cookies" {
  description = "Defines whether or not CloudFront should log cookies. Default: false."
  default     = "false"
}
variable "create_sns_topic" {
  description = "Defines whether or not to create an SNS topic for notifications about events. Default: true."
  default     = "true"
}

variable "elb_subnets" {
  description = "List of subnet IDs to attach to the ELB. Required."
  type        = "list"
}

variable "sns_topic_name" {
  description = "Name for the SNS topic."
  default     = ""
}

variable "site_tld" {
  description = "TLD of the website you want to create. Example: example.com. This will be used for Route53."
}

variable "site_bucket_name" {
  description = "Site bucket name - recomended to use the host TLD of the website... example: www.example.com or test.example.com. Required."
}

variable "site_edit_name" {
  description = "Site name you want to attach to the DNS record for the edit hostname. Required."
}

variable "create_public_dns_zone" {
  description = "If set to true, creates a public hosted zone in Route53 for your site. Default: false."
  default     = "false"
}

variable "efs_subnet_tag_name" {
  description = "What tag name should be used to locate the subnets to create EFS mount targets? Default: Type"
  default     = "Type"
}

variable "efs_subnet_tag_value" {
  description = "What tag value should be used to locate the subnets to create EFS mount targets? Default: Public"
  default     = "Public"
}

variable "create_public_dns_site_record" {
  description = "If set to true, creates a public DNS record in your site_tld hosted zone. If you do not already have a hosted zone for this TLD, you should set create_public_dns_zone to true. Otherwise, this will try to create a record in an existing zone or fail. Default: true."
  default     = "true"
}

variable "create_public_wordpress_record" {
  description = "If set to true, will create a record called *-edit. This is the endpoint for users to access Wordpress to edit articles."
  default     = "true"
}

variable "create_public_dns_www_record" {
  description = "Defines whether or not to create a WWW DNS record for the site. Default: false."
  default     = false
}

variable "site_secret" {
  description = "A secret to be used between S3 and CloudFront to manage web access. This will be put in the bucket policy and CloudFront distribution. Required."
}

variable "codepipeline_kms_key_arn" {
  description = "The ARN of a KMS key to use with the CodePipeline and S3 artifacts bucket. If you do not specify an ARN, we'll create a KMS key for you and use it."
  default     = ""
}

variable "deployer_public_key" {
  description = "Public key for the deployer key pair. Required."
}

variable "build_timeout" {
  description = "Build timeout for the build stage (in minutes). Default: 5"
  default     = "5"
}

variable "build_compute_type" {
  description = "Build instance type to use for the CodeBuild project. Default: BUILD_GENERAL1_SMALL."
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_image" {
  description = "Managed build image for CodeBuild. Default: aws/codebuild/ubuntu-base:14.04"
  default     = "aws/codebuild/ubuntu-base:14.04"
}

variable "test_compute_type" {
  description = "Build instance type to use for the CodeBuild project. Default: BUILD_GENERAL1_SMALL."
  default     = "BUILD_GENERAL1_SMALL"
}

variable "test_image" {
  description = "Managed build image for CodeBuild. Default: aws/codebuild/ubuntu-base:14.04"
  default     = "aws/codebuild/ubuntu-base:14.04"
}

variable "build_privileged_override" {
  description = "Set the build privileged override to 'true' if you are not using a CodeBuild supported Docker base image. This is only relevant to building Docker images."
  default     = "false"
}

variable "root_page_object" {
  description = "The root page object for the Cloudfront/S3 distribution. Default: index.html"
  default     = "index.html"
}

variable "error_page_object" {
  description = "The error page object for the Cloudfront/S3 distribution. Default: 404.html"
  default     = "404.html"
}

variable "cloudfront_price_class" {
  description = "Price class for Cloudfront. Default: PriceClass_100"
  default     = "PriceClass_100"
}

variable "acm_site_certificate_arn" {
  description = "ARN of an ACM certificate to use for https on the CloudFront distribution. Required."
}

variable "static_generation_refresh_time" {
  description = "How often do you want to refresh the site? Default: every 12 hours. Must use cron notation."
  default     = "0 */12 * * *"
}

variable "add_manual_trigger" {
  description = "Boolean to determine whether or not to add code to support running the static refresh manually. Default: true."
  default     = "true"
}
# TODO: Support names for the rest of the resources?
