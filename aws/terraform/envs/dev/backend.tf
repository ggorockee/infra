terraform {
  backend "s3" {
    bucket = "value"
    key = "arpegez-terraform-state/dev/terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
  }
}
