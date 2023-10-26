import pytest

def pytest_addoption(parser):
    parser.addoption("--cloudProvider", action="store", default="aws", help="Cloud provider for this cluster aws or azure")
    parser.addoption("--account", action="store", default="default account", help="Cluster's case-sensitive account name")
    parser.addoption("--region", action="store", default="default region", help="Cluster's region name")
    parser.addoption("--name", action="store", default="default name", help="Cluster's name")


@pytest.fixture(scope="session")
def cloudProvider(request):
    return request.config.getoption("--cloudProvider")

@pytest.fixture(scope="session")
def account(request):
    return request.config.getoption("--account")

@pytest.fixture(scope="session")
def region(request):
    return request.config.getoption("--region")

@pytest.fixture(scope="session")
def name(request):
    return request.config.getoption("--name")

    
