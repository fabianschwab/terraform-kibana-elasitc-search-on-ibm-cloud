terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.63.0"
    }
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibm_cloud_api_key
  region           = var.ibm_region
}

resource "ibm_resource_group" "tf_resource_group" {
  name = var.ibm_resource_group
}
