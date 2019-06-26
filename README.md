# terraform-aws-wordpress-static

Terraform module that deploys a Wordpress installation complete with a static plugin and S3 bucket + CloudFront. The users can use the official Wordpress app to write posts and a CodePipeline/CodeBuild job will export to a static site.