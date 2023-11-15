#!/usr/bin/env python3
import subprocess
import sys

FROM_STATE = "module.argo-registration."
TO_STATE = "module.argo-registration[0]."

if len(sys.argv) <= 1:
    print(
        f"Usage: {sys.argv[0]} <workspace_name> --yes ie {sys.argv[0]} Indico-Dev-us-east-2-dev-ci --yes"
    )
    sys.exit(1)

workspace = sys.argv[1]

dry_run = "-dry-run"
if len(sys.argv) > 2 and sys.argv[2] == "--yes":
    dry_run = ""

backend_string = f"""
terraform {{
  required_version = ">= 0.13.5"
  cloud {{
    organization = "indico"
    workspaces {{
      name = "{workspace}"
    }}
  }}
}}
"""

with open("backend.tf", "w") as f:
    f.write(backend_string)


def run(args, stdout=subprocess.PIPE, shell=False):
    return subprocess.run(args, stdout=stdout, shell=shell)


subprocess.run(["terraform", "init", "-upgrade"])  # TODO: remove comment
result = run(["terraform", "state", "list"])

for l in result.stdout.splitlines():
    line = l.decode()
    if line.startswith(FROM_STATE):
        newpath = line.replace(FROM_STATE, TO_STATE)
        if dry_run != "":
            subprocess.run(
                [
                    "terraform",
                    "state",
                    "mv",
                    dry_run,
                    line,
                    newpath,
                ]
            )
        else:
            subprocess.run(
                [
                    "terraform",
                    "state",
                    "mv",
                    line,
                    newpath,
                ]
            )
