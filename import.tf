variable "import_indico_core" {
  type        = bool
  description = "One-shot: import existing Helm release indico/indico-core into state"
  default     = false
}
import {
  count = var.import_indico_core ? 1 : 0
  to = module.indico-common[0].helm_release.indico_core
  id = "indico/indico-core"
}