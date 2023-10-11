terraform {
  required_version = ">= 0.13.5"
  cloud {
    organization = "indico"
    workspaces {
      name = "allied-us-east-2-allied-dev"
    }
  }
}



