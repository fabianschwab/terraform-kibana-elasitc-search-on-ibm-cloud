resource "ibm_database" "es_cluster" {
  service           = "databases-for-elasticsearch"
  name              = var.es_name
  version           = var.es_version
  plan              = var.es_plan
  location          = var.ibm_region
  resource_group_id = ibm_resource_group.tf_resource_group.id
  adminpassword     = var.es_password

  group {
    group_id = "member"

    memory {
      allocation_mb = var.es_ram_mb
    }

    disk {
      allocation_mb = var.es_disk_mb
    }

    cpu {
      allocation_count = var.es_cpu_count
    }
  }
}

data "ibm_database_connection" "es_cluster_connection" {
  endpoint_type = "public"
  deployment_id = ibm_database.es_cluster.id
  user_id       = var.es_username
  user_type     = "database"
}

# The data object below calls the ES URL in order to establish the full version of the deployed database
# because that is needed to deploy Kibana and Enterprise Search
# The full version gets stored in a local variable es-ful-version and then used in the codengine resources
data "http" "es_metadata" {
  url      = "https://${var.es_username}:${ibm_database.es_cluster.adminpassword}@${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].hostname}:${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].port}"
  insecure = true
}

locals {
  # get data from api call
  es_data = jsondecode(data.http.es_metadata.response_body)

  # get version
  es-full-version = local.es_data.version.number
}

output "es_url" {
  value     = "https://${var.es_username}:${ibm_database.es_cluster.adminpassword}@${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].hostname}:${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].port}"
  sensitive = true
}
