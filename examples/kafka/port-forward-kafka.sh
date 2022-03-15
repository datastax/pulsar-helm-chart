#/bin/bash
set -e
PROXYPOD=$(kubectl get pods | grep proxy | awk '{print $1}' | head -n 1)
kubectl port-forward $PROXYPOD 9093:9093
