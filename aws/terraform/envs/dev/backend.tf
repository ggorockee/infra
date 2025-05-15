terraform {
  backend "s3" {
    bucket = "value"
    key = "dev/terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
  }
}