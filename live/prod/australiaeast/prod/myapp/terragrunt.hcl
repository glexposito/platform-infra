include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "app" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/live/_shared/myapp.hcl"
}
