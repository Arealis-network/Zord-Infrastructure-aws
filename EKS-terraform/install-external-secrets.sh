#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Installs the External Secrets Operator via Helm after terraform apply.
# Called by the GitHub Actions workflow with these env vars already set:
#   CLUSTER_NAME   - EKS cluster name
#   ESO_NAMESPACE  - Namespace where External Secrets Operator runs
#   ESO_SERVICE_ACCOUNT - Service account name for External Secrets Operator
#   AWS_REGION     - AWS region
# ---------------------------------------------------------------------------

echo "Configuring kubectl for cluster: ${CLUSTER_NAME}"
if ! aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "Cluster ${CLUSTER_NAME} was not found in region ${AWS_REGION}."
  echo "Clusters currently visible in this account and region:"
  aws eks list-clusters --region "${AWS_REGION}" || true
  exit 1
fi

echo "Waiting for cluster to become ACTIVE..."
aws eks wait cluster-active --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

echo "Waiting for all nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Adding External Secrets Helm repo..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

echo "Installing External Secrets Operator..."
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace "${ESO_NAMESPACE}" \
  --create-namespace \
  --set installCRDs=true \
  --set serviceAccount.create=true \
  --set serviceAccount.name="${ESO_SERVICE_ACCOUNT}"

echo "Waiting for External Secrets deployment to be available..."
kubectl rollout status deployment/external-secrets \
  -n "${ESO_NAMESPACE}" --timeout=300s

echo "Verifying External Secrets installation..."
kubectl get deployment -n "${ESO_NAMESPACE}" external-secrets
kubectl get pods -n "${ESO_NAMESPACE}"
kubectl get crd externalsecrets.external-secrets.io

echo "External Secrets Operator installed successfully."
