import pytest

# pytest -s -v --name ericfoo

# @pytest.fixture(scope="session")
# def account(pytestconfig):
#     return pytestconfig.getoption("account")

# @pytest.fixture(scope="session")
# def region(pytestconfig):
#     return pytestconfig.getoption("region")

# @pytest.fixture(scope="session")
# def name(pytestconfig):
#     return pytestconfig.getoption("name")

def test_print_name(cloudProvider, account, region, name):
    print(f"\nCloudProvider: {cloudProvider}, Account {account}, Region: {region}, Name: {name}")

def test_print_name_2(pytestconfig):
    print(f"test_print_name_2(name): {pytestconfig.getoption('name')}")