# fill out this file with desired values
direct_connect = false # set to true to deploy the direct connect compatible stack
#region               = "us-east-2" # only 2 az in us-west-1
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
public_subnet_cidrs  = ["10.0.96.0/27", "10.0.97.0/27", "10.0.98.0/27"]


ipa_values = ""
#subnet_az_zones      = ["us-east-2a", "us-east-2b", "us-east-2c"]
#name                 = "dop-832"
#cluster_name         = "dop-832"
#label                = "dop-832" # will be used for resource naming. should be unique within the AWS account
k8s_version = "1.33"
# additional_tags = { # delete this if no additional tags needed
#   foo = "bar",
#   baz = "qux"
# }
default_tags = {
  "indico/customer"    = "indico-dev", #This maps pretty much to which AWS account
  "indico/cluster"     = "dop-832",    #This should match the label variable
  "indico/environment" = "dev"         # Choices are dev , stage , prod
}
submission_expiry = 30 # days
uploads_expiry    = 30 # days
#RDS Stuff
deletion_protection_enabled = false
skip_final_snapshot         = true
#fsx
per_unit_storage_throughput = 50
include_rox                 = false
include_fsx                 = false
include_efs                 = true
#cluster
az_count            = 2
s3_endpoint_enabled = true
