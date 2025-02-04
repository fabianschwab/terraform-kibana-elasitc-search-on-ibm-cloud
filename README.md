# Databases for Elasticsearch, Kibana and Enterprise Search

This terraform script will create the following resources:

- **Resource Group** containing all the deployed resources
- **Databases for Elasticsearch** on IBM Cloud
- **Code Engine Project** which contains the following applications
  - **Kibana**
  - **Enterprise Search**

The Terraform script will ensure that all these resources can communicate with each other. It will output the public facing Kibana URL where the user can access the Enterprise Search user interface.

It will also output the URL of the Elasticsearch deployment.

## Prerequisites

- [Terraform](https://www.terraform.io/)
- [IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)
- [An IBM Cloud Account](https://cloud.ibm.com/registration)

## Available variables to configure deployment

| Name                 | Type   | Description                                                                                                                 | Default                      |
| -------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| `ibm_cloud_api_key`  | string | IAM API Key                                                                                                                 |                              |
| `ibm_region`         | string | Region and zone the resources should be created in.                                                                         | `eu-de`                      |
| `ibm_resource_group` | string | Name of resource group to provision resources. Elastic, Kibana and Enterprise Search                                        | `terraform-ekes-stack`       |
| `es_name`            | string | Name for the Elasticsearch cluster                                                                                          | `Database-for-Elasticsearch` |
| `es_version`         | string | Version of the Elasticsearch instance. If no value is passed, the current preferred version of IBM Cloud Databases is used. |                              |
| `es_plan`            | string | Plan for the Elasticsearch cluster. (`standard`, `enterprise` or `platinum`)                                                | `enterprise`                 |
| `es_username`        | string | Username for the Elasticsearch cluster                                                                                      | `admin`                      |
| `es_password`        | string | Password for the Elasticsearch cluster                                                                                      | _Sensitive_                  |
| `es_ram_mb`          | number | RAM for the Elasticsearch cluster                                                                                           | 4096                         |
| `es_disk_mb`         | number | Disk space for the Elasticsearch cluster                                                                                    | 5120                         |
| `es_cpu_count`       | number | CPU count for the Elasticsearch cluster                                                                                     | 3                            |

## Steps to deploy from local machine

### Step 1

Get an API key by following [these steps](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui#create_user_key).

### Step 2

Clone this repo

```sh
git clone https://github.com/fabianschwab/terraform-kibana-elasitc-search-on-ibm-cloud
cd elastic-kibana-ent-search/terraform
```

### Step 3

Create a `terraform.tfvars` document with the following parameters:

```
ibmcloud_api_key = "<your api key>"
region = "<an ibm cloud region>" #e.g. eu-de
es_username = "admin"
es_password = "<make up a password>" #Passwords have a 15 character minimum and must contain a number, A-Z, a-z, 0-9, -, _
es_version="<a supported major version>" # eg 8.10
```

Note: The `variables.tf` file contains other variables that you can edit to change the CPU, RAM or disk allocation of your Elasticsearch instance.

### Step 4

Run Terraform to deploy the infrastructure:

```sh
terraform init
terraform apply --auto-approve
```

The output will contain the URL of the Kibana deployment:

```sh
kibana_endpoint = "https://kibana-app.1dqmr45rt678g05.eu-gb.codeengine.appdomain.cloud"
```

Log in at this URL with the username and password you supplied above.

Once logged in, you can configure Enterprise Search by visiting `https://kibana-app.1dqmr45rt678g05.eu-gb.codeengine.appdomain.cloud/app/enterprise_search/app_search/engines`

The output also contains the URL of the Elasticsearch deployment, which can be used to connect it to WxA.

## Notes about implementation

1. There is a circular dependency in this process because Kibana needs to know the location of the Enterprise Search deployment. But Enterprise Search also needs to know where the Kibana deployment is located. Both locations are not known until they are deployed, so Terraform is unable to configure all this in one step. This is solved by the `kibana_app_update`null resource, which runs a shell script that updates the Kibana app's environment variables with the location of the Enterprise Search app after both of these have been fully deployed.
2. The Terraform output does not contain the full version of the deployed Elastisearch instance, and this is required to deploy Kibana and Enterprise search. This is solved by the `es_metadata` data resource, which makes an API call to the deployed elasticsearch. The result of that is decoded and parsed to obtain the full version of the deployed instance.
