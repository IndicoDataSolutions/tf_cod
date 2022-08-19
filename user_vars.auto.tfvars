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
node_groups = [
  {
    min_size               = 0
    max_size               = 5
    instance_types         = ["g4dn.xlarge"]
    name                   = "gpu-workers" # for gpu workloads
    type                   = "gpu"
    spot                   = false
    desired_capacity       = "0"
    additional_node_labels = "group=gpu-enabled"
    taints                 = "--register-with-taints=nvidia.com/gpu=true:NoSchedule"
  },
  {
    min_size         = 0
    max_size         = 20
    instance_types   = ["m5.xlarge"]
    name             = "celery-workers" # for pods that we want to autoscale
    type             = "cpu"
    spot             = true
    desired_capacity = "0"
  },
  {
    min_size         = 1
    max_size         = 20
    instance_types   = ["m5.xlarge"]
    name             = "static-workers" # for pods that need to be on stable nodes.
    type             = "cpu"
    spot             = false
    desired_capacity = "0"
  },
  {
    min_size         = 0
    max_size         = 3
    instance_types   = ["m5.xlarge"]
    name             = "pdf-workers" # for pods that need to be on stable nodes.
    type             = "cpu"
    spot             = false
    desired_capacity = "1"
  },
  {
    min_size         = 0
    max_size         = 3
    instance_types   = ["m5.2xlarge"]
    name             = "highmem-workers" # for autoscaling pods that have high memory demands.
    type             = "cpu"
    spot             = false
    desired_capacity = "0"
  },
  {
    min_size         = 1
    max_size         = 9
    instance_types   = ["t2.medium"]
    name             = "monitoring-workers" # for autoscaling pods that have high memory demands.
    type             = "cpu"
    spot             = false
    desired_capacity = "3"
  },
  {
    min_size         = 1
    max_size         = 4
    instance_types   = ["m5.large"]
    name             = "pgo-workers" # for pods that we want to autoscale
    type             = "cpu"
    spot             = false
    desired_capacity = "1"
    taints           = "--register-with-taints=indico.io/crunchy=true:NoSchedule"
  }
]
# additional_tags = { # delete this if no additional tags needed
#   foo = "bar",
#   baz = "qux"
# }
default_tags = {
  "indico/customer"    = "indico-dev", #This maps pretty much to which AWS account
  "indico/cluster"     = "dop-832",    #This should match the label variable
  "indico/environment" = "dev"         # Choices are dev , stage , prod
}
user_ip = "" # set this to the external IP address if deployment server has no outbound access; else, leave as empty string or remove
#cluster_node_policies = ["AWSWAFReadOnlyAccess", "CloudWatchLogsFullAccess", "AmazonSQSFullAccess", "AmazonSNSFullAccess"]
submission_expiry = 30 # days
uploads_expiry    = 30 # days
#RDS Stuff
deletion_protection_enabled = false
skip_final_snapshot         = true
#fsx
per_unit_storage_throughput = 50
include_rox                 = false
#cluster
node_group_multi_az = false
assumed_roles = [
  "arn:aws:iam::528987135818:role/aws-reserved/sso.amazonaws.com/us-east-2/AWSReservedSSO_SupportUser_e2021891b05267dd",
  "arn:aws:iam::528987135818:role/aws-reserved/sso.amazonaws.com/us-east-2/AWSReservedSSO_PowerUserAccess_d162cafa6627ab76",
  "arn:aws:iam::528987135818:role/aws-reserved/sso.amazonaws.com/us-east-2/AWSReservedSSO_AdministratorAccess_e837eb0d7af593bc"
]
