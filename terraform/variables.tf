##########
# General
##########

variable "ibm_cloud_api_key" {
  type        = string
  description = "IAM API Key"
}

variable "ibm_region" {
  type        = string
  description = "Region and zone the resources should be created in."
  default     = "eu-de"
}

variable "ibm_resource_group" {
  type        = string
  description = "Name of resource group to provision resources. Elastic, Kibana and Enterprise Search"
  default     = "terraform-ekes-stack"
}

##########################
# Elasticsearch variables
##########################
variable "es_name" {
  type        = string
  description = "Name for the Elasticsearch cluster"
  default     = "Database-for-Elasticsearch"
}

variable "es_version" {
  type        = string
  description = "Version of the Elasticsearch instance. If no value is passed, the current preferred version of IBM Cloud Databases is used."
}

variable "es_plan" {
  type        = string
  description = "Plan for the Elasticsearch cluster. (`standard`, `enterprise` or `platinum`)"
  default     = "enterprise"
}

variable "es_username" {
  type        = string
  description = "Username for the Elasticsearch cluster"
  default     = "admin"
}

variable "es_password" {
  type        = string
  description = "Password for the Elasticsearch cluster"
  sensitive   = true
}

# Elasticsearch cluster variables
variable "es_ram_mb" {
  type        = number
  description = "RAM for the Elasticsearch cluster"
  default     = 4096
}
variable "es_disk_mb" {
  type        = number
  description = "Disk space for the Elasticsearch cluster"
  default     = 5120
}

variable "es_cpu_count" {
  type        = number
  description = "CPU count for the Elasticsearch cluster"
  default     = 3
}
