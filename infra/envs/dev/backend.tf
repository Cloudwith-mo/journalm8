terraform {
  backend "s3" {
    bucket       = "journalm8-tfstate-114743615542-us-east-1"
    key          = "envs/dev/terraform.tfstate"
    region       = "us-east-1"
    profile      = "default"
    use_lockfile = true
  }
}
