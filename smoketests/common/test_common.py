import pytest
import os
import subprocess
import time

from lib.helpers.utilities import Process


class TestCommon:
    """A common class with common parameters, account, region, name"""

    @pytest.fixture(autouse=True)
    def setup_method(self, cloudProvider, account, region, name):
        self.cloudProvider = cloudProvider
        self.account = account
        self.region = region
        self.name = name

        print(f"\nSetup method called using {account}/{region}/{name}\n")

    @pytest.fixture(autouse=True)
    def teardown_method(self, cloudProvider, account, region, name):
        print(
            f"\nTeardown method called using {cloudProvider} {account}/{region}/{name}\n")

    def test_external_secrets_operator(self, cloudProvider, account, region, name):
        p = Process(account, region, name)
        output = p.run(["kubectl", "get", "secret", "-n",
                       "monitoring", "sql-exporter-dsn"], stdout=subprocess.PIPE)
        assert output.returncode == 0, f"Unable to get External Generated Secret sql-exporter-dsn : {output.stderr}"

    # validate that the vault-secrets-operator is able to make secrets

    def test_vault_secrets_operator(self, cloudProvider, account, region, name):

        thanos_enabled = os.environ.get('thanos_enabled', "false")
        if thanos_enabled == "false":
            return

        p = Process(account, region, name)
        secret_name = "smoketest-secret-from-vault"
        vault_static_secret = f"""
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: smoketest-secret
  namespace: default
spec:
  type: kv-v2

  # mount path
  mount: customer-{account}

  # path of the secret
  path: harbor-registry

  # dest k8s secret
  destination:
    name: {secret_name}
    create: true

  # static secret refresh interval
  refreshAfter: 30s

  # Name of the CRD to authenticate to Vault
  vaultAuthRef: default
"""
        secrets_file_path = os.path.join('/tmp', 'vault-static-secret.yaml')
        with open(secrets_file_path, 'w') as yf:
            yf.write(vault_static_secret)

        p.run(["kubectl", "delete", "-f", secrets_file_path],
              stdout=subprocess.PIPE)
        p.run(["kubectl", "apply", "-f", secrets_file_path,
               "--output", "json"], stdout=subprocess.PIPE)
        time.sleep(5)
        output = p.run(["kubectl", "get", "vaultstaticsecret", "smoketest-secret",
                       "--template", "{{ .status.secretMAC }}"], stdout=subprocess.PIPE)
        assert output.returncode == 0, f"Unable to get vaultstaticsecret : {output.stderr}"
        assert output.stdout != '<no value>', "Unable to obtain mac"
        output = p.run(["kubectl", "get", "secret",
                       f"{secret_name}", "--output", "json"], stdout=subprocess.PIPE)
        assert output.returncode == 0, f"Unable to get secret {secret_name}, error: {output.stderr}"
        p.run(["kubectl", "delete", "-f", secrets_file_path],
              stdout=subprocess.PIPE)
