terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    talos = {
      source = "siderolabs/talos"
      version = "0.7.0"
    }

  }

  backend "s3" {
    bucket  = "kubecounty-tfstate"
    encrypt = false
    key     = "talos/terraform.tfstate"
    region  = "eu-west-1"
  }
}

provider "aws" {
  region  = "eu-west-1"
}
