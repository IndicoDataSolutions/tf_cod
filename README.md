# tf_example-customer
terraform example repo to be used in creating clusters.  The contents of this repo are meant to be copied into a new repo.

## Working with the Terrafile
Please note that this template is dependent on versioned terraform modules using the project : https://github.com/coretech/terrafile/ . Each module is declared in the file named Terrafile.  

## Development Lifecycle:

1. Clone Repository locally with git
2. Create a feature branch from main
3. Perform whichever code changes / Updates needed. Ensure regularly pushing commits.
4. From project root run `terrafile` to download all dependent repositories.
5. Run `terraform init`
6. Run `terraform plan` and if successful, push commit.
7. Create a PR with details of change + plan output (will need to figure out how to do this).
8. Perform whatever actions are requested by reviewers until PR is approved.
10. Squash and Merge PR, delete feature branch.
11. Checkout Main, `terraform init`, `terraform plan`, `terraform apply`.

## Connecting into the cluster

You should be able to get to it using the indico-deployment docker container. What I did is configured a profile for aws called metlife (`aws configure --profile <aws account>` just add the appropriate stuff) then in the indico-deployment docker I needed to run these command to get in: export
1. `AWS_DEFAULT_REGION=<aws-region>`
2. `export AWS_DEFAULT_PROFILE=<aws account name>`
3. `kube set-cloud aws`
4. `kube set-account <aws account name>`
5. `kube switch <cluster-name>`


## Cost saving variables

1. `node_group_multi_az` set this to false if you want only a single AZ to be used for the node groups. This will save money on transfer costs to fsx.
2. `snapshot_id` this is still fairly experimental. This is something that may be used in small clusters to reduce the cost of running a ROX fsx cluster. The snapshot must be manually copied into the aws account / region for this to work.