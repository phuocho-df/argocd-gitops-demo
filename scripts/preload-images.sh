#!/usr/bin/env bash
# Copies the demo images from this laptop into the kind node, so nothing is downloaded on stage.
# The images are built for amd64 only; on Apple Silicon kind cannot download them itself,
# so this step is required there (Docker runs them through emulation).
set -euo pipefail

CLUSTER=gitops-demo
IMAGE=argoproj/rollouts-demo
TAGS="blue yellow" # every tag used in the demo (the typo tag "yelow" is meant to fail)

kind get clusters 2>/dev/null | grep -x "$CLUSTER" >/dev/null || { echo "Cluster '$CLUSTER' not found. Run scripts/setup.sh first."; exit 1; }

for tag in $TAGS; do
  # Download to the laptop once (skipped when already there)
  docker image inspect "$IMAGE:$tag" >/dev/null 2>&1 || docker pull --platform linux/amd64 "$IMAGE:$tag"
  # Copy into the kind node (kind skips images that are already there)
  kind load docker-image "$IMAGE:$tag" --name "$CLUSTER"
done
