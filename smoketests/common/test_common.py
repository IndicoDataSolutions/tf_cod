import pytest
import os
import subprocess

from lib.helpers.utilities import Process

class TestCommon:
  """A common class with common parameters, account, region, name"""

  @pytest.fixture(autouse=True)
  def setup_method(self, cloudProvider, account, region, name):
    self.cloudProvider = cloudProvider
    self.account = account
    self.region = region
    self.name = name
    self.foo = "hell yeah"

    print(f"\nSetup method called using {account}/{region}/{name}\n")

   

  @pytest.fixture(autouse=True)
  def teardown_method(self, cloudProvider, account, region, name):
     print(f"\nTeardown method called using {cloudProvider} {account}/{region}/{name}\n")

