terraform {
  required_version = ">= 0.13.5"
  cloud {
    organization = "indico"
    workspaces {
     name = "indico-dev-azure-eastus-openshift3"
    }
  }
 }




