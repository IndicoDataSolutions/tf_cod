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
    self.foo = "hell yeah"
    self.cluster_filter = f"Name=tag:indico/cluster,Values={self.name}"

    print(f"\nSetup method called using {account}/{region}/{name}\n")

  @pytest.fixture(autouse=True)
  def teardown_method(self, cloudProvider, account, region, name):
     print(f"\nTeardown method called using {cloudProvider} {account}/{region}/{name}\n")


  def test_azs(self, cloudProvider, account, region, name):
    p = Process(account, region, name)
    
    result = p.run(
        [
            "aws",
            "ec2",
            "describe-vpcs",
    #        "--profile",
    #        self.account,
            "--region",
            self.region,
            "--max-items",
            "2048",
            "--filters",
            self.cluster_filter,
            "--output",
            "json",
        ],
        stdout=subprocess.PIPE,
        )
    if result.returncode == 0 and len(result.stdout) > 0:
      print(f"success getting vpcs! {result.stdout}")
      vpcs = json.loads(result.stdout)["Vpcs"]
      if len(vpcs) > 0:
        return vpcs[0]["VpcId"]
    else:
      print(f"Return code: {result.returncode}")       
      print(result.stdout)

  def test_one(self, cloudProvider, account, region, name):
    node_groups = json.loads(os.environ['node_groups'])
    print(node_groups)
