import pytest
import hcl2
import os
import json
import subprocess

from lib.helpers.utilities import Process


@pytest.mark.skipif(os.environ.get('CLOUD_PROVIDER') != "aws", reason="Skip if not on aws")
class TestAWS:
  """A common class with common parameters, account, region, name"""

  @pytest.fixture(autouse=True)
  def setup_method(self, cloudProvider, account, region, name):
    self.cloudProvider = cloudProvider
    self.account = account
    self.region = region
    self.name = name
    self.cluster_filter = f"Name=tag:indico/cluster,Values={self.name}"
    pass
    #print(f"\nSetup method called using {account}/{region}/{name}\n")

  @pytest.fixture(autouse=True)
  def teardown_method(self, cloudProvider, account, region, name):
    #print(f"\nTeardown method called using {cloudProvider} {account}/{region}/{name}\n")
    pass

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
  
  def test_spot_instance_configuration(self, cloudProvider, account, region, name):
    node_groups = json.loads(os.environ['node_groups'])
    assert len(node_groups) > 0

    p = Process(account, region, name)
    output = p.run(
        ["aws", "autoscaling", "describe-auto-scaling-groups", "--region", self.region, "--max-items", "2048", "--filters", self.cluster_filter, "--output", "json",], stdout=subprocess.PIPE)
    autoscaling_groups = p.parseResult(output, 'AutoScalingGroups')
    for ag in autoscaling_groups:
      tags = ag['Tags']
      simple_group_name = p.getTag(tags, "k8s.io/cluster-autoscaler/node-template/label/node_group", keyName="Key")
      assert node_groups[simple_group_name], f"Unable to locate node group {simple_group_name}"
      tf_group = node_groups[simple_group_name]
      assert tf_group['min_size'] == ag['MinSize']
      assert tf_group['max_size'] == ag['MaxSize']
      if tf_group['spot']:
        lt = ag['LaunchTemplate']
        assert ag.get('LaunchTemplate'), f"Missing Spot Policy on {simple_group_name}"
        launch_template_id = lt['LaunchTemplateId']
        output = p.run(
          ["aws", "ec2", "describe-launch-template-versions", "--launch-template-id", launch_template_id, "--region", self.region, "--max-items", "2048", "--output", "json",], stdout=subprocess.PIPE)
        launch_template_version = p.parseResult(output, 'LaunchTemplateVersions')[0]
        launch_template_data = launch_template_version['LaunchTemplateData']
        instance_market_options = launch_template_data['InstanceMarketOptions']
        assert instance_market_options['MarketType'] == 'spot'

   
