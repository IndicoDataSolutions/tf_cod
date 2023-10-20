import pytest
import os
import subprocess

#subprocess.Popen("env|sort", shell=True)

def test_validate_fixture_parameters(cloudProvider, account, region, name):
    print(f"\nCloudProvider: {cloudProvider}, Account {account}, Region: {region}, Name: {name}")
    assert cloudProvider != "aws_or_azure"
    assert account != "default account"
    assert region != "default region"
    assert name != "default name"
    

#def test_print_name_2(pytestconfig):
#    print(f"test_print_name_2(name): {pytestconfig.getoption('name')}")