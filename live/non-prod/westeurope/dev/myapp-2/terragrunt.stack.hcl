unit "myapp-2" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aci-app"
  path   = "app"

  values = {
    name                = "myapp-2"
    resource_group_name = "rg-platform-noncritical-dev-weu"
    container_image     = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
    ip_address_type     = "Public"
    dns_name_label      = "myapp-2-dev-weu"
    container_ports = [
      {
        port = 80
      }
    ]
    liveness_probe = {
      initial_delay_seconds = 10
      period_seconds        = 30
      http_get = {
        path = "/"
        port = 80
      }
    }
    readiness_probe = {
      initial_delay_seconds = 5
      period_seconds        = 15
      http_get = {
        path = "/"
        port = 80
      }
    }
  }
}
