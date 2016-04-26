#!/bin/bash
echo "project_url:$(git config --get remote.origin.url),branch:$(git rev-parse --abbrev-ref HEAD),commit:$(git rev-parse --verify $(git rev-parse --abbrev-ref HEAD))"
