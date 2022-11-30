terraform {
  required_version = ">= 0.13.5"
  cloud {
    organization = "indico"
    workspaces {
      name = "Indico-Devops-us-east-2-devops-ci1"
    }
  }
}



