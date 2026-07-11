terraform {
  backend "s3" {
    bucket = "vprofile-eks-tfstate"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
