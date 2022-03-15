#bin/bash
set -e
BASTIONPOD=$(kubectl get pods | grep bastion | awk '{print $1}' | head -n 1)
TENANT=$1
NAMESPACE=kafka
NAMESPACE2=__kafka
NAMESPACE3=__kafka_unlimited
ROLE="$TENANT-admin"
TOKENFILE=$TENANT.token
CLIENTFILE=kafka.client.$TENANT.properties
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin tenants create $TENANT"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin tenants update -r $ROLE $TENANT"

# DATA
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin namespaces create $TENANT/$NAMESPACE"

# SYSTEM TOPICS WITH RETENTION
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin namespaces create $TENANT/$NAMESPACE2"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin topics create-partitioned-topic -p 50 persistent://$TENANT/$NAMESPACE2/__consumer_offsets"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin topics create-partitioned-topic -p 8 persistent://$TENANT/$NAMESPACE2/__transaction_state"

# SYSTEM TOPICS WITH UNLIMITED RETENTION
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin namespaces create $TENANT/$NAMESPACE3"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin namespaces set-retention -s -1 -t -1  $TENANT/$NAMESPACE3"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin topics create persistent://$TENANT/$NAMESPACE3/__kafka_schemaregistry"
kubectl exec $BASTIONPOD -- bash -c "bin/pulsar-admin topics create persistent://$TENANT/$NAMESPACE3/__kafka_producerid"

kubectl exec $BASTIONPOD -- bash -c "bin/pulsar tokens create -pk token-private-key/my-private.key -s $ROLE" > $TOKENFILE
sed s/TENANT/$TENANT/g kafka.client.properties.template | sed s/TOKEN/$(cat $TOKENFILE)/g > $CLIENTFILE


echo "Created $CLIENTFILE with a admin token for tenant $TENANT"
