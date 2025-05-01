terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.96.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2" # 사용할 AWS 리전 (예: 서울)
}
