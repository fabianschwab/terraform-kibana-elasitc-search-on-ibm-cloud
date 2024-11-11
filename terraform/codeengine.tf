# RSA key of size 4096 bits for ES encryption
resource "random_id" "encryption_key1" {
  byte_length = 32
}

# Create a CE secret for mounting the certificate to Kibana and Enterprise search
resource "ibm_code_engine_secret" "ca_cert" {
  name       = "es-ca-cert"
  project_id = ibm_code_engine_project.ekes.id
  format     = "generic"
  data = {
    "ca.crt" = base64decode(data.ibm_database_connection.es_cluster_connection.https[0].certificate[0].certificate_base64)
  }
}


resource "ibm_code_engine_project" "ekes" {
  name              = "Kibana and Enterprise Search"
  resource_group_id = ibm_resource_group.tf_resource_group.id
}


resource "ibm_code_engine_app" "kibana" {
  project_id          = ibm_code_engine_project.ekes.project_id
  name                = "kibana"
  image_reference     = "docker.elastic.co/kibana/kibana:${local.es-full-version}"
  image_port          = 5601
  scale_min_instances = 1 #this can be scaled down to zero to cut costs, but there may be delays every time the Kibana app has to be re-started
  scale_max_instances = 1
  scale_cpu_limit     = 1
  scale_memory_limit  = "2G"

  run_env_variables {
    type  = "literal"
    name  = "ELASTICSEARCH_HOSTS"
    value = "[\"https://${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].hostname}:${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].port}\"]"
  }
  run_env_variables {
    type  = "literal"
    name  = "ELASTICSEARCH_USERNAME"
    value = data.ibm_database_connection.es_cluster_connection.user_id
  }
  run_env_variables {
    type  = "literal"
    name  = "ELASTICSEARCH_PASSWORD"
    value = ibm_database.es_cluster.adminpassword
  }
  run_env_variables {
    type  = "literal"
    name  = "ELASTICSEARCH_SSL_ENABLED"
    value = "true"
  }

  run_env_variables {
    type  = "literal"
    name  = "SERVER_HOST"
    value = "0.0.0.0"
  }

  run_env_variables {
    type  = "literal"
    name  = "XPACK_SECURITY_ENCRYPTIONKEY"
    value = random_id.encryption_key1.hex
  }

  run_env_variables {
    type  = "literal"
    name  = "XPACK_SECURITY_HTTP_SSL_ENABLED"
    value = "false"
  }

  run_env_variables {
    type  = "literal"
    name  = "ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES"
    value = "config/certs/ca.crt"
  }

  # Mount cert from secret
  run_volume_mounts {
    type       = "secret"
    name       = "ca-cert"
    mount_path = "/usr/share/kibana/config/certs"
    reference  = ibm_code_engine_secret.ca_cert.name
  }

}

resource "ibm_code_engine_app" "enterprise_search" {
  project_id          = ibm_code_engine_project.ekes.project_id
  name                = "enterprise-search"
  image_reference     = "docker.elastic.co/enterprise-search/enterprise-search:${local.es-full-version}"
  image_port          = 3002
  scale_min_instances = 1
  scale_max_instances = 1
  scale_cpu_limit     = 1
  scale_memory_limit  = "4G"

  run_env_variables {
    type  = "literal"
    name  = "elasticsearch.host"
    value = "https://${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].hostname}:${data.ibm_database_connection.es_cluster_connection.https[0].hosts[0].port}"
  }
  run_env_variables {
    type  = "literal"
    name  = "elasticsearch.username"
    value = data.ibm_database_connection.es_cluster_connection.user_id
  }
  run_env_variables {
    type  = "literal"
    name  = "elasticsearch.password"
    value = ibm_database.es_cluster.adminpassword
  }
  run_env_variables {
    type  = "literal"
    name  = "elasticsearch.ssl.enabled"
    value = "true"
  }
  run_env_variables {
    type  = "literal"
    name  = "allow_es_settings_modification"
    value = "true"
  }
  run_env_variables {
    type  = "literal"
    name  = "secret_management.encryption_keys"
    value = "[${random_id.encryption_key1.hex}]"
  }
  run_env_variables {
    type  = "literal"
    name  = "kibana.external_url"
    value = ibm_code_engine_app.kibana.endpoint
  }
  run_env_variables {
    type  = "literal"
    name  = "kibana.host"
    value = ibm_code_engine_app.kibana.endpoint_internal
  }

  # This tells the app where the certificate file will be
  run_env_variables {
    type  = "literal"
    name  = "elasticsearch.ssl.certificate_authority"
    value = "/usr/share/enterprise-search/config/certs/ca.crt"
  }
  # Create a Mount to the place in the app config where the cert will be
  run_volume_mounts {
    type       = "secret"
    name       = "ca-cert"
    mount_path = "/usr/share/enterprise-search/config/certs"
    reference  = ibm_code_engine_secret.ca_cert.name
  }

  depends_on = [ibm_code_engine_app.kibana]
}

#Update kibana app with enterprise search endpoint
resource "null_resource" "kibana_app_update" {
  triggers = {
    ibmcloud_api_key       = var.ibm_cloud_api_key
    region                 = var.ibm_region
    resource_group         = ibm_resource_group.tf_resource_group.id
    enterprise_search_host = ibm_code_engine_app.enterprise_search.endpoint_internal
    project_id             = ibm_code_engine_project.ekes.id
    name                   = ibm_code_engine_app.kibana.name
    kibana_url             = ibm_code_engine_app.kibana.endpoint
    always_run             = "${timestamp()}" #this ensures that the script always runs to re-instante the below env variables 
  }

  provisioner "local-exec" {
    # get an access token then update the kibana app with the enterprise search endpoint
    command = <<EOF
      ibmcloud plugin install code-engine
      ibmcloud login -r ${self.triggers.region} -g ${self.triggers.resource_group} --apikey ${self.triggers.ibmcloud_api_key}
      ibmcloud ce project select --id ${self.triggers.project_id}
      ibmcloud ce application update -n ${self.triggers.name} --env ENTERPRISESEARCH_HOST=${self.triggers.enterprise_search_host} --env ENTERPRISESEARCH_SSL_VERIFICATIONMODE=none --env SERVER_PUBLICBASEURL=${self.triggers.kibana_url}
    EOF

  }
  depends_on = [
    ibm_code_engine_app.enterprise_search,
    ibm_code_engine_app.kibana
  ]
}

output "kibana_endpoint" {
  value = ibm_code_engine_app.kibana.endpoint
}
