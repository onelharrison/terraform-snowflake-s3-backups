terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    snowflake = {
      source = "chanzuckerberg/snowflake"
      version = "~> 0.25"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

provider "snowflake" {
  alias = "account_admin"
  role  = "ACCOUNTADMIN"
}

provider "snowflake" {
  alias = "sys_admin"
  role  = "SYSADMIN"
}

provider "snowflake" {
  alias = "security_admin"
  role  = "SECURITYADMIN"
}
