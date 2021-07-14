# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE DEFAULT PROVIDER
# This is the default region to use for resources that deploy to just one region. Note that even though it's the
# default,  ensuring that we explicitly set each provider to exactly what we need, rather than having an implicit one
# get used accidentally. All the providers below this one are region
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
  alias  = "default"
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE A PROVIDER FOR EACH AWS REGION
# To deploy a multi-region service, we have to configure a provider with a unique alias for each of the regions AWS
# supports and pass all these providers to the multi-region module in a provider = { ... } block. You MUST create a
# provider block for EVERY one of these AWS regions, but you should specify the ones to use and authenticate to (the
# ones actually enabled in your AWS account) using var.opt_in_regions.
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = "af-south-1"
  alias  = "af_south_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "af-south-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "af-south-1") ? false : true
}

provider "aws" {
  region = "ap-east-1"
  alias  = "ap_east_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ap-east-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ap-east-1") ? false : true
}

provider "aws" {
  region = "ap-northeast-1"
  alias  = "ap_northeast_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ap-northeast-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ap-northeast-1") ? false : true
}

provider "aws" {
  region = "ap-northeast-2"
  alias  = "ap_northeast_2"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ap-northeast-2") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ap-northeast-2") ? false : true
}

provider "aws" {
  region = "ap-northeast-3"
  alias  = "ap_northeast_3"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ap-northeast-3") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ap-northeast-3") ? false : true
}

provider "aws" {
  region = "ap-south-1"
  alias  = "ap_south_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ap-south-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ap-south-1") ? false : true
}

provider "aws" {
  region = "ap-southeast-1"
  alias  = "ap_southeast_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ap-southeast-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ap-southeast-1") ? false : true
}

provider "aws" {
  region = "ap-southeast-2"
  alias  = "ap_southeast_2"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ap-southeast-2") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ap-southeast-2") ? false : true
}

provider "aws" {
  region = "ca-central-1"
  alias  = "ca_central_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "ca-central-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "ca-central-1") ? false : true
}

provider "aws" {
  region = "cn-north-1"
  alias  = "cn_north_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "cn-north-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "cn-north-1") ? false : true
}

provider "aws" {
  region = "cn-northwest-1"
  alias  = "cn_northwest_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "cn-northwest-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "cn-northwest-1") ? false : true
}

provider "aws" {
  region = "eu-central-1"
  alias  = "eu_central_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "eu-central-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "eu-central-1") ? false : true
}

provider "aws" {
  region = "eu-north-1"
  alias  = "eu_north_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "eu-north-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "eu-north-1") ? false : true
}

provider "aws" {
  region = "eu-south-1"
  alias  = "eu_south_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "eu-south-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "eu-south-1") ? false : true
}

provider "aws" {
  region = "eu-west-1"
  alias  = "eu_west_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "eu-west-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "eu-west-1") ? false : true
}

provider "aws" {
  region = "eu-west-2"
  alias  = "eu_west_2"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "eu-west-2") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "eu-west-2") ? false : true
}

provider "aws" {
  region = "eu-west-3"
  alias  = "eu_west_3"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "eu-west-3") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "eu-west-3") ? false : true
}

provider "aws" {
  region = "me-south-1"
  alias  = "me_south_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "me-south-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "me-south-1") ? false : true
}

provider "aws" {
  region = "sa-east-1"
  alias  = "sa_east_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "sa-east-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "sa-east-1") ? false : true
}

provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "us-east-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "us-east-1") ? false : true
}

provider "aws" {
  region = "us-east-2"
  alias  = "us_east_2"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "us-east-2") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "us-east-2") ? false : true
}

provider "aws" {
  region = "us-gov-east-1"
  alias  = "us_gov_east_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "us-gov-east-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "us-gov-east-1") ? false : true
}

provider "aws" {
  region = "us-gov-west-1"
  alias  = "us_gov_west_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "us-gov-west-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "us-gov-west-1") ? false : true
}

provider "aws" {
  region = "us-west-1"
  alias  = "us_west_1"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "us-west-1") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "us-west-1") ? false : true
}

provider "aws" {
  region = "us-west-2"
  alias  = "us_west_2"

  # Skip credential validation and account ID retrieval for disabled or restricted regions
  skip_credentials_validation = contains(coalesce(var.opt_in_regions, []), "us-west-2") ? false : true
  skip_requesting_account_id  = contains(coalesce(var.opt_in_regions, []), "us-west-2") ? false : true
}