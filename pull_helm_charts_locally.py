#!/usr/bin/env python3
"""
Simplified script to call TCM API and then do a git pull on the current branch.
"""

import os
import subprocess
import sys
import requests
import argparse


def get_current_branch():
    """Get the currently checked out git branch."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error getting current branch: {e}")
        sys.exit(1)


def call_tcm_api(branch: str, tcm_url: str, github_token: str, charts_branch: str):
    """Call the TCM API to generate COD helm charts."""
    url = f"{tcm_url}/generate-cod-helm-charts/{branch}/{charts_branch}"
    headers = {
        "Authorization": f"Bearer {github_token}",
        "Content-Type": "application/json",
    }

    print(f"Calling TCM API: {url}")

    try:
        response = requests.get(url, headers=headers)

        if response.status_code == 200:
            print("✓ TCM API call successful")

            # Try to parse and print commit_hash from response
            try:
                response_data = response.json()
                commit_hash = response_data.get("commit_hash")
                if commit_hash:
                    print(f"Commit hash: {commit_hash}")
            except (ValueError, KeyError):
                # If response is not JSON or doesn't have commit_hash, continue
                pass

            return True
        else:
            print(
                f"✗ TCM API call failed: HTTP {response.status_code} - {response.text}"
            )
            return False

    except Exception as e:
        print(f"✗ Error calling TCM API: {e}")
        return False


def git_pull(branch: str):
    """Perform a git pull on the current branch."""
    print("Performing git pull...")

    try:
        result = subprocess.run(
            ["git", "pull", "origin", f"{branch}"],
            capture_output=True,
            text=True,
            check=True,
        )
        print("✓ Git pull successful")
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ Git pull failed: {e}")
        print(f"Error output: {e.stderr}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Call TCM API to generate COD helm charts and then do a git pull"
    )
    parser.add_argument(
        "--tcm-url",
        default=os.getenv("TCM_URL", "https://tcm.devops.indico.io"),
        help="TCM URL (default: TCM_URL env var or https://tcm.devops.indico.io)",
    )
    parser.add_argument(
        "--charts-branch", help="Branch to use for charts (default: current branch)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only show what would be done, don't actually execute",
    )

    args = parser.parse_args()

    # Get GitHub token from environment
    github_token = os.getenv("GITHUB_TOKEN")
    if not github_token:
        print("Error: GITHUB_TOKEN environment variable is required")
        sys.exit(1)

    # Get current branch
    current_branch = get_current_branch()
    print(f"Current branch: {current_branch}")

    # Use charts branch if specified, otherwise use current branch
    charts_branch = args.charts_branch if args.charts_branch else current_branch
    print(f"Charts branch: {charts_branch}")

    if args.dry_run:
        print(f"Dry run mode - would call TCM API for charts branch {charts_branch}")
        print(f"Would perform git pull on {current_branch}")
        return

    # Call TCM API
    if call_tcm_api(current_branch, args.tcm_url, github_token, charts_branch):
        # If TCM API call succeeds, do git pull
        git_pull(current_branch)
    else:
        print("TCM API call failed, skipping git pull")
        sys.exit(1)


if __name__ == "__main__":
    main()
