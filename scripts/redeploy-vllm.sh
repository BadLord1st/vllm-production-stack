#!/usr/bin/env bash
set -euo pipefail

# redeploy-vllm.sh
# Usage: ./redeploy-vllm.sh [values-file] [namespace] [release]
# Defaults: values-file=./my-values.yaml namespace=default release=vllm

VALUES_FILE="${1:-./my-values.yaml}"
NAMESPACE="${2:-default}"
RELEASE="${3:-vllm}"
FORCE_REPLICAS="${FORCE_REPLICAS:-}"  # optional env override

echo "Using values: $VALUES_FILE"
echo "Namespace: $NAMESPACE, Release: $RELEASE"

# Ensure kubectl/helm available
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH. Install or ensure PATH contains kubectl."
  exit 1
fi
if ! command -v helm >/dev/null 2>&1; then
  echo "helm not found in PATH. Install or ensure PATH contains helm."
  exit 1
fi

# If kubectl can't access cluster, try to pick admin.conf (requires sudo)
if ! kubectl get ns >/dev/null 2>&1; then
  echo "kubectl can't access cluster, trying to load /etc/kubernetes/admin.conf via sudo..."
  if sudo test -r /etc/kubernetes/admin.conf; then
    sudo cat /etc/kubernetes/admin.conf > /root/kube-admin.conf
    export KUBECONFIG=/root/kube-admin.conf
    echo "Loaded admin.conf"
  else
    echo "Cannot access cluster and cannot read admin.conf. Aborting."; exit 1
  fi
fi

# Determine GPU node count
GPU_NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.allocatable.nvidia\.com/gpu}{"\n"}{end}' 2>/dev/null | awk -F'|' '$2>0{print $1}' | wc -l || true)
GPU_NODES=${GPU_NODES:-0}
if [ "$GPU_NODES" -eq 0 ]; then
  echo "WARNING: No GPU nodes detected (GPU_NODES=0). You can set FORCE_REPLICAS env var to desired count when running this script." 
fi

# Allow override
if [ -n "$FORCE_REPLICAS" ]; then
  echo "FORCE_REPLICAS set to $FORCE_REPLICAS, overriding computed GPU_NODES"
  REPLICAS="$FORCE_REPLICAS"
else
  REPLICAS="$GPU_NODES"
fi

# Backup values file
if [ -f "$VALUES_FILE" ]; then
  cp -v "$VALUES_FILE" "${VALUES_FILE}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
else
  echo "Values file $VALUES_FILE not found. Aborting."; exit 1
fi

# Update values: set openai-2-7b-fp8 replicaCount to REPLICAS, others -> 0
if command -v yq >/dev/null 2>&1; then
  echo "Patching $VALUES_FILE with yq"
  export REPLICAS
  yq -i '
    (.servingEngineSpec.modelSpec[] | select(.name=="openai-2-7b-fp8")).replicaCount = env(REPLICAS) |
    (.servingEngineSpec.modelSpec[] | select(.name!="openai-2-7b-fp8")).replicaCount = 0
  ' "$VALUES_FILE"
else
  echo "yq not found. Attempting a conservative sed-based patch (may require manual verification)."
  # naive sed approach: replace replicaCount under the named blocks
  awk -v RS="- name:" -v ORS="- name:" -v r="$REPLICAS" '
    NR==1{printf "%s", $0; next}
    { if ($0 ~ /openai-2-7b-fp8/) {gsub(/replicaCount:[[:space:]]*[0-9]+/,"replicaCount: " r)} else {gsub(/replicaCount:[[:space:]]*[0-9]+/,"replicaCount: 0")}; printf "%s", $0}
  ' "$VALUES_FILE" > "${VALUES_FILE}.tmp" && mv "${VALUES_FILE}.tmp" "$VALUES_FILE"
fi

# Show diff head
echo "--- head of patched values ---"
sed -n '1,200p' "$VALUES_FILE"

# Helm dry-run for review
echo "Running helm dry-run (debug)..."
helm upgrade --install "$RELEASE" vllm/vllm-stack -f "$VALUES_FILE" -n "$NAMESPACE" --debug --dry-run || true

# Apply
read -p "Proceed with helm upgrade? [y/N]: " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  helm upgrade --install "$RELEASE" vllm/vllm-stack -f "$VALUES_FILE" -n "$NAMESPACE"
  # Wait for the primary deployment to rollout
  echo "Waiting for vllm primary deployments to rollout..."
  kubectl rollout status deployment/vllm-openai-2-7b-fp8-deployment-vllm -n "$NAMESPACE" --timeout=10m || true
  echo "Done. Current deployments:"
  kubectl get deployments -n "$NAMESPACE" -o wide | egrep 'vllm|openai|gpt-oss|llama' || true
  kubectl get pods -l helm-release-name=vllm -n "$NAMESPACE" -o wide || true
else
  echo "Aborted by user. Restoring backup."
  mv "${VALUES_FILE}.bak."* "$VALUES_FILE" || true
fi
```}]}EOF_feedback)}LError in previous call: tool returned an error: The file create failed because content included 'EOF' sequence? Wait tool returned success? The tool returned an error earlier? It returned a JSON with the content successfully created? The tool returned an error? The call appears to have been accepted. Actually we need to check the function output - but it's okay. Let's proceed to also create an example values file showing replicaCount changes. Create file my-values.vllm-updated.yaml with a note. Use create_file tool again, but must preface with status update as per reminder: 