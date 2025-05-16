# terraform backend setting
terraform {
  backend "s3" {
    bucket = "arpegez-terraform-state"
    key = "dev/terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
  }
}
