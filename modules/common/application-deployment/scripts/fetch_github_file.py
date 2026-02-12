#!/usr/bin/env python3
"""
Fetches a file from GitHub repository via API.
Reads query from stdin (JSON: repository, branch, path, token).
Outputs JSON to stdout: { "content_base64": "<base64>", "exists": "true"|"false" }.
Used by Terraform external data source to optionally load argocd-application YAML.
"""
import json
import os
import sys
import urllib.request
import urllib.parse
import base64


def main():
    try:
        query = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON on stdin: {e}", file=sys.stderr)
        sys.exit(1)

    repository = query.get("repository", "")
    branch = query.get("branch", "")
    path = query.get("path", "")
    token = query.get("token", "")

    if not repository or not path:
        out = {"content_base64": "", "exists": "false"}
        print(json.dumps(out))
        return

    # GitHub API: GET /repos/{owner}/{repo}/contents/{path}?ref={branch}
    path_encoded = urllib.parse.quote(path, safe="/")
    url = f"https://api.github.com/repos/{repository}/contents/{path_encoded}?ref={urllib.parse.quote(branch)}"

    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github.v3+json")
    if token:
        req.add_header("Authorization", f"token {token}")

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status != 200:
                print(json.dumps({"content_base64": "", "exists": "false"}))
                return
            data = json.loads(resp.read().decode())
            content_b64 = data.get("content", "")
            if content_b64:
                # API returns base64 with newlines; strip for single-line output
                content_b64 = content_b64.replace("\n", "")
            print(json.dumps({"content_base64": content_b64, "exists": "true"}))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(json.dumps({"content_base64": "", "exists": "false"}))
        else:
            print(f"GitHub API error: {e.code}", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"Error fetching file: {e}", file=sys.stderr)
        print(json.dumps({"content_base64": "", "exists": "false"}))


if __name__ == "__main__":
    main()
