variable "import_indico_core" {
  type        = bool
  description = "One-shot: import existing Helm release indico/indico-core into state"
  default     = false
}

# import blocks support for_each, not count.
locals {
  import_indico_core_ids = var.import_indico_core && !var.multitenant_enabled ? { core = "indico/indico-core" } : {}
}

import {
  for_each = local.import_indico_core_ids
  to       = module.indico-common[0].helm_release.indico_core
  id       = each.value
}