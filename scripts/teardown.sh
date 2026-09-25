#!/usr/bin/env bash
# Deletes the demo cluster and everything in it (ArgoCD, the app). Git is not touched.
set -euo pipefail

CLUSTER=gitops-demo

kind delete cluster --name "$CLUSTER" # does nothing if the cluster is already gone
echo "Cluster '$CLUSTER' removed."
