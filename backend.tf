terraform {
  required_version = ">= 0.13.5"
  cloud {
    organization = "indico"
    workspaces {
      name = "Indico-Dev-us-east-2-dev-ci"
    }
  }
}
