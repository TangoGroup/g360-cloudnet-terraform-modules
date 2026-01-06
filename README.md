# g360-cloudnet-terraform-modules
Public repository containing boilerplate terraform modules used to create AWS and other cloud resources.

## Usage
Example usage of the VPC module.
module "vpc" {
  source = "github.com/TangoGroup/g360-cloudnet-terraform-modules//aws/vpc?ref=1.0.0"

  tags = local.tags

  other_options...
}