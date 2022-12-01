# Azure Setup

## Requirements
1. Terraform must be installed with a version > 0.12.x
2. An azure user must be availble to create resources. The user must have a Contributor role on the resource group and must have permission to add role assignments on the subscription. Note that upon AKS cluster creation in a specific resource group, an additional resource group is automatically created by Azure; the user must have permissions to access this resource group as well.


## Setup

1. Initialize the remote backend
```bash
export REGION=eastus
source init-backend.sh
```

2. Get correct subscription to use
```bash
az account list --output table
```

3. Set correct subscription
```bash
az account set --subscription <Azure-SubscriptionId>
```

4. Create a service principal to use for the indico stack
```bash
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID" --name="indico-manager"
```

5. Set authentication environment variables
```bash
export ARM_SUBSCRIPTION_ID=<Subscription-Id>
export ARM_TENANT_ID=<Tenant-Id>
export ARM_CLIENT_SECRET=<Service-Principal-Password>
export ARM_CLIENT_ID=<Service-Principal-Client-Id>
export ARM_ACCESS_KEY=<Storage-Account-Access-Key> # should be sourced from init-backend.sh
```

Also set the service principal information for cluster consumption
```bash
export TF_VAR_svp_client_id=<service-principal-appid>
export TF_VAR_svp_client_secret=<service-principal-password>
```

7. Create an ssh key to access the Indico resources.
```bash
ssh-keygen -t rsa -b 2048
```

8. Fill out the `user_vars.auto.tfvars` file with appropriate values.

9. Run terraform init, plan, and apply to create the stack
```bash
terraform init
terraform plan # review the plan
terraform apply
```

## Generating resource diagram
The resource diagram in this repo is generated using the [diagrams module](https://github.com/mingrammer/diagrams). To make changes to the diagram, first [install the tool](https://github.com/mingrammer/diagrams#getting-started). Then run `python3 standard-deployment.py`
