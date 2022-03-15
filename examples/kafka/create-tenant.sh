#bin/bash
set -e
BASTIONPOD=$(kubectl get pods | grep bastion | awk '{print $1}' | head -n 1)
TENANT=$1
NAMESPACE=public
ROLE="$TENANT-admin"
TOKENFILE=$TENANT.token
CLIENTFILE=kafka.client.$TENANT.properties
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin tenants create $TENANT"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin tenants update -r $ROLE $TENANT"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin namespaces create $TENANT/$NAMESPACE"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar tokens create -pk token-private-key/my-private.key -s $ROLE" > $TOKENFILE
sed s/TENANT/$TENANT/g kafka.client.properties.template | sed s/TOKEN/$(cat $TOKENFILE)/g > $CLIENTFILE


echo "Created $CLIENTFILE with a admin token for tenant $TENANT"
