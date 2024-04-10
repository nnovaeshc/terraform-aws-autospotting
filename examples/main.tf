provider "aws" {
  # region = "eu-west-1"
  region = "us-east-1"
}

module "autospotting-test" {
  source      = "../"
  name        = "AutoSpotting"
  environment = "test"


  # when this is commented out AutoSpotting will install regional resources in
  # all regions. After this value is changed, Terraform apply needs to be
  # executed twice because of the way we generate some Terraform code from
  # Terraform itself.
  autospotting_regions_enabled = ["us-east-1", "eu-west-1"]
  # lambda_run_frequency         = "rate(30 minutes)"
  notify_email_addresses = ["cristi@autospotting.io", ]

  # use_existing_subnets =false
  # existing_subnets     = ["subnet-0d125a0ab1947d598", "subnet-0a6f799f15489f759"]
  # use_existing_iam_role = false
  # existing_iam_role_arn = "arn:aws:iam::540659244915:role/custom-manual-created-role-for-autospotting"

  # lambda_use_public_ecr    = true
  # lambda_source_ecr        = "public.ecr.aws"
  # lambda_source_image      = "u1c5s9l5/autospotting"
  lambda_source_image_tag = "stable-1.3.0-0"
  # permissions_boundary_arn = ""
}



# This can be used to install a second instance of AutoSpotting with different
# parameters.

# Be careful when destroying additional modules, you will need to restore
# modules/regional/providers.tf and modules/regional/regional.tf from git
# history, as they are deleted on destroy.

# module "autospotting-dev" {
# source      = "../"
# name        = "AutoSpotting"
# environment = "dev"
# autospotting_regions_enabled = ["us-east-1", "eu-west-1"]
# }

output "regions" {
  value = module.autospotting-test.regions
}
