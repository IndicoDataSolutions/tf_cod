#!/usr/bin/env python3
"""
Fetches a file from GitHub repository via API.
Reads query from stdin (JSON: repository, branch, path, token, owner).
Outputs JSON to stdout: { "content_base64": "<base64>", "exists": "true"|"false" }
When exists is false, also returns fetch_debug_* keys for Terraform output.
"""
import json
import sys
import urllib.request
import urllib.parse
import base64


def _fail(out_extra=None):
    out = {"content_base64": "", "exists": "false"}
    if out_extra:
        out.update(out_extra)
    print(json.dumps(out))


def main():
    try:
        query = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        _fail({"fetch_debug_http_status": "0", "fetch_debug_message": f"Invalid JSON: {e}"})
        sys.exit(0)

    repository = (query.get("repository") or "").strip()
    branch = (query.get("branch") or "").strip()
    path = (query.get("path") or "").strip()
    token = (query.get("token") or "").strip()
    owner = (query.get("owner") or "IndicoDataSolutions").strip()

    # GitHub API requires "owner/repo"; if repo is just name, qualify it
    if repository and "/" not in repository and owner:
        repository = f"{owner}/{repository}"

    # Normalize path: "./foo/bar" -> "foo/bar", "." alone stays (will be fixed below)
    if path.startswith("./"):
        path = path[2:]
    if path == ".":
        path = ""

    if not repository or not path:
        _fail({
            "fetch_debug_http_status": "0",
            "fetch_debug_message": "repository or path empty",
            "fetch_debug_repo": repository or "(empty)",
            "fetch_debug_path": path or "(empty)",
            "fetch_debug_branch": branch or "(empty)",
        })
        return

    # GitHub API: GET /repos/{owner}/{repo}/contents/{path}?ref={branch}
    path_encoded = urllib.parse.quote(path, safe="/")
    url = f"https://api.github.com/repos/{repository}/contents/{path_encoded}?ref={urllib.parse.quote(branch)}"

    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github.v3+json")
    if token:
        req.add_header("Authorization", f"token {token}")

    debug_base = {
        "fetch_debug_repo": repository,
        "fetch_debug_path": path,
        "fetch_debug_branch": branch,
    }

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status != 200:
                _fail({**debug_base, "fetch_debug_http_status": str(resp.status), "fetch_debug_message": "Non-200 response"})
                return
            data = json.loads(resp.read().decode())
            content_b64 = data.get("content", "")
            if content_b64:
                content_b64 = content_b64.replace("\n", "")
            print(json.dumps({"content_base64": content_b64, "exists": "true"}))
    except urllib.error.HTTPError as e:
        msg = e.read().decode()[:200] if e.fp else str(e.code)
        _fail({
            **debug_base,
            "fetch_debug_http_status": str(e.code),
            "fetch_debug_message": msg or f"HTTP {e.code}",
        })
        if e.code != 404:
            sys.exit(1)
    except Exception as e:
        _fail({
            **debug_base,
            "fetch_debug_http_status": "0",
            "fetch_debug_message": str(e)[:200],
        })


if __name__ == "__main__":
    main()
