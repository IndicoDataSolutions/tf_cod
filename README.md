# tf_cod
Terraform repo used for Clusters On Demand (COD)

## pre-commit setup

1. Make sure you install the python requirements for this repo.

   `pip install -r smoketests/requirements.txt`

2. Install/Setup pre-commit

   `pre-commit install`

## Smoketests

Whenever `tf_cod` has a commit to it, a Dockerfile located in [smoketests/Dockerfile](smoketests/Dockefile) gets built via a [drone job](https://drone.devops.indico.io/IndicoDataSolutions/tf_cod)

This Dockerfile contains the smoketests that validate that the input variables [./variables.tf](variables.tf) are indeed used to configure the infrastructure.  The Dockerfile contains the `aws` cli as well as the `az` cli, along with `kubectl`.  The tests may freely use these cli tools since there is a policy which enables it to run without special authentication in the same way that the boto3 blob api works.

The (pytest) tests are in 3 categories:

1. AWS Tests located in [smoketests/aws/test_aws.py](smoketests/aws/test_aws.py)
2. Azure Tests located in [smoketests/azure/test_azure.py](smoketests/azure/test_azure.py)
3. Common Tests located in [smoketests/common/test_common.py](smoketests/common/test_common.py)

### Automatic Variable Mapping

Whenever the `tf_cod` has a commit, a `pre-commit` hook runs and generates the file called [tf-smoketest-variables.tf](./tf-smoketest-variables.tf) which will contain a configmap mapping all variables to their supplied values, for example:

```terraform
resource "kubernetes_config_map" "terraform-variables" {
  depends_on = [null_resource.sleep-5-minutes]
  metadata {
    name = "terraform-variables"
  }
  data = {
    is_azure = "${jsonencode(var.is_azure)}"
    is_aws = "${jsonencode(var.is_aws)}"
    label = "${jsonencode(var.label)}"
    message = "${jsonencode(var.message)}"
    applications = "${jsonencode(var.applications)}"
    region = "${jsonencode(var.region)}"
    direct_connect = "${jsonencode(var.direct_connect)}"
    additional_tags = "${jsonencode(var.additional_tags)}"
    default_tags = "${jsonencode(var.default_tags)}"
    ...
```

The container is then deployed into the cluster using the [Helm Chart](./smoketsts/helm-chart) and creates a Job which in turn mounts the configmap as environment variables.

```python
# obtain the region and node_groups
region = os.environ['region']
node_groups = os.environ['node_groups']
```

These values can then be used to validate the inputs against the generated infrastructure.

### Example Test validating az_count

```python
  def test_autoscaling_groups(self, cloudProvider, account, region, name):
    p = Process(account, region, name)
    az_count = int(os.environ['az_count'])
    output = p.run(
        ["aws", "autoscaling", "describe-auto-scaling-groups", "--region", self.region, "--max-items", "2048", "--filters", self.cluster_filter, "--output", "json",], stdout=subprocess.PIPE)
    autoscaling_groups = p.parseResult(output, 'AutoScalingGroups')
    assert len(autoscaling_groups) > 0, f"No autoscaling groups found for {name}"
    for ag in autoscaling_groups:
      availability_zones = ag['AvailabilityZones']
      ag_name = ag['AutoScalingGroupName']
      assert len(availability_zones) == az_count, f"Mismatching az_count for {ag_name}"
```
>>>>>>> 6edf13be4639e314fc3bb3529c63d6b853edd017
