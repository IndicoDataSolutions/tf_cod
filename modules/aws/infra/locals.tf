# define the networking module we're using locally
locals {
  network = var.direct_connect == true ? module.private_networking : module.public_networking

  # TODO: Variablize this?
  aws_usernames = [
    "svc_jenkins",
    "terraform-sa"
  ]
  eks_users = {
    for user in local.aws_usernames : user => {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"
      username = user
      groups   = ["system:masters"]
    }
  }

  # DNS
  the_splits            = local.dns_name != "" ? split(".", local.dns_name) : split(".", "test.domain.com")
  the_length            = length(local.the_splits)
  the_tld               = local.the_splits[local.the_length - 1]
  the_domain            = local.the_splits[local.the_length - 2]
  alternate_domain_root = join(".", [local.the_domain, local.the_tld])

  dns_name = var.domain_host == "" ? lower("${var.label}.${var.region}.${var.aws_account}.${var.domain_suffix}") : var.domain_host
  #dns_suffix        = lower("${var.region}.${var.aws_account}.indico.io")
}
