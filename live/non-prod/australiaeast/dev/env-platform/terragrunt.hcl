include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "platform" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/live/_shared/env-platform.hcl"
}
