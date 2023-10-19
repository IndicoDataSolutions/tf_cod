#!/bin/bash
set -e

echo '{ "branch":  "'"$(git rev-parse --abbrev-ref HEAD)"'",    "sha": "'"$(git rev-parse --short HEAD)"'"}'

