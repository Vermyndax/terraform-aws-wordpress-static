# terraform-aws-wordpress-static

Copyright 2019 by Jason Miller (jmiller@red-abstract.com)

Terraform module that deploys a Wordpress installation complete with a static plugin and S3 bucket + CloudFront. The users can use the official Wordpress app to write posts and a CodePipeline/CodeBuild job will export to a static site.

The CodePipeline/CodeBuild job will run, by default, every 12 hours. This can overriden with a variable (see later in the documentation). It can also be manually executed.
