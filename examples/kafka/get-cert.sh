#/bin/bash
set -e
TLSCERT=tls.crt
CERTPASS=pulsar
PROXYPOD=$(kubectl get pods | grep proxy | awk '{print $1}' | head -n 1)
kubectl exec $PROXYPOD -- bash -c "cp certs/tls.crt /tmp"
kubectl cp $PROXYPOD:/tmp/tls.crt $TLSCERT
kubectl exec $PROXYPOD -- bash -c "rm /tmp/tls.crt"
keytool -import --trustcacerts  -file $TLSCERT -keystore cert.jks -storepass $CERTPASS -noprompt
